#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script should be called by the web server when an HTTP API request is
# made. It parses the POST data and passes it off to keymaster.sh or
# processor.sh.
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

printf "Content-type: text/plain\n\n"

########################################
###      HTTP REQUEST VARIABLES      ###
########################################

if [[ $REQUEST_METHOD != "POST" ]]; then
  echo "405 Method not allowed"
  exit 0
fi

if [[ -z $POST_DATA ]]; then
  echo "400 Bad request"
  exit 0
fi

# Parse POST body into REQUEST_variables
IFS='&=' read -ra REQUEST <<< "$POST_DATA"
for ((i = 0; i < ${#REQUEST[@]}; i += 2)); do
  declare "REQUEST_${REQUEST[i]}=${REQUEST[i + 1]}"
done

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
###         CONDITION CHECKS         ###
########################################

if [[ -z $REQUEST_actionStep ]] || [[ -z $REQUEST_serialNum ]]; then
  echo "400 Bad request"
  exit 0
fi

# do some basic validation on REQUEST_serialNum and REQUEST_hostName

########################################
###           MAIN SCRIPT            ###
########################################

case $REQUEST_actionStep in
  newpub)
    if [[ -z $REQUEST_pubKey ]]; then
      echo "400 Bad request"
      exit 0
    fi
    /usr/share/bluesky/api/validate-pubkey.sh "$REQUEST_pubKey"
    ;;
  port)
    # looks up the port number and sends it
    # only time we return content and not status-code-as-content
    queryDb "SELECT blueskyid FROM computers WHERE serialnum = '$SERIAL_NUM';"
    exit 0
    ;;
  register)
    if [[ -z $REQUEST_hostName ]]; then
      echo "400 Bad request"
      exit 0
    fi
    /usr/share/bluesky/api/register-device.sh "$REQUEST_serialNum" "$REQUEST_hostName"
    ;;
  status)
    /usr/share/bluesky/api/get-status.sh "$REQUEST_serialNum"
    ;;
  user)
    # looks up the default user if any and sends it
    # 204 No Content - action not implemented
    echo "204 No Content"
    exit 0
    ;;
esac
