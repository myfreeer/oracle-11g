#!/usr/bin/env bash

# fix env
export HOME=/opt/oracle
export USER=oracle
export LOGNAME=$USER
export USERNAME=$USER

set -e
source /assets/colorecho
source ~/.bashrc

POSITIVE_RETURN="OPEN"

check_status() {
  sqlplus -s / as sysdba <<EOF
   set heading off;
   set pagesize 0;
   select status from v\$instance;
   exit;
EOF
}

# Check Oracle DB status and store it in status
status=$(check_status)

# Store return code from SQL*Plus
ret=$?
# SQL Plus execution was successful and database is open
if [ $ret -eq 0 ] && [ "${status}" = "${POSITIVE_RETURN}" ]; then
  echo_green "health check passed: ${status}"
  exit 0
# Database is not open
elif [ "$status" != "$POSITIVE_RETURN" ]; then
  echo_yellow "health check failed: ${status}, database is not open"
  exit 1
# SQL Plus execution failed
else
  echo_yellow "health check failed: sql plus exited ${ret}"
  exit 1
fi
