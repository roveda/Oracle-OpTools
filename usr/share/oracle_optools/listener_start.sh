#!/bin/bash
#
# listener_start.sh
#
# ---------------------------------------------------------
# Copyright 2019, roveda
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
#   listener_start.sh  <oracle_environment_script>  {<listener_name> | DEFAULT | NONE}
#
# ---------------------------------------------------------
# Description:
#   Script to start a listener.
#
#   <oracle_environment_script>: 
#       the full path of the script to set the
#       environment variables for Oracle, like ORACLE_HOME and ORACLE_SID
#
#   <listener_name>:
#      The name of the listener to be startied.
#   DEFAULT:
#      Start the default listener.
#
#   NONE:
#      Do not start any listener.
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
# 2019-05-14      roveda      0.01
#   Extracted from instance_start.sh
#
#
# ---------------------------------------------------------

USAGE="listener_start.sh  <oracle_environment_script>  { <listener_name> | DEFAULT | NONE }"

# -------------------------------------------------------------------
title () {
  # Echo a title to stdout.
  local DT=`date +"%Y-%m-%d %H:%M:%S"`

  local A="--[ $*"
  A=`echo $A | awk '{printf("%.53s", $0)}'`
  A="$A ]---------------------------------------------------------------"
  A=`echo $A | awk '{printf("%.56s", $0)}'`
  A="$A[ $DT ]-"

  echo
  echo $A
  echo
}
# -------------------------------------------------------------------
# -------------------------------------------------------------------

title "$0 started"

# YYYY-MM-DD when the script has been started.
STARTED=$(date +"%Y-%m-%d")

# -----
# Go to directory where this script is placed
cd $(dirname $0)

# -----
# Check number of arguments

if [[ $# -ne 2 ]] ; then
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV=$(eval "echo $1")

if [[ ! -f "$ORAENV" ]] ; then
  echo "Error: environment script '$ORAENV' not found => abort"
  exit 2
fi

. $ORAENV
if [[ -z "$ORACLE_SID" ]] ; then
  echo
  echo "Error: the Oracle environment is not set up correctly => aborting script"
  echo
  exit 2
fi

# -----
unset LC_ALL
export LANG=C

# -----
# HOSTNAME is used, but may not be set in cronjobs

HOSTNAME=$(uname -n)
export HOSTNAME

# -----
# Listener

title "Starting Oracle Listener"

LISTENER_NAME="$2"

UC_LISTENER_NAME=$(echo $LISTENER_NAME | tr [[:lower:]] [[:upper:]])

case $UC_LISTENER_NAME in
  NONE)
    echo "No listener is started!"
    title "Finished"
    exit 0
    ;;
  DEFAULT)
    # If 'DEFAULT' has been given as listener name, 
    # start the listener with default listener name

    echo "Starting the default listener"
    echo
    lsnrctl start
    if [ $? -ne 0 ] ; then
      echo "ERROR: Cannot start the default listener!"
      exit 1
    else
      echo "INFO: Successfully started the default listener."
    fi
    ;;
  *)
    # custom listener name
    echo "Starting the non-default listener '$LISTENER_NAME'..."
    echo
    lsnrctl start $LISTENER_NAME
    if [ $? -ne 0 ] ; then
      echo "ERROR: Cannot start the non-default listener '$LISTENER_NAME'!"
      exit 1
    else
      echo "INFO: Successfully started the non-default listener '$LISTENER_NAME'."
    fi
    ;;
esac

# -----
# Test by tnsping
# When running thru this section, a listener must run.

# Assume, you have defined ORACLE_SID as a net service name.

if tnsping $ORACLE_SID ; then
fi

echo
echo "SUCCESS: Database is 'OPEN'."

title "Finished"
exit 0

