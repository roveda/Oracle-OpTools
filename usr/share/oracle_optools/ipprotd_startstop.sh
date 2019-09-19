#!/bin/bash
#
# ipprotd_startstop.sh
#
# ---------------------------------------------------------
# Copyright 2016,2018 roveda
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
# ---------------------------------------------------------
# Synopsis:
#   ipprotd_startstop.sh { start | stop }  <oracle_environment_script>  <listener_ip>
#
# ---------------------------------------------------------
# Description:
#
#   Start-Stop script for an ipprotd daemon to log all traffic from Oracle client.
#
#   { start | stop }:
#     start or stop the ipprotd daemon.
#
#   <oracle_environment_script>:
#     The script that contains all the Oracle relevant environment settings
#     like ORACLE_HOME and ORACLE_SID for the database instance that is to be started.
#
#   <listener_ip>
#     The <listener_ip> must be identical for listening and as destination,
#     the ports must obviously be different.
#
#   SCCL configuration
#     /etc/sccl/packages.conf:
#       ipprotd_orcl  hostname

#     /etc/sccl/resources.conf:
#       oracle_orcl ... SETSTATE RST:ipprotd_orcl
#
#       ipprotd_orcl  ipprotd_for_Oracle_orcl  
#         PKG:oracle_orcl:WAIT:10 
#         PRGP:/usr/share/oracle_optools/ipprotd_startstop.sh:~oracle/oracle_env_orcl:10.20.30.40
#       (that must be in one line, splitted up only for better readability)
#       Wait for the oracle_orcl package for up to 10 minutes, 
#       start the script, use the oracle environment script and the 
#       listener address as parameter. Remember: this is NOT a general purpose 
#       start-stop script for the ipprot daemon, but a specialized script 
#       to start and stop the ipprot daemon for Oracle communication logging 
#       over port 6544 on the listen address of the Oracle listener.
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
# 2018-08-26      roveda      0.01
# 2018-08-30      roveda      0.02
#
#
# -------------------------------------------------------------------

USAGE="ipprotd_startstop.sh { start | stop }  <oracle_environment_script>  <listener_ip>"

if [[ $# -lt 3 ]] ; then
  echo "Error: Improper number of parameters => ABORT"
  echo "$USAGE"
  exit 1
fi

# Get some arguments here
# {start|stop}
START_STOP=$1


# -----
# Go to directory where this script is placed
cd `dirname $0`

unset LC_ALL
export LANG=C

case $START_STOP in

  start)
    echo "Starting the ipprot daemon."

    su - oracle -c "/usr/share/oracle_optools/ipprotd_start.sh $2  $3"

    exit $?
    ;;

  stop)
    echo "Stopping the ipprot daemon."

    su - oracle -c "/usr/share/oracle_optools/ipprotd_stop.sh $2  $3"

    exit $?
    ;;

  *)
    echo "$USAGE"
    exit 1
    ;;
esac

