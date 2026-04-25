# cloudflare-updater

Swift CLIs for **Cloudflare DNS** when your origin has a **dynamic public IPv4**.

## Products

| Binary | Purpose |
|--------|---------|
| **`CloudFlareUpdater`** | Reads current public IPv4, then **creates or updates** the zone **A** record for **`--site`** (e.g. apex **`shapetree.org`**). Intended for a **systemd timer** every minute. |
| **`CreateCNAMERecord`** | **Creates or fixes** a **CNAME**: **`--site`** (FQDN, e.g. **`api.shapetree.org`**) → **`--target`** (apex, e.g. **`shapetree.org`**). Idempotent: skips if correct, **PATCH**es if the target is wrong. Run **once** (or occasionally) — not on the same timer as the A record. |

Together: **A** on the apex follows the server IP; **CNAME**s to the apex follow automatically.

## Build

```bash
swift build -c release --product CloudFlareUpdater
swift build -c release --product CreateCNAMERecord
```

## CloudFlareUpdater

```bash
CloudFlareUpdater --zone-id ZONE_ID --site shapetree.org --email you@example.com --api-key GLOBAL_API_KEY
```

Logs: **`Logs/dns.log`** (cwd-relative). State files: **`Logs/ip4.txt`**, etc. Each log line is also printed to **stdout** so **systemd** captures the same text under **`journalctl -u cloudflare-updater.service`**. Swift may still emit harmless **`errno=13`** thread-priority lines to **stderr** in the journal.

**Public IPv4 discovery** uses **`curl -4`** against **`CLOUDFLARE_PUBLIC_IP_URL`** if set, otherwise **`https://api.ipify.org`** (plain body = IP). Do not default to your own apex hostname before DNS points at this box, or updates never run. If you see **`curl command failed … exited(6)`** in **`dns.log`**, **`curl`’s exit 6** is **“Could not resolve host”** (DNS to that URL failed); check resolver/network or try **`curl -4 -sS https://api.ipify.org`** on the host.

## CreateCNAMERecord

**`api`** for server-tower / Caddy:

```bash
CreateCNAMERecord \
  --zone-id ZONE_ID \
  --site api.shapetree.org \
  --target shapetree.org \
  --email you@example.com \
  --api-key GLOBAL_API_KEY
```

**`www`** (if you want the tool to manage it instead of the dashboard):

```bash
CreateCNAMERecord \
  --zone-id ZONE_ID \
  --site www.shapetree.org \
  --target shapetree.org \
  --email you@example.com \
  --api-key GLOBAL_API_KEY
```

Same options via env: **`CLOUDFLARE_ZONE_ID`**, **`CLOUDFLARE_SITE`**, **`CLOUDFLARE_CNAME_TARGET`**, **`CLOUDFLARE_EMAIL`**, **`CLOUDFLARE_API_KEY`**.

Logs: **`Logs/cname.log`** (also mirrored to stdout / **`journalctl -u cloudflare-cname-api.service`** when run under systemd).

More context: **[CNAME_SETUP.md](./CNAME_SETUP.md)**.

## DocC

```bash
docc preview Sources/CloudFlareUpdater/CloudFlareUpdater.docc
docc preview Sources/CreateCNAMERecord/CreateCNAMERecord.docc
```
