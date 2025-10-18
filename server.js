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
import nodemailer from 'nodemailer';
import PDFDocument from 'pdfkit';
import twilio from 'twilio';

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
// appointmentId -> patientEmail (to email on approve/reject even if DB lacks column)
const appointmentEmailById = new Map();
// orderId -> appointmentId mapping when we create draft rows at order creation
const orderToAppointmentId = new Map();

// SMTP / Email setup (using env variables)
const SMTP_HOST = process.env.SMTP_HOST || '';
const SMTP_PORT = parseInt(process.env.SMTP_PORT || '587', 10);
const SMTP_USER = process.env.SMTP_USER || '';
const SMTP_PASS = process.env.SMTP_PASS || '';
const SMTP_SECURE = (process.env.SMTP_SECURE || '').toLowerCase() === 'true';
const SENDER_EMAIL = (process.env.SENDER_EMAIL || 'srcarehive@gmail.com').trim();
const SENDER_NAME = (process.env.SENDER_NAME || 'Care Hive').trim();

// Twilio SMS Configuration (SECURE - Never expose to frontend!)
const TWILIO_ACCOUNT_SID = (process.env.TWILIO_ACCOUNT_SID || '').trim();
const TWILIO_AUTH_TOKEN = (process.env.TWILIO_AUTH_TOKEN || '').trim();
const TWILIO_PHONE_NUMBER = (process.env.TWILIO_PHONE_NUMBER || '').trim();

let twilioClient = null;
if (TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_PHONE_NUMBER) {
  try {
    twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
    // Masked log - never log full credentials!
    console.log(`[INIT] Twilio SMS enabled. Number: ${TWILIO_PHONE_NUMBER.slice(0,4)}***${TWILIO_PHONE_NUMBER.slice(-4)}`);
  } catch (err) {
    console.error('[ERROR] Twilio initialization failed:', err.message);
  }
} else {
  console.warn('[WARN] Twilio credentials not set. SMS OTP disabled.');
}

let mailer = null;
if (SMTP_HOST && SMTP_USER && SMTP_PASS) {
  try {
    mailer = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: SMTP_SECURE,
      auth: { 
        user: SMTP_USER, 
        pass: SMTP_PASS 
      },
      tls: {
        rejectUnauthorized: false // For Gmail with app password
      },
      debug: true, // Enable debug logs
      logger: true // Enable logging
    });
    
    // Verify connection
    mailer.verify((error, success) => {
      if (error) {
        console.error('[ERROR] Email transport verification failed:', error.message);
      } else {
        console.log('[INIT] Email transport configured and verified successfully');
      }
    });
  } catch (e) {
    console.warn('[WARN] Failed to configure email transport:', e.message);
  }
} else {
  console.warn('[WARN] SMTP not fully configured. Set SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS to enable emails.');
}

function generateReceiptPdfBuffer({
  title = 'Payment Receipt',
  appointment = {},
  orderId,
  paymentId,
  amountRupees,
  date = new Date(),
}) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 40 });
      const chunks = [];
      doc.on('data', (d) => chunks.push(d));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      doc.fontSize(20).text('SR CareHive', { align: 'center' });
      doc.moveDown(0.3);
      doc.fontSize(14).text(title, { align: 'center' });
      doc.moveDown();
      doc.fontSize(10).text(`Date: ${new Date(date).toLocaleString()}`);
      doc.text(`Order ID: ${orderId || '-'}`);
      doc.text(`Payment ID: ${paymentId || '-'}`);
      doc.text(`Amount: ₹${amountRupees != null ? amountRupees : '-'}`);
      doc.moveDown();

      doc.fontSize(12).text('Patient / Appointment Details', { underline: true });
      const lines = [
        ['Name', appointment.full_name],
        ['Email', appointment.patient_email],
        ['Phone', appointment.phone],
        ['Gender', appointment.gender],
        ['Age', appointment.age],
        ['Type', appointment.patient_type],
        ['Date', appointment.date],
        ['Time', appointment.time],
        ['Duration (hr)', appointment.duration_hours],
        ['Amount (₹)', appointment.amount_rupees],
        ['Address', appointment.address],
        ['Emergency Contact', appointment.emergency_contact],
        ['Problem', appointment.problem],
      ];
      doc.moveDown(0.5);
      lines.forEach(([k, v]) => doc.fontSize(10).text(`${k}: ${v == null || String(v).trim() === '' ? '-' : v}`));

      doc.end();
    } catch (e) {
      reject(e);
    }
  });
}

async function sendEmail({ to, subject, html, attachments = [] }) {
  if (!mailer) {
    console.warn('[EMAIL] Transport not configured. Skipping send to', to);
    return { skipped: true };
  }
  const from = `${SENDER_NAME} <${SENDER_EMAIL}>`;
  return mailer.sendMail({ from, to, subject, html, attachments });
}

async function sendPaymentEmails({ appointment, orderId, paymentId, amount }) {
  try {
    const amountRupees = appointment?.amount_rupees ?? (typeof amount === 'number' ? Math.round(amount / 100) : null);
    const pdf = await generateReceiptPdfBuffer({
      title: 'Payment Receipt',
      appointment,
      orderId,
      paymentId,
      amountRupees,
    });
    const attach = [{ filename: `receipt_${orderId}.pdf`, content: pdf }];

    const patientEmail = appointment?.patient_email;
    const subject = 'Your Care Hive payment confirmation';
    const html = `
      <div>
        <p>Hi ${appointment?.full_name || 'Patient'},</p>
        <p>We received your payment and scheduled request. Your appointment is now pending assignment.</p>
        <ul>
          <li><b>Order ID:</b> ${orderId}</li>
          <li><b>Payment ID:</b> ${paymentId}</li>
          <li><b>Amount:</b> ₹${amountRupees ?? '-'}</li>
          <li><b>Date/Time:</b> ${appointment?.date || '-'} ${appointment?.time || ''}</li>
          <li><b>Duration:</b> ${appointment?.duration_hours ?? '-'} hr</li>
        </ul>
        <p>Receipt attached.</p>
        <p>— Care Hive</p>
      </div>`;

    if (patientEmail) await sendEmail({ to: patientEmail, subject, html, attachments: attach });
    // Send to admin/sender as well
    await sendEmail({ to: SENDER_EMAIL, subject: `[Admin Copy] ${subject}`, html, attachments: attach });
  } catch (e) {
    console.error('[EMAIL] payment emails failed', e.message);
  }
}

async function sendApprovalEmail(appointment) {
  try {
    const to = appointment?.patient_email || null;
    if (!to) return;
    // Generate receipt if payment is present
    let attachments = [];
    if (appointment?.payment_id || appointment?.order_id) {
      try {
        const pdf = await generateReceiptPdfBuffer({
          title: 'Payment Receipt',
          appointment,
          orderId: appointment.order_id,
          paymentId: appointment.payment_id,
          amountRupees: appointment.amount_rupees,
        });
        attachments.push({ filename: `receipt_${appointment.order_id || 'payment'}.pdf`, content: pdf });
      } catch (e) { console.warn('[WARN] approval receipt gen failed', e.message); }
    }
    const html = `
      <div>
        <p>Hi ${appointment.full_name || 'Patient'},</p>
        <p>Your nurse request has been <b>approved</b>.</p>
        <p><b>Assigned Nurse Details</b></p>
        <ul>
          <li><b>Name:</b> ${appointment.nurse_name || '-'}</li>
          <li><b>Phone:</b> ${appointment.nurse_phone || '-'}</li>
          <li><b>Branch:</b> ${appointment.nurse_branch || '-'}</li>
          <li><b>Comments:</b> ${appointment.nurse_comments || '-'}</li>
          <li><b>Available:</b> ${appointment.nurse_available ? 'Yes' : 'No'}</li>
        </ul>
        <p><b>Appointment</b>: ${appointment.date || '-'} ${appointment.time || ''} • ${appointment.duration_hours ?? '-'} hr</p>
        <p>— SR CareHive</p>
      </div>`;
    await sendEmail({ to, subject: 'Your nurse appointment is approved', html, attachments });
  } catch (e) {
    console.error('[EMAIL] approve email failed', e.message);
  }
}

async function sendRejectionEmail(appointment) {
  try {
    const to = appointment?.patient_email || null;
    if (!to) return;
    // Optionally attach receipt as well
    let attachments = [];
    if (appointment?.payment_id || appointment?.order_id) {
      try {
        const pdf = await generateReceiptPdfBuffer({
          title: 'Payment Receipt',
          appointment,
          orderId: appointment.order_id,
          paymentId: appointment.payment_id,
          amountRupees: appointment.amount_rupees,
        });
        attachments.push({ filename: `receipt_${appointment.order_id || 'payment'}.pdf`, content: pdf });
      } catch (e) { console.warn('[WARN] rejection receipt gen failed', e.message); }
    }
    const html = `
      <div>
        <p>Hi ${appointment.full_name || 'Patient'},</p>
        <p>We’re sorry to inform you that your nurse request was <b>rejected</b> at this time.</p>
        <p><b>Reason:</b> ${appointment.rejection_reason || '-'}</p>
        <p>— Care Hive</p>
      </div>`;
    await sendEmail({ to, subject: 'Your nurse appointment was rejected', html, attachments });
  } catch (e) {
    console.error('[EMAIL] reject email failed', e.message);
  }
}

// --- Nurse admin auth (env-based) ---
// We issue a short-lived bearer token kept in memory. No credentials leaked to client code.
const nurseSessions = new Map(); // token -> { createdAt }
const NURSE_EMAIL = (process.env.NURSE_ADMIN_EMAIL || '').trim().toLowerCase();
const NURSE_PASSWORD = (process.env.NURSE_ADMIN_PASSWORD || '').trim();
const SESSION_TTL_MS = 12 * 60 * 60 * 1000; // 12h

function createSession() {
  const token = crypto.randomBytes(32).toString('hex');
  nurseSessions.set(token, { createdAt: Date.now() });
  return token;
}

function isAuthed(req) {
  const h = req.headers['authorization'] || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return false;
  const rec = nurseSessions.get(token);
  if (!rec) return false;
  if (Date.now() - rec.createdAt > SESSION_TTL_MS) {
    nurseSessions.delete(token);
    return false;
  }
  return true;
}

app.post('/api/nurse/login', (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
    if (!NURSE_EMAIL || !NURSE_PASSWORD) return res.status(500).json({ error: 'Server nurse creds not configured' });
    if (email.toLowerCase() === NURSE_EMAIL && password === NURSE_PASSWORD) {
      const token = createSession();
      return res.json({ success: true, token });
    }
    return res.status(401).json({ success: false, error: 'Invalid credentials' });
  } catch (e) {
    res.status(500).json({ error: 'Internal error' });
  }
});

// List all appointments (admin view). Protected.
app.get('/api/nurse/appointments', async (req, res) => {
  try {
    if (!isAuthed(req)) return res.status(401).json({ error: 'Unauthorized' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });
    const { data, error } = await supabase
      .from('appointments')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) return res.status(500).json({ error: error.message });
    res.json({ items: data || [] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Approve appointment with assignment details. Protected.
app.post('/api/nurse/appointments/:id/approve', async (req, res) => {
  try {
    if (!isAuthed(req)) return res.status(401).json({ error: 'Unauthorized' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });
    const id = String(req.params.id);
    if (!id || id.length < 10) return res.status(400).json({ error: 'Invalid id' });
    const {
      nurse_name,
      nurse_phone,
      nurse_branch,
      nurse_comments,
      available,
    } = req.body || {};

    const payload = {
      status: 'approved',
      nurse_name: nurse_name || null,
      nurse_phone: nurse_phone || null,
      nurse_branch: nurse_branch || null,
      nurse_comments: nurse_comments || null,
      nurse_available: !!available,
      approved_at: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from('appointments')
      .update(payload)
      .eq('id', id)
      .select()
      .maybeSingle();
    if (error) return res.status(500).json({ error: error.message });
    // Send email to patient if we know email
    try {
      const enriched = { ...(data || {}), patient_email: data?.patient_email || appointmentEmailById.get(id) || null };
      await sendApprovalEmail(enriched);
    } catch (e) {
      console.warn('[WARN] approve email skipped/failed:', e.message);
    }
    res.json({ success: true, item: data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Reject appointment with reason. Protected.
app.post('/api/nurse/appointments/:id/reject', async (req, res) => {
  try {
    if (!isAuthed(req)) return res.status(401).json({ error: 'Unauthorized' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });
    const id = String(req.params.id);
    if (!id || id.length < 10) return res.status(400).json({ error: 'Invalid id' });
    const { reason } = req.body || {};
    const payload = {
      status: 'rejected',
      rejection_reason: reason || null,
      rejected_at: new Date().toISOString(),
    };
    const { data, error } = await supabase
      .from('appointments')
      .update(payload)
      .eq('id', id)
      .select()
      .maybeSingle();
    if (error) return res.status(500).json({ error: error.message });
    // Email patient about rejection
    try {
      const enriched = { ...(data || {}), patient_email: data?.patient_email || appointmentEmailById.get(id) || null };
      await sendRejectionEmail(enriched);
    } catch (e) {
      console.warn('[WARN] reject email skipped/failed:', e.message);
    }
    res.json({ success: true, item: data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

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

      // Persist a draft row immediately so we don't depend on memory
      if (supabase) {
        try {
          const baseDraft = {
            patient_id: appointment.patient_id || null,
            full_name: appointment.full_name || null,
            age: appointment.age ?? null,
            gender: appointment.gender || null,
            phone: appointment.phone || null,
            address: appointment.address || null,
            emergency_contact: appointment.emergency_contact || null,
            date: appointment.date || null,
            time: appointment.time || null,
            problem: appointment.problem || null,
            patient_type: appointment.patient_type || null,
            duration_hours: appointment.duration_hours ?? null,
            amount_rupees: appointment.amount_rupees ?? null,
            patient_email: appointment.patient_email || appointment.email || null,
            status: 'payment_initiated',
            created_at: new Date().toISOString(),
            order_id: order.id,
          };
          const { data: d1, error: e1 } = await supabase.from('appointments').insert(baseDraft).select().maybeSingle();
          if (!e1 && d1?.id) {
            orderToAppointmentId.set(order.id, String(d1.id));
            if (baseDraft.patient_email) appointmentEmailById.set(String(d1.id), baseDraft.patient_email);
          }
        } catch (e) {
          console.warn('[WARN] draft appointment insert failed:', e.message);
        }
      }
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
  let appt = pendingAppointments.get(razorpay_order_id);
  if (appt) {
      // After payment success, mark business status as 'pending' (awaiting processing)
      appt.status = 'pending';
      appt.payment_id = razorpay_payment_id;
      if (supabase) {
        try {
          const updatePayload = {
            status: 'pending',
            payment_id: razorpay_payment_id,
          };
          let dbAppt = null;
          const draftId = orderToAppointmentId.get(razorpay_order_id) || null;
          if (draftId) {
            const { data: u1, error: e1 } = await supabase
              .from('appointments')
              .update(updatePayload)
              .eq('id', draftId)
              .select()
              .maybeSingle();
            if (!e1) dbAppt = u1;
          }
          if (!dbAppt) {
            // Try update by order_id (in case mapping lost)
            const { data: u2, error: e2 } = await supabase
              .from('appointments')
              .update(updatePayload)
              .eq('order_id', razorpay_order_id)
              .select()
              .maybeSingle();
            if (!e2) dbAppt = u2;
          }
          if (!dbAppt) {
            // Final fallback: insert a fresh row as before
            const basePayload = {
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
              payment_id: razorpay_payment_id,
              patient_email: appt.patient_email || appt.email || null,
            };
            const { data: d3, error: e3 } = await supabase.from('appointments').insert(basePayload).select().maybeSingle();
            if (!e3) {
              dbAppt = d3;
              if (dbAppt?.id && basePayload.patient_email) appointmentEmailById.set(String(dbAppt.id), basePayload.patient_email);
            }
          }
          appt.persisted = true;

          // Send payment emails using DB row if present (has IDs), else fallback to appt object
          try {
            const emailAppt = dbAppt || { ...appt, order_id: razorpay_order_id, payment_id: razorpay_payment_id };
            await sendPaymentEmails({ appointment: emailAppt, orderId: razorpay_order_id, paymentId: razorpay_payment_id, amount: null });
          } catch (e) {
            console.warn('[WARN] payment email skipped/failed:', e.message);
          }
        } catch (dbErr) {
          console.error('Supabase insert failed', dbErr.message);
        }
      }
    }
    // Fallback: if no in-memory appointment (server restart), at least upsert a minimal record so patient sees it
    else if (supabase) {
      try {
        const { data: d4 } = await supabase.from('appointments').insert({
          status: 'pending',
          created_at: new Date().toISOString(),
          order_id: razorpay_order_id,
          payment_id: razorpay_payment_id
        }).select().maybeSingle();
        try {
          const emailAppt = d4 || { order_id: razorpay_order_id, payment_id: razorpay_payment_id };
          await sendPaymentEmails({ appointment: emailAppt, orderId: razorpay_order_id, paymentId: razorpay_payment_id, amount: null });
        } catch (e) { console.warn('[WARN] payment email skipped/failed:', e.message); }
      } catch (e) {
        console.error('Supabase fallback insert failed', e.message);
      }
    }

    res.json({ verified: true, orderId: razorpay_order_id, paymentId: razorpay_payment_id });
  } catch (err) {
    console.error('verify error', err.message);
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

// Archive past appointments into appointments_history table (manual trigger). Protected.
app.post('/api/nurse/appointments/archive-past', async (req, res) => {
  try {
    if (!isAuthed(req)) return res.status(401).json({ error: 'Unauthorized' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });
    // We treat 'past' strictly by date+optional time in IST; logic implemented in app already.
    // For server side: archive appointments whose date < today (IST) OR date = today and time earlier than now.
    // Supabase SQL function would be more precise; here we pull limited batch to avoid heavy operations.
    const { data: all, error: listErr } = await supabase.from('appointments').select('*').order('date', { ascending: true }).limit(5000);
    if (listErr) return res.status(500).json({ error: listErr.message });
    const nowUtc = new Date();
    const nowIst = new Date(nowUtc.getTime() + (5.5 * 60 * 60 * 1000));
    const todayIstStr = nowIst.toISOString().slice(0,10);
    const toArchive = [];
    for (const a of (all || [])) {
      if (!a.date) continue;
      try {
        const d = new Date(a.date + 'T00:00:00Z');
        let hour = 0, minute = 0;
        if (a.time) {
          const m = String(a.time).match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
          if (m) {
            hour = parseInt(m[1]);
            minute = parseInt(m[2]);
            const ap = m[3].toUpperCase();
            if (ap === 'PM' && hour < 12) hour += 12;
            if (ap === 'AM' && hour === 12) hour = 0;
          }
        }
        const istDateTime = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), hour, minute));
        const istMs = istDateTime.getTime() + (5.5 * 60 * 60 * 1000);
        const finalIst = new Date(istMs);
        if (finalIst < nowIst) toArchive.push(a);
      } catch {}
    }
    if (!toArchive.length) return res.json({ archived: 0 });
    // Insert into history table then delete original (soft archival)
    const rows = toArchive.map(a => ({
      original_appointment_id: a.id,
      full_name: a.full_name,
      patient_email: a.patient_email,
      phone: a.phone,
      gender: a.gender,
      age: a.age,
      patient_type: a.patient_type,
      date: a.date,
      time: a.time,
      duration_hours: a.duration_hours,
      amount_rupees: a.amount_rupees,
      status: a.status,
      order_id: a.order_id,
      payment_id: a.payment_id,
      nurse_name: a.nurse_name,
      nurse_phone: a.nurse_phone,
      nurse_branch: a.nurse_branch,
      nurse_comments: a.nurse_comments,
      nurse_available: a.nurse_available,
      rejection_reason: a.rejection_reason,
      created_at: a.created_at,
      approved_at: a.approved_at,
      rejected_at: a.rejected_at,
      archived_at: new Date().toISOString(),
    }));
    const { error: insErr } = await supabase.from('appointments_history').insert(rows);
    if (insErr) return res.status(500).json({ error: insErr.message });
    // Delete originals in small batches
    for (const a of toArchive) {
      await supabase.from('appointments').delete().eq('id', a.id);
    }
    res.json({ archived: toArchive.length });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Query history with optional status filter. Protected.
app.get('/api/nurse/appointments/history', async (req, res) => {
  try {
    if (!isAuthed(req)) return res.status(401).json({ error: 'Unauthorized' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });
    const status = (req.query.status || '').toString().trim().toLowerCase();
    let query = supabase.from('appointments_history').select('*').order('date', { ascending: false });
    if (status && ['pending','approved','rejected'].includes(status)) {
      query = query.eq('status', status);
    }
    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    res.json({ items: data || [] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Dev-only: quick email test to verify SMTP works. Enable with DEBUG_PAYMENTS=true
app.get('/api/email/test', async (req, res) => {
  if (process.env.DEBUG_PAYMENTS !== 'true') return res.status(404).end();
  try {
    const to = (req.query?.to || SENDER_EMAIL || '').toString();
    if (!to) return res.status(400).json({ error: 'Provide ?to=email@example.com' });
    const info = await sendEmail({
      to,
      subject: 'Care Hive email test',
      html: '<p>This is a test email from Care Hive server. SMTP is working ✅</p>'
    });
    res.json({ ok: true, to, messageId: info?.messageId || null });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
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

// Support: payment query submission (refund/issue). Stores in Supabase and emails admin.
app.post('/api/support/payment-query', async (req, res) => {
  try {
    const { payment_id, name, email, mobile, amount, complaint, reason, transaction_date } = req.body || {};
    if (!payment_id || !name || !email) return res.status(400).json({ error: 'payment_id, name and email are required' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });

    const row = {
      payment_id: String(payment_id),
      name: String(name),
      email: String(email),
      mobile: mobile ? String(mobile) : null,
      amount: (amount == null || amount === '') ? null : Number(amount),
      complaint: complaint ? String(complaint) : null,
      reason: reason || null,
      transaction_date: transaction_date || null,
      created_at: new Date().toISOString(),
    };
    const { data, error } = await supabase.from('payment_queries').insert(row).select().maybeSingle();
    if (error) return res.status(500).json({ error: error.message });

    // Email admin with a dashboard link button
    const mode = (RAZORPAY_KEY_ID || '').startsWith('rzp_live_') ? 'live' : 'test';
    const paymentUrl = payment_id ? `https://dashboard.razorpay.com/app/payments/${payment_id}` : 'https://dashboard.razorpay.com/app/payments';
    const searchUrl = payment_id ? `https://dashboard.razorpay.com/app/search?q=${encodeURIComponent(payment_id)}` : 'https://dashboard.razorpay.com/app/search';
    const html = `
      <div>
        <p><b>New Payment Query</b> (${mode} mode)</p>
        <ul>
          <li><b>Payment ID:</b> ${payment_id}</li>
          <li><b>Name:</b> ${name}</li>
          <li><b>Email:</b> ${email}</li>
          <li><b>Mobile:</b> ${mobile || '-'}</li>
          <li><b>Amount:</b> ${amount != null && amount !== '' ? '₹' + amount : '-'}</li>
          <li><b>Complaint:</b> ${complaint || '-'}</li>
          <li><b>Reason:</b> ${reason || '-'}</li>
          <li><b>Transaction Date:</b> ${transaction_date ? new Date(transaction_date).toLocaleDateString() : '-'}</li>
          <li><b>Recorded at:</b> ${new Date().toLocaleString()}</li>
        </ul>
        <p>
          <a href="${paymentUrl}" style="display:inline-block;background:#2260FF;color:#fff;padding:10px 14px;border-radius:6px;text-decoration:none">Open Razorpay</a>
          <a href="${searchUrl}" style="display:inline-block;margin-left:8px;color:#2260FF;text-decoration:none">Search by ID</a>
        </p>
      </div>`;
    try {
      await sendEmail({ to: SENDER_EMAIL, subject: 'New Payment Query Received', html });
    } catch (e) {
      console.warn('[WARN] payment-query email failed:', e.message);
    }

    // Optional ack to user (non-blocking)
    try {
      await sendEmail({ to: email, subject: 'We received your payment query', html: '<p>Thanks! Our team will review and get back to you shortly.</p>' });
    } catch {}

    res.json({ success: true, item: data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// OTP Email endpoint
app.post('/api/send-otp-email', async (req, res) => {
  try {
    const { email, otp } = req.body;
    
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    if (!mailer) {
      console.error('[ERROR] Email mailer not configured');
      return res.status(500).json({ error: 'Email service not configured' });
    }

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: #2260FF; padding: 20px; text-align: center;">
          <h1 style="color: white; margin: 0;">SERECHI</h1>
          <p style="color: white; margin: 5px 0;">by SR CareHive Pvt. Ltd.</p>
        </div>
        <div style="padding: 30px; background: #f9f9f9;">
          <h2 style="color: #333;">Your Verification Code</h2>
          <p style="color: #666; font-size: 16px;">Please use the following OTP to complete your registration:</p>
          <div style="background: white; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
            <h1 style="color: #2260FF; font-size: 36px; letter-spacing: 8px; margin: 0;">${otp}</h1>
          </div>
          <p style="color: #666;">This code is valid for <strong>2 minutes</strong>.</p>
          <p style="color: #666;">If you didn't request this code, please ignore this email.</p>
        </div>
        <div style="background: #333; padding: 15px; text-align: center; color: #999; font-size: 12px;">
          <p style="margin: 0;">© 2025 SR CareHive Pvt. Ltd. All rights reserved.</p>
          <p style="margin: 5px 0;">Compassionate Care, Connected Community</p>
        </div>
      </div>
    `;

    console.log(`[INFO] Sending OTP email to: ${email}`);
    
    await sendEmail({
      to: email,
      subject: 'SERECHI - Your Verification Code',
      html
    });

    console.log(`[SUCCESS] OTP email sent to: ${email}`);
    res.json({ success: true, message: 'OTP sent successfully' });
  } catch (e) {
    console.error('[ERROR] send-otp-email:', e);
    res.status(500).json({ 
      error: 'Failed to send OTP email',
      details: e.message 
    });
  }
});

// SMS OTP endpoint (SECURE - Backend only!)
app.post('/api/send-otp-sms', async (req, res) => {
  try {
    const { phone, otp } = req.body;
    
    if (!phone || !otp) {
      return res.status(400).json({ error: 'Phone number and OTP are required' });
    }

    if (!twilioClient) {
      console.error('[ERROR] Twilio SMS not configured');
      return res.status(500).json({ error: 'SMS service not configured' });
    }

    // Format phone number (ensure +country code)
    let formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      // Default to India if no country code
      formattedPhone = `+91${formattedPhone}`;
    }

    // Security: Validate phone number format
    const phoneRegex = /^\+[1-9]\d{1,14}$/;
    if (!phoneRegex.test(formattedPhone)) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }

    const message = `SERECHI Verification: Your OTP is ${otp}. Valid for 2 minutes. DO NOT share this code with anyone.`;

    console.log(`[INFO] Sending SMS OTP to: ${formattedPhone.slice(0,6)}***${formattedPhone.slice(-4)}`);
    
    const result = await twilioClient.messages.create({
      body: message,
      from: TWILIO_PHONE_NUMBER,
      to: formattedPhone
    });

    console.log(`[SUCCESS] SMS sent. SID: ${result.sid}`);
    res.json({ 
      success: true, 
      message: 'SMS sent successfully',
      messageSid: result.sid 
    });
  } catch (e) {
    console.error('[ERROR] send-otp-sms:', e);
    res.status(500).json({ 
      error: 'Failed to send SMS',
      details: e.message 
    });
  }
});

// ============================================
// PAYMENT NOTIFICATION ENDPOINTS (3-Tier System)
// ============================================

// 1. Registration Payment Notification (₹100)
app.post('/api/notify-registration-payment', async (req, res) => {
  try {
    const { 
      appointmentId, 
      patientEmail, 
      patientName, 
      patientPhone,
      nurseEmail,
      nurseName,
      paymentId, 
      receiptId, 
      amount,
      date,
      time
    } = req.body;

    if (!appointmentId || !patientEmail || !paymentId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    console.log(`[INFO] Sending registration payment notification for appointment #${appointmentId}`);

    // Email to Patient
    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4acc 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">✅ Registration Successful!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Patient'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your registration payment of <strong style="color: #2260FF; font-size: 18px;">₹${amount || 100}</strong> has been received successfully! 🎉
          </p>

          <div style="background: #e8f4ff; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2260FF;">
            <h3 style="margin-top: 0; color: #2260FF;">📋 Appointment Details</h3>
            <p style="margin: 5px 0;"><strong>Appointment ID:</strong> #${appointmentId}</p>
            <p style="margin: 5px 0;"><strong>Date:</strong> ${date || 'To be confirmed'}</p>
            <p style="margin: 5px 0;"><strong>Time:</strong> ${time || 'To be confirmed'}</p>
            <p style="margin: 5px 0;"><strong>Payment ID:</strong> ${paymentId}</p>
            ${receiptId ? `<p style="margin: 5px 0;"><strong>Receipt ID:</strong> ${receiptId}</p>` : ''}
          </div>

          <div style="background: #fff3cd; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107; margin: 20px 0;">
            <h4 style="margin-top: 0; color: #856404;">🔔 What Happens Next?</h4>
            <ol style="color: #856404; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
              <li>Our care provider will contact you shortly to confirm appointment details</li>
              <li>They will assess your needs and set the total service amount</li>
              <li>You'll be notified when the total amount is ready</li>
              <li>Payment will be split: 50% before visit, 50% after successful completion</li>
            </ol>
          </div>

          <div style="background: #d4edda; padding: 15px; border-radius: 8px; border-left: 4px solid #28a745; margin: 20px 0;">
            <p style="margin: 0; color: #155724;">
              <strong>✅ Your booking is now confirmed!</strong> We'll keep you updated via email and SMS.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="http://localhost:5173/patient/appointments" 
               style="display: inline-block; background: #2260FF; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">
              View My Appointments
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
            This is an automated email from SR CareHive. Please do not reply to this email.
            <br>Need help? Contact us at srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    // Email to Nurse/Admin
    const nurseHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #2260FF;">💰 New Registration Payment Received</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Patient:</strong> ${patientName || 'N/A'} (${patientPhone || 'N/A'})</p>
          <p><strong>Email:</strong> ${patientEmail}</p>
          <p><strong>Amount Paid:</strong> ₹${amount || 100}</p>
          <p><strong>Payment ID:</strong> ${paymentId}</p>
          <p><strong>Date:</strong> ${date || 'N/A'}</p>
          <p><strong>Time:</strong> ${time || 'N/A'}</p>
        </div>
        <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 0; color: #856404;">
            <strong>⏭️ Next Action:</strong> Please contact the patient and set the total service amount in the nurse dashboard.
          </p>
        </div>
        <a href="http://localhost:5173/nurse/manage-appointments" 
           style="display: inline-block; background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin-top: 10px;">
          Manage Appointments
        </a>
      </div>
    `;

    // Send emails
    const emailPromises = [
      sendEmail({ 
        to: patientEmail, 
        subject: `✅ Registration Payment Successful - Appointment #${appointmentId}`, 
        html: patientHtml 
      })
    ];

    if (nurseEmail) {
      emailPromises.push(
        sendEmail({ 
          to: nurseEmail, 
          subject: `💰 Registration Payment Received - Appointment #${appointmentId}`, 
          html: nurseHtml 
        })
      );
    }

    // Send SMS to patient
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `CareHive: Registration payment ₹${amount || 100} received! Appointment #${appointmentId}. Our care provider will contact you soon. Check email for details.`,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Registration SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }

    await Promise.all(emailPromises);
    console.log(`[SUCCESS] Registration payment notifications sent for appointment #${appointmentId}`);

    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-registration-payment:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});

// 2. Amount Set Notification (Nurse sets total amount)
app.post('/api/notify-amount-set', async (req, res) => {
  try {
    const { 
      appointmentId, 
      patientEmail, 
      patientName,
      patientPhone,
      totalAmount,
      nurseRemarks,
      nurseName,
      date,
      time
    } = req.body;

    if (!appointmentId || !patientEmail || !totalAmount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const preAmount = (totalAmount / 2).toFixed(2);
    const finalAmount = (totalAmount / 2).toFixed(2);

    console.log(`[INFO] Sending amount-set notification for appointment #${appointmentId}, total: ₹${totalAmount}`);

    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #9c27b0 0%, #7b1fa2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">💰 Service Amount Set</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Patient'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Our care provider has assessed your requirements and set the total service amount for your appointment.
          </p>

          <div style="background: #f3e5f5; padding: 25px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #9c27b0; text-align: center;">
            <h3 style="margin: 0 0 10px 0; color: #9c27b0;">Total Service Amount</h3>
            <p style="font-size: 36px; font-weight: bold; color: #7b1fa2; margin: 0;">₹${totalAmount}</p>
            <p style="color: #666; margin: 10px 0 0 0; font-size: 14px;">(Registration ₹100 already paid)</p>
          </div>

          ${nurseRemarks ? `
          <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #4caf50;">
            <h4 style="margin-top: 0; color: #2e7d32;">📝 Service Breakdown</h4>
            <p style="color: #2e7d32; margin: 0; white-space: pre-wrap;">${nurseRemarks}</p>
          </div>
          ` : ''}

          <div style="background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
            <h4 style="margin-top: 0; color: #856404;">💳 Payment Schedule</h4>
            <div style="display: flex; justify-content: space-between; margin: 15px 0; padding: 15px; background: white; border-radius: 6px;">
              <div style="text-align: center; flex: 1;">
                <p style="color: #666; margin: 0; font-size: 12px;">BEFORE VISIT (50%)</p>
                <p style="font-size: 24px; font-weight: bold; color: #9c27b0; margin: 5px 0;">₹${preAmount}</p>
              </div>
              <div style="border-left: 2px dashed #ddd; margin: 0 10px;"></div>
              <div style="text-align: center; flex: 1;">
                <p style="color: #666; margin: 0; font-size: 12px;">AFTER VISIT (50%)</p>
                <p style="font-size: 24px; font-weight: bold; color: #4caf50; margin: 5px 0;">₹${finalAmount}</p>
              </div>
            </div>
          </div>

          <div style="background: #e3f2fd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2196f3;">
            <p style="margin: 0; color: #1565c0;">
              <strong>ℹ️ Next Step:</strong> Please pay ₹${preAmount} before your scheduled appointment to confirm your booking.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="http://localhost:5173/patient/appointments" 
               style="display: inline-block; background: #9c27b0; color: white; padding: 14px 40px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px;">
              Pay Now (₹${preAmount})
            </a>
          </div>

          <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h4 style="margin-top: 0;">📋 Appointment Details</h4>
            <p style="margin: 5px 0;"><strong>Appointment ID:</strong> #${appointmentId}</p>
            <p style="margin: 5px 0;"><strong>Date:</strong> ${date || 'To be confirmed'}</p>
            <p style="margin: 5px 0;"><strong>Time:</strong> ${time || 'To be confirmed'}</p>
            ${nurseName ? `<p style="margin: 5px 0;"><strong>Care Provider:</strong> ${nurseName}</p>` : ''}
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
            Need clarification on the service charges? Please contact your care provider.
            <br>SR CareHive | srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    await sendEmail({ 
      to: patientEmail, 
      subject: `💰 Service Amount Set - ₹${totalAmount} | Appointment #${appointmentId}`, 
      html: patientHtml 
    });

    // Send SMS
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `CareHive: Service amount set ₹${totalAmount} for appointment #${appointmentId}. Pay ₹${preAmount} (50%) before visit. Login to pay now.`,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Amount-set SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }

    console.log(`[SUCCESS] Amount-set notifications sent for appointment #${appointmentId}`);
    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-amount-set:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});

// 3. Pre-Visit Payment Notification
app.post('/api/notify-pre-payment', async (req, res) => {
  try {
    const { 
      appointmentId, 
      patientEmail, 
      patientName,
      patientPhone,
      nurseEmail,
      nurseName,
      amount,
      paymentId,
      receiptId,
      totalAmount,
      date,
      time
    } = req.body;

    if (!appointmentId || !patientEmail || !amount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const finalAmount = (totalAmount / 2).toFixed(2);

    console.log(`[INFO] Sending pre-payment notification for appointment #${appointmentId}`);

    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #3f51b5 0%, #303f9f 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">✅ Pre-Visit Payment Successful!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Patient'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your pre-visit payment of <strong style="color: #3f51b5; font-size: 18px;">₹${amount}</strong> has been received successfully! 🎉
          </p>

          <div style="background: #e8eaf6; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3f51b5;">
            <h3 style="margin-top: 0; color: #3f51b5;">💳 Payment Details</h3>
            <p style="margin: 5px 0;"><strong>Payment ID:</strong> ${paymentId}</p>
            ${receiptId ? `<p style="margin: 5px 0;"><strong>Receipt ID:</strong> ${receiptId}</p>` : ''}
            <p style="margin: 5px 0;"><strong>Amount Paid:</strong> ₹${amount}</p>
            <p style="margin: 5px 0;"><strong>Remaining:</strong> ₹${finalAmount} (payable after visit)</p>
          </div>

          <div style="background: #d4edda; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #28a745;">
            <h4 style="margin-top: 0; color: #155724;">🎯 You're All Set!</h4>
            <p style="color: #155724; margin: 10px 0;">Your appointment is confirmed. Our care provider will visit you as scheduled.</p>
            <div style="background: white; padding: 15px; border-radius: 6px; margin-top: 15px;">
              <p style="margin: 5px 0;"><strong>📅 Date:</strong> ${date || 'To be confirmed'}</p>
              <p style="margin: 5px 0;"><strong>🕐 Time:</strong> ${time || 'To be confirmed'}</p>
              ${nurseName ? `<p style="margin: 5px 0;"><strong>👨‍⚕️ Care Provider:</strong> ${nurseName}</p>` : ''}
            </div>
          </div>

          <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
            <p style="margin: 0; color: #856404;">
              <strong>💡 Remember:</strong> The remaining ₹${finalAmount} is payable after successful completion of your service.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="http://localhost:5173/patient/appointments" 
               style="display: inline-block; background: #3f51b5; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">
              View Appointment Details
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
            SR CareHive | srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    const nurseHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #3f51b5;">✅ Pre-Visit Payment Received</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Patient:</strong> ${patientName || 'N/A'}</p>
          <p><strong>Pre-Payment:</strong> ₹${amount} (50%)</p>
          <p><strong>Remaining:</strong> ₹${finalAmount} (payable after visit)</p>
          <p><strong>Payment ID:</strong> ${paymentId}</p>
        </div>
        <div style="background: #d4edda; padding: 15px; border-radius: 8px;">
          <p style="margin: 0; color: #155724;">
            <strong>✅ Patient is ready for appointment.</strong> Please proceed with the scheduled visit.
          </p>
        </div>
      </div>
    `;

    const emailPromises = [
      sendEmail({ 
        to: patientEmail, 
        subject: `✅ Pre-Visit Payment Successful - Appointment #${appointmentId}`, 
        html: patientHtml 
      })
    ];

    if (nurseEmail) {
      emailPromises.push(
        sendEmail({ 
          to: nurseEmail, 
          subject: `✅ Pre-Payment Received - Appointment #${appointmentId}`, 
          html: nurseHtml 
        })
      );
    }

    // Send SMS
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `CareHive: Pre-visit payment ₹${amount} received! Appointment #${appointmentId} confirmed for ${date || 'scheduled date'}. Remaining ₹${finalAmount} after visit.`,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Pre-payment SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }

    await Promise.all(emailPromises);
    console.log(`[SUCCESS] Pre-payment notifications sent for appointment #${appointmentId}`);

    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-pre-payment:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});

// 4. Final Payment Notification (Completion)
app.post('/api/notify-final-payment', async (req, res) => {
  try {
    const { 
      appointmentId, 
      patientEmail, 
      patientName,
      patientPhone,
      nurseEmail,
      nurseName,
      amount,
      paymentId,
      receiptId,
      totalPaid,
      date,
      time
    } = req.body;

    if (!appointmentId || !patientEmail || !amount) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    console.log(`[INFO] Sending final payment notification for appointment #${appointmentId}`);

    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #009688 0%, #00796b 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 32px;">🎉 Payment Complete!</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 16px;">Thank you for choosing SR CareHive</p>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Patient'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your final payment of <strong style="color: #009688; font-size: 18px;">₹${amount}</strong> has been received successfully! All payments are now complete. 🎊
          </p>

          <div style="background: #e0f2f1; padding: 25px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #009688; text-align: center;">
            <h3 style="margin: 0 0 15px 0; color: #009688;">💰 Payment Summary</h3>
            <div style="display: flex; justify-content: space-around; flex-wrap: wrap;">
              <div style="text-align: center; margin: 10px;">
                <p style="color: #666; margin: 0; font-size: 12px;">REGISTRATION</p>
                <p style="font-size: 20px; font-weight: bold; color: #009688; margin: 5px 0;">₹100</p>
              </div>
              <div style="text-align: center; margin: 10px;">
                <p style="color: #666; margin: 0; font-size: 12px;">PRE-VISIT (50%)</p>
                <p style="font-size: 20px; font-weight: bold; color: #009688; margin: 5px 0;">₹${((totalPaid - 100 - amount) || 0).toFixed(0)}</p>
              </div>
              <div style="text-align: center; margin: 10px;">
                <p style="color: #666; margin: 0; font-size: 12px;">FINAL (50%)</p>
                <p style="font-size: 20px; font-weight: bold; color: #009688; margin: 5px 0;">₹${amount}</p>
              </div>
            </div>
            <div style="border-top: 2px solid #00796b; margin: 15px 0; padding-top: 15px;">
              <p style="color: #666; margin: 0; font-size: 14px;">TOTAL PAID</p>
              <p style="font-size: 32px; font-weight: bold; color: #00796b; margin: 5px 0;">₹${totalPaid || (100 + amount * 2)}</p>
            </div>
          </div>

          <div style="background: #e8eaf6; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3f51b5;">
            <h4 style="margin-top: 0; color: #3f51b5;">📄 Final Payment Receipt</h4>
            <p style="margin: 5px 0;"><strong>Payment ID:</strong> ${paymentId}</p>
            ${receiptId ? `<p style="margin: 5px 0;"><strong>Receipt ID:</strong> ${receiptId}</p>` : ''}
            <p style="margin: 5px 0;"><strong>Amount:</strong> ₹${amount}</p>
            <p style="margin: 5px 0;"><strong>Appointment ID:</strong> #${appointmentId}</p>
          </div>

          <div style="background: #fff9c4; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
            <h3 style="margin: 0 0 10px 0; color: #f57f17;">⭐ Rate Your Experience</h3>
            <p style="color: #666; margin: 0;">We'd love to hear your feedback about our service!</p>
          </div>

          <div style="background: #d4edda; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #28a745;">
            <p style="margin: 0; color: #155724; text-align: center; font-size: 16px;">
              <strong>✅ Service Completed Successfully!</strong>
              <br><br>
              Thank you for trusting SR CareHive for your care needs. We hope to serve you again!
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="http://localhost:5173/patient/appointments" 
               style="display: inline-block; background: #009688; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">
              View Appointment History
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
            Need assistance? Contact us at srcarehive@gmail.com
            <br>SR CareHive - Quality Home Care Services
          </p>
        </div>
      </div>
    `;

    const nurseHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #009688;">🎉 Final Payment Received - Service Complete</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Patient:</strong> ${patientName || 'N/A'}</p>
          <p><strong>Final Payment:</strong> ₹${amount}</p>
          <p><strong>Total Paid:</strong> ₹${totalPaid || (100 + amount * 2)}</p>
          <p><strong>Payment ID:</strong> ${paymentId}</p>
        </div>
        <div style="background: #d4edda; padding: 15px; border-radius: 8px;">
          <p style="margin: 0; color: #155724;">
            <strong>✅ Service completed!</strong> All payments received. Great job!
          </p>
        </div>
      </div>
    `;

    const emailPromises = [
      sendEmail({ 
        to: patientEmail, 
        subject: `🎉 Payment Complete! Thank You - Appointment #${appointmentId}`, 
        html: patientHtml 
      })
    ];

    if (nurseEmail) {
      emailPromises.push(
        sendEmail({ 
          to: nurseEmail, 
          subject: `✅ Final Payment Received - Appointment #${appointmentId}`, 
          html: nurseHtml 
        })
      );
    }

    // Send SMS
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `CareHive: Final payment ₹${amount} received! Total paid ₹${totalPaid || (100 + amount * 2)}. Service complete. Thank you for choosing SR CareHive! 🎉`,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Final payment SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }

    await Promise.all(emailPromises);
    console.log(`[SUCCESS] Final payment notifications sent for appointment #${appointmentId}`);

    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-final-payment:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});

app.listen(PORT, () => console.log(`Payment server (Razorpay) running on http://localhost:${PORT}`));
