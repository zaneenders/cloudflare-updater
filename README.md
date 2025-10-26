# CloudFlareUpdater

A Swift command-line tool to update [CloudFlare DNS records](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/list/) (A and AAAA) based on your current public IP address.

## Features

- Automatically detects IPv4 or IPv6 and updates the appropriate DNS record
- Creates DNS records if they don't exist
- Supports both command-line arguments and environment variables
- Logs operations to files

## Usage

```console
swift run CloudFlareUpdater --zone-id <zone-id> --site example.com --email your@email.com --api-key <api-key>
```

## Options

- `--zone-id`: CloudFlare Zone ID
- `--site`: Domain name to update
- `--email`: CloudFlare account email
- `--api-key`: CloudFlare Global API Key

## How it Works

1. Fetches your current public IP from CloudFlare's trace endpoint
2. Checks if an A or AAAA record exists for the site
3. Creates the record if it doesn't exist, or updates it if the IP has changed
4. Logs all operations to `Logs/dns.log`

