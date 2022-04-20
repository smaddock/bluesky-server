#!/bin/bash
set -euo pipefail

# BlueSkyConnect macOS SSH tunnel
#
# See https://github.com/BlueSkyTools/BlueSkyConnect
# Licensed under the Apache License, Version 2.0

# Increment build number
BUILD=$(< build/.build_number)
((BUILD++))
echo "$BUILD" > build/.build_number

# Update DEB control file
sed \
    --regexp-extended \
    --expression="s/~[0-9]+$/~$BUILD/g" \
    --in-place \
    payload/DEBIAN/control

# Build package (compressed with xz level 6)
dpkg-deb --root-owner-group --build ./payload/ ./build

# Wrap archive for better transport
pushd build
tar -czvf "bluesky-server_3.0.0alpha~${BUILD}_all.deb.tar.gz" "bluesky-server_3.0.0alpha~${BUILD}_all.deb"
popd
