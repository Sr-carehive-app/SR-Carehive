// Minimal Express server to integrate Razorpay order + signature verification flow.
// NOTE: Keep key_secret ONLY on server. Do NOT expose to Flutter app.
// Start: npm install && npm start (runs on http://localhost:9090 by default)

import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import Razorpay from 'razorpay';
import https from 'https';

dotenv.config();

const app = express();
app.use(express.json());
// Configurable CORS: specify comma-separated origins in ALLOWED_ORIGINS
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '*')
  .split(',')
  .map(o => o.trim())
  .filter(o => o.length > 0);

app.use(cors({
  origin: (origin, cb) => {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) return cb(null, true);
    return cb(new Error('CORS blocked: ' + origin));
  },
  credentials: false
}));

// Config (adjust for deployment)
const PORT = process.env.PORT || 9090;

// Razorpay config
const RAZORPAY_KEY_ID = (process.env.RAZORPAY_KEY_ID || '').trim();
const RAZORPAY_KEY_SECRET = (process.env.RAZORPAY_KEY_SECRET || '').trim();
if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
  console.warn('[WARN] RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET not set. Set them in .env');
}
// Heuristic: live/test key secrets are typically ~32+ chars. If it's much shorter, it may be truncated or copied wrong.
if (RAZORPAY_KEY_SECRET && RAZORPAY_KEY_SECRET.length < 28) {
  console.warn(`[WARN] Razorpay key secret looks unusually short (len=${RAZORPAY_KEY_SECRET.length}). If you regenerated keys, ensure you saved the new Key Secret (shown once) and updated .env with the matching pair.`);
}
// Masked log to confirm keys are loaded (do not leak full keys)
if (RAZORPAY_KEY_ID) {
  const kid = RAZORPAY_KEY_ID;
  console.log(`[INIT] Razorpay key id loaded: ${kid.slice(0,4)}***${kid.slice(-4)}`);
}

const razorpay = new Razorpay({ key_id: RAZORPAY_KEY_ID || 'rzp_test_xxx', key_secret: RAZORPAY_KEY_SECRET || 'test_secret' });

// Supabase client
// Prefer service role for server-side inserts (bypasses RLS); fallback to anon for dev read-only/testing.
let supabase = null;
if (process.env.SUPABASE_URL && (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY)) {
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
  if (process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.log('[INIT] Supabase using service role key for server-side operations');
  } else {
    console.warn('[WARN] SUPABASE_SERVICE_ROLE_KEY not set. Using anon key; inserts may fail if RLS denies.');
  }
  supabase = createClient(process.env.SUPABASE_URL, supabaseKey);
}

// In-memory pending appointment store: orderId -> appointment payload (for dev only)
const pendingAppointments = new Map();

// Create Razorpay order
// Input: { amount, currency?, receipt?, notes?, appointment? }
// Output: { orderId, amount, currency, keyId }
app.post('/api/pg/razorpay/create-order', async (req, res) => {
  try {
  const { amount, currency = 'INR', receipt, notes, appointment } = req.body || {};
    if (!amount) return res.status(400).json({ error: 'amount is required (in rupees as string, e.g., "99.00")' });
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) return res.status(500).json({ error: 'Server misconfigured: Razorpay keys missing' });

    const paise = Math.round(parseFloat(amount) * 100);
    const order = await razorpay.orders.create({ amount: paise, currency, receipt, notes });

    if (appointment) {
      pendingAppointments.set(order.id, {
        ...appointment,
        order_id: order.id,
        amount: amount,
        currency,
        created_at: new Date().toISOString(),
        status: 'payment_pending'
      });
    }

    res.json({ orderId: order.id, amount: order.amount, currency: order.currency, keyId: RAZORPAY_KEY_ID });
  } catch (err) {
    // Surface Razorpay error details when available
    const status = err?.statusCode || 500;
    const description = err?.error?.description || err?.message || 'Unknown error';
    const code = err?.error?.code;
    console.error('create-order error', { statusCode: status, description, code });
    res.status(status).json({ error: 'Internal error', message: description, code });
  }
});

// Verify payment signature after checkout success
// Input: { razorpay_order_id, razorpay_payment_id, razorpay_signature }
// Output: { verified: true, details }
app.post('/api/pg/razorpay/verify', async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};
    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({ error: 'Missing fields' });
    }
    const body = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expected = crypto.createHmac('sha256', RAZORPAY_KEY_SECRET).update(body).digest('hex');
    const verified = expected === razorpay_signature;
    if (!verified) return res.status(400).json({ verified: false, error: 'Signature mismatch' });

    // Mark appointment paid and optionally persist via Supabase
    const appt = pendingAppointments.get(razorpay_order_id);
    if (appt) {
      // After payment success, mark business status as 'pending' (awaiting processing)
      appt.status = 'pending';
      appt.payment_id = razorpay_payment_id;
      if (supabase) {
        try {
          await supabase.from('appointments').insert({
            patient_id: appt.patient_id,
            full_name: appt.full_name,
            age: appt.age,
            gender: appt.gender,
            phone: appt.phone,
            address: appt.address,
            emergency_contact: appt.emergency_contact,
            date: appt.date,
            time: appt.time,
            problem: appt.problem,
            patient_type: appt.patient_type,
            duration_hours: appt.duration_hours ?? null,
            amount_rupees: appt.amount_rupees ?? null,
            status: 'pending',
            created_at: new Date().toISOString(),
            order_id: razorpay_order_id,
            payment_id: razorpay_payment_id
          });
          appt.persisted = true;
        } catch (dbErr) {
          console.error('Supabase insert failed', dbErr.message);
        }
      }
    }

    res.json({ verified: true, orderId: razorpay_order_id, paymentId: razorpay_payment_id });
  } catch (err) {
    res.status(500).json({ error: 'Internal error', message: err.message });
  }
});

// Optional: simple status endpoint for polling by orderId
app.get('/api/pg/razorpay/status/:orderId', (req, res) => {
  const appt = pendingAppointments.get(req.params.orderId);
  if (!appt) return res.status(404).json({ error: 'Not found' });
  res.json(appt);
});

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// Dev-only: quick auth check to see if Razorpay keys are valid.
// Enable by setting DEBUG_PAYMENTS=true in .env. Do not enable in production.
app.get('/api/pg/razorpay/debug-auth', async (req, res) => {
  if (process.env.DEBUG_PAYMENTS !== 'true') {
    return res.status(404).end();
  }
  try {
    const list = await razorpay.orders.all({ count: 1 });
    res.json({ ok: true, sample: Array.isArray(list?.items) ? list.items.length : 0 });
  } catch (err) {
    res.status(err?.statusCode || 500).json({ ok: false, code: err?.error?.code, message: err?.error?.description || err?.message });
  }
});

// Dev-only: reveal non-sensitive info about loaded keys (useful to verify .env parsing)
app.get('/api/pg/razorpay/debug-keyinfo', (req, res) => {
  if (process.env.DEBUG_PAYMENTS !== 'true') {
    return res.status(404).end();
  }
  const kid = RAZORPAY_KEY_ID || '';
  const masked = kid ? `${kid.slice(0,4)}***${kid.slice(-4)}` : '';
  const mode = kid.startsWith('rzp_live_') ? 'live' : (kid.startsWith('rzp_test_') ? 'test' : 'unknown');
  res.json({
    keyIdMasked: masked,
    mode,
    keySecretLength: (RAZORPAY_KEY_SECRET || '').length
  });
});

// Dev-only: raw HTTPS check to capture response headers like X-Razorpay-Request-Id
app.get('/api/pg/razorpay/debug-auth-raw', (req, res) => {
  if (process.env.DEBUG_PAYMENTS !== 'true') {
    return res.status(404).end();
  }
  const auth = Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
  const options = {
    hostname: 'api.razorpay.com',
    path: '/v1/orders?count=1',
    method: 'GET',
    headers: {
      Authorization: `Basic ${auth}`,
      'User-Agent': 'care12-debug/1.0'
    }
  };
  const reqHttps = https.request(options, (r) => {
    let data = '';
    r.on('data', (chunk) => (data += chunk));
    r.on('end', () => {
      res.status(r.statusCode || 500).json({
        statusCode: r.statusCode,
        requestId: r.headers['x-razorpay-request-id'] || r.headers['x-request-id'] || null,
        headers: {
          'x-razorpay-request-id': r.headers['x-razorpay-request-id'] || null,
          'content-type': r.headers['content-type'] || null
        },
        body: (() => { try { return JSON.parse(data); } catch { return data; } })()
      });
    });
  });
  reqHttps.on('error', (e) => res.status(500).json({ error: e.message }));
  reqHttps.end();
});

// Dev-only: validate env key formats and hidden chars (no secret exposure)
app.get('/api/pg/razorpay/debug-cred-check', (req, res) => {
  if (process.env.DEBUG_PAYMENTS !== 'true') {
    return res.status(404).end();
  }
  const kid = RAZORPAY_KEY_ID || '';
  const ks = RAZORPAY_KEY_SECRET || '';
  const keyIdRegexOk = /^rzp_(test|live)_[A-Za-z0-9]+$/.test(kid);
  const keyIdLen = kid.length;
  const keySecretLen = ks.length;
  const asciiOnly = /^[\x20-\x7E]*$/.test(ks); // printable ASCII only
  const hasWhitespace = /\s/.test(ks);
  const hasNonAlnum = /[^A-Za-z0-9]/.test(ks);
  res.json({
    keyIdRegexOk,
    keyIdLen,
    keySecretLen,
    asciiOnly,
    hasWhitespace,
    hasNonAlnum,
    mode: kid.startsWith('rzp_live_') ? 'live' : (kid.startsWith('rzp_test_') ? 'test' : 'unknown')
  });
});

app.listen(PORT, () => console.log(`Payment server (Razorpay) running on http://localhost:${PORT}`));
