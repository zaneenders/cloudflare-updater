# cloudflare-updater

Swift CLIs for **Cloudflare DNS**: dynamic **A** records, **CNAME** helpers, and **iCloud+ Custom Email Domain** sync.

Shared library **`CloudflareDNS`** holds the Cloudflare API client and record upsert logic; each binary is a thin **ArgumentParser** wrapper.

## Products

| Binary | Purpose |
|--------|---------|
| **`CloudFlareUpdater`** | Reads current public IPv4, then **creates or updates** the zone **A** record for **`--site`** (e.g. apex **`example.com`**). Run on a **systemd timer** (~every minute). |
| **`CreateCNAMERecord`** | **Creates or fixes** a **CNAME**: **`--site`** (FQDN, e.g. **`www.example.com`**) → **`--target`** (apex). Idempotent: skips if correct, **PATCH**es if wrong. Run once or occasionally — not on the same timer as the A record. |
| **`SyncICloudMailDNS`** | Idempotently syncs [iCloud+ Custom Email Domain](https://support.apple.com/en-us/102540) DNS to Cloudflare (TXT, MX, DKIM CNAME). Run daily or after Apple gives you new verification values. |

Together: **A** on the apex follows the server IP; **CNAME**s to the apex track automatically; **mail** records stay aligned with Apple.

## Build

```bash
swift build -c release
# or one product:
swift build -c release --product CloudFlareUpdater
swift build -c release --product CreateCNAMERecord
swift build -c release --product SyncICloudMailDNS
```

**Linux static (musl)** — same as CI:

```bash
swift sdk install https://download.swift.org/swift-6.2.3-release/static-sdk/swift-6.2.3-RELEASE/swift-6.2.3-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
  --checksum f30ec724d824ef43b5546e02ca06a8682dafab4b26a99fbb0e858c347e507a2c
swift build --swift-sdk x86_64-swift-linux-musl -c release
```

Binaries land in **`.build/release/`** (or **`.build/x86_64-swift-linux-musl/release/`** for musl).

## Shared options

All tools accept **`--zone-id`**, **`--email`**, and **`--api-key`** (Cloudflare Global API Key + account email). Env fallbacks:

| Variable | Used by |
|----------|---------|
| `CLOUDFLARE_ZONE_ID` | all |
| `CLOUDFLARE_EMAIL` | all |
| `CLOUDFLARE_API_KEY` | all |
| `CLOUDFLARE_SITE` | **CloudFlareUpdater** (apex), **SyncICloudMailDNS** (`--domain`) |
| `CLOUDFLARE_CNAME_TARGET` | **CreateCNAMERecord** (`--target`) |

Logs are written under **`Logs/`** relative to the process **working directory**. Each line is also printed to **stdout** so **systemd** stores the same text in the journal (`journalctl -u …`). Swift may emit harmless **`errno=13`** thread-priority lines to **stderr**.

---

## CloudFlareUpdater

```bash
CloudFlareUpdater \
  --zone-id ZONE_ID \
  --site example.com \
  --email you@example.com \
  --api-key GLOBAL_API_KEY
```

- **Logs:** `Logs/dns.log`, `Logs/ip.log`
- **State:** `Logs/ip4.txt` (last seen IPv4)

**Public IPv4 discovery** uses **`https://api.ipify.org`** (plain body = IP). If that fails, check **`curl -4 -sS https://api.ipify.org`** on the host.

---

## CreateCNAMERecord

```bash
CreateCNAMERecord \
  --zone-id ZONE_ID \
  --site www.example.com \
  --target example.com \
  --email you@example.com \
  --api-key GLOBAL_API_KEY
```

- **Logs:** `Logs/cname.log`
- If an **A** or **AAAA** blocks the CNAME, the tool removes only those types, then creates the CNAME (**DNS only**, `proxied: false`).

More detail: **[CNAME_SETUP.md](./CNAME_SETUP.md)**.

---

## SyncICloudMailDNS

Ensures these records exist on Cloudflare (creates or updates; does not delete unrelated TXT records):

| Type | Name | Value |
|------|------|-------|
| TXT | apex (`--domain`) | Apple personal verification (`apple-domain=…`) |
| TXT | apex | `v=spf1 include:icloud.com ~all` (override with `ICLOUD_SPF_VALUE`) |

`SyncICloudMailDNS` sends TXT values to Cloudflare wrapped in double quotes (RFC 1035). **`.env`** values stay unquoted, e.g. `apple-domain=YOUR_CODE`.
| MX | apex | `mx01.mail.icloud.com` (priority 10) |
| MX | apex | `mx02.mail.icloud.com` (priority 10) |
| CNAME | `sig1._domainkey.<domain>` | Apple DKIM target |

```bash
SyncICloudMailDNS \
  --zone-id ZONE_ID \
  --domain example.com \
  --email you@example.com \
  --api-key GLOBAL_API_KEY \
  --verification-txt "apple-domain=YOUR_CODE" \
  --dkim-target sig1.dkim.example.com.at.icloudmailadmin.com
```

Or via env (typical with **server-tower** `EnvironmentFile`):

| Variable | Required |
|----------|----------|
| `ICLOUD_MAIL_TXT_VERIFICATION` | yes |
| `ICLOUD_DKIM_TARGET` | yes |
| `ICLOUD_SPF_VALUE` | no (defaults to `v=spf1 include:icloud.com ~all`) |

- **Logs:** `Logs/icloud-mail-dns.log`
- **Cloudflare:** DKIM CNAME must stay **DNS only** (not proxied). Finish verification in [iCloud settings](https://www.icloud.com/settings) → Custom Email Domain.

---

## DocC

```bash
docc preview Sources/CloudFlareUpdater/CloudFlareUpdater.docc
docc preview Sources/CreateCNAMERecord/CreateCNAMERecord.docc
```
