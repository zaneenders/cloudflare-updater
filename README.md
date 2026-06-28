# cloudflare-updater

Swift CLIs for Cloudflare DNS: dynamic A records, CNAME helpers, and iCloud+ Custom Email Domain sync.

## Tools

| Binary | Purpose |
|---|---|
| `CloudFlareUpdater` | Keeps an A record pointed at your server's public IPv4 — run on a systemd timer |
| `CreateCNAMERecord` | Creates/fixes a CNAME pointing a subdomain to the apex — run once |
| `SyncICloudMailDNS` | Syncs iCloud+ Custom Email Domain records (TXT, MX, DKIM) — run daily |


## Documentation

Full documentation is built with [DocC](https://www.swift.org/documentation/docc/):

```bash
docc preview Sources/CloudFlareUpdater/CloudFlareUpdater.docc
docc preview Sources/CreateCNAMERecord/CreateCNAMERecord.docc
docc preview Sources/SyncICloudMailDNS/SyncICloudMailDNS.docc
```

## Build

```bash
swift build -c release
# Or a single product:
swift build -c release --product CloudFlareUpdater
```

