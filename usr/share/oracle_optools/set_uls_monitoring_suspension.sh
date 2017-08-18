#!/bin/bash
#
# set_uls_monitoring_suspension.sh
#
# -----
# Example script how to set a monitoring suspension in ULS. 
# 
# NOTE: the hostname must(!!!) be enabled in ULS to set a monitoring 
# suspension from remote. See: administration - client suspension.

BEGIN=`date --date "-10 min"   +"%Y-%m-%d %H:%M:%S"`
UNTIL=`date --date "+24 hours" +"%Y-%m-%d %H:%M:%S"`
SECTION="My Section*"
REASON="The reason why a monitoring suspension is set"

echo  "P;$BEGIN;`hostname`;$SECTION;;;$UNTIL;;;$REASON" | send_test_tab -S

