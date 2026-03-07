# ``CloudFlareUpdater``

A command-line tool to automatically update CloudFlare DNS A records with your current IP address.

## Overview

CloudFlareUpdater monitors your public IP address and automatically updates DNS A records in CloudFlare when your IP changes. This is useful for:

- Dynamic DNS setups
- Home servers with changing IP addresses
- Automated DNS management

## Features

- Automatic IP detection (IPv4 and IPv6)
- CloudFlare DNS record updates
- Detailed logging to `Logs/dns.log`
- IP address history tracking
- Environment variable or command-line configuration

## Usage

```bash
# Using environment variables
export CLOUDFLARE_ZONE_ID="your-zone-id"
export CLOUDFLARE_SITE="example.com"
export CLOUDFLARE_EMAIL="your@email.com"
export CLOUDFLARE_API_KEY="your-api-key"

CloudFlareUpdater

# Using command-line arguments
CloudFlareUpdater \
  --zoneID your-zone-id \
  --site example.com \
  --email your@email.com \
  --apiKey your-api-key
```

## Configuration

All configuration options can be provided via environment variables or command-line arguments:

| Option | Environment Variable | Description |
|--------|---------------------|-------------|
| `--zoneID` | `CLOUDFLARE_ZONE_ID` | Your CloudFlare Zone ID |
| `--site` | `CLOUDFLARE_SITE` | The domain to update (e.g., example.com) |
| `--email` | `CLOUDFLARE_EMAIL` | Your CloudFlare account email |
| `--apiKey` | `CLOUDFLARE_API_KEY` | Your CloudFlare API key |

## Topics

### Essentials

- ``CloudFlareUpdater``
- ``CloudFlareConfig``

### API Integration

- ``CloudFlareAPI``
- ``CloudFlareResponse``
- ``CloudFlareUpdateResponse``

### Utilities

- ``DNSUpdater``
- ``String`` extensions
