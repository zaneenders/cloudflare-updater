# ``CloudFlareUpdater``

Keep a Cloudflare DNS A record pointed at your server's current public IPv4.

## Usage

```bash
# All options can be CLI flags or environment variables.
CloudFlareUpdater \
  --zone-id abc123... \
  --site example.com \
  --email you@example.com \
  --api-key your-global-api-key
```

With environment variables (recommended for systemd):

```bash
export CLOUDFLARE_ZONE_ID=abc123...
export CLOUDFLARE_EMAIL=you@example.com
export CLOUDFLARE_API_KEY=your-global-api-key
export CLOUDFLARE_SITE=example.com

CloudFlareUpdater
```

## Behavior

- Fetches current public IPv4 from `api.ipify.org`
- Compares against cached IP in `Logs/ip4-example.com.txt`
- If unchanged → no-op (avoids unnecessary API calls)
- If changed → upserts the A record for `--site`

## Logs

| File | Content |
|------|---------|
| `Logs/dns-example.com.log` | API call log |
| `Logs/ip-example.com.log` | IP change history |
| `Logs/ip4-example.com.txt` | Last seen IPv4 (cache) |

All log lines also print to stdout for systemd journal capture.

## Topics

### Essentials

- ``CloudFlareUpdater``
- ``CloudFlareConfig``
- ``DNSUpdater``

### API

- ``CloudFlareAPI``
- ``CloudFlareResponse``
- ``CloudFlareUpdateResponse``
