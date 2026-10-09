#!/bin/bash
# How much of this month's data transfer allowance have you used?
# Lightsail counts BOTH inbound and outbound against the allowance, so a proxy
# burns roughly 2 GB of allowance per 1 GB you actually download.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/lib.sh"
START="$(date -u +%Y-%m-01)T00:00:00Z"
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ALLOW=$(aws lightsail get-instance --instance-name "$INSTANCE" --region "$AWS_REGION" \
        --profile "$AWS_PROFILE_NAME" \
        --query 'instance.networking.monthlyTransfer.gbPerMonthAllocated' --output text)
tot=0
for M in NetworkIn NetworkOut; do
  B=$(aws lightsail get-instance-metric-data --instance-name "$INSTANCE" --region "$AWS_REGION" \
      --profile "$AWS_PROFILE_NAME" --metric-name $M --period 86400 \
      --start-time "$START" --end-time "$END" --unit Bytes --statistics Sum \
      --query 'metricData[].sum' --output text 2>/dev/null | tr '\t' '\n' | awk '{s+=$1} END {print s+0}')
  G=$(echo "scale=3; $B/1073741824" | bc -l)
  printf "  %-11s %8.2f GB\n" "$M" "$G"
  tot=$(echo "$tot + $G" | bc -l)
done
printf "  %-11s %8.2f GB of %s GB allowance (%.1f%%)\n" "TOTAL" "$tot" "$ALLOW" \
  "$(echo "scale=4; $tot*100/$ALLOW" | bc -l)"

DAY=$(date -u +%-d)
DIM=$(date -u -v1d -v+1m -v-1d +%-d 2>/dev/null || date -u -d "$(date -u +%Y-%m-01) +1 month -1 day" +%-d)
PROJ=$(echo "scale=1; $tot/$DAY*$DIM" | bc -l)
echo
printf "  Day %s of %s this month. At this rate: ~%.0f GB by month end.\n" "$DAY" "$DIM" "$PROJ"
echo
echo "  The allowance is PER CALENDAR MONTH (UTC) and resets on the 1st. Nothing rolls over."
echo "  Both directions count toward it, so ~2 GB is used per 1 GB you actually download."
echo "  Going over does not cut you off - outbound overage is billed; inbound overage is free."
echo "  Rule of thumb: 1 hour of 1080p video ~= 6 GB of allowance (3 GB each way)."
