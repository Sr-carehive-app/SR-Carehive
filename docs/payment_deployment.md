# Razorpay Payment Deployment Guide

Goal: Run the Node server that creates Razorpay orders and verifies payment signatures. The Flutter app opens Razorpay Checkout using the public key and sends success payloads back for verification.

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
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your_live_secret_here
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

No callback URL is needed for Razorpay Checkout (we verify via signature). Keep server accessible to mobile clients.

## 6. Update Flutter Client

Client `.env` (bundled):

```env
API_BASE_URL=https://api.srcarehive.com
```

Rebuild the app so the new base URL is used.

## 7. Razorpay Dashboard

- Generate live API keys and paste RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET into server `.env`.
- Set branding and payment methods as needed.

## 8. Test Flow

1. Hit health (optional create GET /health) to confirm 200.
2. POST `/api/pg/razorpay/create-order` with amount and notes.
3. App opens Razorpay checkout using returned keyId + orderId.
4. On success, app posts to `/api/pg/razorpay/verify` and you should see `{ verified: true }`.

## 9. Security Checklist

- Keep RAZORPAY_KEY_SECRET only on server `.env`.
- Use service role key (RLS enforced) not anon for inserting payment-confirmed records.
- Rotate secret if ever exposed.
- Restrict CORS origins (ALLOWED_ORIGINS env variable).

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Blank payment page | Missing country code or bad hash | Check canonical string + add 91 prefix to mobile. |
| Callback never hits | Return URL not public / blocked | Curl from outside, ensure 200; verify DNS & SSL. |
| Mixed content warnings | HTTP assets | Force HTTPS via `--redirect` certbot. |
| 400/500 on create-order | Invalid amount or missing keys | Ensure RAZORPAY_KEY_ID/SECRET are set and amount is numeric. |

## 11. Optional: Cloudflare Tunnel (No VPS Port Exposure)

Install tunnel, map `api.srcarehive.com` to `http://localhost:9090`, still need cert (Cloudflare provides edge SSL). No special return URL is required for Razorpay Checkout.

---

Keep this doc updated with any environment or spec changes.
