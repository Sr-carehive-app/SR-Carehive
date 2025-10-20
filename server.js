// Defer route registration until after Express app is initialized
function registerNurseOtpRoutes(app) {
  // Send OTP for healthcare provider login
  async function handleSendOtp(req, res, resend = false) {
    try {
      const { email } = req.body;
      if (!email || !email.trim()) {
        return res.status(400).json({ error: 'Email is required' });
      }
      const normalizedEmail = email.toLowerCase().trim();
      // Validate email format
      const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
      if (!emailRegex.test(normalizedEmail)) {
        return res.status(400).json({ error: 'Invalid email format' });
      }
      let otpData = nurseLoginOTPs.get(normalizedEmail);
      const now = Date.now();
      if (otpData && !resend && now < (otpData.lastSentAt + 2 * 60 * 1000)) {
        // Prevent spamming OTP
        const wait = Math.ceil((otpData.lastSentAt + 2 * 60 * 1000 - now) / 1000);
        return res.status(429).json({ error: `Please wait ${wait} seconds before resending OTP.` });
      }
      // Generate new OTP
      const otp = generateOTP();
      const expiresAt = now + 5 * 60 * 1000; // 5 min expiry
      nurseLoginOTPs.set(normalizedEmail, {
        otp,
        expiresAt,
        attempts: 0,
        lastSentAt: now,
        verified: false
      });
      // Send OTP email
      if (!mailer) {
        return res.status(500).json({ error: 'Email service not configured' });
      }
      const otpEmailHtml = `<div style="font-family:sans-serif"><h2>SR CareHive healthcare provider Login OTP</h2><p>Your OTP is: <b>${otp}</b></p><p>This OTP is valid for 5 minutes.</p></div>`;
      try {
        await sendEmail({
          to: normalizedEmail,
          subject: 'SR CareHive healthcare provider Login OTP',
          html: otpEmailHtml
        });
        return res.json({ success: true, message: resend ? 'OTP resent.' : 'OTP sent.', expiresIn: 300, canResendAfter: 120 });
      } catch (e) {
        return res.status(500).json({ error: 'Failed to send OTP email.' });
      }
    } catch (e) {
      return res.status(500).json({ error: 'Internal error' });
    }
  }

  app.post('/api/nurse/send-otp', async (req, res) => {
    return handleSendOtp(req, res, false);
  });

  // Verify OTP for healthcare provider login
  app.post('/api/nurse/verify-otp', (req, res) => {
    try {
      const { email, otp } = req.body;
      if (!email || !otp) return res.status(400).json({ error: 'OTP required' });
      const normalizedEmail = email.toLowerCase().trim();
      const otpData = nurseLoginOTPs.get(normalizedEmail);
      if (!otpData) return res.status(400).json({ error: 'No OTP sent or OTP expired.' });
      if (Date.now() > otpData.expiresAt) {
        nurseLoginOTPs.delete(normalizedEmail);
        return res.status(400).json({ error: 'OTP expired. Please request a new one.' });
      }
      if (otpData.attempts >= 5) {
        nurseLoginOTPs.delete(normalizedEmail);
        return res.status(429).json({ error: 'Too many failed attempts. Please request a new OTP.' });
      }
      if (otp !== otpData.otp) {
        otpData.attempts += 1;
        nurseLoginOTPs.set(normalizedEmail, otpData);
        return res.status(400).json({ error: `Invalid OTP. ${5 - otpData.attempts} attempt(s) remaining.` });
      }
      otpData.verified = true;
      nurseLoginOTPs.set(normalizedEmail, otpData);
      // Success: return a session token (or flag)
      return res.json({ success: true, message: 'OTP verified.' });
    } catch (e) {
      return res.status(500).json({ error: 'Internal error' });
    }
  });
}

// Resend OTP for healthcare provider login (enforces 2 min cooldown)
function registerNurseResendOtpRoute(app){
  app.post('/api/nurse/resend-otp', async (req, res) => {
    return app._router.stack.find(r => r.route && r.route.path === '/api/nurse/send-otp')
      ? req.body.email
        ? await app._router.stack.find(r => r.route && r.route.path === '/api/nurse/send-otp').route.stack[0].handle(req, res, true)
        : res.status(400).json({ error: 'Email is required' })
      : res.status(500).json({ error: 'Send OTP route not found' });
  });
}
// --- healthcare provider OTP Login State ---
const nurseLoginOTPs = new Map(); // email -> { otp, expiresAt, attempts, lastSentAt, verified }


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
// Configurable CORS: allow localhost:5173, Vercel, and production frontend
const allowedOrigins = [
  'http://localhost:5173',
  'https://srcarehive.com',
  'https://sr-carehive.vercel.app'
];
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
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

// Register deferred healthcare provider OTP routes now that 'app' exists
registerNurseOtpRoutes(app);
registerNurseResendOtpRoute(app);

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
// appointmentId -> healthcare seeker Email (to email on approve/reject even if DB lacks column)
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
const SENDER_NAME = (process.env.SENDER_NAME || 'SR CareHive').trim();

// Admin/healthcare provider emails that receive all notifications
const ADMIN_EMAILS = ['srcarehive@gmail.com', 'ns.srcarehive@gmail.com'];

// Frontend URL for email links (used when users don't have app installed)
const FRONTEND_URL = (process.env.FRONTEND_URL || '${FRONTEND_URL}').trim();

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

      doc.fontSize(12).text('Healthcare seeker / Appointment Details', { underline: true });
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
  
  try {
    const from = `${SENDER_NAME} <${SENDER_EMAIL}>`;
    console.log(`[EMAIL] Attempting to send email to: ${to}`);
    console.log(`[EMAIL] Subject: ${subject}`);
    console.log(`[EMAIL] From: ${from}`);
    
    const info = await mailer.sendMail({ from, to, subject, html, attachments });
    
    console.log(`[EMAIL]  Email sent successfully!`);
    console.log(`[EMAIL] Message ID: ${info.messageId}`);
    console.log(`[EMAIL] Response: ${info.response}`);
    
    return info;
  } catch (error) {
    console.error(`[EMAIL]  Failed to send email to ${to}`);
    console.error(`[EMAIL] Error: ${error.message}`);
    console.error(`[EMAIL] Full error:`, error);
    throw error; // Re-throw to handle it in calling function
  }
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
    const subject = 'Your Serechi payment confirmation';
    const html = `
      <div>
        <p>Hi ${appointment?.full_name || 'Healthcare seeker'},</p>
        <p>We received your payment and scheduled request. Your appointment is now pending assignment.</p>
        <ul>
          <li><b>Order ID:</b> ${orderId}</li>
          <li><b>Payment ID:</b> ${paymentId}</li>
          <li><b>Amount:</b> ₹${amountRupees ?? '-'}</li>
          <li><b>Date/Time:</b> ${appointment?.date || '-'} ${appointment?.time || ''}</li>
          <li><b>Duration:</b> ${appointment?.duration_hours ?? '-'} hr</li>
        </ul>
        <p>Receipt attached.</p>
        <p>— Serechi By SR CareHive</p>
      </div>`;

    if (patientEmail) await sendEmail({ to: patientEmail, subject, html, attachments: attach });
    
    // Send comprehensive admin notification to both admin emails
    await sendAdminNotification({
      appointment,
      type: 'REGISTRATION_PAYMENT',
      paymentDetails: {
        amount: amountRupees || 100,
        paymentId: paymentId,
        orderId: orderId
      }
    });
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
        <p>Hi ${appointment.full_name || 'Healthcare seeker'},</p>
        <p>Your healthcare provider request has been <b>approved</b>.</p>
        <p><b>Assigned Healthcare provider Details</b></p>
        <ul>
          <li><b>Name:</b> ${appointment.nurse_name || '-'}</li>
          <li><b>Phone:</b> ${appointment.nurse_phone || '-'}</li>
          <li><b>Branch:</b> ${appointment.nurse_branch || '-'}</li>
          <li><b>Comments:</b> ${appointment.nurse_comments || '-'}</li>
          <li><b>Available:</b> ${appointment.nurse_available ? 'Yes' : 'No'}</li>
        </ul>
        <p><b>Appointment</b>: ${appointment.date || '-'} ${appointment.time || ''} •</p>
        <hr>
        <p style="color: #2260FF; font-weight: bold;">Next Step: Please pay your registration fee of ₹100 to confirm your booking.</p>
        <p>You can pay and view your appointment in the app by clicking the button below:</p>
        <a href="https://srcarehive.com/appointments?aid=${appointment.id}" style="display:inline-block;padding:10px 20px;background:#2260FF;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;">View & Pay in App</a>
        <p>— Serechi By SR CareHive</p>
      </div>`;
    await sendEmail({ to, subject: 'Your healthcare provider appointment is approved', html, attachments });
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
        <p>Hi ${appointment.full_name || 'Healthcare seeker'},</p>
        <p>We’re sorry to inform you that your healthcare provider request was <b>rejected</b> at this time.</p>
        <p><b>Reason:</b> ${appointment.rejection_reason || '-'}</p>
        <p>— Serechi By SR CareHive</p>
      </div>`;
    await sendEmail({ to, subject: 'Your healthcare provider appointment was rejected', html, attachments });
  } catch (e) {
    console.error('[EMAIL] reject email failed', e.message);
  }
}

// Comprehensive admin notification with ALL healthcare seeker details
async function sendAdminNotification({ appointment, type, paymentDetails = null }) {
  try {
    const adminHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 700px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
        <div style="background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%); padding: 25px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 26px;">
            ${type === 'NEW_APPOINTMENT' ? 'New Appointment Request' : 
              type === 'REGISTRATION_PAYMENT' ? 'Registration Payment Received (₹100)' :
              type === 'PRE_VISIT_PAYMENT' ? 'Pre-Visit Payment Received (50%)' :
              type === 'FINAL_PAYMENT' ? 'Final Payment Received (50%)' : 'Admin Notification'}
          </h1>
        </div>
        
        <div style="background: white; padding: 25px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #ffc107;">
            <p style="margin: 0; color: #856404; font-size: 16px; font-weight: bold;">
              ${type === 'NEW_APPOINTMENT' ? 'Action Required: Review and assign nurse' :
                type === 'REGISTRATION_PAYMENT' ? 'Healthcare seeker paid registration fee - Review appointment' :
                type === 'PRE_VISIT_PAYMENT' ? 'Healthcare seeker ready for appointment - Proceed with visit' :
                type === 'FINAL_PAYMENT' ? 'Service completed - All payments received!' :
                type === 'VISIT_COMPLETED' ? 'Visit completed - Final payment enabled for healthcare seeker' : ''}
            </p>
          </div>

          ${paymentDetails ? `
          <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #4caf50;">
            <h3 style="margin-top: 0; color: #2e7d32;">💳 Payment Information</h3>
            <p style="margin: 5px 0;"><strong>Amount:</strong> ₹${paymentDetails.amount}</p>
            <p style="margin: 5px 0;"><strong>Payment ID:</strong> ${paymentDetails.paymentId || 'N/A'}</p>
            <p style="margin: 5px 0;"><strong>Order ID:</strong> ${paymentDetails.orderId || 'N/A'}</p>
            ${paymentDetails.totalPaid ? `<p style="margin: 5px 0;"><strong>Total Paid:</strong> ₹${paymentDetails.totalPaid}</p>` : ''}
          </div>` : ''}

          <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #1976d2;">Healthcare seeker Information</h3>
            <table style="width: 100%; border-collapse: collapse;">
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Full Name:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.full_name || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Age:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.age || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Gender:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.gender || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Healthcare seeker Type:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.patient_type || 'N/A'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Aadhar Number:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.aadhar_number || 'N/A'}</td>
              </tr>
            </table>
          </div>

          <div style="background: #fce4ec; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #c2185b;">Contact Details</h3>
            <p style="margin: 8px 0;"><strong>Phone:</strong> <a href="tel:${appointment?.phone}">${appointment?.phone || 'N/A'}</a></p>
            <p style="margin: 8px 0;"><strong>Email:</strong> <a href="mailto:${appointment?.patient_email}">${appointment?.patient_email || 'N/A'}</a></p>
            <p style="margin: 8px 0;"><strong>Address:</strong> ${appointment?.address || 'N/A'}</p>
            <p style="margin: 8px 0;"><strong>Emergency Contact:</strong> ${appointment?.emergency_contact || 'N/A'}</p>
          </div>

          <div style="background: #f3e5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #7b1fa2;">Medical Information</h3>
            <p style="margin: 8px 0;"><strong>Problem/Symptoms:</strong></p>
            <p style="background: white; padding: 12px; border-radius: 6px; margin: 8px 0;">${appointment?.problem || 'N/A'}</p>
            ${appointment?.primary_doctor_name ? `
            <p style="margin: 8px 0;"><strong>Primary Doctor:</strong> ${appointment.primary_doctor_name}</p>
            ${appointment?.primary_doctor_phone ? `<p style="margin: 8px 0;"><strong>Doctor Phone:</strong> ${appointment.primary_doctor_phone}</p>` : ''}
            ${appointment?.primary_doctor_location ? `<p style="margin: 8px 0;"><strong>Doctor Location:</strong> ${appointment.primary_doctor_location}</p>` : ''}
            ` : '<p style="margin: 8px 0; color: #999;">No primary doctor information provided</p>'}
          </div>

          <div style="background: #e8eaf6; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #3f51b5;">Appointment Schedule</h3>
            <p style="margin: 8px 0;"><strong>Date:</strong> ${appointment?.date || 'N/A'}</p>
            <p style="margin: 8px 0;"><strong>Time:</strong> ${appointment?.time || 'N/A'}</p>
            <p style="margin: 8px 0;"><strong>Appointment ID:</strong> #${appointment?.id || 'N/A'}</p>
            <p style="margin: 8px 0;"><strong>Status:</strong> <span style="background: #ffeb3b; padding: 4px 10px; border-radius: 4px; font-weight: bold;">${appointment?.status || 'Pending'}</span></p>
          </div>

          ${appointment?.nurse_name ? `
          <div style="background: #e0f2f1; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #00796b;">Assigned Healthcare provider</h3>
            <p style="margin: 8px 0;"><strong>Name:</strong> ${appointment.nurse_name}</p>
            <p style="margin: 8px 0;"><strong>Phone:</strong> ${appointment.nurse_phone || 'N/A'}</p>
            <p style="margin: 8px 0;"><strong>Branch:</strong> ${appointment.nurse_branch || 'N/A'}</p>
          </div>` : ''}

          <div style="text-align: center; margin: 30px 0;">
            <a href="carehive://nurse-admin"
               style="display: inline-block; background: #ff6b6b; color: white; padding: 14px 40px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px;">
              Manage Appointments
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
            This is an automated admin notification from SR CareHive
            <br>srcarehive@gmail.com | ns.srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    // Send to all admin emails
    let subjectPrefix = 'NOTIFICATION';
    if (type === 'NEW_APPOINTMENT') subjectPrefix = 'NEW';
    else if (type === 'REGISTRATION_PAYMENT') subjectPrefix = 'REGISTRATION';
    else if (type === 'PRE_VISIT_PAYMENT') subjectPrefix = 'PRE-VISIT';
    else if (type === 'FINAL_PAYMENT') subjectPrefix = 'FINAL';
    
    const emailPromises = ADMIN_EMAILS.map(adminEmail => 
      sendEmail({ 
        to: adminEmail, 
        subject: `${subjectPrefix} - Appointment #${appointment?.id || 'N/A'} - ${appointment?.full_name || 'Patient'}`, 
        html: adminHtml 
      })
    );

    await Promise.all(emailPromises);
    console.log(`[SUCCESS] Admin notifications sent to ${ADMIN_EMAILS.join(', ')} for ${type}`);
  } catch (e) {
    console.error('[EMAIL] Admin notification failed', e.message);
  }
}

// --- healthcare provider admin auth (env-based) ---
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
    if (!NURSE_EMAIL || !NURSE_PASSWORD) return res.status(500).json({ error: 'Server healthcare provider creds not configured' });
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
    // Email healthcare seeker about rejection
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
    // Fallback: if no in-memory appointment (server restart), at least upsert a minimal record so healthcare seeker sees it
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

// Root endpoint - Welcome message
app.get('/', (_req, res) => {
  res.send('SR CareHive Payment Server is running! Use /health for health check.');
});

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', message: 'SR CareHive Backend is healthy!' });
});

// New appointment notification endpoint (called after Flutter creates appointment)
app.post('/api/notify-new-appointment', async (req, res) => {
  try {
    const { appointmentId } = req.body;

    if (!appointmentId) {
      return res.status(400).json({ error: 'Missing appointmentId' });
    }

    console.log(`[INFO] Sending new appointment notification for appointment #${appointmentId}`);

    // Fetch full appointment details
    let appointment = null;
    try {
      const { data } = await supabase
        .from('appointments')
        .select('*')
        .eq('id', appointmentId)
        .maybeSingle();
      appointment = data;
    } catch (err) {
      console.error('[ERROR] Could not fetch appointment:', err.message);
      return res.status(404).json({ error: 'Appointment not found' });
    }

    if (!appointment) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    // Send comprehensive admin notification to both admin emails
    await sendAdminNotification({
      appointment,
      type: 'NEW_APPOINTMENT',
      paymentDetails: null
    });

    console.log(`[SUCCESS] New appointment notifications sent for appointment #${appointmentId}`);
    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-new-appointment:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
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
        // Compare strictly in IST by string/date components to avoid TZ drift
        const dateStr = String(a.date).slice(0,10);
        if (dateStr < todayIstStr) { toArchive.push(a); continue; }
        if (dateStr === todayIstStr) {
          // Parse time like '6:00 PM' as 24h local values
          let hour = 0, minute = 0;
          const m = String(a.time || '').match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
          if (m) {
            hour = parseInt(m[1], 10);
            minute = parseInt(m[2], 10);
            const ap = m[3].toUpperCase();
            if (ap === 'PM' && hour < 12) hour += 12;
            if (ap === 'AM' && hour === 12) hour = 0;
          }
          const nowHour = nowIst.getUTCHours() + 5; // 5h from UTC to IST hours; adjust minutes below
          const nowMinute = nowIst.getUTCMinutes() + 30; // +30 mins
          const adjHour = (nowHour + Math.floor(nowMinute / 60)) % 24;
          const adjMinute = nowMinute % 60;
          if (hour < adjHour || (hour === adjHour && minute < adjMinute)) {
            toArchive.push(a);
          }
        }
      } catch {}
    }
    if (!toArchive.length) return res.json({ archived: 0 });
    // Insert into history table then delete original (soft archival)
    // ✅ COMPLETE FIELD MAPPING - ALL NEW FIELDS INCLUDED
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
      
      // ✅ NEW PATIENT FIELDS
      aadhar_number: a.aadhar_number,
      address: a.address,
      emergency_contact: a.emergency_contact,
      problem: a.problem,
      
      // ✅ PRIMARY DOCTOR FIELDS
      primary_doctor_name: a.primary_doctor_name,
      primary_doctor_phone: a.primary_doctor_phone,
      primary_doctor_location: a.primary_doctor_location,
      
      // ✅ 3-TIER PAYMENT SYSTEM
      // Registration Payment
      registration_payment_id: a.registration_payment_id,
      registration_receipt_id: a.registration_receipt_id,
      registration_paid: a.registration_paid,
      registration_paid_at: a.registration_paid_at,
      
      // Pre-visit Payment (50%)
      total_amount: a.total_amount,
      nurse_remarks: a.nurse_remarks,
      pre_payment_id: a.pre_payment_id,
      pre_receipt_id: a.pre_receipt_id,
      pre_paid: a.pre_paid,
      pre_paid_at: a.pre_paid_at,
      
      // Final Payment (50%)
      final_payment_id: a.final_payment_id,
      final_receipt_id: a.final_receipt_id,
      final_paid: a.final_paid,
      final_paid_at: a.final_paid_at,
      
      // ✅ healthcare provider ASSIGNMENT
      nurse_name: a.nurse_name,
      nurse_phone: a.nurse_phone,
      nurse_branch: a.nurse_branch,
      nurse_comments: a.nurse_comments,
      nurse_available: a.nurse_available,
      
      // ✅ CONSULTATION/DOCTOR RECOMMENDATION FIELDS
      consulted_doctor_name: a.consulted_doctor_name,
      consulted_doctor_phone: a.consulted_doctor_phone,
      consulted_doctor_specialization: a.consulted_doctor_specialization,
      consulted_doctor_clinic_address: a.consulted_doctor_clinic_address,
      post_visit_remarks: a.post_visit_remarks,
      visit_completed_at: a.visit_completed_at,
      
      // ✅ STATUS TRACKING
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
      subject: 'Serechi By SR CareHive email test',
      html: '<p>This is a test email from Serechi By SR CareHive server. SMTP is working</p>'
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
      return res.status(400).json({ error: 'OTP is required' });
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

    // Email to healthcare seeker
    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4acc 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Registration Successful!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Healthcare seeker'}</strong>,</p>
          
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
            <h4 style="margin-top: 0; color: #856404;">What Happens Next?</h4>
            <ol style="color: #856404; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
              <li>Our care provider will contact you shortly to confirm appointment details</li>
              <li>They will assess your needs and set the total service amount</li>
              <li>You'll be notified when the total amount is ready</li>
              <li>Payment will be split: 50% before visit, 50% after successful completion</li>
            </ol>
          </div>

          <div style="background: #d4edda; padding: 15px; border-radius: 8px; border-left: 4px solid #28a745; margin: 20px 0;">
            <p style="margin: 0; color: #155724;">
              <strong>Your booking is now confirmed!</strong> We'll keep you updated via email and SMS.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="carehive://patient/appointments" 
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
        <h2 style="color: #2260FF;">New Registration Payment Received</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Healthcare seeker:</strong> ${patientName || 'N/A'} (${patientPhone || 'N/A'})</p>
          <p><strong>Email:</strong> ${patientEmail}</p>
          <p><strong>Amount Paid:</strong> ₹${amount || 100}</p>
          <p><strong>Payment ID:</strong> ${paymentId}</p>
          <p><strong>Date:</strong> ${date || 'N/A'}</p>
          <p><strong>Time:</strong> ${time || 'N/A'}</p>
        </div>
        <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 0; color: #856404;">
            <strong>Next Action:</strong> Please contact the healthcare seeker and set the total service amount in the healthcare provider dashboard.
          </p>
        </div>
  <a href="carehive://nurse/manage-appointments" 
           style="display: inline-block; background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin-top: 10px;">
          Manage Appointments
        </a>
      </div>
    `;

    // Send emails
    const emailPromises = [
      sendEmail({ 
        to: patientEmail, 
        subject: `Registration Payment Successful - Appointment #${appointmentId}`, 
        html: patientHtml 
      })
    ];

    if (nurseEmail) {
      emailPromises.push(
        sendEmail({ 
          to: nurseEmail, 
          subject: `Registration Payment Received - Appointment #${appointmentId}`, 
          html: nurseHtml 
        })
      );
    }

    // Send SMS to healthcare seeker
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `CareHive: Registration payment ₹${amount || 100} received! Appointment #${appointmentId}. Our healthcare provider provider will contact you soon. Check email for details.`,
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

// 2. Amount Set Notification (healthcare provider sets total amount)
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
          <h1 style="color: white; margin: 0; font-size: 28px;">Service Amount Set</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Healthcare seeker'}</strong>,</p>
          
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
              <strong>Next Step:</strong> Please pay ₹${preAmount} before your scheduled appointment to confirm your booking.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="carehive://patient/appointments" 
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
            <br>Serechi By SR CareHive | srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    await sendEmail({ 
      to: patientEmail, 
      subject: `Service Amount Set - ₹${totalAmount} | Appointment #${appointmentId}`, 
      html: patientHtml 
    });

    // Send SMS
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `SR CareHive: Service amount set ₹${totalAmount} for appointment #${appointmentId}. Pay ₹${preAmount} (50%) before visit. Login to pay now.`,
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

    // Calculate final amount correctly - it should be same as pre-visit (50% each)
    const finalAmount = amount; // Since pre-visit is 50%, final is also 50%

    console.log(`[INFO] Sending pre-payment notification for appointment #${appointmentId}. Amount: ${amount}, Remaining: ${finalAmount}`);

    // Fetch full appointment details for admin notification
    let fullAppointment = null;
    try {
      const { data } = await supabase
        .from('appointments')
        .select('*')
        .eq('id', appointmentId)
        .maybeSingle();
      fullAppointment = data;
    } catch (err) {
      console.warn('[WARN] Could not fetch full appointment for admin notification:', err.message);
    }

    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #3f51b5 0%, #303f9f 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Pre-Visit Payment Successful!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Healthcare seeker'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your pre-visit payment of <strong style="color: #3f51b5; font-size: 18px;">₹${amount}</strong> has been received successfully! 
          </p>

          <div style="background: #e8eaf6; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3f51b5;">
            <h3 style="margin-top: 0; color: #3f51b5;">Payment Details</h3>
            <p style="margin: 5px 0;"><strong>Payment ID:</strong> ${paymentId}</p>
            ${receiptId ? `<p style="margin: 5px 0;"><strong>Receipt ID:</strong> ${receiptId}</p>` : ''}
            <p style="margin: 5px 0;"><strong>Amount Paid:</strong> ₹${amount}</p>
            <p style="margin: 5px 0;"><strong>Remaining:</strong> ₹${finalAmount} (payable after visit)</p>
          </div>

          <div style="background: #d4edda; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #28a745;">
            <h4 style="margin-top: 0; color: #155724;">You're All Set!</h4>
            <p style="color: #155724; margin: 10px 0;">Your appointment is confirmed. Our care provider will visit you as scheduled.</p>
            <div style="background: white; padding: 15px; border-radius: 6px; margin-top: 15px;">
              <p style="margin: 5px 0;"><strong>Date:</strong> ${date || 'To be confirmed'}</p>
              <p style="margin: 5px 0;"><strong>Time:</strong> ${time || 'To be confirmed'}</p>
              ${nurseName ? `<p style="margin: 5px 0;"><strong>Care Provider:</strong> ${nurseName}</p>` : ''}
            </div>
          </div>

          <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
            <p style="margin: 0; color: #856404;">
              <strong>Remember:</strong> The remaining ₹${finalAmount} is payable after successful completion of your service.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="carehive://patient/appointments" 
               style="display: inline-block; background: #3f51b5; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">
              View Appointment Details
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
            Serechi By SR CareHive | srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    const nurseHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #3f51b5;">Pre-Visit Payment Received</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Healthcare seeker:</strong> ${patientName || 'N/A'}</p>
          <p><strong>Pre-Payment:</strong> ₹${amount} (50%)</p>
          <p><strong>Remaining:</strong> ₹${finalAmount} (payable after visit)</p>
          <p><strong>Payment ID:</strong> ${paymentId}</p>
        </div>
        <div style="background: #d4edda; padding: 15px; border-radius: 8px;">
          <p style="margin: 0; color: #155724;">
            <strong>Healthcare seeker is ready for appointment.</strong> Please proceed with the scheduled visit.
          </p>
        </div>
      </div>
    `;

    const emailPromises = [
      sendEmail({ 
        to: patientEmail, 
        subject: `Pre-Visit Payment Successful - Appointment #${appointmentId}`, 
        html: patientHtml 
      })
    ];

    if (nurseEmail) {
      emailPromises.push(
        sendEmail({ 
          to: nurseEmail, 
          subject: `Pre-Payment Received - Appointment #${appointmentId}`, 
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
          body: `SR CareHive: Pre-visit payment ₹${amount} received! Appointment #${appointmentId} confirmed for ${date || 'scheduled date'}. Remaining ₹${finalAmount} after visit.`,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Pre-payment SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }

    await Promise.all(emailPromises);
    
    // Send comprehensive admin notification
    if (fullAppointment) {
      await sendAdminNotification({
        appointment: fullAppointment,
        type: 'PRE_VISIT_PAYMENT',
        paymentDetails: {
          amount: amount,
          paymentId: paymentId,
          orderId: receiptId || 'N/A'
        }
      });
    }
    
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

    // Fetch full appointment details for admin notification
    let fullAppointment = null;
    try {
      const { data } = await supabase
        .from('appointments')
        .select('*')
        .eq('id', appointmentId)
        .maybeSingle();
      fullAppointment = data;
    } catch (err) {
      console.warn('[WARN] Could not fetch full appointment for admin notification:', err.message);
    }

    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #009688 0%, #00796b 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 32px;">🎉 Payment Complete!</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 16px;">Thank you for choosing SR CareHive</p>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Healthcare seeker'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your final payment of <strong style="color: #009688; font-size: 18px;">₹${amount}</strong> has been received successfully! All payments are now complete. 🎊
          </p>

          <div style="background: #e0f2f1; padding: 25px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #009688; text-align: center;">
            <h3 style="margin: 0 0 15px 0; color: #009688;">Payment Summary</h3>
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
            <h3 style="margin: 0 0 10px 0; color: #f57f17;">Rate Your Experience</h3>
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
            <a href="carehive://patient/appointments" 
               style="display: inline-block; background: #009688; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">
              View Appointment History
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
            Need assistance? Contact us at srcarehive@gmail.com
            <br>Serechi By SR CareHive - Quality Home Care Services
          </p>
        </div>
      </div>
    `;

    const nurseHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #009688;">🎉 Final Payment Received - Service Complete</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Healthcare seeker:</strong> ${patientName || 'N/A'}</p>
          <p><strong>Final Payment:</strong> ₹${amount}</p>
          <p><strong>Total Paid:</strong> ₹${totalPaid || (100 + amount * 2)}</p>
          <p><strong>Payment ID:</strong> ${paymentId}</p>
        </div>
        <div style="background: #d4edda; padding: 15px; border-radius: 8px;">
          <p style="margin: 0; color: #155724;">
            <strong>Service completed!</strong> All payments received. Great job!
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
          subject: `Final Payment Received - Appointment #${appointmentId}`, 
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
          body: `SR CareHive: Final payment ₹${amount} received! Total paid ₹${totalPaid || (100 + amount * 2)}. Service complete. Thank you for choosing SR CareHive! `,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Final payment SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }

    await Promise.all(emailPromises);
    
    // Send comprehensive admin notification
    if (fullAppointment) {
      await sendAdminNotification({
        appointment: fullAppointment,
        type: 'FINAL_PAYMENT',
        paymentDetails: {
          amount: amount,
          paymentId: paymentId,
          orderId: receiptId || 'N/A',
          totalPaid: totalPaid
        }
      });
    }
    
    console.log(`[SUCCESS] Final payment notifications sent for appointment #${appointmentId}`);

    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-final-payment:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});

// 5. Visit Completion Notification (enables final payment)
app.post('/api/notify-visit-completed', async (req, res) => {
  try {
    const { 
      appointmentId, 
      patientEmail, 
      patientName,
      patientPhone,
      nurseName,
      postVisitRemarks,
      doctorName,
      doctorPhone,
      doctorSpecialization,
      doctorClinicAddress
    } = req.body;

    if (!appointmentId || !patientEmail) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    console.log(`[INFO] Sending visit completion notification for appointment #${appointmentId}`);

    // Fetch full appointment details
    let fullAppointment = null;
    try {
      const { data } = await supabase
        .from('appointments')
        .select('*')
        .eq('id', appointmentId)
        .maybeSingle();
      fullAppointment = data;
    } catch (err) {
      console.warn('[WARN] Could not fetch full appointment:', err.message);
    }

    const totalAmount = fullAppointment?.total_amount || 0;
    const finalAmount = (totalAmount / 2).toFixed(2);

    // healthcare seeker email
    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #4caf50 0%, #45a049 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Visit Completed!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Healthcare seeker'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your healthcare provider has completed the visit and submitted the post-visit consultation summary.
          </p>

          <div style="background: #e8f5e9; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #4caf50;">
            <h3 style="margin-top: 0; color: #2e7d32;">📋 Visit Summary</h3>
            ${postVisitRemarks ? `<p style="margin: 5px 0;"><strong>Healthcare provider Remarks:</strong><br/>${postVisitRemarks}</p>` : ''}
            ${nurseName ? `<p style="margin: 5px 0;"><strong>Care Provider:</strong> ${nurseName}</p>` : ''}
            ${doctorName ? `
              <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #c8e6c9;">
                <p style="margin: 5px 0; color: #2e7d32; font-weight: bold;">Recommended Doctor:</p>
                <p style="margin: 5px 0;"><strong>Name:</strong> ${doctorName}</p>
                ${doctorPhone ? `<p style="margin: 5px 0;"><strong>Phone:</strong> ${doctorPhone}</p>` : ''}
                ${doctorSpecialization ? `<p style="margin: 5px 0;"><strong>Specialization:</strong> ${doctorSpecialization}</p>` : ''}
                ${doctorClinicAddress ? `<p style="margin: 5px 0;"><strong>Clinic:</strong> ${doctorClinicAddress}</p>` : ''}
              </div>
            ` : ''}
          </div>

          <div style="background: #fff3e0; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ff9800;">
            <h4 style="margin-top: 0; color: #e65100;">Final Payment Now Available</h4>
            <p style="color: #e65100; margin: 10px 0;">
              You can now complete your final payment of <strong>₹${finalAmount}</strong> to complete this appointment.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="carehive://patient/appointments" 
               style="display: inline-block; background: #4caf50; color: white; padding: 14px 40px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px;">
              Pay Final Amount (₹${finalAmount})
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
           Serechi By SR CareHive | srcarehive@gmail.com
          </p>
        </div>
      </div>
    `;

    // Send email to healthcare seeker
    await sendEmail({ 
      to: patientEmail, 
      subject: `Visit Completed - Final Payment Available - Appointment #${appointmentId}`, 
      html: patientHtml 
    });

    // Send SMS
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        
        await twilioClient.messages.create({
          body: `SR CareHive: Visit completed! You can now pay the final amount ₹${finalAmount} to complete your appointment #${appointmentId}. Thank you for choosing us!`,
          from: TWILIO_PHONE_NUMBER,
          to: phone
        });
        console.log(`[SUCCESS] Visit completion SMS sent to ${phone.slice(0,6)}***`);
      } catch (smsErr) {
        console.error('[ERROR] SMS failed:', smsErr.message);
      }
    }
    
    // Send admin notification
    if (fullAppointment) {
      await sendAdminNotification({
        appointment: fullAppointment,
        type: 'VISIT_COMPLETED',
        paymentDetails: null
      });
    }
    
    console.log(`[SUCCESS] Visit completion notifications sent for appointment #${appointmentId}`);

    res.json({ success: true, message: 'Notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-visit-completed:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});


app.post('/api/notify-feedback-submitted', async (req, res) => {
  try {
    const {
      appointmentId,
      patientEmail,
      patientName,
      overallRating,
      feedbackText
    } = req.body;

    if (!appointmentId || !patientEmail) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    console.log(`[INFO] Sending feedback thank you email for appointment #${appointmentId}`);

    // healthcare seeker thank you email
    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #ffa726 0%, #fb8c00 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Thank You for Your Feedback!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Valued Customer'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            We sincerely appreciate you taking the time to share your feedback about our service! 
          </p>

          <div style="background: #fff3e0; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center; border-left: 4px solid #ffa726;">
            <div style="font-size: 48px; margin-bottom: 10px;">
              ${'⭐'.repeat(overallRating || 5)}
            </div>
            <p style="margin: 0; color: #e65100; font-size: 18px; font-weight: bold;">
              Your Rating: ${overallRating || 'N/A'} / 5
            </p>
          </div>

          <div style="background: #e8f5e9; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #4caf50;">
            <h4 style="margin-top: 0; color: #2e7d32;">Your feedback helps us improve!</h4>
            <p style="color: #2e7d32; margin: 10px 0; line-height: 1.6;">
              At SR CareHive, we're committed to providing the best possible care. Your honest feedback allows us to continuously improve our services and better serve you.
            </p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="carehive://patient/appointments" 
               style="display: inline-block; background: #2260FF; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">
              View Your Appointments
            </a>
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
           Serechi By SR CareHive | srcarehive@gmail.com | Thank you for choosing us!
          </p>
        </div>
      </div>
    `;

    // Admin notification email
    const adminHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #ffa726;">⭐ New Feedback Received</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Healthcare seeker:</strong> ${patientName || 'N/A'}</p>
          <p><strong>Overall Rating:</strong> ${'⭐'.repeat(overallRating || 0)} (${overallRating || 0}/5)</p>
          ${feedbackText ? `<p><strong>Feedback:</strong><br/>${feedbackText}</p>` : ''}
        </div>
      </div>
    `;

    // Send emails
    await sendEmail({
      to: patientEmail,
      subject: `Thank You for Your Feedback - Appointment #${appointmentId}`,
      html: patientHtml
    });

    // Send to admin emails
    await sendEmail({
      to: ['srcarehive@gmail.com', 'ns.srcarehive@gmail.com'],
      subject: `New Feedback - Appointment #${appointmentId}`,
      html: adminHtml
    });

    console.log(`[SUCCESS] Feedback thank you emails sent for appointment #${appointmentId}`);

    res.json({ success: true, message: 'Feedback notifications sent successfully' });
  } catch (e) {
    console.error('[ERROR] notify-feedback-submitted:', e);
    res.status(500).json({ error: 'Failed to send notifications', details: e.message });
  }
});

// ============================================================================
// OTP-BASED PASSWORD RESET SYSTEM
// ============================================================================

// In-memory OTP storage (for production, use Redis or database)
const passwordResetOTPs = new Map(); // email -> { otp, expiresAt, attempts, lastSentAt }

// Generate 6-digit OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send OTP via email for password reset
app.post('/send-password-reset-otp', async (req, res) => {
  try {
    const { email, resend = false } = req.body;
    
    if (!email || !email.trim()) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    console.log(`[OTP-RESET] ${resend ? 'Resend' : 'New'} request for email: ${normalizedEmail}`);

    // Validate email format
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(normalizedEmail)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    // Check for resend cooldown (2 minutes)
    const existingOTP = passwordResetOTPs.get(normalizedEmail);
    if (existingOTP && existingOTP.lastSentAt) {
      const timeSinceLastSend = Date.now() - existingOTP.lastSentAt;
      const cooldownPeriod = 2 * 60 * 1000; // 2 minutes in milliseconds
      
      if (timeSinceLastSend < cooldownPeriod) {
        const remainingTime = Math.ceil((cooldownPeriod - timeSinceLastSend) / 1000); // seconds
        const minutes = Math.floor(remainingTime / 60);
        const seconds = remainingTime % 60;
        
        console.log(`[OTP-RESET] Cooldown active for ${normalizedEmail}. Remaining: ${minutes}m ${seconds}s`);
        
        return res.status(429).json({ 
          error: `Please wait ${minutes > 0 ? minutes + ' minute(s) ' : ''}${seconds} second(s) before requesting a new OTP.`,
          remainingSeconds: remainingTime,
          canResendAt: existingOTP.lastSentAt + cooldownPeriod
        });
      }
    }

    if (!supabase) {
      console.error('[ERROR] Supabase client not initialized');
      return res.status(500).json({ error: 'Database connection not available' });
    }

    
    console.log(`[OTP-RESET] Querying database for email: ${normalizedEmail}`);
    
    const { data: patient, error: patientError } = await supabase
  .from('patients')
  .select('email, name, user_id')
  .eq('email', normalizedEmail)
  .single();

    console.log(`[OTP-RESET] Query result - Data:`, patient);
    console.log(`[OTP-RESET] Query result - Error:`, patientError);

    if (patientError || !patient) {
      console.log(`[OTP-RESET] User not found: ${normalizedEmail}`);
      console.log(`[OTP-RESET] Error details:`, patientError?.message, patientError?.code);
      
      // For debugging: Try case-insensitive search
      console.log(`[OTP-RESET] Attempting case-insensitive search...`);
      const { data: altPatient, error: altError } = await supabase
        .from('patients')
        .select('email, name, user_id')
        .ilike('email', normalizedEmail);
      
      console.log(`[OTP-RESET] Case-insensitive result:`, altPatient);
      
      if (altPatient && altPatient.length > 0) {
        console.log(`[OTP-RESET] Found user with case-insensitive match: ${altPatient[0].email}`);
        console.log(`[OTP-RESET] Database has: "${altPatient[0].email}"`);
        console.log(`[OTP-RESET] Frontend sent: "${normalizedEmail}"`);
      }
      
      // Return success to prevent email enumeration
      return res.json({ 
        success: true, 
        message: 'If this email exists, an OTP has been sent.',
        canResendAfter: 120 // 2 minutes
      });
    }

  console.log(`[OTP-RESET] User found: ${patient.name} <${patient.email}>`);

    // Generate 6-digit OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + (10 * 60 * 1000); // 10 minutes expiry
    const lastSentAt = Date.now();

    // Store OTP in memory
    passwordResetOTPs.set(normalizedEmail, {
      otp,
      expiresAt,
      attempts: 0,
      userId: patient.user_id,
      lastSentAt
    });

    console.log(`[OTP-RESET] Generated OTP for ${normalizedEmail}: ${otp} (expires in 10 min, can resend after 2 min)`);

    // Create OTP email HTML
    const otpEmailHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
          <tr>
            <td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Reset Your Password</h1>
                  </td>
                </tr>
                
                <!-- Body -->
                <tr>
                  <td style="padding: 40px 30px;">
                    <p style="font-size: 16px; color: #333; margin: 0 0 20px;">Hello ${patient.name || 'there'},</p>
                    
                    <p style="font-size: 14px; color: #666; line-height: 1.6; margin: 0 0 20px;">
                      We received a request to reset your password for your SR CareHive account. 
                      Use the OTP below to verify your identity:
                    </p>
                    
                    <!-- OTP Box -->
                    <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                      <p style="margin: 0 0 10px; font-size: 14px; color: #ffffff; opacity: 0.9;">Your OTP Code</p>
                      <p style="margin: 0; font-size: 42px; font-weight: bold; color: #ffffff; letter-spacing: 8px; font-family: 'Courier New', monospace;">
                        ${otp}
                      </p>
                    </div>
                    
                    <!-- Warning Box -->
                    <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
                      <p style="margin: 0; font-size: 13px; color: #856404;">
                        <strong>⚠️ Important:</strong><br/>
                        • This OTP will expire in <strong>10 minutes</strong><br/>
                        • Do not share this code with anyone<br/>
                        • You can request a new OTP after <strong>2 minutes</strong><br/>
                        • If you didn't request this, please ignore this email
                      </p>
                    </div>
                    
                    <p style="font-size: 14px; color: #666; line-height: 1.6; margin: 20px 0 0;">
                      After entering the OTP, you'll be able to set a new password for your account.
                    </p>
                  </td>
                </tr>
                
                <!-- Footer -->
                <tr>
                  <td style="background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #e0e0e0;">
                    <p style="margin: 0 0 10px; font-size: 14px; color: #2260FF; font-weight: bold;">SR CareHive</p>
                    <p style="margin: 0 0 10px; font-size: 12px; color: #999;">
                      Your trusted healthcare companion
                    </p>
                    <p style="margin: 0; font-size: 11px; color: #999;">
                      This is an automated email. Please do not reply to this message.
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Security Notice -->
              <table width="600" cellpadding="0" cellspacing="0" style="margin-top: 20px;">
                <tr>
                  <td style="text-align: center; padding: 20px;">
                    <p style="font-size: 11px; color: #999; margin: 0;">
                      For security reasons, never share your OTP or password with anyone.<br/>
                      SR CareHive will never ask for your OTP via phone or chat.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    `;

    // Send OTP email via Nodemailer
    if (!mailer) {
      console.error('[ERROR] Nodemailer not configured');
      return res.status(500).json({ error: 'Email service not configured' });
    }

    console.log(`[OTP-RESET] Attempting to send OTP email...`);
    
    try {
      const emailResult = await sendEmail({
        to: normalizedEmail,
        subject: 'Your Password Reset OTP - SR CareHive',
        html: otpEmailHtml
      });

      if (emailResult.skipped) {
        console.error('[ERROR] Email was skipped - mailer not configured');
        return res.status(500).json({ error: 'Email service not available' });
      }

      console.log(`[SUCCESS] OTP email sent successfully to: ${normalizedEmail}`);

      res.json({ 
        success: true, 
        message: resend 
          ? 'New OTP sent successfully! Check your email.' 
          : 'OTP sent successfully to your email. Please check your inbox and spam folder.',
        expiresIn: 600, // 10 minutes in seconds
        canResendAfter: 120 // 2 minutes in seconds
      });
    } catch (emailError) {
      console.error('[ERROR] Failed to send OTP email:', emailError.message);
      console.error('[ERROR] Full error:', emailError);
      
      return res.status(500).json({ 
        error: 'Failed to send OTP email. Please try again later.',
        details: emailError.message
      });
    }

  } catch (e) {
    console.error('[ERROR] send-password-reset-otp:', e);
    res.status(500).json({ 
      error: 'Failed to send OTP', 
      details: e.message 
    });
  }
});

// Verify OTP
app.post('/verify-password-reset-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    
    if (!email || !otp) {
      return res.status(400).json({ error: 'OTP required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const normalizedOTP = otp.trim();

    console.log(`[OTP-VERIFY] Verification attempt for: ${normalizedEmail}`);

    const otpData = passwordResetOTPs.get(normalizedEmail);

    if (!otpData) {
      console.log(`[OTP-VERIFY] No OTP found for: ${normalizedEmail}`);
      return res.status(400).json({ 
        error: 'Invalid or expired OTP. Please request a new one.' 
      });
    }

    // Check expiry
    if (Date.now() > otpData.expiresAt) {
      console.log(`[OTP-VERIFY] OTP expired for: ${normalizedEmail}`);
      passwordResetOTPs.delete(normalizedEmail);
      return res.status(400).json({ 
        error: 'OTP has expired. Please request a new one.' 
      });
    }

    // Check attempts (max 5 attempts)
    if (otpData.attempts >= 5) {
      console.log(`[OTP-VERIFY] Too many attempts for: ${normalizedEmail}`);
      passwordResetOTPs.delete(normalizedEmail);
      return res.status(429).json({ 
        error: 'Too many failed attempts. Please request a new OTP.' 
      });
    }

    // Verify OTP
    if (normalizedOTP !== otpData.otp) {
      otpData.attempts += 1;
      passwordResetOTPs.set(normalizedEmail, otpData);
      
      const remainingAttempts = 5 - otpData.attempts;
      console.log(`[OTP-VERIFY] Invalid OTP for: ${normalizedEmail}. Remaining attempts: ${remainingAttempts}`);
      
      return res.status(400).json({ 
        error: `Invalid OTP. ${remainingAttempts} attempt(s) remaining.`,
        remainingAttempts
      });
    }

    console.log(`[OTP-VERIFY] OTP verified successfully for: ${normalizedEmail}`);

    // OTP verified - mark as verified but don't delete yet
    otpData.verified = true;
    passwordResetOTPs.set(normalizedEmail, otpData);

    res.json({ 
      success: true, 
      message: 'OTP verified successfully. You can now reset your password.',
      userId: otpData.userId
    });

  } catch (e) {
    console.error('[ERROR] verify-password-reset-otp:', e);
    res.status(500).json({ 
      error: 'Failed to verify OTP', 
      details: e.message 
    });
  }
});

// Reset password with OTP (final step)
app.post('/reset-password-with-otp', async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;
    
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Email, OTP, and new password are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    console.log(`[PASSWORD-RESET] Reset attempt for: ${normalizedEmail}`);

    const otpData = passwordResetOTPs.get(normalizedEmail);

    if (!otpData || !otpData.verified) {
      console.log(`[PASSWORD-RESET] OTP not verified for: ${normalizedEmail}`);
      return res.status(400).json({ 
        error: 'OTP not verified. Please verify OTP first.' 
      });
    }

    // Check if OTP is still valid
    if (Date.now() > otpData.expiresAt) {
      console.log(`[PASSWORD-RESET] OTP expired for: ${normalizedEmail}`);
      passwordResetOTPs.delete(normalizedEmail);
      return res.status(400).json({ 
        error: 'OTP has expired. Please request a new one.' 
      });
    }

    // Validate password strength
    if (newPassword.length < 6) {
      return res.status(400).json({ 
        error: 'Password must be at least 6 characters long' 
      });
    }

    if (!supabase) {
      console.error('[ERROR] Supabase client not initialized');
      return res.status(500).json({ error: 'Database connection not available' });
    }

    // Update password in Supabase Auth
    const { data, error } = await supabase.auth.admin.updateUserById(
      otpData.userId,
      { password: newPassword }
    );

    if (error) {
      console.error('[ERROR] Failed to update password:', error.message);
      return res.status(500).json({ 
        error: 'Failed to update password', 
        details: error.message 
      });
    }

    console.log(`[SUCCESS] ✅ Password reset successfully for: ${normalizedEmail}`);

    // Delete OTP after successful password reset
    passwordResetOTPs.delete(normalizedEmail);

    res.json({ 
      success: true, 
      message: 'Password reset successfully! You can now login with your new password.' 
    });

  } catch (e) {
    console.error('[ERROR] reset-password-with-otp:', e);
    res.status(500).json({ 
      error: 'Failed to reset password', 
      details: e.message 
    });
  }
});

// Clean up expired OTPs every 5 minutes
setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  
  for (const [email, data] of passwordResetOTPs.entries()) {
    if (now > data.expiresAt) {
      passwordResetOTPs.delete(email);
      cleaned++;
    }
  }
  
  if (cleaned > 0) {
    console.log(`[OTP-CLEANUP] Removed ${cleaned} expired OTP(s)`);
  }
}, 5 * 60 * 1000);

app.listen(PORT, () => console.log(`Payment server (Razorpay) running on http://localhost:${PORT}`));
