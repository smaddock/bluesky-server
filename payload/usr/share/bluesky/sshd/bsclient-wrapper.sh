#!/bin/bash

# BlueSkyConnect macOS SSH tunnel
#
# This script is called from the bluesky user’s authorized_keys. It prevents
# BlueSky clients from shelling directly into the server or running commands on
# the server.
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

########################################
###           MAIN SCRIPT            ###
########################################

echo "Remote shell access is not permitted for BlueSky."
exit 1
