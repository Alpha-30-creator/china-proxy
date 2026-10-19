#!/bin/bash
# EMERGENCY: run this when China blocks your server's IP. Takes ~2 minutes.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"

OLD=$(current_ip)
OLDNAME=$(aws lightsail get-static-ips --region "$AWS_REGION" --profile "$AWS_PROFILE_NAME" \
          --query "staticIps[?ipAddress=='$OLD'].name" --output text)
NEW="${INSTANCE}-ip-$(date +%s)"
echo "Current IP: $OLD"
if [ -n "$OLDNAME" ] && [ "$OLDNAME" != "None" ]; then
  aws lightsail detach-static-ip  --static-ip-name "$OLDNAME" --region "$AWS_REGION" --profile "$AWS_PROFILE_NAME" >/dev/null
  aws lightsail release-static-ip --static-ip-name "$OLDNAME" --region "$AWS_REGION" --profile "$AWS_PROFILE_NAME" >/dev/null
  echo "Released the blocked IP."
fi
aws lightsail allocate-static-ip --static-ip-name "$NEW" --region "$AWS_REGION" --profile "$AWS_PROFILE_NAME" >/dev/null
aws lightsail attach-static-ip --static-ip-name "$NEW" --instance-name "$INSTANCE" --region "$AWS_REGION" --profile "$AWS_PROFILE_NAME" >/dev/null
IP=$(current_ip)
echo "New IP: $IP"

ssh-keygen -R "$OLD" >/dev/null 2>&1 || true
ssh-keyscan -t ed25519 "$IP" >> ~/.ssh/known_hosts 2>/dev/null || true

echo "Re-pointing the connection details at the new IP..."
# relink.py keeps the SAME uuid and REALITY keys - only the server address changes,
# so on your devices you only have to edit one line.
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$IP" 'sudo python3 /root/relink.py' | tail -2
python3 "$DIR/mkconfig.py"
python3 "$DIR/mkclash.py"

cat <<MSG

=====================================================================
NEXT STEPS - do these in order:

1. CHECK IT IS NOT BLOCKED TOO:
      https://ping.pe/$IP
   Scroll to the rows starting with "China".
   All 0% loss  -> good, continue.
   All 100%     -> run this script again (AWS hands out burned IPs).

2. GET THE NEW CONNECTION LINK:
      ./show-link.sh

3. UPDATE YOUR DEVICES. Only the IP changed - your uuid and keys are the same.
   Mac:   Clash Verge -> Profiles -> edit clash-profile -> change the ONE line
            server: <old-ip>   ->   server: $IP
          then Save. (Or re-import ./clash-profile.yaml, already regenerated.)
   Phone: v2rayNG -> tap the pencil/edit on sg-443 -> change "Address" to $IP -> save.
          No need to re-scan the QR code.
=====================================================================
MSG
