#!/usr/bin/perl
#
# orabackup.pl - does an old-style online backup of an Oracle database instance
#
# ---------------------------------------------------------
# Copyright 2004-2017, roveda
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
#   perl orabackup.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script does an online backup of an Oracle database
#   by setting the database tablespaces into backup mode and 
#   copy all of its datafiles to a destination directory.
#   All necessary archived redo logs are also copied into 
#   that directory so that a complete recovery (to that point 
#   in time) is possible with the given files in the 
#   destination directory.
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   uls-client-2.0-1 or later
#   You must set environment variables or use a configuration file
#   when using this script.
#
# ---------------------------------------------------------
# Restrictions:
#   ** All data files must be uniquely named, even if they are
#      placed in different directories!
#
#   Currently, the script canNOT copy the tnsnames.ora, sqlnet.ora 
#   and listener.ora for Oracle on Wind*ws.
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
# 2004-11-09      roveda      0.01
#
# 2004-11-17      roveda      0.02
#   Added an "alter system switch logfile".
#
# 2004-12-02      roveda      0.03 
#   Calculate runtime in secs, mins or hours.
#
# 2004-12-07      roveda      0.04 
#   Changed to "start-stop", IDENTIFIER, runtime()
#   Changed to IDENTIFIER, "start-stop", "script name, version" and
#   uses now send_runtime(). Obsolete variables removed.
#
# 2005-05-09      roveda      0.06 
#   Now bails out in backup_tablespaces() when copy_ts_datafiles() has failed.
#   Checks now for tablespaces (and not datafiles) left in backup mode.
#
# 2005-08-01      roveda      0.07 
#   Now uses Misc.pm and Uls.pm. Returns an exit value
#   to the calling context.
#
# 2005-12-21      roveda      0.08 
#   Moved clean_up() to the proper position.
#
# 2006-02-28      roveda      0.09 
#   __BASEFILENAME__ is as new replacement in the COPY_COMMAND available.
#   If there is no spfile, a temporary spfile is created and a pfile 
#   is generated from that. __SID__ is available as replacement in both the 
#   COPY_COMMAND and the BACKUP_DESTINATION.
#
# 2006-10-30      roveda      0.10 
#   Embrace tablespace names with double quotes 
#   (error, if it e.g. ends with a period).
#   Changed use of sprintf to pround(), uses now get_config() 
#   and therefore needs now Misc 0.17.
#
# 2007-06-18      roveda      0.11 
#   Now uses Misc 0.21, ULS settings and sqlplus command in 
#   configuration file. Work and log files are placed in 
#   WORKING_DIR (configuration file). Sending a report with the 
#   necessary redo log sequence numbers for a recovery.
#   Preparation of HTTPS support.
#
# 2007-09-12      roveda      0.12 
#   Some minor changes due to new Uls.pm (0.21).
#   Supports __FILES__, __SCRIPTSTART__ and __TABLESPACENAME__ 
#   in the COPY_COMMAND.
#
# 2007-12-11      roveda      0.13 
#   copy_single_files not correct.
#
# 2008-01-30      roveda      0.14 
#   The return result of an operating system command is 
#   no longer shifted by 8.
#
# 2008-07-01      roveda      0.15 
#   Set the default directory for spfiledir to $ORACLE_HOME/dbs.
#
# 2009-02-16      roveda      0.16 
#   Changed for use of Uls2.pm.
#
# 2009-03-20      roveda      0.17 
#   Check, if any COPY_COMMAND has been set in the conf file.
#   Quit, if not.
#
# 2009-06-15      roveda      0.18 
#   "set linesize 5000" in sub exec_sql(), because at least v$parameter has
#   value of 4000 lemgth.
#
# 2009-12-30      roveda      0.19 
#   Now removing old temporary log files correctly.
#
# 2010-03-12      roveda      0.21 
#   Removed double definition of $initial_logfile.
#
# 2011-11-11      roveda      0.22 
#   Added the GPL.
#
# 2012-08-27      roveda      0.23 
#   Copy the needed archived redo log files to the backup destination. 
#   So, all needed files for a complete recovery of the full backup are in one place.
#   Though, it may still be necessary (and most likely) to apply more 
#   archived redo logs from other locations.
#   Changed to ULS-modules.
#
# 2013-08-17      roveda      0.24 
#   Modifications to match the new single configuration file.
#
# 2015-02-14      roveda      0.25 
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#
# 2016-03-09      roveda      0.26 
#   The "exit value" is no longer sent to ULS.
#
# 2016-03-17      roveda      0.27 
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.28 
#   Added the SID to the WORKFILEPREFIX.
#
# 2017-02-02      roveda      0.29 
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.30 
#   Added signal handling.
#
# 2017-03-21      roveda      0.31 
#   Fixed the broken support of sid specific configuration file.
#
#
#   Change also $VERSION later in this script!
#
# ===================================================================


use 5.8.0;
use strict;
use warnings;
use File::Basename;
use File::Copy;

# These are ULS-modules:
use lib ".";
use Misc 0.40;
use Uls2 1.15;

my $VERSION = 0.31;

# ===================================================================
# The "global" variables
# ===================================================================

# Keeps the name of this script.
my $CURRPROG;  # Keeps the name of this script.

# The runtime of this script is measured in minutes
my $RUNTIME_UNIT = "M";

my $WORKFILEPREFIX;
my $TMPOUT1;
my $LOCKFILE;
my $DELIM = "!";

# The $MSG will contain still the "OK", when reaching the end 
# of the script. If any errors occur (which the script is testing for) 
# the $MSG will contain "ERROR" or a complete error message, additionally,
# the script will send any error messages to the uls directly.
# <hostname> - $ULS_SECTION - __<name of this script> - message
my $MSG = "OK"; 

# Final numerical value, 0 if MSG = "OK", 1 if MSG contains any other value
my $EXIT_VALUE = 0;

# This keeps a report of all actions and is sent to ULS as "Report"
my $REPORT = "";

# This hash keeps the documentation for the teststeps.
my %TESTSTEP_DOC;

# Keeps the contents of the configuration file
my %CFG;

# This keeps the settings for the ULS
my %ULS;

# Holds the __$CURRPROG or $CFG{"IDENTIFIER"} just for easy usage.
my $IDENTIFIER;

# Destination directory of the backup
my $BACKUP_DESTINATION = "";

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';


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
  # Send the given message, set the $MSG variable and
  # print out the message.

  $EXIT_VALUE = 1;
  $MSG = "ERROR";

  foreach my $msg (@_) {
    print STDERR "$msg\n";
    uls_value($IDENTIFIER, "message", $msg, " ");
  }

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
sub rpt_app {
  # rpt_app(<value>);
  # 
  # <value> := all values will be appended to $REPORT

  if($REPORT) {$REPORT .= "\n"}

  $REPORT .= join("", @_);

} # rpt_app

# ------------------------------------------------------------
sub exec_sql {
  # <sql command>
  # Just executes the given sql statement against the current database instance.
  # If <verbose> is a true expression (e.g. a 1) the sql statement will
  # be printed to stdout.

  # connect / as sysdba

  my $sql = "
    set echo off
    set newpage 0
    set space 0
    set linesize 32000
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

    spool off;
  ";

  print "\nexec_sql(): SQL:\n";
  print "$sql\n";

  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    output_error_message(sub_name() . ": Error: Cannot open pipe to sqlplus. $!");
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

  my $unit = "S";
  if ($_[1]) {$unit = uc($_[1])}

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
  my $astitle = $title;

  if ($_[1]) {$astitle = $_[1]}

  if (%TESTSTEP_DOC) {
    if ($TESTSTEP_DOC{$title}) {
      # TODO: You may want to substitute <title> with <astitle> in the text?
      uls_doc($astitle, $TESTSTEP_DOC{$title})
    } else {
      print "No documentation for '$title' found.\n";
    }
  }

} # send_doc


# -------------------------------------------------------------------
sub general_info {
  # Gather some general info about the current oracle instance
  # This is only used to check, whether Oracle Database Server
  # is running (OPEN).

  # This sub returns a value, whether the rest of the script is
  # executed or not.

  title("Checking for running Oracle instance");

  my $sql = "select 'database status', status from v\$instance;";

  if (! do_sql($sql)) {return(0)}

  my $V = trim(get_value($TMPOUT1, $DELIM, "database status"));
  if ($V ne "OPEN") {
    output_error_message(sub_name() . ": Error: Database instance is not OPEN, but '$V'.");
    return(0);
  } else {
    print "Database is OPEN => ok.\n";
  }
  # uls_value($ts, "database status", $V, " ");

  # send_doc($ts);

  return(1); # ok
} # general_info



# -------------------------------------------------------------------
sub check_for_archivelog {
  title("Checking for required ARCHIVELOG mode");

  my $sql = "select 'log mode', log_mode from v\$database;";

  # 'LOGMODE LOG_MODE
  # -------- ------------
  # log mode NOARCHIVELOG

  if (! do_sql($sql)) {return(0)}

  my $V = uc(trim(get_value($TMPOUT1, $DELIM, "log mode")));
  # Keep in mind: it may be ARCHIVELOG or NOARCHIVELOG. A pattern 
  # matching must cope with that.
  if ($V ne "ARCHIVELOG") {
    output_error_message(sub_name() . ": Error: Database instance is not in ARCHIVELOG mode but '$V' => no online backup possible.");
    return(0);
  } else {
    print "Database instance is in ARCHIVELOG mode => ok.\n";
  }

  return(1); # ok
} # check_for_archivelog


# -------------------------------------------------------------------
sub current_sequence_no {
  # current_sequence_no();
  #
  # This returns the SEQUENCE# of the current redo log.
  # That is the first redo log that you need for a 
  # recovery with the backup files of this script run.

  title(sub_name());

  my $sql = "select 'sequence_no', SEQUENCE# from V\$LOG where STATUS = 'CURRENT'; ";

  if (! do_sql($sql)) {return(0)}

  my $V = uc(trim(get_value($TMPOUT1, $DELIM, "sequence_no")));

  return($V);
} # current_sequence_no


# -------------------------------------------------------------------
sub check_for_offline_ts {
  # select TABLESPACE_NAME, STATUS, CONTENTS from dba_tablespaces;
  # TABLESPACE_NAME                STATUS    CONTENTS
  # ------------------------------ --------- ---------
  # SYSTEM                         ONLINE    PERMANENT
  # UNDOTS                         ONLINE    UNDO
  # TEMPTS                         ONLINE    TEMPORARY
  # ARTUS                          ONLINE    PERMANENT
  #
  # Check for ONLINE,
  # Take all but TEMPORARY
  # and walk thru the list of datafiles.

  title("Checking for offline tablespaces");

  my $sql = "
    select tablespace_name, contents, status
      from dba_tablespaces
      where status != 'ONLINE';
  ";

  if (! do_sql($sql)) {return(1)}

  my @TS = get_value_list($TMPOUT1, $DELIM);
  if (scalar(@TS) > 0) {
    output_error_message(sub_name() . ": Error: tablespace(s) [" . join(",", @TS) . "] are not ONLINE!");
    return(1);
  } else {
    print "All tablespaces are ONLINE => ok.\n";
  }

  return(0);
} # check_for_offline_ts


# -------------------------------------------------------------------
sub backup_tablespaces {
  # Go thru all tablespaces and copy their datafiles one after another
  # to the backup destination.
  #
  # All tablespaces are online, that has been checked previously.
  #
  # select TABLESPACE_NAME, STATUS, CONTENTS from dba_tablespaces;
  # TABLESPACE_NAME                STATUS    CONTENTS
  # ------------------------------ --------- ---------
  # SYSTEM                         ONLINE    PERMANENT
  # UNDOTS                         ONLINE    UNDO
  # TEMPTS                         ONLINE    TEMPORARY
  # ARTUS                          ONLINE    PERMANENT
  #
  # Check for ONLINE,
  # Take all but TEMPORARY
  # and walk thru the list of datafiles.

  title("Backing up tablespaces");

  my $sql = "
    select tablespace_name, contents, status
      from dba_tablespaces
      where status = 'ONLINE'
        and contents != 'TEMPORARY';
  ";

  if (! do_sql($sql)) {return(0)}

  my @TableSpaces = get_value_list($TMPOUT1, $DELIM);

  foreach my $ts (@TableSpaces) {
    if (! copy_ts_datafiles($ts)) {
      output_error_message(sub_name() . ": Error: there have been errors while copying the tablespace's datafiles.");
      return(0);
    }
  } # foreach

  return(1);
} # backup_tablespaces



# -------------------------------------------------------------------
sub copy_ts_datafiles {
  # copy_ts_datafiles(<tablespace>);
  #
  # Copy all datafiles for the given tablespace.

  my $ts = $_[0];

  title("Backing up tablespace $ts");

  if (! set_ts_backup_mode($ts, "BEGIN")) { return(0) }

  my $sql = "
    select file_name, status
      from dba_data_files
      where tablespace_name = '$ts';
  ";

  if (! do_sql($sql)) {return(0)}

  # -----
  # Check the datafile for 'AVAILABLE'

  my @DataFiles = get_value_list($TMPOUT1, $DELIM);

  foreach my $df (@DataFiles) {
    my $status = get_value($TMPOUT1, $DELIM, $df);
    if ($status ne "AVAILABLE") {
      output_error_message(sub_name() . ": Error: datafile '$df' is not 'AVAILABLE', but '$status'!", "Tablespace '$ts' is not backed up!");
    }
  } # foreach

  # -----
  # "copy" the files if 'AVAILABLE'

  if ($CFG{"ORABACKUP.COPY_COMMAND"} =~ /__FILES__/) {
    # process all datafiles of the tablespace in one command
    copy_files_batch(lc($ts), \@DataFiles);
  } else {
    # Process each single datafile of the tablespace
    copy_single_files(lc($ts), \@DataFiles);
  }

  if (! set_ts_backup_mode($ts, "END")) { return(0) }

  return(1);
} # copy_ts_datafiles



# -------------------------------------------------------------------
sub copy_single_files {
  # copy_single_files(<tablespace>, <ref to list of datafiles>
  # copy_single_files("UNDOTBS", \@DataFiles);

  my $ret = 1; # assume success

  my $ts = $_[0];
  my $refDataFiles = $_[1];

  foreach my $df (@$refDataFiles) {

    title("Copying datafile $df");

    # NOTE: __FILES__ is not supported in this section!

    # $CFG{"COPY_COMMAND"}  e.g. cp __FILE__ __BACKUP_DESTINATION__
    my $cmd = $CFG{"ORABACKUP.COPY_COMMAND"};

    $cmd =~ s/__BACKUP_DESTINATION__/$BACKUP_DESTINATION/g;
    $cmd =~ s/__FILE__/$df/g;

    my $bfn = basename($df);
    $cmd =~ s/__BASEFILENAME__/$bfn/g;

    my $sid = lc($ENV{"ORACLE_SID"});
    $cmd =~ s/__SID__/$sid/g;

    $cmd =~ s/__SCRIPTSTART__/$CFG{SCRIPTSTART}/g;
    $cmd =~ s/__TABLESPACENAME__/$ts/g;

    print "Executing command: $cmd\n";

    my $cmd_out = `$cmd`;
    # my $result = ($? >> 8);
    my $result = $?;
    if ($result != 0) {
      output_error_message(sub_name() . ": Error: When executing the os command! Return value: $result. $!");
      $ret = 0;  # error
    }
    # Stdout of executed command.
    print "$cmd_out\n";
  } # foreach

  return($ret);

} # copy_single_files


# -------------------------------------------------------------------
sub copy_files_batch {
  # copy_files_batch(<tablespace>, <ref to list of datafiles>
  # copy_files_batch("UNDOTBS", \@DataFiles);

  my $ret = 1; 

  my $ts = $_[0];
  my $aref = $_[1];

  # List of filenames, blank separated.
  my $files = join(" ", @$aref);

  title(sub_name());

  # NOTE: __FILE__ and __BASEFILENAME__ are not supported in this section!

  # $CFG{"COPY_COMMAND"}  e.g. cp __FILES__ __BACKUP_DESTINATION__
  my $cmd = $CFG{"ORABACKUP.COPY_COMMAND"};

  $cmd =~ s/__BACKUP_DESTINATION__/$BACKUP_DESTINATION/g;
  $cmd =~ s/__FILES__/$files/g;

  my $sid = lc($ENV{"ORACLE_SID"});
  $cmd =~ s/__SID__/$sid/g;

  $cmd =~ s/__SCRIPTSTART__/$CFG{SCRIPTSTART}/g;
  $cmd =~ s/__TABLESPACENAME__/$ts/g;

  print "Executing command: $cmd\n";

  my $cmd_out = `$cmd`;
  # my $result = ($? >> 8);
  my $result = $?;
  if ($result != 0) {
    output_error_message(sub_name() . ": Error: When executing the os command! Return value: $result. $!");
    $ret = 0;
  }
  print "$cmd_out\n";

  return($ret);

} # copy_files_batch


# -------------------------------------------------------------------
sub set_ts_backup_mode {
  # BEGIN | END BACKUP for the given tablespace.
  # set_ts_backup_mode(<tablespace>, "BEGIN")
  # set_ts_backup_mode(<tablespace>, "END")

  my ($ts, $mode) = @_;
  title("Set tablespace $ts to $mode BACKUP");

  if ($mode !~ /BEGIN|END/i) {
    output_error_message(sub_name() . ": Error: backup mode for tablespaces may only be 'BEGIN' or 'END', not '$mode'.");
    return(0);
  }

  my $sql = "ALTER TABLESPACE \"$ts\" $mode BACKUP;";

  if (! do_sql($sql)) {return(0)}

  print "Tablespace $ts altered to $mode BACKUP.\n";

  return(1);
} # set_ts_backup_mode


# -------------------------------------------------------------------
sub tablespace_not_in_backup {
  # Check if any tablespace is left in backup mode (or an error occurred), return 0,
  # if none is in backup mode return 1 (success).
  #
  # SQL> select * from v$backup;
  #
  #      FILE# STATUS                CHANGE# TIME
  # ---------- ------------------ ---------- --------
  #          1 NOT ACTIVE           16033136 20041108
  #          2 NOT ACTIVE           16033243 20041108
  #          3 NOT ACTIVE           16033013 2004

  title("Check for tablespaces in backup mode");

  my $sql = "
    select distinct tablespace_name 
      from dba_data_files df, v\$backup b
        where df.file_id = b.file#
          and b.status != 'NOT ACTIVE';
  ";

  if (! do_sql($sql)) {return(0)}

  my @TS = get_value_list($TMPOUT1, $DELIM);
  if (scalar(@TS) > 0) {   # error
    output_error_message(
      sub_name() . ": Error: these tablespaces are still in backup mode:", 
      @TS,
      "You must issue an 'ALTER TABLESPACE <ts> END BACKUP' manually."
    );
    return(0);
  }
  print "No tablespaces are left in backup mode => ok\n";

  return(1);
} # tablespace_not_in_backup



# -------------------------------------------------------------------
sub save_other_files {
  # save_other_files();
  # 
  # Controlfile
  # select value from v$parameter where name= 'control_files';
  #
  # spfile/pfile
  # listener.ora, tnsnames.ora, sqlnet.ora

  # List of files to save
  my @F = ();

  backup_controlfile(\@F);

  save_spfile(\@F);

  # network/admin
  my $path = $ENV{"ORACLE_HOME"} . "/network/admin";

  foreach my $f ( ("sqlnet.ora", "listener.ora", "tnsnames.ora") ) {
    my $fn = "$path/$f";

    if (-e $fn)   { 
      # Put the filename onto the file stack.
      push(@F, $fn);
    } else {
      print sub_name() . ": Warning: file '$fn' does not exist.\n";
    }
  } # foreach

  # -----
  # Save files to backup destination using 
  # the COPY_COMMAND

  if ($CFG{"ORABACKUP.COPY_COMMAND"} =~ /__FILES__/) {
    # process all files in one command
    copy_files_batch("others", \@F);
  } else {
    # Process each single file
    copy_single_files("others", \@F);
  }

} # save_other_files


# -------------------------------------------------------------------
sub backup_controlfile {
  # Write the control file as binary and as text.
  #
  # ALTER DATABASE BACKUP CONTROLFILE TO 'control.bak' REUSE;
  # ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
  # ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS 'control2.txt' REUSE;

  title("Controlfile");

  my $refF = $_[0];

  # Find directory where the first control file sits
  # SQL> select value from v$parameter where name = 'control_files';
  # 
  # VALUE
  # --------------------------------------------------------------------------------
  # /oracle/admin/artusp/oradata/control01.ctl, /oracle/admin/artusp/oradata/control
  # 02.ctl, /oracle/admin/artusp/oradata/control03.ctl

  my $sql = "select 'control_files', value from v\$parameter where name = 'control_files';";

  if (! do_sql($sql)) {return(0)}

  my $control_files = trim(get_value($TMPOUT1, $DELIM, "control_files"));
  print "control_files=$control_files\n";

  # Get the first control file's full path
  my $cf1 = (split(/,/, $control_files))[0];
  print "Path of first control file:$cf1\n";

  # Path of first control file
  # (that's where i will place a backup copy)
  my $pcf1 = dirname(trim($cf1));

  # my $bak = "$BACKUP_DESTINATION/control.bak";
  my $bak = "$pcf1/control.bak";
  # my $txt = "$BACKUP_DESTINATION/control.txt";
  my $txt = "$pcf1/control.txt";

  $sql = "
    ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
    ALTER DATABASE BACKUP CONTROLFILE TO '$bak' REUSE;
    ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS '$txt' REUSE;
  ";

  if (! do_sql($sql)) {return(0)}

  # Put the filenames onto the file stack.
  push(@$refF, $bak);
  push(@$refF, $txt);

  print "Controlfile backed up to first control file's directory and to bdump.\n";

  return(1);
} # backup_controlfile



# -------------------------------------------------------------------
sub save_spfile {
  # save_spfile(<ref to file array>);
  # 
  # Create an init.ora for backup purpose only.
  # It is created from an spfile, if no one exists, 
  # the script will create a temporary spfile just for 
  # that action. It will have a non-default filename, 
  # there are no side effects when starting up the instance.
  # (The spfile in found in $OH/dbs or $OH/database)

  title("Save spfile to pfile");

  my $refF = $_[0];

  my $spfilename = "";
  my $pfilename  = "";
  my $spfiledir  = "";   # temporary directory to place the copy of the [s]pfile

  # -----
  # Get the [s]pfile settings
  # BUT: PFILE does not need to be set!!!

  my $sql = "select name, value from v\$parameter where name in ('pfile', 'spfile');";

  if (! do_sql($sql)) {return(0)}

  # Only one of these values are normally set.
  # $spfilename = trim(get_value($TMPOUT1, $DELIM, "spfile"));
  # $pfilename  = trim(get_value($TMPOUT1, $DELIM, "pfile"));

  $spfilename = "-";
  $pfilename  = "-";

  my @T;
  get_value_lines(\@T, $TMPOUT1);
  foreach my $t (@T) {
    my @E = split($DELIM, $t);
    @E = map(trim($_), @E);
    my ($n, $v) = @E;

    if ($n eq "pfile") {$pfilename = $v}
    if ($n eq "spfile") {$spfilename = $v}
  } # foreach

  # Find the directory where the [s]pfile are found.
  # 1st: set defaults
  # Unix
  $spfiledir = $ENV{ORACLE_HOME} . "/dbs";
  
  # Windows
  my $d = $ENV{ORACLE_HOME} . "/database";
  if ( -d $d ) {$spfiledir = $d}
  
  # 2nd: find directory in results of above sql
  if ($pfilename  ne "-") {$spfiledir = dirname($pfilename)}
  if ($spfilename ne "-") {$spfiledir = dirname($spfilename)}

  if ($spfilename eq "-") {
    print "SPFILE parameter is not set => build a temporary spfile.\n";

    # Use a none default filename! Oracle would use it otherwise at next startup.
    $spfilename = "$spfiledir/spfile_" . $ENV{"ORACLE_SID"} . "_for_backup_only.ora";

    $sql = "create spfile='$spfilename' from pfile;";

    if (! do_sql($sql)) {return(0)}

    print "Temporary spfile '$spfilename' created from pfile.\n";

  } else {

    print "SPFILE parameter is set.\n";

  }
  # Now, we do have an spfile (whether by default or explicitly created)
  # and can create a readable parameter file (init.ora) out of it.

  # -----
  $pfilename = "$spfiledir/init_" . $ENV{"ORACLE_SID"} . "_for_backup_only.ora";

  $sql = "create pfile = '$pfilename' from spfile = '$spfilename';";

  if (! do_sql($sql)) {return(0)}

  # Put the filename onto the file stack.
  push(@$refF, $pfilename);

  print "PFILE '$pfilename' created from SPFILE.\n";

  return(1);
} # save_spfile



# -------------------------------------------------------------------
sub switch_logfile {
  # Switch to next redo log, the current one will be archived.

  title("Switch logfile");

  my $sql = "ALTER SYSTEM SWITCH LOGFILE;";
  if (! do_sql($sql)) {return(0)}

  print "Switched to next redo log.\n";

  return(1);

} # switch_logfile


# -------------------------------------------------------------------
sub wait_for_archived_log {
  # Wait for Oracle to write the archived redo log with the given 
  # sequence number.
  # 
  # wait_for_archived_log(<latest_sequence#>);

  my ($seq2) = @_;

  print "Wait for archived redo log, sequence# $seq2\n";

  while ( 1 ) {
    my $sql = "select name from V\$ARCHIVED_LOG where SEQUENCE# = $seq2 ;";
  
    if (! do_sql($sql)) {return(0)}

    my @F = get_value_list($TMPOUT1, $DELIM);
    foreach my $f (@F) {

      if (-e $f) { 
        print "Found file '$f'\n";

        return(1)
      }
    } # foreach

    sleep(5);

  } # while

} # wait_for_archived_log


# -------------------------------------------------------------------
sub copy_arls {
  # Copy the needed archived redo log files to the backup destination.
  # 
  # copy_arls(<sequence#1>, <sequence#2>);

  title("Copy the needed archived redo logs");

  my ($seq1, $seq2) = @_;

  # -----
  # Wait a bit until Oracle has written the archived redo log.

  if (! wait_for_archived_log($seq2)) {return(0)}

  # -----
  # Get the file names

  my $sql = "
    select name
      from V\$ARCHIVED_LOG
        where SEQUENCE# >= $seq1
          and SEQUENCE# <= $seq2
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @F = get_value_list($TMPOUT1, $DELIM);

  copy_single_files("archived_redo_logs", \@F);


} # copy_arls



# -------------------------------------------------------------------
sub clean_backup_dest {
  # Delete all files in the backup destination.
  # 

  title ("Delete all files in the backup destination");

  opendir(DIR, $BACKUP_DESTINATION);

  my @files = readdir(DIR);

  foreach my $file (@files) {
    if ($file eq ".") {next}
    if ($file eq "..") {next}

    print "Remove '", $file, "'\n";
    my $c = unlink("$BACKUP_DESTINATION/$file");
    print "$c file(s) successfully removed.\n";
  } # foreach

} # clean_backup_dest




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

my $initdir = $ENV{"TMP"} || $ENV{"TEMP"} || "/tmp";   # $currdir;

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

# ----------
# Get the configuration file.

my $cfgfile = $ARGV[0];
print "configuration file=$cfgfile:\n";

my @Sections = ( "GENERAL", "ORACLE", "ULS", "ORABACKUP" );
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
show_hash(\%ULS);

# ----------
# Check for IDENTIFIER

# Set default
$IDENTIFIER = $CFG{"ORABACKUP.IDENTIFIER"} || $IDENTIFIER;
# Overwrite with conf file contents
# $IDENTIFIER = $CFG{"IDENTIFIER"} || die "Error: IDENTIFIER not spefied in configuration file!\n";
print "IDENTIFIER=$IDENTIFIER\n";
# From here on, you may use $IDENTIFIER for uniqueness

# -------------------------------------------------------------------
# environment
#
# Check here the necessary environment variables

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

$WORKFILEPREFIX = "${IDENTIFIER}";
# _orabackup
#
# If no oracle sid is found in the workfile prefix, then add it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _orabackup_orcl
#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /var/tmp/oracle_optools/orcl/_orabackup_orcl

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
  while (<INITLOG>) {print;}
  close(INITLOG);
  print "Removing initial log file '$initial_logfile'.\n";
  my $c = unlink($initial_logfile);
  print "$c file(s) successfully removed.\n";

  print "Remove possible old temporary files.\n";
  # Remove old .tmp files
  opendir(INITDIR, $initdir);
  my @files = grep(/$CURRPROG.*\.tmp/, map("$initdir/$_", readdir(INITDIR)));
  foreach my $file (@files) {
    # Modification time of file, also fractions of days.
    my $days = pround(-M $file, -1);

    if ($days > 5) {
      print "Remove '", basename($file), "', ($days days old)...\n";
      my $c = unlink($file);
      print "$c file(s) successfully removed.\n";
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
$d =~ s/://g;
$d =~ s/ /_/g;
$CFG{SCRIPTSTART} = $d;

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

print "DELIM=$DELIM\n";

# ----- documentation -----
# Does the documentation needs to be resent to ULS?
title("Documentation");

print "Prepare the documentation.\n";

# de-reference the return value to the complete hash.
%TESTSTEP_DOC = %{doc2hash(\*DATA)};

uls_value($IDENTIFIER, "documentation", "transferring", " ");


# ----- sqlplus command -----
# Check, if the sqlplus command has been redefined in the configuration file.
$SQLPLUS_COMMAND = $CFG{"ORACLE.SQLPLUS_COMMAND"} || $SQLPLUS_COMMAND;

# -----
# Check, if a COPY_COMMAND has been given in the configuration file.
if (! exists($CFG{"ORABACKUP.COPY_COMMAND"})) {
  output_error_message("$CURRPROG: Error: No COPY_COMMAND has been found in the configuration file '$cfgfile' => aborting..");

  send_runtime($start_secs, $RUNTIME_UNIT);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  clean_up($TMPOUT1, $LOCKFILE);
  exit(1);
}

# -------------------------------------------------------------------
# Check if Oracle database is running.

if (! general_info()) {
  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  send_runtime($start_secs, $RUNTIME_UNIT);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  clean_up($TMPOUT1, $LOCKFILE);
  exit(1);
}

# -------------------------------------------------------------------
# Check if Oracle database runs in ARCHIVELOG mode (else no online backup possible)

if (! check_for_archivelog()) {
  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  send_runtime($start_secs, $RUNTIME_UNIT);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  clean_up($TMPOUT1, $LOCKFILE);
  exit(1);
}

# $CFG{"BACKUP_DESTINATION"}
# $CFG{"COPY_COMMAND"}  e.g. cp __FILE__ __BACKUP_DESTINATION__/__FILE__

# -------------------------------------------------------------------
# Check if any tablespace is not online (the backup would be incomplete)

if (check_for_offline_ts()) {
  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  send_runtime($start_secs, $RUNTIME_UNIT);
  uls_timing($IDENTIFIER, "start-stop", "stop");
  uls_flush(\%ULS);

  clean_up($TMPOUT1, $LOCKFILE);
  exit(1);
}

# -------------------------------------------------------------------
# Check, if the backup destination exists and is a directory

if ($CFG{"ORABACKUP.COPY_COMMAND"} =~ /__BACKUP_DESTINATION__/) {

  # Check if the backup destination directory exists only
  # if __BACKUP_DESTINATION__ is used in the COPY_COMMAND

  $BACKUP_DESTINATION = $CFG{"ORABACKUP.BACKUP_DESTINATION"};
  $BACKUP_DESTINATION =~ s/__SID__/$ENV{"ORACLE_SID"}/g;

  if (! -d $BACKUP_DESTINATION) {
    output_error_message("$CURRPROG: Error: '$BACKUP_DESTINATION' is not a directory => aborting script.");

    send_runtime($start_secs, $RUNTIME_UNIT);
    uls_timing($IDENTIFIER, "start-stop", "stop");
    uls_flush(\%ULS);

    clean_up($TMPOUT1, $LOCKFILE);
    exit(1);
  }

  # Remove all files in that directory
  clean_backup_dest();

} else {

  print "BACKUP_DESTINATION is not used in the COPY_COMMAND.\n";

}

# -------------------------------------------------------------------
# Get the current sequence number of the redo logs

my $seq1 = current_sequence_no();

# -------------------------------------------------------------------
# Get the list of tablespaces and walk thru their datafiles and copy 
# them to the backup destination

backup_tablespaces();

# -------------------------------------------------------------------
# Check if any tablespaces are left in backup mode

tablespace_not_in_backup();

# -------------------------------------------------------------------
# Save other files such as the control file, [s]pfile, listener.ora, 
# sqlnet.ora, tnsnames.ora

save_other_files();

# -------------------------------------------------------------------
# Get the current sequence number of the redo logs

my $seq2 = current_sequence_no();

if ($seq1 eq $seq2) {
  uls_value($IDENTIFIER, "needed redo logs", $seq1, " ");
} else {
  uls_value($IDENTIFIER, "needed redo logs", "$seq1..$seq2", " ");
}

# -------------------------------------------------------------------
# switch to next redo log (the last redo log will be archived then)

switch_logfile();

# -----
# Copy the needed archived redo log to the backup destination
copy_arls($seq1, $seq2);

# The real work ends here.
# -------------------------------------------------------------------

# Any errors will have set already its error messages in $MSG.
uls_value($IDENTIFIER, "message", $MSG, " ");
# uls_value($IDENTIFIER, "exit value", $EXIT_VALUE, "#");

send_doc($CURRPROG, $IDENTIFIER);

send_runtime($start_secs, $RUNTIME_UNIT);

uls_timing($IDENTIFIER, "start-stop", "stop");
uls_flush(\%ULS);


# -------------------------------------------------------------------
clean_up($TMPOUT1, $LOCKFILE);
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
*orabackup.pl
============

This is a backup script for an Oracle 9i, 10g or 11g database instances.

This script is part of the Oracle OpTools and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org

This script (orabackup.pl) makes an online backup of an Oracle instance 
and writes:
  - all datafiles, 
  - a control file (binary and readable),
  - the initSID.ora (derived from the therefore required spfile),
  - tnsnames.ora, listener.ora and sqlnet.ora (from ORACLE_HOME/network/admin)
to the backup destination given in the configuration file and 
finally switches to the next redo log.

This script is run by a calling script
that sets the correct environment before starting the orabackup.pl.
It is mostly started by the cron daemon or scheduled tasks.

Currently, the script cannot copy the tnsnames.ora, listener.ora and 
sqlnet.ora for Oracle on Wind*ws!


message:
  If the script runs fine, it returns 'OK', else an error message.
  You should generate a ticket for any other value.

runtime:
  The runtime of the script.

start-stop:
  The start and stop timestamps for the script.

documentation:
  Is 'transferring' when the complete documentation section of this script is transferred to the ULS.

script name, version:
  The name and version of this script.

needed redo logs:
  These redo logs are needed for a recovery.

# exit value:
#   Is 0 if the script has finished without errors,
#   1 if errors have occurred. This is intended to monitor the
#   proper execution of this script.
# 

Copyright 2004-2016, roveda

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

