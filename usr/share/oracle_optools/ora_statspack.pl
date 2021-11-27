#!/usr/bin/perl
#
# ora_statspack.pl - make STATSPACK snapshots and generate reports
#
# ---------------------------------------------------------
# Copyright 2013 - 2021, roveda
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
# along with Oracle OpTools. If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   perl ora_statspack.pl <configuration file> <mode> [<report_parameter_name>]
#
# ---------------------------------------------------------
# Description:
#   This script takes a statspack snapshot which is saved to a table.
#   Old snapshots are deleted, after the SNAPSHOT_RETENTION defined
#   in the configuration file. iNothing is done, if the defined
#   STATSPACK_OWNER is not present.
#
#   This script generates a statspack report based on the 
#   existing statspack snapshots. The time ranges and weekdays 
#   are defined in the conf file as the given <report_parameter_name>.
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
# 2013-04-07      roveda      0.01
#   Creation
#
# 2013-08-16      roveda      0.02
#   Merged with ora_statspack_snapshot.pl and modified to match
#   the new single configuration file.
#
# 2014-01-18      roveda      0.03
#   Debugged the purge_snapshots(), that did not work if the 
#   database was recovered because the dbid and instance_number 
#   was not used in some sqls. Added DBID and INSTNO as globals.
#
# 2014-07-18      roveda      0.04
#   Now supports time intervals over midnight 
#   (like 16:00 - 06:00, and 08:00 - 08:00).
#   Now all sql commands use bind variables instead of constant expressions.
#
# 2014-11-23      roveda      0.05
#   Changed variable 'in' to 'instno'.
#
# 2015-02-14      roveda      0.06
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#
# 2016-03-09      roveda      0.07
#   The "exit value" is no longer sent to ULS.
#
# 2016-03-18      roveda      0.08
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.09
#   Added the SID to the WORKFILEPREFIX.
#
# 2016-06-14      roveda      0.10
#   Added the mode (SNAPSHOT/REPORT) to the WORKFILEPREFIX.
#
# 2017-02-02      roveda      0.11
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.12
#   Added signal handling.
#
# 2017-03-21      roveda      0.13
#   Fixed the broken support of sid specific configuration file.
#
# 2019-07-13      roveda      0.14
#   No execution and no error when running as physical standby.
#
# 2021-11-27      roveda      0.15
#   Added full UTF-8 support. Thanks for the boilerplate
#   https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129
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

my $VERSION = 0.15;

# ===================================================================
# The "global" variables
# ===================================================================

# Usage
my $USAGE = "perl ora_statspack.pl <configuration file> <mode> [<report_parameter_name>]";

# Name of this script.
my $CURRPROG = "";

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';

my $WORKFILEPREFIX;
my $TMPOUT1;
my $TMPOUT2;
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

# Holds the __$CURRPROG or $CFG{"IDENTIFIER"} just for easy usage.
my $IDENTIFIER;

# This hash keeps the documentation for the teststeps.
my %TESTSTEP_DOC;

# Keeps the version of the oracle software
my $ORACLE_VERSION = "";

# dbid and instno of the current database
# (after cloning a databse, there may be left-over snapshots of other dbids/instnos)
my $DBID = "";
my $INSTNO = "";

# The hostname where this script runs on
my $MY_HOST = "";

# Mode: SNAPSHOT / REPORT
my $MODE = "";

# Name of parameter in configuration file for report definition
my $REPORT = "";



# ===================================================================
# The subroutines
# ===================================================================

# ------------------------------------------------------------
sub signal_handler {
  # first parameter is the signal, like HUP INT QUIT ABRT ALRM TERM.

  title(sub_name());

  output_error_message("$CURRPROG: Signal $_[0] catched! Clean up and abort script.");

  clean_up($TMPOUT1, $TMPOUT2, $LOCKFILE);

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
  # <sql command>
  # Just executes the given sql statement against the current database instance.
  # If <verbose> is a true expression (e.g. a 1) the sql statement will
  # be printed to stdout.

  # connect / as sysdba

  # Set nls_territory='AMERICA' to get decimal points.

  my $sql = "
    set echo off
    alter session set nls_territory='AMERICA';
    set newpage 0
    set space 0
    set linesize 10000
    set pagesize 0
    set feedback off
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

    spool off;";

  print "\nexec_sql()\n";
  print "SQL: $sql\n";

  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    output_error_message(sub_name() . ": Error: Cannot open pipe to '$SQLPLUS_COMMAND'. $!");
    return(0);   # error
  }
  print CMDOUT "$sql\n";
  if (! close(CMDOUT)) {
    output_error_message(sub_name() . ": Error: Cannot close pipe to sqlplus. $!");
    return(0);
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

  if (exec_sql($_[0])) {
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

  title("Cleaning up");

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

  print "database role=$db_role, status=$db_status\n";

  if ("$db_role, $db_status" eq "PRIMARY, OPEN" ) {
    # role and status is ok, create AWR report
    print "Database role $db_role and status $db_status is ok.\n";

  } elsif ("$db_role, $db_status" eq "PHYSICAL STANDBY, MOUNTED") {
    # role and status is ok, but no AWR report
    return(2);

  } else {
    # role and status is NOT ok, no AWR report, error
    output_error_message(sub_name() . ": Error: the database status is not 'OPEN'!");
    return(0);
  }

  # -----
  # Find some necessary information

  $sql = "
    select 'dbid', dbid from v\$database;
    select 'instance_number', instance_number from v\$instance;
  ";

  if (! do_sql($sql)) {return(0)}

  $DBID = trim(get_value($TMPOUT1, $DELIM, "dbid"));
  $INSTNO = trim(get_value($TMPOUT1, $DELIM, "instance_number"));

  return(1);

} # oracle_available



# -------------------------------------------------------------------
sub has_statspack {
  # Check, if statspack is installed.

  title(sub_name());

  my $sp_owner = uc($CFG{"ORA_STATSPACK.STATSPACK_OWNER"});

  my $sql = "
    variable ow VARCHAR2(30)
    exec :ow := '$sp_owner'

    variable tn VARCHAR2(30)
    exec :tn := 'STATS%'

    select 'table_count', count(*)
      from dba_tables
      where owner = :ow
        and table_name like :tn
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my $table_count = trim(get_value($TMPOUT1, $DELIM, "table_count"));
  print "table_count of $sp_owner=$table_count\n";

  return($table_count);

} # has_statspack




# -------------------------------------------------------------------
sub take_snapshot {

  title(sub_name());

  my $sp_owner = uc($CFG{"ORA_STATSPACK.STATSPACK_OWNER"});

  my $sql = "EXECUTE $sp_owner.statspack.snap; ";

  if (! do_sql($sql)) {return(0)}

} # take_snapshot


# -------------------------------------------------------------------
sub purge_snapshots {

  title(sub_name());

  my $sql = "";

  my $sp_owner = uc($CFG{"ORA_STATSPACK.STATSPACK_OWNER"});

  # -----
  # Find oldest snap id.

  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    select 'min_snap_id', min(snap_id) 
      from $sp_owner.STATS\$SNAPSHOT
      where DBID            = :dbid
        and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my $OLDEST_SNAP_ID = trim(get_value($TMPOUT1, $DELIM, "min_snap_id"));
  print "SNAP_ID(oldest)=$OLDEST_SNAP_ID\n";

  if ($OLDEST_SNAP_ID !~ /\d+/) {
    print "No snapshots found => nothing to purge.\n";
    return(0);
  }


  # -----
  # Find max snap id which is older than 5 days

  my $keep_for_days = $CFG{"ORA_STATSPACK.SNAPSHOT_RETENTION"};
  if ($keep_for_days !~ /\d+/) {
    print STDERR sub_name() . ": Error: SNAPSHOT_RETENTION is not numeric in configuration file, using default of '5'.\n";
    $keep_for_days = 5;
  }
  print "Used snapshot retention time is: $keep_for_days days.\n";

  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    variable kfd number
    exec :kfd := $keep_for_days

    select 'snap_id', max(snap_id) from $sp_owner.STATS\$SNAPSHOT
      where snap_time <= sysdate - :kfd
        and DBID            = :dbid
        and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my $UPTO_SNAP_ID = trim(get_value($TMPOUT1, $DELIM, "snap_id"));
  print "SNAP_ID (older than $keep_for_days days)=$UPTO_SNAP_ID\n";

  if ($UPTO_SNAP_ID !~ /\d+/) {
    print "No snapshots found older than $keep_for_days days => nothing to purge.\n";
    return(0);
  }

  # -----
  # Purge old snapshots

  print "Purging snapshots $OLDEST_SNAP_ID to $UPTO_SNAP_ID.\n";

  # Use the direct call to the purge procedure,
  # see $ORACLE_HOME/rdbms/admin/sppurge.sql

  $sql = "
    begin
      statspack.purge(
         i_begin_snap      => $OLDEST_SNAP_ID
       , i_end_snap        => $UPTO_SNAP_ID
       , i_snap_range      => true
       , i_extended_purge  => false
       , i_dbid            => $DBID
       , i_instance_number => $INSTNO
       );
    end;
    /

  ";

  if (! do_sql($sql)) {return(0)}


} # purge_snapshots



# -------------------------------------------------------------------
sub do_reports {

  title(sub_name());

  # This will get more complex over time.

  print "Report definition: ORA_STATSPACK.$REPORT = " . $CFG{"ORA_STATSPACK.$REPORT"} . "\n";
  # my $report = $CFG{"REPORT"};
  my $report = $CFG{"ORA_STATSPACK.$REPORT"};
  # 03:00-04:00
  # 08:00 - 17:00
  # 01:00 - 06:00, 06:00 - 12:00, 12:00 - 18:00

  # Remove all blanks
  $report =~ tr/ //ds;

  my @REPORTS = split(",", $report);

  foreach my $r (@REPORTS) {
    print "Do report for: $r\n";
    do_report($r);
  }

} # do_reports


# -------------------------------------------------------------------
sub do_report {
  # do_report(<time_range>);

  title(sub_name());

  my $sql = "";

  my $sp_owner = uc($CFG{"ORA_STATSPACK.STATSPACK_OWNER"});

  my ($from, $to) = split("-", $_[0]);

  my ($day1, $day2);
  my ($rep_day1, $rep_time1, $first_snap);
  my ($rep_day2, $rep_time2, $last_snap);

  # -----
  # Find the last day having a snapshot older than 'to' hours

  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    variable tohhmm varchar2(30)
    exec :tohhmm := '$to'

    select 'day', max(to_char(snap_time, 'yyyy-mm-dd'))
    from $sp_owner.STATS\$SNAPSHOT
    where to_char(snap_time, 'HH24:MI') >= :tohhmm
      and DBID            = :dbid
      and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  $day2 = trim(get_value($TMPOUT1, $DELIM, "day"));
  print "DAY(to)=$day2\n";

  if ($day2 !~ /\d+/) {
    print "Could not find any day for a snapshot older than $to => cannot generate report!\n";
    return(0);
  }

  # -----
  # Find the snap id at exactly or the first snap id younger than 'day' and 'to'

  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    variable todt varchar2(30)
    exec :todt := '$day2 $to'

    select 'last_snap', min(snap_id)
    from $sp_owner.STATS\$SNAPSHOT
    where snap_time >= to_date(:todt, 'yyyy-mm-dd HH24:MI')
      and DBID            = :dbid
      and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  $last_snap = trim(get_value($TMPOUT1, $DELIM, "last_snap"));
  print "LAST_SNAP=$last_snap\n";

  if ($last_snap !~ /\d+/) {
    print "Last snap $last_snap is not numeric => cannot generate report!\n";
    return(0);
  }

  # -----
  # Find the exact day and time for that snapshot
  # (for the name of the report)

  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    variable lastsnap number
    exec :lastsnap := $last_snap

    select
      'snap_datetime'
      , to_char(snap_time, 'yyyy-mm-dd')
      , to_char(snap_time, 'HH24MI')
    from $sp_owner.STATS\$SNAPSHOT
    where snap_id         = :lastsnap
      and DBID            = :dbid
      and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  $rep_day2  = trim(get_value($TMPOUT1, $DELIM, "snap_datetime", 2));
  $rep_time2 = trim(get_value($TMPOUT1, $DELIM, "snap_datetime", 3));

  print "End date for report=$rep_day2, time=$rep_time2\n";

  if ($rep_day2 !~ /\d+/) {
    print "Cannot determine the day of the last snap $last_snap => cannot generate report!\n";
    return(0);
  }

  if ($rep_time2 !~ /\d+/) {
    print "Cannot determine the time of the last snap $last_snap => cannot generate report!\n";
    return(0);
  }

  # -----
  # Check if midnight is in between

  $day1 = $day2;
  if ($to le $from) {
    $sql = "
      select 'day1', to_char(to_date('$day2', 'yyyy-mm-dd') - 1, 'yyyy-mm-dd') from dual;
    ";
    if (! do_sql($sql)) {return(0)}
    $day1 = trim(get_value($TMPOUT1, $DELIM, "day1"));
  }

  # -----
  # Find the first snap id at exactly or the first snap id older than 'day' and 'from'


  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    variable day1 varchar2(30)
    exec :day1 := '$day1'

    variable frhhmm varchar2(30)
    exec :frhhmm := '$from'

    select 'first_snap', max(snap_id)
    from $sp_owner.STATS\$SNAPSHOT
    where to_char(snap_time, 'yyyy-mm-dd') <= :day1
      and to_char(snap_time, 'HH24MI')     <= :frhhmm
      and DBID            = :dbid
      and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  $first_snap = trim(get_value($TMPOUT1, $DELIM, "first_snap"));
  print "FIRST_SNAP=$first_snap\n";

  if ($first_snap !~ /\d+/) {
    print "First snap $first_snap is not numeric => cannot generate report!\n";
    return(0);
  }


  # -----
  # Find the exact day and time for that snapshot

  $sql = "
    variable dbid number
    exec :dbid := $DBID

    variable instno number
    exec :instno := $INSTNO

    variable firstsnap number
    exec :firstsnap := $first_snap

    select
      'snap_datetime'
      , to_char(snap_time, 'yyyy-mm-dd')
      , to_char(snap_time, 'HH24MI')
    from $sp_owner.STATS\$SNAPSHOT
    where snap_id         = :firstsnap
      and DBID            = :dbid
      and INSTANCE_NUMBER = :instno
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  $rep_day1  = trim(get_value($TMPOUT1, $DELIM, "snap_datetime", 2));
  $rep_time1 = trim(get_value($TMPOUT1, $DELIM, "snap_datetime", 3));
  print "Begin date for report=$rep_day1, time=$rep_time1\n";

  if ($rep_day1 !~ /\d+/) {
    print "Cannot determine the day of the first snap $first_snap => cannot generate report!\n";
    return(0);
  }

  if ($rep_time1 !~ /\d+/) {
    print "Cannot determine the time of the first snap $first_snap => cannot generate report!\n";
    return(0);
  }

  # -----
  # Generate the report

  # Run the report
  $sql = "
    DEFINE begin_snap=$first_snap
    DEFINE end_snap=$last_snap
    define report_name=$TMPOUT2
    @?/rdbms/admin/spreport.sql

  ";

  if (! do_sql($sql)) {return(0)}

  # Send the statspack report
  uls_file({
    teststep => $IDENTIFIER
   ,detail   => "Statspack Report"
   ,filename => $TMPOUT2
   ,rename_to => $rep_day1 . "_" . $rep_time1 . "-" . $rep_day2 . "_" . $rep_time2 . ".txt"
  });

} # do_report



# -------------------------------------------------------------------


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

# -------------------------------------------------------------------
# Get configuration file contents

# first command line argument
my $cfgfile = $ARGV[0];
print "configuration file=$cfgfile\n";

my @Sections = ( "GENERAL", "ORACLE", "ULS", "ORA_STATSPACK" );
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

# -----
# second(!) command line argument
$MODE = uc($ARGV[1]);
if (! $MODE) {
  print STDERR $CURRPROG . ": Error: no mode given as command line argument!\n";
  exit(2);
}

if ( $MODE ne "REPORT" && $MODE ne "SNAPSHOT" ) {
  print STDERR $CURRPROG . ": Error: You must specify 'SNAPSHOT' or 'REPORT' as command line argument!\n";
  print STDERR $CURRPROG . ": Usage: $USAGE\n";
  exit(2);
}
print "MODE:$MODE\n";

# -----
if ( $MODE eq "REPORT" ) {
  # third command line argument
  $REPORT = $ARGV[2];
  if (! $REPORT) {
    print STDERR $CURRPROG . ": Error: no report specification parameter given as command line argument!\n";
    exit(2);
  }
}


# ----------
# This sets the %ULS to all necessary values
# deriving from %CFG (configuration file),
# environment variables (ULS_*) and defaults.

uls_settings(\%ULS, \%CFG);

print "-- ULS settings:\n";
show_hash(\%ULS, " = ");
print "-----\n";

# ----------
# Check for IDENTIFIER

# Set default
$IDENTIFIER = $CFG{"ORA_STATSPACK.IDENTIFIER"} || $IDENTIFIER;
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

# Prefix for work files.
$WORKFILEPREFIX = "${IDENTIFIER}";
# _ora_statspack
#
# If no oracle sid is found in the workfile prefix, then append it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/i) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _ora_statspack_orcl

# If the mode cannot be found in the workfile prefix, then append it for uniqueness.
if ($WORKFILEPREFIX !~ /$MODE/i) { $WORKFILEPREFIX .= "_" . lc($MODE) }
# _ora_statspack_orcl_snapshot

#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /oracle/admin/orcl/oracle_tools/var/_ora_statspack_orcl

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
$d =~ s/\d{1}$/0/;

set_uls_timestamp($d);

# uls_show();

# ---- Send name of this script and its version
uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

uls_timing({
    teststep  => $IDENTIFIER
  , detail    => "start-stop"
  , start     => iso_datetime($start_secs)
});

# Send the ULS data up to now to have that for sure.
# uls_flush(\%ULS);
# No, do not do that: it will generate ULS data, even if statspack is not activated!

# -----
# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
print "TMPOUT1=$TMPOUT1\n";
$TMPOUT2 = "${WORKFILEPREFIX}_2.tmp";
print "TMPOUT2=$TMPOUT2\n";

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
# Which mode
uls_value($IDENTIFIER, "mode", $MODE, " ");
if ($REPORT) {
  uls_value($IDENTIFIER, "report", $REPORT, " ");
}

# -------------------------------------------------------------------
# The real work starts here.
# ------------------------------------------------------------

my $ret = oracle_available();
if ($ret == 0) {
  output_error_message("$CURRPROG: Error: Oracle database is not available => aborting script.");

  clean_up($TMPOUT1, $TMPOUT2, $LOCKFILE);

  send_runtime($start_secs);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  exit(1);

} elsif ($ret == 2) {
  print "INFO: The database role and database status is not suitable for STATSPACK actions.\n";
  clean_up($TMPOUT1, $TMPOUT2, $LOCKFILE);

  send_runtime($start_secs);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  # Do not flush anything to ULS, be silent.
  # uls_flush(\%ULS);

  exit(0);
}


my $DO_FLUSH = 1;

if (has_statspack()) {

  if ( $MODE eq "REPORT" ) {

    # -----
    # Generate the STATSPACK Reports

    do_reports();

  } else {

    # -----
    # Take a snapshot
    # and delete old snapshots.

    take_snapshot();
    purge_snapshots();

  }

} else {

  print "Statspack is not installed => do nothing.\n";
  $DO_FLUSH = 0;
  # Send nothing to ULS, be silent.

}




# The real work ends here.
# -------------------------------------------------------------------


# Any errors will have sent already its error messages.
# This is just the final message.
uls_value($IDENTIFIER, "message", $MSG, " ");
# uls_value($IDENTIFIER, "exit value", $EXIT_VALUE, "#");

send_doc($CURRPROG, $IDENTIFIER);

send_runtime($start_secs);
uls_timing($IDENTIFIER, "start-stop", "stop");

if ( $DO_FLUSH ) {
  # Transfer to ULS only if STATSPACK is installed
  uls_flush(\%ULS);
}

# -------------------------------------------------------------------
clean_up($TMPOUT1, $TMPOUT2, $LOCKFILE);

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
*ora_statspack.pl
================

This script can take statspack snapshots and can generate statspack reports for daily time intervals.

You must have set up the statspack functionality, typically with database user PERFSTAT. See the Oracle documentation on how to set up statspack (spcreate).

Define the database user for statspack in the oracle_tools.conf. The script does only work, if that database user exist and owns database objects.

Take a snapshot with:
$ ./ora_statspack SNAPSHOT

Generate a report with:
$ ./ora_statspack REPORT <report_name>

where the <report_name> must exist as parameter in the oracle_tools.conf, like:
  DAILY_REPORT = 08:00 - 17:00
in the [ORA_STATSPACK] section.


The script is part of the Oracle OpTools package of the Universal Logging System (ULS), see also: http://www.universal-logging-system.org


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

Statspack Report:
  One or more text files that contain the generated statspack reports.

# exit value:
#   Is 0 if the script has finished without errors,
#   1 if errors have occurred. This is intended to monitor the
#   proper execution of this script.

Copyright 2013-2016, roveda

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

