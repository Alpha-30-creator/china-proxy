#!/usr/bin/env python3
"""Rewrites the share link for the CURRENT server address, keeping uuid and keys."""
import json, re, subprocess, urllib.request
WP = re.search(r':2053/([a-f0-9]+)/', open('/root/x-ui-access.txt').read()).group(1)
T = open('/root/.xui-token').read().strip()
B = f"http://127.0.0.1:2053/{WP}/panel/api/inbounds"
IPADDR = subprocess.run(['curl','-s','-4','ifconfig.me'],capture_output=True,text=True).stdout.strip()
req = urllib.request.Request(B+"/list", data=b"", method="GET",
        headers={"Authorization":"Bearer "+T})
links, sni = [], "?"
for ib in json.load(urllib.request.urlopen(req))["obj"]:
    st = ib["settings"] if isinstance(ib["settings"], dict) else json.loads(ib["settings"])
    ss = ib["streamSettings"] if isinstance(ib["streamSettings"], dict) else json.loads(ib["streamSettings"])
    rs = ss.get("realitySettings") or {}
    if not rs: continue
    c = st["clients"][0]; sni = rs["serverNames"][0]
    links.append(f"vless://{c['id']}@{IPADDR}:{ib['port']}?type=tcp&security=reality"
                 f"&pbk={rs['settings']['publicKey']}&fp={rs['settings'].get('fingerprint','chrome')}"
                 f"&sni={sni}&sid={rs['shortIds'][0]}&spx=%2F"
                 f"&flow={c.get('flow','xtls-rprx-vision')}#{ib['remark']}")
txt = open('/root/x-ui-access.txt').read()
head = re.sub(r'\d+\.\d+\.\d+\.\d+', IPADDR,
       txt.split('REALITY dest')[0].split('--- client share links ---')[0].rstrip())
with open('/root/x-ui-access.txt','w') as f:
    f.write(head + f"\n\nREALITY dest/SNI: {sni}\n\n--- client share links ---\n")
    for l in links: f.write(l+"\n")
print(f"Relinked {len(links)} inbound(s) to {IPADDR} (uuid and keys unchanged)")
