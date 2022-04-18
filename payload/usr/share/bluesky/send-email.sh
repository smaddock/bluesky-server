#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# Sends email alerts
#
# Usage: send-email.sh <email-subject> <email-body>
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

########################################
###         CONFIG VARIABLES         ###
########################################

if [[ -f /etc/bluesky/email.ini ]]; then
  # shellcheck disable=SC1090
  source <(grep "=" /etc/bluesky/email.ini)
else
  echo "Missing required email.ini config file, discarding email message"
  exit 1
fi

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
  echo "Missing required email subject argument, discarding email message"
  exit 1
else
  SUBJECT_LINE="$1"
fi

if [[ -z $2 ]]; then
  echo "Missing required email body argument, discarding email message"
  exit 1
else
  MESSAGE_BODY="$2"
fi

########################################
###         CONDITION CHECKS         ###
########################################

if [[ $ENABLE_EMAIL != "true" ]]; then
  exit 0
fi

if [[ -z $FROM_ADDRESS ]]; then
  echo "FROM_ADDRESS not set in email.ini, discarding email message"
  exit 1
fi

if [[ -z $TO_ADDRESS ]]; then
  echo "TO_ADDRESS not set in email.ini, discarding email message"
  exit 1
fi

if [[ -z $SMTP_SERVER ]]; then
  echo "SMTP_SERVER not set in email.ini, discarding email message"
  exit 1
fi

if [[ -z $SMTP_PORT ]]; then
  SMTP_PORT=587
fi

########################################
###           MAIN SCRIPT            ###
########################################

if [[ $SMTP_SSL = "true" ]]; then
  SSL_OPT="--ssl-reqd"
  URL="smtps://$SMTP_SERVER:$SMTP_PORT"
else
  SSL_OPT=""
  URL="smtp://$SMTP_SERVER:$SMTP_PORT"
fi

MESSAGE=$(
  cat << EOF
From: <$FROM_ADDRESS>
To: <$TO_ADDRESS>
Subject: $SUBJECT_LINE
Date: $(date --rfc-email)

$MESSAGE_BODY
EOF
)

curl \
  --mail-from "$FROM_ADDRESS" \
  --mail-rcpt "$TO_ADDRESS" \
  --show-error \
  --silent \
  "$SSL_OPT" \
  --upload-file <(echo "$MESSAGE") \
  --url "$URL" \
  --user "$SMTP_USERNAME:$SMTP_PASSWORD"
