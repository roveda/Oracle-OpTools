#!/usr/bin/env bash
#
# ipprotd_stop.sh
#
# ---------------------------------------------------------
# Copyright 2018, roveda
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
#   ipprotd_stop.sh  <oracle_environment_script>  <ip_address>
#
# ---------------------------------------------------------
# Description:
#   Script to stop an ipprotd daemon
#
#   <oracle_environment_script>:
#       the full path of the script to set the
#       environment variables for Oracle, like ORACLE_HOME and ORACLE_SID
#
#   <ip_address>:
#      The ip address to listen on and to write the tcp packets to.
#      That must be identical to the ip address of the listener.
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
# 2018-08-26      roveda      0.01
#
# ---------------------------------------------------------

USAGE="ipprotd_start.sh  <oracle_environment_script>  <ip_address>"

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

if [ -r /oracle/admin/$ORACLE_SID/connection_protocol/pid_6544_$LISTENER_IP ]; then
  # if the file with the pid exists
  P=$(cat /oracle/admin/$ORACLE_SID/connection_protocol/pid_6544_$LISTENER_IP)
  echo "PID=$P"

  if [ ! -z "$P" ] ; then

    # get the process name for that PID
    PNAME=$(ps --pid $P -o comm h)
    echo "Process name of PID $P: $PNAME"

    if [[ "$PNAME" != "ipprotd" ]] ; then
      echo "Error: Process with PID $P is not an ipprotd process."
    else
      echo "Killing $PNAME process with PID $P."
      kill $P
    fi

  else
    echo "Error: The process id is not a number. You must terminate the ipprotd process manually."
  fi
else
  echo "Error: the ipprotd process id file /oracle/admin/$ORACLE_SID/connection_protocol/pid_6544_$LISTENER_IP could not be found."
  exit 9
fi



title "Finished"
exit 0

