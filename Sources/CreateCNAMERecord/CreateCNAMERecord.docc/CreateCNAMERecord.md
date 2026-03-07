# ``CreateCNAMERecord``

A command-line tool to create CNAME DNS records in CloudFlare.

## Overview

CreateCNAMERecord simplifies the creation of CNAME records in CloudFlare DNS. It checks for existing records before creating new ones to prevent duplicates.

## Features

- Create CNAME records pointing one domain to another
- Automatic duplicate detection
- Detailed logging to `Logs/cname.log`
- Environment variable or command-line configuration

## Usage

```bash
# Using environment variables
export CLOUDFLARE_ZONE_ID="your-zone-id"
export CLOUDFLARE_SITE="www.example.com"
export CLOUDFLARE_CNAME_TARGET="example.com"
export CLOUDFLARE_EMAIL="your@email.com"
export CLOUDFLARE_API_KEY="your-api-key"

CreateCNAMERecord

# Using command-line arguments
CreateCNAMERecord \
  --zoneID your-zone-id \
  --site www.example.com \
  --target example.com \
  --email your@email.com \
  --apiKey your-api-key
```

## Configuration

All configuration options can be provided via environment variables or command-line arguments:

| Option | Environment Variable | Description |
|--------|---------------------|-------------|
| `--zoneID` | `CLOUDFLARE_ZONE_ID` | Your CloudFlare Zone ID |
| `--site` | `CLOUDFLARE_SITE` | The subdomain to create (e.g., www.example.com) |
| `--target` | `CLOUDFLARE_CNAME_TARGET` | The target domain for the CNAME record |
| `--email` | `CLOUDFLARE_EMAIL` | Your CloudFlare account email |
| `--apiKey` | `CLOUDFLARE_API_KEY` | Your CloudFlare API key |

## Topics

### Essentials

- ``CreateCNAMERecord``
- ``CloudFlareConfig``

### API Integration

- ``CloudFlareAPI``
- ``CloudFlareResponse``
- ``CloudFlareUpdateResponse``

### Utilities

- ``String`` extensions
