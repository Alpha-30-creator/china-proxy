#!/bin/bash
# Checks that this computer is fully routed through the proxy.
# Run it with the proxy ON and any other VPN OFF.
#   ./test-client.sh                     basic suite
#   ./test-client.sh --speed             also measure throughput
#   ./test-client.sh https://extra.url   also check a specific site
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
SPEED=no; EXTRA=()
for a in "$@"; do
  case "$a" in --speed) SPEED=yes ;; http*) EXTRA+=("$a") ;; esac
done

SERVER=$(current_ip)
pass=0; fail=0; warn=0
ok(){   printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass=$((pass+1)); }
no(){   printf "  \033[31mFAIL\033[0m  %s\n" "$1"; fail=$((fail+1)); }
hmm(){  printf "  \033[33mWARN\033[0m  %s\n" "$1"; warn=$((warn+1)); }

echo "Expected exit address: $SERVER"
echo
echo "1. Egress address (no proxy flags - this is the TUN test)"
IP4=$(curl -s -4 --max-time 20 https://api.ipify.org || true)
if [ "$IP4" = "$SERVER" ]; then ok "IPv4 exits via the proxy ($IP4)"
elif [ -z "$IP4" ]; then no "no IPv4 response at all - no connectivity?"
else no "IPv4 exits as $IP4 - NOT the proxy. TUN off, or another VPN is active."; fi

echo
echo "2. IPv6 leak"
SERVER6=$(aws lightsail get-instance --instance-name "$INSTANCE" --region "$AWS_REGION" \
          --profile "$AWS_PROFILE_NAME" --query 'instance.ipv6Addresses' --output text 2>/dev/null)
IP6=$(curl -s -6 --max-time 10 https://api6.ipify.org 2>/dev/null || true)
if [ -z "$IP6" ]; then ok "no IPv6 route - cannot leak"
elif echo "$SERVER6" | grep -qiF "$IP6"; then ok "IPv6 also exits via the proxy ($IP6)"
else no "IPv6 exits as $IP6 - that is NOT the server, so IPv6 traffic bypasses the tunnel."; fi

echo
echo "3. DNS resolver"
R=$(curl -sL --max-time 20 https://edns.ip-api.com/json 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("dns",{}).get("ip",""))' 2>/dev/null || true)
if [ -z "$R" ]; then hmm "could not determine the resolver"
elif [ "$R" = "$SERVER" ]; then ok "DNS resolves through the proxy ($R)"
else hmm "DNS queries reach the internet from $R, not the proxy. Harmless with fake-ip - your traffic is still tunnelled - but it does reveal your region to that resolver."; fi

echo
echo "4. Reachability"
for u in https://www.google.com https://www.youtube.com "${EXTRA[@]}"; do
  C=$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$u" || echo 000)
  [ "$C" != "000" ] && ok "$u -> HTTP $C" || no "$u -> no response"
done

echo
echo "5. Latency to the server"
L=$(ping -c 3 -t 10 "$SERVER" 2>/dev/null | awk -F'/' '/round-trip/{printf "%.0f", $5}')
[ -n "$L" ] && ok "round-trip ${L} ms" || hmm "no ICMP reply (fine if ICMP is closed)"

if [ "$SPEED" = yes ]; then
  echo
  echo "6. Throughput (20 MB download)"
  S=$(curl -s -o /dev/null --max-time 120 -w '%{speed_download}' \
      https://speed.cloudflare.com/__down?bytes=20000000 || echo 0)
  MBPS=$(echo "scale=1; $S*8/1000000" | bc -l)
  echo "     ${MBPS} Mbit/s"
  echo "     (10-50 is normal across a censored border; local speed is not the limit)"
fi

echo
echo "-----------------------------------------"
echo "  $pass passed, $fail failed, $warn warnings"
[ "$fail" -eq 0 ] && echo "  Ready." || echo "  Not ready - fix the failures above."
