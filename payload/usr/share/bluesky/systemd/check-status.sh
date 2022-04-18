#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called by systemd bluesky-status.service every five minutes.
# It checks the status of computers marked with the Alert checkbox and
# generates the down or up email alerts.
#
# alerts in TZ of user?
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

########################################
###         CONFIG VARIABLES         ###
########################################

CHECK_THRESH=$(date -d "10 minutes ago" "+%s")
TIME_STAMP=$(date "+%Y-%m-%d %H:%M:%S %Z")

########################################
###            FUNCTIONS             ###
########################################

# sends a query to the database and returns the result
# Usage: queryDb <query>
queryDb() {
  sqlite3 -batch -noheader /var/lib/bluesky/bluesky.sqlite3 "$1"
  return $?
}

# sends an up/down email alert
# Usage: sendAlert <state>
sendAlert() {
  ALERT_STAT="$1"
  HOST_NAME=$(queryDb "SELECT hostname FROM computers WHERE serialnum = '$SERIAL_NUM';")
  LAST_DATE=$(date -d @"$LAST_CONN" "+%Y-%m-%d %H:%M:%S %Z")
  if [[ $ALERT_STAT = "Down" ]]; then
    MESS_BODY="You requested to be notified when $HOST_NAME with serial number $SERIAL_NUM has been offline for more than 15 minutes. Last time we saw it was $LAST_DATE"
  elif [[ $ALERT_STAT = "Up" ]]; then
    MESS_BODY="The computer $HOST_NAME with serial number $SERIAL_NUM is now back online."
  else
    return
  fi

  /usr/share/bluesky/send-email.sh "[BlueSky] Device $SERIAL_NUM $ALERT_STAT Alert" "$MESS_BODY"
}

# attempts to run a shell command on a client device
# Usage: testSsh <command>
testSsh() {
  ssh \
    -i /var/lib/bluesky/blueskyd \
    -l bluesky \
    -o ConnectionAttempts=5 \
    -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no \
    -p "$SSH_PORT" \
    localhost \
    "$1"
  return $?
}

########################################
###           MAIN SCRIPT            ###
########################################

ALERT_LIST=$(queryDb "SELECT serialnum FROM computers WHERE alert = '1';")

for SERIAL_NUM in $ALERT_LIST; do
  # 1 is up, <=0 is down, negative number is how many times this script has seen it as down
  UP_STATUS=$(queryDb "SELECT downup FROM computers WHERE serialnum = '$SERIAL_NUM';")
  if [[ -z $UP_STATUS ]] || [[ $UP_STATUS = "NULL" ]]; then
    UP_STATUS=1
  fi

  # timestamp is an epoch populated by processor when it confirms a good connection
  LAST_CONN=$(queryDb "SELECT timestamp FROM computers WHERE serialnum = '$SERIAL_NUM';")
  if [[ -z $LAST_CONN ]] || [[ $LAST_CONN = "NULL" ]]; then
    LAST_CONN=0
  fi

  # if it’s been quiet for more than 10 min, might be down
  if [[ $LAST_CONN -lt $CHECK_THRESH ]]; then

    # first do our own spot check to see if server is really down
    # if we do not connect, mark down the counter
    MY_PORT=$(queryDb "SELECT blueskyid FROM computers WHERE serialnum = '$SERIAL_NUM';")
    SSH_PORT=$((49152 + MY_PORT))
    if ! testSsh "/usr/bin/defaults read /var/bluesky/settings serial"; then
      ((UP_STATUS--))
      queryDb "UPDATE computers SET downup = '$UP_STATUS' WHERE serialnum = '$SERIAL_NUM';"

      # if this is the third time we have seen it as down - up to 10 min on
      # checkin, 3 times with this script every 5 (0, -1, -2), time to alert
      if [[ $UP_STATUS -eq -2 ]]; then
        queryDb "UPDATE computers SET status = 'Alert sent for offline', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';"
        sendAlert Down
      fi

      # TODO - send an extended down at larger interval?
    fi

  # server was last contacted in acceptable threshold
  else
    # if server was down last time, mark up
    if [[ $UP_STATUS -lt 1 ]]; then
      queryDb "UPDATE computers SET downup = '1' WHERE serialnum = '$SERIAL_NUM';"

      # if down alert has been sent, follow up
      if [[ $UP_STATUS -lt -1 ]]; then
        queryDb "UPDATE computers SET status = 'Recovered from alert', datetime = '$TIME_STAMP' WHERE serialnum = '$SERIAL_NUM';"
        sendAlert Up
      fi
    fi
  fi
done

# look for disconnected computers and mark offline
OFFLINE_LIST=$(queryDb "SELECT id FROM computers WHERE datetime < (NOW() - INTERVAL 12 MINUTE) AND status = 'Connection is good';")
for THIS_ID in $OFFLINE_LIST; do
  queryDb "UPDATE computers SET status = 'Offline', datetime = '$TIME_STAMP' WHERE id = '$THIS_ID';"
done
