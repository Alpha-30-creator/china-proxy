#!/bin/bash
# Opens an SSH tunnel to the admin panel (needed for the phone QR code).
# Leave this running, then browse to the panel URL with the IP replaced by 127.0.0.1
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
IP=$(current_ip)
echo "Tunnelling to the panel on $IP ..."
echo "Now open your panel URL in a browser, but replace $IP with 127.0.0.1"
echo "Get the URL with: ./show-link.sh      Press Ctrl-C here when finished."
exec ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -L 2053:127.0.0.1:2053 "ubuntu@$IP"
