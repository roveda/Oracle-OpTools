#!/bin/bash
#
# nightly_performance_reports.sh - execute performance report scripts each night
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
#   nightly_performance_reports.sh  <oracle_env_script>
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
# 2018-04-18      roveda      0.01
#   Extracted from nightly.sh
#
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

