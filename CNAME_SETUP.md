# CNAME Record Creator

This tool creates a CNAME DNS record in Cloudflare, pointing a subdomain (e.g., `www.example.com`) to another domain (e.g., `example.com`).

## Why Use CNAME?

When running a web server with Caddy behind a dynamic IP, you typically:
1. Use `CloudFlareUpdater` to update the A record for your apex domain (e.g., `shapetree.org`)
2. Use CNAME to point subdomains (e.g., `www.shapetree.org`) to the apex domain

This approach means:
- Only the apex domain needs dynamic IP updates
- Subdomains automatically follow the apex domain's IP
- Caddy can obtain SSL certificates for both domains

## Usage

### Build the Tool

```bash
cd /path/to/cloudflare-updater
swift build --product CreateCNAMERecord
```

### Run with Command Line Arguments

```bash
.build/debug/CreateCNAMERecord \
    --zone-id YOUR_ZONE_ID \
    --site www.shapetree.org \
    --target shapetree.org \
    --email your-email@example.com \
    --api-key YOUR_API_KEY
```

### Run with Environment Variables

```bash
export CLOUDFLARE_ZONE_ID="your-zone-id"
export CLOUDFLARE_SITE="www.shapetree.org"
export CLOUDFLARE_CNAME_TARGET="shapetree.org"
export CLOUDFLARE_EMAIL="your-email@example.com"
export CLOUDFLARE_API_KEY="your-api-key"

.build/debug/CreateCNAMERecord
```

## Setup Script for shapetree.org

To set up `www.shapetree.org` as a CNAME to `shapetree.org`:

```bash
#!/bin/bash

# Configuration
ZONE_ID="dbd2eb17a3cdd4d8b590e67de904d7ed"
SITE="www.shapetree.org"
TARGET="shapetree.org"
EMAIL="fetcher-rub.0d@icloud.com"
API_KEY="932a0e081e54587c7d4831b86ddfeab5d48d5"

# Create CNAME record
/usr/local/bin/CreateCNAMERecord \
    --zone-id "$ZONE_ID" \
    --site "$SITE" \
    --target "$TARGET" \
    --email "$EMAIL" \
    --api-key "$API_KEY"
```

## Installing to /usr/local/bin

```bash
cd /path/to/cloudflare-updater
swift build -c release --product CreateCNAMERecord
sudo cp .build/release/CreateCNAMERecord /usr/local/bin/
```

## Verifying the Record

After creating the CNAME record, verify it:

```bash
# Check DNS propagation
dig www.shapetree.org +short

# Should return: shapetree.org
```

Then Caddy will automatically obtain an SSL certificate for `www.shapetree.org`.

## Complete Setup Example

For a typical server-tower setup with `shapetree.org`:

1. **Create the CNAME record (one-time setup):**
   ```bash
   CreateCNAMERecord \
       --zone-id dbd2eb17a3cdd4d8b590e67de904d7ed \
       --site www.shapetree.org \
       --target shapetree.org \
       --email fetcher-rub.0d@icloud.com \
       --api-key 932a0e081e54587c7d4831b86ddfeab5d48d5
   ```

2. **Keep cloudflare-updater running for the apex domain only:**
   ```
   # In cloudflare-updater.service, use only:
   --site shapetree.org
   ```

3. **Verify Caddy can get certificates:**
   ```bash
   sudo journalctl -u caddy.service -f
   # Should see successful certificate issuance for both domains
   ```

## Troubleshooting

### Record already exists
The tool will skip creation if a CNAME record already exists for the site.

### Check logs
View detailed logs in `Logs/cname.log`:
```bash
cat Logs/cname.log
```

### DNS not propagating
DNS changes can take time. Check:
```bash
# From multiple DNS servers
dig @8.8.8.8 www.shapetree.org +short
dig @1.1.1.1 www.shapetree.org +short
```
