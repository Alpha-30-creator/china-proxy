"""Reads config.sh so the Python scripts share the shell scripts' settings."""
import os, re

DIR = os.path.dirname(os.path.abspath(__file__))

def load():
    path = os.path.join(DIR, "config.sh")
    if not os.path.exists(path):
        raise SystemExit("Missing config.sh - copy config.example.sh to config.sh and edit it.")
    cfg = {}
    for line in open(path):
        line = line.split("#", 1)[0].strip()
        m = re.match(r'^(\w+)=(.*)$', line)
        if m:
            cfg[m.group(1)] = os.path.expandvars(m.group(2).strip().strip('"\''))
    return cfg

def current_ip(cfg):
    import subprocess
    return subprocess.run(["aws","lightsail","get-instance","--instance-name",cfg["INSTANCE"],
        "--region",cfg["AWS_REGION"],"--profile",cfg["AWS_PROFILE_NAME"],
        "--query","instance.publicIpAddress","--output","text"],
        capture_output=True, text=True).stdout.strip()
