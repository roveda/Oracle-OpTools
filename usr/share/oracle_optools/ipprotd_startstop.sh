#!/bin/bash
#
# THIS IS WORK IN PROGRESS
# DONT USE!
#
# ---------------------------------------------------------
# Copyright 2016, roveda
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
#   ipprotd_startstop.sh <oracle_environment_script>
#
# ---------------------------------------------------------
# Description:
#   xxxx
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

echo "THIS IS WORK IN PROGRESS"
echo "DONT USE!"
exit 9

# START

# ------
# ipprot logging
#
# Recording of external access via listener, see also 'instance_stop'
#
# You must change the <listen_ip> and <dest_ip> to your needs!
# You may change the ports also.
# Activate the related part in the instance_stop script also.
#
# Be sure to have ipprotd installed somewhere in your PATH!

# title "Starting ipprotd daemon"

# ipprotd -p <listen_port>@<listen_ip> -P <dest_port>@<dest_ip> -L -s -t 180 -f /oracle/admin/$ORACLE_SID/connection_protocol/prot -j -u /oracle/admin/$ORACLE_SID/oracle_tools/send_ipprot -Dp /oracle/admin/$ORACLE_SID/connection_protocol/pid_<listen_port>_<listen_ip>



# STOP


# -----
# ipprot daemon
#
# Recording of external access, see also 'instance_start'
# Activate also the related part in the instance_start script.

# title "Stopping the ipprotd Daemon"

# if [ -r /oracle/admin/$ORACLE_SID/connection_protocol/pid_<listen_port>_<listen_ip> ]; then
#   echo "Stopping the ipprot daemon."
#   kill `cat /oracle/admin/$ORACLE_SID/connection_protocol/pid_<listen_port>_<listen_ip>`
#   echo "Done."
# fi





