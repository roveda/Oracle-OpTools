#!/bin/bash
#
# backup_redologs.sh - backup the redo logs regularly
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

