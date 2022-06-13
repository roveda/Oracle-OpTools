#!/usr/bin/env bash
#
# nightly.sh - execute scripts each night
#
# ---------------------------------------------------------
# Copyright 2016-2018, 2021, 2022, roveda
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
# 2018-02-14      roveda      0.02
#   Changed check for successful sourcing the environment to [[ -z "$ORACLE_SID" ]]
#   instead of [ $? -ne 0 ] (what does not work).
#
# 2021-12-02      roveda      0.03
#   Get current directory thru 'readlink'.
#   Set LANG=en_US.UTF-8
#   Using new box functions from ooFunctions
#
# 2021-12-08      roveda      0.04
#   unset ORACLE_PATH and SQLPATH to prohibit processing of login.sql
#
# 2022-03-25      roveda      0.05
#   Find the adump directory and remove all *.aud files older than 8 days.
#   Remove left over temporary files in /tmp if older than 3 days.
#
#
# ---------------------------------------------------------


# Go to directory where this script is placed
mydir=$(dirname "$(readlink -f "$0")")
cd "$mydir"

. ./ooFunctions

# -----
# Set environment

ORAENV=$(eval "echo $1")

if [[ ! -f "$ORAENV" ]] ; then
  echoerr "Error: environment script '$ORAENV' not found => abort"
  exit 1
fi

. $ORAENV
if [[ -z "$ORACLE_SID" ]] ; then
  echoerr "Error: the Oracle environment is not set up correctly => aborting script"
  exit 1
fi

unset LC_ALL
# export LANG=C
export LANG=en_US.UTF-8
# Prohibit the reading of a possible login.sql
unset ORACLE_PATH SQLPATH

# Set Oracle NLS parameter
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"
export NLS_TIMESTAMP_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_TIMESTAMP_TZ_FORMAT="YYYY-MM-DD HH24:MI:SS TZH:TZM"

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

# Find adump in directory below /db
for d in $(find /db -type d -name adump) ; do
  # Purge files older than 8 days
  # also in sub-directories
  find $d -type f -mtime +8 -name "*.aud" -delete
done


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

# -----
# Remove old temporary files that are left over

find /tmp -maxdepth 1 -user oracle -type f -mtime +3 -name "tmp.*" -delete

