#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called from controller.sh. It checks if submitted payloads
# are valid BlueSky public keys, then hands them off to gatekeeper.sh via
# systemd bluesky-pubkey.path
#
# Status codes:
# 201 Created - public key installing
# 400 Bad request - payload not a valid public key
# 400 Bad request - public key is not using an accepted algorithm
#
# Usage: add-key.sh <payload>
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

########################################
###         CONFIG VARIABLES         ###
########################################

TEMP_FILE=$(mktemp)

########################################
###      CLI OPTIONS & OPERANDS      ###
########################################

while getopts ":" CLI_OPTION; do
  case $CLI_OPTION in
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

if [[ -z $1 ]]; then
  echo "Missing required payload, exiting"
  exit 1
else
  DATA_UP="$1"
fi

########################################
###           MAIN SCRIPT            ###
########################################

# Attempt to decrypt with the client and admin keys. Whichever one passes, note
# the type. If both fail, reject it.
if openssl smime -decrypt -inform PEM -inkey /var/lib/bluesky/bsadmin.key -out "$TEMP_FILE" <<< "$DATA_UP"; then
  KEY_USER="bsadmin"
elif openssl smime -decrypt -inform PEM -inkey /var/lib/bluesky/bsclient.key -out "$TEMP_FILE" <<< "$DATA_UP"; then
  KEY_USER="bsclient"
else
  echo "400 Bad request"
  exit 0
fi

# $KEY_VALID contains the hash that will appear in auth.log
KEY_VALID=$(ssh-keygen -l -f "$TEMP_FILE")
if [[ $KEY_VALID = *"ED25519"* ]] || [[ $KEY_VALID = *"RSA"* ]]; then
  cp "$TEMP_FILE" "/var/spool/bluesky/$KEY_USER-$(uuidgen).pub"

  # send new admin key notice
  if [[ $KEY_USER = "bsadmin" ]]; then
    KEY_ID=$(awk '{ print $NF }' "$TEMP_FILE")
    EMAIL_BODY=$(
      cat <<- EOM
				A new admin key with identifier $KEY_ID was registered in your server. If you
				did not expect this, please invoke Emergency Stop.
				EOM
    )
    /usr/share/bluesky/send-email.sh "[BlueSky] Admin Key Registered" "$EMAIL_BODY" &> /dev/null
  fi
  echo "201 Created"
  exit 0
else
  echo "400 Bad request"
  exit 0
fi
