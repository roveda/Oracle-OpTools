#!/usr/bin/perl
#
#   ora_awr_addm.pl - create AWR and ADDM reports for time intervals
#
# ---------------------------------------------------------
# Copyright 2009 - 2019, roveda
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
#   perl ora_awr_addm.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Restrictions:
#   The use of AWR and ADDM is not free, it must be licensed 
#   on extra costs! So do not use theis script if you do not 
#   have a license.
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   uls-client-2.0-1 or later
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
# 2009-10-29      roveda      0.01
#
# 2009-12-30      roveda      0.02
#   Debugged the cleaning of old temporary pre-logfiles.
#
# 2011-11-11      roveda      0.03
#   Added the GPL.
#
# 2012-08-30      roveda      0.04
#   Changed to ULS-modules.
#
# 2015-01-09      roveda      0.05
#   Corrected to private *.pm
#
# 2015-02-14      roveda      0.06
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#
# 2016-03-09      roveda      0.07
#   The "exit value" is no longer sent to ULS.
#   Debugged the awrrpti invocation, added 'set define on'.
#   All resulting files are compressed, if any of xz, bzip2 or gzip is available.
#
# 2016-03-17      roveda      0.08
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.09
#   Added the SID to the WORKFILEPREFIX.
#
# 2017-02-02      roveda      0.10
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.11
#   Added signal handling.
#
# 2017-02-09      roveda      0.12
#   Added ORACLE_SID to resulting filenames of AWR and ADDM report.
#
# 2017-02-14      roveda      0.13
#   Changed ORACLE_SID in resulting filenames to INSTANCE_NAME, 
#   added HOSTNAME to resulting filename.
#
# 2017-03-20      roveda      0.14
#   Fixed a writing mistake.
#   Fixed the broken support of sid specific configuration file.
#
# 2017-07-06      roveda      0.15
#   Now creating an error message file which is compressed and sent 
#   to ULS in case of an error during script execution.
#
# 2019-07-13      roveda      0.16
#   No execution and no error when running as physical standby.
#
#
#   Change also $VERSION later in this script!
#
# ===================================================================


# use 5.003_07;
use strict;
use warnings;
use File::Basename;
use File::Copy;

# These are my modules:
use lib ".";
use Misc 0.42;
use Uls2 1.16;

my $VERSION = 0.16;

# ===================================================================
# The "global" variables
# ===================================================================

my $CURRPROG;  # Keeps the name of this script.
# Timestamp of script start is seconds
my $STARTSECS = time;

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';

my $WORKFILEPREFIX;
# Keeps the list of temporary files, to be purged at script end
# push filenames onto this array.
my @TEMPFILES;
# Temporary file for SQL execution
my $TMPOUT1;
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

# This hash keeps the documentation for the teststeps.
my %TESTSTEP_DOC;

# Holds the __$CURRPROG or $CFG{"IDENTIFIER"} just for easy usage.
my $IDENTIFIER;

# Keeps the version of the oracle software
my $ORACLE_VERSION  = "";

my $INSTANCE_NAME   = "";
my $INSTANCE_NUMBER = "";
my $DATABASE_NAME   = "";
my $DATABASE_ID     = "";
my $HOSTNAME        = "";


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

  clean_up(@TEMPFILES, $ERROUTFILE, $LOCKFILE);

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

  # -----
  my $t0 = time;

  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    output_error_message(sub_name() . ": Error: Cannot open pipe to '$SQLPLUS_COMMAND'. $!");
    return(0);   # error
  }
  print CMDOUT "$sql\n";
  if (! close(CMDOUT)) {
    output_error_message(sub_name() . ": Error: Cannot close pipe to sqlplus. $!");
    return(0);
  }

  print sub_name() . ": Info: execution time:", time - $t0, "s\n";

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
  my $sql = "
    select 'database status', status from v\$instance;
    SELECT 'database role', DATABASE_ROLE FROM V\$DATABASE;
  ";

  my $db_status = "";
  my $db_role   = "";

  if (exec_sql($sql)) {

    if (! errors_in_file($TMPOUT1)) {

      $db_status = trim(get_value($TMPOUT1, $DELIM, "database status"));
      $db_role = trim(get_value($TMPOUT1, $DELIM, "database role"));

      if ("$db_role, $db_status" eq "PRIMARY, OPEN" ) {
        # role and status is ok, create AWR report
        print "Database role $db_role and status $db_status is ok.\n";

      } elsif ("$db_role, $db_status" eq "PHYSICAL STANDBY, MOUNTED") {
        # role and status is ok, but no AWR report
        return(2);

      } else {
        # role and status is NOT ok, no AWR report, error
        return(0);
      }

    } else {

      output_error_message(sub_name() . ": Error: there have been errors when executing the sql statement.");
      # uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
      appendfile2file($TMPOUT1, $ERROUTFILE);
      return(0);

    }
  } else {
    # It is a fatal error if that value cannot be derived.
    output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
    # uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
    appendfile2file($TMPOUT1, $ERROUTFILE);
    return(0);
  }

  # ----- More information
  $sql = "
    select 'oracle version', version from v\$instance;
    select 'hostname', host_name from v\$instance;
    select 'instance name', instance_name from v\$instance;
    select 'instance number', instance_number from v\$instance;
    select 'database name', name from v\$database;
    select 'database id', dbid from v\$database;
    select 'instance startup at', TO_CHAR(startup_time,'YYYY-MM-DD HH24:MI:SS') from v\$instance;
    select 'database log mode', log_mode from v\$database;
  ";

  if (! do_sql($sql)) {return(0)}

  $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  $WORKFILE_TIMESTAMP = trim(get_value($TMPOUT1, $DELIM, "instance startup at"));
  $INSTANCE_NAME      = trim(get_value($TMPOUT1, $DELIM, "instance name"));
  $INSTANCE_NUMBER    = trim(get_value($TMPOUT1, $DELIM, "instance number"));
  $DATABASE_NAME      = trim(get_value($TMPOUT1, $DELIM, "database name"));
  $DATABASE_ID        = trim(get_value($TMPOUT1, $DELIM, "database id"));
  $HOSTNAME           = trim(get_value($TMPOUT1, $DELIM, "hostname"));

  return(1); # ok
} # general_info



# -------------------------------------------------------------------
sub awrrpti {
  # awrrpti(output_file, begin_snapid, end_snapid);

  title(sub_name());

  my ($filename, $begin_snapid, $end_snapid) = @_;

  # define  inst_num     = 1;
  # define  num_days     = 3;
  # define  inst_name    = 'Instance';
  # define  db_name      = 'Database';
  # define  dbid         = 4;
  # define  begin_snap   = 10;
  # define  end_snap     = 11;
  # define  report_type  = 'text';
  # define  report_name  = /tmp/swrf_report_10_11.txt
  # @@?/rdbms/admin/awrrpti

  # NOTE: inst_name and db_name is assumed to be the SID


  my $sql = "
    set define on;

    define  inst_num     = $INSTANCE_NUMBER;
    define  num_days     = 3;
    define  inst_name    = '$INSTANCE_NAME';
    define  db_name      = '$DATABASE_NAME';
    define  dbid         = $DATABASE_ID;
    define  begin_snap   = $begin_snapid;
    define  end_snap     = $end_snapid;
    define  report_type  = 'html';
    define  report_name  = $filename;

    @@?/rdbms/admin/awrrpti.sql

  ";
  # The '/' results in a 
  # SP2-0103: Nothing in SQL buffer to run.
  # but now it runs. Tested again without '/': that is working, too???!!!
  #
  # TODO the whole perl script bails out when executing above call, why???
  # No difference whether:
  # @@?/rdbms/admin/awrrpti
  # @?/rdbms/admin/awrrpti

  if (! do_sql($sql)) {return('')}

  return($filename);

} # awrrpti


# -------------------------------------------------------------------
sub addmrpt {
  # addmrpt(output_file, $begin_snapid, $end_snapid);

  title(sub_name());

  my ($filename, $begin_snapid, $end_snapid) = @_;

  my $task_name = "addm_${begin_snapid}_${end_snapid}";

  my $sql = "
    exec DBMS_ADVISOR.create_task ( advisor_name => 'ADDM', task_name => '$task_name', task_desc => 'Advisor for snapshots $begin_snapid to $end_snapid.');

    exec DBMS_ADVISOR.set_task_parameter (task_name => '$task_name', parameter => 'START_SNAPSHOT', value => $begin_snapid);

    exec DBMS_ADVISOR.set_task_parameter ( task_name => '$task_name', parameter => 'END_SNAPSHOT', value => $end_snapid);

    exec DBMS_ADVISOR.execute_task(task_name => '$task_name');

    /

    SET LONG 100000
    SET LONGCHUNK 100000

    spool $filename

    SELECT 
      DBMS_ADVISOR.get_task_report('$task_name', 'TEXT', 'TYPICAL', 'ALL') AS report
      FROM dual;

    spool off;

    exec DBMS_ADVISOR.DELETE_TASK('$task_name');

  ";

  if (! do_sql($sql)) {return('')}

  return($filename);

} # addmrpt




# -------------------------------------------------------------------
sub generate_report {
  # generate_report(<schedule_range_no>, <time_range>);
  #
  #

  title(sub_name());

  my $seqno = $_[0];

  # 08:00:00-17:00:00
  my ($from, $to) = split("-", $_[1]);

  my ($day1, $day2);
  my ($rep_day1, $rep_time1, $first_snap);
  my ($rep_day2, $rep_time2, $last_snap);

  # -----
  # Find the last day having a snapshot older than 'to' hours

  my $sql = "
    variable dbid number
    exec :dbid := $DATABASE_ID

    variable instno number
    exec :instno := $INSTANCE_NUMBER

    variable totime varchar2(30)
    exec :totime := '$to'

    select 'day', max(to_char(end_interval_time, 'yyyy-mm-dd'))
    from dba_hist_snapshot
    where to_char(end_interval_time, 'HH24:MI:SS') >= :totime
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
    exec :dbid := $DATABASE_ID

    variable instno number
    exec :instno := $INSTANCE_NUMBER

    variable todt varchar2(30)
    exec :todt := '$day2 $to'

    select 'last_snap', min(snap_id)
    from dba_hist_snapshot
    where end_interval_time >= to_date(:todt, 'yyyy-mm-dd HH24:MI:SS')
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
  # (for the name of the report only)

  $sql = "
    variable dbid number
    exec :dbid := $DATABASE_ID

    variable instno number
    exec :instno := $INSTANCE_NUMBER

    variable ls number
    exec :ls := $last_snap

    select
      'snap_datetime'
      , to_char(end_interval_time, 'yyyy-mm-dd')
      , to_char(end_interval_time, 'HH24MISS')
    from dba_hist_snapshot
    where snap_id         = :ls
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
    $sql = "select 'day1', to_char(to_date('$day2', 'yyyy-mm-dd') - 1, 'yyyy-mm-dd') from dual; ";
    if (! do_sql($sql)) {return(0)}
    $day1 = trim(get_value($TMPOUT1, $DELIM, "day1"));
  }


  # -----
  # Find the first snap id at exactly or the first snap id older than 'day' and 'from'


  $sql = "
    variable dbid number
    exec :dbid := $DATABASE_ID

    variable instno number
    exec :instno := $INSTANCE_NUMBER

    variable d1 varchar2(30)
    exec :d1 := '$day1'

    variable fr varchar2(30)
    exec :fr := '$from'

    select 'first_snap', max(snap_id)
    from dba_hist_snapshot
    where to_char(begin_interval_time, 'yyyy-mm-dd') <= :d1
      and to_char(begin_interval_time, 'HH24:MI:SS') <= :fr
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
  # (for the name of the report only)
  # yes, here also the "end_interval_time" is used, 
  # because that is also used in the (contents of the) AWR.
  # The report name would else be misleading.

  $sql = "
    variable dbid number
    exec :dbid := $DATABASE_ID

    variable instno number
    exec :instno := $INSTANCE_NUMBER

    variable fs number
    exec :fs := $first_snap

    select
      'snap_datetime'
      , to_char(end_interval_time, 'yyyy-mm-dd')
      , to_char(end_interval_time, 'HH24MISS')
    from dba_hist_snapshot
    where snap_id         = :fs
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
  # AWR report

  # You must use a seqno here, because all report files must exist 
  # until the end of the script (flush_test_values).
  my $awr_report = "${WORKFILEPREFIX}_awr_report_${seqno}.html";

  awrrpti($awr_report, $first_snap, $last_snap);

  # Name of the file that is shown in ULS
  my $uls_filename;
  my $uls_filename_prefix;

  $uls_filename_prefix = "awr_${HOSTNAME}_${INSTANCE_NAME}";
  $uls_filename = "${uls_filename_prefix}_${rep_day1}_${rep_time1}-${rep_time2}.html";
  if ( $rep_day1 ne $rep_day2 ) {
    $uls_filename = "${uls_filename_prefix}_${rep_day1}_${rep_time1}-${rep_day2}_${rep_time2}.html";
  }

  if (my $new_ext = try_to_compress($awr_report)) {
    $awr_report .= $new_ext;
    $uls_filename .= $new_ext;
  }

  # Add the file to those which must be deleted at the final end of the script.
  push(@TEMPFILES, $awr_report);

  uls_file({
    teststep  => "$IDENTIFIER"
   ,detail    => "AWR"
   ,filename  => $awr_report
   ,rename_to => $uls_filename
  });

  # -----
  # ADDM advisory

  # You must use a seqno here, because all report files must exist
  # until the end of the script (flush_test_values).
  my $addm_report = "${WORKFILEPREFIX}_addm_report_${seqno}.html";

  addmrpt($addm_report, $first_snap, $last_snap);

  # Name of the file that is shown in ULS
  $uls_filename_prefix = "addm_${HOSTNAME}_${INSTANCE_NAME}";
  $uls_filename = "${uls_filename_prefix}_${rep_day1}_${rep_time1}-${rep_time2}.txt";
  if ( $rep_day1 ne $rep_day2 ) {
    $uls_filename = "${uls_filename_prefix}_${rep_day1}_${rep_time1}-${rep_day2}_${rep_time2}.txt";
  }

  if (my $new_ext = try_to_compress($addm_report)) {
    $addm_report .= $new_ext;
    $uls_filename .= $new_ext;
  }

  # Add the file to those which must be deleted at the final end of the script.
  push(@TEMPFILES, $addm_report);

  uls_file({
    teststep  => "$IDENTIFIER"
   ,detail    => "ADDM"
   ,filename  => $addm_report
   ,rename_to => $uls_filename
  });

  return(1);

} # generate_report


# -------------------------------------------------------------------
sub generate_reports {
  # generate_reports

  title(sub_name());

  # SCHEDULE = 08:00:00 - 17:00:00, 12:00:00 - 14:00:00, 16:00:00 - 08:00:00

  my $schedule = $CFG{"ORA_AWR_ADDM.SCHEDULE"};
  $schedule =~ s/\n//g;
  $schedule =~ s/\r//g;
  $schedule =~ s/\t//g;
  # Remove all blanks
  $schedule =~ tr/ //ds;

  my @SCHEDULE = split(",", $schedule);
  # @SCHEDULE = map(trim($_), @SCHEDULE);
  print "Resulting schedule:", join(",", @SCHEDULE), "\n";

  if ($#SCHEDULE < 0) {
    print "No schedule!\n";
    return(0);
  }

  my $i = 1;
  foreach my $time_range (@SCHEDULE) {
    print "Processing schedule: $time_range \n";
    generate_report($i, $time_range);
    $i++;
  }

  return(1);

} # generate_reports



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

my $initdir = $ENV{"TMP"} || $ENV{"TEMP"} || "/tmp";   #  $currdir;
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

my @Sections = ("GENERAL", "ORACLE", "ULS", "ORA_AWR_ADDM");

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

print "-- ULS settings:\n";
show_hash(\%ULS, " = ");
print "-----\n";

# ----------
# Check for IDENTIFIER

# Set default
$IDENTIFIER = $CFG{"ORA_AWR_ADDM.IDENTIFIER"} || "$IDENTIFIER";
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

my $workdir = $ENV{"WORKING_DIR"} || $CFG{"GENERAL.WORKING_DIR"} || "/var/tmp/oracle_optools/$ENV{ORACLE_SID}";   # $currdir;

if ( ! (-e $workdir)) {
  print "Creating directory '$workdir' for work files.\n";
  if (! mkdir($workdir)) {
    print STDERR "$CURRPROG: Error: Cannot create directory '$workdir' => aborting!\n";
    exit(1);
  }
}

# prefix for work files
$WORKFILEPREFIX = "${IDENTIFIER}";
# _ora_awr_addm
#
# If no oracle sid is found in the workfile prefix, then add it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _ora_awr_addm_orcl
#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /oracle/admin/orcl/oracle_tools/var/_ora_awr_addm_orcl

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

my $d = iso_datetime($STARTSECS);
# $d =~ s/\d{1}$/0/;

set_uls_timestamp($d);

# uls_show();

# ---- Send name of this script and its version
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

# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
print "TMPOUT1=$TMPOUT1\n";
push(@TEMPFILES, $TMPOUT1);

$ERROUTFILE = "${WORKFILEPREFIX}_errout.log";
print "ERROUTFILE=$ERROUTFILE\n";
# push(@TEMPFILES, $ERROUTFILE);

print "DELIM=$DELIM\n";

# ----- general info ----
my $ret = general_info();
if ($ret == 0) {
  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");
  end_script(1);
} elsif ($ret == 2) {
  print "INFO: The database role and database status is not suitable for generating an AWR report.\n";
  end_script(0);
}

generate_reports();

## Continue here with more

# The real work ends here.
# -------------------------------------------------------------------

send_doc($CURRPROG, $IDENTIFIER);

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

#########################
*ora_awr_addm.pl
===============

This perl script generates AWR and ADDM reports on a defined schedule. The resulting reports are sent to the ULS to be used as a baseline information. Use the configuration file to define the report schedule. The script is normally run once a day, but it may be started also manually, preferably by using another configuration file with a changed IDENTIFIER.

This script is part of the Oracle OpTools and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org

To use this script you must set the database parameter:

  alter system set control_management_pack_access='DIAGNOSTIC+TUNING'

KEEP IN MIND:
  The usage of DIAGNOSTIC+TUNING (control_management_pack_access) is NOT (!!!)
  part of the Oracle Standard Edition and must be additionally licensed
  for an Oracle Enterprise Edition!

BUT:
  It is readily installed to be used in your database! 
  And may be easily used via SQL-Developer reports.
  There is NO HINT that tells you that you need an extra licence for that!
  Some day, you may be asked friendly to pay for the necessary licence fee.


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

Copyright 2009-2017, roveda

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

