#!/bin/bash
#
# nightly.sh - execute scripts each night
#
# ---------------------------------------------------------
# Copyright 2016 - 2017, roveda
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
#   nightly.sh  <oracle_env_script>
#
# ---------------------------------------------------------
# Description:
#   Do some nightly jobs.
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
if [ $? -ne 0 ] ; then
  echo
  echo "Error: Cannot source Oracle's environment script '$ORAENV' => abort"
  echo
  exit 1
fi

unset LC_ALL
export LANG=C

# -----
# Generate a daily report of the database statspack performance snapshots
# (only if configured)

# ./ora_statspack.sh REPORT DAILY_REPORT
./run_perl_script.sh $ORAENV ora_statspack.pl  /etc/oracle_optools/standard.conf  REPORT  DAILY_REPORT


# -----
# AWR and ADDM report
#
# NOTE: Use this ONLY(!) if you have the necessary Oracle product option licensed!!!

# ./ora_awr_addm.sh 
./run_perl_script.sh $ORAENV ora_awr_addm.pl  /etc/oracle_optools/standard.conf


# -----
# Generate a database configuration report

# ./ora_dbinfo.sh
./run_perl_script.sh $ORAENV ora_dbinfo.pl  /etc/oracle_optools/standard.conf


# -----
# Housekeeping
#
# That purges old audit entries,
# deletes old tracefiles and rotates the logfiles on sundays.

# [ -x ./ora_housekeeping.sh ] && ./ora_housekeeping.sh
./run_perl_script.sh $ORAENV ora_housekeeping.pl  /etc/oracle_optools/standard.conf


# -----
# Remove old audit files
#   Set the path according to Oracle's parameter 'audit_file_dest'.
#
#   This must always be set, because SYSDBA connections are always logged there.
#   (If ora_housekeeping does not work or the configuration does not match)

find /oracle/admin/$ORACLE_SID/?dump -follow -type f -mtime +10 -exec rm {} \; > /dev/null 2>&1


# -----
# Remove old archived redo logs
#   Only together with old style database backup!
#   RMAN will take care of the archived redo logs itself.
#   Set the path to 'log_archive_dest_?', perhaps you need
#   multiple entries. Adjust the '+10' (days) to your needs.
#   '-follow' is needed for linked directories.
#
# find /oracle/backup/$ORACLE_SID/archived_redo_logs/ -follow -type f -mtime +10 -exec rm {} \; > /dev/null 2>&1
# find /oracle/archived_redo_logs/$ORACLE_SID/ -follow -type f -mtime +10 -exec rm {} \; > /dev/null 2>&1

# -----
# Remove old connection protocol files made by ipprotd.
#
find /oracle/admin/$ORACLE_SID/connection_protocol -name "prot_*" -follow -type f -mtime +10 -exec rm {} \; > /dev/null 2>&1


# -----
# Remove *.tmp files from current directory

find . -follow -type f -name "*.tmp" -mtime +10 -exec rm {} \; > /dev/null 2>&1

