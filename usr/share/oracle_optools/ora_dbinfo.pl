#!/usr/bin/perl
#
#   ora_dbinfo.pl - collect information about an Oracle database instance
#
# ---------------------------------------------------------
# Copyright 2011 - 2022, roveda
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
#   perl ora_dbinfo.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script gathers a lot of information about an Oracle database
#   instance and builds an html report, which is sent to the ULS.
#
#   A csv file with the major information about Oracle's version, 
#   installed components and used features is sent as an inventory
#   file.
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
#   Information about Oracle RAC is currently not implemented.
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   HtmlDocument.pm
#   uls-client-2.0-1 or later
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
# 2010-12-22      roveda      0.01
#
# 2011-01-04      roveda      0.02
#   Added AS_VALUE.
#
# 2011-11-11      roveda      0.03
#   Added the GPL. Added the DBID. Added the list of installed options.
#   Database Links are probably vulnerable!?
#
# 2012-09-07      roveda      0.04
#   Added an inventory with version, instance name and components
#   in csv format (inventory-oracle-<hostname>.csv)
#
# 2013-01-20      roveda      0.05
#   Added ORACLEOPTIONUSAGE and ORACLEPATCH to inventory output.
#
# 2013-04-27      roveda      0.06
#   Got some problems with long strings selected from v$parameter,
#   now using rtrim() and linesize 32000, that works correctly.
#   Added 'is default' to parameter output.
#
# 2013-06-23      roveda      0.07
#   Added ENCRYPTED for tablespace information.
#
# 2013-08-17      roveda      0.08
#   Modifications to match the new single configuration file.
#   Added compression information for tablespaces.
#
# 2013-09-28      roveda      0.09
#   Added nls_instance_parameters.
#
# 2014-04-03      roveda      0.10
#   Changed "Database ID" to "DBID", to find it better.
#
# 2015-02-14      roveda      0.11
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#
# 2015-04-19      roveda      0.12
#   Introduced single variables for the Oracle version.
#   Backported the tablespace and datafile information to 10.2.
#
# 2015-06-20      roveda      0.13
#   Changed the parameter list in part_1(), now selecting the
#   display_name from v$parameter2.
#
# 2015-09-20      roveda      0.14
#   Added patch information from registry$history.
#
# 2015-12-15      roveda      0.15
#   Implemented the latest version of options_packs_usage_statistics.sql (MOS Note 1317265.1)
#   The output is changed! Only for Oracle 11g.
#   There was always one file for a server, not for each instance.
#   Added the SID to the file name.
#
# 2016-02-01      roveda      0.16
#   Implemented the latest version of options_packs_usage_statistics.sql (MOS Note 1317265.1)
#   For Oracle 12c.
#
# 2016-02-03      roveda      0.17
#   Removed detailed feature usage from inventory.
#
# 2016-02-22      roveda      0.18
#   The report is now sent as an (probably compressed) html file.
#
# 2016-03-09      roveda      0.19
#   The "exit value" is no longer sent to ULS.
#
# 2016-03-18      roveda      0.20
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.21
#   Added the SID to the WORKFILEPREFIX.
#
# 2016-06-09      roveda      0.22
#   Added the DBID to the inventory output.
#
# 2017-01-03      roveda      0.23
#   Added the output of V$NLS_PARAMETERS.
#
# 2017-01-11      roveda      0.24
#   Removed the V$NLS_PARAMETERS, they reflect the current settings of the session.
#   Added some HTML styles. Merged "Database Settings" with "General Info".
#   Added the DBENGINE, DBVERSION, DBINSTANCE, DBHOST and DBINSTANCEIP inventory values.
#   Changed the name of the output file to inventory-database-...
#   The name for the server doc now contains the ORACLE_SID to distinguish
#   multiple instances on one server.
#
# 2017-02-02      roveda      0.25
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.26
#   Added signal handling.
#   Added the last modification timestamp for files.
#
# 2017-03-21      roveda      0.27
#   Fixed the broken support of sid specific configuration file.
#
# 2017-04-04      roveda      0.28
#   Merged the NLS parameters into one table.
#
# 2017-07-07      roveda      0.29
#   Instead of a script result message as a sequence of single string lines
#   a message file is created and finally compressed and sent to ULS but 
#   only if an error has occured.
#   Retrieving the IP address and the port from the output of tnsping <sid>.
#
# 2017-08-18      roveda      0.30
#   Use now the Oracle sql script options_packs_usage_statistics.sql as delivered.
#   The content is textually extracted from the generated text file.
#   That should result in less maintenance work for this script.
#   REMEMBER: the path of the spool file must be changed in the options_packs_usage_statistics.sql script!
#
# 2017-09-19      roveda      0.31
#   Debugged multitenant_info(), feature_usage_details11_2_0_4() and product_usage11_2_0_4() 
#   to even work the first time it is ever executed.
#
# 2018-03-08      roveda      0.32
#   Added one more pipe character to each line of the options_packs_usage_statistics output.
#   The resulting tables will be complete in means of empty cells. 
#
# 2018-03-14      roveda      0.33
#   Added security_settings(), currently for Unified Auditing.
#
# 2018-03-28      roveda      0.34
#   Added FORCE_LOGGING for database and for tablespace.
#
# 2018-06-06      roveda      0.35
#   Added incarnation information.
#
# 2018-08-01      roveda      0.36
#   Added BIGFILE info for tablespaces.
#
# 2019-07-13      roveda      0.37
#   No execution and no error when running as physical standby.
#
# 2019-10-15      roveda      0.38
#   Added stat_prefs() which contains information about the global 
#   optimizer statistics preferences which are used in the job
#   'auto optimizer stats collection'.
#
# 2020-03-20      roveda      0.39
#   Added informational text in part_2(), parameter section, especially for Oracle 12.2.
#
# 2020-09-21      roveda      0.40
#   Get the full version (e.g. 19.7.0.0) for Oracle 19.
#   Conditional execution for Oracle 19 in security_settings(), 
#   the structure of AUDIT_UNIFIED_ENABLED_POLICIES has changed.
#
# 2020-09-23      roveda      0.41
#   Double use of 'my $sql' corrected.
#
# 2020-10-21      roveda      0.42
#   Added support for multitenant (pluggable) databases.
#
# 2020-11-03      roveda      0.43
#   Chaged "Oracle Version" to "Oracle Full Version" for PDBs.
#
# 2020-11-11      roveda      0.44
#   In Oracle 12.1 there is no column CREATION_TIME in dba_pdbs, 
#   multitenant_info() changed accordingly.
#
# 2020-12-14      roveda      0.45
#   Multitenant information is now 12.1.0.1 safe, and a text is added 
#   to the report when no pluggable database is found (instead of an empty table).
#
# 2021-03-17      roveda      0.46
#   Identifying if the database is a CDB fixed in part_1().
#   It was constantly 'YES'.
#
# 2021-06-03      roveda      0.47
#   Added a list of all defined services for the cdb or, if present, for all pdbs.
#   If the tnsnames.ora file contains IFILE entries, then these referenced files 
#   are also appended to the report.
#
# 2021-10-06      roveda      0.48
#   Removed the transfer of inventory data to ULS (sendinventory2uls) as the used format 
#   may not be useful for customer environments.
#
# 2021-11-27      roveda      0.49
#   Added full UTF-8 support. Thanks for the boilerplate
#   https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129
#
# 2021-12-09      roveda      0.50
#   Moved 'set feedback off' to beginning of sql command in exec_sql()
#   and added more NLS settings.
#
# 2022-03-28      roveda      0.51
#   Added online_status in datafiles(), table heading is adjusted 
#   depending on the processed file types (data / temp).
#
# 2022-03-31      roveda      0.52
#   Omit some PDB information if it is a standby PDB (the CDB is a standby)
#
# 2022-05-07      roveda      0.53
#   Added COMP_ID to the list of components.
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
use HtmlDocument;

my $VERSION = 0.53;

# ===================================================================
# The "global" variables
# ===================================================================

# Name of this script.
my $CURRPROG = "";
# Timestamp of script start is seconds
my $STARTSECS = time;

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';

# SQL script from Oracle support to gather option pack usages
my $OPUSSQL = dirname($0) . "/options_packs_usage_statistics.sql";

# Keeps the list of temporary files, to be purged at script end
# push filenames onto this array.
my @TEMPFILES;

my $WORKFILEPREFIX;
my $TMPOUT1;
my $TMPOUT2;
my $HTMLOUT1;
my $LOCKFILE;
my $ERROUTFILE;

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

# This is to indicate "not available":
my $NA = "n/a";

# Use this to test for (nearly) zero:
my $VERY_SMALL = 1E-60;

# Text expression for not applicable, n/a, unknown or undefined:
$NA = "unknown";

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

my ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO);

# Database role (PRIMARY/PHYSICAL STANDBY)
my $ORACLE_DBROLE = "";
# Database status (OPEN/MOUNTED)
my $ORACLE_DBSTATUS = "";

# Data Guard Role
my $DG_ROLE = "NONE";

# Keeps the list of all present pdbs (for the current cdb)
my @PDB_LIST = ();

# Holds the current pdb name (of @PDB_LIST)
my $CURRENT_PDB = "";
my $CURRENT_CON_ID = -1;

# Status of the current PDB
my $PDB_STATUS = "";

# -----
# This keeps the complete report (as html)
my $HtmlReport = HtmlDocument->new();

# Set the default css styles, see the appropriate section in the 
# conf file to adjust the style to your taste.

$HtmlReport->set_style("
  table {
      border-collapse: collapse;
      border: 1px solid darkgrey;
      margin-top: 5px;
  }
  th, td {
      border: 1px solid darkgrey;
      padding: 5px;
  }
  th { background-color: #dbe4f0; }
  pre  {background-color: whitesmoke; }
");

# my $REPORT = "";


# That keeps the inventory data
my $INVENTORY = "";

# The hostname where this script runs on
my $MY_HOST = "";



# ===================================================================
# The subroutines
# ===================================================================

# ------------------------------------------------------------
sub signal_handler {
  # first parameter is the signal, like HUP INT QUIT ABRT ALRM TERM.

  title(sub_name());

  $MSG = "SIGNAL " . $_[0];

  output_error_message("$CURRPROG: Signal $_[0] catched! Clean up and abort script.");

  end_script(9);
}


# ------------------------------------------------------------
sub end_script {
  # end_script(<exit_value>);

  uls_value($IDENTIFIER, "message", $MSG, " ");

  # -----
  # Is there an error message file?
  if (-r $ERROUTFILE ) {

    my $uls_filename = "error_message_file.log";

    # Try to compress the file.
    if (my $new_ext = try_to_compress($ERROUTFILE)) {
      $ERROUTFILE .= $new_ext;
      $uls_filename .= $new_ext;
    }

    # Send the error message file
    uls_file({
      teststep  => "$IDENTIFIER"
     ,detail    => "error message file"
     ,filename  => $ERROUTFILE
     ,rename_to => $uls_filename
    });

  }

  # -----
  # The following errors are lost!
  # But the output_error_message() is not used there anyway.

  send_runtime($STARTSECS);
  uls_timing($IDENTIFIER, "start-stop", "stop");

  uls_flush(\%ULS);

  clean_up(@TEMPFILES);

  exit($_[0]);

} # end_script



# ------------------------------------------------------------
sub output_error_message {
  # output_error_message(<message>)
  #
  # Send the given message(s), set the $MSG variable and
  # print out the message to STDERR and to an error message file.

  $MSG = "ERROR";

  foreach my $msg (@_) { print STDERR "$msg\n" }
  # foreach my $msg (@_) { uls_value($IDENTIFIER, "message", $msg, " ") }

  # Write all error messages to a file.
  my $erroutfile;
  if (! open($erroutfile, ">>:utf8", $ERROUTFILE)) {
    print STDERR sub_name() . ": Error: Cannot open '$ERROUTFILE' for writing!\n";
    return(1);
  }

  foreach my $msg (@_) { print $erroutfile "$msg\n" }

  # Close file
  if (! close($erroutfile)) {
    print STDERR sub_name() . ": Error: Cannot close '$ERROUTFILE'!\n";
    return(1);
  }

  return(0);

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
    if ($L =~ /SP2-\d{4,}/i) {
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
sub print_file {
  my $f = $_[0];

  if (open(F, $f)) {
    while(my $Line = <F>) {
      chomp($Line);
      print "[" . $Line . "]\n";
    }
  }
  close(F);

} # print_file



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

    spool $TMPOUT1;

    $_[0]

    spool off;
  ";

  print "----- SQL -----\n$sql\n---------------\n\n";

  print "----- result -----\n";

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
      # uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
      appendfile2file($TMPOUT1, $ERROUTFILE);
      return(0);
    }
    # Ok
    return(1);
  }

  output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
  # uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
  appendfile2file($TMPOUT1, $ERROUTFILE);

  return(0);

} # do_sql



# -------------------------------------------------------------------
sub clean_up {
  # clean_up()
  #
  # Remove all left over files at script end.

  title("Cleaning up");

  my @files = @_;

  foreach my $f (@files) {
    # Remove the file.
    if (-e $f) {
      print "Removing file '$f' ...";
      if (unlink($f)) {print "Done.\n"}
      else {print STDERR "Removing of file '$f' has failed! $!\n"}
    }
  }

} # clean_up


# -------------------------------------------------------------------
sub send_runtime {
  # The runtime of this script
  # send_runtime(<start_secs> [, {"s"|"m"|"h"}]);

  # Current time minus start time.
  my $rt = time - $_[0];

  my $unit =  "S";
  if ( $_[1] ) { $unit = uc($_[1]) }

  if    ($unit eq "M") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0, -1), "min") }
  elsif ($unit eq "H") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0 / 60.0, -2), "h") }
  else                 { uls_value($IDENTIFIER, "runtime", pround($rt, 0), "s") }


} # send_runtime



# -------------------------------------------------------------------
sub append2inventory {
  # append2inventory(<key>, <value1>, <value2>, ...)

  # The resulting line is:
  # <key>;<value1>;<value2>;...

  my $Line = uc(shift);

  # while ( my $t = shift ) {
  #   $Line .= ";" . $t
  # }

  while (@_) {
    $Line .= ";" . shift;
  }
  # print "$Line\n";

  if ($INVENTORY) { $INVENTORY .= "\n" }
  $INVENTORY .= $Line;

} # append2inventory



# -------------------------------------------------------------------
sub get_instance_ip {

  # Use the $ORACLE_SID for a:
  # tnsping $ORACLE_SID
  # parse the output for the hostname or ip address:
  # ...(PROTOCOL = TCP)(HOST = 10.20.30.40)(PORT = 1234))) ...

  my $tnsping = `tnsping $ENV{ORACLE_SID}`;
  print "[$tnsping]\n";

  # \s whitespace
  # \S non-whitespace
  $tnsping =~ /\(HOST\s*=\s*(\S+?)\s*\)/;
  my $host = $1;

  # nothing found
  if (! $host) {
    print "No HOST parameter found in tnsping output!\n";
    return(undef);
  }

  # Is it an ip already?
  # Check for digits at the beginning.
  if ($host =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) { return($host) }

  # Assume it is a hostname, must get ip:
  # (may not work on all flavours of Unix)
  print "Must resolve hostname to ip address.\n";

  my $ip = `gethostip -d $host`;
  chomp($ip);
  if ( $ip =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) { return($ip) }

  print "No valid ip address found!\n";
  return(undef);

} # get_instance_ip



# -------------------------------------------------------------------
sub get_instance_port {

  # Use the $ORACLE_SID for a:
  # tnsping $ORACLE_SID
  # parse the output for the hostname or ip address:
  # ...(PROTOCOL = TCP)(HOST = 10.20.30.40)(PORT = 1234))) ...

  my $tnsping = `tnsping $ENV{ORACLE_SID}`;
  print "[$tnsping]\n";

  # \s whitespace
  # \S non-whitespace
  $tnsping =~ /\(PORT\s*=\s*(\S+?)\s*\)/;
  my $port = $1;

  # nothing found
  if (! $port) {
    print "No PORT parameter found in tnsping output!\n";
    return(undef);
  }

  # Is it a port?
  # Check for digits at the beginning.
  if ($port =~ /\d{1,5}/) { return($port) }

  print "No valid port number found!\n";
  return(undef);

} # get_instance_port




# ===================================================================

# -------------------------------------------------------------------
sub oracle_3d_version {
  # oracle_3d_version([<number_of_elements>]);

  my $elements = 4;
  if ($_[0]) { $elements = $_[0] }

  if ($elements < 1 || $elements > 5) {
    print STDERR "sub_name(): Error: Parameter may only be from 1 to 5, not: $elements!\n";
    return(undef);
  }

  my @E;

  if ($elements >= 1) { push(@E, $ORA_MAJOR_RELNO)       }
  if ($elements >= 2) { push(@E, $ORA_MAINTENANCE_RELNO) }
  if ($elements >= 3) { push(@E, $ORA_APPSERVER_RELNO)   }
  if ($elements >= 4) { push(@E, $ORA_COMPONENT_RELNO)   }
  if ($elements >= 5) { push(@E, $ORA_PLATFORM_RELNO)    }

  @E = map(sprintf("%03d", $_), @E);
  return(join(".", @E));

} # oracle_3d_version


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

  return(1);

} # oracle_available



# -------------------------------------------------------------------
sub option_usage {

  # 11.2.0.2.0
  # This is currently only matching Oracle version 11.2
  # Use the features instead for earlier Oracle versions.
  # 
  # NOTE: there is a newer version of this sub for 11.2.0.4 and for 12.1+, see below.
  #

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_heading(2, "Option Usage", "_default_");
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");
    return 0
  }

  # if ( $ORACLE_VERSION !~ /^11\.2/ ) { return 0 }
  if ( $ORA_MAJOR_RELNO < 11 ) { 
    $HtmlReport->add_heading(2, "Option Usage", "_default_");
    $HtmlReport->add_paragraph('p', "Not supported for this Oracle version!");
    $HtmlReport->add_goto_top("top");
    return 0 
  }

  title(sub_name());

  # -----
  # installed options
  #
  # see
  # Oracle Database Licensing Information
  # 11g Release 2 (11.2)
  # Part Number E10594-26
  # http://docs.oracle.com/cd/E11882_01/license.112/e10594/options.htm
  #
  # The query is based on the option_usage.sql script which can
  # be downloaded at My Oracle Support, Document ID 1317265.1
  #
  # It is a bit lengthy...
  #
  # NOTE: Spatial cannot be checked correctly because the usage is always
  #       incremented, even for the Locator which is free to use.
  #
  # The result looks like:
  #
  # Option/Management Pack                             !Use!ReportGen Time
  # ---------------------------------------------------!---!-------------------
  # Tuning  Pack                                       !YES!2013-01-25 08:31:22
  # Active Data Guard                                  !NO !2013-01-25 08:31:22
  # Advanced Compression                               !NO !2013-01-25 08:31:22
  # Advanced Security                                  !NO !2013-01-25 08:31:22
  # Change Management Pack                             !NO !2013-01-25 08:31:22
  # Configuration Management Pack for Oracle Database  !NO !2013-01-25 08:31:22
  # Data Masking Pack                                  !NO !2013-01-25 08:31:22
  # Data Mining                                        !NO !2013-01-25 08:31:22
  # Database Vault                                     !NO !2013-01-25 08:31:22
  # Diagnostic Pack                                    !NO !2013-01-25 08:31:22
  # Exadata                                            !NO !2013-01-25 08:31:22
  # Label Security                                     !NO !2013-01-25 08:31:22
  # OLAP                                               !NO !2013-01-25 08:31:22
  # Partitioning                                       !NO !2013-01-25 08:31:22
  # Provisioning and Patch Automation Pack             !NO !2013-01-25 08:31:22
  # Provisioning and Patch Automation Pack for Database!NO !2013-01-25 08:31:22
  # Real Application Clusters                          !NO !2013-01-25 08:31:22
  # Real Application Testing                           !NO !2013-01-25 08:31:22
  # Spatial                                            !NO !2013-01-25 08:31:22
  # Total Recall                                       !NO !2013-01-25 08:31:22
  # WebLogic Server Management Pack Enterprise Edition !NO !2013-01-25 08:31:22
  #
  # NOTE: Only the used options will make it to the inventory!


  my $sql = "
    with features as(
      select a OPTIONS, b NAME  from (
        select 'Active Data Guard' a,  'Active Data Guard - Real-Time Query on Physical Standby' b from dual
        union all
        select 'Advanced Compression', 'HeapCompression' from dual
        union all
        select 'Advanced Compression', 'Backup BZIP2 Compression' from dual
        union all
        select 'Advanced Compression', 'Backup DEFAULT Compression' from dual
        union all
        select 'Advanced Compression', 'Backup HIGH Compression' from dual
        union all
        select 'Advanced Compression', 'Backup LOW Compression' from dual
        union all
        select 'Advanced Compression', 'Backup MEDIUM Compression' from dual
        union all
        select 'Advanced Compression', 'Backup ZLIB, Compression' from dual
        union all
        select 'Advanced Compression', 'SecureFile Compression (user)' from dual
        union all
        select 'Advanced Compression', 'SecureFile Deduplication (user)' from dual
        union all
        select 'Advanced Compression', 'Data Guard' from dual
        union all
        select 'Advanced Compression', 'Oracle Utility Datapump (Export)' from dual
        union all
        select 'Advanced Compression', 'Oracle Utility Datapump (Import)' from dual
        union all
        select 'Advanced Security',    'ASO native encryption and checksumming' from dual
        union all
        select 'Advanced Security',    'Transparent Data Encryption' from dual
        union all
        select 'Advanced Security',    'Encrypted Tablespaces' from dual
        union all
        select 'Advanced Security',    'Backup Encryption' from dual
        union all
        select 'Advanced Security',    'SecureFile Encryption (user)' from dual
        union all
        select 'Change Management Pack', 'Change Management Pack (GC)' from dual
        union all
        select 'Data Masking Pack',     'Data Masking Pack (GC)' from dual
        union all
        select 'Data Mining',           'Data Mining' from dual
        union all
        select 'Diagnostic Pack',       'Diagnostic Pack' from dual
        union all
        select 'Diagnostic Pack',       'ADDM' from dual
        union all
        select 'Diagnostic Pack',       'AWR Baseline' from dual
        union all
        select 'Diagnostic Pack',       'AWR Baseline Template' from dual
        union all
        select 'Diagnostic Pack',       'AWR Report' from dual
        union all
        select 'Diagnostic Pack',       'Baseline Adaptive Thresholds' from dual
        union all
        select 'Diagnostic Pack',       'Baseline Static Computations' from dual
        union all
        select 'Tuning  Pack',          'Tuning Pack' from dual
        union all
        select 'Tuning  Pack',          'Real-Time SQL Monitoring' from dual
        union all
        select 'Tuning  Pack',          'SQL Tuning Advisor' from dual
        union all
        select 'Tuning  Pack',          'SQL Access Advisor' from dual
        union all
        select 'Tuning  Pack',          'SQL Profile' from dual
        union all
        select 'Tuning  Pack',          'Automatic SQL Tuning Advisor' from dual
        union all
        select 'Database Vault',        'Oracle Database Vault' from dual
        union all
        select 'WebLogic Server Management Pack Enterprise Edition',    'EM AS Provisioning and Patch Automation (GC)' from dual
        union all
        select 'Configuration Management Pack for Oracle Database',     'EM Config Management Pack (GC)' from dual
        union all
        select 'Provisioning and Patch Automation Pack for Database',   'EM Database Provisioning and Patch Automation (GC)' from dual
        union all
        select 'Provisioning and Patch Automation Pack',        'EM Standalone Provisioning and Patch Automation Pack (GC)' from dual
        union all
        select 'Exadata',               'Exadata' from dual
        union all
        select 'Label Security',        'Label Security' from dual
        union all
        select 'OLAP',                  'OLAP - Analytic Workspaces' from dual
        union all
        select 'Partitioning',          'Partitioning (user)' from dual
        union all
        select 'Real Application Clusters',  'Real Application Clusters (RAC)' from dual
        union all
        select 'Real Application Testing',   'Database Replay: Workload Capture' from dual
        union all
        select 'Real Application Testing',   'Database Replay: Workload Replay' from dual
        union all
        select 'Real Application Testing',   'SQL Performance Analyzer' from dual
        union all
        select 'Spatial',        'Spatial (Not used because this does not differential usage of spatial over locator, which is free)' from dual
        union all
        select 'Total Recall',   'Flashback Data Archive' from dual
      )  -- select
    )    -- with
    select
         t.o \"Option/Management Pack\"
       , t.u \"Used\"
       -- ,d.DBID   \"DBID\"
       -- ,d.name   \"DB Name\"
       -- ,i.version  \"DB Version\"
       -- ,i.host_name  \"Host Name\"
       -- ,to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') \"ReportGen Time\"
    from (
      select OPTIONS o, DECODE(sum(num),0,'NO','YES') u
      from (
        select f.OPTIONS OPTIONS, case
          when f_stat.name is null then 0
          when (
            (f_stat.currently_used = 'TRUE' and
             f_stat.detected_usages > 0 and
             (sysdate - f_stat.last_usage_date) < 366 and
             f_stat.total_samples > 0)
            or
             (f_stat.detected_usages > 0 and (sysdate - f_stat.last_usage_date) < 366 and f_stat.total_samples > 0)
          ) and (
            f_stat.name not in('Data Guard', 'Oracle Utility Datapump (Export)', 'Oracle Utility Datapump (Import)')
            or
            (f_stat.name in('Data Guard', 'Oracle Utility Datapump (Export)', 'Oracle Utility Datapump (Import)') and
             f_stat.feature_info is not null and trim(substr(to_char(feature_info), instr(to_char(feature_info), 'compression used: ',1,1) + 18, 2)) != '0')
          )
          then 1
          else 0
         end num
        from features f, sys.dba_feature_usage_statistics f_stat
        where f.name = f_stat.name(+)
      ) group by options
    ) t, v\$instance i, v\$database d
    order by 2 desc,1
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @O = ();
  get_value_lines(\@O, $TMPOUT1);

  # - options
  foreach my $i (@O) {
    my @E = split($DELIM, $i);
    @E = map(trim($_), @E);

    if ( uc($E[1]) eq "YES" ) {
      # Only USED options are reported in the inventory
      append2inventory("ORACLEOPTIONUSAGE", $E[0]);
    }
  }

  # - report

  # prepend a title line
  unshift(@O, "Option/Management Pack  $DELIM  Use ");

  $HtmlReport->add_heading(2, "Option Usage", "_default_");
  $HtmlReport->add_table(\@O, $DELIM, "LL", 1);
  $HtmlReport->add_goto_top("top");

  return(1);

} # option_usage


# -------------------------------------------------------------------
sub multitenant_info {
  # Multitenant information.
  # see options_packs_usage_statistics.sql, MOS Note 1317265.1
  # For: Oracle Database - Version 11.2 and later

  my $sql = "";
  my $title_line = "CON_ID  $DELIM  PDB_NAME  $DELIM  CREATION_TIME  $DELIM  STATUS";

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_heading(2, "Multitenant Information", "_default_");
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");
    return(1);
  }

  my $ora3dversion = oracle_3d_version(4);

  if ($ora3dversion lt "012.001.000.002") {
    # 12.1.0.1 only
    # Has column 'pdb_id' (but not 'con_id').
    # Has column CREATION_SCN (but not 'CREATION_TIME').

    $sql = "select pdb_id, pdb_name
           , creation_scn
           , status from dba_pdbs order by pdb_id;"
    ;

    $title_line = "PDB_ID  $DELIM  PDB_NAME  $DELIM  CREATION_SCN  $DELIM  STATUS";

  } elsif ($ora3dversion lt "012.002.000.000") {
    # 12.1.0.2
    # Has column 'con_id'.
    # Has column CREATION_SCN (but not 'CREATION_TIME').

    $sql = "select con_id, pdb_name
           , creation_scn
           , status from dba_pdbs order by con_id;"
    ;

    $title_line = "CON_ID  $DELIM  PDB_NAME  $DELIM  CREATION_SCN  $DELIM  STATUS";

  } else {
    # 18, 19
    # Has column 'con_id'.
    # Has column 'CREATION_TIME'.

    $sql = "select con_id, pdb_name
           , to_char(creation_time, 'yyyy-mm-dd HH24:MI:SS')
           , status from dba_pdbs order by con_id;"
    ;
  }

  if (! do_sql($sql)) {return(0)}

  my @L = ();
  get_value_lines(\@L, $TMPOUT1);

  $HtmlReport->add_heading(2, "Multitenant Information", "_default_");

  if ( $#L >= 0 ) {
    # Has found pluggable databases

    # Prepend the title line
    unshift(@L, $title_line);

    # Add the pluggable databases list
    $HtmlReport->add_table(\@L, $DELIM, "LLLL", 1);

  } else {
    # No pluggable databases found
    $HtmlReport->add_paragraph('p', "This database instance has no pluggable databases.");
  }

  $HtmlReport->add_goto_top("top");

  return(1);

} # multitenant_info


# -------------------------------------------------------------------
sub feature_usage_details11_2_0_4 {
  # This sub is specially prepared for Oracle 11.2.0.4 and later, older versions are NOT correctly gathered.
  # See MOS Note 1317265.1 for further information (since Aug 2015).
  #
  # -----------------------------------------------------------------------
  # QUOTATION: 
  #   This information is to be used for informational purposes only and
  #   this does not represent your license entitlement or requirement.
  # -----------------------------------------------------------------------
  #

  title(sub_name());

  my $opusfile = "/tmp/options_packs_usage_statistics.txt";

  if (-e $opusfile) {
    my $age_of_file = (-M $opusfile) * 24 * 60;  # age of file in minutes
    if ($age_of_file > 5) {
      print "Removing old '$opusfile'...";
      if (unlink($opusfile)) {print "done.\n"}
      else {
        print "failed.\n";
        output_error_message(sub_name() . ": Error: Cannot remove existing '$opusfile'. $!");
      }
      # system('sqlplus / as sysdba @/usr/share/oracle_optools/options_packs_usage_statistics.sql');
      exec_os_command("$SQLPLUS_COMMAND @" . "$OPUSSQL");
    } else {
      print "File '$opusfile' is younger than 5 minutes, use it.\n";
    }
  } else {
    exec_os_command("$SQLPLUS_COMMAND @" . "$OPUSSQL");
  }

  if (! open(OPUSFILE, "<", $opusfile) ) {
    print "Cannot open file $opusfile for reading!\n";
    return(undef);
  }

  my $in_table = 0;
  my $headline = "";
  my @report_lines = ();

  while (my $line = <OPUSFILE>) {
    chomp $line;
    # -----
    # Bail out, if the end of the table has been reached.
    if ( $headline && $in_table && $line eq "" ) { last }
    # print "[$line]\n";

    # -----
    $in_table = 0;
    # If the line contains |, then you are processing a table section.
    if ( $line =~ /\|/ ) { $in_table = 1 }

    # -----
    # If specific expressions appear at the beginning of the line
    # then you are processing a new headline.
    # Do NOT abbreviate the expressions!

    # if ($line =~ /^MULTITENANT INFORMATION|^PRODUCT USAGE|^FEATURE USAGE DETAILS/) {
    if ($line =~ /^FEATURE USAGE DETAILS/) {
      # Start a new report (or report table)
      $headline = $line;
      $in_table = 0;
    }

    # -----
    # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # FEATURE USAGE DETAILS
    # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # 
    # PRODUCT              |FEATURE_BEING_USED         |USAGE                 |LAST_SAMPLE_DATE   |      DBID|VERSION    |DETECTED_USAGES|TOTAL_SAMPLES|CURRENTLY_USED|FIRST_USAGE_DATE   |LAST_USAGE_DATE    |EXTRA_FEATURE_INFO
    # ---------------------|---------------------------|----------------------|-------------------|----------|-----------|---------------|-------------|--------------|-------------------|-------------------|------------------
    # Active Data Guard    |Global Data Services       |NO_CURRENT_USAGE      |2017.07.08_09.50.28|2992156657|12.1.0.2.0 |              0|           41|FALSE         |                   |                   |
    # Advanced Analytics   |Data Mining                |NO_CURRENT_USAGE      |2017.07.08_09.50.28|2992156657|12.1.0.2.0 |              0|           41|FALSE         |                   |                   |
    # Advanced Compression |Advanced Index Compression |SUPPRESSED_DUE_TO_BUG |2017.07.08_09.50.28|2992156657|12.1.0.2.0 |              0|           41|FALSE         |                   |                   |
    # Diagnostics Pack     |ADDM                       |CURRENT_USAGE         |2017.07.08_09.50.28|2992156657|12.1.0.2.0 |             28|           41|TRUE          |2016.10.06_04.38.40|2017.07.08_09.50.28|
    # 

    # If you have a non-empty headline
    if ($headline) {
      # and if you are processing the lines of a table
      if ($in_table) {
        if ($line =~ /---/ ) {
          # Ignore the lines with ---
        } else {
          # Then add this line to the resulting array of report lines
          # print "[$line]\n";
          push(@report_lines, "$line |");
        }
      }
    }

  } # while

  close(OPUSFILE);

  # unshift(@O, " product $DELIM feature $DELIM version $DELIM detected usages $DELIM usage $DELIM currently used $DELIM first usage date $DELIM last usage date ");

  $HtmlReport->add_heading(2, "Feature Usage Details", "_default_");

  $HtmlReport->add_paragraph('p', "NOTES: The report lists all detectable products, according to the sampled database version(s).");
  $HtmlReport->add_paragraph('p', "CURRENT_USAGE represents usage tracked over the last sample period, which defaults to one week.");
  $HtmlReport->add_paragraph('p', "PAST_OR_CURRENT_USAGE example: Datapump Export entry indicates CURRENTLY_USED='TRUE' and FEATURE_INFO \"compression used\" counter indicates a non zero value that can be triggered by past or current (last week) usage.");
  $HtmlReport->add_paragraph('p', "For historical details check FIRST_USAGE_DATE, LAST_USAGE_DATE, LAST_SAMPLE_DATE, TOTAL_SAMPLES, DETECTED_USAGES columns.
A leading dot (.) denotes a product that is not a Database Option or Database Management Pack.");

  $HtmlReport->add_paragraph('p', "Please refer to MOS DOC ID 1317265.1 and 1309070.1 for more information.");

  $HtmlReport->add_table(\@report_lines, '\|', "LLLLLLRRLLLL", 1);
  $HtmlReport->add_goto_top("top");

  return(1);

} # feature_usage_details11_2_0_4


# -------------------------------------------------------------------
sub options_packs_usage_statistics19 {
  # This script just uses the options_packs_usage_statistics.sql script (2020-10)
  # from Oracle Support and adds its output as 'code' to the html document.
  # For a CDB it will return also all option usage for all open PDBs, 
  # although that is redundant, as it is called also for each PDB.

  # This sub only uses the PRODUCT USAGE section of the report.
  # The detailed FEATURE USAGE DETAILS section is omitted.


  title(sub_name());

  my $tmp = $ENV{'TMP'} || $ENV{'TMPDIR'} || '/tmp';
  my $sid = lc($ENV{'ORACLE_SID'});
  my $pdb = "";
  if ($CURRENT_PDB) {
    $pdb = lc($CURRENT_PDB);
  }
  my $set_container = "";

  # The original script
  my $opussql = dirname($0) . "/options_packs_usage_statistics19.sql";

  # The script that will be executed (will get some changes)
  my $opussql2 = "$tmp/options_packs_usage_statistics19_$sid.sql";

  # Output file of the above sql script
  my $opusfile = "$tmp/options_packs_usage_statistics19_$sid.txt";

  if ($pdb) {
    # Change filenames for PDBs
    $opussql2 = "$tmp/options_packs_usage_statistics19_${sid}_${pdb}.sql";
    $opusfile = "$tmp/options_packs_usage_statistics19_${sid}_${pdb}.txt";
    $set_container = "ALTER SESSION SET CONTAINER=$CURRENT_PDB;";
  }

  if (-e $opusfile) {
    print "Removing old '$opusfile'...";
    if (unlink($opusfile)) {print "done.\n"}
    else {
      print "failed.\n";
      output_error_message(sub_name() . ": Error: Cannot remove existing '$opusfile'. $!");
      return(undef);
    }
  }

  # -----
  # Use the original sql file, copy that to /tmp and replace the placeholder
  #   '__SPOOLFILE__' with $opusfile and
  #   '-- __SET_CONTAINER__' with 'ALTER SESSION SET CONTAINER=pdb1;'.

  if (! open(OPUSSQL, "<", $opussql) ) {
    output_error_message(sub_name() . ": Error: Cannot open file $opussql for reading!" .$!);
    return(undef);
  }
  if (! open(OPUSSQL2, ">", $opussql2) ) {
    output_error_message(sub_name() . ": Error: Cannot open file $opussql2 for writing!" .$!);
    return(undef);
  }
  while(my $line = <OPUSSQL>) {
    if ($set_container) {
      $line =~ s/-- __SET_CONTAINER__/$set_container/g;
    }
    $line =~ s/__SPOOLFILE__/$opusfile/g;
    print OPUSSQL2 $line;
  }
  close(OPUSSQL);
  close(OPUSSQL2);

  # -----
  exec_os_command("$SQLPLUS_COMMAND @" . "$opussql2");

  my $txt = `cat $opusfile`;

  $HtmlReport->add_heading(2, "Options Packs Usage Statistics", "_default_");
  $HtmlReport->add_paragraph('p', "Please refer to MOS DOC ID 1317265.1 and 1309070.1 for more information.");
  $HtmlReport->add_paragraph('pre', $txt);
  $HtmlReport->add_goto_top("top");

  return(1);

} # options_packs_usage_statistics19


# -------------------------------------------------------------------
sub product_usage  {
  # -----
  # This is for Oracle versions BELOW 11.2.0.4 only!
  #
  # installed features
  #
  # NOTE: That are NOT the options!
  #
  # see
  # Oracle Database Licensing Information
  # 11g Release 2 (11.2)
  # Part Number E10594-26
  # http://docs.oracle.com/cd/E11882_01/license.112/e10594/options.htm

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_heading(2, "Installed Feature", "_default_");
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");
    return 0
  }

  my ($dbid) = @_;

  my $sql = "
    select
      NAME, VERSION, DETECTED_USAGES,
      nvl(to_char(FIRST_USAGE_DATE, 'YYYY-MM-DD HH24:MI:SS'), '-'),
      nvl(to_char(LAST_USAGE_DATE, 'YYYY-MM-DD HH24:MI:SS'), '-')
    from dba_feature_usage_statistics
    where DBID = $dbid
    order by NAME, VERSION
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @L = ();
  get_value_lines(\@L, $TMPOUT1);

  if ( uc($CFG{"ORA_DBINFO.ORACLE_FEATURES"}) eq 'YES' ) {
    # Only if the Oracle features are actively set as option

    # - inventory
    foreach my $i (@L) {
      my @E = split($DELIM, $i);
      @E = map(trim($_), @E);

      append2inventory("ORACLEFEATURE", $E[0], $E[1], $E[2]);
    }
  }

  # - report

  # prepend a title line
  unshift(@L, "feature  $DELIM  version  $DELIM  usages  $DELIM  first usage $DELIM last usage");

  $HtmlReport->add_heading(2, "Installed Feature", "_default_");
  $HtmlReport->add_table(\@L, $DELIM, "LLRLL", 1);
  $HtmlReport->add_goto_top("top");

} # product_usage


# -------------------------------------------------------------------
sub product_usage11_2_0_4 {
  # This is for Oracle version of 11.2.0.4 and higher.

  # see MOS Note 1317265.1

  title(sub_name());

  my ($dbid) = @_;

  my $opusfile = "/tmp/options_packs_usage_statistics.txt";

  if (-e $opusfile) {
    my $age_of_file = (-M $opusfile) * 24 * 60;  # age of file in minutes
    if ($age_of_file > 5) {
      print "Removing old '$opusfile'...";
      if (unlink($opusfile)) {print "done.\n"}
      else {
        print "failed.\n";
        output_error_message(sub_name() . ": Error: Cannot remove existing '$opusfile'. $!");
      }
      # system('sqlplus / as sysdba @/usr/share/oracle_optools/options_packs_usage_statistics.sql');
      exec_os_command("$SQLPLUS_COMMAND @" . "$OPUSSQL");
    } else {
      print "File '$opusfile' is younger than 5 minutes, use it.\n";
    }
  } else {
    exec_os_command("$SQLPLUS_COMMAND @" . "$OPUSSQL");
  }

  if (! open(OPUSFILE, "<", $opusfile) ) {
    print "Cannot open file $opusfile for reading!\n";
    return(undef);
  }

  my $in_table = 0;
  my $headline = "";
  my @report_lines = ();

  while (my $line = <OPUSFILE>) {
    chomp $line;
    # -----
    # Bail out, if the end of the table has been reached.
    if ( $headline && $in_table && $line eq "" ) { last }
    # print "[$line]\n";

    # -----
    $in_table = 0;
    # If the line contains |, then you are processing a table section.
    if ( $line =~ /\|/ ) { $in_table = 1 }

    # -----
    # If specific expressions appear at the beginning of the line
    # then you are processing a new headline.
    # Do NOT abbreviate the expressions!

    # if ($line =~ /^MULTITENANT INFORMATION|^PRODUCT USAGE|^FEATURE USAGE DETAILS/) {
    if ($line =~ /^PRODUCT USAGE/) {
      # Start a new report (or report table)
      $headline = $line;
      $in_table = 0;
    }

    # -----
    # ++++++++++++++++++++++++++++++++++++++++++++++++...
    # PRODUCT USAGE
    # ++++++++++++++++++++++++++++++++++++++++++++++++...
    # 
    # PRODUCT                                            |USAGE                   |LAST_SAMPLE_DATE   |FIRST_USAGE_DATE   |LAST_USAGE_DATE
    # ---------------------------------------------------|------------------------|-------------------|-------------------|-------------------
    # Active Data Guard                                  |NO_USAGE                |2017.07.08_09.50.28|                   |
    # Advanced Analytics                                 |NO_USAGE                |2017.07.08_09.50.28|                   |
    # Advanced Compression                               |NO_USAGE                |2017.07.08_09.50.28|                   |
    # Advanced Security                                  |NO_USAGE                |2017.07.08_09.50.28|                   |
    # Database In-Memory                                 |NO_USAGE                |2017.07.08_09.50.28|                   |
    # Database Vault                                     |NO_USAGE                |2017.07.08_09.50.28|                   |
    # Diagnostics Pack                                   |CURRENT_USAGE           |2017.07.08_09.50.28|2016.10.06_04.38.40|2017.07.08_09.50.28

    # If you have a non-empty headline
    if ($headline) {
      # and if you are processing the lines of a table
      if ($in_table) {
        if ($line =~ /---/ ) {
          # Ignore the lines with ---
        } else {
          # Then add this line to the resulting array of report lines
          # print "[$line]\n";
          push(@report_lines, "$line |");
        }
      }
    }

  } # while

  close(OPUSFILE);

  foreach my $i (@report_lines) {
    my @E = split('\|', $i);
    @E = map(trim($_), @E);
    my $p =  $E[0];
    my $u =  $E[1];

    # add only if CURRENT_USAGE or PAST_OR_CURRENT_USAGE
    if ($u =~ /CURRENT_USAGE/i) {
      append2inventory("ORACLEOPTIONUSAGE", $p, $u);
    }
  } # foreach

  $HtmlReport->add_heading(2, "Product Usage", "_default_");
  $HtmlReport->add_paragraph('p', "Please refer to MOS DOC ID 1317265.1 and 1309070.1 for more information.");

  $HtmlReport->add_table(\@report_lines, '\|', "LLLLL", 1);
  $HtmlReport->add_goto_top("top");

} # product_usage11_2_0_4




# -------------------------------------------------------------------
sub part_1 {
  # Oracle version, components (what is installed), features, options, opatch lsinventory, environment variables

  title(sub_name());

  my $sql = "";
  my $txt = "";
  my @L = ();

  my $dt = iso_datetime();

  $HtmlReport->add_heading(1, "Oracle Database Information Report");
  $HtmlReport->add_paragraph('p', "Generated: $dt");

  $HtmlReport->set_local_anchor_list();

  # -----
  $sql = "select 'oracle version', version from v\$instance;";

  if (! do_sql($sql)) {return(0)}
  $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  # e.g. 10.1.0.3.0, 10.2.0.3.0
  ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO) = split(/\./, $ORACLE_VERSION);

  # -----
  # VERSION_FULL is only available for Oracle 18
  # Refresh the version to the full version like 18.7.0.0
  # Overwrite the previous values.

  $sql = "";

  if ($ORA_MAJOR_RELNO >= 18 ) {
    if ( $sql ) { $sql .= "\n" }
    $sql .= "select 'oracle full version', version_full from v\$instance;";
  }
  if ($ORA_MAJOR_RELNO >= 12 ) {
    if ( $sql ) { $sql .= "\n" }
    $sql .= "select 'is_cdb', cdb from v\$database;";
  }

  my $is_cdb = "NO";
  if ($sql ) {
    if (! do_sql($sql)) {return(0)}

    my $ovf = trim(get_value($TMPOUT1, $DELIM, "oracle version full"));
    if ( $ovf ) { 
      $ORACLE_VERSION = trim(get_value($TMPOUT1, $DELIM, "oracle full version"));
      ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO) = split(/\./, $ORACLE_VERSION);
    }

    my $iamacdb = uc(trim(get_value($TMPOUT1, $DELIM, "is_cdb")));
    # Only if it is found in the results
    if ( $iamacdb ) { $is_cdb = $iamacdb }
  }

  # -----
  $sql = "
    select 'oracle version', version from v\$instance;
    select 'hostname',       host_name from v\$instance;
    select 'platform',       platform_name from v\$database;
    select 'instance name',  instance_name from v\$instance;
    select 'instance startup at', TO_CHAR(startup_time,'YYYY-MM-DD HH24:MI:SS') from v\$instance;
    select 'database_name',  name from v\$database;
    select 'created',        TO_CHAR(created,'YYYY-MM-DD HH24:MI:SS') from v\$database;
    select 'DBID',           dbid from v\$database;
    select 'DATABASE_ROLE',  DATABASE_ROLE from v\$database;
    select 'DATABASE_STATUS',  STATUS from v\$instance;
    select 'GUARD_STATUS',   GUARD_STATUS from v\$database;
    select 'DB_UNIQUE_NAME', DB_UNIQUE_NAME from v\$database;
    select 'FLASHBACK_ON',   FLASHBACK_ON from v\$database;
    select 'FORCE_LOGGING',  FORCE_LOGGING from v\$database;
    select 'LOG_MODE',       LOG_MODE from v\$database;
  ";

  if (! do_sql($sql)) {return(0)}

  # $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  # # e.g. 10.1.0.3.0, 10.2.0.3.0
  # ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO) = split(/\./, $ORACLE_VERSION);

  append2inventory("# date generated", $dt);
  append2inventory("DBENGINE", "Oracle");

  append2inventory("ORACLEVERSION", $ORACLE_VERSION);
  append2inventory("DBVERSION", $ORACLE_VERSION);

  my $my_instance = trim(get_value($TMPOUT1, $DELIM, "instance name"));
  append2inventory("ORACLEINSTANCE", $my_instance);
  append2inventory("DBINSTANCE", $my_instance);

  my $my_instance_ip = get_instance_ip();
  if (! $my_instance_ip) { $my_instance_ip = $NA }
  append2inventory("DBINSTANCEIP", $my_instance_ip);

  my $my_instance_port = get_instance_port();
  if (! $my_instance_port) { $my_instance_port = $NA }
  append2inventory("DBINSTANCEPORT", $my_instance_port);

  my $my_database_name = trim(get_value($TMPOUT1, $DELIM, "database_name"));

  my $database_created = trim(get_value($TMPOUT1, $DELIM, "created"));

  # Save for later usage.
  my $dbid = trim(get_value($TMPOUT1, $DELIM, "DBID"));
  append2inventory("ORACLEDBID", $dbid);

  $MY_HOST = trim(get_value($TMPOUT1, $DELIM, "hostname"));
  append2inventory("ORACLEHOST", $MY_HOST);
  append2inventory("DBHOST", $MY_HOST);

  $HtmlReport->add_heading(2, "General Info", "_default_");

  my $aref = [
    "Instance name        ! $my_instance"
  , "Database name        ! $my_database_name"
  , "Database unique name ! " . trim(get_value($TMPOUT1, $DELIM, "DB_UNIQUE_NAME"))
  , "Oracle Version       ! $ORACLE_VERSION"
  , "DBID                 ! $dbid"
  , "Database created     ! $database_created"
  , "Database role        ! " . trim(get_value($TMPOUT1, $DELIM, "DATABASE_ROLE"))
  , "Is a CDB             ! " . $is_cdb
  , "Database status      ! " . trim(get_value($TMPOUT1, $DELIM, "DATABASE_STATUS"))
  , "Archive log mode     ! " . trim(get_value($TMPOUT1, $DELIM, "LOG_MODE"))
  , "Flashback            ! " . trim(get_value($TMPOUT1, $DELIM, "FLASHBACK_ON"))
  , "Force Logging        ! " . trim(get_value($TMPOUT1, $DELIM, "FORCE_LOGGING"))
  , "Dataguard status     ! " . trim(get_value($TMPOUT1, $DELIM, "GUARD_STATUS"))
  , "Running on host      ! $MY_HOST"
  , "Host platform        ! " . trim(get_value($TMPOUT1, $DELIM, "platform"))
  , "Instance startup at  ! " . trim(get_value($TMPOUT1, $DELIM, "instance startup at"))
  , "Listening on IP      ! $my_instance_ip"
  , "Listening on port    ! $my_instance_port"
  ];

  $HtmlReport->add_table($aref, "!", "LL", 0);
  $HtmlReport->add_goto_top("top");

  # -----
  # Check for PDBs

  if ( $is_cdb ne 'YES' ) {
    print "This is not a container database, no pluggable databases.\n";
  } else {
    print "I am a container database, check for pluggable databases.\n";
    # Leave out the PDBSEED

    $sql = "SELECT NAME, CON_ID FROM V\$PDBS WHERE CON_ID > 2 ORDER BY CON_ID;";
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

    } # foreach pdb

  } # is_cdb


  # -----
  # Incarnations


  $sql = "
    select 
      INCARNATION#
    , to_char(RESETLOGS_TIME, 'yyyy-mm-dd HH24:MI:SS')  RESETLOGS_TIME
    , STATUS
    , RESETLOGS_ID
    from V\$DATABASE_INCARNATION
    order by 1;
  ";

  if (! do_sql($sql)) {return(0)}

  @L = ();

  if (get_value_lines(\@L, $TMPOUT1)) {

    # prepend a title line
    unshift(@L, "incarnation no  $DELIM  resetlogs time  $DELIM  status  $DELIM  resetlogs id");

    $HtmlReport->add_heading(2, "Incarnations", "_default_");
    $HtmlReport->add_table(\@L, $DELIM, "RLLR", 1);

    $HtmlReport->add_paragraph('p', "incarnation no: Record ID for the branch record in the control file<br>
resetlogs time: Resetlogs timestamp for the incarnation of the current row<br>
status: ORPHAN incarnation, CURRENT incarnation of the database, PARENT of the current incarnation<br>
resetlogs id: Branch ID for the incarnation of the current row (used by user-managed recovery/RMAN restore to get unique names for archived logs across incarnations) ");
  }

  # -----
  # Environment variables

  $HtmlReport->add_heading(2, "Environment Variables", "_default_");

  $aref = [
    "ORACLE_BASE: $ENV{'ORACLE_BASE'}"
  , "ORACLE_HOME: $ENV{'ORACLE_HOME'}"
  , "ORACLE_SID : $ENV{'ORACLE_SID'}"
  , "TNS_ADMIN  : $ENV{'TNS_ADMIN'}"
  , "NLS_LANG   : $ENV{'NLS_LANG'} (*)"
  ];

  $HtmlReport->add_table($aref, ":", "LL", 0);
  $HtmlReport->add_paragraph('p', "(*) NLS_LANG does not reflect the database settings! Just the setting of oracle's environment variable!");

  # -----
  # banner information
  # standard edition/enterprise edition

  $sql = "select banner from v\$version; ";

  if (! do_sql($sql)) {return(0)}

  @L = ();
  $txt = "";

  if (get_value_lines(\@L, $TMPOUT1)) {
    $HtmlReport->add_heading(2, "Banner Information", "_default_");
    $HtmlReport->add_table(\@L, $DELIM, "L", 0);
  }


  # -----
  # components

  if ($ORACLE_DBSTATUS eq "OPEN") {
    $sql = "
      select
        COMP_ID, COMP_NAME, VERSION, STATUS,
        to_char(to_date(MODIFIED, 'DD-MON-YYYY HH24:MI:SS'), 'YYYY-MM-DD HH24:MI:SS')
      from dba_registry
      order by COMP_NAME
      ;
    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    # - inventory
    foreach my $i (@L) {
      my @E = split($DELIM, $i);
      @E = map(trim($_), @E);

      append2inventory("ORACLECOMPONENT", $E[0], $E[1]);
    }

    # - report

    # prepend a title line
    unshift(@L, "component_id  $DELIM  component  $DELIM  version  $DELIM  status  $DELIM  last modified");

    $HtmlReport->add_heading(2, "Components", "_default_");
    $HtmlReport->add_table(\@L, $DELIM, "LLLLL", 1);
    $HtmlReport->add_goto_top("top");
  } else {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  } # eq OPEN


  # -----
  my $version_3d = oracle_3d_version(4);
  print "Oracle Version: $version_3d\n";

  # -----
  # multitenant information
  if ($version_3d ge "012.001.000.000") {
    multitenant_info($dbid);
  } else {
    print "No multitenant information available for Oracle $ORACLE_VERSION ($version_3d)!\n";
  }

  # -----
  # installed features
  # Now called: product usage
  # 
  # NOTE: That are NOT the options!

  if ($version_3d lt "011.002.000.004") {
    product_usage($dbid);
  } elsif ($version_3d ge "011.002.000.004" && $version_3d lt "019.000.000.000") {
    product_usage11_2_0_4($dbid);
  } elsif ($version_3d ge "019.000.000.000") {
    # do nothing here
  } else {
    print "No product usage available for Oracle $ORACLE_VERSION ($version_3d)!\n";
  }


  # -----
  # feature usage details

  if ($version_3d lt "011.000.000.000" ) {
    # Oracle 10 and earlier
    print "No option or feature usage available for Oracle 10 or older like this $ORACLE_VERSION ($version_3d)!\n";
  } elsif ($version_3d lt "011.002.000.004" ) {
    option_usage();
  } elsif ($version_3d ge "011.002.000.004" && $version_3d lt "019.000.000.000" ) {
    feature_usage_details11_2_0_4();
  } elsif ($version_3d ge "019.000.000.000") {
    # do nothing here
  } else {
    print "No option usage available for Oracle $ORACLE_VERSION ($version_3d)!\n";
  }

  # Complete output for Oracle 19+
  if ($version_3d ge "019.000.000.000" ) {
    options_packs_usage_statistics19();
  }

  # -----
  # opatch lsinventory

  # Find the opatch routine
  my $opatch = $ENV{"ORACLE_HOME"} . "/OPatch/opatch";

  my $cmd = "$opatch lsinventory";

  $txt = `$cmd`;

  $HtmlReport->add_heading(2, "OPatch lsinventory", "_default_");
  $HtmlReport->add_paragraph('pre', $txt);
  $HtmlReport->add_goto_top("top");

  # -----
  # Find all installed patches from output of opatch lsinventory

  my @lines = split /\n/, $txt;
  foreach my $line (@lines) {

    # Patch  6494745      : applied on Mon Jul 06 13:37:48 CEST 2009
    # if ( $line =~ /^Patch  \d+/i ) {
    if ( $line =~ /^Patch\s+\d+/i ) {

      my ($patch, $patchno, $dummy) = split(/\s+/, $line);
      print "patch=$patchno\n";

      append2inventory("ORACLEPATCH", $patchno);
    }
  } # foreach


  # -----
  # Additional patch information from registry$history

  if ($ORACLE_DBSTATUS eq "OPEN") {
    $sql = "
      select 
          to_char(action_time, 'YYYY-MM-DD HH24:MI:SS')
        , action
        , namespace
        , version 
        , bundle_series 
        , comments
      from registry\$history
      order by 1
      ;

    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    # prepend a title line
    unshift(@L, "timestamp  $DELIM  action  $DELIM  namespace  $DELIM  version $DELIM bundle_series $DELIM comments ");

    $HtmlReport->add_heading(2, "Registry History", "_default_");
    $HtmlReport->add_table(\@L, $DELIM, "LLLLLL", 1);
    $HtmlReport->add_paragraph('p', "The 'version' often contains expressions like: 19.8.0.0.200714OJVMRU where 200714 is the date of the patch: 2020-07-14.");
    $HtmlReport->add_goto_top("top");
  } else {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  } # eq OPEN

  return(1);
} # part_1


# -------------------------------------------------------------------
sub part_2 {
  # Parameters,  NLS settings

  title(sub_name());

  my @L = ();
  my $txt = "";
  my $sql = "";

  # -----
  # Parameters

  # my $sql = "
  #   select rtrim(name)
  #   , rtrim(value)
  #   , rtrim(isdefault)
  #   from v\$parameter
  #   order by name;
  # ";

  if ( oracle_3d_version() lt "019.000.000.000") {
    $sql = "
      select name
      , display_value
      , isdefault
      , ismodified
      from gv\$parameter2
      order by name;
    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    unshift(@L, "parameter  $DELIM  value $DELIM is modified $DELIM is default");

    $HtmlReport->add_heading(2, "Parameters", "_default_");
    if ( oracle_3d_version(2) eq "012.002" ) {
      $HtmlReport->add_paragraph('p', "In Oracle 12.2 there may be some underscore parameters added because the STATISTICS_LEVEL was changed. This is expected behavior, see: When Changing STATISTICS_LEVEL Parameter On 12.2.0.1, Few Extra Parameters Are Also Added To Spfile (Doc ID 2282692.1)");
    }
    $HtmlReport->add_table(\@L, $DELIM, "LLLL", 1);
    $HtmlReport->add_goto_top("top");

  } else {
    # Oracle 19+

    $sql = "
    select
      case con_id
        when 0 then 'ALL'
        when 1 then 'CDB ONLY'
      end FOR_CONTAINER
    , name
    , display_value
    , ismodified
    , isdefault
    , DESCRIPTION
    from V\$SYSTEM_PARAMETER2
    where con_id <= 1
    order by name;
  ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    unshift(@L, "for container $DELIM  parameter  $DELIM  value $DELIM is modified $DELIM is default $DELIM description");

    $HtmlReport->add_heading(2, "Parameters", "_default_");
    $HtmlReport->add_table(\@L, $DELIM, "LLLLLL", 1);
    $HtmlReport->add_goto_top("top");

  } # Oracle 19


  # -----
  # database and instance NLS parameters

  # At least the instance NLS parameters seem to be modifiable in PDBs.
  # So show them (all).

  if ($ORACLE_DBSTATUS eq "OPEN") {

    # Use concatenation to avoid the substitution question
    $sql = "
      SELECT
         db.parameter as parameter,
         nvl(db.value, '&' || 'nbsp;') as database_value,
         nvl(i.value, '&' || 'nbsp;') as instance_value
      FROM nls_database_parameters db
      LEFT JOIN nls_instance_parameters i ON i.parameter = db.parameter
      ORDER BY parameter;
    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    # Insert title
    unshift(@L, "NLS PARAMETER  $DELIM  NLS_DATABASE_PARAMETERS   $DELIM   NLS_INSTANCE_PARAMETERS");

    $HtmlReport->add_heading(2, "NLS Database and Instance Parameters", "_default_");
    $HtmlReport->add_paragraph('p', "NLS_DATABASE_PARAMETERS show the initially defined values of the NLS parameters for the database. These are fixed at the database level and cannot be changed, some can be overridden by NLS_INSTANCE_PARAMETERS. NLS_CHARACTERSET and NLS_NCHAR_CHARACTERSET can NOT be changed, though!");
    $HtmlReport->add_paragraph('p', "NLS_INSTANCE_PARAMETERS show the current NLS instance parameters that have been explicitly set to override the invariable NLS_DATABASE_PARAMETERS. This is the base from which the NLS_SESSION_PARAMETRS are derived (the effective parameters for the user session). Note that enviroment variables like NLS_LANG which can be effective in a user session do overwrite the NLS_INSTANCE_PARAMETERS.");
    $HtmlReport->add_table(\@L, $DELIM, "LLL", 1);
    $HtmlReport->add_goto_top("top");
  } else {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  }

} # part_2


# -------------------------------------------------------------------
sub security_settings {
  # -----
  # Security Settings

  # all parameters SEC_PROTOCOL_xxx
  # Check that unified auditing is enabled 12.1+
  # select parameter, value from v$option where PARAMETER = 'Unified Auditing';

  # audit_trail must be DB
  # select name, value from v$parameter where name = 'audit_trail';

  # Show enabled policies
  # select POLICY_NAME, ENABLED_OPT, USER_NAME, SUCCESS, FAILURE
  # from AUDIT_UNIFIED_ENABLED_POLICIES;
  # ATT: The structure has changed (at least) for Oracle 19, see sql below.

  # Also the audit options for all enabled policies?
  # That would be (for all POLICY_NAME in AUDIT_UNIFIED_ENABLED_POLICIES):
  # select POLICY_NAME, AUDIT_OPTION, CONDITION_EVAL_OPT
  # from   AUDIT_UNIFIED_POLICIES
  # where policy_name = 'ORA_SECURECONFIG'

  title(sub_name());

  $HtmlReport->add_heading(2, "Security Settings", "_default_");
  $HtmlReport->add_heading(3, "Unified Auditing", "_default_");

  my @L = ();
  my $txt = "";

  # -----
  # Check for UNIFIED AUDITING

  my $sql = "
    select 'unified_auditing', upper(value) 
    from v\$option 
    where lower(parameter) = 'unified auditing';
  ";

  if (! do_sql($sql)) {return(0)}

  my $V = trim(get_value($TMPOUT1, $DELIM, "unified_auditing"));
  print "Unified Auditing=$V\n";

  if ($V !~ /TRUE/i ) { 
    $HtmlReport->add_paragraph('p', "Unified Auditing is not enabled.");
    $HtmlReport->add_goto_top("top");
    return(1);
  }
  $HtmlReport->add_paragraph('p', "Unified Auditing is enabled.");

  # -----
  # Get enabled Auditing Policies

  if ($ORACLE_DBSTATUS eq "OPEN") {

    if ( $ORA_MAJOR_RELNO < 19 ) {
      # pre Oracle 19 (Oracle 18 is not supported by this script, though)

      $sql = "
        select
        USER_NAME, POLICY_NAME, ENABLED_OPT, SUCCESS, FAILURE    
        FROM AUDIT_UNIFIED_ENABLED_POLICIES
        order by 1,2;
      ";

      if (! do_sql($sql)) {return(0)}

      @L = ();
      get_value_lines(\@L, $TMPOUT1);

      unshift(@L, "USER_NAME  $DELIM  POLICY_NAME   $DELIM   ENABLED_OPT  $DELIM  SUCCESS  $DELIM  FAILURE");

      $HtmlReport->add_table(\@L, $DELIM, "LLLLL", 1);

    } else { 

      # Oracle 19
      $sql = "
        select
          POLICY_NAME, ENABLED_OPTION, ENTITY_NAME, ENTITY_TYPE, SUCCESS, FAILURE
        FROM AUDIT_UNIFIED_ENABLED_POLICIES
        order by 1,2,3;
      ";

      if (! do_sql($sql)) {return(0)}

      @L = ();
      get_value_lines(\@L, $TMPOUT1);

      unshift(@L, "POLICY_NAME  $DELIM ENABLED_OPTION $DELIM  ENTITY_NAME  $DELIM  ENTITY_TYPE  $DELIM  SUCCESS  $DELIM  FAILURE");

      $HtmlReport->add_table(\@L, $DELIM, "LLLLLL", 1);

      # -----
      # TODO
      # Definitions of non-standard policies


    }  # Oracle 19

    # -----
    # NOTE: These initialization parametes have no effect
    #       when unified auditing is enabled.
    # AUDIT_TRAIL
    # AUDIT_FILE_DEST
    # AUDIT_SYS_OPERATIONS
    # AUDIT_SYSLOG_LEVEL

    $HtmlReport->add_paragraph('p', "Keep in mind that the following initialization parametes have no effect when unified auditing is enabled:<br>AUDIT_TRAIL<br>AUDIT_FILE_DEST<br>AUDIT_SYS_OPERATIONS<br>AUDIT_SYSLOG_LEVEL.");

    $HtmlReport->add_goto_top("top");
  } else {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  }

  return(0);

} # security_settings


# -------------------------------------------------------------------
sub part_4 {
  # RAC

  title(sub_name());

  $HtmlReport->add_heading(2, "RAC", "_default_");
  $HtmlReport->add_paragraph('p', "Information about RAC environments is currently not implemented.");
  $HtmlReport->add_goto_top("top");

} # part_4


# -------------------------------------------------------------------
sub buffer_cache9 {

  $HtmlReport->add_heading(2, "Buffer Caches", "_default_");
  $HtmlReport->add_paragraph('p', "This is currently not supported for Oracle 9.");
  $HtmlReport->add_goto_top("top");

} # buffer_cache9


# -------------------------------------------------------------------
sub part_5 {
  # SGA, shared pool, buffer caches, pga

  title(sub_name());

  my $txt = "";
  my @L = ();

  # -----
  # SGA

  my $sql = "
    select 'overall size', sum(value) from v\$sga;
    select 'free memory', current_size from v\$sga_dynamic_free_memory;
  ";

  if (! do_sql($sql)) {return(0)}

  my $size = trim(get_value($TMPOUT1, $DELIM, "overall size"));
  $size = sprintf("%10.1f MB", $size/(1024*1024));

  my $free = trim(get_value($TMPOUT1, $DELIM, "free memory"));
  $free = sprintf("%10.1f MB", $free/(1024*1024));

  $HtmlReport->add_heading(2, "SGA", "_default_");
  $HtmlReport->add_table(["Size : $size", "Free : $free"], ":", "LL", 0);
  $HtmlReport->add_goto_top("top");

  # -----
  # Buffer Caches

  # for Oracle 9.2
  # if ($ORACLE_VERSION =~ /^9/) {
  if ($ORA_MAJOR_RELNO <= 9) {
    # Use the old style for Oracle 9
    buffer_cache9();
    return();
  }

  # Here only for Oracle 10, 11, 12

  # current_size is in MB

  $sql = "
    select
        name || ' (' || block_size / 1024 || 'k)'
      , current_size
    from v\$buffer_pool
    order by name, block_size
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  @L = ();
  get_value_lines(\@L, $TMPOUT1);

  unshift(@L, "buffer cache  $DELIM  size [MB]");

  $HtmlReport->add_heading(3, "Buffer Caches", "_default_");
  $HtmlReport->add_table(\@L, $DELIM, "LR", 1);
  $HtmlReport->add_goto_top("top");

  # -----
  # shared pool

  $sql = "
    select 'shared pool size', current_size from v\$sga_dynamic_components
      where component = 'shared pool';
  ";

  if (! do_sql($sql)) {return(0)}

  my $V = int(trim(get_value($TMPOUT1, $DELIM, 'shared pool size')));
  $V = sprintf("%10.1f MB", $V/(1024*1024));

  $HtmlReport->add_heading(3, "Shared Pool", "_default_");
  $HtmlReport->add_table(["Size ! $V"], $DELIM, "L", 0);

  # -----
  # PGA

  $sql = "select name, value from v\$pgastat;";

  if (! do_sql($sql)) {return(0)}

  $V = trim(get_value($TMPOUT1, $DELIM, "aggregate PGA target parameter"));
  my $aptp = sprintf("%10.1f MB", $V/(1024*1024));

  $V = trim(get_value($TMPOUT1, $DELIM, "aggregate PGA auto target"));
  my $apat = sprintf("%10.1f MB", $V/(1024*1024));

  $V = trim(get_value($TMPOUT1, $DELIM, "maximum PGA allocated"));
  my $mpa  = sprintf("%10.1f MB", $V/(1024*1024));

  my $aref = [
    "aggregate PGA target parameter : $aptp"
  , "aggregate PGA auto target      : $apat"
  , "maximum PGA allocated          : $mpa"
  ];

  $HtmlReport->add_heading(3, "PGA", "_default_");
  $HtmlReport->add_table($aref, ":", "LR", 0);

  $HtmlReport->add_goto_top("top");
} # part_5


# -------------------------------------------------------------------
sub part_6 {
  # Online Redo Logs

  title(sub_name());

  my $txt = "";
  my @L = ();

  # -----
  # Online Redo Logs

  my $sql = "
    select 
      l1.group#
      , member
      , l1.status
      , type
      , round(bytes / 1024 / 1024, 1)
    from v\$log l1, v\$logfile l2
    where l1.GROUP# = l2.GROUP#
    order by l1.GROUP#
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  @L = ();
  get_value_lines(\@L, $TMPOUT1);

  # Insert title
  unshift(@L, "group $DELIM member $DELIM status $DELIM type $DELIM size [MB]");

  $HtmlReport->add_heading(2, "Online Redo Logs", "_default_");
  $HtmlReport->add_table(\@L, $DELIM, "RLLLR", 1);
  $HtmlReport->add_goto_top("top");

} # part_6


# -------------------------------------------------------------------
sub part_7 {

  # ASM

  title(sub_name());



} # part_7



# -------------------------------------------------------------------
sub datafiles {
  # datafiles(<tablespace>, <contents>);

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  }

  my ($ts, $contents) = @_;

  my $sql;

  my $tabtitle = "data file $DELIM size [MB] $DELIM max size [MB] $DELIM status $DELIM  online status $DELIM autoextensible";
  my $tabtitlealign = "LRRLLL";

  if ($contents eq "TEMPORARY") {

    $sql = "
      select
          file_name
        , round(bytes / (1024 * 1024))
        , round(maxbytes / (1024 * 1024))
        , status
        , autoextensible
      from dba_temp_files
      where upper(tablespace_name) = upper('$ts')
      order by file_id;
    ";

    $tabtitle = "temp file $DELIM size [MB] $DELIM max size [MB] $DELIM status $DELIM  autoextensible";
    $tabtitlealign = "LRRLL";

  } else {

    $sql = "
      select
          file_name
        , round(bytes / (1024 * 1024))
        , round(maxbytes / (1024 * 1024))
        , status
        , autoextensible
      from dba_data_files
      where upper(tablespace_name) = upper('$ts')
      order by file_id;
    ";

  }

  if (! do_sql($sql)) {return(0)}

  my @DF;
  get_value_lines(\@DF, $TMPOUT1);

  # prepend a title line
  unshift(@DF, $tabtitle);

  $HtmlReport->add_table(\@DF, $DELIM, $tabtitlealign, 1);

} # datafiles

# -------------------------------------------------------------------
sub part_8_til10 {
  # part_8_til10();
  # 
  # Tablespaces, datafiles

  title(sub_name());



  # This will work for all Oracle Versions, specifically up to 10.2
  my $sql = "
    select tablespace_name, initial_extent, next_extent,
           status, contents, logging, extent_management,
           allocation_type, segment_space_management,
           (select count(*) from dba_data_files ddf
              where autoextensible = 'YES'
                and dts.tablespace_name = ddf.tablespace_name) +
           (select count(*) from dba_temp_files dtf
              where autoextensible = 'YES'
                and dts.tablespace_name = dtf.tablespace_name),
           (select count(*) from dba_data_files ddf
              where dts.tablespace_name = ddf.tablespace_name) +
           (select count(*) from dba_temp_files dtf
              where dts.tablespace_name = dtf.tablespace_name),
           block_size,
           PCT_INCREASE,
           DEF_TAB_COMPRESSION,
           force_logging
      from dba_tablespaces dts order by 1;
  ";

  if (! do_sql($sql)) {return(0)}

  $HtmlReport->add_heading(2, "Tablespaces", "_default_");

  my @TSPACE;
  get_value_lines(\@TSPACE, $TMPOUT1);

  foreach my $tspace (@TSPACE) {
    my @E = split($DELIM, $tspace);
    @E = map(trim($_), @E);

    # -----
    # tablespace infos

    $HtmlReport->add_heading(3, $E[0]);

    my $aref = [
      "Contents                  : " . $E[4]
    , "Block Size                : " . $E[11]
    , "Status                    : " . $E[3]
    , "Logging                   : " . $E[5]
    , "Force Logging             : " . $E[14]
    , "Default Table Compression : " . $E[13]
    , "Extent Management         : " . $E[6]
    , "Initial Extent            : " . $E[1]
    , "Percent Increase          : " . $E[12]
    , "Next Extent               : " . $E[2]
    , "Allocation Type           : " . $E[7]
    , "Segment Space Management  : " . $E[8]
    , "Datafiles                 : " . $E[10]
    , "Autoextensible datafiles  : " . $E[9]
    ];
    $HtmlReport->add_table($aref, ":", "LL", 0);

    # tablespace name, contents
    datafiles($E[0], $E[4]);

    $HtmlReport->add_goto_top("top");

  } # foreach

} # part_8_til10


# -------------------------------------------------------------------
sub part_8_11plus {
  # part_8_11plus();
  #
  # Tablespaces, datafiles

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_heading(2, "Tablespaces", "_default_");
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");
    return(0);
  }

  # Not sure, if this will work for older versions.
  my $sql = "
    select tablespace_name, initial_extent, next_extent,
           status, contents, logging, extent_management,
           allocation_type, segment_space_management,
           (select count(*) from dba_data_files ddf
              where autoextensible = 'YES'
                and dts.tablespace_name = ddf.tablespace_name) +
           (select count(*) from dba_temp_files dtf
              where autoextensible = 'YES'
                and dts.tablespace_name = dtf.tablespace_name),
           (select count(*) from dba_data_files ddf
              where dts.tablespace_name = ddf.tablespace_name) +
           (select count(*) from dba_temp_files dtf
              where dts.tablespace_name = dtf.tablespace_name),
           block_size, 
           PCT_INCREASE,
           encrypted,
           DEF_TAB_COMPRESSION, COMPRESS_FOR, BIGFILE
      from dba_tablespaces dts order by 1;
  ";

  if (! do_sql($sql)) {return(0)}

  $HtmlReport->add_heading(2, "Tablespaces", "_default_");

  my @TSPACE;
  get_value_lines(\@TSPACE, $TMPOUT1);

  foreach my $tspace (@TSPACE) {
    my @E = split($DELIM, $tspace);
    @E = map(trim($_), @E);

    # -----
    # tablespace infos

    $HtmlReport->add_heading(3, $E[0]);

    my $ts_compression = ($E[14] eq 'DISABLED') ? $E[14] : $E[14] . " for " . $E[15];

    my $aref = [
        "Contents                 : " . $E[4]
      , "Block Size               : " . $E[11]
      , "Bigfile                  : " . $E[16]
      , "Status                   : " . $E[3]
      , "Encrypted                : " . $E[13]
      , "Logging                  : " . $E[5]
      , "Table Compression        : " . $ts_compression
      , "Extent Management        : " . $E[6]
      , "Initial Extent           : " . $E[1]
      , "Percent Increase         : " . $E[12]
      , "Next Extent              : " . $E[2]
      , "Allocation Type          : " . $E[7]
      , "Segment Space Management : " . $E[8]
      , "Datafiles                : " . $E[10]
      , "Autoextensible datafiles : " . $E[9]
    ];

    # my $txt = make_text_report($aref, ":", "LL", 0);
    # $HtmlReport->add_paragraph("pre", $txt);
    # Discarded, because the pipe char is ALWAYS used as resulting column delimiter.

    $HtmlReport->add_table($aref, ":", "LL", 0);

    # tablespace name, contents
    datafiles($E[0], $E[4]);

    $HtmlReport->add_goto_top("top");

  } # foreach

} # part_8_11plus


# -------------------------------------------------------------------
sub part_9 {
  # fast recovery area
  # Not available before Oracle 10
  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORA_MAJOR_RELNO < 10) { return(1) }

  title(sub_name());

  my $sql = "";

  # -----
  # Check if fast recovery area is in use

  $sql = "
    select upper(name), value from v\$parameter
      where upper(name)
        in ('DB_RECOVERY_FILE_DEST_SIZE', 'DB_RECOVERY_FILE_DEST');
  ";

  if (! do_sql($sql)) {return(0)}

  # 'db_recovery_file_dest' could be used for RMAN backups,
  # even if flashback feature is not enabled.

  my $db_recovery_file_dest = trim(get_value($TMPOUT1, $DELIM, 'DB_RECOVERY_FILE_DEST'));
  my $db_recovery_file_dest_size = trim(get_value($TMPOUT1, $DELIM, 'DB_RECOVERY_FILE_DEST_SIZE'));

  if ($db_recovery_file_dest && $db_recovery_file_dest_size) {
    # FRA is used

    $sql = "
      select 'fra_usage'
      , name , space_limit , space_used
      from v\$recovery_file_dest;
    ";
    # this will currently return just one record

    if (! do_sql($sql)) {return(0)}

    my $fra_dest = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 2));

    my $fra_size = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 3));
    $fra_size = sprintf("%10.1f MB", $fra_size / (1024*1024));

    my $fra_used = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 4));
    $fra_used = sprintf("%10.1f MB", $fra_used / (1024*1024));

    my $aref = [
      "Destination : $fra_dest"
    , "Size        : $fra_size"
    , "Used        : $fra_used"
    ];

    $HtmlReport->add_heading(2, "Fast Recovery Area", "_default_");
    $HtmlReport->add_table($aref, ":", "LR", 0);
    $HtmlReport->add_goto_top("top");

  } else {
    $HtmlReport->add_heading(2, "Fast Recovery Area", "_default_");
    $HtmlReport->add_paragraph('p', "Not used.");
    $HtmlReport->add_goto_top("top");
  }

} # part_9


# -------------------------------------------------------------------
sub part_10 {
  # pfile/spfile, control.txt

  title(sub_name());

  # -----
  # pfile/spfile

  # create pfile=/path/to/backup.ora from spfile;

  my $spfilename = "";
  my $spfile_is_temporary = 0;
  my $pfilename  = "";
  # temporary directory to place the copy of the [s]pfile
  my $tempdir  = $ENV{"TMP"} || $ENV{"TEMP"} || "/tmp";
  my $filenameext = "_for_$0_only.ora";

  # -----
  # Get the [s]pfile settings
  # BUT: PFILE does not need to be set!!!

  my $sql = "
    select 
      upper(name), rtrim(value)
    from v\$parameter 
    where upper(name) in ('PFILE', 'SPFILE');
  ";

  if (! do_sql($sql)) {return(0)}

  $spfilename = trim(get_value($TMPOUT1, $DELIM, "SPFILE"));
  $pfilename  = trim(get_value($TMPOUT1, $DELIM, "PFILE"));
  print "PFILE: $pfilename, SPFILE: $spfilename\n";

  if (! $spfilename) {
    print "SPFILE parameter is not set => build a temporary spfile.\n";

    # Use a none default filename! Oracle would use it otherwise at next startup.
    $spfilename = "$tempdir/spfile_" . $ENV{"ORACLE_SID"} . $filenameext;

    $sql = "create spfile='$spfilename' from pfile;";

    if (! do_sql($sql)) {return(0)}

    print "Temporary spfile '$spfilename' created from pfile.\n";
    $spfile_is_temporary = 1;

  } else {

    print "SPFILE parameter is set: $spfilename\n";

  }
  # Now, we do have an spfile (whether by default or explicitly created)
  # and can create a readable parameter file (init.ora) out of it.

  # -----
  $pfilename = "$tempdir/init_" . $ENV{"ORACLE_SID"} . $filenameext;

  $sql = "create pfile = '$pfilename' from spfile = '$spfilename';";

  if (! do_sql($sql)) {return(0)}

  append_file_contents($pfilename, "spfile");

  unlink($pfilename);
  if ($spfile_is_temporary) { unlink($spfilename) }

  # -----
  # control.txt

  my $cfile = "$tempdir/control.txt";

  $sql = "
    ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS '$cfile' REUSE;
  ";

  if (! do_sql($sql)) {return(0)}

  append_file_contents($cfile, "controlfile");

  unlink($cfile);

} # part_10



# -------------------------------------------------------------------
sub read_file {
  # read_file(<filename>);

  my ($filename) = @_;

  my $txt = "";

  if (! open(INFILE, "<", $filename)) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    return(undef);
  }
  while (my $L = <INFILE>) {
    chomp($L);
    if ($txt) { $txt .= "\n" }
    $txt .= $L;
  } # while

  if (! close(INFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(undef);
  }

  return($txt);

} # read_file


# -------------------------------------------------------------------
sub append_file_contents {
  my ($filename, $title) = @_;

  # Default title is the basename of the file
  if (! $title) { $title = basename($filename) }

  my $txt = "File '$filename' could not be found or is not readable!";

  my $last_modified = "";

  if (-r $filename) {
    # Read in the contents of the file
    $txt = read_file($filename);

    if ($txt) { 
      print "File '$filename' has contents.\n";
    } else {
      print "File '$filename' has no contents.\n";
      $txt = "File '$filename' has no contents!";
    }
    $last_modified = iso_datetime((stat($filename))[9]);
  }

  # -----
  $HtmlReport->add_heading(2, $title, "_default_");

  if ($last_modified) {
    $HtmlReport->add_paragraph('p', "Filename: $filename (last modified: $last_modified)");
  } else {
    $HtmlReport->add_paragraph('p', "Filename: $filename");
  }
  $HtmlReport->add_paragraph('pre', $txt);
  $HtmlReport->add_goto_top("top");

} # append_file_contents



# -------------------------------------------------------------------
sub part_11 {
  # listener.ora, tnsnames.ora, sqlnet.ora

  title(sub_name());

  ### my $txt = "";

  my $nw_admin = $ENV{"ORACLE_HOME"} . "/network/admin";
  if ($ENV{"TNS_ADMIN"} ) {
    $nw_admin = $ENV{"TNS_ADMIN"};
  }

  # -----
  # sqlnet.ora

  my $filename = $nw_admin . "/sqlnet.ora";
  append_file_contents($filename);

  # -----
  # listener.ora

  $filename = $nw_admin . "/listener.ora";
  append_file_contents($filename);

  # -----
  # tnsnames.ora

  $filename = $nw_admin . "/tnsnames.ora";
  append_file_contents($filename);

  # -----
  # Check for IFILE entries in tnsnames.ora
  # and append the contents of those.

  print "Check '$filename' for IFILE entries\n";

  if (! open(TNSNAMES, "<", $filename)) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    return(undef);
  }

  while (my $line = <TNSNAMES>) {
    chomp($line);

    if ($line =~ /^ *IFILE *= *(.*)$/i){
       print "Found line containing IFILE: $line\n";
       print "Extracted filename: [$1]\n";

       append_file_contents("$1");
    }
  } # while

  if (! close(TNSNAMES)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(undef);
  }


} # part_11




# -------------------------------------------------------------------
sub services {
  title(sub_name());

  my $version_3d = oracle_3d_version(4);
  print "Oracle Version: $version_3d\n";

  # -----
  if ($version_3d ge "012.001.000.002") {
    print "Print a list of defined services.\n";
  } else {
    print "Services are not listed for Oracle versions lower than 12.1.0.2\n";
  }

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_heading(2, "Services", "_default_");
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");
    return(0);
  }


  # For all versions, CDB
  # 
  # SELECT PDB, NAME, NETWORK_NAME FROM CDB_SERVICES ORDER BY PDB, NAME;
  # 
  # PDB        NAME                           NETWORK_NAME
  # ---------- ------------------------------ ------------------------------
  # CDB$ROOT   SYS$BACKGROUND
  # CDB$ROOT   SYS$USERS
  # CDB$ROOT   dcdb19                         dcdb19
  # CDB$ROOT   dcdb19XDB                      dcdb19XDB
  # PBDMOTO001 PBDMOTO001                     PBDMOTO001
  # PBDMOTO001 S-RV.NEU20                     s-rv.neu20
  # PBDMOTO001 SERVICE1                       SERVICE1

  # For all versions, PDB:
  # 
  # alter session set container=PBDMOTO001;
  # 
  # SELECT PDB, NAME, NETWORK_NAME FROM DBA_SERVICES ORDER BY PDB, NAME;
  # 
  # PDB        NAME                           NETWORK_NAME
  # ---------- ------------------------------ ------------------------------
  # PBDMOTO001 PBDMOTO001                     PBDMOTO001
  # PBDMOTO001 S-RV.NEU20                     s-rv.neu20
  # PBDMOTO001 SERVICE1                       SERVICE1
  # PBDMOTO001 SERVICE2                       SERVICE2
  # PBDMOTO001 SERVICE3                       SERVICE3
  # PBDMOTO001 SRV.NEU20                      srv.neu20
  # 

  my $tblname = "CDB_SERVICES";
  my $where   = "WHERE PDB IS NOT NULL";
  if ($CURRENT_PDB) {
    # sub is called for a PDB
    $tblname = "DBA_SERVICES"; 
    $where   = "";
  }

  my $sql = " SELECT PDB, NAME, NETWORK_NAME FROM $tblname $where ORDER BY PDB, NAME; ";

  if (! do_sql($sql)) {return(0)}

  my @A = ();
  get_value_lines(\@A, $TMPOUT1);

  # Insert title
  unshift(@A, "container/pdb $DELIM service name $DELIM network name");

  $HtmlReport->add_heading(2, "Services", "_default_");
  $HtmlReport->add_table(\@A, $DELIM, "LLL", 1);
  $HtmlReport->add_paragraph('p', "Services are usable via the 'network name'."); 
  $HtmlReport->add_goto_top("top");

} # services


# -------------------------------------------------------------------
sub stat_prefs {
  # optimizer statistics preferences

  title(sub_name());

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_heading(2, "Optimizer Statistics Preferences", "_default_");
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");
    return(0);
  }

  my $sql = "
    select 'stats_prefs'
      , trim(substr(dbms_stats.get_prefs('AUTOSTATS_TARGET'), 1, 20))
      , trim(substr(dbms_stats.get_prefs('CASCADE'), 1, 20))
      , trim(substr(dbms_stats.get_prefs('ESTIMATE_PERCENT'), 1, 20))
      , trim(substr(dbms_stats.get_prefs('GRANULARITY'), 1, 20))
      , trim(substr(dbms_stats.get_prefs('STALE_PERCENT'), 1, 20)) from dual
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my $autostats_target = trim(get_value($TMPOUT1, $DELIM, 'stats_prefs', 2));
  my $cascade          = trim(get_value($TMPOUT1, $DELIM, 'stats_prefs', 3));
  my $estimate_percent = trim(get_value($TMPOUT1, $DELIM, 'stats_prefs', 4));
  my $granularity      = trim(get_value($TMPOUT1, $DELIM, 'stats_prefs', 5));
  my $stale_percent    = trim(get_value($TMPOUT1, $DELIM, 'stats_prefs', 6));

  my $aref = [
      "AUTOSTATS_TARGET : $autostats_target"
    , "CASCADE          : $cascade"
    , "ESTIMATE_PERCENT : $estimate_percent"
    , "GRANULARITY      : $granularity"
    , "STALE_PERCENT    : $stale_percent"
  ];

  $HtmlReport->add_heading(2, "Optimizer Statistics Preferences", "_default_");
  $HtmlReport->add_paragraph('p', "Current global statistic preferences for 'auto optimizer stats collection'. See dbms_stats.set_global_prefs and dbms_stats.get_prefs on how to set and request global statistic preferences.");
  $HtmlReport->add_table($aref, ":", "LL", 0);
  $HtmlReport->add_goto_top("top");

} # stat_prefs


# ===================================================================
# PDB subs


# -------------------------------------------------------------------
sub get_ip_port {

  title(sub_name());

  my $sql = "";

  $sql = "select 'local_listener', value from v\$listener_network 
          where type = 'LOCAL LISTENER';
  ";

  if (! do_sql($sql)) {return( (undef, undef) )}

  my $local_listener = trim(get_value($TMPOUT1, $DELIM, "local_listener"));

  # \s whitespace
  # \S non-whitespace
  $local_listener =~ /\(HOST\s*=\s*(\S+?)\s*\)/;
  my $host = $1;

  # nothing found
  if (! $host) {
    print "No HOST parameter found in LOCAL LISTENER output!\n";
    return( (undef, undef) );
  }

  # Is it an ip already?
  # Check for digits at the beginning.
  if ($host =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) { 
    print "'$host' is already an ip address, no lookup necessary.\n";
  } else {
    # Assume it is a hostname, must get ip:
    # (may not work on all flavours of Unix)
    print "Must resolve hostname to ip address.\n";

    my $ip = `gethostip -d $host`;
    chomp($ip);
    if ( $ip =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) { 
      print "'$host' resolved to '$ip'\n";
      $host = $ip;
    } else {
      print "No valid ip address found!\n";
      return( (undef, undef) );
    }
  }

  # -----
  $local_listener =~ /\(PORT\s*=\s*(\S+?)\s*\)/;
  my $port = $1;

  # nothing found
  if (! $port) {
    print "No PORT parameter found in LOCAL LISTENER output!\n";
    return( (undef, undef) );
  }

  # Is it a port?
  # Check for digits at the beginning.
  if ($port =~ /\d{1,5}/) { 
    print "'$port' is a valid number.\n";
  } else {
    print "'$port' is not a valid number!\n";
    return( (undef, undef) );
  }

  return( ($host, $port) );

} # get_ip_port


# -------------------------------------------------------------------
sub part_1_pdb {
  # Oracle version, components (what is installed), features, options, opatch lsinventory, environment variables

  title(sub_name());

  my $sql = "";
  my $txt = "";
  my @L = ();

  my $dt = iso_datetime();

  $HtmlReport->add_heading(1, "Oracle Pluggable Database Information Report");
  $HtmlReport->add_paragraph('p', "Generated: $dt");

  $HtmlReport->set_local_anchor_list();

  if ($ORACLE_DBSTATUS ne "OPEN") {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS only allow the restricted evaluation of this section!");
  }

  # -----
  $sql = "select 'oracle version', version from v\$instance;";

  if (! do_sql($sql)) {return(0)}
  $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  # e.g. 10.1.0.3.0, 10.2.0.3.0
  ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO) = split(/\./, $ORACLE_VERSION);

  # -----
  # VERSION_FULL is only available for Oracle 19
  # Refresh the version to the full version like 19.7.0.0
  # Overwrite the previous values.

  if ($ORA_MAJOR_RELNO >= 19 ) {
    $sql = "select 'oracle full version', version_full from v\$instance;";
    if (! do_sql($sql)) {return(0)}
    $ORACLE_VERSION = trim(get_value($TMPOUT1, $DELIM, "oracle full version"));
    ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO) = split(/\./, $ORACLE_VERSION);
  }

  # -----
  if ($ORACLE_DBSTATUS ne "OPEN") {
    $sql = "
      select 'cdb', host_name, instance_name from v\$instance;
      select 'pdb1', con_id, name, dbid, TO_CHAR(CREATION_TIME,'YYYY-MM-DD HH24:MI:SS'), open_mode, max_size, to_char(open_time, 'YYYY-MM-DD HH24:MI:SS') from v\$pdbs;";

  } else {

    $sql = "
      select 'cdb', host_name, instance_name from v\$instance;
      select 'pdb1', con_id, name, dbid, TO_CHAR(CREATION_TIME,'YYYY-MM-DD HH24:MI:SS'), open_mode, max_size, to_char(open_time, 'YYYY-MM-DD HH24:MI:SS') from v\$pdbs;
      select 'pdb2', force_logging, refresh_mode, REFRESH_INTERVAL, guid, status from dba_pdbs;
  ";
  }

  if (! do_sql($sql)) {return(0)}

  my $my_hostname  = trim(get_value($TMPOUT1, $DELIM, "cdb", 2));
  my $my_cdb_name  = trim(get_value($TMPOUT1, $DELIM, "cdb", 3));

  my $my_con_id    = trim(get_value($TMPOUT1, $DELIM, "pdb1", 2));
  my $my_pdb_name  = trim(get_value($TMPOUT1, $DELIM, "pdb1", 3));
  my $my_dbid      = trim(get_value($TMPOUT1, $DELIM, "pdb1", 4));
  my $my_created   = trim(get_value($TMPOUT1, $DELIM, "pdb1", 5));
  my $my_open_mode = trim(get_value($TMPOUT1, $DELIM, "pdb1", 6));
  my $my_max_size  = trim(get_value($TMPOUT1, $DELIM, "pdb1", 7));
  my $my_open_time = trim(get_value($TMPOUT1, $DELIM, "pdb1", 8));

  my ($my_force_log, $my_refresh_mode, $my_refresh_int, $my_guid, $my_status) = ("unknown", "unknown", "unknown", "unknown", "unknown");

  if ($ORACLE_DBSTATUS ne "OPEN") {
    # leave all values to 'unknown'
    print "Values from dba_pds are not available\n";
  } else {
    $my_force_log    = trim(get_value($TMPOUT1, $DELIM, "pdb2", 2));
    $my_refresh_mode = trim(get_value($TMPOUT1, $DELIM, "pdb2", 3));
    $my_refresh_int  = trim(get_value($TMPOUT1, $DELIM, "pdb2", 4));
    $my_guid         = trim(get_value($TMPOUT1, $DELIM, "pdb2", 5));
    $my_status       = trim(get_value($TMPOUT1, $DELIM, "pdb2", 6));
  }

  # $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  # # e.g. 10.1.0.3.0, 10.2.0.3.0
  # ($ORA_MAJOR_RELNO, $ORA_MAINTENANCE_RELNO, $ORA_APPSERVER_RELNO, $ORA_COMPONENT_RELNO, $ORA_PLATFORM_RELNO) = split(/\./, $ORACLE_VERSION);

  append2inventory("# date generated", $dt);
  append2inventory("DBENGINE", "Oracle");

  append2inventory("ORACLEVERSION", $ORACLE_VERSION);
  append2inventory("DBVERSION", $ORACLE_VERSION);

  my $my_instance = trim(get_value($TMPOUT1, $DELIM, "instance name"));
  append2inventory("ORACLEINSTANCE", $my_pdb_name);
  append2inventory("DBINSTANCE", $my_pdb_name);
  append2inventory("ORACLEDBID", $my_dbid);

  my ($my_instance_ip, $my_instance_port) = get_ip_port();
  if ( $my_instance_ip ) {
    if ( $my_instance_port ) {
      append2inventory("DBINSTANCEIP", $my_instance_ip);
      append2inventory("DBINSTANCEPORT", $my_instance_port);
    }
  }

  append2inventory("ORACLEHOST", $my_hostname);
  append2inventory("DBHOST", $my_hostname);

  $HtmlReport->add_heading(2, "General Info", "_default_");

  # PDB info
  my $aref;
  if ($my_refresh_mode =~ /NONE/) {
    $aref = [
      "PDB name             ! $my_pdb_name"
    , "Oracle Full Version  ! $ORACLE_VERSION"
    , "PDB guid             ! $my_guid"
    , "PDB DBID             ! $my_dbid"
    , "PDB created          ! $my_created"
    , "PDB startup at       ! $my_open_time"
    , "PDB status           ! $my_status"
    , "Force Logging        ! $my_force_log"
    , "Refresh mode         ! $my_refresh_mode"
    , "CDB instance name    ! $my_cdb_name"
    , "Running on host      ! $my_hostname"
    , "CDB database status  ! $ORACLE_DBSTATUS"
    , "CDB database role    ! $ORACLE_DBROLE"
    ];
  } else {
    # Refresh Mode is not NONE => is active

    $aref = [
      "PDB name             ! $my_pdb_name"
    , "Oracle Full Version  ! $ORACLE_VERSION"
    , "PDB guid             ! $my_guid"
    , "PDB DBID             ! $my_dbid"
    , "PDB created          ! $my_created"
    , "PDB startup at       ! $my_open_time"
    , "PDB status           ! $my_status"
    , "Force Logging        ! $my_force_log"
    , "Refresh mode         ! $my_refresh_mode"
    , "Refresh interval     ! $my_refresh_int"
    , "CDB instance name    ! $my_cdb_name"
    , "Running on host      ! $my_hostname"
    , "CDB database status  ! $ORACLE_DBSTATUS"
    , "CDB database role    ! $ORACLE_DBROLE"
    ];
  }

  $HtmlReport->add_table($aref, "!", "LL", 0);

  $HtmlReport->add_goto_top("top");

  # ------
  # Options pack usage

  # Complete output for Oracle 19+
  # (Not sure if it works for Oracle 18)
  if ( oracle_3d_version(4) ge "019.000.000.000" ) {
    options_packs_usage_statistics19();
  }


  # -----
  # Additional patch information from registry$history

  # Although this normally shows the same results as for the CDB, 
  # the patches are normally applied a bit later for the pdbs.

  if ($ORACLE_DBSTATUS eq "OPEN") {
    $sql = "
      select
          to_char(action_time, 'YYYY-MM-DD HH24:MI:SS')
        , action
        , namespace
        , version
        , bundle_series
        , comments
      from registry\$history
      order by 1
      ;

    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    # prepend a title line
    unshift(@L, "timestamp  $DELIM  action  $DELIM  namespace  $DELIM  version $DELIM bundle_series $DELIM comments ");

    $HtmlReport->add_heading(2, "Registry History", "_default_");
    $HtmlReport->add_table(\@L, $DELIM, "LLLLLL", 1);
    $HtmlReport->add_paragraph('p', "The 'version' often contains expressions like: 19.8.0.0.200714OJVMRU where 200714 is the date of the patch: 2020-07-14.");
    $HtmlReport->add_goto_top("top");
  } else {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  }

  return(1);

} # part_1_pdb


# -------------------------------------------------------------------
sub part_2_pdb {
  # Parameters,  NLS settings

  title(sub_name());

  my @L = ();
  my $txt = "";
  my $sql = "";

  # -----
  # Parameters

  # my $sql = "
  #   select rtrim(name)
  #   , rtrim(value)
  #   , rtrim(isdefault)
  #   from v\$parameter
  #   order by name;
  # ";

  $sql = "
    select 
      name
    , display_value
    , ismodified
    , isdefault
    , DESCRIPTION
    from V\$SYSTEM_PARAMETER2
    where con_id = $CURRENT_CON_ID
    order by name;
  ";


  if (! do_sql($sql)) {return(0)}

  @L = ();
  get_value_lines(\@L, $TMPOUT1);

  unshift(@L, "parameter  $DELIM  value $DELIM  is modified $DELIM is default $DELIM  description");

  $HtmlReport->add_heading(2, "Parameters", "_default_");
  # if ( oracle_3d_version(2) eq "012.002" ) {
  #   $HtmlReport->add_paragraph('p', "In Oracle 12.2 there may be some underscore parameters added because the STATISTICS_LEVEL was changed. This is expected behavior, see: When Changing STATISTICS_LEVEL Parameter On 12.2.0.1, Few Extra Parameters Are Also Added To Spfile (Doc ID 2282692.1)");
  # }
  $HtmlReport->add_table(\@L, $DELIM, "LLLLL", 1);
  $HtmlReport->add_goto_top("top");


  # -----
  # database and instance NLS parameters

  # At least the instance NLS parameters seem to be modifiable in PDBs.
  # So show them (all).

  if ($ORACLE_DBSTATUS eq "OPEN") {

    # Use concatenation to avoid the substitution question
    $sql = "
      SELECT
         db.parameter as parameter,
         nvl(db.value, '&' || 'nbsp;') as database_value,
         nvl(i.value, '&' || 'nbsp;') as instance_value
      FROM nls_database_parameters db
      LEFT JOIN nls_instance_parameters i ON i.parameter = db.parameter
      ORDER BY parameter;
    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    # Insert title
    unshift(@L, "NLS PARAMETER  $DELIM  NLS_DATABASE_PARAMETERS   $DELIM   NLS_INSTANCE_PARAMETERS");

    $HtmlReport->add_heading(2, "NLS Database and Instance Parameters", "_default_");
    $HtmlReport->add_paragraph('p', "NLS_DATABASE_PARAMETERS show the initially defined values of the NLS parameters for the database. These are fixed at the database level and cannot be changed, some can be overridden by NLS_INSTANCE_PARAMETERS. NLS_CHARACTERSET and NLS_NCHAR_CHARACTERSET can NOT be changed, though!");
    $HtmlReport->add_paragraph('p', "NLS_INSTANCE_PARAMETERS show the current NLS instance parameters that have been explicitly set to override the invariable NLS_DATABASE_PARAMETERS. This is the base from which the NLS_SESSION_PARAMETRS are derived (the effective parameters for the user session). Note that enviroment variables like NLS_LANG which can be effective in a user session do overwrite the NLS_INSTANCE_PARAMETERS.");
    $HtmlReport->add_table(\@L, $DELIM, "LLL", 1);
    $HtmlReport->add_goto_top("top");
  } else {
    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
  }

} # part_2_pdb


# -------------------------------------------------------------------
sub security_settings_pdbs {
  # Security Settings

  title(sub_name());

  $HtmlReport->add_heading(2, "Security Settings", "_default_");
  $HtmlReport->add_heading(3, "Unified Auditing", "_default_");

  if ( $ORA_MAJOR_RELNO < 19 ) {
    $HtmlReport->add_paragraph('p', "This section is only supported for Oracle 19 (and later).");
    $HtmlReport->add_goto_top("top");

    print sub_name() . ": is only supported for Oracle 19 and later\n";
    return(0);
  }

  my @L = ();
  my $txt = "";
  my $sql = "";

  # -----
  # Check for UNIFIED AUDITING

  $sql = "
    select 'unified_auditing', upper(value)
    from v\$option
    where lower(parameter) = 'unified auditing';
  ";

  if (! do_sql($sql)) {return(0)}

  my $V = trim(get_value($TMPOUT1, $DELIM, "unified_auditing"));
  print "Unified Auditing=$V\n";

  if ($V !~ /TRUE/i ) {
    $HtmlReport->add_paragraph('p', "Unified Auditing is not enabled.");
    $HtmlReport->add_goto_top("top");
    return(1);
  }
  $HtmlReport->add_paragraph('p', "Unified Auditing is enabled.");

  $HtmlReport->add_paragraph('p', "Keep in mind that the following initialization parametes have NO EFFECT when unified auditing is enabled: AUDIT_TRAIL, AUDIT_FILE_DEST, AUDIT_SYS_OPERATIONS and AUDIT_SYSLOG_LEVEL.");

  # -----
  # Get enabled Auditing Policies

  if ($ORACLE_DBSTATUS eq "OPEN") {

    # Oracle 19 only, older versions are not supported

    $sql = "
      select
        POLICY_NAME, ENABLED_OPTION, ENTITY_NAME, ENTITY_TYPE, SUCCESS, FAILURE
      FROM AUDIT_UNIFIED_ENABLED_POLICIES
      order by 1;
    ";

    if (! do_sql($sql)) {return(0)}

    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    unshift(@L, "POLICY_NAME  $DELIM ENABLED_OPTION $DELIM  ENTITY_NAME  $DELIM  ENTITY_TYPE  $DELIM  SUCCESS  $DELIM  FAILURE");

    $HtmlReport->add_table(\@L, $DELIM, "LLLLLL", 1);

    # -----
    # Check if there are policies listed more than once.
    # That indicates (AFAIK currently) inherited policies from the cdb. 
    # (tested on Oracle 19.9)

    $sql = "
      select POLICY_NAME  FROM AUDIT_UNIFIED_ENABLED_POLICIES 
      group by POLICY_NAME 
      having count(POLICY_NAME) > 1;
    ";

    if (! do_sql($sql)) {return(0)}
    @L = ();
    get_value_lines(\@L, $TMPOUT1);

    my $in_clause = "";

    foreach my $polname (@L) {
      my @E = split($DELIM, $polname);
      @E = map(trim($_), @E);

      if ($in_clause) { $in_clause .= "," }
      $in_clause .= "'$E[0]'";
    }

    if ($in_clause) {
      # That select does not contain all columns, 
      # further inspection may be necessary.
      # This is just for informational purposes.

      $sql = "
        select POLICY_NAME           
        , AUDIT_OPTION          
        , AUDIT_OPTION_TYPE     
        , COMMON                
        , INHERITED             
        , AUDIT_ONLY_TOPLEVEL   
        from audit_unified_policies 
        WHERE  policy_name IN ($in_clause)
          AND inherited = 'YES'
        ORDER BY 1,2,3,4,5,6;
      ";

      if (! do_sql($sql)) {return(0)}

      @L = ();
      get_value_lines(\@L, $TMPOUT1);

      $HtmlReport->add_heading(4, "Inherited Audit Policies", "_default_");

      $HtmlReport->add_paragraph('p', "(Inherited from the CDB)");

      unshift(@L, "POLICY_NAME  $DELIM AUDIT_OPTION $DELIM  AUDIT_OPTION_TYPE  $DELIM  COMMON  $DELIM  INHERITED  $DELIM  AUDIT_ONLY_TOPLEVEL");

      $HtmlReport->add_table(\@L, $DELIM, "LLLLLL", 1);

      $HtmlReport->add_paragraph('p', "This table does not contain all columns, further inspection of table AUDIT_UNIFIED_POLICIES may be necessary.");

    # } else {
    #   print "No inherited audit policies found.\n";
    }

    $HtmlReport->add_goto_top("top");

  } else {

    $HtmlReport->add_paragraph('p', "Database role $ORACLE_DBROLE and status $ORACLE_DBSTATUS do not allow the evaluation of this section!");
    $HtmlReport->add_goto_top("top");

  }

  return(0);

} # security_settings_pdbs



# ===================================================================
# -------------------------------------------------------------------
sub send2uls {
  # send2uls(<filename>);
  #
  # Write the report to a file and send that to ULS.

  title(sub_name());

  my ($filename) = @_;

  my $uls_detail = "Oracle Database Information Report";
  my $alias_filename = "ora_dbinfo_${MY_HOST}_$ENV{'ORACLE_SID'}.html";
  if ( $CURRENT_PDB ) {
    $alias_filename = "ora_dbinfo_${MY_HOST}_$ENV{'ORACLE_SID'}_" . lc($CURRENT_PDB) . ".html";
  }
  my $compress = "none";

  # compress the file, if possible
  if ( $CFG{"ORA_DBINFO.BZIP_THE_REPORT"} ) { $compress = "bzip2" }
  if ( $CFG{"ORA_DBINFO.GZIP_THE_REPORT"} ) { $compress = "gzip" }
  if ( $CFG{"ORA_DBINFO.XZ_THE_REPORT"}   ) { $compress = "xz" }

  my $new_filename = $HtmlReport->save2file($filename, $compress, 'FORCE');
  if (! $new_filename ) {
    output_error_message(sub_name() . ": Error: Cannot process file '$filename' correctly!");
    return(undef);
  }
  # print "new_filename=$new_filename\n";
  push(@TEMPFILES, $new_filename);

  # Has the extension changed? (Because of compression)
  my ($new_filename_ext) = $new_filename =~ /(\.[^.]+)$/;
  my ($alias_filename_ext) = $alias_filename =~ /(\.[^.]+)$/;

  # print "alias_filename=$alias_filename\n";
  if ( $new_filename_ext ne $alias_filename_ext ) { $alias_filename .= $new_filename_ext }
  # print "alias_filename=$alias_filename\n";

  if ($CFG{"ORA_DBINFO.AS_SERVER_DOC"} ) {
    # Send the report as server documentation.
    # The name must contain the SID to distinguish the instances.
    my $server_doc_name = "${IDENTIFIER}_$ENV{'ORACLE_SID'}";
    if ( $CURRENT_PDB ) {
      $server_doc_name = "${IDENTIFIER}_$ENV{'ORACLE_SID'}_" . lc($CURRENT_PDB);
    }

    uls_server_doc({
        name        => $server_doc_name
      , description => $uls_detail
      , filename    => $new_filename
      , rename_to   => $alias_filename
    });
  }

  if ($CFG{"ORA_DBINFO.AS_VALUE"} ) {
    # Send the report in the Oracle DB [<sid>] section.
    # The name can be invariable, the document is stored under its section, 
    # which contains the SID already.

    uls_file({
        teststep  => $IDENTIFIER
      , detail    => $uls_detail
      , filename  => $new_filename
      , rename_to => $alias_filename
   });
  }

} # send2uls



# -------------------------------------------------------------------
sub sendinventory2uls {
  # sendinventory2uls(<filename>);
  #
  # Write the report to a file and send that to ULS.

  title(sub_name());

  my ($filename) = @_;

  # DBENGINE, DBVERSION, .. new from 2017-01-11
  my $description = "# Inventory of an Oracle Database:
# -----
# DBENGINE;Oracle
# Oracle software version
# ORACLEVERSION;<version>
# ORACLEVERSION;11.2.0.2.0
# DBVERSION;11.2.0.2.0
# -----
# Name of the Oracle database instance
# ORACLEINSTANCE;<orcl>
# DBINSTANCE;<orcl>
# -----
# IP address of database instance
# DBINSTANCEIP; 10.11.12.13
# -----
# Hostname on which the Oracle database runs
# ORACLEHOST;<hostname>
# DBHOST;<hostname>
# -----
# List of all installed Oracle components
# ORACLECOMPONENT;<component>;<version>
# ORACLECOMPONENT;Oracle Expression Filter;11.2.0.2.0
# -----
# List of all installed Oracle features
# ORACLEFEATURE;<feature>;<version>;<number of times used> 
# ORACLEFEATURE;AWR Baseline;11.2.0.2.0;0
# -----
# List of all used (and only these), extra chargeable options, based on the options_packs_usage_statistics.sql, MOS Note 1317265.1
# ORACLEOPTIONUSAGE;<option>
# ORACLEOPTIONUSAGE;Provisioning and Patch Automation Pack for Database
# -----
# List of all installed patches as found by 'opatch lsinventory'
# ORACLEPATCH;<patch_number>
# ORACLEPATCH;7154843
";

  print "----- inventory -----\n";
  print "$description\n";
  print "$INVENTORY\n";
  print "---------------------\n";

  if (! open(OUTFILE, ">", $filename)) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for writing. $!");
    return(0);
  }

  print OUTFILE $description, "\n";
  print OUTFILE $INVENTORY, "\n";

  if (! close(OUTFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(0);
  }

  my $orasid = lc($ENV{"ORACLE_SID"});

  # Send the inventory as server documentation

  my $server_doc_name = "Inventory-Database-Oracle-$orasid";
  my $rename_to       = "Inventory-Database-Oracle-$MY_HOST-$orasid.csv";

  if ( $CURRENT_PDB ) {
    my $orapdb = lc($CURRENT_PDB);
    $server_doc_name = "Inventory-Database-Oracle-$orasid-$orapdb";
    $rename_to       = "Inventory-Database-Oracle-$MY_HOST-$orasid-$orapdb.csv";
  }

  uls_server_doc({
      hostname    => $MY_HOST
    , name        => $server_doc_name
    , description => $description
    , filename    => $filename
    , rename_to   => $rename_to
  });
  #                  "Inventory-Database-" 
  #                  is the agreement for all database inventory files
  #                  also from other databases like MySQL, PostgreSQL, Informix

} # sendinventory2uls



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

my $initdir = $ENV{"TMP"} || $ENV{"TEMP"} || '/tmp';
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

my @Sections = ( "GENERAL", "ORACLE", "ULS", "ORA_DBINFO" );
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
$IDENTIFIER = $CFG{"ORA_DBINFO.IDENTIFIER"} || "_$CURRPROG";
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

# prefix for work files
$WORKFILEPREFIX = "${IDENTIFIER}";
# _ora_dbinfo
#
# If no oracle sid is found in the workfile prefix, then add it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _ora_dbinfo_orcl
#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /oracle/admin/orcl/oracle_tools/var/_ora_dbinfo_orcl

print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

# -------------------------------------------------------------------
# Setting up a lock file to prevent more than one instance of this
# script starting simultaneously.

$LOCKFILE = "${WORKFILEPREFIX}.LOCK";
print "LOCKFILE=$LOCKFILE\n";
push(@TEMPFILES, $LOCKFILE);

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

my $d = iso_datetime($STARTSECS);
$d =~ s/\d{1}$/0/;

set_uls_timestamp($d);

# uls_show();

# ---- Send name of this script and its version
# uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

# Signal handling, do own housekeeping, send data to ULS and exit on most signals.
use sigtrap 'handler' => \&signal_handler, 'normal-signals', 'error-signals';

uls_timing({
    teststep  => $IDENTIFIER
  , detail    => "start-stop"
  , start     => iso_datetime($STARTSECS)
});

# Send the ULS data up to now to have that for sure.
uls_flush(\%ULS);


# Temporary variable to hold the ULS section, 
# will be changed for the PDBs (if any), 
# and set back to default for the final ULS values
# before exiting the script.
my $uls_section = $CFG{"ULS.ULS_SECTION"} ;

# -----
# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
push(@TEMPFILES, $TMPOUT1);
print "TMPOUT1=$TMPOUT1\n";

$TMPOUT2 = "${WORKFILEPREFIX}_2.tmp";
push(@TEMPFILES, $TMPOUT2);
print "TMPOUT2=$TMPOUT2\n";

$HTMLOUT1 = "${WORKFILEPREFIX}_1.html";
push(@TEMPFILES, $HTMLOUT1);
print "HTMLOUT1=$HTMLOUT1\n";

$ERROUTFILE = "${WORKFILEPREFIX}_errout.log";
push(@TEMPFILES, $ERROUTFILE);
print "ERROUTFILE=$ERROUTFILE\n";

print "DELIM=$DELIM\n";

# -----
# sqlplus command

# Check, if the sqlplus command has been redefined in the configuration file.
$SQLPLUS_COMMAND = $CFG{"ORACLE.SQLPLUS_COMMAND"} || $SQLPLUS_COMMAND;

# -----
# Set the documentation from behind __END__.
# De-reference the return value to the complete hash.
%TESTSTEP_DOC = %{doc2hash(\*DATA)};

# -----
# Perhaps, corporate settings are set up in the configuration file(s).

my $css_style = $CFG{"ORA_DBINFO.CSS_STYLE"};
if ( $css_style ) { $HtmlReport->set_style("$css_style") }

# -------------------------------------------------------------------
# The real work starts here.
# ------------------------------------------------------------

if (! oracle_available() ) {
  output_error_message("$CURRPROG: Error: Oracle database is not available => aborting script.");
  end_script(1);
}


# -----
# Build everything in hash? array? xml? line-by-line?

# -----
# Oracle version, components (what is installed), options, 
# opatch lsinventory, environment variables

part_1();

# -----
# Parameters,  NLS settings
part_2();

# -----
# Statistics preferences

stat_prefs ();

# -----
# Security Settings

security_settings();

# -----
# RAC
part_4();

# -----
# SGA, shared pool, buffer caches, pga
part_5();

# -----
# Online Redo Logs
part_6();

# -----
# ASM
part_7();

# -----
# Tablespaces, datafiles
if ($ORA_MAJOR_RELNO <= 10) {
  part_8_til10();
} else {
  part_8_11plus();
}

# -----
# fast recovery area
part_9();


# -----
# pfile/spfile, control.txt
part_10();


# -----
# services

services();

# -----
# listener.ora, tnsnames.ora, sqlnet.ora
part_11();


# -----
# Continue here with more tests.



# The real work ends here.
# -------------------------------------------------------------------

send2uls($HTMLOUT1);
# print $REPORT, "\n";

# -----
# 2021-01-06: This is disabled as from version 0.48 on
# sendinventory2uls($TMPOUT2);
# print "$INVENTORY\n";

# -------------------------------------------------------------------
send_doc($CURRPROG, $IDENTIFIER);




# ==================================================================
# CDB/PDB

if ($#PDB_LIST >= 0) {
  # Remember: $#ARRAY returns the max index of the array, which starts at zero!

  print "List of PDBs and CON_IDs: ", join(",", @PDB_LIST), "\n";

  # -----
  # Keep that, add pdb name for each pdb in loop below
  my $base_WORKFILEPREFIX = $WORKFILEPREFIX;

  foreach my $p (@PDB_LIST ) {
    # pdb_name|con_id

    ($CURRENT_PDB, $CURRENT_CON_ID) = split('\|', $p);
    # print "p=$p, CURRENT_PDB=$CURRENT_PDB, CURRENT_CON_ID=$CURRENT_CON_ID\n";
    print "Gathering info for pluggable database '$CURRENT_PDB' (CON_ID: $CURRENT_CON_ID)\n";

    my $pdb_lc = lc($CURRENT_PDB);

    # -----
    # Temporary variable to hold the ULS section 
    # for the currently selected PDB.
    $uls_section = $CFG{"ULS.ULS_SECTION_PDB"} ;
    # (just set a default, if no entry is found in conf)
    if ( ! $uls_section ) { $uls_section = "Oracle PDB [__PDB_NAME__]" }
    #
    # See the configuration file:
    # vi /etc/oracle_optools/standard.conf
    # ULS_SECTION_PDB = Oracle PDB [__PDB_NAME__]

    # Replace placeholder with PDB name
    $uls_section =~ s/__PDB_NAME__/$pdb_lc/g;

    print "Setting ULS_SECTION to: $uls_section\n";

    set_uls_section($uls_section);

    # -----
    $WORKFILEPREFIX = $base_WORKFILEPREFIX . "_$pdb_lc";
    print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

    $HTMLOUT1 = "${WORKFILEPREFIX}_1.html";
    push(@TEMPFILES, $HTMLOUT1);
    print "HTMLOUT1=$HTMLOUT1\n";

    # -----
    # This keeps the complete report for this pdb (as html)
    # (reset the document)
    $HtmlReport = HtmlDocument->new();

    # Set the default css styles, see the appropriate section in the
    # conf file to adjust the style to your taste.

    $HtmlReport->set_style("
      table {
          border-collapse: collapse;
          border: 1px solid darkgrey;
          margin-top: 5px;
      }
      th, td {
          border: 1px solid darkgrey;
          padding: 5px;
      }
      th { background-color: #dbe4f0; }
      pre  {background-color: whitesmoke; }
    ");

    $css_style = $CFG{"ORA_DBINFO.CSS_STYLE"};
    if ( $css_style ) { $HtmlReport->set_style("$css_style") }

    $INVENTORY = "";

    part_1_pdb();

    # Parameters, NLS settings
    part_2_pdb();

    # Audit policies
    security_settings_pdbs();

    # Tablespaces (default sql commands work)
    part_8_11plus();

    # PDB specific services
    services();


    ## -----
    ## Continue here with more pdb tests.


    # The real work ends here.
    # -------------------------------------------------------------------

    send2uls($HTMLOUT1);
    # print $REPORT, "\n";

    # 2021-01-06: This is disabled as from version 0.48 on
    # sendinventory2uls($TMPOUT2);
    # print "$INVENTORY\n";

    # -------------------------------------------------------------------
    send_doc($CURRPROG, $IDENTIFIER);


  } # foreach pdb


} # is_cdb, has pdbs


# The real work ends here.
# -------------------------------------------------------------------

# The final message and runtime is only sent for the cdb.

$uls_section = $CFG{"ULS.ULS_SECTION"} ;
set_uls_section($uls_section);

if ($MSG eq "OK") {end_script(0)}

end_script(1);

# -----
# Script should never arrive here.
exit(255);


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
*ora_dbinfo.pl
==============

This script gathers a lot of information about an Oracle database instance.

This script is part of the Oracle OpTools and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org

This script builds a text report about many database characteristics, settings and quantity information. An inventory file in the supported inventory file format is generated. Both are sent to the ULS.

This script may not cover everything that YOU are interested in, especially no RAC specifics (currently), but it gives quite an overview. Collected information e.g.;
  the name and some settings of the instance, 
  the installed Oracle components,
  a list of used options, 
  a list of installed patches as reported by opatch, 
  a list of all parameters, 
  the NLS settings of the database, 
  the size and usage of the SGA, buffer caches, shared pool, PGA and tablespaces,
  the size and usage of the fast recovery area (if used), 
  the contents of the [s]pfile, sqlnet.ora, listener.ora and tnsnames.ora, 
  a textual output of the control file.

You find the inventory information in ULS:
main menu -- administration -- documentation -- server documentation -- <domain> -- <server>

This script is run by a calling script, typically 'ora_dbinfo', that sets the correct environment before starting the Perl script ora_dbinfo.pl. The 'ora_dbinfo' in turn is called by the cron daemon on Un*x or through a scheduled task on Wind*ws. The script generates a log file and several files to keep data for the next run(s). The directory defined by WORKING_DIR in the oracle_tools.conf configuration file is used as the destination for those files.

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

Oracle Database Information Report:
  An html file (probably compressed) that contains the report.
  Depending on the user configuration, the report may instead appear 
  at the server documentation section for that server.

# exit value:
#   Is 0 if the script has finished without errors,
#   1 if errors have occurred. This is intended to monitor the
#   proper execution of this script.
# 

Copyright 2011 - 2021, roveda

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

