#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called from controller.sh. It adds a computer to the database.
#
# Status codes:
# 201 Created - successfully added
# 500 Internal Server Error - database error adding record
#
# Usage: register-device.sh <serial-number> <hostname>
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

########################################
###         CONFIG VARIABLES         ###
########################################

TIME_STAMP=$(date "+%Y-%m-%d %H:%M:%S %Z")

########################################
###      CLI OPTIONS & OPERANDS      ###
########################################

if [[ -z $1 ]]; then
  echo "Missing required serial number, exiting"
  exit 1
else
  SERIAL_NUM="$1"
fi

if [[ -z $2 ]]; then
  echo "Missing required hostname, exiting"
  exit 1
else
  HOST_NAME="$2"
fi

########################################
###            FUNCTIONS             ###
########################################

# sends a query to the database and returns the result
# Usage: queryDb <query>
queryDb() {
  sqlite3 -batch -noheader /var/lib/bluesky/bluesky.sqlite3 "$1"
  return $?
}

########################################
###           MAIN SCRIPT            ###
########################################

COMP_REC=$(queryDb "SELECT id FROM computers WHERE serialnum = '$SERIAL_NUM';")
# ON DUPLICATE KEY UPDATE instead of if/else?
if [[ -z $COMP_REC ]]; then
  # fetch unique ID - this whole section could just use auto-increment?
  BLU_ID=$(queryDb "SELECT MIN(t1.blueskyid + 1) AS nextID FROM computers t1 LEFT JOIN computers t2 ON t1.blueskyid + 1 = t2.blueskyid WHERE t2.blueskyid IS NULL;")
  if [[ -z $BLU_ID ]] || [[ $BLU_ID = "NULL" ]]; then
    BLU_ID=1
  fi
  MY_QRY="INSERT INTO computers (serialnum, hostname, sharingname, registered, blueskyid) VALUES ('$SERIAL_NUM', '$HOST_NAME', '$HOST_NAME', '$TIME_STAMP', '$BLU_ID');"
else
  MY_QRY="UPDATE computers SET registered = '$TIME_STAMP', sharingname = '$HOST_NAME' WHERE id = '$COMP_REC';"
fi
if queryDb "$MY_QRY"; then
  echo "201 Created"
  exit 0
else
  echo "500 Internal Server Error"
  exit 0
fi
