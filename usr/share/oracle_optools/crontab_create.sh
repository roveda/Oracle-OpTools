#!/bin/bash
#
# crontab_create.sh - create a default crontab file for the Oracle OpTools
#
# ---------------------------------------------------------
# Copyright 2017, roveda
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
#   crontab_create.sh <oracle_environment_script>  <destination_dir>  [ SILENT ]
#
# ---------------------------------------------------------
# Description:
#   Creates a crontab for the OpTools for Oracle Databases with 
#   start hours and minutes randomly scattered over a time interval.
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
# 2014-11-16      roveda      0.01
#   Created.
#
# 2015-01-07      roveda      0.02
#   Added the --silent option, which will suppress all informational output.
#
# 2016-06-01      roveda      0.03
#   environment script is optionally given as parameter
#
# 2016-06-16      roveda      0.04
#   Changed to .sh script names, added the environment script as parameter
#
# 2016-06-27      roveda      0.05
#   Add the uppercase ORACLE_SID to the crontab heading
#
# 2016-06-29      roveda      0.06
#   Set ORAENV to default value of ./oracle_env
#
# 2016-07-07      roveda      0.07
#   Changed to named argument for oracle's environment script
#   Removed the entry for watch_oracle.
#
# 2017-01-13      roveda      0.08
#   Rearranged the command line parameters.
#
# 2017-01-24      roveda      0.09
#   Added the LEVEL0 and LEVEL1 lines for the different weekdays.
#   The resulting crontab file is placed in the <destination_dir>.
#
# 2017-02-07      roveda      0.10
#   Added an entry for the old-style, file-by-file for each tablespace backup (orabackup).
#
# 2017-03-02      roveda      0.11
#   Changed comments in crontab
#
# 2017-05-29      roveda      0.12
#   Changed housekeeping from 22:00 to 03:00. DB-info report and AWR report will
#   therefor appear under 'today' in ULS which is the default. An explicit 
#   change to 'yesterday' was necessary previously. 
#
# 2017-10-04      roveda      0.13
#   Set the permissions to world-readable. Added the check for being root.
#
# 2017-10-30      roveda      0.14
#   Check for proper number of parameters corrected.
#
# -----------------------------------------------------------------------------

USAGE="crontab_create.sh  <oracle_environment_script>  <destination_dir>  [ SILENT ]"


if [ $EUID -ne 0 ]; then
   echo "$0: ERROR: This script can only be run as root => ABORTING"
   exit 1
fi

# -----
# Check number of arguments

if [[ $# -lt 2 ]] ; then
  echo "ERROR: Wrong number of command line parameters => ABORTING"
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment
ORAENV=$(eval "echo $1")

if [[ ! -f "$ORAENV" ]] ; then
  echo "ERROR: environment script '$ORAENV' not found => ABORTING"
  exit 1
fi

. "$ORAENV"
if [ $? -ne 0 ] ; then
  echo
  echo "ERROR: Cannot source Oracle's environment script '$ORAENV' => ABORTING"
  echo
  exit 1
fi

# -----
# Destination directory for the resulting crontab file

DESTDIR="$2"
if [ -d "$DESTDIR" ] && [ -x "$DESTDIR" ] && [ -w "$DESTDIR" ] ; then
  :
else
  echo
  echo "ERROR: Cannot access or write to directory '$DESTDIR' => ABORTING"
  echo
  exit 1
fi

# -----
# silent?

SILENT="$3"
SILENT=$(echo $SILENT | tr [[:lower:]] [[:upper:]])

if [[ "$SILENT" == 'SILENT' ]] ; then
  SILENT="yes"
fi

# -----
SID=$(echo $ORACLE_SID | awk '{print toupper($0)}')

unset LC_ALL
export LANG=C

# -----
# hour, 21..25 (21, 22, 23, 00, 01), for backup_database

H=$((21 + $RANDOM % 5))
if [ $H -gt 23 ] ; then
  H=$(( $H - 24 ))
fi


# -----
# minute, 01..59, for backup_database

M=$((1 + $RANDOM % 59))


# -----
# Minute for the backup_redologs, 30 mins offset to minutes of backup_database

N=$(( ($M + 30) % 60 ))

# -----
# weekday for the full backup

WD=$(($RANDOM % 7))
# [0..6]

WDS=""
for dy in 0 1 2 3 4 5 6 ; do
  if [[ dy -ne $WD ]] ; then
    if [[ ! -z "$WDS" ]] ; then
      WDS=$(echo "${WDS},")
    fi
    WDS=$(echo "${WDS}${dy}")
  fi
done

# -----
# Generate the crontab file

CRONFILE="$DESTDIR/oracle_optools_$ORACLE_SID"

cat << EOF > $CRONFILE
# -------------------------------------------------------------------
# crontab for oracle_optools
#
# ORACLE_SID: $SID
#
# -----
# Hourly actions at xx:01 (e.g. snapshots for statspack)
01 * * * * oracle /usr/share/oracle_optools/hourly.sh $ORAENV > /var/tmp/oracle_optools/${ORACLE_SID}/hourly.log 2>&1
#
# -----
# Nightly jobs at 03:01 (removal of trace files, statspack and/or AWR reports, DB info report, housekeeping)
01 03 * * * oracle /usr/share/oracle_optools/nightly.sh $ORAENV > /var/tmp/oracle_optools/${ORACLE_SID}/nightly.log 2>&1
#
# -----
# Hourly backup of redo logs
$N * * * * oracle /usr/share/oracle_optools/backup_redologs.sh $ORAENV > /var/tmp/oracle_optools/${ORACLE_SID}/backup_redologs.log 2>&1
#
# -----
# Nightly database backup
#
# RMAN backups
# Full backup every weekday:
$M $H * * *           oracle /usr/share/oracle_optools/backup_database.sh $ORAENV FULL > /var/tmp/oracle_optools/${ORACLE_SID}/backup_database.log 2>&1
#
# Or: level 0 once a week, and level 1 every other weekday:
# $M $H * * $WD           oracle /usr/share/oracle_optools/backup_database.sh $ORAENV LEVEL0 > /var/tmp/oracle_optools/${ORACLE_SID}/backup_database.log 2>&1
# $M $H * * $WDS oracle /usr/share/oracle_optools/backup_database.sh $ORAENV LEVEL1 > /var/tmp/oracle_optools/${ORACLE_SID}/backup_database.log 2>&1
#
# Or old style, copy datafile-by-datafile for each tablespace.
# $M $H * * * oracle /usr/share/oracle_optools/backup_database_files.sh $ORAENV > /var/tmp/oracle_optools/${ORACLE_SID}/backup_database_files.log 2>&1
#

EOF

chmod 644 "$CRONFILE"

echo
echo "crontab file '$CRONFILE' created."
echo

# -----
# output to stdout

if [ "$SILENT" != "yes" ] ; then
  echo "cron file:"
  echo
  echo "-------------------------------------------------------------------------------"
  cat $CRONFILE
  echo "-------------------------------------------------------------------------------"
  echo
fi

# This is obsolete:
# -----
# copy command
#
#if [ "$SILENT" != "yes" ] ; then
#  echo
#  echo "Copy it as root:"
#  echo
#  echo "cp \"$CRONFILE\" /etc/cron.d/"
#  echo
#fi

