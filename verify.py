#!/usr/bin/env python3
"""Proves the tunnel works. Starts a LOCAL SOCKS proxy only - system network
settings are never touched, so your other apps keep working normally."""
import os, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _config

DIR = _config.DIR
cfg = _config.load()
IP = _config.current_ip(cfg)
client = os.path.join(DIR, "client-443.json")
if not os.path.exists(client):
    raise SystemExit("client-443.json missing - run: python3 mkconfig.py")
xray = shutil.which("xray") or "/opt/homebrew/bin/xray"
if not os.path.exists(xray):
    raise SystemExit("xray not found - run: brew install xray")

p = subprocess.Popen([xray,"run","-c",client],
                     stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
time.sleep(4)
if p.poll() is not None:
    raise SystemExit("xray exited early:\n" + p.stderr.read()[:600])
try:
    def via(url):
        return subprocess.run(["curl","-s","-o","/dev/null","-w","%{http_code} in %{time_total}s",
            "--max-time","25","--socks5-hostname","127.0.0.1:10810",url],
            capture_output=True,text=True).stdout
    egress = subprocess.run(["curl","-s","--max-time","25","--socks5-hostname",
        "127.0.0.1:10810","https://api.ipify.org"],capture_output=True,text=True).stdout.strip()
    print(f"egress IP:   {egress or '(none)'}   -> {'PASS' if egress==IP else 'FAIL'}")
    print(f"google.com:  {via('https://www.google.com')}")
finally:
    p.terminate(); p.wait(timeout=10)
    print("(test proxy stopped - your machine is unchanged)")
