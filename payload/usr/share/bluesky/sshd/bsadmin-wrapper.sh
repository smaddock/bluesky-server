#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called from the admin user’s authorized_keys. It prevents
# admin users from shelling directly into the server with their BlueSky creds
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

########################################
###         CONFIG VARIABLES         ###
########################################

# allowed SSH commands
TEST_CMD1="/bin/nc localhost ....."
TEST_CMD2="/usr/bin/ssh localhost -p .*"

########################################
###            FUNCTIONS             ###
########################################

# closes the previous MySQL record with an exit code and finish time
# Usage: closeAudit <exit code>
closeAudit() {
  END_TIME=$(date "+%Y-%m-%d %H:%M:%S %Z")

  queryDb "UPDATE connections SET endTime = '$END_TIME', exitStatus = '$1' WHERE id = '$AUDIT_ID';"
}

# sends a query to the database and returns the result
# Usage: queryDb <query>
queryDb() {
  sqlite3 -batch -noheader /var/lib/bluesky/bluesky.sqlite3 "$1"
  return $?
}

# creates a record in MySQL for tracking admin activity
# Usage: closeAudit [error description]
writeAudit() {
  KEY_USED="TBD"
  SOURCE_IP=$(awk '/for admin from/ { match($0, /\y([0-9]{1,3}\.){3}[0-9]{1,3}\y/, a) } END { print a[0] }' /var/log/auth.log)
  START_TIME=$(date "+%Y-%m-%d %H:%M:%S %Z")
  TARGET_PORT_RAW=$(awk 'NR == 1 { print $NF }' <<< "$SSH_ORIGINAL_COMMAND")
  TARGET_PORT=$((TARGET_PORT_RAW - 49152))

  queryDb "INSERT INTO connections (startTime, sourceIP, adminkey, targetPort, notes) VALUES ('$START_TIME', '$SOURCE_IP', '$KEY_USED', '$TARGET_PORT', '$1');"
  AUDIT_ID=$(queryDb "SELECT id FROM connections WHERE startTime = '$START_TIME' AND adminkey = '$KEY_USED';")
}

########################################
###      ENVIRONMENT VARIABLES       ###
########################################

# no command equals no access, punk
if [[ -z $SSH_ORIGINAL_COMMAND ]]; then
  writeAudit "Tried For Shell Access"
  closeAudit 127
  echo "Remote shell access is not permitted for BlueSky."
  exit 1
fi

########################################
###           MAIN SCRIPT            ###
########################################

# only allow the specified commands
if awk -v test1="$TEST_CMD1" -v test2="$TEST_CMD2" '{
  if (($0 ~ ^test1$) || ($0 ~ ^test2$)) && ($0 !~ [;&|])
  { exit 0 } else { exit 1 }
}' <<< "$SSH_ORIGINAL_COMMAND"; then
  writeAudit "Valid Connection"
  $SSH_ORIGINAL_COMMAND
  closeAudit $?
else
  writeAudit "Invalid Command"
  closeAudit 127
  echo "Invalid shell command."
  exit 1
fi
