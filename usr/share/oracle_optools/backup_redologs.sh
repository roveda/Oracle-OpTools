#!/bin/bash
#
# backup_redologs.sh - backup the redo logs regularly
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
#   backup_redologs.sh <oracle_env_script>
#
# ---------------------------------------------------------
# Description:
#
#   Backup the unsaved redo logs to the backup destination.
# 
#   Send any hints, wishes or bug reports to:
#     roveda at universal-logging-system.org
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
#   Changed check for successful sourcing the environment to [ -z "$ORACLE_SID" ]
#   instead of [ $? -ne 0 ] (what does not work).
#
# 2019-01-02      roveda      0.03
#   Added support for skipping the redo log backup based on time intervals 
#   defined in /var/tmp/oracle_optools/${ORACLE_SID}/no_backup_redologs.
#
# ---------------------------------------------------------


# Go to directory where this script is placed
cd `dirname $0`


# -----
# Set environment
ORAENV=$(eval "echo $1")

if [[ ! -f "$ORAENV" ]] ; then
  echo "Error: environment script '$ORAENV' not found => abort"
  exit 1
fi

. $ORAENV
if [[ -z "$ORACLE_SID" ]] ; then
  echo
  echo "Error: the Oracle environment is not set up correctly => aborting script"
  echo
  exit 1
fi

unset LC_ALL
export LANG=C


# -----
# Check if redo log backup is turned off

# To turn off the redo log backup, you must enter the appropriate date interval in file:
#   /var/tmp/oracle_optools/${ORACLE_SID}/no_backup_redologs
#
# You find a template file here:
#   /var/tmp/oracle_optools/no_backup_redologs.template
#
# Format of interval to skip the redo log backup (interval_begin interval_end):
#   yyyy-mm-dd_HH:MI:SS yyyy-mm-dd_HH:MI:SS
#
SKIPFILE=/var/tmp/oracle_optools/${ORACLE_SID}/no_backup_redologs

if [ -r $SKIPFILE ] ; then
  NOW=$(date +"%Y-%m-%d_%H:%M:%S")

  F=$(mktemp).tmp
  # skip empty lines, skip lines beginning with '#'
  sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*#/d' $SKIPFILE > $F

  while read timeint_begin timeint_end ; do
    if [[ "$NOW" > "$timeint_begin" ]] ; then
      if [[ "$NOW" < "$timeint_end" ]] ; then
        # echo "Do NOT execute the redo log backup"
        exit 0
      fi
    fi
  done < $F
  rm $F
  # echo "Execute the redo log backup"
fi

# -----
# Backup the redo log and archived redo logs
#

# Try again, if first execution fails.
C=1

while [ 1 ]; do

  # The parameter must match a parameter in the ORARMAN section in the configuration file!
  # Leave the loop, if successful.
  # ./orarman.sh REDOLOGS  && break
  ./run_perl_script.sh $ORAENV orarman.pl  /etc/oracle_optools/standard.conf REDOLOGS  && break

  # Continue the loop if the script has failed, 
  # but bail out after the second try.
  [ $C -ge 2 ] &&  break

  # Increment loop counter
  let C+=1

  # Wait for 6..8 minutes before trying again.
  sleep $((360 + $RANDOM % 120))

done


