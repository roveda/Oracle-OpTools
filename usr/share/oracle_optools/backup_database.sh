#!/usr/bin/env bash
#
# backup_database.sh - backup the database regularly
#
# ---------------------------------------------------------
# Copyright 2016-2018, 2021, roveda
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
#   backup_database.sh <oracle_env_script> [<parameter_in_conf>]
#
# ---------------------------------------------------------
# Description:
#
#   <parameter_in_conf> must match a parameter in the configuration file
#   in section [ORARMAN]. If not given, it defaults to FULL.
#   That can be used to make a LEVEL1 backup on weekdays, 
#   and a FULL backup on sundays (or whatever day combination 
#   makes sense for you).
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
# 2017-02-07      roveda      0.02
#   Use LEVEL0 instead of FULL as default. FULL does not exist in the standard.conf
# 
# 2018-02-14      roveda      0.03
#   Changed check for successful sourcing the environment to [ -z "$ORACLE_SID" ]
#   instead of [ $? -ne 0 ] (what does not work).
#
# 2019-07-16      roveda      0.04
#   Checking role and status of database. Continue to backup only
#   if it is PRIMARY,OPEN. Do nothing for PHYSICAL STANDBY,MOUNTED.
#   Give error for anything else.
#
# 2021-04-22      roveda      0.05
#   Exit value of backup script is used as exit value of this script.
#
# 2021-12-02      roveda      0.06
#   Get current directory thru 'readlink'.
#   Set LANG=en_US.UTF-8
#
# 2021-12-08      roveda      0.07
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
# export LANG=C
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
# Check the role and status of the database

ROLESTAT=$(./get_role_status.sh $ORAENV)

ROLEPARAMETER=${2:-LEVEL0}

case $ROLESTAT in
  "PRIMARY,OPEN") # echo "$ROLESTAT"
    # continue normally
    ;;
  "PHYSICAL STANDBY,MOUNTED") # echo "$ROLESTAT"
    # add "_STANDBY" to the parameter
    ROLEPARAMETER="${ROLEPARAMETER}_STANDBY"
    ;;
  *) echo "Anything else"
    exiterr 2 "ERROR: This database role and status '$ROLESTAT' is not supported => ABORT"
    ;;
esac

# -----
# Backup of database

# NOTE:
#   ./orarman PARAMETER
#   The orarman parameter must match a parameter in
#   the [ORARMAN] section of the configuration file!
# BUT:
#   The RMAN commands in the [ORARMAN] section determine the ACTUAL ACTIONS
#   (the actual RMAN commands) which are executed during the script execution.
#   The parameter is only an arbitrary text expression.

# Execute the RMAN commands of section [ORARMAN] and parameter LEVEL0
# (or use the given second command line parameter as parameter)

# -----
# Set LANG explicitly to be used in the Perl scripts
export LANG=en_US.UTF-8

# Set Oracle NLS parameter
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"
export NLS_TIMESTAMP_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_TIMESTAMP_TZ_FORMAT="YYYY-MM-DD HH24:MI:SS TZH:TZM"

./run_perl_script.sh $ORAENV orarman.pl  /etc/oracle_optools/standard.conf  $ROLEPARAMETER
retval=$?

exit $retval

