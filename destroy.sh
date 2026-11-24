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
# Never let this sweep abort the script: the deletions above have already happened,
# and a failed check must not be mistaken for a failed teardown. Regions the account
# has not opted into return a token error, so "no output" alone is not proof of
# "nothing there" - count what was actually checked and say so.
checked=0; found=0; unreachable=""
REGIONS=$($AWS lightsail get-regions --query 'regions[].name' --output text 2>/dev/null) || REGIONS=""

if [ -z "$REGIONS" ]; then
  echo "  !! could not list regions - verify the account yourself before trusting this."
else
  for R in $REGIONS; do
    AR="aws --region $R --profile $AWS_PROFILE_NAME"
    # The first call doubles as the reachability probe for this region.
    if ! L=$($AR lightsail get-instances --query 'instances[].name' --output text 2>/dev/null); then
      unreachable="$unreachable $R"; continue
    fi
    S=$($AR lightsail get-static-ips        --query 'staticIps[].name'        --output text 2>/dev/null || true)
    N=$($AR lightsail get-instance-snapshots --query 'instanceSnapshots[].name' --output text 2>/dev/null || true)
    D=$($AR lightsail get-disks             --query 'disks[].name'            --output text 2>/dev/null || true)
    checked=$((checked + 1))
    if [ -n "$L$S$N$D" ]; then
      echo "  [$R] $L $S $N $D"
      found=$((found + 1))
    fi
  done

  echo
  echo "  checked $checked region(s); $found had resources."

  if [ -n "$unreachable" ]; then
    echo "  could not query:$unreachable"
    for R in $unreachable; do
      ST=$(aws account get-region-opt-status --region-name "$R" --profile "$AWS_PROFILE_NAME" \
             --query 'RegionOptStatus' --output text 2>/dev/null || echo UNKNOWN)
      case "$ST" in
        DISABLED|DISABLING)
          echo "    $R - not enabled on this account, so nothing can exist there. Fine." ;;
        *)
          echo "    $R - status $ST. CHECK THIS ONE BY HAND." ;;
      esac
    done
  fi

  if [ "$found" -eq 0 ] && [ "$checked" -gt 0 ]; then
    echo
    echo "  Nothing billable found in any region that could be checked."
  fi
fi

echo
echo "The SSH key pair stays - it is free. identity.json is kept locally so that"
echo "./deploy.sh restores a working setup with the same credentials."
