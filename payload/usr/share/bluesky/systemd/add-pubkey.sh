#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called by systemd bluesky-pubkey.service when keys exist in
# /var/spool/bluesky/. It adds public keys validated by validate-pubkey.sh to
# sshd and the database.
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

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

for FILE in /var/spool/bluesky/bs@(admin|client)*.pub; do

  # handle empty glob
  if [[ ! -e "$FILE" ]]; then
    exit 0
  fi

  if [[ $FILE = /var/spool/bluesky/bsadmin* ]]; then
    TARGET_LOC="bsadmin"
    PREFIX_CODE="command=\"/usr/share/bluesky/sshd/bsadmin-wrapper.sh\""
  else
    TARGET_LOC="bsclient"
    PREFIX_CODE="command=\"/usr/share/bluesky/sshd/bsclient-wrapper.sh\",no-X11-forwarding,no-agent-forwarding,no-pty"
  fi

  PUB_KEY=$(< "$FILE")
  KEY_ID=$(awk '{ print $NF }' "$FILE")
  rm -f "$FILE"

  # install as an authorized key, removing any previous keys with same key ID
  sed -i "/$KEY_ID/d" /home/$TARGET_LOC/.ssh/authorized_keys
  echo "$PREFIX_CODE $PUB_KEY" >> /home/$TARGET_LOC/.ssh/authorized_keys

  # add to admin keys database table
  if [[ $TARGET_LOC = "bsadmin" ]]; then
    ADMIN_KEYS=$(awk '{ print $NF }' /home/bsadmin/.ssh/authorized_keys)
    queryDb "UPDATE global SET adminkeys = '$ADMIN_KEYS';"
  fi
done
