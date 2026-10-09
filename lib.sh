# Shared settings. Values come from config.sh (gitignored) - copy config.example.sh.
_LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_LIBDIR/config.sh" ]; then
  source "$_LIBDIR/config.sh"
else
  echo "Missing config.sh - copy config.example.sh to config.sh and edit it." >&2
  exit 1
fi

current_ip() {
  aws lightsail get-instance --instance-name "$INSTANCE" \
    --region "$AWS_REGION" --profile "$AWS_PROFILE_NAME" \
    --query 'instance.publicIpAddress' --output text
}
