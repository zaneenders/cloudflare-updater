# ``SyncICloudMailDNS``

Sync iCloud+ Custom Email Domain DNS records to Cloudflare.

## Usage

```bash
SyncICloudMailDNS \
  --zone-id abc123... \
  --domain example.com \
  --email you@example.com \
  --api-key your-global-api-key \
  --verification-txt "apple-domain=YOUR_CODE" \
  --dkim-target sig1.dkim.example.com.at.icloudmailadmin.com
```

With environment variables (recommended for systemd):

```bash
export CLOUDFLARE_ZONE_ID=abc123...
export CLOUDFLARE_EMAIL=you@example.com
export CLOUDFLARE_API_KEY=your-global-api-key
export ICLOUD_MAIL_TXT_VERIFICATION="apple-domain=YOUR_CODE"
export ICLOUD_DKIM_TARGET=sig1.dkim.example.com.at.icloudmailadmin.com

SyncICloudMailDNS --domain example.com
```

## Records created

| Type | Name | Value |
|------|------|-------|
| TXT | apex | Apple verification (`apple-domain=…`) |
| TXT | apex | `v=spf1 include:icloud.com ~all` (override with `--spf-value`) |
| MX | apex | `mx01.mail.icloud.com` (priority 10) |
| MX | apex | `mx02.mail.icloud.com` (priority 10) |
| CNAME | `sig1._domainkey.<domain>` | Apple DKIM target |

TXT values are sent wrapped in double quotes (RFC 1035). Environment variable values should stay unquoted (e.g. `apple-domain=YOUR_CODE`).

> Important: The DKIM CNAME must remain **DNS-only** (not proxied). Finish verification in [iCloud settings](https://www.icloud.com/settings) → Custom Email Domain.

## Topics

### Essentials

- ``SyncICloudMailDNS``
- ``ICloudMailDNSSync``
- ``CloudFlareConfig``

### API

- ``CloudFlareAPI``
- ``TXTRecordContent``
