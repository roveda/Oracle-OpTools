#!/usr/bin/perl
#
# ora_grants.pl - revoke all and grant rights on Oracle database objects
#
# ---------------------------------------------------------
# Copyright 2009 - 2021, roveda
#
# This file is part of Oracle OpTools.
#
# Oracle OpTools is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Oracle OpTools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Oracle OpTools.  If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   perl ora_grants.pl <configuration file> <ora_grants_section>
#
# ---------------------------------------------------------
# Description:
#   This perl script looks for the name of a definition file
#   for privileges on database objects, which is found in the
#   given <configuration file>.
#
#   It parses that definition file for privileges and revokes all
#   database object privileges and grants the defined rights to
#   other database schemas (=users).
#
#   WARNING: Run this script only if you know what you are doing!!!
#            It may break your complete application!
#            There is no fallback except a complete recovery!
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts on a test instance initially.
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   uls-client-2.0-1 or later
#   You must set the necessary Oracle environment variables
#   or configuration file variables before starting this script.
#
# ---------------------------------------------------------
# Versions:
#
# date            name        version
# ----------      ----------  -------
# 2009-10-02      roveda      0.01
#
# 2009-10-29      roveda      0.02
#   Added a bit doc in the header.
#
# 2009-12-30      roveda      0.03
#   Now removing old temporary log files correctly.
#
# 2011-11-11      roveda      0.04
#   Added the GPL.
#
# 2012-08-30      roveda      0.05
#   Changed to ULS-modules.
#
# 2013-08-25      roveda      0.06
#   Modified to match the new single configuration file.
#
# 2014-08-20      roveda      0.07
#   Added the processing of section SPECIFIC_GRANTS.
#
# 2014-12-14      roveda      0.08
#   Omit the synonyms that point to a remote table via database link in db_objects().
#
# 2015-02-14      roveda      0.09
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#
# 2016-03-09      roveda      0.10
#   The "exit value" is no longer sent to ULS.
#
# 2016-03-18      roveda      0.11
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-11-23      roveda      0.12
#   Boost for the revoke object privilege section.
#   Write all revoke commands for all object privileges for all grantees
#   in one script and execute it.
#
# 2017-02-02      roveda      0.13
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.14
#   Added signal handling.
#
# 2017-03-21      roveda      0.15
#   Fixed the broken support of sid specific configuration file.
#
# 2017-06-19      roveda      0.16
#   Ignoring temporary compression advisor tables when granting privilges.
#
# 2021-01-26      roveda      0.17
#   Added Support for multitenant databases. The PDB parameter can now be 
#   set additionally in each section of the configuration file.
#   Updated the module versions as of today.
#
# 2021-11-27      roveda      0.18
#   Added full UTF-8 support. Thanks for the boilerplate
#   https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129
#
# 2021-12-09      roveda      0.19
#   Moved 'set feedback off' to beginning of sql command in exec_sql()
#   and added more NLS settings.
#
#
#   Change also $VERSION later in this script!
#
# ===================================================================


# use 5.003_07;
use strict;
use warnings;

# -----------------------------------------------------------------------------
# boilerplate from
# https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129

use warnings    qw< FATAL  utf8     >;
use open        qw< :std  :utf8     >;
use charnames   qw< :full >;
use feature     qw< unicode_strings >;

# use File::Basename      qw< basename >;
# use Carp                qw< carp croak confess cluck >;
use Encode              qw< encode decode >;
use Unicode::Normalize  qw< NFD NFC >;
# -----------------------------------------------------------------------------

use File::Basename;
use File::Copy;

# These are ULS-module:
use lib ".";
use Misc 0.44;
use Uls2 1.17;

my $VERSION = 0.19;

# ===================================================================
# The "global" variables
# ===================================================================

# Usage
my $USAGE = "perl ora_grants.pl <configuration file> <ora_grants_section>";

# Name of this script.
my $CURRPROG = "";

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';

my $WORKFILEPREFIX;
my $TMPOUT1;
my $SQLSCRIPT;
my $LOCKFILE;
my $DELIM = "!";

# This hash keeps the command line arguments
my %CMDARGS;
# This keeps the contents of the configuration file
my %CFG;

# This keeps the settings for the ULS
my %ULS;

# That is used to give the workfiles a timestamp.
# If it has changed since the last run of this script, it
# will build new workfiles (e.g. when the system is rebooted).
# (similar to LAST_ONSTAT_Z for Informix)
my $WORKFILE_TIMESTAMP = "";

# Some helping constants for calculating {K | M | G}Bytes (you must divide):
my $KB = 1024;
my $MB = $KB * $KB;
my $GB = $KB * $MB;

my $MB_FMT  = "%.1f";  # sprintf formatting for MegaBytes
my $PC_FMT  = "%.1f";  # sprintf formatting for %
my $SEC_FMT = "%.3f";  # sprintf formatting for seconds

# This is to indicate "not available":
my $NA = "n/a";

# Use this to test for (nearly) zero:
my $VERY_SMALL = 1E-60;

# The $MSG will contain still the "OK", when reaching the end
# of the script. If any errors occur (which the script is testing for)
# the $MSG will contain "ERROR" or a complete error message, additionally,
# the script will send any error messages to the uls directly.
# <hostname> - "Oracle Database Server [xxxx]" - __watch_oracle9.pl - message
my $MSG = "OK";

# Final numerical value, 0 if MSG = "OK", 1 if MSG contains any other value
my $EXIT_VALUE = 0;

# This hash keeps the documentation for the teststeps.
my %TESTSTEP_DOC;

# Holds the __$CURRPROG or $CFG{"IDENTIFIER"} just for easy usage.
my $IDENTIFIER;

# Keeps the version of the oracle software
my $ORACLE_VERSION = "";

# Holds the pdb name (if PDB is defined in the configuration)
my $USE_PDB = "";

# Keeps the section name of the configuration file, in
# which the grants are defined.
my $GRANTS_SECTION = "";

# ===================================================================
# The subroutines
# ===================================================================

# ------------------------------------------------------------
sub signal_handler {
  # first parameter is the signal, like HUP INT QUIT ABRT ALRM TERM.

  title(sub_name());

  output_error_message("$CURRPROG: Signal $_[0] catched! Clean up and abort script.");

  clean_up($TMPOUT1, $LOCKFILE);

  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  exit(9);
}

# ------------------------------------------------------------
sub output_error_message {
  # output_error_message(<message>)
  #
  # Send the given message(s), set the $MSG variable and
  # print out the message.

  $EXIT_VALUE = 1;
  $MSG = "ERROR";
  foreach my $msg (@_) { print STDERR "$msg\n" }
  foreach my $msg (@_) { uls_value($IDENTIFIER, "message", $msg, " ") }

} # output_error_message


# ------------------------------------------------------------
sub errors_in_file {
  # errors_in_file <filename>
  #
  # Check contents of e.g. $TMPOUT1 for ORA- errors.

  my $filename = $_[0];

  if (! open(INFILE, "<$filename")) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    return(1);
  }

  my $L;

  while ($L = <INFILE>) {
    chomp($L);
    if ($L =~ /ORA-/i) {
      # yes, there have been errors.
      output_error_message(sub_name() . ": Error: There have been error(s) in file '$filename'!");
      return(1);
    }

  } # while

  if (! close(INFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(1);
  }
  return(0); # everything ok
} # errors_in_file


# ------------------------------------------------------------
sub reformat_spool_file {
  # reformat_spool_file(<filename>)
  #
  # Reformats the spool file, removes unnecessary blanks surrounding
  # the delimiter, like this:
  #
  # ARTUS                         !          2097152000!            519569408
  # SYSTEM                        !          2097152000!            174129152
  # UNDOTS                        !          1048576000!             10027008
  #
  # ARTUS!2097152000!519569408
  # SYSTEM!2097152000!174129152
  # UNDOTS!1048576000!10027008
  #
  # This is necessary, because matching of constant expressions (like 'ARTUS')
  # would fail (the proper expression would be: 'ARTUS                         ').

  my $filename = $_[0];
  my $tmp_filename = "$filename.tmp";

  if (! open(INFILE, $filename)) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    return(0);
  }

  if (! open(OUTFILE, ">$tmp_filename")) {
    output_error_message(sub_name() . ": Error: Cannot open '$tmp_filename' for writing. $!");
    return(0);
  }

  my $L;

  while($L = <INFILE>) {
    chomp($L);
    my @e = split($DELIM, $L);
    my $E;
    foreach $E(@e) {
      print OUTFILE trim($E), $DELIM;
    }
    print OUTFILE "\n";
  }

  if (! close(INFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(0);
  }

  if (! close(OUTFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$tmp_filename'. $!");
    return(0);
  }

  if (! copy($tmp_filename, $filename)) {
    output_error_message(sub_name() . ": Error: Cannot copy '$tmp_filename' to '$filename'. $!");
    return(0);
  }

  if (! unlink($tmp_filename)) {
    output_error_message(sub_name() . ": Error: Cannot remove '$tmp_filename'. $!");
    return(0);
  }
} # reformat_spool_file


# ------------------------------------------------------------
sub exec_sql {
  # exec_sql(<sql command> [, <spool_filename>]);
  # Just executes the given sql statement against the current database instance.
  # Use <spool_filename> if givven, else $TMPOUT1.

  my $sql_command = $_[0];
  my $spool_filename = $_[1] || $TMPOUT1;

  my $set_container = "";
  # For PDBs
  if ( $USE_PDB ) {
    print "USE_PDB=$USE_PDB\n";
    $set_container = "alter session set container=$USE_PDB;";
  }

  # connect / as sysdba

  # Set nls_territory='AMERICA' to get decimal points.

  my $sql = "
    set echo off
    set feedback off

    alter session set NLS_TERRITORY='AMERICA';
    alter session set NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
    alter session set NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS';
    alter session set NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SS TZH:TZM';

    $set_container

    set newpage 0
    set space 0
    set linesize 32000
    set pagesize 0
    set heading off
    set markup html off spool off

    set trimout on;
    set trimspool on;
    set serveroutput off;
    set define off;
    set flush off;

    set numwidth 20
    set colsep '$DELIM'

    spool $spool_filename;

    $sql_command

    spool off;";

  print "----- SQL -----\n$sql\n---------------\n\n";

  print "----- result -----\n";

  # if (! open(CMDOUT, "| sqlplus -S \"/ as sysdba\" ")) {
  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    output_error_message(sub_name() . ": Error: Cannot open pipe to '$SQLPLUS_COMMAND'. $!");
    return(0);   # error
  }
  print CMDOUT "$sql\n";
  if (! close(CMDOUT)) {
    output_error_message(sub_name() . ": Error: Cannot close pipe to sqlplus. $!");
    return(0);
  }
  print "------------------\n";

  reformat_spool_file($spool_filename);

  return(1);   # ok
} # exec_sql


# -------------------------------------------------------------------
sub do_sql {
  # do_sql(<sql> [, <spool_filename>] )
  #
  # Returns 0, when errors have occurred,
  # and outputs an error message,
  # returns 1, when no errors have occurred.

  my $sql = $_[0];
  my $spool_filename = $_[1] || $TMPOUT1;

  if (exec_sql($sql, $spool_filename)) {
    if (errors_in_file($spool_filename)) {
      output_error_message(sub_name() . ": Error: there have been errors when executing the sql statement.");
      uls_send_file_contents($IDENTIFIER, "message", $spool_filename);
      return(0);
    }
    # Ok
    return(1);
  }

  output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
  uls_send_file_contents($IDENTIFIER, "message", $spool_filename);

  return(0);

} # do_sql


# -------------------------------------------------------------------
sub clean_up {
  # clean_up(<file list>)
  #
  # Remove all left over files at script end.

  title("Cleaning up");

  # Remove temporary files.
  foreach my $file (@_) {
    if (-e $file) {
      print "Removing temporary file '$file' ...";
      if (unlink($file)) {print "Done.\n"}
      else {print "Failed.\n"}
    }
  }
} # clean_up


# -------------------------------------------------------------------
sub send_runtime {
  # The runtime of this script
  # send_runtime(<start_secs> [, {"s"|"m"|"h"}]);

  # Current time minus start time.
  my $rt = time - $_[0];

  my $unit = uc($_[1]) || "S";

  if    ($unit eq "M") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0, -1), "min") }
  elsif ($unit eq "H") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0 / 60.0, -2), "h") }
  else                 { uls_value($IDENTIFIER, "runtime", pround($rt, 0), "s") }


} # send_runtime


# ------------------------------------------------------------
sub send_doc {
  # send_doc(<title> [, <as title>])
  #
  # If the <title> is found in the $TESTSTEP_DOC hash, then
  # the associated text is sent as documentation to the ULS.
  # Remember: the teststep must exist in the ULS before any
  #           documentation can be saved for it.
  # If the alias <as title> is given, the associated text is
  # sent to the ULS for teststep <as title>. So you may even
  # document variable teststeps with constant texts. You may
  # substitute parts of the contents of the hash value, before
  # it is sent to the ULS.

  my $title = $_[0];
  my $astitle = $_[1] || $title;

  if (%TESTSTEP_DOC) {
    if ($TESTSTEP_DOC{$title}) {
      # TODO: You may want to substitute <title> with <astitle> in the text?
      uls_doc($astitle, $TESTSTEP_DOC{$title})
    } else {
      print "No documentation for '$title' found.\n";
    }
  }

} # send_doc


# ===================================================================
sub general_info {
  # Gather some general info about the current oracle instance

  # This sub returns a value, whether the rest of the script is
  # executed or not.

  title("General Info");

  my $ts = "Info";

  # ----- Check if Oracle is available
  my $sql = "select 'database status', status from v\$instance;";

  if (exec_sql($sql)) {

    if (! errors_in_file($TMPOUT1)) {

      my $V = trim(get_value($TMPOUT1, $DELIM, "database status"));
      if ($V ne "OPEN") {return(0)}

    } else {

      output_error_message(sub_name() . ": Error: there have been errors when executing the sql statement.");
      uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
      return(0);

    }
  } else {
    # It is a fatal error if that value cannot be derived.
    output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
    uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
    return(0);
  }

  # ----- More information
  $sql = "
    select 'oracle version', version from v\$instance;
    select 'hostname', host_name from v\$instance;
    select 'instance name', instance_name from v\$instance;
    select 'instance startup at', TO_CHAR(startup_time,'YYYY-MM-DD HH24:MI:SS') from v\$instance;
    select 'database log mode', log_mode from v\$database;
  ";

  if (! do_sql($sql)) {return(0)}

  $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  $WORKFILE_TIMESTAMP = trim(get_value($TMPOUT1, $DELIM, "instance startup at"));

  return(1); # ok
} # general_info



# -------------------------------------------------------------------
sub db_objects {
  # db_objects(<schema_owner>, <object_types>);

  # <object_types> = 'TABLE', 'VIEW', 'SYNONYM'

  my ($schema, $object_types) = @_;

  $schema = uc($schema);
  $object_types = uc($object_types);

  # Only synonyms that do not point to a remote table vi db link
  my $sql = "
    select object_name from dba_objects
      where object_type in ($object_types)
        and owner = '$schema'
        and status = 'VALID'
        and ( select db_link 
              from dba_synonyms 
              where owner = '$schema' 
                and synonym_name=object_name ) is null
      order by 1
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @objects = get_value_list($TMPOUT1, $DELIM, 1);

  return(join(",", @objects));

} # db_objects


# =====[ GRANT SECTION ]============================================


# -------------------------------------------------------------------
sub grant_object_rights {
  # grant_object_rights(<grantor>, <grants>, <grantees>);

  title(sub_name());

  my ($grantor, $grants, $grantees) = @_;

  if (! $grantor || ! $grants || ! $grantees ) { return() }

  # <grants>: select,insert,update,...
  # <grantees>: user1,user2,user3,...

  # The expression is directly used in a sql command, so watch out!
  my $schema_objects = db_objects($grantor, "'TABLE', 'VIEW', 'SYNONYM'");

  # table1,synonym2,view3,...

  # print "schema_objects=$schema_objects\n";

  my $sql = "";

  foreach my $dbo ( (split(",", $schema_objects)) ) {
    # Exclude temporary Compression Advisor tables like CMP3$123456
    if ($dbo !~ /^CMP\d{1}\$\d{3,}/) {
      $sql .= "grant $grants on $grantor.$dbo to $grantees;\n";
    } else {
      print "Info: Leaving out object $grantor.$dbo, it is a compression advisor table.\n";
    }
  } # foreach

  # print "SQL=\n";
  # print "$sql\n";

  if (! do_sql($sql)) {return(0)}

} # grant_object_rights


# -------------------------------------------------------------------
sub remove_non_existing_grantees {
  # remove_non_existing_grantees("USER1,USER2,USER3,...");


} # remove_non_existing_grantees


# -------------------------------------------------------------------
sub set_object_rights {

  title(sub_name());

  # Walk over the keys of the hash and set the defined grant for the
  # schemas in the values.

  # GRANT_OBJECT_PRIVS = <<EOP
  #   pcs02t: select       :pcs02t,pcs03t;
  #   pcs03t: select update:pcs02t,pcs03t;
  #   pcsash: select       :dop_admin;
  #
  # EOP


  my $obj_privs = $CFG{"$GRANTS_SECTION.GRANT_OBJECT_PRIVS"};
  if (! $obj_privs ) {
    print "No GRANT_OBJECT_PRIVS section found.\n";
    return(1)
  }


  # make one line
  $obj_privs =~ s/\n//g;
  # split into array at ';'
  my @OP = split(";", $obj_privs);

  foreach my $op (@OP) {
    my ($grantor, $grants, $grantees) = split(":", $op);

    $grantor = uc(trim($grantor));

    # from "select,  update,delete"
    my @G = map(trim($_), (split(",", trim($grants))) );

    # to "select,update,delete"
    $grants = join(",", @G);

    # from "pcs02t,pcs03t,  pcs04t"
    my @E = map(uc(trim($_)), (split(",", trim($grantees))) );

    # to "PCS02T,PCS03T,PCS04T"
    $grantees = join(",", @E);

    # remove grantor from middle, end or beginning
    $grantees =~ s/,$grantor,/,/g;
    $grantees =~ s/,$grantor$//g;
    $grantees =~ s/^$grantor,//g;

    remove_non_existing_grantees($grantees);

    print "grantor=$grantor | grants=$grants | grantees=$grantees\n";

    grant_object_rights($grantor, $grants, $grantees);

  } # foreach

} # set_object_rights


# =====[ REVOKE SECTION ]============================================


# -------------------------------------------------------------------
sub revoke_all_for_grantees {

  title(sub_name());

  my $rGrantees = $_[0];

  @$rGrantees = map("'" . $_ . "'", @$rGrantees);

  my $in_grantees = join(",", @$rGrantees);
  print "in_grantees=$in_grantees\n";

  my $object_types = "'TABLE', 'VIEW', 'SYNONYM'";

  my $sql = "
    select 'REVOKE ' || PRIVILEGE || ' ON ' || OWNER || '.' || TABLE_NAME || ' FROM ' || GRANTEE
    FROM dba_tab_privs
    where GRANTEE in ($in_grantees)
    ;
  ";

  if (! do_sql($sql, $SQLSCRIPT)) {return(0)}

  # You must change the delimiter ! to ;
  $sql = "
    host sed -i 's/!/;/g' $SQLSCRIPT
    start $SQLSCRIPT
  ";
  if (! do_sql($sql)) {return(0)}

  return(1);

} # revoke_all_for_grantees

# -------------------------------------------------------------------
sub revoke_all_object_rights {
  #
  # Revoke all grants of all known database users from all
  # objects of all schemas (grantors), except the schema owner.

  title(sub_name());

  # Walk over all schemas which have objects.

  # Remove all grants to other (!) grantees

  # REVOKE_ALL_OBJECT_PRIVS = <<EOP
  #   pcs02t;
  #   pcs03t;
  #   pcsash;
  # EOP

  my $grantees = $CFG{"$GRANTS_SECTION.REVOKE_ALL_OBJECT_PRIVS"};
  if (! $grantees ) {
    print "No REVOKE_ALL_OBJECT_PRIVS section found.\n";
    return(1)
  }

  # make one line
  $grantees =~ s/\n//g;
  # split into array at ';'
  my @G = map(trim($_), (split(";", trim($grantees))) );
  @G = map(uc($_), @G);

  revoke_all_for_grantees(\@G);

} # revoke_all_object_rights


# =====[ SPECIFIC_GRANT SECTION ]============================================


# -------------------------------------------------------------------
sub specific_grants {
  # specific_grants();

  # Process the explicitly defined GRANTs like:
  #
  # SPECIFIC_GRANTS = <<EOP
  #   GRANT SELECT ON OWNER1.TABLE1 TO OWNER2;
  #   GRANT SELECT ON OWNER2.TABLE3 TO OWNER1;
  # EOP
  #
  # No checks are made, whether the owners or tables exist, but
  # there will be an error entry in the log file.
  #

  title(sub_name());

  my $specific_grants = $CFG{"$GRANTS_SECTION.SPECIFIC_GRANTS"};
  if (! $specific_grants ) {
    print "No SPECIFIC_GRANTS section found.\n";
    return(1)
  }

  # make one line
  $specific_grants =~ s/\n//g;
  # split into array at ';'
  my @G = map(trim($_), (split(";", trim($specific_grants))) );
  # re-append a ; to each line
  @G = map("$_;", @G );

  my $i = 0;
  foreach my $sql (@G) {
    print "grant command=$sql\n";

    if (! do_sql($sql)) {
      print STDERR sub_name() . ": Error: Cannot process sql: $sql\n";

      $i++;
      # Send only the first 30 error messages as report to ULS
      if    ($i  < 30 ) { uls_value($IDENTIFIER, "error report", "Cannot process sql: $sql", " ") }
      elsif ($i == 30 ) { uls_value($IDENTIFIER, "error report", "...", " ") }
    }
  }

  return(0)

} # specific_grants



# ===================================================================
# main
# ===================================================================
#
# initial customization, no output should happen before this.
# The environment must be set up already.

# $CURRPROG = basename($0, ".pl");   # extension is removed
$CURRPROG = basename($0);
$IDENTIFIER = "_" . basename($0, ".pl");

my $currdir = dirname($0);
my $start_secs = time;

my $initdir = $ENV{"TMP"} || $ENV{"TEMP"} || '/tmp';  # $currdir;
my $initial_logfile = "${initdir}/${CURRPROG}_$$.tmp";
# re-direct stdout and stderr to a temporary logfile.
open(STDOUT, "> $initial_logfile") or die "Cannot re-direct STDOUT to $initial_logfile.\n";
open(STDERR, ">&STDOUT") or die "Cannot re-direct STDERR to STDOUT.\n";
select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;           # make unbuffered

# -------------------------------------------------------------------
# From here on, STDOUT+ERR is logged.

title("Start");
print "$CURRPROG is started in directory $currdir\n";

# -----
# ORA_GRANTS section identifier
# (like LEVEL0_RMAN_COMMAND)

# second(!) command line argument
$GRANTS_SECTION = $ARGV[1];
if (! $GRANTS_SECTION) {
  print STDERR $CURRPROG . ": Error: no ORA_GRANTS section given as argument!\n";
  exit(2);
}

print "ORA_GRANTS section:$GRANTS_SECTION\n";


# -------------------------------------------------------------------
# Get configuration file contents

my $cfgfile = $ARGV[0];
print "configuration file=$cfgfile\n";

# $GRANTS_SECTION keeps the dynamic section name, given as command line parameter.
my @Sections = ( "GENERAL", "ORACLE", "ULS", $GRANTS_SECTION );
print "Reading sections: ", join(",", @Sections), " from configuration file\n";

if (! get_config2($cfgfile, \%CFG, @Sections)) {
  print STDERR "$CURRPROG: Error: Cannot parse configuration file '$cfgfile' correctly => aborting\n";
  exit(1);
}

# Check for SID-specific .conf file
my ($name,$dir,$ext) = fileparse($cfgfile,'\..*');
# $cfgfile = "${dir}${name}_$ENV{ORACLE_SID}${ext}";
$cfgfile = "${dir}$ENV{ORACLE_SID}${ext}";

if (-r $cfgfile) {
  print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' found => processing it.\n";

  if (! get_config2($cfgfile, \%CFG, @Sections)) {
    print STDERR "$CURRPROG: Error: Cannot parse ORACLE_SID-specific configuration file '$cfgfile' correctly => aborting\n";
    exit(1);
  }
} else {
  print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' NOT found. Executing with defaults.\n";
}

print "-- Effective configuration:\n";
show_hash(\%CFG, "=");
print "-----\n\n";

# ----------
# This sets the %ULS to all necessary values
# deriving from %CFG (configuration file),
# environment variables (ULS_*) and defaults.

uls_settings(\%ULS, \%CFG);

print "-- ULS configuration:\n";
show_hash(\%ULS);
print "-----\n\n";

# ----------
# Check for IDENTIFIER

# Set default
$IDENTIFIER = $CFG{"$GRANTS_SECTION.IDENTIFIER"} || $IDENTIFIER;
print "IDENTIFIER=$IDENTIFIER\n";
# From here on, you may use $IDENTIFIER for uniqueness

# -------------------------------------------------------------------
# environment

if ((! $ENV{"ORACLE_SID"})  && $CFG{"ORACLE.ORACLE_SID"})  {$ENV{"ORACLE_SID"}  = $CFG{"ORACLE.ORACLE_SID"}}
if ((! $ENV{"ORACLE_HOME"}) && $CFG{"ORACLE.ORACLE_HOME"}) {$ENV{"ORACLE_HOME"} = $CFG{"ORACLE.ORACLE_HOME"}}

if (! $ENV{"ORACLE_SID"}) {
  print STDERR "$CURRPROG: Error: ORACLE_SID is not set in the environment => aborting.\n";
  exit(1);
}
if (! $ENV{"ORACLE_HOME"}) {
  print STDERR "$CURRPROG: Error: ORACLE_HOME is not set in the environment => aborting.\n";
  exit(1);
}
print "Oracle environment variables:\n";
print "ORACLE_HOME=", $ENV{"ORACLE_HOME"}, "\n";
print "ORACLE_SID=", $ENV{"ORACLE_SID"}, "\n";
print "\n";


# -------------------------------------------------------------------
# Working directory

my $workdir = $ENV{"WORKING_DIR"} || $CFG{"GENERAL.WORKING_DIR"} || "/var/tmp/oracle_optools/$ENV{ORACLE_SID}";  # $currdir;

if ( ! (-e $workdir)) {
  print "Creating directory '$workdir' for work files.\n";
  if (! mkdir($workdir)) {
    print STDERR "$CURRPROG: Error: Cannot create directory '$workdir' => aborting!\n";
    exit(1);
  }
}

# $WORKFILEPREFIX = "${workdir}/${CURRPROG}_" . $ENV{"ORACLE_SID"};
# # If a different identifier is specified in the conf file, then add it
# if ( $IDENTIFIER ne "__$CURRPROG" ) { $WORKFILEPREFIX .= "_$IDENTIFIER" }
# print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

$WORKFILEPREFIX = "${workdir}/${IDENTIFIER}";
# print "WORKFILEPREFIX=$WORKFILEPREFIX\n";
# If no oracle sid is found in the workfile prefix, then add it.
# Normally, this should be set in the configuration file.
# if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

# -------------------------------------------------------------------
# Setting up a lock file to prevent more than one instance of this
# script starting simultaneously.

$LOCKFILE = "${WORKFILEPREFIX}.LOCK";
# print "LOCKFILE=$LOCKFILE\n";

if (! lockfile_build($LOCKFILE)) {
  # LOCK file exists and process is still running, abort silently.
  print "Another instance of this script is still running => aborting!\n";
  exit(1);
}

# -------------------------------------------------------------------
# The final log file.

my $logfile = "$WORKFILEPREFIX.log";

move_logfile($logfile);

# re-direct stdout and stderr to a logfile.
open(STDOUT, "> $logfile") or die "Cannot re-direct STDOUT to $logfile. $!\n";
open(STDERR, ">&STDOUT") or die "Cannot re-direct STDERR to STDOUT. $!\n";
select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;           # make unbuffered

# Copy initial logfile contents to current logfile.
if (-e $initial_logfile) {
  print "Contents of initial logfile '$initial_logfile':\n";
  open(INITLOG, $initial_logfile);
  while (<INITLOG>) {print}
  close(INITLOG);
  print "Removing initial log file '$initial_logfile'...";
  if (unlink($initial_logfile)) {print "Done.\n"}
  else {print "Failed.\n"}

  print "Remove possible old temporary files.\n";
  # Remove old .tmp files
  opendir(INITDIR, $initdir);
  my @files = grep(/$CURRPROG.*\.tmp/, map("$initdir/$_", readdir(INITDIR)));
  foreach my $file (@files) {
    # Modification time of file, also fractions of days.
    my $days = pround(-M $file, -1);

    if ($days > 5) {
      print "Remove '", basename($file), "', ($days days old)...";
      if (unlink($file)) {print "Done.\n"}
      else {print "Failed.\n"}
    }
  } # foreach
}

# -------------------------------------------------------------------
title("Set up ULS");

# Initialize uls with basic settings
uls_init(\%ULS);

my $d = iso_datetime($start_secs);
# $d =~ s/\d{1}$/0/;

set_uls_timestamp($d);

# uls_show();

# ---- Send name of this script and its version
uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

# Signal handling, do own housekeeping, send data to ULS and exit on most signals.
use sigtrap 'handler' => \&signal_handler, 'normal-signals', 'error-signals';

# ---- Send also versions of ULS-modules.
uls_value($IDENTIFIER, "modules", "Misc $Misc::VERSION, Uls2 $Uls2::VERSION", " ");

uls_timing({
    teststep  => $IDENTIFIER
  , detail    => "start-stop"
  , start     => iso_datetime($start_secs)
});

# Send the ULS data up to now to have that for sure.
uls_flush(\%ULS);

# -------------------------------------------------------------------
# The real work starts here.
# ------------------------------------------------------------

# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
print "TMPOUT1=$TMPOUT1\n";
$SQLSCRIPT = "${WORKFILEPREFIX}_1.sql";
print "SQLSCRIPT=$SQLSCRIPT\n";

print "DELIM=$DELIM\n";

# ----- documentation -----
title("Documentation");

print "Send the documentation during this run.\n";

# de-reference the return value to the complete hash.
%TESTSTEP_DOC = %{doc2hash(\*DATA)};

# uls_value($IDENTIFIER, "documentation", "transferring", " ");

# -----
# Check if a pdb is defined

title("Check for PDB");

$USE_PDB = "";
if ($CFG{"$GRANTS_SECTION.PDB"}) {
  $USE_PDB = $CFG{"$GRANTS_SECTION.PDB"};
  print "PDB specified in configuration file: $USE_PDB\n";
} else {
  print "No PDB specified in configuration file.\n";
}

# ----- sqlplus command -----
# Check, if the sqlplus command has been redefined in the configuration file.
$SQLPLUS_COMMAND = $CFG{"ORACLE.SQLPLUS_COMMAND"} || $SQLPLUS_COMMAND;

# ----- general info ----
if (! general_info()) {
  # Check the alert.log, even if Oracle isn't running any longer,
  # it may contain interesting info.
  alert_log();

  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  clean_up($TMPOUT1, $LOCKFILE);
  send_runtime($start_secs);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);
  exit(1);
}


# -----[ System Privileges ]-----

# -----
# Revoke all system privileges

# -----
# Set system privileges
#
# set_privileges();



# -----[ Object Privileges ]-----

# -----
# Revoke ALL grants to any schema objects for all grantees!!!

revoke_all_object_rights();

# -----
# Set all object privileges to grantees

set_object_rights();


# -----
# Set specific grants

specific_grants();

# -----

#uls_file({
#     teststep  => "$IDENTIFIER"
#   , detail    => "grant definition"
#   , filename  => "$PRIVS_DEFINITION_FILE"
#});
# Need to change that later



## Continue here with more

# The real work ends here.
# -------------------------------------------------------------------

# Any errors will have sent already its error messages.
uls_value($IDENTIFIER, "message", $MSG, " ");
# uls_value($IDENTIFIER, "exit value", $EXIT_VALUE, "#");

send_doc($CURRPROG, $IDENTIFIER);

send_runtime($start_secs);
uls_timing($IDENTIFIER, "start-stop", "stop");

uls_flush(\%ULS);

# -------------------------------------------------------------------
clean_up($TMPOUT1, $SQLSCRIPT, $LOCKFILE);

title("END");

if ($MSG eq "OK") {exit(0)}
else {exit(1)}


#########################
# end of script
#########################

__END__

# The format:
#
# *<teststep title>
# <any text>
# <any text>
#
# *<teststep title>
# <any text>
# <any text>
# ...
#
# Remember to keep the <teststep title> equal to those used
# in the script. If not, you won't get the expected documentation.

#########################
*ora_grants.pl
=============

This perl script parses a definition file for privileges which is defined in a configuration file, and revokes all database object privileges from defined schemas and grants defined rights from a grantor (=schema=user) to other database grantees (=schemas=users).

This script is part of the Oracle OpTools and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org


message:
  If the script runs fine, it returns 'OK', else an error message.

runtime:
  The runtime of the script.

start-stop:
  The start and stop timestamps for the script.

script name, version:
  Sends the name and the current version of this script.

# exit value:
#   Is 0 if the script has finished without errors,
#   1 if errors have occurred. This is intended to monitor the
#   proper execution of this script.
# 


Copyright 2009-2021, roveda

Oracle OpTools is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Oracle OpTools is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Oracle OpTools.  If not, see <http://www.gnu.org/licenses/>.

