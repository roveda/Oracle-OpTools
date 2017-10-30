#!/bin/bash
#
# setup_for_sid - Create all necessary files for a ORACLE_SID
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
#   setup_for_sid.sh  <oracle_environment_script>
#
# ---------------------------------------------------------
# Description:
#   Creates an empty ORACLE_SID specific configuration file.
#   Creates the crontab file and the working directory in /var.
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
# 2017-10-04      roveda      0.01
#   Created.
#
#
# -----------------------------------------------------------------------------

unset LC_ALL
export LANG=C

USAGE="setup_for_sid.sh  <oracle_environment_script>"

if [ $EUID -ne 0 ]; then
   echo "$0: ERROR: This script can only be run as root => ABORTING"
   exit 1
fi

# -----
# Check number of arguments

if [[ $# -ne 1 ]] ; then
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
  echo "ERROR: Cannot source Oracle's environment script '$ORAENV' => abort"
  echo
  exit 1
fi


# -----
echo
echo "Creating the ORACLE_SID specific configuration file"

CONFFILE="/etc/oracle_optools/${ORACLE_SID}.conf"

cat << EOF > $CONFFILE
# =============================================================================
#
# SID specific configuration file for: ${ORACLE_SID}
#
# =============================================================================
#
# Overwrite any defaults defined in standard.conf in this file.
# Specify [SECTION], parameter and the differing value.
#

EOF

chown oracle:oinstall $CONFFILE

echo "ORACLE_SID specific configuration file '$CONFFILE' created."
echo

# -----
# Create crontab file

echo
echo "Creating crontab file for ${ORACLE_SID}"
echo
/usr/share/oracle_optools/crontab_create.sh ~oracle/oracle_env_${ORACLE_SID} /etc/cron.d

chmod 644 /etc/cron.d/oracle_optools_${ORACLE_SID}
echo "Crontab file '/etc/cron.d/oracle_optools_${ORACLE_SID}' created."
echo

# -----
# Create the working directory
echo
echo "Creating the working directory in /var"

# The crontab .sh scripts want to write into that directory,
# they won't start, if it does not exist.

WD=/var/tmp/oracle_optools/${ORACLE_SID}

if [ -d $WD ] ; then
  echo "Directory '$WD' already exists."
else
  mkdir -p $WD
  chown oracle:oinstall $WD
  echo "Directory '$WD' created."
fi


