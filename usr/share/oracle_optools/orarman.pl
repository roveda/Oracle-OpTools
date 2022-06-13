#!/usr/bin/perl
#
# orarman.pl - makes an online backup of an oracle database instance
#
# ---------------------------------------------------------
# Copyright 2008 - 2022, roveda
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
#   perl orarman.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script executes an RMAN backup of a running Oracle database. 
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   uls-client-2.0-1 or later
#   You must set the necessary environment variables for
#   used operating system commands before starting this script.
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
# 2008-05-28      roveda      0.01
#   spin off from orabackup.pl
#
# 2008-06-12      roveda      0.02
#   Changed the CONFIGURE CONTROLFILE...FORMAT.
#
# 2008-11-13      roveda      0.03
#   Ported to Uls2.pm. Added RMAN commands.
#
# 2009-01-30      roveda      0.04
#   Minor changes to documentation below __END__.
#
# 2009-02-16      roveda      0.05
#   Changed to Uls2.pm, only archive logging
#
# 2009-12-30      roveda      0.06
#   Now removing old temporary log files correctly.
#
# 2010-01-29      roveda      0.07
#   Changed the RMAN commands (DELETE OBSOLETE instead of
#   DELETE ARCHIVELOG and DELETE EXPIRED BACKUP).
#
# 2010-02-26      roveda      0.08
#   MAX_SET_SIZE can now be set in the configuration file, the
#   default is now UNLIMITED (was 30G).
#
# 2010-03-04      roveda      0.09
#   Added the COMPRESSED feature, changed the REDUNDANCY feature.
#
# 2010-09-20      roveda      0.11
#   Moved from only recovery window to retention policy for
#   recovery window and redundancy.
#
# 2010-12-22      roveda      0.12
#   Backup to fast recovery area now possible. But removed the
#   copying of the listener.ora, tnsnames.ora and sqlnet.ora.
#
# 2011-11-11      roveda      0.13
#   Added the GPL.
#
# 2012-08-30      roveda      0.14
#   Changed to ULS-modules.
#
# 2013-03-29      roveda      0.15
#   Changed to new configuration file format. The complete
#   RMAN command must now be specified in the configuration file.
#   No substitutions.
#
# 2013-08-17      roveda      0.16
#   Modifications to match the new single configuration file.
#
# 2015-02-14      roveda      0.17
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#
# 2015-09-06      roveda      0.18
#   Extract some networker environment variables if set, and
#   send them to ULS for informational purpose.
#
# 2016-03-09      roveda      0.19
#   The "exit value" is no longer sent to ULS.
#   All resulting files are compressed, if any of xz, bzip2 or gzip is available.
#
# 2016-03-18      roveda      0.20
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.21
#   The parameter (e.g. FULL, LEVEL0) is sent as detail to ULS
#   a value of 0 indicates an error, a 1 success. That allows
#   math-based monitoring of backup execution over different levels.
#   Added the SID to the WORKFILEPREFIX.
#
# 2016-06-15      roveda      0.22
#   Added the lines from rman logfile to "message", starting at line that contains "ORA-".
#
# 2017-02-02      roveda      0.23
#   Changed the default working directory to /var/tmp/oracle_optools/sid.
#
# 2017-02-07      roveda      0.24
#   Added signal handling.
#   Now uses <parameter>_IDENTIFIER in [ORARMAN] section.
#   That allows separate identifiers as teststeps in ULS for the
#   different level (FULL, LEVEL0, LEVEL1) or types (REDOLOGS) of rman backups.
#   Re-enabled the "message".
#
# 2017-03-21      roveda      0.25
#   Fixed the broken support of sid specific configuration file.
#
# 2017-07-12      roveda      0.26
#   Instead of a script result message as a sequence of single string lines
#   a message file is created and finally compressed and sent to ULS but 
#   only if an error has occured.
#
# 2019-07-16      roveda      0.27
#   Now accepting PRIMARY,OPEN and PHYSICAL STANDBY,MOUNTED as possible
#   database roles and states. But, the given parameter must point to the 
#   matching entry in the configuration file and the rman commands must match 
#   the database role and status.
#
# 2021-11-27      roveda      0.28
#   Added full UTF-8 support. Thanks for the boilerplate
#   https://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/6163129#6163129
#
# 2022-01-16      roveda      0.29
#   Send all networker environment variables (NSR_*) to ULS as further 
#   information (only if present).
#
# 2022-01-28      roveda      0.30
#   Fixed: the networker environment variables were not sent to ULS.
#
#
#   Change also $VERSION later in this script!
#
# ===================================================================


# use 5.8.0;
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

# These are ULS-modules:
use lib ".";
use Misc 0.44;
use Uls2 1.17;

my $VERSION = 0.30;

# ===================================================================
# The "global" variables
# ===================================================================

# Keeps the name of this script.
# $CURRPROG = basename($0, ".pl");   # extension is removed
my $CURRPROG = basename($0);

my $currdir = dirname($0);
# Timestamp of script start is seconds
my $STARTSECS = time;

# The runtime of this script is measured in minutes
my $RUNTIME_UNIT = "M";

my $WORKFILEPREFIX;

# Keeps the list of temporary files, to be purged at script end
# push filenames onto this array.
my @TEMPFILES;

my $TMPOUT1;
my $TMPOUT2;
my $TMPOUT3;
my $LOCKFILE;
my $ERROUTFILE;


# Delimiter for tabular query results
my $DELIM = "!";

# The $MSG will contain still the "OK", when reaching the end
# of the script. If any errors occur (which the script is testing for)
# the $MSG will contain "ERROR" or a complete error message, additionally,
# the script will send any error messages to the uls directly.
# <hostname> - $ULS_SECTION - __<IDENTIFIER> - message
my $MSG = "OK";

# Final numerical value, 0 if MSG = "OK", 1 if MSG contains any other value
my $EXIT_VALUE = 0;

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

# The default command to execute sql commands.
# NOTE: there is another rman in /usr/X11R6/bin!!!
#
# my $RMAN_INVOCATION = '/oracle/admin/product/10.2.0/db_1/bin/rman TARGET / NOCATALOG';
my $RMAN_INVOCATION = $ENV{ORACLE_HOME} . '/bin/rman TARGET / ';

# A parameter is given on the command line that specifies
# the RMAN command within the section ORARMAN to be used.

my $ORARMAN_PARAMETER = "";



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
  $EXIT_VALUE = 1;

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

  my $ret = 0;
  my $filename = $_[0];

  if (! open(INFILE, "<$filename")) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    $ret = 1;
    return($ret);
  }

  my $L;

  while ($L = <INFILE>) {
    chomp($L);
    if ($L =~ /ORA-\d+|RMAN-\d+|SP2-\d+|error/i) {
      # yes, there have been errors.
      output_error_message(sub_name() . ": Error: There have been error(s) in file '$filename'!");
      $ret = 1;
    }

  } # while

  if (! close(INFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    $ret = 1;
  }
  return($ret);
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

  my $sql = "
    set echo off
    set feedback off

    alter session set NLS_TERRITORY='AMERICA';
    alter session set NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
    alter session set NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS';
    alter session set NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SS TZH:TZM';

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

  print "----- SQL -----\n$sql\n---------------\n\n";

  print "----- result -----\n";

  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    output_error_message(sub_name() . ": Error: Cannot open pipe to sqlplus. $!");
    return(0);   # error
  }
  print CMDOUT "$sql\n";
  if (! close(CMDOUT)) {
    output_error_message(sub_name() . ": Error: Cannot close pipe to sqlplus. $!");
    return(0);
  }
  print "------------------\n";

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
      appendfile2file($TMPOUT1, $ERROUTFILE);
      return(0);
    }
    # Ok
    return(1);
  }

  output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
  appendfile2file($TMPOUT1, $ERROUTFILE);

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
  # send_runtime(<STARTSECS> [, {"s"|"m"|"h"}]);

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

  my $sql = "
    select 'database status', status from v\$instance;
    SELECT 'database role', DATABASE_ROLE FROM V\$DATABASE;
  ";

  if (! do_sql($sql)) {return(0)}

  my $db_status = trim(get_value($TMPOUT1, $DELIM, "database status"));
  my $db_role = trim(get_value($TMPOUT1, $DELIM, "database role"));
  print "Database role: $db_role, status: $db_status\n";

  if ("$db_role, $db_status" eq "PRIMARY, OPEN" ) {
    # role and status is ok
    print "Database role and status is ok.\n";

  } elsif ("$db_role, $db_status" eq "PHYSICAL STANDBY, MOUNTED") {
    # role and status is ok
    print "Database role and status is ok.\n";

  } else {
    # role and status is NOT ok
    output_error_message(sub_name() . ": ERROR: Database instance has incompatible role and status: $db_role, $db_status.");
    return(0);
  }

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



#--------------------------------------------------------------------
sub exec_system {

  my $cmd = $_[0];

  my $ret = 1;  # assume success

  print "$cmd\n";

  system($cmd);

  if ($? == -1) {

    output_error_message(sub_name() . ": Error: failed to execute '$cmd': $!");
    $ret = 0;

  } elsif ($? & 127) {

    my $txt = sprintf("child died with signal %d, %s coredump", ($? & 127),  ($? & 128) ? 'with' : 'without');
    output_error_message(sub_name() . ": Error: $txt");
    $ret = 0;

  } else {
    # Ok

    my $txt = sprintf("child exited with value %d", $? >> 8);
    print "$txt\n";
    $ret = 1;  # Ok

  }

  return($ret);

} # exec_system


#--------------------------------------------------------------------
sub grep_file {
  # grep_file(<file>, <pattern>)

  my ($file, $patt) = @_;

  my $ret = 0;

  if (! open(RD, "<", $file)) {
    output_error_message(sub_name() . ": Error: Cannot open '$file' for reading. $!");
    return($ret);
  }

  while (my $L = <RD>) {
    if ($L =~ /$patt/i) {
      $ret = 1;
      last;
    }
  }

  if (! close(RD)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$file'. $!");
    $ret = 0;
  }

  return($ret);

} # grep_file



#--------------------------------------------------------------------
sub extract_from_to {

  my ($filename, $pattern_from, $pattern_to) = @_;

  my $ret = "";

  if (! open(RD, "<", $filename)) {
    # output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    print sub_name() . ": Error: Cannot open '$filename' for reading. $!";
    return(undef);
  }

  # while (<RD>) {
  #   if (/$pattern_from/ .. /$pattern_to/) {
  #     $ret .= $_;
  #   }
  # }
  while (my $L = <RD>) {
    if ($L =~ /$pattern_from/i .. $L =~ /$pattern_to/i) {
      $ret .= $L;
    }
  }


  if (! close(RD)) {
    # output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    print sub_name() . ": Error: Cannot close file handler for file '$filename'. $!";
    return(undef);
  }

  return($ret);

} # extract_from_to


#--------------------------------------------------------------------
sub exec_rman {
  # exec_rman(<command file>);

  # Just executes the given rman command file against the rman.

  # rman cmdfile 'xyz.rman' checksyntax log '/tmp/rman_syntax_??.log'
  # ...
  # The cmdfile has no syntax errors
  # ...
  #
  # rman target / cmdfile 'xyz.rman' log 'sasasa'

  my $command_file = $_[0];

  # print "command_file = $command_file\n";

  my $rman_command = $CFG{"ORACLE.RMAN_INVOCATION"} || $RMAN_INVOCATION;
  print "RMAN invocation command: $rman_command\n";

  # -----
  # check syntax

  my $cmd = "$rman_command cmdfile '$command_file' checksyntax log '$TMPOUT1'";

  # print "cmd=$cmd\n";

  if (! exec_system($cmd)) { return(0) }

  # Check the output
  # (only in English? or also other languages possible?)
  if (! grep_file($TMPOUT1, "The cmdfile has no syntax errors")) {
    output_error_message(sub_name() . ": Error: Improper syntax.");

    my $syntax_logfile = $TMPOUT1;
    my $uls_filename = "rman_syntax_check_log_file.txt";

    if (my $new_ext = try_to_compress($syntax_logfile)) {
      $syntax_logfile .= $new_ext;
      $uls_filename   .= $new_ext;
      push(@TEMPFILES, $syntax_logfile);
    }

    uls_file({
      teststep => $IDENTIFIER
     ,detail   => "RMAN syntax check log file"
     ,filename => $syntax_logfile
     ,rename_to => $uls_filename
    });
    return(0);
  }

  $cmd = "$rman_command cmdfile '$command_file' log '$TMPOUT3'";

  # Return value for this function, 1 is success, 0 failure
  my $retval = 1;

  # Return value of the os command
  my $ret = exec_system($cmd);

  if (! $ret) { $retval = 0; }

  # -----
  # Check the output file

  if (grep_file($TMPOUT3, 'ORA-\d+')) {
    # Check for ORA- messages

    $retval = 0;

    # Extract the ORA- lines up to the first empty line
    my $ora_lines = extract_from_to($TMPOUT3, "ORA-", "^\$");
    if ($ora_lines) {
      output_error_message($ora_lines);
    } else {
      # If (whyever) no ORA-lines have been found, send default error message
      output_error_message(sub_name() . ": ORA Error: when executing rman command file.");
    }

  } elsif (grep_file($TMPOUT3, 'RMAN-\d+')) {
    # Check for RMAN-messages, if no ORA- messages have been found so far

    $retval = 0;

    # Extract the RMAN- lines up to the first empty line
    my $rman_lines = extract_from_to($TMPOUT3, "RMAN-", "^\$");
    if ($rman_lines) {
      output_error_message($rman_lines);
    } else {
      # If (whyever) no RMAN-lines have been found, send default error message
      output_error_message(sub_name() . ": RMAN Error: when executing rman command file.");
    }

  }

  # -----
  # This check is a bit too general
  # if (grep_file($TMPOUT3, "error")) {
  #   output_error_message(sub_name() . ": Error: when executing rman command file.");
  #   return(0);
  # }


  # -----
  # The command file.

  my $uls_filename = "rman_command_file.sql";
  if (my $new_ext = try_to_compress($command_file)) {
    $command_file .= $new_ext;
    $uls_filename .= $new_ext;
  }
  push(@TEMPFILES, $command_file);

  uls_file({
    teststep => $IDENTIFIER
   ,detail   => "RMAN command file"
   ,filename => $command_file
   ,rename_to => $uls_filename
  });

  # -----
  # The logfile.

  $uls_filename = "rman_logfile.txt";
  if (my $new_ext = try_to_compress($TMPOUT3)) {
    $TMPOUT3 .= $new_ext;
    $uls_filename .= $new_ext;
  }
  push(@TEMPFILES, $TMPOUT3);

  uls_file({
    teststep => $IDENTIFIER
   ,detail   => "RMAN logfile"
   ,filename => $TMPOUT3
   ,rename_to => $uls_filename
  });

  # -----
  return($retval);

} # exec_rman


#--------------------------------------------------------------------
sub rman_backup {

  title("RMAN backup");

  # -----
  # The command sequence from the configuration file for the RMAN backup action.

  my $C = $CFG{"ORARMAN.$ORARMAN_PARAMETER"};
  print "\n";
  print "RMAN command to execute:\n";
  print "$C\n\n";

  if (! $C) {
    output_error_message(sub_name() . ": Error: No matching RMAN command found in configuration file for parameter '$ORARMAN_PARAMETER'.");
    return(0);
  }

  # -----
  # Networker special
  # Extract some networker environment variables, if set.
  # 2022-01-16: extract all networker environment variabls, if present


  my $nsrenv = "";
  # if ($ENV{"NSR_SERVER"}) { $nsrenv = "NSR_SERVER=" . $ENV{"NSR_SERVER"} }
  # if ($ENV{"NSR_DATA_VOLUME_POOL"}) { $nsrenv .= "\nNSR_DATA_VOLUME_POOL=" . $ENV{"NSR_DATA_VOLUME_POOL"} }
  # if ($nsrenv) {
  #   uls_value($IDENTIFIER, "networker environment", $nsrenv, "_");
  # }

  foreach my $k ( keys %ENV ) {
    if ( $k =~ /^NSR_/ ) {
      # print "$k=$ENV{$k}\n";
      if ( $nsrenv ) { $nsrenv = "$nsrenv\n"; }
      $nsrenv="$nsrenv$k=$ENV{$k}";
    }
  }
  if ($nsrenv) {
    uls_value($IDENTIFIER, "networker environment", $nsrenv, "_");
  }

  # -----
  # Output to temporary command file

  if (! open(OUTFILE, ">", $TMPOUT2)) {
    output_error_message(sub_name() . ": Error: Cannot open '$TMPOUT2' for writing. $!");
    return(0);
  }

  print OUTFILE "$C\n";

  if (! close(OUTFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$TMPOUT2'. $!");
    return(0);
  }

  # -----
  # Execute the command file

  exec_rman($TMPOUT2);

  print "Backup with rman done.\n";

  return(1);

} # rman_backup



# ===================================================================
# main
# ===================================================================
#
# initial customization, no output should happen before this.
# The environment must be set up already.

$CURRPROG = basename($0);
$IDENTIFIER = "_" . basename($0, ".pl");

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
print "$CURRPROG is started in directory '$currdir'\n";

# ----------
# Get the configuration file.

# first command line argument
my $cfgfile = $ARGV[0];
print "Configuration file=$cfgfile\n";

my @Sections = ( "GENERAL", "ORACLE", "ULS", "ORARMAN" );
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
show_hash(\%CFG, " = ");
print "-----\n\n";

# -----
# RMAN command identifier
# (like ORARMAN_FULL or LEVEL0)
# Must be a parameter of the [ORARMAN] section in the oracle_tools.conf

# second command line argument
$ORARMAN_PARAMETER = $ARGV[1];
if (! $ORARMAN_PARAMETER) {
  print STDERR $CURRPROG . ": Error: no command line argument given for an ORARMAN parameter!\n";
  exit(2);
}
print "RMAN command parameter:$ORARMAN_PARAMETER\n\n";

# ----------
# This sets the %ULS to all necessary values
# deriving from %CFG (configuration file),
# environment variables (ULS_*) and defaults.

uls_settings(\%ULS, \%CFG);

print "-- ULS settings:\n";
show_hash(\%ULS, " = ");
print "-----\n\n";

# ----------
# IDENTIFIER

# from [ORARMAN]      -- from script name
# REDOLOGS_IDENTIFIER || _orarman
# LEVEL0_IDENTIFIER   || _orarman
# LEVEL1_IDENTIFIER   || _orarman
$IDENTIFIER = $CFG{"ORARMAN.${ORARMAN_PARAMETER}_IDENTIFIER"} || $IDENTIFIER;

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

my $workdir = $ENV{"WORKING_DIR"} || $CFG{"GENERAL.WORKING_DIR"} || "/var/tmp/oracle_optools/$ENV{ORACLE_SID}";  # $currdir;

if ( ! (-e $workdir)) {
  print "Creating directory '$workdir' for work files.\n";
  if (! mkdir($workdir)) {
    print STDERR "$CURRPROG: Error: Cannot create directory '$workdir' => aborting!\n";
    exit(1);
  }
}

# -----
# WORKFILEPREFIX
#
# Prefix for work files.
# Add the lower case parameter of the command line parameter.
$WORKFILEPREFIX = "${IDENTIFIER}_" . lc($ORARMAN_PARAMETER);
# _orarman_level0
#
# If no oracle sid is found in the workfile prefix, then append it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _orarman_level0_orcl
#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /oracle/admin/orcl/oracle_tools/var/_orarman_level0_orcl

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

my $d = iso_datetime($STARTSECS);
$d =~ s/\d{1}$/0/;

set_uls_timestamp($d);


# ---- Send name of this script and its version
uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", " ");

# Signal handling, do own housekeeping, send data to ULS and exit on most signals.
use sigtrap 'handler' => \&signal_handler, 'normal-signals', 'error-signals';

# ---- Send also versions of ULS-modules.
uls_value($IDENTIFIER, "modules", "Misc $Misc::VERSION, Uls2 $Uls2::VERSION", " ");

uls_timing({
    teststep  => $IDENTIFIER
  , detail    => "start-stop"
  , start     => iso_datetime($STARTSECS)
});

# Send the ULS data up to now to have that for sure.
uls_flush(\%ULS);

# -------------------------------------------------------------------
# The real work starts here.
# ------------------------------------------------------------

# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
print "TMPOUT1=$TMPOUT1\n";
push(@TEMPFILES, $TMPOUT1);

# Use for the rman commands
$TMPOUT2 = "${WORKFILEPREFIX}_2.tmp";
print "TMPOUT2=$TMPOUT2\n";
push(@TEMPFILES, $TMPOUT2);

# Use for the rman output
$TMPOUT3 = "${WORKFILEPREFIX}_3.tmp";
print "TMPOUT3=$TMPOUT3\n";
push(@TEMPFILES, $TMPOUT3);

$ERROUTFILE = "${WORKFILEPREFIX}_errout.log";
push(@TEMPFILES, $ERROUTFILE);
print "ERROUTFILE=$ERROUTFILE\n";

print "DELIM=$DELIM\n";


# -----
# Which section is used in this run
# uls_value($IDENTIFIER, "used parameter in configuration file", $ORARMAN_PARAMETER, " ");


# ----- documentation -----
# Send the documentation to ULS

title("Documentation");

print "Prepare the documentation.\n";

# de-reference the return value to the complete hash.
%TESTSTEP_DOC = %{doc2hash(\*DATA)};


# ----- sqlplus command -----
# Check, if the sqlplus command has been redefined in the configuration file.

$SQLPLUS_COMMAND = $CFG{"ORACLE.SQLPLUS_COMMAND"} || $SQLPLUS_COMMAND;


# -------------------------------------------------------------------
# Check if Oracle database is running.

if (! general_info()) {
  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  uls_value($IDENTIFIER, "$ORARMAN_PARAMETER", 0, "[#]");

  end_script(1);
}

# -------------------------------------------------------------------
# Check if Oracle database runs in ARCHIVELOG mode (else no online backup possible)

if (! check_for_archivelog()) {
  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  uls_value($IDENTIFIER, "$ORARMAN_PARAMETER", 0, "[#]");

  end_script(1);
}


#--------------------------------------------------------------------

rman_backup();


# The real work ends here.
# -------------------------------------------------------------------

# $EXIT_VALUE = 0 => Ok, 1 => Error
uls_value($IDENTIFIER, "$ORARMAN_PARAMETER", 1-$EXIT_VALUE, "[#]");
# 0 => Error, 1 => Ok

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
*orarman.pl
============

This is a backup script that runs RMAN against an Oracle database and performs a 
command that is defined in the first command line argument <configuration_file>. 
In that <configuration_file> the script searches for an RMAN 
<command_identifier> which is specified as second command line argument
and executes that without making any changes to that.

This script is part of the Oracle OpTools and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org

message:
  If the script runs fine, it returns 'OK', else an error message.
  You should generate a notification for any other value.

runtime:
  The runtime of the script.

start-stop:
  The start and stop timestamps for the script.

script name, version:
  The name and version of this script.

modules:
  The used modules (.pm).

RMAN command file:
  Keeps the commands executed by the script.

RMAN log file:
  Keeps the log file of the execution of the RMAN commands.

<command line parameter>:
  The command line parameter (e.g. FULL, LEVEL0, REDOLOGS), which identifies the parameter 
  that contains the RMAN commands in the ORARMAN section. This is a dynamic detail. 
  A value of 0 (zero) indicates an error, a value of 1 a successful execution of the script.

# exit value:
#   Is 0 if the script has finished without errors,
#   1 if errors have occurred. This is intended to monitor the
#   proper execution of this script.
# 

Copyright 2008-2018, roveda

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

