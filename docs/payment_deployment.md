# PhiCommerce Return URL Deployment Guide

Goal: Move `PHI_RETURN_URL` from `http://localhost:9090/...` to a public **HTTPS** URL under your domain `srcarehive.com` so PhiCommerce (ICICI) can reach your callback.

## 1. What You Need

1. Domain DNS control for `srcarehive.com`.
2. A server / VPS (Ubuntu 22.04+ recommended) with public IPv4.
3. Ability to open ports 80 (HTTP) + 443 (HTTPS).
4. Node.js 18+ installed.
5. Optional: Supabase service key (server only) for secure DB writes.

## 2. DNS Setup

Create the following DNS record (example):

```text
Type: A
Host: api   (gives api.srcarehive.com)   OR use root / @ if you prefer
Value: <YOUR_SERVER_PUBLIC_IP>
TTL: 300 (5m)
```

Decide your final callback URL; examples:

```text
https://api.srcarehive.com/api/pg/payment-processing/PAYPHI
OR
https://srcarehive.com/api/pg/payment-processing/PAYPHI
```

Propagate (can take 5–30 min). Test:

```bash
ping api.srcarehive.com
dig +short api.srcarehive.com
```

## 3. Server Directory Structure

```text
/srv/carehive
  ├── server.js (copied from repo)
  ├── package.json
  ├── .env            (server ONLY; do not copy client .env)
```

### `.env` (server)

```env
PORT=9090
PHI_MERCHANT_ID=T_03342
PHI_SECRET=abc
PHI_RETURN_URL=https://api.srcarehive.com/api/pg/payment-processing/PAYPHI
PHI_DEFAULT_ADDL_PARAM1=14
PHI_DEFAULT_ADDL_PARAM2=15
PHI_CURRENCY_CODE=356
PHI_PAY_TYPE=0
SUPABASE_URL=...          # optional
SUPABASE_SERVICE_ROLE=... # safer than anon for inserts
ALLOWED_ORIGINS=https://srcarehive.com,https://app.srcarehive.com
```

## 4. Install & Run (Systemd)

```bash
cd /srv/carehive
npm ci   # or npm install
node server.js # test
```

Create systemd unit `/etc/systemd/system/carehive-payment.service`:

```ini
[Unit]
Description=CareHive Payment Server
After=network.target

[Service]
WorkingDirectory=/srv/carehive
Environment=NODE_ENV=production
EnvironmentFile=/srv/carehive/.env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
```

Enable & start:

```bash
systemctl daemon-reload
systemctl enable --now carehive-payment
systemctl status carehive-payment
```

## 5. Reverse Proxy with Nginx + SSL

Install:

```bash
apt update && apt install -y nginx certbot python3-certbot-nginx
```

Nginx site `/etc/nginx/sites-available/carehive.conf`:

```nginx
server {
  listen 80;
  server_name api.srcarehive.com;
  location / {
    proxy_pass http://127.0.0.1:9090;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

Enable & test:

```bash
ln -s /etc/nginx/sites-available/carehive.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

Issue certificate:

```bash
certbot --nginx -d api.srcarehive.com --redirect --agree-tos -m admin@srcarehive.com
```

After this your `PHI_RETURN_URL` becomes:

```text
https://api.srcarehive.com/api/pg/payment-processing/PAYPHI
```

## 6. Update Flutter Client

Client `.env` (bundled):

```env
API_BASE_URL=https://api.srcarehive.com
```

Rebuild the app so the new base URL is used.

## 7. Register Return URL With PhiCommerce

Provide them the exact return URL. They may whitelist domain. Ensure it matches the one in every initiateSale request.

## 8. Test Flow

1. Hit health (optional create GET /health) to confirm 200.
2. POST `/api/pg/payment/initiateSale` from local machine to new domain.
3. Receive JSON; open redirectUrl; complete test payment.
4. Confirm browser redirects back to your return URL page (simple HTML from server.js) and server logs callback.
5. Poll `/api/pg/payment/status/<merchantTxnNo>` or build STATUS call to verify success.

## 9. Security Checklist

- PHI_SECRET only on server `.env`.
- Use service role key (RLS enforced) not anon for inserting payment-confirmed records.
- Rotate secret if ever exposed.
- Restrict CORS origins (ALLOWED_ORIGINS env variable).

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Blank payment page | Missing country code or bad hash | Check canonical string + add 91 prefix to mobile. |
| Callback never hits | Return URL not public / blocked | Curl from outside, ensure 200; verify DNS & SSL. |
| Mixed content warnings | HTTP assets | Force HTTPS via `--redirect` certbot. |
| 502 in initiateSale | Gateway validation failure | Log full response body, verify field casing & values. |

## 11. Optional: Cloudflare Tunnel (No VPS Port Exposure)

Install tunnel, map `api.srcarehive.com` to `http://localhost:9090`, still need cert (Cloudflare provides edge SSL). Set `PHI_RETURN_URL` to HTTPS Cloudflare host.

---

Keep this doc updated with any environment or spec changes.
