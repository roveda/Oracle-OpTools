#!/usr/bin/env bash
#
# ipprotd_start.sh
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
#   ipprotd_start.sh  <oracle_environment_script>  <ip_address>
#
# ---------------------------------------------------------
# Description:
#   Script to start an ipprotd daemon
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
LISTENER_IP="$2"


# -----
unset LC_ALL
export LANG=C


# -----
# Start the ipprot daemon

ipprotd -p 6544@$LISTENER_IP -P 6543@$LISTENER_IP -L -s -t 180 -f /oracle/admin/$ORACLE_SID/connection_protocol/prot -j -u /oracle/admin/$ORACLE_SID/oracle_tools/send_ipprot -Dp /oracle/admin/$ORACLE_SID/connection_protocol/pid_6544_$LISTENER_IP
RET=$?


title "Finished"
exit $RET

