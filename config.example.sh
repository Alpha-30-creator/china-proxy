# Copy to config.sh and edit. config.sh is gitignored.
AWS_PROFILE_NAME=my-aws-profile     # aws CLI profile with Lightsail access
AWS_REGION=ap-southeast-1           # region the instance lives in
INSTANCE=my-proxy-instance       # Lightsail instance name
SSH_KEY="$HOME/.ssh/my-proxy-key"   # private key for the instance
REALITY_SNI=www.asus.com            # REALITY camouflage destination
KEY_PAIR=my-proxy-key              # Lightsail SSH key pair name
