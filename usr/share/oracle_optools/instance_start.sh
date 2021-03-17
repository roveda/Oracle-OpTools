#!/bin/bash
#
# instance_start.sh
#
# ---------------------------------------------------------
# Copyright 2016 - 2019, roveda
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
#   instance_start.sh  <oracle_environment_script>  {<listener_name> | DEFAULT | NONE}
#
# ---------------------------------------------------------
# Description:
#   Script to start an Oracle database instance.
#
#   <oracle_environment_script>: 
#       the full path of the script to set the
#       environment variables for Oracle, like ORACLE_HOME and ORACLE_SID
#
#   <listener_name>:
#      The name of the listener to be started.
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
# 2017-02-01      roveda      0.01
#   Fixed the missing usage of the environment script given as parameter.
#
# 2018-02-14      roveda      0.02
#   Changed check for successful sourcing the environment to [[ -z "$ORACLE_SID" ]]
#   instead of [ $? -ne 0 ] (what does not work).
#
# 2019-07-03      roveda      0.03
#   Now supporting Data Guard Standby databases. Starting up only in MOUNTED.
#
# ---------------------------------------------------------

USAGE="instance_start.sh  <oracle_environment_script>  { <listener_name> | DEFAULT | NONE }"

# -----
# Go to directory where this script is placed
cd $(dirname $0)
. ./ooFunctions

# -------------------------------------------------------------------
title "$0 started"

# YYYY-MM-DD when the script has been started.
STARTED=$(date +"%Y-%m-%d")

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
    ;;
  DEFAULT)
    # If 'DEFAULT' has been given as listener name, 
    # start the listener with default listener name

    echo "Starting the default listener"
    echo
    lsnrctl start
    if [ $? -ne 0 ] ; then
      echo "WARNING: Cannot start the default listener!"
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
      echo "WARNING: Cannot start the non-default listener '$LISTENER_NAME'!"
    else
      echo "INFO: Successfully started the non-default listener '$LISTENER_NAME'."
    fi
    ;;
esac

# -----
# Database

title "Starting Oracle Database Server"

echo "ORACLE_HOME=$ORACLE_HOME"
echo "ORACLE_SID=$ORACLE_SID"
echo
echo "+------------------------------------------------------------+"
echo "|                                                            |"
echo "| Performing a STARTUP MOUNT, this may take a while...       |"
echo "|                                                            |"
echo "+------------------------------------------------------------+"
echo

# -----
# STARTUP MOUNT

sql_exec "STARTUP MOUNT"

# -----
# Check for MOUNTED

OPENMODE=$(sql_value "SELECT STATUS FROM V\$INSTANCE;")
if [[ "$OPENMODE" != "MOUNTED" ]] ; then
  echo
  echo "================================================================"
  echo "ERROR: Database is not 'MOUNTED'! Shutting down..."
  sql_exec "SHUTDOWN IMMEDIATE"
  echo "================================================================"
  title "Aborted"
  exit 1
fi
# Database is MOUNTED


# -----
# Check for DataGuard Standby
DBROLE=$(sql_value "SELECT DATABASE_ROLE FROM V\$DATABASE;")

if [[ "$DBROLE" == "PRIMARY" ]] ; then
  echo
  echo "+-------------------------------------------------------------+"
  echo "|                                                             |"
  echo "| Performing an ALTER DATABASE OPEN, this may take a while... |"
  echo "|                                                             |"
  echo "+-------------------------------------------------------------+"
  echo
  sql_exec "ALTER DATABASE OPEN;"

  # Check for READ WRITE

  OPENMODE=$(sql_value "SELECT STATUS FROM V\$INSTANCE;")
  if [[ "$OPENMODE" != "OPEN" ]] ; then
    echo
    echo "================================================================"
    echo "ERROR: Database is not 'OPEN'! Shutting down..."
    sql_exec "SHUTDOWN IMMEDIATE"
    echo "================================================================"
    title "Aborted"
    exit 1
  fi
fi

echo
echo "SUCCESS: Database '$ORACLE_SID' is '$OPENMODE', database role '$DBROLE'."
echo
title "Oracle Database Server started"

title "Finished"
exit 0

