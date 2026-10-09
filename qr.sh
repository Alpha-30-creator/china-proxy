#!/bin/bash
# Shows the connection QR code so you can pair a phone (v2rayNG), without the panel.
#
#   ./qr.sh          print the QR in this terminal and scan it off the screen
#   ./qr.sh --png    also write + open phone-qr.png (deleted on exit unless --keep)
#   ./qr.sh --link   print the vless:// link as text instead
#
# Always reads the CURRENT ip from AWS and the CURRENT link from the server,
# so it stays correct after ./swap-ip.sh.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"

MODE=term; KEEP=no
for a in "$@"; do
  case "$a" in
    --png)  MODE=png ;;
    --link) MODE=link ;;
    --keep) KEEP=yes ;;
    *) echo "unknown option: $a"; exit 1 ;;
  esac
done

command -v qrencode >/dev/null || { echo "Run first:  brew install qrencode"; exit 1; }

IP=$(current_ip)
LINK=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$IP" \
        "sudo grep -h '^vless://' /root/x-ui-access.txt" | head -1 | tr -d '\n')
[ -n "$LINK" ] || { echo "No share link found on $IP"; exit 1; }

if [ "$MODE" = link ]; then
  printf '%s\n' "$LINK"; exit 0
fi

echo "Server: $IP"
echo "In v2rayNG:  +  ->  Scan QR code  ->  point the camera at this"
echo
printf '%s' "$LINK" | qrencode -t ANSIUTF8

if [ "$MODE" = png ]; then
  PNG="$DIR/phone-qr.png"
  printf '%s' "$LINK" | qrencode -o "$PNG" -s 10 -m 3
  open "$PNG" 2>/dev/null || true
  if [ "$KEEP" = yes ]; then
    echo; echo "Saved $PNG - delete it when you are done."
  else
    echo; echo "Opened $PNG. Press Return once you have scanned it, and it will be deleted."
    read -r _
    rm -f "$PNG"; echo "Deleted."
  fi
fi
