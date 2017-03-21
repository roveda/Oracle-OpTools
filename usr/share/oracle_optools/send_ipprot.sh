#!/bin/bash
#
# THIS IS WORK IN PROGRESS!
# DONT USE!
#
# send_ipprot.sh
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
#   xxxxxxxxxx
#
# ---------------------------------------------------------
# Description:
#   This script is normally used as post-processing script to
#   protocol files created by the ipprotd for user connections
#   to the Oracle listener.
#   Be sure to use the absolute path of this script when starting the ipprotd!!!
#
#   NOTE: This script uses the command 'date -d "@<secs_since_epoch>"'
#         Be sure that is available for your flavour of shell or
#         use the work around in section "Start-stop timestamp tuple" below.
#
#
#   For further information see:
#     http://www.universal-logging-system.org/dokuwiki/doku.php?id=ipprot
#
#   Start the ipprot similar to:
#
#     ipprotd -p 1234@<listen_ip> -P 4321@<dest_ip>
#             -L -s -t 180 -f /oracle/admin/$ORACLE_SID/connection_protocol/prot -j
#             -u /oracle/admin/$ORACLE_SID/oracle_tools/send_ipprot
#             -Dp /oracle/admin/$ORACLE_SID/connection_protocol/pid_1234_<listen_ip>
#
#   See also the script: instance_start.sh
#
#   Be sure, that the directory /oracle/admin/$ORACLE_SID/connection_protocol exists!
#
#   Parameters got from ipprotd:
#     $1 := the complete path of the recorded network traffic file
#     $2 := timestamp of the start of the protocol, in number of seconds since the Unix epoch
#     $3 := timestamp of the stop of the protocol, in number of seconds since the Unix epoch
#     $4 := number of bytes received from connection establisher (in) to destination (out)
#     $5 := number of bytes sent from destination to connection establisher
#     $6 := the ip address of the connection establisher
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
# 2013-02-03      roveda      0.01
#
# 2013-02-24      roveda      0.02
#   Added USER, HOST and PROGRAM, extracted from the network traffic protocol.
#
# 2013-09-01      roveda      0.03
#   Changed to the usage of a single configuration file
#
# 2014-01-11      roveda      0.04
#   Debugged the script: oracle_tools.conf was not processed correctly in the perl snipped, 
#   used wrong variable names for date and time in send_test_value call.
#
# 2017-01-24      roveda      0.05
#   Added GPL
#
# ---------------------------------------------------------

echo "THIS IS WORK IN PROGRESS!"
echo "DONT USE!"
exit 9

# -----
# Go to directory where this script is placed
cd `dirname $0`

# -----
# Set environment

. ./oracle_env
if [ $? -ne 0 ] ; then
  echo
  echo "Error: Cannot source Oracle's environment script './oracle_env'"
  echo
  exit 1
fi

unset LC_ALL
export LANG=C

# -----
# Check number of parameters

if [ $# -ne 6 ]; then
  echo "Improper number of parameters!"
  echo "usage:"
  echo "  $0 <recorded_file> <connection_begin> <connection_end> <#bytes_recvd> <#bytes_sent> <client_ip> <oracle_tools_configuration_file>"
  exit 1
fi

# -----
# file name containing the recorded network traffic

FILE="$1"
if [ ! -r "$FILE" ] ; then
  echo "Cannot read file '$FILE'!"
  exit 1
fi

# -----
# Start-stop timestamp tuple

START=`date +"%Y-%m-%d %H:%M:%S"`

if [ ! -z "$2" ]; then
  START=`date -d "@$2" '+%F %T'`

  # Use that if perl is available but not 'date -d...'
  # START=`perl -e '
  #   use strict;
  #   use warnings;
  #   use Time::localtime;
  #
  #   my $tm = localtime($ARGV[0]);
  #   printf("%04d-%02d-%02d %02d:%02d:%02d\n",
  #     $tm->year+1900, $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
  # ' $2`
fi

if [ ! -z "$3" ]; then
  STOP=`date -d "@$3" '+%F %T'`

  # Use that if perl is available but not 'date -d...'
  # STOP=`perl -e '
  #   use strict;
  #   use warnings;
  #   use Time::localtime;
  #
  #   my $tm = localtime($ARGV[0]);
  #   printf("%04d-%02d-%02d %02d:%02d:%02d\n",
  #     $tm->year+1900, $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
  # ' $3`
fi

# Split up date and time for the ULS timestamp
read DT TI <<< $START
# echo "START=$START, DT=$DT, TI=$TI"

# -----
# ip address of connection establisher

CLIENT="$6"

# -----
# Get ULS_HOSTNAME from oracle_tools.conf

ULS_HOSTNAME=`perl -e '
  use strict;
  use warnings;
  use lib ".";
  use Misc;

  my %CFG;

  my $c = $ARGV[0];
  get_config2($c, \%CFG, "ULS");
  my $p = "ULS.ULS_HOSTNAME";
  print "ULS_HOSTNAME=$CFG{$p}\n";
  ' ./oracle_tools.conf | awk -F = '/ULS_HOSTNAME=/ {print $2}'`

# Get ULS_SECTION from oracle_tools.conf

ULS_SECTION=`perl -e '
  use strict;
  use warnings;
  use lib ".";
  use Misc;

  my %CFG;

  my $c = $ARGV[0];
  get_config2($c, \%CFG, "ULS");
  my $p = "ULS.ULS_SECTION";
  print "ULS_SECTION=$CFG{$p}\n";
  ' ./oracle_tools.conf | awk -F = '/ULS_SECTION=/ {print $2}'`

# -----
# Teststep in ULS

TESTSTEP="listener tcp protocol"

# echo "ULS_HOSTNAME=$ULS_HOSTNAME, ULS_SECTION=$ULS_SECTION, TESTSTEP=$TESTSTEP, DATE=$DT, TIME=$TI"
# send start and stop of connection
send_test_value -h $ULS_HOSTNAME "$ULS_SECTION" "$TESTSTEP" "start-stop" $DT $TI "Start $START" "{T}"
send_test_value -h $ULS_HOSTNAME "$ULS_SECTION" "$TESTSTEP" "start-stop" $DT $TI "Stop $STOP"   "{T}"

# send client info
send_test_value -h $ULS_HOSTNAME "$ULS_SECTION" "$TESTSTEP" "client" $DT $TI "$CLIENT" " "

# -----
# Find the extension of the file
#
# Eat all chars up to the last dot, sed is greedy!
X=`echo $FILE | sed 's/.*\.//'`

# Choose the appropriate cat command
CAT="cat"

case $X in
  bz2) CAT="bzcat";;
  gz)  CAT="zcat";;
esac

# -----
# Get the first lines of the recorded file
#
# Try to find the user, the program and the machine information of the connection.

T=`$CAT "$FILE" | head -20 | grep DESCRIPTION`

# Looks like:
#
# #748369#2013-02-13 10:26:08-01:00 6 , A O : (DESCRIPTION=(CONNECT_DATA=(SID=orcl)(CID=(PROGRAM=SQL Developer)(HOST=__jdbc__)(USER=roveda)))(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1111))) 6 , A O : (DESCRIPTION=(CONNECT_DATA=(SID=orcl)(CID=(PROGRAM=SQL Developer)(HOST=__jdbc__)(USER=roveda)))(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1111)))

# Find the program like 'SQL Developer'
PROG=$(echo $T | sed 's/.*PROGRAM=//' | sed 's/).*//')
[ -z "$PROG" ] && PROG="unknown"

# Find the host like 'localhost'
HOST=$(echo $T | sed 's/.*HOST.*HOST=//' | sed 's/).*//')
[ -z "$HOST" ] && HOST="unknown"

# Find the user
USER=$(echo $T | sed 's/.*USER=//' | sed 's/).*//')
[ -z "$USER" ] && USER="unknown"

send_test_value  -h $ULS_HOSTNAME "$ULS_SECTION" "$TESTSTEP" "program" $DT $TI "$PROG" " "
send_test_value  -h $ULS_HOSTNAME "$ULS_SECTION" "$TESTSTEP" "host"    $DT $TI "$HOST" " "
send_test_value  -h $ULS_HOSTNAME "$ULS_SECTION" "$TESTSTEP" "user"    $DT $TI "$USER" " "

# -----
# send the recorded network traffic as file, restricted access!
# only visible for access rights 'adm'

send_file_value  -h $ULS_HOSTNAME -s adm "$ULS_SECTION" "$TESTSTEP" "connection recording" $DT $TI "$FILE"


