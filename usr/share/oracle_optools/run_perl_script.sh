#!/bin/bash
#
# run_perl_script.sh
#
# ---------------------------------------------------------
# Copyright 2016, roveda
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
# ===================================================================


USAGE="run_perl_script.sh <oracle_environment_script> <perl_script_name> <standard_conf_file> [ <parameters_to_perl_script> ] "

unset LC_ALL
export LANG=C

cd `dirname $0`

# -----
# Check number of arguments

if [[ $# -lt 3 ]] ; then
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV=$(eval "echo $1")
shift 1

if [[ ! -f "$ORAENV" ]] ; then
  echo "Error: environment script '$ORAENV' not found => abort"
  exit 2
fi

. "$ORAENV"
if [ $? -ne 0 ] ; then
  echo
  echo "Error: Cannot source environment script '$ORAENV' => abort"
  exit 2
fi

# -----
# Check for script

SCRIPT="$1"
shift 1

if [[ ! -r "$SCRIPT" ]] ; then
  echo
  echo "Error: The script '$SCRIPT' is not readable or cannot be found => abort"
  exit 2
fi


# -----
# Check for standard conf file

CONF="$1"
shift 1

if [[ ! -r "$CONF" ]] ; then
  echo
  echo "Error: The standard configuration file '$CONF' is not readable or cannot be found => abort"
  exit 2
fi


# -----
# HOSTNAME is used, but perhaps not set in cronjobs

HOSTNAME=`uname -n`
export HOSTNAME

# Remember to include the directory where flush_test_values can
# be found ('/usr/bin' or '/usr/local/bin') in the PATH.


# -----
# Exit silently, if the TEST_BEFORE_RUN command does
# not return the exit value 0.

perl test_before_run.pl "$CONF" > /dev/null 2>&1 || exit


# -----
# Call the script.

# Set for decimal point, english messages and ISO date representation
# (for this script execution only).
# export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
export NLS_LANG=AMERICAN_AMERICA.UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"

perl "$SCRIPT" "$CONF" "$@" 

