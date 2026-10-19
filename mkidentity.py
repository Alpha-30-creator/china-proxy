#!/usr/bin/env python3
"""Creates identity.json once: the uuid and REALITY keypair reused across every
redeploy, so clients only ever need their server address changed. Gitignored."""
import json, os, re, secrets, shutil, subprocess, sys, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _config

DIR = _config.DIR
path = os.path.join(DIR, "identity.json")
if os.path.exists(path):
    print(f"identity.json already exists - reusing it (clients keep working)"); raise SystemExit

cfg = _config.load()
xray = shutil.which("xray") or "/opt/homebrew/bin/xray"
if not os.path.exists(xray):
    raise SystemExit("xray not found - run: brew install xray")
out = subprocess.run([xray, "x25519"], capture_output=True, text=True).stdout
priv = re.search(r"Private[Kk]ey:\s*(\S+)", out).group(1)
m = re.search(r"Password \(PublicKey\):\s*(\S+)", out) or re.search(r"Public [Kk]ey:\s*(\S+)", out)
ident = {"uuid": str(uuid.uuid4()), "privateKey": priv, "publicKey": m.group(1),
         "shortId": secrets.token_hex(4), "sni": cfg.get("REALITY_SNI", "www.asus.com")}
json.dump(ident, open(path, "w"), indent=2); os.chmod(path, 0o600)
print(f"Created identity.json (sni={ident['sni']}). Back this up - it is what keeps your\n"
      f"clients working across redeploys.")
