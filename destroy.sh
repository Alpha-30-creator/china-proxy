#!/bin/bash
# Deletes everything so AWS charges nothing. identity.json stays, so a later
# ./deploy.sh brings your clients back with only the address changed.
#
# NOTE: stopping a Lightsail instance does NOT stop billing. Deleting does.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
AWS="aws --region $AWS_REGION --profile $AWS_PROFILE_NAME"

echo "About to delete, in $AWS_REGION:"
$AWS lightsail get-instances --query 'instances[].name' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/  instance:  /'
$AWS lightsail get-static-ips --query 'staticIps[].name' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/  static IP: /'
echo
read -r -p "Type DELETE to confirm: " C
[ "$C" = DELETE ] || { echo "Aborted."; exit 1; }

for i in $($AWS lightsail get-instances --query 'instances[].name' --output text 2>/dev/null); do
  $AWS lightsail delete-instance --instance-name "$i" >/dev/null && echo "deleted instance $i"
done
for s in $($AWS lightsail get-static-ips --query 'staticIps[].name' --output text 2>/dev/null); do
  $AWS lightsail release-static-ip --static-ip-name "$s" >/dev/null && echo "released static IP $s"
done
for d in $($AWS lightsail get-disks --query 'disks[].name' --output text 2>/dev/null); do
  $AWS lightsail delete-disk --disk-name "$d" >/dev/null && echo "deleted disk $d"
done
for n in $($AWS lightsail get-instance-snapshots --query 'instanceSnapshots[].name' --output text 2>/dev/null); do
  $AWS lightsail delete-instance-snapshot --instance-snapshot-name "$n" >/dev/null && echo "deleted snapshot $n"
done

rm -f "$DIR/client-443.json" "$DIR/clash-profile.yaml" "$DIR/phone-qr.png"

echo
echo "--- remaining billable resources ---"
for R in $($AWS lightsail get-regions --query 'regions[].name' --output text); do
  L=$(aws lightsail get-instances --region $R --profile "$AWS_PROFILE_NAME" --query 'instances[].name' --output text 2>/dev/null)
  S=$(aws lightsail get-static-ips --region $R --profile "$AWS_PROFILE_NAME" --query 'staticIps[].name' --output text 2>/dev/null)
  N=$(aws lightsail get-instance-snapshots --region $R --profile "$AWS_PROFILE_NAME" --query 'instanceSnapshots[].name' --output text 2>/dev/null)
  [ -n "$L$S$N" ] && echo "  [$R] $L $S $N"
done
echo "  (nothing listed above = you are being charged nothing)"
echo
echo "The SSH key pair stays - it is free. identity.json is kept locally so that"
echo "./deploy.sh restores a working setup with the same credentials."
