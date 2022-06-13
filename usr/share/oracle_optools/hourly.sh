#!/usr/bin/env bash
#
# hourly.sh - execute scripts each hour
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
#   hourly.sh  <oracle_env_script>
#
# ---------------------------------------------------------
# Description:
#   Do some hourly actions.
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
#
# 2021-12-08      roveda      0.04
#   unset ORACLE_PATH and SQLPATH to prohibit processing of login.sql
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
  echo
  echoerr "Error: the Oracle environment is not set up correctly => aborting script"
  echo
  exit 1
fi

export LANG=en_US.UTF-8
# Prohibit the reading of a possible login.sql
unset ORACLE_PATH SQLPATH

# -----
# Take a database performance snapshot
# (only if it is configured)

# ./ora_statspack.sh SNAPSHOT
./run_perl_script.sh $ORAENV ora_statspack.pl  /etc/oracle_optools/standard.conf  SNAPSHOT


