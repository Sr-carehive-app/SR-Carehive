// Minimal Express server to integrate Razorpay order + signature verification flow.
// NOTE: Keep key_secret ONLY on server. Do NOT expose to Flutter app.
// Start: npm install && npm start (runs on http://localhost:9090 by default)

import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import Razorpay from 'razorpay';

if (fs.existsSync('.env.server')) {
  dotenv.config({ path: '.env.server' });
} else {
  dotenv.config();
}

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
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID;
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;
if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
  console.warn('[WARN] RAZORPAY_KEY_ID/RAZORPAY_KEY_SECRET not set. Set them in .env');
}

const razorpay = new Razorpay({ key_id: RAZORPAY_KEY_ID || 'rzp_test_xxx', key_secret: RAZORPAY_KEY_SECRET || 'test_secret' });

// Supabase client (uses anon key for dev; for production use service_role secret and secure server-side RLS policies)
let supabase = null;
if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
  supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
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
    console.error('create-order error', err);
    res.status(500).json({ error: 'Internal error', message: err.message });
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
      appt.status = 'paid';
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
            status: 'paid',
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

app.listen(PORT, () => console.log(`Payment server (Razorpay) running on http://localhost:${PORT}`));
