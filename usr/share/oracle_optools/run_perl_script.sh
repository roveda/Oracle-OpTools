#!/usr/bin/env bash
#
# run_perl_script.sh
#
# ---------------------------------------------------------
# Copyright 2016-2018, 2021, roveda
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
# along with the 'Oracle OpTools'.  If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   run_perl_script.sh <oracle_environment_script> <perl_script_name> 
#                      <standard_conf_file> [ <parameters_to_perl_script> ]
#
# ---------------------------------------------------------
# Description:
#   This script sources the <oracle_environment_script>, 
#   executes the test_before_run script and continues if its 
#   return value is ok. 'perl' is started with the given <perl_script_name>
#   taking the <standard_conf_file> as first parameter and 
#   any additional remaining arguments are passed to the <perl_script_name>
#   as further parameters.
#
#   Send any hints, wishes or bug reports to:
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Dependencies:
#
# ---------------------------------------------------------
# Restrictions:
#
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts in a test environment initially.
#
# ---------------------------------------------------------
# Versions:
#
# date            name        version
# ----------      ----------  -------
# 2016-09-03      roveda      0.01
#   Created
#
# 2017-01-30      roveda      0.02
#   Changed some text.
#
# 2018-02-14      roveda      0.03
#   Changed check for successful sourcing the environment to [[ -z "$ORACLE_SID" ]]
#   instead of [ $? -ne 0 ] (what does not work).
#
# 2021-04-22      roveda      0.04
#   The exit value of the executed perl script is used as the exit value of this script.
#   Added more NLS_ variables.
#
# 2021-12-02      roveda      0.05
#   Get current directory thru 'readlink'.
#   Set LANG=en_US.UTF-8, use ooFunctions.
#
# 2021-12-08      roveda      0.06
#   unset ORACLE_PATH and SQLPATH to prohibit processing of login.sql
#
# ===================================================================


USAGE="run_perl_script.sh <oracle_environment_script> <perl_script_name> <standard_conf_file> [ <parameters_to_perl_script> ] "

mydir=$(dirname "$(readlink -f "$0")")
cd "$mydir"

. ./ooFunctions

unset LC_ALL
# export LANG=C
export LANG=en_US.UTF-8


# -----
# Check number of arguments

if [[ $# -lt 3 ]] ; then
  echoerr "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV=$(eval "echo $1")
shift 1

if [[ ! -f "$ORAENV" ]] ; then
  echoerr "ERROR: environment script '$ORAENV' not found => aborting script"
  exit 2
fi

. "$ORAENV"
if [[ -z "$ORACLE_SID" ]] ; then
  echoerr "ERROR: the Oracle environment is not set up correctly => aborting script"
  exit 2
fi

# -----
# Check for script

SCRIPT="$1"
shift 1

if [[ ! -r "$SCRIPT" ]] ; then
  echoerr "ERROR: The script '$SCRIPT' is not readable or cannot be found => aborting script"
  exit 2
fi


# -----
# Check for standard conf file

CONF="$1"
shift 1

if [[ ! -r "$CONF" ]] ; then
  echoerr "ERROR: The standard configuration file '$CONF' is not readable or cannot be found => aborting script"
  exit 2
fi


# -----
# HOSTNAME is used, but perhaps not set in cronjobs

HOSTNAME=`uname -n`
export HOSTNAME

# Remember to include the directory where flush_test_values can
# be found ('/usr/bin' or '/usr/local/bin') in the PATH.

# -----
unset LC_ALL
# Set LANG explicitly to be used in the Perl scripts
export LANG=en_US.UTF-8

# Prohibit the reading of a possible login.sql
unset ORACLE_PATH SQLPATH

# Set Oracle NLS parameter
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"
export NLS_TIMESTAMP_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_TIMESTAMP_TZ_FORMAT="YYYY-MM-DD HH24:MI:SS TZH:TZM"

# -----
# Exit silently, if the TEST_BEFORE_RUN command does
# not return the exit value 0.

perl test_before_run.pl "$CONF" > /dev/null 2>&1 || exit 2

# -----
# Call the script.

perl "$SCRIPT" "$CONF" "$@" 

exit $?

