#!/usr/bin/env python3
"""Regenerates the local Xray test config (client-443.json) from the live server."""
import json, os, subprocess, sys
from urllib.parse import urlparse, parse_qs, unquote
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
    raise SystemExit("No share link found on the server.")

u = urlparse(raw[0]); q = parse_qs(u.query)
out = {"log":{"loglevel":"warning"},
  "inbounds":[{"port":10810,"listen":"127.0.0.1","protocol":"socks","settings":{"udp":True}}],
  "outbounds":[{"protocol":"vless","settings":{"vnext":[{"address":u.hostname,"port":u.port,
      "users":[{"id":u.username,"encryption":"none","flow":q.get("flow",[""])[0]}]}]},
    "streamSettings":{"network":"tcp","security":"reality",
      "realitySettings":{"serverName":q["sni"][0],"fingerprint":q.get("fp",["chrome"])[0],
        "publicKey":q["pbk"][0],"shortId":q.get("sid",[""])[0],
        "spiderX":unquote(q.get("spx",["/"])[0])}}}]}
path = os.path.join(DIR,"client-443.json")
json.dump(out, open(path,"w"), indent=2); os.chmod(path,0o600)
print(f"Wrote local test config -> {u.hostname}:{u.port}")
