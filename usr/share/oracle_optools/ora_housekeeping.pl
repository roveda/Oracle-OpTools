#!/usr/bin/perl
#
# ora_housekeeping.pl - purge old audit entries
#
# ---------------------------------------------------------
# Copyright 2016 - 2022, roveda
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
#   perl ora_housekeeping.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script sets the timestamp for the oldest audit entry to keep
#   (last_archive_time) and purges all audit entries that are older 
#   than that timestamp. By default, Oracle does not have a built-in 
#   mechanism for that.
#
#   The alert.log and the listener.log will be moved aside each 
#   sunday night and compress these files with date and time placed in
#   the filename.
#
#   The adrci is executed and purges all(!) other files.
#
#   The number of days to be kept is defined in the configuration file, 
#   section [ORA_HOUSEKEEPING].
#
#   Send any hints, wishes or bug reports to: 
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#   See the configuration file.
#
# ---------------------------------------------------------
# Restrictions:
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   uls-client
#   You must set the necessary Oracle environment variables
#   or configuration file variables before starting this script.
#
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts on a test instance initially.
#
# ---------------------------------------------------------
# Versions:
#
# date            name        version
# ----------      ----------  -------
# 2016-02-04      roveda      0.01
#   Created.
#
# 2016-03-09      roveda      0.02
#   The "exit value" is no longer sent to ULS.
#
# 2016-03-18      roveda      0.03
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.04
#   Added the SID to the WORKFILEPREFIX.
#
# 2017-01-30      roveda      0.05
#   Renamed parameter to ROTATE_LOGFILES_ONLY_GREATER_THAN.
#
# 2017-02-02      roveda      0.06
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.07
#   Added signal handling.
#
# 2017-03-20      roveda      0.08
#   Fixed the age in 'purge -age' to minutes derived from the given number of days.
#   Implemented workaround for Oracle bug concerning adr_base which is 
#   NOT derived from diagnostic_dest but from a central file in ORACLE_HOME.
#   Therefore not correct if multiple instances are present on one server.
#   Fixed the broken support of sid specific configuration file.
#
# 2017-12-28      roveda      0.09
#   Added the purging of old audit entries if unified auditing is enabled.
#
# 2018-02-15      roveda      0.10
#   Changed the deletion of unified audit entries.
#
# 2018-03-09      roveda      0.11
#   Unified auditing now has an own parameter for how long the entries 
#   have to be kept on the local database.
#
# 2018-03-11      roveda      0.12
#   Missing END IF corrected.
#
# 2019-07-24      roveda      0.13
#   Restricted execution when running as physical standby in dataguard.
#
# 2020-07-27      roveda      0.14
#   Added 'set serveroutput on' to PLSQL sections.
#
# 2021-11-27      roveda      0.15
#   Added full UTF-8 support. Thanks for the boilerplate
#   https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129
#
# 2021-12-08      roveda      0.16
#   Added support for multitenant, checking for initialized audit trails and 
#   initialize them, if not.
#
# 2021-12-09      roveda      0.17
#   Moved 'set feedback off' to beginning of sql command in exec_sql()
#   and added more NLS settings.
#   Added 'set serveroutput on' in sql of init_cleanup().
#
# 2022-02-03      roveda      0.18
#   init_cleanup() will not be executed if database is not open (e.g. on DataGuard standby server).
#
# 2022-02-10      roveda      0.19
#   Real numbers are now allowed for KEEP_UNIFIED_AUDIT_ENTRIES_FOR in purge_unified_audit_entries().
#   Added/changed some informational output in purge_unified_audit_entries().
#
#
#   Change also $VERSION later in this script!
#
# ===================================================================


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

# These are my modules:
use lib ".";
use Misc 0.44;
use Uls2 1.17;

my $VERSION = 0.19;

# ===================================================================
# The "global" variables
# ===================================================================

# Name of this script.
my $CURRPROG = "";

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';

my $WORKFILEPREFIX;
my $TMPOUT1;
my $LOCKFILE;
my $DELIM = "!";

# This hash keeps the command line arguments
my %CMDARGS;
# This keeps the contents of the configuration file
my %CFG;

# This keeps the settings for the ULS
my %ULS;

# The $MSG will contain still the "OK", when reaching the end
# of the script. If any errors occur (which the script is testing for)
# the $MSG will contain "ERROR" or a complete error message, additionally,
# the script will send any error messages to the uls directly.
# <hostname> - "Oracle Database Server [xxxx]" - __watch_oracle9.pl - message
my $MSG = "OK";

# Final numerical value, 0 if MSG = "OK", 1 if MSG contains any other value
my $EXIT_VALUE = 0;

# Holds the __$CURRPROG or $CFG{"IDENTIFIER"} just for easy usage.
my $IDENTIFIER;

# This hash keeps the documentation for the teststeps.
my %TESTSTEP_DOC;

# Keeps the complete version of the Oracle software
# (11.2.0.4.5)
my $ORACLE_VERSION = "";
# from 18 on there is a 
my $ORACLE_VERSION_FULL = "";
# Oracle version with leading zeroes for comparison
my $ORACLE_VERSION_3D = "";

# The following variables keep the single release numbers derived from the overall version.
# 
# Major Database Release Number: 
# The first digit is the most general identifier. It represents a major new version 
# of the software that contains significant new functionality.
# 
# Database Maintenance Release Number: 
# The second digit represents a maintenance release level. Some new features may also be included.
# 
# Application Server Release Number:
# The third digit reflects the release level of the Oracle Application Server (OracleAS).
# 
# Component-Specific Release Number:
# The fourth digit identifies a release level specific to a component. Different 
# components can have different numbers in this position depending upon, 
# for example, component patch sets or interim releases.
# 
# Platform-Specific Release Number:
# The fifth digit identifies a platform-specific release. Usually this is a patch set. 
# When different platforms require the equivalent patch set, 
# this digit will be the same across the affected platforms.

my $ORACLE_MAJOR_VERSION = "";
my $ORACLE_MINOR_VERSION = "";


# Database role (PRIMARY/PHYSICAL STANDBY)
my $ORACLE_DBROLE = "";
# Database status (OPEN/MOUNTED)
my $ORACLE_DBSTATUS = "";

# -----
#  Multitenant 
#
# NO/YES if it is a CDB
my $ORACLE_IS_CDB = "NO"; 

# Keeps the list of all present pdbs (for the current cdb)
my @PDB_LIST = ();
# Holds the current pdb name (of @PDB_LIST)
my $CURRENT_PDB = "";
my $CURRENT_CON_ID = -1;


# -----
# diagnostic_dest, used for 'set base $DIAG_DEST' in adrci
my $DIAG_DEST = "";


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
  # exec_sql(<sql command> [, <print the spool file>]);
  #
  # Just executes the given sql statement against the current database instance.
  # If <print the spool file> is a true expression (e.g. a 1) the spool file
  # will be printed to stdout.

  # connect / as sysdba

  # Set nls_territory='AMERICA' to get decimal points.

  my $set_container = "";
  # For PDBs
  if ( $CURRENT_PDB ) {
    print "CURRENT_PDB=$CURRENT_PDB\n";
    $set_container = "alter session set container=$CURRENT_PDB;";
  }


  my $sql = "
    set echo off
    set feedback off

    alter session set nls_territory='AMERICA';
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

    spool $TMPOUT1;

    $_[0]

    spool off;
  ";

  print "----- SQL -----\n$sql\n---------------\n\n";

  # -----
  my $t0 = time;

  print "----- result -----\n";

  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    print sub_name() . ": Info: execution time:", time - $t0, "s\n";
    output_error_message(sub_name() . ": Error: Cannot open pipe to '$SQLPLUS_COMMAND'. $!");
    return(0);   # error
  }
  print CMDOUT "$sql\n";
  if (! close(CMDOUT)) {
    print sub_name() . ": Info: execution time:", time - $t0, "s\n";
    output_error_message(sub_name() . ": Error: Cannot close pipe to sqlplus. $!");
    return(0);
  }

  print "------------------\n";
  print sub_name() . ": Info: execution time:", time - $t0, "s\n";

  # -----
  # Print the spool output if a true second parameter is given

  if ($_[1]) {
    print "-----[ $TMPOUT1 ]-----\n";
    print_file($TMPOUT1);
    print "----------------------\n";
  }

  reformat_spool_file($TMPOUT1);

  return(1);   # ok
} # exec_sql


# -------------------------------------------------------------------
sub do_sql {
  # do_sql(<sql>)
  #
  # Returns 0, when errors have occurred,
  # and outputs an error message,
  # returns 1, when no errors have occurred.

  # if (exec_sql($_[0])) {
  if (exec_sql(@_)) {
    if (errors_in_file($TMPOUT1)) {
      output_error_message(sub_name() . ": Error: there have been errors when executing the sql statement.");
      uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
      return(0);
    }
    # Ok
    return(1);
  }

  output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
  uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);

  return(0);

} # do_sql



# -------------------------------------------------------------------
sub clean_up {
  # clean_up()
  #
  # Remove all left over files at script end.

  title(sub_name());

  my @files = @_;

  foreach my $f (@files) {
    # Remove the file.
    if (-e $f) {
      print "Removing file '$f' ...";
      if (unlink($f)) {print "Done.\n"}
      else {print "Failed.\n"}
    }
  }

} # clean_up


# -------------------------------------------------------------------
sub send_runtime {
  # The runtime of this script
  # send_runtime(<start_secs> [, {"s"|"m"|"h"}]);
  title(sub_name());

  # Current time minus start time.
  my $rt = time - $_[0];

  my $unit = uc($_[1]) || "S";

  if    ($unit eq "M") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0, -1), "min") }
  elsif ($unit eq "H") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0 / 60.0, -2), "h") }
  else                 { uls_value($IDENTIFIER, "runtime", pround($rt, 0), "s") }


} # send_runtime


# ===================================================================


# -------------------------------------------------------------------
sub oracle_available {
  title(sub_name());

  # ----- Check if Oracle is available
  my $sql = "
    select 'database status', status from v\$instance;
    SELECT 'database role', DATABASE_ROLE FROM V\$DATABASE;
  ";

  if (! do_sql($sql)) {return(0)}

  my $db_status = trim(get_value($TMPOUT1, $DELIM, "database status"));
  my $db_role = trim(get_value($TMPOUT1, $DELIM, "database role"));

  # Set global variables
  $ORACLE_DBSTATUS = $db_status;
  $ORACLE_DBROLE = $db_role;

  if ("$db_role, $db_status" eq "PRIMARY, OPEN" ) {
    # role and status is ok, create AWR report
    print "Database role $db_role and status $db_status is ok.\n";

  } elsif ("$db_role, $db_status" eq "PHYSICAL STANDBY, MOUNTED") {
    # role and status is ok, but no AWR report
    print "Database role $db_role and status $db_status only allows restricted execution.\n";

  } else {
    # role and status is NOT ok, abort and error
    output_error_message(sub_name() . ": Error: Database role $db_role and status $db_status do not allow an execution!");
    return(0);
  }

  $sql = "select 'from_instance', version from v\$instance;";
  if (! do_sql($sql)) {return(0)}
  $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "from_instance", 2));
  $ORACLE_VERSION_FULL = $ORACLE_VERSION;
  ($ORACLE_MAJOR_VERSION, $ORACLE_MINOR_VERSION, my $dummy) = split(/\./, $ORACLE_VERSION, 3);
  $ORACLE_VERSION_3D = join(".", map(sprintf("%03d", $_), split(/\./, $ORACLE_VERSION) ) );

  $sql = "";

  # Only Oracle 18 and later has this column
  if ($ORACLE_MAJOR_VERSION >= 18) {
    if ( $sql ) { $sql .= "\n" }
    $sql .= "select 'oracle version full', version_full FROM v\$instance;";
  }
  # Only Oracle 12 and later has this column
  if ($ORACLE_MAJOR_VERSION >= 12) {
    if ( $sql ) { $sql .= "\n" }
    $sql .= "select 'is_cdb', cdb from v\$database;";
  }

  my $ORACLE_IS_CDB = "NO";
  if ($sql ) {
    if (! do_sql($sql)) {return(0)}
    my $ovf = trim(get_value($TMPOUT1, $DELIM, "oracle version full"));
    if ( $ovf ) { $ORACLE_VERSION_FULL = $ovf }
    $ORACLE_IS_CDB = uc(trim(get_value($TMPOUT1, $DELIM, "is_cdb")));
  }

  # -----
  if ( $ORACLE_IS_CDB ne 'YES' ) {
    print "This is not a container database, no pluggable databases.\n";
    # No error, just leave the sub.
    return(1);  # ok
  }
  # -----------------------------------------------------------------

  # Ok, we got pluggable databases
  # Leave out the PDB$SEED and any PDBs not 'READ WRITE'

  $sql = "
    SELECT NAME, CON_ID FROM V\$PDBS 
    WHERE NAME != 'PDB\$SEED' AND OPEN_MODE = 'READ WRITE'
    ORDER BY CON_ID;
  ";
  if (! do_sql($sql)) {return(0)}

  # -----
  # Fill the global @PDB_LIST with all pdb names

  my @pdbs;
  get_value_lines(\@pdbs, $TMPOUT1);

  # Walk over all lines (which are PDBs)
  # Remember: each line contains a delimiter.

  foreach my $pdb (@pdbs) {

    my @p = split($DELIM, $pdb);
    @p = map(trim($_), @p);
    # There is only one PDB per line
    my ($p, $conid) = @p;

    push(@PDB_LIST, "$p|$conid");
  }


  return(1);

} # oracle_available


# ===================================================================
sub purge_audit_entries {

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    print "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the execution of this section!\n";
    return(0);
  }

  my $default_keep_for_days = 90;

  my $keep_for_days = $CFG{"ORA_HOUSEKEEPING.KEEP_AUDIT_ENTRIES_FOR"} || $default_keep_for_days;
  if ( $keep_for_days !~ /\d+/ ) {
    output_error_message(sub_name() . ": Error: The parameter KEEP_AUDIT_ENTRIES_FOR is not numeric in the configuration file! The default value of $default_keep_for_days is used.");
    $keep_for_days = $default_keep_for_days;
  }
  print "Keeping the audit entries for: $keep_for_days days.\n";

  my $sql = "

    set serveroutput on;

    select 'AUDIT_TRAIL: ' || to_char(upper(value)) from v\$parameter where lower(name) = 'audit_trail';
    select 'OLDEST_ENTRY (before purge): ' || to_char(min(TIMESTAMP), 'yyyy-mm-dd HH24:MI:SS') from dba_audit_session;

    DECLARE
      audit_setting varchar(30);
    BEGIN
      select upper(value) into audit_setting from v\$parameter where lower(name) = 'audit_trail';

      IF audit_setting != 'NONE' then

        dbms_output.put_line('Cleaning some audit trails');

        -- using AUDIT_TRAIL_ALL does not work, an error is thrown. so use each single trail

        IF 
          DBMS_AUDIT_MGMT.IS_CLEANUP_INITIALIZED(DBMS_AUDIT_MGMT.AUDIT_TRAIL_AUD_STD)
        THEN
          dbms_output.put_line('Cleaning AUDIT_TRAIL_AUD_STD');
          -- Set timestamp for oldest audit entry to keep
          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_AUD_STD, TRUNC(SYSTIMESTAMP)-$keep_for_days);
          -- purge the entries
          DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_AUD_STD, use_last_arch_timestamp => TRUE);
        ELSE
          dbms_output.put_line('AUDIT_TRAIL_AUD_STD is not initialized');
        END IF;

        IF 
          DBMS_AUDIT_MGMT.IS_CLEANUP_INITIALIZED(DBMS_AUDIT_MGMT.AUDIT_TRAIL_FGA_STD)
        THEN
          dbms_output.put_line('Cleaning AUDIT_TRAIL_FGA_STD');
          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_FGA_STD, TRUNC(SYSTIMESTAMP)-$keep_for_days);
          DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_FGA_STD, use_last_arch_timestamp => TRUE);
        ELSE
          dbms_output.put_line('AUDIT_TRAIL_FGA_STD is not initialized');
        END IF;

        IF 
          DBMS_AUDIT_MGMT.IS_CLEANUP_INITIALIZED(DBMS_AUDIT_MGMT.AUDIT_TRAIL_OS)
        THEN
          dbms_output.put_line('Cleaning AUDIT_TRAIL_OS');
          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_OS     , TRUNC(SYSTIMESTAMP)-$keep_for_days);
          DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_OS, use_last_arch_timestamp => TRUE);
        ELSE
          dbms_output.put_line('AUDIT_TRAIL_OS is not initialized');
        END IF;

        IF 
          DBMS_AUDIT_MGMT.IS_CLEANUP_INITIALIZED(DBMS_AUDIT_MGMT.AUDIT_TRAIL_XML)
        THEN
          dbms_output.put_line('Cleaning AUDIT_TRAIL_XML');
          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_XML    , TRUNC(SYSTIMESTAMP)-$keep_for_days);
          DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_XML, use_last_arch_timestamp => TRUE);
        ELSE
          dbms_output.put_line('AUDIT_TRAIL_XML is not initialized');
        END IF;
      END IF;

    END;
    /

    select 'OLDEST_ENTRY (after purge): ' || to_char(min(TIMESTAMP), 'yyyy-mm-dd HH24:MI:SS') from dba_audit_session;
  ";

  if (! do_sql($sql)) {return(0)}

  return(1);

} # purge_audit_entries



# -------------------------------------------------------------------
sub init_cleanup {
  # Check, if the audit trail has been initialized.
  # If not, do so.

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    print "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the execution of this section!\n";
    return(0);
  }

  my $sql = "
    SELECT 'clean_up_interval', count(1) FROM dba_audit_mgmt_config_params
    where parameter_name = 'DEFAULT CLEAN UP INTERVAL';
  ";

  if (! do_sql($sql)) {return(0)}

  my $c = trim(get_value($TMPOUT1, $DELIM, "clean_up_interval"));
  print "Number of 'DEFAULT CLEAN UP INTERVAL's found: $c\n";

  if ( $c < 1 ) {
    $sql = "
      set serveroutput on;

      BEGIN
        DBMS_AUDIT_MGMT.INIT_CLEANUP(
           audit_trail_type         => DBMS_AUDIT_MGMT.AUDIT_TRAIL_ALL
          ,default_cleanup_interval => 240     /* hours */
          -- ,container => DBMS_AUDIT_MGMT.CONTAINER_CURRENT   /* default  */
        );
      END;
      /
    ";

    if (! do_sql($sql)) {return(0)}

  }

  return(1);

} # init_cleanup



# -------------------------------------------------------------------
sub purge_unified_audit_entries {

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    print "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the execution of this section!\n";
    return(0);
  }

  # -----
  my $sql = "select 'unified_auditing', upper(value) from v\$option where lower(parameter) = 'unified auditing';";

  if (! do_sql($sql)) {return(0)}

  my $V = trim(get_value($TMPOUT1, $DELIM, "unified_auditing"));
  print "Unified Auditing=$V\n";

  if ($V !~ /TRUE/ ) { return(1) }

  # -----
  my $default_keep_for_days = 30;

  my $keep_for_days = $CFG{"ORA_HOUSEKEEPING.KEEP_UNIFIED_AUDIT_ENTRIES_FOR"} || $default_keep_for_days;
  if ( ($keep_for_days =~ /^\d+\z/) || ($keep_for_days =~ /^-?(?:\d+\.?|\.\d)\d*\z/) ) {
    # This is an integer or a real number (with decimal point)
    print "The parameter KEEP_UNIFIED_AUDIT_ENTRIES_FOR ($keep_for_days) is an integer or a real number in the configuration file\n";
  } else {
    output_error_message(sub_name() . ": Error: The parameter KEEP_UNIFIED_AUDIT_ENTRIES_FOR ($keep_for_days) is not numeric in the configuration file! The default value of $default_keep_for_days is used.");
    $keep_for_days = $default_keep_for_days;
  }
  print "Keeping the unified audit entries for: $keep_for_days days.\n";

  $sql = "
    set serveroutput on;

    DECLARE
      unified_auditing varchar(30);
      oldest_entry date;
      keep_for_days number := $keep_for_days;
      keep_until date;
    BEGIN
      select upper(value) into unified_auditing from v\$option where lower(parameter) = 'unified auditing';

      IF unified_auditing = 'TRUE' then

        dbms_output.put_line('Cleaning the unified audit trail (AUDIT_TRAIL_UNIFIED)');

        DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL;

        select SYSTIMESTAMP - keep_for_days into keep_until from dual;
        dbms_output.put_line('Keep audit entries until: ' || to_char(keep_until, 'yyyy-mm-dd HH24:MI:SS'));

        select min(EVENT_TIMESTAMP) into oldest_entry from UNIFIED_AUDIT_TRAIL;
        dbms_output.put_line('OLDEST_ENTRY (before purge): ' || to_char(oldest_entry, 'yyyy-mm-dd HH24:MI:SS'));

        if oldest_entry < keep_until then
          dbms_output.put_line('There are outdated entries => purge');

          -- Set timestamp for oldest audit entry to keep
          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
              audit_trail_type     => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED
            , last_archive_time    => keep_until
            , CONTAINER => DBMS_AUDIT_MGMT.CONTAINER_CURRENT
          );

          -- purge the entries
          DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
              AUDIT_TRAIL_TYPE           =>  DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED
            , USE_LAST_ARCH_TIMESTAMP    =>  TRUE
          );

          select min(EVENT_TIMESTAMP) into oldest_entry from UNIFIED_AUDIT_TRAIL;
          dbms_output.put_line('OLDEST_ENTRY (after purge): ' || to_char(oldest_entry, 'yyyy-mm-dd HH24:MI:SS'));

        ELSE
          dbms_output.put_line('No audit entries found older than ' || to_char(keep_until, 'yyyy-mm-dd HH24:MI:SS') );
        END IF;

      ELSE
        dbms_output.put_line('Unified Auditing is not activated');
      END IF;

    END;
    /

  ";
  # There are circumstances that keep old entries although they should be purged.
  # A solution is still work in progress.

  if (! do_sql($sql)) {return(0)}

  return(1);

} # purge_unified_audit_entries



# -------------------------------------------------------------------
sub rm_old_files {
  # rm_old_files(filename);

  # The parameter contains a complete filename.
  # THAT ONE MAY NOT BE REMOVED, but older ones that 
  # have similar names.
  #
  # The file names look like:
  # /oracle/admin/orcl/diag/tnslsnr/lbbkptd001/listener_db11a/trace/listener_db11a.log.20160209_114317
  # or
  # /oracle/admin/orcl/diag/rdbms/db11a/db11a/trace/alert_db11a.log.20160209_114317

  my $filename = $_[0];
  # file name: "/oracle/admin/orcl/diag/rdbms/orcl/orcl/trace/alert_orcl.log"
  # The files: "/oracle/admin/orcl/diag/rdbms/orcl/orcl/trace/alert_orcl.log.20160209_115600.xz"

  # The filename itself, followed by a dot and a 2 (the date) and anything else.
  my $pattern = "$filename\.2.*";

  # Days to keep the compressed logfiles.
  my $default_max_age = 90;
  my $max_age = $CFG{"ORA_HOUSEKEEPING.KEEP_COMPRESSED_LOGFILES_FOR"} || $default_max_age;
  if ( $max_age !~ /\d+/ ) {
    output_error_message(sub_name() . ": Error: The parameter KEEP_COMPRESSED_LOGFILES_FOR is not numeric in the configuration file! The default value of $default_max_age is used.");
    $max_age = $default_max_age;
  }
  print "Keep compressed logfiles for $max_age days.\n";

  my $dir = dirname($filename);
  print "Directory: $dir\n";

  # Open the directory
  opendir(DIR, $dir);
  # Array of matching files
  my @files = grep(/$pattern/, map("$dir/$_", readdir(DIR)));
  closedir(DIR);

  foreach my $file (@files) {
    print "Checking file: $file\n";
    # Modification time of file, also fractions of days.
    my $days = pround(-M $file, -1);
    print "File was modified $days days ago.\n";

    if ($days >= $max_age) {
      print "Remove '", basename($file), "', ($days days old)...";
      if (unlink($file)) {print "Done.\n"}
      else {print "Failed.\n"}
    }
  } # foreach

} # rm_old_files


# -------------------------------------------------------------------
sub diagnostic_dest {
  title(sub_name());

  # -----
  # Get the diagnostic dest from database
  #
  # See :
  #   Changing Adr Base with "diagnostic_dir" but ADRCI Shows Old Base (Doc ID 1435987.1)
  # for further information. In short:
  # the adr base is maintained in file 
  # ORACLE_HOME/log/diag/adrci_dir.mif
  # BUT THAT IS NOT SID SPECIFIC, it would not work for 
  # multiple instances.

  my $sql = "select 'DIAGNOSTIC_DEST', value from v\$parameter where upper(name) = 'DIAGNOSTIC_DEST'; ";

  if (! do_sql($sql)) {return(undef)}

  $DIAG_DEST = trim(get_value($TMPOUT1, $DELIM, "DIAGNOSTIC_DEST"));
  print "DIAG_DEST=$DIAG_DEST\n";

  return($DIAG_DEST);
} # diagnostic_dest
 
# -------------------------------------------------------------------
sub rotate_logs {
  # If any logfile is greater than a defined size, 
  # move that aside and compress it using the command given 
  # in the configuration file.

  # How To Purge Listener Log.Xml File? [ID 816871.1]

  # /oracle/admin/SID/diag/rdbms/SID/DBNAME/trace/alert_SID.log
  # /oracle/admin/SID/diag/rdbms/SID/DBNAME/trace/sbtio.log

  title(sub_name());

  # in MB
  my $default_greater_than = 10;
  my $greater_than = $CFG{"ORA_HOUSEKEEPING.ROTATE_LOGFILES_ONLY_GREATER_THAN"} || $default_greater_than;
  if ( $greater_than !~ /\d+/ ) {
    output_error_message(sub_name() . ": Error: The parameter ROTATE_LOGFILES_ONLY_GREATER_THAN is not numeric in the configuration file! The default value of $default_greater_than is used.");
    $greater_than = $default_greater_than;
  }
  print "Rotate log files only if greater than $greater_than MB.\n";

  my $default_compress_cmd = "xz -1";
  my $compress_cmd = $CFG{"ORA_HOUSEKEEPING.COMPRESS_COMMAND"} || $default_compress_cmd;
  print "Compress command: $compress_cmd\n";

  my $cmd = "";
  my $out = "";

  # -----
  # Get all tracefiles ending in .log
  #
  # Especially the alert.log

  $cmd = "adrci exec=\"set base $DIAG_DEST; show tracefiles %.log\" 2>&1";
  print "cmd: $cmd\n";

  my @out = `$cmd`;
  if ( $? == -1 ) {
    output_error_message(sub_name() . ": Error: The command failed: $!");
    return(1);
  } else {
    print "The command exited with value: ", $? >> 8, "\n";
  }

  foreach my $tracefile (@out) {
    $tracefile = trim($tracefile);
    print "\nTracefile: $tracefile\n";

    my $file = $DIAG_DEST . "/" . $tracefile;
    if (-r $file) {
      my $fsize_bytes = -s $file;
      my $fsize_mb = pround($fsize_bytes / (1024 * 1024), -1);
      print "Size of file is: $fsize_mb MB ($fsize_bytes Bytes).\n";
      # Do nothing if file is less than defined minimum.
      if ($fsize_mb <= $greater_than) { next }

      my $DT = datetimestamp();
      # 2016-02-09_114317

      my $new_name = "$file.$DT";
      print "Rename $file to: $new_name\n";

      if ( ! rename($file, $new_name) ) {
        output_error_message(sub_name() . ": Error: Cannot rename file $file.");
        next;
      } else {

        print "Command: $compress_cmd $new_name\n";
        system("$compress_cmd $new_name");
        if ( $? == -1 ) {
          output_error_message(sub_name() . ": Error: The command failed: $!");
          next;
        } else {
          print "The command exited with value: ", $? >> 8, "\n";
        }

        # Remove old compressed files
        rm_old_files($file);

      } # if rename
    } # if -r file

  } # foreach

  return(0);

} # rotate_logs



# -------------------------------------------------------------------
sub adrci_purge {

  # echo "INFO: adrci purge started at `date`"
  # adrci exec="show homes"|grep -v : | while read file_line
  # do
  # purge -age 10080  # hours
  # done

  title(sub_name());

  my $default_keep_for_days = 60;

  my $keep_for_days = $CFG{"ORA_HOUSEKEEPING.KEEP_ADR_FOR"} || $default_keep_for_days;
  if ( $keep_for_days !~ /\d+/ ) {
    output_error_message(sub_name() . ": Error: The parameter KEEP_ADR_FOR is not numeric in the configuration file! The default value of $default_keep_for_days is used.");
    $keep_for_days = $default_keep_for_days;
  }
  print "Keeping the audit entries for: $keep_for_days days.\n";

  my $keep_for_mins = $keep_for_days * 24 * 60;
  print "Keeping the audit entries for: $keep_for_mins minutes.\n";

  my $cmd = "adrci exec=\"set base $DIAG_DEST; show homes\" 2>&1";
  print "cmd: $cmd\n";

  my @adr_homes = `$cmd`;
  if ( $? == -1 ) {
    output_error_message(sub_name() . ": Error: The command failed: $!");
  } else {
    print "The command exited with value: ", $? >> 8, "\n";
  }

  foreach my $adr_home (@adr_homes) {
    chomp($adr_home);

    # First line is a title
    # ADR Homes:
    if ($adr_home =~ /:/) {next;}

    print "\n";
    print "Purging ADR home: $adr_home\n";

    $cmd = "adrci exec=\"set base $DIAG_DEST; set homepath $adr_home; purge -age $keep_for_mins\" 2>&1";
    print "cmd: $cmd\n";

    my $out = `$cmd`;
    if ( $? == -1 ) {
      output_error_message(sub_name() . ": Error: The command failed: $!");
    } else {
      print "The command exited with value: ", $? >> 8, "\n";
    }

    print "$out\n";

  } # foreach

  print "\n";

  return(0);

} # adrci_purge



# -------------------------------------------------------------------


# ===================================================================
# main
# ===================================================================
#
# initial customization, no output should happen before this.
# The environment must be set up already.

# $CURRPROG = basename($0, ".pl");   # extension is removed
$CURRPROG = basename($0);
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

# -------------------------------------------------------------------
# Get configuration file contents

my $cfgfile = $ARGV[0];
print "configuration file=$cfgfile\n";

my @Sections = ( "GENERAL", "ORACLE", "ULS", "ORA_HOUSEKEEPING" );
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

show_hash(\%CFG, "=");
print "-----\n\n";

# ----------
# This sets the %ULS to all necessary values
# deriving from %CFG (configuration file),
# environment variables (ULS_*) and defaults.

uls_settings(\%ULS, \%CFG);

show_hash(\%ULS);

# ----------
# Check for IDENTIFIER

# Set default
my $default_identifier = "_" . basename($0, ".pl");
$IDENTIFIER = $CFG{"ORA_HOUSEKEEPING.IDENTIFIER"} || $default_identifier;
print "IDENTIFIER=$IDENTIFIER\n";
# From here on, you may use $IDENTIFIER for uniqueness

# -------------------------------------------------------------------
# environment

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

# Prefix for work files
$WORKFILEPREFIX = "${IDENTIFIER}";
# _ora_housekeeping
#
# If no oracle sid is found in the workfile prefix, then add it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _ora_housekeeping_orcl
#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /oracle/admin/orcl/oracle_tools/var/_ora_housekeeping_orcl

print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

# -------------------------------------------------------------------
# Setting up a lock file to prevent more than one instance of this
# script starting simultaneously.

$LOCKFILE = "${WORKFILEPREFIX}.LOCK";
print "LOCKFILE=$LOCKFILE\n";

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

  # Read the directory
  opendir(INITDIR, $initdir);
  my @files = grep(/$CURRPROG.*\.tmp/, map("$initdir/$_", readdir(INITDIR)));
  closedir(INITDIR);

  # Remove old .tmp files
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
$d =~ s/\d{1}$/0/;

set_uls_timestamp($d);

# The section will be dynamically changed for PDBs
# (if any are present)
my $uls_section = "";

# uls_show();

# ---- Send name of this script and its version
# uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

# Signal handling, do own housekeeping, send data to ULS and exit on most signals.
use sigtrap 'handler' => \&signal_handler, 'normal-signals', 'error-signals';

uls_timing({
    teststep  => $IDENTIFIER
  , detail    => "start-stop"
  , start     => iso_datetime($start_secs)
});

# Send the ULS data up to now to have that for sure.
uls_flush(\%ULS);

# -----
# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
print "TMPOUT1=$TMPOUT1\n";
# $TMPOUT2 = "${WORKFILEPREFIX}_2.tmp";
# print "TMPOUT2=$TMPOUT2\n";

print "DELIM=$DELIM\n";

# -----
# sqlplus command

# Check, if the sqlplus command has been redefined in the configuration file.
$SQLPLUS_COMMAND = $CFG{"ORACLE.SQLPLUS_COMMAND"} || $SQLPLUS_COMMAND;

# -----
# Set the documentation from behind __END__.
# De-reference the return value to the complete hash.
%TESTSTEP_DOC = %{doc2hash(\*DATA)};


# -------------------------------------------------------------------
# The real work starts here.
# ------------------------------------------------------------

if (! oracle_available() ) {
  output_error_message("$CURRPROG: Error: Oracle database is not available => aborting script.");

  clean_up($TMPOUT1, $LOCKFILE);

  send_runtime($start_secs);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  exit(1);
}

$DIAG_DEST = diagnostic_dest();
if ( ! $DIAG_DEST ) {
  output_error_message("$CURRPROG: Error: diagnostic_dest cannot be determined => aborting script.");

  clean_up($TMPOUT1, $LOCKFILE);

  send_runtime($start_secs);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  exit(1);
}

my @wday = qw/Monday Tuesday Wednesday Thursday Friday Saturday Sunday/;
my $day_of_week = $wday[ (localtime(time))[6] - 1 ];

# if ($day_of_week =~ /SUNDAY/i) {
  rotate_logs();
# }

adrci_purge();

purge_audit_entries();

init_cleanup();

purge_unified_audit_entries();

# CDB/PDB

if ($#PDB_LIST >= 0) {
  # Remember: $#ARRAY returns the max index of the array, which starts at zero!

  title("Database Instance is a CDB and has PDBs");

  print "List of PDBs and CON_IDs: ", join(",", @PDB_LIST), "\n";

  foreach my $p (@PDB_LIST ) {
    ($CURRENT_PDB, $CURRENT_CON_ID) = split('\|', $p);

    title("PDB: $CURRENT_PDB");

    print "p=$p, CURRENT_PDB=$CURRENT_PDB, CURRENT_CON_ID=$CURRENT_CON_ID\n";
    my $pdb_lc = lc($CURRENT_PDB);

    # $uls_section = $CFG{"ULS.ULS_SECTION_PDB"} ;
    # ULS_SECTION_PDB = Oracle DB [%%ORACLE_SID%% -> __PDB_NAME__]
    # vi /etc/uls/oracle/standard.conf

    # $uls_section =~ s/__PDB_NAME__/$pdb_lc/g;

    # print "Setting ULS_SECTION to: $uls_section\n";

    # set_uls_section($uls_section);

    init_cleanup();

    purge_unified_audit_entries();

  } # foreach

} # has pdbs


# -----
# Continue here with more tests.

# The real work ends here.
# -------------------------------------------------------------------

# Any errors will have sent already its error messages.
# This is just the final message.
uls_value($IDENTIFIER, "message", $MSG, " ");
# uls_value($IDENTIFIER, "exit value", $EXIT_VALUE, "#");

send_doc($CURRPROG, $IDENTIFIER);

send_runtime($start_secs);
uls_timing($IDENTIFIER, "start-stop", "stop");

# Do not transfer to ULS
# uls_flush(\%ULS, 1);
#
# Transfer to ULS
uls_flush(\%ULS);

# -------------------------------------------------------------------
# clean_up($TMPOUT1, $TMPOUT2, $LOCKFILE);
clean_up($TMPOUT1, $LOCKFILE);

title("END");

if ($MSG eq "OK") {exit(0)}

exit(1);


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
#
# Do not use the '\' but use '\\'!

#########################
*ora_housekeeping.pl
=====================

This script sets the timestamp for the oldest audit entry to keep (last_archive_time) and purges all audit entries that are older than that timestamp. By default, Oracle does not have a built-in mechanism for that.

This script is part of the Oracle OpTools and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org

This script is run by a calling script, typically 'ora_housekeeping', that sets the correct environment before starting the Perl script ora_housekeeping.pl. The 'ora_housekeeping' in turn is called by the cron daemon on Un*x or through a scheduled task on Wind*ws. The script generates a log file. The directory defined by WORKING_DIR in the oracle_tools.conf configuration file is used as the destination for those files.

You may place the scripts in whatever directory you like.

script name, version:
  Sends the name and the current version of this script.

start-stop:
  The start and stop timestamps for the script.

message:
  If the script runs fine, it returns 'OK', else an error message.
  This is intended to monitor the proper execution of this script.

runtime:
  The runtime of the script. This does not include the transmission
  to the ULS.

# exit value:
#   Is 0 if the script has finished without errors,
#   1 if errors have occurred. This is intended to monitor the
#   proper execution of this script.
# 

Copyright 2016 - 2021, roveda

This file is part of Oracle OpTools.

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

