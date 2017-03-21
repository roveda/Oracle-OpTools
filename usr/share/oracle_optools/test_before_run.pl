#!/usr/bin/perl
#
# test_before_run.pl - Test, if any Oracle OpTools script is to be run or not
#
# ---------------------------------------------------------
# Copyright 2013 - 2017, roveda
#
# This file is part of the 'Oracle OpTools'.
#
# The 'Oracle OpTools' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The 'Oracle OpTools' is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the 'Oracle OpTools'. If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   perl test_before_run.pl <configuration_file>
#
# ---------------------------------------------------------
# Description:
#   This script reads the <configuration_file> and gets the 
#   command defined in TEST_BEFORE_RUN. The script executes the 
#   command on system level and returns 0 if it was successful 
#   or it returns 1 if it was not successful.
#
#   It can be used to find out if any script of the Oracle OpTools
#   shall be executed or not. The test may e.g. be a test if a 
#   specific directory is mounted or a process is running.
#
#   Send any hints, wishes or bug reports to: 
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Restrictions:
#
# ---------------------------------------------------------
# Dependencies:
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
# 2013-08-18      roveda      0.01
#    Creation.
#
# 2013-08-24      roveda      0.02
#    Support no command as no tests necessary, exit(0)
#
# 2016-03-18      roveda      0.03
#    Added support for oracle_tools_SID.conf
#    (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2017-01-24      roveda      0.04
#    Changed copyright text.
#
# 2017-03-21      roveda      0.05
#   Fixed the broken support of sid specific configuration file.
#   Updated the version reference for Misc.pm.
#
#
#    Change also $VERSION later in this script!
#
# ===================================================================


use strict;
use warnings;
use File::Basename;

# These are my modules:
use lib ".";
use Misc 0.40;

my $VERSION = 0.05;

# ===================================================================
# The "global" variables
# ===================================================================

# Name of this script.
my $CURRPROG = "";

# This keeps the contents of the configuration file
my %CFG;

# ===================================================================
# main
# ===================================================================
#
# -------------------------------------------------------------------
# Get configuration file contents

my $cfgfile = $ARGV[0];
# print "configuration file=$cfgfile\n";

my @Sections = ( "GENERAL" );
# print "Reading sections: ", join(",", @Sections), " from configuration file\n";

if (! get_config2($cfgfile, \%CFG, @Sections)) {
  print STDERR "$CURRPROG: Error: Cannot parse configuration file '$cfgfile' correctly => aborting\n";
  exit(1);
}

# Check for SID-specific .conf file
my ($name,$dir,$ext) = fileparse($cfgfile,'\..*');
# $cfgfile = "${dir}${name}_$ENV{ORACLE_SID}${ext}";
$cfgfile = "${dir}$ENV{ORACLE_SID}${ext}";

if (-r $cfgfile) {
  # print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' found => processing it.\n";

  if (! get_config2($cfgfile, \%CFG, @Sections)) {
    print STDERR "$CURRPROG: Error: Cannot parse ORACLE_SID-specific configuration file '$cfgfile' correctly => aborting\n";
    exit(1);
  }
# } else {
#   print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' NOT found. Executing with defaults.\n";
}

# show_hash(\%CFG, "=");
# print "-----\n\n";

my $cmd = $CFG{"GENERAL.TEST_BEFORE_RUN"};
# print "cmd=[$cmd]\n";

if (! $cmd) {
  # Got no command, assume no tests are necessary.
  # print "Continue with script...\n";
  exit(0);
}

my $cmd_out = `$cmd`;
my $result = $?;
# print "result=$result\n";

if ($result != 0) {
  # print "Do not execute script!\n";
  exit(1);
}

# print "Continue with script...\n";
exit(0);


