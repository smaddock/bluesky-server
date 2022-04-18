#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called from controller.sh. It attempts an SSH connection back
# through the tunnel, and returns the status. If flagged, this also sends self
# destruct instruction and email notice.
#
# Status codes:
# 200 OK - able to connect
# 404 Not Found - serial number mismatch
# 410 Gone - self destruct
# 500 Internal Server Error - unable to connect
#
# Usage: get-status.sh <serial-number>
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

########################################
###            FUNCTIONS             ###
########################################

# updates DB and returns success code when device is up
# also sends email notice if requested
# Usage: allGood
allGood() {
  # send device online notice - could be moved to serverup/cron?
  if [[ $(queryDb "SELECT notify FROM computers WHERE serialnum = '$SERIAL_NUM';") -eq 1 ]]; then
    HOST_NAME=$(queryDb "SELECT hostname FROM computers WHERE serialnum = '$SERIAL_NUM';")
    SERVER_FQDN=$(< /etc/server.txt)
    EMAIL_BODY=$(
      cat <<- EOM
				You requested to be notified when we next saw $HOST_NAME with serial number $SERIAL_NUM, ID: $MY_PORT.
				https://$SERVER_FQDN/blu=$MY_PORT
				SSH bluesky://com.solarwindsmsp.bluesky.admin?blueSkyID=$MY_PORT&action=ssh
				VNC bluesky://com.solarwindsmsp.bluesky.admin?blueSkyID=$MY_PORT&action=vnc
				SCP bluesky://com.solarwindsmsp.bluesky.admin?blueSkyID=$MY_PORT&action=scp
				EOM
    )
    /usr/share/bluesky/send-email.sh "[BlueSky] Device $SERIAL_NUM Online" "$EMAIL_BODY" &> /dev/null
    queryDb "UPDATE computers SET notify = 0 WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  fi

  queryDb "UPDATE computers SET status = 'Connection is good', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  queryDb "UPDATE computers SET timestamp = '$(date +%s)' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  echo "200 OK"
  exit 0
}

# sends a query to the database and returns the result
# Usage: queryDb <query>
queryDb() {
  sqlite3 -batch -noheader /var/lib/bluesky/bluesky.sqlite3 "$1"
  return $?
}

# updates DB and returns error code when serial numbers don’t match
# Usage: snMismatch
snMismatch() {
  queryDb "UPDATE computers SET status = 'ERROR: serial mismatch returned $TEST_CONN', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  echo "404 Not Found"
  exit 0
}

# attempts to run a shell command on a client device
# Usage: testSsh <command>
testSsh() {
  ssh \
    -i /var/lib/bluesky/blueskyd \
    -l bluesky \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -p "$SSH_PORT" \
    localhost \
    "$1"
  return $?
}

########################################
###           MAIN SCRIPT            ###
########################################

# self destruct
if [[ $(queryDb "SELECT selfdestruct FROM computers WHERE serialnum = '$SERIAL_NUM';") -eq 1 ]]; then
  queryDb "UPDATE computers SET status = 'Remote removal initiated', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  queryDb "UPDATE computers SET selfdestruct = 0 WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  echo "410 Gone"
  exit 0
fi

MY_PORT=$(queryDb "SELECT blueskyid FROM computers WHERE serialnum = '$SERIAL_NUM';")
SSH_PORT=$((49152 + MY_PORT))

# Attempt to connect and read remote cached serial number with `defaults`
if TEST_CONN=$(testSsh "/usr/bin/defaults read /var/bluesky/settings serial"); then
  if [[ $TEST_CONN = "$SERIAL_NUM" ]]; then
    allGood
  else
    snMismatch
  fi

# either down or `defaults` is messed up, try again with `PlistBuddy`
elif TEST_CONN_TWO=$(testSsh "/usr/libexec/PlistBuddy -c 'Print serial' /var/bluesky/settings.plist"); then
  if [[ $TEST_CONN_TWO = "$SERIAL_NUM" ]]; then
    allGood
  else
    snMismatch
  fi

# it’s down - PKI exchange issue for bluesky user - let’s return OK to keep tunnel up.
elif [[ $TEST_CONN_TWO = *"ssh_exchange_identification"* ]]; then
  queryDb "UPDATE computers SET status = 'ERROR: tunnel issue to client', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  echo "200 OK"
  exit 0

# it’s down - most likely prompting for password auth (key issue) - let’s return OK to keep tunnel up.
elif [[ $TEST_CONN_TWO = *"Permission denied"* ]]; then
  queryDb "UPDATE computers SET status = 'ERROR: cannot verify serial number', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  echo "200 OK"
  exit 0

# it’s down - report as down
else
  queryDb "UPDATE computers SET status = 'ERROR: no tunnel established', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';" &> /dev/null
  echo "500 Internal Server Error"
  exit 0
fi
