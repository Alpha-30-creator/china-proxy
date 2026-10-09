#!/usr/bin/env python3
"""Generates clash-profile.yaml for Clash Verge / mihomo. Gitignored - holds a credential."""
import os, subprocess, sys
from urllib.parse import urlparse, parse_qs
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _config

DIR = _config.DIR
cfg = _config.load()
IP = _config.current_ip(cfg)
raw = subprocess.run(["ssh","-i",os.path.expanduser(cfg["SSH_KEY"]),
    "-o","StrictHostKeyChecking=accept-new","-o","ConnectTimeout=20",
    f"ubuntu@{IP}","sudo grep -h '^vless://' /root/x-ui-access.txt"],
    capture_output=True, text=True).stdout.strip().splitlines()
if not raw:
    raise SystemExit("No share link on the server.")
u = urlparse(raw[0]); q = parse_qs(u.query)

yaml = f"""# generated for {IP}
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false

dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver: [1.1.1.1, 8.8.8.8]

proxies:
  - name: "sg-443"
    type: vless
    server: {u.hostname}
    port: {u.port}
    uuid: {u.username}
    network: tcp
    udp: true
    tls: true
    flow: {q.get('flow',[''])[0]}
    servername: {q['sni'][0]}
    client-fingerprint: {q.get('fp',['chrome'])[0]}
    reality-opts:
      public-key: {q['pbk'][0]}
      short-id: "{q.get('sid',[''])[0]}"

proxy-groups:
  - name: "PROXY"
    type: select
    proxies: ["sg-443", "DIRECT"]

rules:
  - GEOIP,PRIVATE,DIRECT,no-resolve
  - MATCH,PROXY
"""
path = os.path.join(DIR, "clash-profile.yaml")
open(path,"w").write(yaml); os.chmod(path, 0o600)
print(f"Wrote {path}  -> {u.hostname}:{u.port}")
