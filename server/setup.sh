#!/bin/bash
# Runs as root on a fresh instance. Installs and configures everything.
set -e
XRAY_VERSION=v25.12.8
export DEBIAN_FRONTEND=noninteractive

echo "[1/6] swap + BBR"
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi
grep -q tcp_congestion_control /etc/sysctl.conf || \
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' >> /etc/sysctl.conf
sysctl -p >/dev/null

echo "[2/6] packages"
apt-get update -qq >/dev/null 2>&1 || true
apt-get install -y -qq unzip >/dev/null 2>&1

echo "[3/6] 3x-ui panel"
printf "n\n" | bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) >/tmp/xui.log 2>&1
systemctl is-active --quiet x-ui || { echo "x-ui failed to start"; tail -20 /tmp/xui.log; exit 1; }

echo "[4/6] pin Xray to $XRAY_VERSION (26.x breaks mihomo clients)"
cd /tmp && curl -sL -o x.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"
unzip -oq x.zip xray
install -m 755 /tmp/xray /usr/local/x-ui/bin/xray-linux-amd64
/usr/local/x-ui/bin/xray-linux-amd64 version | head -1

echo "[5/6] panel credentials (generated here, never leave the server)"
U="admin_$(openssl rand -hex 4)"
PW="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)"
WP="$(openssl rand -hex 12)"
IPADDR="$(curl -s -4 ifconfig.me)"
/usr/local/x-ui/x-ui setting -username "$U" -password "$PW" -webBasePath "$WP" -port 2053 >/dev/null 2>&1
{
  echo "3x-ui panel access  (created $(date -u +%Y-%m-%dT%H:%MZ))"
  echo "URL:      http://${IPADDR}:2053/${WP}/"
  echo "Username: ${U}"
  echo "Password: ${PW}"
  echo
  echo "Save these to a password manager. The panel port is closed at the cloud"
  echo "firewall - reach it with ./panel.sh over an SSH tunnel."
} > /root/x-ui-access.txt
chmod 600 /root/x-ui-access.txt
systemctl restart x-ui
sleep 5
/usr/local/x-ui/x-ui setting -getApiToken -tokenScope admin 2>/dev/null \
  | grep -oE '[A-Za-z0-9_.-]{20,}' | tail -1 > /root/.xui-token
chmod 600 /root/.xui-token

echo "[6/6] inbound"
python3 /root/inbound.py
echo
echo "x-ui: $(systemctl is-active x-ui)   xray: $(/usr/local/x-ui/bin/xray-linux-amd64 version | head -1)"
ss -ltn | grep -q ':443 ' && echo "listening on 443" || { echo "ERROR: not listening on 443"; exit 1; }
