# bluesky-server

This is a _very_ early development version of BlueSky Server 3, and should not be used for production!

## Build

- On a Debian-based device, clone this repo then run `dpkg-deb --build --root-owner-group ./payload/ ./build/`

## Usage

- On a Debian-based device, run `sudo apt install ./bluesky-server_3.0.0_1_all.deb`
- If the `hostname` is different from the server’s FQDN, edit `/etc/bluesky/server.txt` with the actual FQDN
- Edit `/etc/bluesky/email.ini` with your SMTP info to receive notices and alerts
- Configure your web server to point requests for `/cgi-bin/collector.php` to `/usr/share/bluesky/api/controller.sh`

## To Do

- Get a generic email for BlueSkyTools for DEB package maintainer
- Test post-install script
- Generate macOS config profile with signing certificate
- Update systemd doc links to this specific repo
- Rewrite API calls as REST endpoints and verbs
- Add data sanitization for new device register requests
- Test other ways this could break
