# china-proxy

Scripts for running your own encrypted proxy outside a national firewall, so that a laptop and a
phone inside the censored network keep working normally.

A single small VPS runs **Xray** with **VLESS + XTLS-REALITY** on TCP 443. REALITY borrows a real
website's TLS fingerprint, so traffic inspection sees ordinary HTTPS rather than a VPN handshake.

**Why self-hosted rather than a commercial VPN.** Commercial providers have a few thousand
well-known server addresses, and those get dropped on sight — the encryption never has to be
broken. A private server's address is on no such list. The trade-off is that you own the
operations, which is what these scripts are for.

---

## What you need

- An account with a VPS provider. These scripts target **AWS Lightsail** via the `aws` CLI;
  the server-side setup applies to any provider.
- `aws`, `python3`, `ssh`, and `qrencode` (`brew install qrencode`) on your computer.
- A region whose exit location suits you. Pick one close enough for low latency, and check that
  the services you depend on are actually available from that country — some are region-locked
  independently of any firewall, so a nearby exit can solve the censorship problem while leaving
  you blocked anyway.

---

## Server setup

Once, roughly 25 minutes.

**1. Create the instance.** Ubuntu 24.04; the cheapest bundle is plenty, since Xray on one vCPU
handles several hundred Mbit/s. Allocate a **static IP** and attach it: most providers change the
public address on every stop/start, and a static one means a blocked address costs a two-minute
swap instead of rebuilding the machine.

**2. Open the ports** in the provider's firewall: **TCP 443**, **TCP 22**, and **ICMP**.
ICMP matters — without it every ping-based reachability test reports 100% loss from everywhere on
earth and looks exactly like a total block.

**3. Install the panel.**

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

Save the generated credentials to a password manager immediately.

**4. Add swap** if the instance has under 1 GB of RAM:

```bash
fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab
```

**5. Enable BBR** — the highest-value tuning knob on long, lossy routes:

```bash
printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' >> /etc/sysctl.conf
sysctl -p
```

**6. Create the inbound** in the panel: protocol **VLESS**, port **443**, security **REALITY**,
flow `xtls-rprx-vision`.

**7. Close the panel port** at the provider firewall. The panel is plain HTTP, so exposing it
would send the admin password across the network in clear text. Reach it with `./panel.sh`,
which tunnels it over SSH.

### Choosing the REALITY destination

The destination is what inspection sees you connecting to. It must support **TLS 1.3 and HTTP/2**,
respond quickly from the server, and not be blocked where you are connecting from.

**Avoid the obvious candidates.** Xray warns at startup that very popular choices *increase* your
risk, because they are the commonest picks among proxy users and get fingerprinted. Prefer a
plausible, unremarkable, well-provisioned site. Test a candidate with:

```bash
curl -sI --tlsv1.3 --tls-max 1.3 https://CANDIDATE/ -o /dev/null \
  -w '%{http_version} %{time_connect}s %{http_code}\n'
```

Look for `2`, a low connect time, and `200`.

### Use port 443 only

A second inbound on an alternate port is sometimes suggested as insurance against incidents that
target 443. Xray warns that listening on non-standard ports *raises* blocking risk, because
REALITY on an odd port looks anomalous to scanners. On balance, 443 alone is the better bet.

---

## ⚠️ Pin the server's Xray core to v25.12.8

Xray **26.x** changed REALITY in a way **mihomo** — the core inside Clash Verge and several other
clients — does not implement. Against a 26.x server those clients fail every connection with
`REALITY authentication failed`, even when the uuid, public key and short-id are byte-for-byte
correct. Xray-based clients work fine against the same server, which makes it look like a client
bug and can cost hours.

Symptom: the proxy shows **Timeout** in Clash Verge, and the core log says
`REALITY authentication failed`.

To install or restore the working version:

```bash
cd /usr/local/x-ui/bin
curl -sL -o /tmp/x.zip https://github.com/XTLS/Xray-core/releases/download/v25.12.8/Xray-linux-64.zip
unzip -oq /tmp/x.zip xray -d /tmp
install -m 755 /tmp/xray xray-linux-amd64
systemctl restart x-ui && ./xray-linux-amd64 version | head -1
```

Updating the Xray core from the panel will break mihomo clients again.

---

## Configure the scripts

```bash
cp config.example.sh config.sh    # then edit it
```

`config.sh` holds the provider profile, region, instance name, SSH key path and REALITY
destination. It is gitignored.

| Script | What it does |
|---|---|
| `./show-link.sh` | Prints the panel URL, login and the `vless://` link. **Output is secret.** |
| `./qr.sh` | **Pair a phone.** Prints the connection QR in your terminal. |
| `./swap-ip.sh` | **Emergency.** Swaps a blocked address for a fresh one. ~2 minutes. |
| `./panel.sh` | SSH tunnel to the admin panel. |
| `./usage.sh` | How much of this month's data transfer allowance you have used. |
| `./test-client.sh` | Checks this computer is fully routed: egress, IPv6 leak, DNS, reachability. |
| `python3 mkconfig.py` | Regenerates the local Xray test config. |
| `python3 mkclash.py` | Regenerates a Clash/mihomo profile. |
| `python3 verify.py` | Proves the tunnel works, without touching system network settings. |

Every script looks up the current address from the provider API, so they all stay correct after a
swap.

---

## Pairing a phone

```bash
./qr.sh
```

The QR prints straight into your terminal. In **v2rayNG**: **+** → **Scan QR code** → point the
camera at the screen.

| Command | When |
|---|---|
| `./qr.sh` | Normal case |
| `./qr.sh --png` | Terminal font too small to scan. Opens an image, deletes it when you press Return |
| `./qr.sh --png --keep` | Keeps the image — delete it yourself, it is a credential in picture form |
| `./qr.sh --link` | Prints the `vless://` text, for pasting into a desktop client |

> The panel can also produce the QR, but it lives on the **client**, not the inbound:
> Inbounds → click the **client-count badge** to expand the client row, and the QR icon is there.
> The inbound's own **⋮** menu has no QR. `./qr.sh` exists to skip that.
>
> The panel is still where you add a **second** client, so a spare device gets its own credential
> and can be revoked independently.

### Installing v2rayNG

Get the `arm64-v8a` APK from the [official releases](https://github.com/2dust/v2rayNG/releases).
Avoid APK mirror sites — at least one circulating fork ships an outdated core.

**Install it before you travel.** GitHub downloads are blocked or throttled inside the firewall,
so arriving without a client is the one mistake with no recovery path.

Afterwards set the app to **unrestricted battery usage**, or Android will kill it in the
background and drop the tunnel without telling you.

---

## Desktop client

[Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev/releases) works well.

```bash
python3 mkclash.py
```

Import the generated `clash-profile.yaml` as a **Local** profile — the import box only accepts
`http(s)` subscription URLs, not raw share links. Then select the proxy under **Proxies**.

### System Proxy vs TUN

**System Proxy** writes a setting into the OS network preferences that applications have to choose
to read. Browsers do. `curl`, `git`, `ssh`, `npm`, `pip` and cloud CLIs do **not** — they only
honour `HTTPS_PROXY` environment variables.

**TUN mode** captures traffic at the network layer, so applications get no say. It needs a
privileged helper service installed once.

If you only browse, System Proxy is enough. **If you work from a terminal, use TUN** — otherwise
your tooling silently bypasses the tunnel and hangs in a way that is baffling to debug.

Use one or the other, not both. The test that distinguishes them:

```bash
curl -s https://api.ipify.org
```

With no `-x` flag, only TUN makes that return the server's address.

---

## Verifying

**The whole client, in one command** — run it with the proxy on and any other VPN off:

```bash
./test-client.sh            # add --speed to measure throughput
```

It checks the egress address without any proxy flags (which is what proves TUN is active, not
just System Proxy), looks for an IPv6 bypass, reports which resolver your DNS actually reaches,
and confirms reachability and latency.

**Just the tunnel, without changing system settings:** `python3 verify.py` — expect the server's
address as the egress, and a 200 from a site that would otherwise be blocked.

**From inside the firewall — the test that matters:**

```
https://ping.pe/<your-ip>
```

No CAPTCHA, English, and it probes from a dozen cities inside the censored network. Scroll to the
rows beginning with the country name: **0% loss is good, 100% means the address is blocked.**

Avoid tools that gate testing behind a localised click-the-characters CAPTCHA.

---

## When the address gets blocked

```bash
./swap-ip.sh
```

It releases the dead address, allocates a fresh one, re-points the connection details at it, and
prints the next steps. About two minutes.

**It keeps the same uuid and REALITY keys.** The server listens on `0.0.0.0:443` and never cared
about its own address — only the share link embedded it. So on each device you change exactly one
field. **You do not need to re-pair, re-scan, or re-import anything.**

Note the new address that the script prints, then do both devices.

#### Desktop — Clash Verge

1. The script already regenerated `clash-profile.yaml` with the new address.
2. In Clash Verge go to **Profiles**.
3. Click the **edit (pencil)** icon on your profile to open its editor.
4. Find the single line `    server: <old-address>` and change it to the new one.
   Leave `uuid`, `public-key`, `short-id` and `servername` exactly as they are.
5. **Save.** The core reloads automatically.
6. **Proxies** → re-run the latency test. It should show a number, not *Timeout*.

   Prefer to start clean? Delete the profile and re-import the regenerated
   `clash-profile.yaml` as a **Local** profile — same result, a few more clicks.

7. Confirm, with no `-x` flag (this also proves TUN is still active):

   ```bash
   curl -s https://api.ipify.org
   ```

   It must print the **new** address.

#### Phone — v2rayNG

1. Open v2rayNG. **Do not** tap **+**; you are editing, not adding.
2. Tap the **pencil / edit** icon on the right of your existing profile row.
3. Change the **Address** field to the new address. Leave **Port**, **id (UUID)**,
   **SNI**, **publicKey**, **shortId**, **Fingerprint** and **Flow** untouched.
4. Tap the **✓ / save** icon, top right.
5. Tap the profile row to make sure it is still selected.
6. Tap the **V button**: once to disconnect, once more to reconnect. A stale connection
   will otherwise keep trying the dead address.
7. Check with **⋮ → Test profile connection**, or just load a site that was blocked.

If the edit screen is confusing, `./qr.sh` on the computer gives you a fresh QR — scan it,
then delete the old profile so you are not left with two.

#### Afterwards

- Verify from inside the network: `https://ping.pe/<new-address>` — country rows at 0% loss.
- If they are at 100%, the replacement address is blocked too. Run `./swap-ip.sh` again.

> **Expect to run it more than once.** Cloud providers recycle addresses, and many were already
> burned by previous proxy users. **Getting a blocked address is the normal case, not bad luck** —
> while building this setup, the very first address allocated was already blackholed before it had
> ever been used. Re-running costs nothing.

You need some connectivity to run the script at all. A foreign SIM roaming inside the country
routes back through its home network and bypasses the firewall entirely, which makes it a reliable
repair path when everything else is down.

### Diagnose before you swap

Most "it's blocked" moments are not. Rule out the boring explanations first.

| Symptom | Likely cause |
|---|---|
| Works on mobile data, not on wifi | The local network, not the firewall. Hotel and office wifi break tunnels constantly. |
| All ping nodes worldwide show 100% loss | ICMP is closed at the provider firewall. Open it. |
| Client shows **Timeout**, log says `REALITY authentication failed` | Server Xray is 26.x. See the version pin above. |
| Browser works, terminal does not | System Proxy is on instead of TUN. |
| Only nodes inside the country fail, everywhere else is fine | The address really is blocked. Swap it. |

Confirm the last one with controls before acting: check that those same probe nodes can reach a
domestic address *and* an unrelated foreign address. If both succeed and only yours fails, it is a
block.

---

## Sizing: is the cheapest instance enough?

For a couple of devices, almost certainly yes. **The constraint is the cross-border link, not the
server.** Those links deliver roughly 10–50 Mbit/s; a one-vCPU instance running XTLS-Vision pushes
several hundred, and the data path uses `splice`, so encryption barely touches the CPU. Two
simultaneous clients — a laptop doing browsing, chat and video, and a phone doing messaging and
calls — is not a meaningful load. RAM is the thing to watch on a 512 MB box, which is why the
setup adds 1 GB of swap.

**Data transfer is the real limit**, and it is easy to misjudge, because the allowance counts
**both directions**. Every 1 GB you download costs about **2 GB** of allowance: once arriving at
the server, once leaving it for you.

| Activity | Per hour, real | Per hour, allowance |
|---|---|---|
| Terminal work, chat, LLM APIs | a few MB | negligible |
| Browsing, social media | ~0.1–0.3 GB | ~0.2–0.6 GB |
| Video call | ~0.5 GB | ~1 GB |
| 1080p video | ~3 GB | ~6 GB |
| 4K video | ~7 GB | ~14 GB |

With a 1 TB allowance that is roughly **160 hours of 1080p a month**, or unlimited amounts of
everything else. Only sustained 4K streaming puts it at risk.

Check where you stand at any time:

```bash
./usage.sh
```

If you do exceed it, the instance is not cut off — the overage is billed, on the order of
$0.09–0.12 per GB depending on region, and only on outbound.

**Resizing is not an in-place operation.** You snapshot the instance and create a new, larger one
from the snapshot, which gets a new address — so budget for re-pairing your clients. Given the
link is the bottleneck, upgrade only if `./usage.sh` says you are near the transfer cap, never
for speed.

---

## Operating notes

- **Pick one exit country and stay there.** Services flag rapid geographic hopping as an
  account-abuse signal.
- **Stay signed in to things.** Some providers put login flows behind bot protection that
  challenges datacenter addresses, so a fresh sign-in through the tunnel can fail where an
  existing session works fine. Log in before you travel.
- **Expect evening congestion.** International links slow down at night independently of your
  setup. Not a fault to debug.
- **Realistic throughput:** measured on this setup, **~60 Mbit/s from inside the censored
  network** (146 ms to the server) against ~130 Mbit/s from outside it (46 ms). Your local line
  speed is not the constraint — the cross-border link is, and the proxy itself costs a few
  percent. Expect worse at peak hours.
- **Keep profile names unremarkable, and don't redistribute access.** Personal use is a tolerated
  grey area in many places; distributing access is a different category of risk. Check the rules
  that apply to you.

---

## Security notes

- `config.sh`, `client-*.json`, `clash-profile.yaml` and `*.png` are gitignored — they hold either
  infrastructure details or the client UUID, which is a credential.
- Panel credentials belong in a password manager, never in the repository.
- The admin panel is not exposed to the internet. Use `./panel.sh`.
- Back up the SSH private key. Without it you lose server access and must rebuild.
- Prefer a scoped API credential over a root one. A root key cannot be restricted, so a leak costs
  the whole account rather than one service.
- Keep the server patched. Updates and a reboot do not disturb a static address.

---

## Costs

A nano instance is in the region of $5/month, often with an introductory free period. Two traps:
free periods tend to **start billing silently** rather than warn you, and some providers count
**inbound as well as outbound** traffic against the transfer allowance, effectively halving it.
Either way it is far more than text-based work consumes — only video streaming would threaten it.
