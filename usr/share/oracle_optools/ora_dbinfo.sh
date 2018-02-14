#!/bin/bash
#
# ora_dbinfo.sh
#
# ---------------------------------------------------------
# Copyright 2017 - 2018, roveda
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
#   ora_dbinfo.sh  [ <oracle_environment_script> ]
#
# ---------------------------------------------------------
# Description:
#   This script uses the current ORACLE_SID or (!) sources the optionally
#   given <oracle_environment_script> and uses that ORACLE_SID, 
#   and executes the ora_dbinfo.pl script.
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
# 2017-10-30      roveda      0.01
#   Created
#
# 2018-02-14      roveda      0.02
#   Changed check for successful sourcing the environment to [[ -z "$ORACLE_SID" ]]
#   instead of [ $? -ne 0 ] (what does not work).
#
#
# ===================================================================


USAGE="ora_dbinfo.sh  [ <oracle_environment_script> ] "

# The standard configuration file is found as:
CONF=/etc/oracle_optools/standard.conf

# The script to call
SCRIPT=ora_dbinfo.pl

# unset language variables
unset LC_ALL
export LANG=C

# Go to directory where this script is located
cd $(dirname $0)

# -----
# Check, if ORACLE_SID is set in current environment

if [[ -z "$ORACLE_SID" ]] ; then
  # -----
  # If not set, you MUST have given a parameter

  if [[ $# -lt 1 ]] ; then
    echo "$USAGE"
    exit 1
  fi
  ORAENV=$(eval "echo $1")

else
  # Use the current ORACLE_SID
  ORAENV=$(eval "echo ~oracle/oracle_env_$ORACLE_SID")

fi

# -----
# Set environment

if [[ ! -f "$ORAENV" ]] ; then
  echo "Error: environment script '$ORAENV' not found => abort"
  exit 2
fi

. "$ORAENV"
if [[ -z "$ORACLE_SID" ]] ; then
  echo
  echo "Error: the Oracle environment is not set up correctly => aborting script"
  exit 2
fi

# -----
# HOSTNAME is used, but perhaps not set in cronjobs

HOSTNAME=`uname -n`
export HOSTNAME

# Remember to include the directory where flush_test_values can
# be found ('/usr/bin' or '/usr/local/bin') in the PATH.


# -----
# Exit, if the TEST_BEFORE_RUN command does
# not return the exit value 0.

if perl test_before_run.pl "$CONF" > /dev/null 2>&1 ; then
  :
else
  echo "The test before run check was not successful => abort"
  exit 3
fi


# -----
# Call the script.

# Set for decimal point, english messages and ISO date representation
# (for this script execution only).
# export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
export NLS_LANG=AMERICAN_AMERICA.UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"

perl "$SCRIPT" "$CONF"

