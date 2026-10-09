#!/bin/bash
# Prints the panel URL, login, and the vless:// link for your phone and Mac.
# Save the output to your password manager. Never commit it.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
IP=$(current_ip)
echo "Server: $IP"
echo
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$IP" 'sudo cat /root/x-ui-access.txt'
