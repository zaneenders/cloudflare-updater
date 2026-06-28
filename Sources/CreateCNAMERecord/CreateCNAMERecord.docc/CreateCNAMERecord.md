# ``CreateCNAMERecord``

Create or fix a CNAME record pointing a subdomain to the apex.

## Usage

```bash
CreateCNAMERecord \
  --zone-id abc123... \
  --site www.example.com \
  --target example.com \
  --email you@example.com \
  --api-key your-global-api-key
```

With environment variables:

```bash
export CLOUDFLARE_ZONE_ID=abc123...
export CLOUDFLARE_EMAIL=you@example.com
export CLOUDFLARE_API_KEY=your-global-api-key

CreateCNAMERecord --site www.example.com --target example.com
CreateCNAMERecord --site api.example.com --target example.com
```

## Behavior

- CNAME missing → creates it (DNS-only, not proxied)
- CNAME exists and points to `--target` → no-op
- CNAME exists but points elsewhere → patches to target
- Conflicting A or AAAA records → automatically removed before creating the CNAME

## Verify

```bash
dig www.example.com +short
# → example.com.
```

## Topics

### Essentials

- ``CreateCNAMERecord``
- ``CloudFlareConfig``
- ``CloudFlareAPI``

### Logging

- ``LogLine``
