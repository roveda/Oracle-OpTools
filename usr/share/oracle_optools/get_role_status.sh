#!/usr/bin/env bash
#
# get_role_status.sh - get database role and status from database instance
#
# ------------------------------------------------------------------------------
# Copyright 2019-2021, roveda
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
#   ./get_role_status.sh
#
# ---------------------------------------------------------
# Description:
#   Get the database role and the status from the database instance.
#   E.g. the backup must be done differently when the database role 
#   is PRIMARY or PHYSICAL STANDBY.
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Restrictions:
#   No other output except error messages are allowed.
#   The echo'ed result is used by other scripts.
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
# 2019-07-16      roveda      0.01
#   Script created.
#
# 2021-01-08      roveda      0.02
#   Ignoring possible output when sourcing the environment script. 
#   (There may be custom scripts that produce output)
#   Which would spoil the expected output that is further processed in 
#   other bash scripts.
#
# 2021-12-02      roveda      0.03
#   Get current directory thru 'readlink'.
#   Set LANG=en_US.UTF-8
#
# ------------------------------------------------------------------------------

USAGE="get_role_status.sh  [ <oracle_env> ]"

mydir=$(dirname "$(readlink -f "$0")")
cd "$mydir"

. ./ooFunctions

# --------------------------
# Stay silent!
# --------------------------


if [[ -z "$1" ]] ; then
  echo $USAGE
  exiterr 2 "ERROR: No environment script given as parameter => ABORT"
fi

oraenv=$(eval "echo $1")

# -----
# environment script found?

if [[ ! -f "$oraenv" ]] ; then
  exiterr 2 "ERROR: environment script '$oraenv' not found => ABORT"
fi

# Source the environment script
# and ignore any output
. "$oraenv"  >  /dev/null  2>&1
if [[ -z "$ORACLE_SID" ]] ; then
  exiterr 2 "ERROR: the Oracle environment is not set up correctly => ABORT"
fi

export LANG=en_US.UTF-8

dbrole=$(sql_value "select database_role from v\$database;")
if [[ "$dbrole" =~ ORA-[0-9]{3,} ]] ; then
  exiterr 1 'ERROR: When executing the sql: select database_role from v$database;'
fi


dbstatus=$(sql_value "select status from v\$instance;")
if [[ "$dbstatus" =~ ORA-[0-9]{3,} ]] ; then
  exiterr 1 'ERROR: When executing the sql: select status from v$instance;'
fi

echo "$dbrole,$dbstatus"

exit 0

