# bluesky-server

This is a _very_ early development version of BlueSky Server 3, and should not be used for production!

## Build

1. On a Debian-based device, clone this repo
1. Run: `./build.sh`
1. Copy the `/build/bluesky-server_<version>.deb.tar.gz` to your destination
1. Commit and push the `/build/.build_number` changes to avoid version number conflicts

## Use

1. On a Debian-based device, download the package from GitHub
1. Un-tar/gzip the package file
1. Run: `sudo apt install ./bluesky-server_<version>.deb`
1. If the `hostname` is different from the server’s FQDN, edit `/etc/bluesky/server.txt` with the actual FQDN
1. Edit `/etc/bluesky/email.ini` with your SMTP info to receive notices and alerts
1. Configure your web server to point requests for `/cgi-bin/collector.php` to `/usr/share/bluesky/api/controller.sh`

## To Do

- Get a generic email for BlueSkyTools for DEB package maintainer
- Test post-install script
- Generate macOS config profile with signing certificate
- Update control and systemd doc links to upstream repo
- Rewrite API calls as REST endpoints and verbs
- Add data sanitization for new device register requests
- Test other ways this could break
