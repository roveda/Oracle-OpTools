#!/usr/bin/env bash
#
# instance_stop.sh
#
# ---------------------------------------------------------
# Copyright 2016-2019, 2021, roveda
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
#   instance_stop.sh  <oracle_environment_script>  { <listener_name> | DEFAULT | NONE }  [ABORT]
#
# ---------------------------------------------------------
# Description:
#   Script to stop an Oracle instance.
#
#   <oracle_environment_script>:
#      The full path of the script to set the
#      environment variables for Oracle, like ORACLE_HOME and ORACLE_SID
#
#   <listener_name>:
#      The name of the listener to be stopped.
#   DEFAULT:
#      Stop the default listener.
#
#   NONE:
#      Do not stop any listener.
#
#   ABORT:
#      Shutdown the database with 'shutdown abort' instead of the default 'shutdown immediate'.
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
# 2017-02-01      roveda      0.01
#   Fixed the missing usage of the environment script given as parameter.
#
# 2018-02-14      roveda      0.02
#   Changed check for successful sourcing the environment to [[ -z "$ORACLE_SID" ]]
#   instead of [ $? -ne 0 ] (what does not work).
#
# 2019-07-03      roveda      0.03
#   Debugged the test of the parameter count. And ABORT is now recognized.
#
# 2021-12-02      roveda      0.04
#   Get current directory thru 'readlink'.
#   Set LANG=en_US.UTF-8
#   Using new box functions from ooFunctions
#
# ---------------------------------------------------------
#

USAGE="instance_stop.sh  <oracle_environment_script>  { <listener_name> | DEFAULT | NONE }  [ABORT]"

# -----
# Go to directory where this script is placed
mydir=$(dirname "$(readlink -f "$0")")
cd "$mydir"

. ./ooFunctions

# -----
title "$0 started"

# YYYY-MM-DD when the script has been started.
STARTED=$(date +"%Y-%m-%d")

# -----
# Check number of arguments

if [[ $# -lt 2 ]] ; then
  echoerr "Error: You must at least specify 2 parameters => ABORTING SCRIPT"
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV=$(eval "echo $1")

if [[ ! -f "$ORAENV" ]] ; then
  echoerr "Error: environment script '$ORAENV' not found => ABORTING SCRIPT"
  exit 2
fi

. $ORAENV
if [[ -z "$ORACLE_SID" ]] ; then
  echoerr "Error: the Oracle environment is not set up correctly => ABORTING SCRIPT"
  exit 2
fi

# -----

unset LC_ALL
# export LANG=C
export LANG=en_US.UTF-8

# -----
# HOSTNAME is used, but perhaps not set in cronjobs

HOSTNAME=$(uname -n)
export HOSTNAME

# for information only
echo "ORACLE_HOME=$ORACLE_HOME"
echo "ORACLE_SID=$ORACLE_SID"
echo

# -----
title "Stopping the Listener"

LISTENER_NAME="$2"
UC_LISTENER_NAME=${LISTENER_NAME^^}

case $UC_LISTENER_NAME in
  NONE)
    infobox "INFO:" "No listener is stopped!"
    ;;
  DEFAULT)
    # If 'DEFAULT' has been given as listener name,
    # start the listener with default listener name

    echo "Stopping the default listener"
    echo
    lsnrctl stop
    if [ $? -ne 0 ] ; then
      infobox "WARNING:" "Cannot stop the default listener!"
    else
      infobox "INFO:" "Successfully stopped the default listener."
    fi
    ;;
  *)
    # custom listener name
    echo "Stopping the non-default listener '$LISTENER_NAME'..."
    echo
    lsnrctl stop $LISTENER_NAME
    if [ $? -ne 0 ] ; then
      infobox "WARNING:" "Cannot stop the non-default listener '$LISTENER_NAME'!"
    else
      infobox "INFO:" "Successfully stopped the non-default listener '$LISTENER_NAME'."
    fi
    ;;
esac

# -----
# Shut down the database

# ABORT the database instance?
ABORT=${3:-NO}

title "Stopping Oracle Database Server"

# -----
ABORT_COMMAND="
SHUTDOWN ABORT;
STARTUP RESTRICT;
SHUTDOWN IMMEDIATE;
exit;
"

ABORT_MSG="
Performing a  SHUTDOWN ABORT
followed by a STARTUP RESTRICT
and a final   SHUTDOWN IMMEDIATE
      this may take a while...

The prompt 'SQL>' may be displayed for several minutes,
don't be impatient! This is Oracle!
"

# -----
SHUTDOWN_COMMAND="
SHUTDOWN IMMEDIATE;
exit;
"

SHUTDOWN_MSG="
Performing a SHUTDOWN IMMEDIATE
      this may take a while...

The prompt 'SQL>' may be displayed for several minutes,
don't be impatient! This is Oracle!
"

if [ "$ABORT" = "ABORT" ] ; then
  # -----
  # Long running transactions may deny the clean 'shutdown immediate',
  # so use 'shutdown abort' followed by a clean 'shutdown immediate'.
  # Currently, I do not know of any other solution.
  infobox "INFO:" "$ABORT_MSG"

  exec_sql "$ABORT_COMMAND"
else
  # shutdown immediate
  infobox "INFO:" "$SHUTDOWN_MSG"

  sql_exec "$SHUTDOWN_COMMAND"
fi

# -----
# Always assume, the database was stopped successfully.

title "Finished"

exit 0

