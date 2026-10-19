#!/usr/bin/env python3
"""Creates the VLESS/REALITY inbound from a fixed identity, so redeploys keep
the same uuid and keys and clients only need their server address changed."""
import json, re, secrets, subprocess, sys, time, urllib.request

ident = json.load(open('/root/identity.json'))
WP = re.search(r':2053/([a-f0-9]+)/', open('/root/x-ui-access.txt').read()).group(1)
T = open('/root/.xui-token').read().strip()
B = f"http://127.0.0.1:2053/{WP}/panel/api/inbounds"
IPADDR = subprocess.run(['curl','-s','-4','ifconfig.me'],capture_output=True,text=True).stdout.strip()

def call(path, data=None, method="POST"):
    body = json.dumps(data).encode() if data is not None else b""
    req = urllib.request.Request(B+path, data=body, method=method,
        headers={"Authorization":"Bearer "+T, "Content-Type":"application/json"})
    return json.load(urllib.request.urlopen(req))

for ib in call("/list", method="GET")["obj"]:
    call("/del/%d" % ib["id"])
time.sleep(3)

SNI = ident["sni"]
stream = json.dumps({"network":"tcp","security":"reality","externalProxy":[],
  "realitySettings":{"show":False,"xver":0,"dest":SNI+":443","serverNames":[SNI],
    "privateKey":ident["privateKey"],"shortIds":[ident["shortId"]],
    "settings":{"publicKey":ident["publicKey"],"fingerprint":"chrome",
                "serverName":"","spiderX":"/"}},
  "tcpSettings":{"acceptProxyProtocol":False,"header":{"type":"none"}}})

payload = {"up":0,"down":0,"total":0,"remark":"sg-443","enable":True,"expiryTime":0,
  "listen":"","port":443,"protocol":"vless",
  "settings":json.dumps({"clients":[{"id":ident["uuid"],"flow":"xtls-rprx-vision",
      "email":"primary-"+secrets.token_hex(3),"limitIp":0,"totalGB":0,
      "expiryTime":0,"enable":True}],"decryption":"none","fallbacks":[]}),
  "streamSettings":stream,
  "sniffing":json.dumps({"enabled":True,"destOverride":["http","tls","quic"]})}

for attempt in range(4):
    try:
        r = call("/add", payload)
        if r.get("success"):
            break
        print("attempt", attempt+1, "failed:", r.get("msg"))
    except Exception as e:
        print("attempt", attempt+1, "exception:", e)
    time.sleep(4)
else:
    sys.exit("could not create the inbound")

link = (f"vless://{ident['uuid']}@{IPADDR}:443?type=tcp&security=reality"
        f"&pbk={ident['publicKey']}&fp=chrome&sni={SNI}&sid={ident['shortId']}"
        f"&spx=%2F&flow=xtls-rprx-vision#sg-443")
head = open('/root/x-ui-access.txt').read().split('REALITY dest')[0].split('--- client share links ---')[0].rstrip()
with open('/root/x-ui-access.txt','w') as f:
    f.write(head + f"\n\nREALITY dest/SNI: {SNI}\n\n--- client share links ---\n{link}\n")
print("inbound created on 443")
