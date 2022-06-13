#!/usr/bin/env bash
#
# backup_database_files.sh - backup the database old style, all datafiles
#
# ---------------------------------------------------------
# Copyright 2017-2018, 2021, roveda
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
#   backup_database_files.sh <oracle_env_script>
#
# ---------------------------------------------------------
# Description:
#
#   The database backup is done in old style, file by file for each tablespace.
#   Section [ORABACKUP] is used. 
#
#   RMAN is NOT!!! used.
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
# 2017-02-07      roveda      0.01
#   Created
#
# 2018-02-14      roveda      0.02
#   Changed all checks for successful sourcing the environment to
#   -z "$ORACLE_SID"
#   instead of
#   $? -ne 0 (what does not work)
#
# 2021-12-02      roveda      0.03
#   Get current directory thru 'readlink'.
#   Set LANG=en_US.UTF-8
#
# 2021-12-08      roveda      0.04
#   unset ORACLE_PATH and SQLPATH to prohibit processing of login.sql
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
export LANG=en_US.UTF-8
# Prohibit the reading of a possible login.sql
unset ORACLE_PATH SQLPATH


# -----
# Check if database backup is turned off

# To turn off the database backup, you must enter the appropriate date
# (yyyy-mm-dd) in file  /var/tmp/oracle_${ORACLE_SID}.norman.
#

if [ "`uname`" != "HP-UX" ] ; then
  # Check if current date (minus 12 hours) is listed in
  # file /var/tmp/oracle_optools/${ORACLE_SID}/no_backup

  # Date, 12 hours ago, (e.g.: 2016-06-16)
  LOGICAL_START_DATE=$(date -d "-12 hours" +"%F")

  if [ -r /var/tmp/oracle_optools/${ORACLE_SID}/no_backup ] ; then
    # Does this date exist in the /var/tmp/oracle_optools/${ORACLE_SID}/no_backup file?
    FOUND=$(grep -c $LOGICAL_START_DATE /var/tmp/oracle_optools/${ORACLE_SID}/no_backup)
    if [ $FOUND -gt 0 ] ; then
      # No backup
      exit 0
    fi
  fi
fi

# -----
# Backup of database

export LANG=en_US.UTF-8
# Set Oracle NLS parameter
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"
export NLS_TIMESTAMP_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_TIMESTAMP_TZ_FORMAT="YYYY-MM-DD HH24:MI:SS TZH:TZM"

./run_perl_script.sh $ORAENV orabackup.pl  /etc/oracle_optools/standard.conf

