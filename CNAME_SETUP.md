# CNAME helper (`CreateCNAMERecord`)

Use this when **`CloudFlareUpdater`** only maintains the **apex A** record. Subdomains (**`www`**, **`api`**, …) should be **CNAME → apex** so they track IP changes without a second updater.

## Build and install

```bash
cd /path/to/cloudflare-updater
swift build -c release --product CreateCNAMERecord
sudo cp .build/release/CreateCNAMERecord /usr/local/bin/
```

## Examples (replace placeholders)

**`api.example.com` → `example.com`** (needed for **`https://api.example.com`** with server-tower + Caddy):

```bash
CreateCNAMERecord \
  --zone-id YOUR_ZONE_ID \
  --site api.example.com \
  --target example.com \
  --email YOUR_CLOUDFLARE_EMAIL \
  --api-key YOUR_GLOBAL_API_KEY
```

**`www.example.com` → `example.com`**:

```bash
CreateCNAMERecord \
  --zone-id YOUR_ZONE_ID \
  --site www.example.com \
  --target example.com \
  --email YOUR_CLOUDFLARE_EMAIL \
  --api-key YOUR_GLOBAL_API_KEY
```

## Behavior

- If the **CNAME** is missing → **POST** create (**DNS only**, `proxied: false`).
- If it exists and already points at **`--target`** → no-op.
- If it exists but points elsewhere → **PATCH** to **`--target`**.

## Verify

```bash
dig api.example.com +short
dig www.example.com +short
```

Expect the **apex name** (often shown as **`example.com.`** in `dig` output).

## Logs

```bash
cat Logs/cname.log
```
