# ``CreateCNAMERecord``

Create or fix a CNAME record pointing a hostname to any target, including CloudFront and ACM validation hostnames.

## Usage

```bash
CreateCNAMERecord \
  --zone-id abc123... \
  --site www.example.com \
  --target example.com \
  --api-token "$CLOUDFLARE_API_TOKEN"
```

With environment variables:

```bash
export CLOUDFLARE_ZONE_ID=abc123...
# Load CLOUDFLARE_API_TOKEN securely into your environment.
# Scope it to Zone → DNS → Edit for this zone only.

CreateCNAMERecord --site www.example.com --target example.com
CreateCNAMERecord --site api.example.com --target example.com
```

## Behavior

- CNAME missing → creates it (DNS-only, not proxied)
- CNAME exists, points to `--target`, and is DNS-only → no-op
- CNAME exists but points elsewhere or is proxied → patches to target with proxy disabled
- Conflicting A, AAAA, or NS records → fails without deleting records
- API or network errors → nonzero exit status
- Existing TXT and MX records are preserved

Legacy `CLOUDFLARE_EMAIL` and `CLOUDFLARE_API_KEY` authentication remains supported. A token takes precedence when supplied.

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
