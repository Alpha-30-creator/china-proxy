#!/bin/bash
# Creates the proxy server from nothing. Safe to re-run after ./destroy.sh.
# Reuses identity.json, so your phone and laptop only need the new address.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
AWS="aws --region $AWS_REGION --profile $AWS_PROFILE_NAME"
BLUEPRINT=ubuntu_24_04
BUNDLE=${BUNDLE:-nano_3_0}

if $AWS lightsail get-instance --instance-name "$INSTANCE" >/dev/null 2>&1; then
  echo "Instance '$INSTANCE' already exists. Nothing to do."
  echo "Current address: $(current_ip)"; exit 0
fi

python3 "$DIR/mkidentity.py"

echo "[1/7] SSH key pair"
if ! $AWS lightsail get-key-pair --key-pair-name "$KEY_PAIR" >/dev/null 2>&1; then
  [ -f "$SSH_KEY" ] || ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$KEY_PAIR" >/dev/null
  $AWS lightsail import-key-pair --key-pair-name "$KEY_PAIR" \
     --public-key-base64 "$(cat "${SSH_KEY}.pub")" >/dev/null
  echo "      imported"
else
  echo "      reusing existing key pair"
fi

echo "[2/7] creating instance ($BUNDLE, $AWS_REGION)"
$AWS lightsail create-instances --instance-names "$INSTANCE" \
  --availability-zone "${AWS_REGION}a" --blueprint-id $BLUEPRINT --bundle-id "$BUNDLE" \
  --key-pair-name "$KEY_PAIR" >/dev/null

echo -n "      waiting for it to run"
for i in $(seq 1 60); do
  S=$($AWS lightsail get-instance --instance-name "$INSTANCE" --query 'instance.state.name' --output text 2>/dev/null || echo pending)
  [ "$S" = running ] && { echo " - running"; break; }
  echo -n "."
done

echo "[3/7] static IP"
SIP="${INSTANCE}-ip-$(date +%s)"
$AWS lightsail allocate-static-ip --static-ip-name "$SIP" >/dev/null
$AWS lightsail attach-static-ip --static-ip-name "$SIP" --instance-name "$INSTANCE" >/dev/null
IP=$(current_ip); echo "      $IP"

echo "[4/7] firewall: TCP 443, TCP 22, ICMP"
$AWS lightsail put-instance-public-ports --instance-name "$INSTANCE" --port-infos \
  'fromPort=22,toPort=22,protocol=TCP' 'fromPort=443,toPort=443,protocol=TCP' \
  'fromPort=-1,toPort=-1,protocol=ICMP' >/dev/null

echo -n "[5/7] waiting for SSH"
ssh-keygen -R "$IP" >/dev/null 2>&1 || true
for i in $(seq 1 40); do
  if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
       -o BatchMode=yes "ubuntu@$IP" true 2>/dev/null; then echo " - up"; break; fi
  echo -n "."
done

echo "[6/7] configuring the server (3-4 minutes)"
scp -q -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
    "$DIR/server/setup.sh" "$DIR/server/inbound.py" "$DIR/server/relink.py" \
    "$DIR/identity.json" "ubuntu@$IP:/tmp/"
ssh -i "$SSH_KEY" "ubuntu@$IP" \
  'sudo mv /tmp/setup.sh /tmp/inbound.py /tmp/relink.py /tmp/identity.json /root/ &&
   sudo chmod 600 /root/identity.json && sudo chmod +x /root/setup.sh &&
   sudo /root/setup.sh'

echo "[7/7] local client configs"
python3 "$DIR/mkconfig.py"
python3 "$DIR/mkclash.py"

cat <<MSG

=====================================================================
  Deployed.  Address: $IP

  1. Check it is not pre-blocked:   https://ping.pe/$IP
       country rows all 0%  -> good
       all 100%             -> ./destroy.sh then ./deploy.sh again
  2. Your uuid and keys are UNCHANGED, so on each device just update
     the address:
       Mac    Clash Verge -> profile -> server: $IP
       Phone  v2rayNG -> edit profile -> Address: $IP
     (or re-pair from scratch with ./qr.sh)
  3. Verify:  ./test-client.sh
  4. Panel login:  ./show-link.sh
=====================================================================
MSG
