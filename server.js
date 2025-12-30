// Defer route registration until after Express app is initialized
function registerNurseOtpRoutes(app) {
  // Send OTP for healthcare provider login
  async function handleSendOtp(req, res, resend = false) {
    try {
      const { email } = req.body;
      if (!email || !email.trim()) {
        return res.status(400).json({ error: 'Email or phone number is required' });
      }
      
      const identifier = email.trim();
      
      // Detect if input is phone number (10 digits) or email
      const isPhoneNumber = /^\d{10}$/.test(identifier.replace(/[^\d]/g, ''));
      const normalizedIdentifier = isPhoneNumber ? identifier.replace(/[^\d]/g, '') : identifier.toLowerCase();
      
      console.log(`[OTP] Input type: ${isPhoneNumber ? 'Phone' : 'Email'}, Identifier: ${normalizedIdentifier}`);
      
      // Validate format
      if (!isPhoneNumber) {
        const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
        if (!emailRegex.test(normalizedIdentifier)) {
          return res.status(400).json({ error: 'Invalid email format' });
        }
      }
      
      let otpData = await getOTP(normalizedIdentifier);
      const now = Date.now();
      if (otpData && !resend && now < (otpData.lastSentAt + 2 * 60 * 1000)) {
        // Prevent spamming OTP
        const wait = Math.ceil((otpData.lastSentAt + 2 * 60 * 1000 - now) / 1000);
        return res.status(429).json({ error: `Please wait ${wait} seconds before resending OTP.` });
      }
      // Generate new OTP
      const otp = generateOTP();
      const expiresAt = now + 5 * 60 * 1000; // 5 min expiry
      
      await storeOTP(normalizedIdentifier, {
        otp,
        expiresAt,
        attempts: 0,
        lastSentAt: now,
        verified: false,
        type: isPhoneNumber ? 'phone' : 'email'  // Store type for verification
      });
      
      // Send OTP via appropriate channel
      if (isPhoneNumber) {
        // Send OTP via SMS
        console.log(`[OTP] Sending OTP via SMS to: ${normalizedIdentifier}`);
        const smsSent = await sendOTPViaTubelight(
          normalizedIdentifier, 
          otp, 
          'Healthcare Provider',
          TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID,
          'provider login'
        );
        
        if (smsSent) {
          console.log(`[OTP] SMS sent successfully to: ${normalizedIdentifier}`);
          return res.json({ success: true, message: resend ? 'OTP resent to your phone.' : 'OTP sent to your phone.', expiresIn: 300, canResendAfter: 120, deliveryChannels: ['SMS'] });
        } else {
          console.error(`[OTP] Failed to send SMS to: ${normalizedIdentifier}`);
          // Clear stored OTP if SMS failed
          await deleteOTP(normalizedIdentifier);
          return res.status(500).json({ error: 'Failed to send SMS. Please try again or use email.' });
        }
      } else {
        // Send OTP email (sendEmail function handles mailer initialization internally)
        const otpEmailHtml = `<div style="font-family:sans-serif"><h2>SR CareHive Healthcare Provider Login OTP</h2><p>Your OTP is: <b>${otp}</b></p><p>This OTP is valid for 5 minutes.</p></div>`;
        try {
          console.log('[OTP] Sending OTP email to healthcare provider:', normalizedIdentifier);
          await sendEmail({
            to: normalizedIdentifier,
            subject: 'SR CareHive Healthcare Provider Login OTP',
            html: otpEmailHtml
          });
          console.log('[OTP] OTP email sent successfully to:', normalizedIdentifier);
          return res.json({ success: true, message: resend ? 'OTP resent.' : 'OTP sent.', expiresIn: 300, canResendAfter: 120, deliveryChannels: ['email'] });
        } catch (e) {
          console.error('[OTP] Failed to send OTP email to healthcare provider:', normalizedIdentifier, 'Error:', e.message);
          // Clear stored OTP if email failed
          await deleteOTP(normalizedIdentifier);
          return res.status(500).json({ error: 'Failed to send OTP email. Please try again.' });
        }
      }
    } catch (e) {
      console.error('[OTP] Internal error:', e.message);
      return res.status(500).json({ error: 'Internal error' });
    }
  }

  app.post('/api/nurse/send-otp', async (req, res) => {
    return handleSendOtp(req, res, false);
  });

  // Verify OTP for healthcare provider login
  app.post('/api/nurse/verify-otp', async (req, res) => {
    try {
      const { email, otp } = req.body;
      if (!email || !otp) return res.status(400).json({ error: 'OTP required' });
      
      const identifier = email.trim();
      const isPhoneNumber = /^\d{10}$/.test(identifier.replace(/[^\d]/g, ''));
      const normalizedIdentifier = isPhoneNumber ? identifier.replace(/[^\d]/g, '') : identifier.toLowerCase();
      
      const otpData = await getOTP(normalizedIdentifier);
      if (!otpData) return res.status(400).json({ error: 'No OTP sent or OTP expired.' });
      
      if (Date.now() > otpData.expiresAt) {
        await deleteOTP(normalizedIdentifier);
        return res.status(400).json({ error: 'OTP expired. Please request a new one.' });
      }
      if (otpData.attempts >= 5) {
        await deleteOTP(normalizedIdentifier);
        return res.status(429).json({ error: 'Too many failed attempts. Please request a new OTP.' });
      }
      if (otp !== otpData.otp) {
        otpData.attempts += 1;
        await storeOTP(normalizedIdentifier, otpData);
        return res.status(400).json({ error: `Invalid OTP. ${5 - otpData.attempts} attempt(s) remaining.` });
      }
      
      otpData.verified = true;
      await storeOTP(normalizedIdentifier, otpData);
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
// Removed: const nurseLoginOTPs = new Map(); // Now using Redis/fallback


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
import bcrypt from 'bcryptjs';
import { Redis } from '@upstash/redis';

dotenv.config();

// ===== UPSTASH REDIS CONFIGURATION =====
// Using REST API for serverless compatibility (Vercel)
let redis = null;
let redisEnabled = false;

try {
  if (process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN) {
    redis = new Redis({
      url: process.env.UPSTASH_REDIS_REST_URL,
      token: process.env.UPSTASH_REDIS_REST_TOKEN,
    });
    redisEnabled = true;
    console.log('✅ [REDIS] Connected to Upstash Redis (REST API)');
  } else {
    console.warn('⚠️ [REDIS] Upstash credentials not found - using in-memory fallback');
  }
} catch (error) {
  console.error('❌ [REDIS] Connection failed:', error.message);
  console.warn('⚠️ [REDIS] Falling back to in-memory storage');
}

// Fallback in-memory storage (if Redis unavailable)
const memoryOTPs = new Map();
const memorySessions = new Map();

const app = express();
app.use(express.json());
// Configurable CORS: allow localhost:5173, Vercel, and production frontend
// IMPORTANT: Always allow both srcarehive.com and www.srcarehive.com
const allowedOrigins = [
  'http://localhost:5173',
  'https://srcarehive.com',      // Without www
  'https://www.srcarehive.com',  // With www
  'https://api.srcarehive.com'
];

// Optional: Allow additional origins from env var
const allowedOriginsEnv = (process.env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
if (allowedOriginsEnv.length > 0) {
  allowedOrigins.push(...allowedOriginsEnv);
}
// Log allowed origins on startup
console.log('🌐 CORS Allowed Origins:', allowedOrigins);

app.use(cors({
  origin: (origin, cb) => {
    // Allow requests with no origin (like mobile apps or Postman)
    if (!origin) {
      console.log('✅ CORS: No origin (allowed)');
      return cb(null, true);
    }
    
    // Check if origin is in allowed list
    if (allowedOrigins.includes(origin)) {
      console.log(`✅ CORS: ${origin} (allowed)`);
      return cb(null, true);
    }
    
    // Block unauthorized origins
    console.log(`❌ CORS: ${origin} (blocked)`);
    return cb(new Error('CORS blocked: ' + origin));
  },
  credentials: false
}));

// Security headers middleware
app.use((req, res, next) => {
  // Prevent clickjacking
  res.setHeader('X-Frame-Options', 'DENY');
  // Prevent MIME type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');
  // Enable XSS protection
  res.setHeader('X-XSS-Protection', '1; mode=block');
  // Referrer policy
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

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
let supabaseInitialized = false;
let usingServiceRole = false;

if (process.env.SUPABASE_URL && (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY)) {
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
  if (process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.log('[INIT] ✅ Supabase using SERVICE ROLE key (bypasses RLS)');
    usingServiceRole = true;
  } else {
    console.warn('[INIT] ⚠️  SUPABASE_SERVICE_ROLE_KEY not set. Using ANON key; queries may fail if RLS blocks!');
    usingServiceRole = false;
  }
  supabase = createClient(process.env.SUPABASE_URL, supabaseKey);
  supabaseInitialized = true;
  console.log('[INIT] ✅ Supabase client initialized');
} else {
  console.error('[INIT] ❌ Supabase NOT initialized - missing credentials!');
  console.error('[INIT]    SUPABASE_URL:', process.env.SUPABASE_URL ? '✓' : '✗ MISSING');
  console.error('[INIT]    SUPABASE_SERVICE_ROLE_KEY:', process.env.SUPABASE_SERVICE_ROLE_KEY ? '✓' : '✗ MISSING');
  console.error('[INIT]    SUPABASE_ANON_KEY:', process.env.SUPABASE_ANON_KEY ? '✓' : '✗ MISSING');
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

// ============================================================================
// TUBELIGHT SMS API (JIO TRUECONNECT) - For OTP Sending
// ============================================================================
const TUBELIGHT_USERNAME = (process.env.TUBELIGHT_USERNAME || '').trim();
const TUBELIGHT_PASSWORD = (process.env.TUBELIGHT_PASSWORD || '').trim();
const TUBELIGHT_SENDER_ID = (process.env.TUBELIGHT_SENDER_ID || '').trim();
const TUBELIGHT_ENTITY_ID = (process.env.TUBELIGHT_ENTITY_ID || '').trim();

// Template IDs for different OTP scenarios
const TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID = (process.env.TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID || '').trim();
const TUBELIGHT_LOGIN_OTP_TEMPLATE_ID = (process.env.TUBELIGHT_LOGIN_OTP_TEMPLATE_ID || '').trim();
const TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID = (process.env.TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID || '').trim();
const TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID = (process.env.TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID || '').trim();
const TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID = (process.env.TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID || '').trim();

let tubelightSMSEnabled = false;
if (TUBELIGHT_USERNAME && TUBELIGHT_PASSWORD && TUBELIGHT_SENDER_ID && TUBELIGHT_ENTITY_ID && 
    TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID && TUBELIGHT_LOGIN_OTP_TEMPLATE_ID && 
    TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID && TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID && 
    TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID) {
  tubelightSMSEnabled = true;
  console.log(`[INIT] ✅ Tubelight SMS enabled with all 5 templates`);
} else {
  console.warn('[WARN] ⚠️  Tubelight SMS not fully configured');
  if (!TUBELIGHT_USERNAME || !TUBELIGHT_PASSWORD || !TUBELIGHT_SENDER_ID || !TUBELIGHT_ENTITY_ID) {
    console.warn('[WARN]    Missing credentials or basic config');
  }
  if (!TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID) console.warn('[WARN]    Missing TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID');
  if (!TUBELIGHT_LOGIN_OTP_TEMPLATE_ID) console.warn('[WARN]    Missing TUBELIGHT_LOGIN_OTP_TEMPLATE_ID');
  if (!TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID) console.warn('[WARN]    Missing TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID');
  if (!TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID) console.warn('[WARN]    Missing TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID');
  if (!TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID) console.warn('[WARN]    Missing TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID');
}

// ============================================================================
// TUBELIGHT API TOKEN MANAGEMENT (Bearer Authentication)
// ============================================================================
let tubelightAuthToken = null;
let tubelightTokenExpiry = null;

/**
 * Get valid Tubelight Bearer token (login if needed)
 * Based on Tubelight API v2.1 documentation - Login API
 */
async function getTubelightAuthToken() {
  // Check if we have a valid token
  if (tubelightAuthToken && tubelightTokenExpiry && Date.now() < tubelightTokenExpiry) {
    console.log('[TUBELIGHT-AUTH] ✅ Using cached token');
    return tubelightAuthToken;
  }

  // Login to get new token
  console.log('[TUBELIGHT-AUTH] 🔑 Logging in to get Bearer token...');
  
  const loginUrl = 'https://portal.tubelightcommunications.com/api/authentication/login';
  const loginBody = {
    username: TUBELIGHT_USERNAME,
    password: TUBELIGHT_PASSWORD,
    validityTime: '1460', // Token validity in minutes (24 hours)
  };

  try {
    const response = await fetch(loginUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify(loginBody),
    });

    if (!response.ok) {
      console.error(`[TUBELIGHT-AUTH] ❌ Login failed with status: ${response.status}`);
      return null;
    }

    const data = await response.json();
    
    if (data.accessToken) {
      tubelightAuthToken = data.accessToken;
      // Set expiry to 23 hours (1380 minutes) to be safe
      tubelightTokenExpiry = Date.now() + (1380 * 60 * 1000);
      console.log('[TUBELIGHT-AUTH] ✅ Login successful, token acquired');
      console.log(`[TUBELIGHT-AUTH] 📅 Token valid until: ${new Date(tubelightTokenExpiry).toLocaleString()}`);
      return tubelightAuthToken;
    } else {
      console.error('[TUBELIGHT-AUTH] ❌ No accessToken in response:', JSON.stringify(data));
      return null;
    }
  } catch (error) {
    console.error('[TUBELIGHT-AUTH] ❌ Login error:', error.message);
    return null;
  }
}

/**
 * Send OTP via Tubelight SMS API with specific template
 * Based on Tubelight API v2.1 documentation - Send SMS API
 * @param {string} phoneNumber - 10 digit phone number
 * @param {string} otp - OTP code
 * @param {string} recipientName - Name of recipient
 * @param {string} templateId - Template ID for the specific OTP type
 * @param {string} messageContext - Context for message (e.g., 'registration', 'login', 'password reset')
 * @returns {boolean} - Success status
 */
async function sendOTPViaTubelight(phoneNumber, otp, recipientName = 'User', templateId = '', messageContext = 'verification') {
  if (!tubelightSMSEnabled) {
    console.log('[TUBELIGHT-SMS] ⚠️  SMS not configured');
    return false;
  }

  if (!templateId) {
    console.error('[TUBELIGHT-SMS] ❌ Template ID is required');
    return false;
  }

  try {
    const cleanPhone = phoneNumber.replace(/[^\d]/g, '');
    if (cleanPhone.length !== 10) {
      console.error(`[TUBELIGHT-SMS] ❌ Invalid phone: ${phoneNumber}`);
      return false;
    }

    const fullPhoneNumber = `91${cleanPhone}`;
    
    // Construct message based on template type
    // The actual message content MUST EXACTLY match the approved DLT template
    let message = '';
    let validity = '2 minutes'; // Default
    
    if (templateId === TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID) {
      // Template: "Dear {#var#}, your OTP for Serechi registration is {#var#}. Valid for 2 minutes. Do not share. - SERECH"
      validity = '2 minutes';
      message = `Dear ${recipientName}, your OTP for Serechi registration is ${otp}. Valid for 2 minutes. Do not share. - SERECH`;
    } else if (templateId === TUBELIGHT_LOGIN_OTP_TEMPLATE_ID) {
      // Template: "Dear {#var#}, your OTP for Serechi (SR CareHive) login is {#var#}. Valid for 10 minutes. Do not share. - SERECH"
      validity = '10 minutes';
      message = `Dear ${recipientName}, your OTP for Serechi (SR CareHive) login is ${otp}. Valid for 10 minutes. Do not share. - SERECH`;
    } else if (templateId === TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID) {
      // Template: "Dear {#var#}, your OTP for Serechi password reset is {#var#}. Valid for 10 minutes. Do not share. - SERECH"
      validity = '10 minutes';
      message = `Dear ${recipientName}, your OTP for Serechi password reset is ${otp}. Valid for 10 minutes. Do not share. - SERECH`;
    } else if (templateId === TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID) {
      // Template: "Dear Healthcare Provider, your OTP for Serechi (SR CareHive) login is {#var#}. Valid for 5 minutes. Do not share. - SERECH"
      validity = '5 minutes';
      message = `Dear Healthcare Provider, your OTP for Serechi (SR CareHive) login is ${otp}. Valid for 5 minutes. Do not share. - SERECH`;
    } else if (templateId === TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID) {
      // Template: "Dear Healthcare Provider, your OTP for Serechi password reset is {#var#}. Valid for 10 minutes. Do not share. - SERECH"
      validity = '10 minutes';
      message = `Dear Healthcare Provider, your OTP for Serechi password reset is ${otp}. Valid for 10 minutes. Do not share. - SERECH`;
    } else {
      console.error(`[TUBELIGHT-SMS] ❌ Unknown template ID: ${templateId}`);
      return false;
    }

    // ========================================================================
    // TUBELIGHT SMS API v2.1 - CORRECT IMPLEMENTATION
    // ========================================================================
    // Based on official Tubelight API v2.1 documentation
    // Uses Bearer token authentication + POST request with JSON body
    
    console.log(`[TUBELIGHT-SMS] 📤 Sending ${messageContext} OTP to: ${fullPhoneNumber.slice(0,6)}***`);
    console.log(`[TUBELIGHT-SMS] 📝 Template ID: ${templateId}`);
    console.log(`[TUBELIGHT-SMS] 🏢 Entity ID: ${TUBELIGHT_ENTITY_ID}`);

    // Step 1: Get Bearer token (login if needed)
    const authToken = await getTubelightAuthToken();
    if (!authToken) {
      console.error('[TUBELIGHT-SMS] ❌ Failed to get authentication token');
      console.error('[TUBELIGHT-SMS] 🔧 Please check:');
      console.error('[TUBELIGHT-SMS]    - Username and password are correct');
      console.error('[TUBELIGHT-SMS]    - Account is active in Tubelight portal');
      console.error('[TUBELIGHT-SMS]    - Network connectivity to portal.tubelightcommunications.com');
      return false;
    }

    // Step 2: Send SMS using correct API endpoint and format
    const smsUrl = 'https://portal.tubelightcommunications.com/sms/api/v1/webhms/single';
    
    // Prepare request body as per Tubelight API v2.1 specification
    const requestBody = {
      sender: TUBELIGHT_SENDER_ID,        // "SERECH"
      mobileNo: fullPhoneNumber,          // "919876543210"
      messageType: 'TEXT',                // Always TEXT for OTP
      messages: message,                   // Full OTP message matching DLT template
      tempId: templateId,                 // DLT Template ID
      peId: TUBELIGHT_ENTITY_ID,          // DLT Entity ID
      cust_uuid: `${Date.now()}_${cleanPhone}`, // Unique ID for tracking
    };

    console.log('[TUBELIGHT-SMS] 🚀 Sending SMS request...');
    console.log(`[TUBELIGHT-SMS] 📍 Endpoint: ${smsUrl}`);
    console.log(`[TUBELIGHT-SMS] 📦 Payload: ${JSON.stringify({...requestBody, messages: requestBody.messages.substring(0, 50) + '...'})}`);

    try {
      const response = await fetch(smsUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': `Bearer ${authToken}`,
        },
        body: JSON.stringify(requestBody),
      });

      const contentType = response.headers.get('content-type') || '';
      
      // Check if we got HTML (error/login page)
      if (contentType.includes('text/html')) {
        const htmlText = await response.text();
        console.error('[TUBELIGHT-SMS] ❌ Received HTML response instead of JSON');
        console.error('[TUBELIGHT-SMS] ⚠️  This indicates:');
        console.error('[TUBELIGHT-SMS]    - Token expired or invalid');
        console.error('[TUBELIGHT-SMS]    - IP not whitelisted');
        console.error('[TUBELIGHT-SMS]    - Account issue');
        console.error(`[TUBELIGHT-SMS] Response preview: ${htmlText.substring(0, 200)}`);
        
        // Clear token to force re-login next time
        tubelightAuthToken = null;
        tubelightTokenExpiry = null;
        return false;
      }

      // Parse JSON response
      const responseData = await response.json();
      console.log('[TUBELIGHT-SMS] 📡 Response received:', JSON.stringify(responseData));

      // Check for success
      if (response.ok && (responseData.message === 'Message Sent Successfully' || 
          responseData.message === 'Message Queued Successfully' ||
          responseData.messageId)) {
        console.log('[TUBELIGHT-SMS] ✅ SMS sent successfully!');
        if (responseData.messageId) {
          console.log(`[TUBELIGHT-SMS] 📬 Message ID: ${responseData.messageId}`);
        }
        return true;
      } else {
        console.error('[TUBELIGHT-SMS] ❌ SMS sending failed');
        console.error(`[TUBELIGHT-SMS] Status: ${response.status}`);
        console.error(`[TUBELIGHT-SMS] Response: ${JSON.stringify(responseData)}`);
        return false;
      }

    } catch (error) {
      console.error('[TUBELIGHT-SMS] ❌ Network/Fetch Error:', error.message);
      console.error('[TUBELIGHT-SMS] 🔧 Check:');
      console.error('[TUBELIGHT-SMS]    - Internet connectivity');
      console.error('[TUBELIGHT-SMS]    - Tubelight API server status');
      console.error('[TUBELIGHT-SMS]    - Firewall/proxy settings');
      return false;
    }

  } catch (error) {
    console.error(`[TUBELIGHT-SMS] ❌ Error:`, error.message);
    return false;
  }
}

let mailer = null;
let mailerReady = false;

// Initialize mailer with proper verification
async function initializeMailer() {
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) {
    console.error('[INIT] ❌ SMTP NOT CONFIGURED!');
    console.error('[INIT] ⚠️  Missing environment variables:');
    console.error('[INIT]    SMTP_HOST:', SMTP_HOST ? '✓' : '✗ MISSING');
    console.error('[INIT]    SMTP_PORT:', SMTP_PORT ? '✓' : '✗ MISSING');  
    console.error('[INIT]    SMTP_USER:', SMTP_USER ? '✓' : '✗ MISSING');
    console.error('[INIT]    SMTP_PASS:', SMTP_PASS ? '✓' : '✗ MISSING');
    console.error('[INIT] 📝 Set these in Vercel environment variables!');
    return false;
  }

  try {
    console.log('[INIT] 🔧 Configuring email transport...');
    console.log('[INIT] SMTP_HOST:', SMTP_HOST);
    console.log('[INIT] SMTP_PORT:', SMTP_PORT);
    console.log('[INIT] SMTP_USER:', SMTP_USER);
    console.log('[INIT] SMTP_SECURE:', SMTP_SECURE);
    console.log('[INIT] SENDER_EMAIL:', SENDER_EMAIL);
    console.log('[INIT] SENDER_NAME:', SENDER_NAME);
    
    mailer = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: SMTP_SECURE,
      auth: { 
        user: SMTP_USER, 
        pass: SMTP_PASS 
      },
      tls: {
        rejectUnauthorized: false
      },
      debug: false,
      logger: false
    });
    
    // Verify connection synchronously
    console.log('[INIT] 🔍 Verifying SMTP connection...');
    await mailer.verify();
    
    console.log('[INIT] ✅ Email transport verified and ready!');
    console.log('[INIT] ✅ Emails will be sent from:', SENDER_EMAIL);
    mailerReady = true;
    return true;
    
  } catch (e) {
    console.error('[INIT] ❌ Email transport verification FAILED!');
    console.error('[INIT] ❌ Error:', e.message);
    console.error('[INIT] ⚠️  Emails will NOT be sent!');
    mailer = null;
    mailerReady = false;
    return false;
  }
}

// Initialize mailer on startup
// Use top-level await for serverless (blocks until ready)
let mailerInitPromise = null;

// Start initialization immediately
mailerInitPromise = initializeMailer().then(success => {
  if (success) {
    console.log('[INIT] 📧 Email service is READY');
  } else {
    console.error('[INIT] 📧 Email service is NOT available');
  }
  return success;
});

// Helper to ensure mailer is ready
async function ensureMailerReady() {
  if (mailerInitPromise) {
    await mailerInitPromise;
    mailerInitPromise = null; // Clear after first use
  }
  return mailerReady;
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
  // Lazy initialization - ensure mailer is ready before sending
  if (!mailer || !mailerReady) {
    console.log('[EMAIL] ⚠️ Mailer not ready, attempting to initialize...');
    const success = await initializeMailer();
    if (!success) {
      const error = new Error('Email transport not configured. Please contact administrator.');
      console.error('[EMAIL] ❌ Transport initialization failed. Cannot send to:', to);
      throw error;
    }
  }
  
  try {
    const from = `${SENDER_NAME} <${SENDER_EMAIL}>`;
    console.log(`[EMAIL] 📧 Attempting to send email...`);
    console.log(`[EMAIL] To: ${to}`);
    console.log(`[EMAIL] Subject: ${subject}`);
    console.log(`[EMAIL] From: ${from}`);
    console.log(`[EMAIL] SMTP Host: ${SMTP_HOST}`);
    console.log(`[EMAIL] SMTP Port: ${SMTP_PORT}`);
    console.log(`[EMAIL] SMTP User: ${SMTP_USER}`);
    console.log(`[EMAIL] SMTP Secure: ${SMTP_SECURE}`);
    
    const info = await mailer.sendMail({ from, to, subject, html, attachments });
    
    console.log(`[EMAIL] ✅ Email sent successfully!`);
    console.log(`[EMAIL] Message ID: ${info.messageId}`);
    console.log(`[EMAIL] Response: ${info.response}`);
    console.log(`[EMAIL] Accepted: ${info.accepted}`);
    console.log(`[EMAIL] Rejected: ${info.rejected}`);
    
    return info;
  } catch (error) {
    console.error(`[EMAIL] ❌ Failed to send email to ${to}`);
    console.error(`[EMAIL] Error name: ${error.name}`);
    console.error(`[EMAIL] Error message: ${error.message}`);
    console.error(`[EMAIL] Error code: ${error.code}`);
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
        <p>— Serechi</p>
      </div>`;

    if (patientEmail) await sendEmail({ to: patientEmail, subject, html, attachments: attach });
    
    // NOTE: Admin notifications are sent separately via /api/notify-registration-payment
    // to avoid duplicate emails. This function only sends patient confirmation.
    console.log('[EMAIL] Patient confirmation sent. Admin notification will be sent via notification endpoint.');
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
        <p style="color: #2260FF; font-weight: bold;">Next Step: Please pay your registration fee of ₹10 to confirm your booking.</p>
        <p>You can pay and view your appointment in the app by clicking the button below:</p>
  <a href="${(process.env.WEB_FRONTEND_URL || `carehive://appointments?aid=${appointment.id}`)}" style="display:inline-block;padding:10px 20px;background:#2260FF;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;">View & Pay in App</a>
        <p>— Serechi</p>
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
        <p>— Serechi</p>
      </div>`;
    await sendEmail({ to, subject: 'Your healthcare provider appointment was rejected', html, attachments });
  } catch (e) {
    console.error('[EMAIL] reject email failed', e.message);
  }
}

// Comprehensive admin notification with ALL healthcare seeker details
async function sendAdminNotification({ appointment, type, paymentDetails = null }) {
  try {
    console.log('[ADMIN_EMAIL] ='.repeat(30));
    console.log(`[ADMIN_EMAIL] Preparing ${type} notification`);
    console.log('[ADMIN_EMAIL] Full appointment object:', JSON.stringify(appointment, null, 2));
    console.log('[ADMIN_EMAIL] ='.repeat(30));
    
    const adminHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 700px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
        <div style="background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%); padding: 25px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 26px;">
            ${type === 'NEW_APPOINTMENT' ? 'New Appointment Request' : 
              type === 'REGISTRATION_PAYMENT' ? 'Registration Payment Received (₹10)' :
              type === 'PRE_VISIT_PAYMENT' ? 'Pre-Visit Payment Received (50%)' :
              type === 'FINAL_PAYMENT' ? 'Final Payment Received (50%)' : 'Admin Notification'}
          </h1>
        </div>
        
        <div style="background: white; padding: 25px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #ffc107;">
            <p style="margin: 0; color: #856404; font-size: 16px; font-weight: bold;">
              ${type === 'NEW_APPOINTMENT' ? 'Action Required: Review and assign healthcare provider' :
                type === 'REGISTRATION_PAYMENT' ? 'Healthcare seeker paid registration fee - Review appointment' :
                type === 'PRE_VISIT_PAYMENT' ? 'Healthcare seeker ready for appointment - Proceed with visit' :
                type === 'FINAL_PAYMENT' ? 'Service completed - All payments received!' :
                type === 'VISIT_COMPLETED' ? 'Visit completed - Final payment enabled for healthcare seeker' : ''}
            </p>
          </div>

          ${paymentDetails ? `
          <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #4caf50;">
            <h3 style="margin-top: 0; color: #2e7d32;">Payment Information</h3>
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
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.full_name || '-'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Age:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.age || '-'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Gender:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.gender || '-'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Healthcare seeker Type:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.patient_type || '-'}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;"><strong>Aadhar Number:</strong></td>
                <td style="padding: 8px 0; border-bottom: 1px solid #ddd;">${appointment?.aadhar_number || '-'}</td>
              </tr>
            </table>
          </div>

          <div style="background: #fce4ec; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #c2185b;">Contact Details</h3>
            <p style="margin: 8px 0;"><strong>Phone:</strong> <a href="tel:${appointment?.phone}">${appointment?.phone || '-'}</a></p>
            <p style="margin: 8px 0;"><strong>Email:</strong> <a href="mailto:${appointment?.patient_email}">${appointment?.patient_email || '-'}</a></p>
            <p style="margin: 8px 0;"><strong>Address:</strong> ${appointment?.address || '-'}</p>
            <p style="margin: 8px 0;"><strong>Emergency Contact:</strong> ${appointment?.emergency_contact || '-'}</p>
          </div>

          <div style="background: #f3e5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #7b1fa2;">Medical Information</h3>
            <p style="margin: 8px 0;"><strong>Problem/Symptoms:</strong></p>
            <p style="background: white; padding: 12px; border-radius: 6px; margin: 8px 0;">${appointment?.problem || '-'}</p>
            ${appointment?.primary_doctor_name ? `
            <p style="margin: 8px 0;"><strong>Primary Doctor:</strong> ${appointment.primary_doctor_name}</p>
            ${appointment?.primary_doctor_phone ? `<p style="margin: 8px 0;"><strong>Doctor Phone:</strong> ${appointment.primary_doctor_phone}</p>` : ''}
            ${appointment?.primary_doctor_location ? `<p style="margin: 8px 0;"><strong>Doctor Location:</strong> ${appointment.primary_doctor_location}</p>` : ''}
            ` : '<p style="margin: 8px 0; color: #999;">No primary doctor information provided</p>'}
          </div>

          <div style="background: #e8eaf6; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #3f51b5;">Appointment Schedule</h3>
            <p style="margin: 8px 0;"><strong>Date:</strong> ${appointment?.date || '-'}</p>
            <p style="margin: 8px 0;"><strong>Time:</strong> ${appointment?.time || '-'}</p>
            <p style="margin: 8px 0;"><strong>Appointment ID:</strong> #${appointment?.id || '-'}</p>
            <p style="margin: 8px 0;"><strong>Status:</strong> <span style="background: #ffeb3b; padding: 4px 10px; border-radius: 4px; font-weight: bold;">${appointment?.status || 'Pending'}</span></p>
          </div>

          ${appointment?.nurse_name ? `
          <div style="background: #e0f2f1; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #00796b;">Assigned Healthcare provider</h3>
            <p style="margin: 8px 0;"><strong>Name:</strong> ${appointment.nurse_name}</p>
            <p style="margin: 8px 0;"><strong>Phone:</strong> ${appointment.nurse_phone || '-'}</p>
            <p style="margin: 8px 0;"><strong>Branch:</strong> ${appointment.nurse_branch || '-'}</p>
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
        subject: `${subjectPrefix} - Appointment #${appointment?.id || 'N/A'} - ${appointment?.full_name || 'Healthcare Seeker'}`, 
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
// Removed: const nurseSessions = new Map(); // Now using Redis/fallback
const NURSE_EMAIL = (process.env.NURSE_ADMIN_EMAIL || '').trim().toLowerCase();
const NURSE_PASSWORD = (process.env.NURSE_ADMIN_PASSWORD || '').trim();
const SESSION_TTL_MS = 12 * 60 * 60 * 1000; // 12h

// ===== REDIS HELPER FUNCTIONS =====

// OTP Storage Functions
async function storeOTP(email, otpData) {
  const key = `otp:${email}`;
  const ttl = 300; // 5 minutes in seconds
  
  try {
    if (redisEnabled) {
      await redis.setex(key, ttl, JSON.stringify(otpData));
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] storeOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  memoryOTPs.set(email, otpData);
  return true;
}

async function getOTP(email) {
  const key = `otp:${email}`;
  
  try {
    if (redisEnabled) {
      const data = await redis.get(key);
      return data ? (typeof data === 'string' ? JSON.parse(data) : data) : null;
    }
  } catch (error) {
    console.error('❌ [REDIS] getOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  return memoryOTPs.get(email) || null;
}

async function deleteOTP(email) {
  const key = `otp:${email}`;
  
  try {
    if (redisEnabled) {
      await redis.del(key);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] deleteOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  memoryOTPs.delete(email);
  return true;
}

// Session Storage Functions
async function createSession() {
  const token = crypto.randomBytes(32).toString('hex');
  const sessionData = { createdAt: Date.now() };
  const key = `session:${token}`;
  const ttl = Math.floor(SESSION_TTL_MS / 1000); // Convert to seconds
  
  try {
    if (redisEnabled) {
      await redis.setex(key, ttl, JSON.stringify(sessionData));
      return token;
    }
  } catch (error) {
    console.error('❌ [REDIS] createSession failed:', error.message);
  }
  
  // Fallback to in-memory
  memorySessions.set(token, sessionData);
  return token;
}

async function getSession(token) {
  const key = `session:${token}`;
  
  try {
    if (redisEnabled) {
      const data = await redis.get(key);
      return data ? (typeof data === 'string' ? JSON.parse(data) : data) : null;
    }
  } catch (error) {
    console.error('❌ [REDIS] getSession failed:', error.message);
  }
  
  // Fallback to in-memory
  const rec = memorySessions.get(token);
  if (!rec) return null;
  
  // Check expiry for in-memory sessions
  if (Date.now() - rec.createdAt > SESSION_TTL_MS) {
    memorySessions.delete(token);
    return null;
  }
  
  return rec;
}

async function isAuthed(req) {
  const h = req.headers['authorization'] || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return false;
  
  const rec = await getSession(token);
  if (!rec) return false;
  
  // Redis handles TTL automatically, but check for in-memory fallback
  if (Date.now() - rec.createdAt > SESSION_TTL_MS) {
    return false;
  }
  
  return true;
}

// Password Reset OTP Storage Functions
async function storePasswordResetOTP(email, otpData) {
  const key = `password-reset-otp:${email}`;
  const ttl = 600; // 10 minutes in seconds
  
  try {
    if (redisEnabled) {
      await redis.setex(key, ttl, JSON.stringify(otpData));
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] storePasswordResetOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  passwordResetOTPs.set(email, otpData);
  return true;
}

async function getPasswordResetOTP(email) {
  const key = `password-reset-otp:${email}`;
  
  try {
    if (redisEnabled) {
      const data = await redis.get(key);
      return data ? (typeof data === 'string' ? JSON.parse(data) : data) : null;
    }
  } catch (error) {
    console.error('❌ [REDIS] getPasswordResetOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  return passwordResetOTPs.get(email) || null;
}

async function deletePasswordResetOTP(email) {
  const key = `password-reset-otp:${email}`;
  
  try {
    if (redisEnabled) {
      await redis.del(key);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] deletePasswordResetOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  passwordResetOTPs.delete(email);
  return true;
}

// Provider Password Reset OTP Storage Functions
async function storeProviderPasswordResetOTP(email, otpData) {
  const key = `provider-password-reset-otp:${email}`;
  const ttl = 600; // 10 minutes in seconds
  
  try {
    if (redisEnabled) {
      await redis.setex(key, ttl, JSON.stringify(otpData));
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] storeProviderPasswordResetOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  providerPasswordResetOTPs.set(email, otpData);
  return true;
}

async function getProviderPasswordResetOTP(email) {
  const key = `provider-password-reset-otp:${email}`;
  
  try {
    if (redisEnabled) {
      const data = await redis.get(key);
      return data ? (typeof data === 'string' ? JSON.parse(data) : data) : null;
    }
  } catch (error) {
    console.error('❌ [REDIS] getProviderPasswordResetOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  return providerPasswordResetOTPs.get(email) || null;
}

async function deleteProviderPasswordResetOTP(email) {
  const key = `provider-password-reset-otp:${email}`;
  
  try {
    if (redisEnabled) {
      await redis.del(key);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] deleteProviderPasswordResetOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  providerPasswordResetOTPs.delete(email);
  return true;
}

app.post('/api/nurse/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    console.log('🔐 Healthcare Provider Login Attempt:', { identifier: email, hasPassword: !!password });
    
    if (!email || !password) {
      console.log('❌ Missing identifier or password');
      return res.status(400).json({ success: false, error: 'Email/Phone and password required' });
    }
    
    const identifier = email.trim();
    const normalizedEmail = email.toLowerCase().trim();
    
    // Detect if input is phone number (10 digits)
    const isPhoneNumber = /^\d{10}$/.test(identifier.replace(/[^\d]/g, ''));
    console.log('📱 Input type:', isPhoneNumber ? 'Phone Number' : 'Email');
    
    // Check if super admin credentials (only for email)
    if (!isPhoneNumber && NURSE_EMAIL && NURSE_PASSWORD && normalizedEmail === NURSE_EMAIL && password === NURSE_PASSWORD) {
      const token = await createSession();
      console.log('✅ Super Admin Login Successful');
      return res.json({ success: true, token, isSuperAdmin: true });
    }
    
    // Check healthcare_providers table for regular providers
    if (!supabase) {
      console.error('❌ Supabase not configured');
      return res.status(500).json({ success: false, error: 'Database not configured' });
    }
    
    // Query by email OR phone number (mobile_number or alternative_mobile)
    let query = supabase
      .from('healthcare_providers')
      .select('*');
    
    if (isPhoneNumber) {
      const cleanPhone = identifier.replace(/[^\d]/g, '');
      query = query.or(`mobile_number.eq.${cleanPhone},alternative_mobile.eq.${cleanPhone}`);
    } else {
      query = query.eq('email', normalizedEmail);
    }
    
    const { data: provider, error } = await query.maybeSingle();
    
    if (error) {
      console.error('❌ Error fetching provider:', error.message);
      return res.status(500).json({ success: false, error: 'Database error' });
    }
    
    if (!provider) {
      console.log('❌ Provider not found');
      return res.status(401).json({ success: false, error: 'Invalid credentials! Email/Phone or password is incorrect.' });
    }
    
    console.log('📋 Provider found - verifying credentials');
    
    // Verify password - support both bcrypt and legacy SHA-256
    const storedPasswordHash = provider.password_hash;
    
    if (!storedPasswordHash) {
      console.error('❌ No password hash stored');
      return res.status(500).json({ success: false, error: 'Account configuration error. Please contact support.' });
    }
    
    let isPasswordValid = false;
    
    // Try bcrypt first (for newly reset passwords)
    if (storedPasswordHash.startsWith('$2a$') || storedPasswordHash.startsWith('$2b$')) {
      console.log('🔐 Using bcrypt verification');
      isPasswordValid = await bcrypt.compare(password, storedPasswordHash);
    } else {
      // Legacy SHA-256 verification (for existing registrations)
      console.log('🔐 Using legacy SHA-256 verification');
      const hashedInputPassword = crypto.createHash('sha256').update(password).digest('hex');
      isPasswordValid = (storedPasswordHash === hashedInputPassword);
    }
    
    if (!isPasswordValid) {
      console.log('❌ Password mismatch');
      return res.status(401).json({ success: false, error: 'Invalid credentials! Email/Phone or password is incorrect.' });
    }
    
    // Password is correct - check application status
    const status = provider.application_status || 'pending';
    console.log('✅ Password Verified. Application Status:', status);
    
    // Status: REJECTED
    if (status === 'rejected') {
      console.log('❌ Application is REJECTED');
      return res.json({ 
        success: false,
        rejected: true, 
        providerData: provider  // ✅ Send COMPLETE provider data
      });
    }
    
    // Status: PENDING, UNDER_REVIEW, ON_HOLD
    if (status === 'pending' || status === 'under_review' || status === 'on_hold') {
      console.log('⏳ Application is PENDING/UNDER_REVIEW/ON_HOLD');
      return res.json({ 
        success: false,
        pending: true, 
        providerData: provider  // ✅ Send COMPLETE provider data
      });
    }
    
    // Status: APPROVED
    if (status === 'approved') {
      console.log('✅ Application is APPROVED - Creating session');
      const token = await createSession();
      return res.json({ 
        success: true, 
        token, 
        providerData: {
          id: provider.id,
          full_name: provider.full_name,
          email: provider.email,
          mobile_number: provider.mobile_number,
          alternative_mobile: provider.alternative_mobile,
          application_status: provider.application_status,
          professional_role: provider.professional_role,
          city: provider.city
        }
      });
    }
    
    // Unknown status
    console.log('⚠️ Unknown application status:', status);
    return res.status(500).json({ success: false, error: 'Invalid application status. Please contact support.' });
    
  } catch (e) {
    console.error('❌ Login error:', e.message, e.stack);
    return res.status(500).json({ success: false, error: 'Internal server error. Please try again later.' });
  }
});

// Send approval email to provider
app.post('/api/provider/send-approval-email', async (req, res) => {
  try {
    const { userEmail, userName, professionalRole, adminComments } = req.body || {};
    if (!userEmail || !userName) {
      return res.status(400).json({ error: 'userEmail and userName required' });
    }

    const commentsSection = adminComments 
      ? `<div style="background: #e7f3ff; border-left: 4px solid #2260FF; padding: 15px; margin: 20px 0;">
           <h3 style="margin-top: 0; color: #2260FF;">Message from Hiring Team:</h3>
           <p style="margin: 0; color: #333; line-height: 1.6;">${adminComments}</p>
         </div>`
      : '';

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1A4FCC 100%); padding: 30px; border-radius: 10px 10px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🎉 Congratulations!</h1>
        </div>
        <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
          <p style="font-size: 16px; color: #333;">Dear <strong>${userName}</strong>,</p>
          
          <p style="font-size: 16px; color: #333; line-height: 1.6;">
            We are pleased to inform you that your application for <strong>${professionalRole}</strong> has been <span style="color: #28a745; font-weight: bold;">APPROVED</span>! 
          </p>
          
          ${commentsSection}
          
          <div style="background: #f0f8ff; border-left: 4px solid #2260FF; padding: 15px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #2260FF;">Your Login Credentials:</h3>
            <p style="margin: 5px 0;"><strong>Email:</strong> ${userEmail}</p>
            <p style="margin: 5px 0;"><strong>Password:</strong> Use the password you set during registration</p>
          </div>

          <p style="font-size: 16px; color: #333; line-height: 1.6;">
            You can now login to the <strong>Healthcare Provider Dashboard</strong> using your registered email and password. After entering your credentials, you will receive an OTP for verification.
          </p>

          <div style="text-align: center; margin: 30px 0;">
            <a href="https://srcarehive.com/provider-login" style="background: #2260FF; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Login to Dashboard</a>
          </div>

          <p style="font-size: 14px; color: #666; line-height: 1.6;">
            Welcome to SR CareHive! We look forward to working with you to provide quality healthcare services.
          </p>

          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
          
          <p style="font-size: 13px; color: #999;">
            For any questions or support, contact us at <a href="mailto:contact@srcarehive.com" style="color: #2260FF;">contact@srcarehive.com</a>
          </p>
        </div>
      </div>
    `;

    await sendEmail({
      to: userEmail,
      subject: '✅ Your SR CareHive Application Has Been Approved!',
      html: emailHtml
    });

    res.json({ success: true, message: 'Approval email sent' });
  } catch (e) {
    console.error('Error sending approval email:', e);
    res.status(500).json({ error: 'Failed to send approval email' });
  }
});

// Send rejection email to provider
app.post('/api/provider/send-rejection-email', async (req, res) => {
  try {
    const { userEmail, userName, rejectionReason } = req.body || {};
    if (!userEmail || !userName) {
      return res.status(400).json({ error: 'userEmail and userName required' });
    }

    const reasonSection = rejectionReason 
      ? `<div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
           <h3 style="margin-top: 0; color: #856404;">Reason for Rejection:</h3>
           <p style="margin: 0; color: #856404;">${rejectionReason}</p>
         </div>`
      : '';

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: #dc3545; padding: 30px; border-radius: 10px 10px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Application Status Update</h1>
        </div>
        <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
          <p style="font-size: 16px; color: #333;">Dear <strong>${userName}</strong>,</p>
          
          <p style="font-size: 16px; color: #333; line-height: 1.6;">
            Thank you for your interest in joining SR CareHive. After careful review of your application, we regret to inform you that we are unable to approve your application at this time.
          </p>

          ${reasonSection}

          <p style="font-size: 16px; color: #333; line-height: 1.6;">
            We appreciate the time and effort you put into your application. If you believe this was an error or would like to reapply in the future, please don't hesitate to contact our support team.
          </p>

          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
          
          <p style="font-size: 13px; color: #999;">
            For any questions or support, contact us at <a href="mailto:contact@srcarehive.com" style="color: #dc3545;">contact@srcarehive.com</a>
          </p>
        </div>
      </div>
    `;

    await sendEmail({
      to: userEmail,
      subject: 'SR CareHive Application Status Update',
      html: emailHtml
    });

    res.json({ success: true, message: 'Rejection email sent' });
  } catch (e) {
    console.error('Error sending rejection email:', e);
    res.status(500).json({ error: 'Failed to send rejection email' });
  }
});

// Send registration notification to admin emails
app.post('/api/provider/send-registration-notification', async (req, res) => {
  try {
    const { providerData, adminEmails } = req.body || {};
    
    if (!providerData) {
      return res.status(400).json({ error: 'providerData is required' });
    }

    const {
      full_name,
      mobile_number,
      alternative_mobile,
      email,
      city,
      professional_role,
      other_profession,
      doctor_specialty,
      highest_qualification,
      completion_year,
      registration_number,
      current_work_role,
      workplace,
      years_of_experience,
      services_offered,
      availability_days,
      time_slots,
      community_experience,
      languages,
      service_areas,
      home_visit_fee,
      teleconsultation_fee,
      submitted_at
    } = providerData;

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1A4FCC 100%); padding: 30px; border-radius: 10px 10px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🆕 New Healthcare Provider Registration</h1>
        </div>
        <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
          
          <div style="background: #f0f8ff; border-left: 4px solid #2260FF; padding: 15px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #2260FF;">📋 Basic Information</h3>
            <p style="margin: 5px 0;"><strong>Full Name:</strong> ${full_name || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Email:</strong> ${email || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Mobile:</strong> ${mobile_number || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Alternative Mobile:</strong> ${alternative_mobile || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>City:</strong> ${city || 'Not provided'}</p>
          </div>

          <div style="background: #fff8e1; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #f57c00;">👨‍⚕️ Professional Details</h3>
            <p style="margin: 5px 0;"><strong>Role:</strong> ${professional_role || 'Not provided'}</p>
            ${professional_role === 'Other Allied Health Professional' ? `<p style="margin: 5px 0;"><strong>Other Profession:</strong> ${other_profession || 'Not provided'}</p>` : ''}
            ${professional_role === 'Doctor' ? `<p style="margin: 5px 0;"><strong>Specialty:</strong> ${doctor_specialty || 'Not provided'}</p>` : ''}
            <p style="margin: 5px 0;"><strong>Qualification:</strong> ${highest_qualification || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Completion Year:</strong> ${completion_year || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Registration Number:</strong> ${registration_number || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Current Role:</strong> ${current_work_role || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Workplace:</strong> ${workplace || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Experience:</strong> ${years_of_experience || 'Not provided'} years</p>
          </div>

          <div style="background: #e8f5e9; border-left: 4px solid #4caf50; padding: 15px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #2e7d32;">💼 Service Information</h3>
            <p style="margin: 5px 0;"><strong>Services Offered:</strong> ${Array.isArray(services_offered) ? services_offered.join(', ') : (services_offered || 'Not provided')}</p>
            <p style="margin: 5px 0;"><strong>Availability:</strong> ${Array.isArray(availability_days) ? availability_days.join(', ') : (availability_days || 'Not provided')}</p>
            <p style="margin: 5px 0;"><strong>Time Slots:</strong> ${Array.isArray(time_slots) ? time_slots.join(', ') : (time_slots || 'Not provided')}</p>
            <p style="margin: 5px 0;"><strong>Languages:</strong> ${Array.isArray(languages) ? languages.join(', ') : (languages || 'Not provided')}</p>
            <p style="margin: 5px 0;"><strong>Service Areas:</strong> ${service_areas || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Home Visit Fee:</strong> ₹${home_visit_fee || 'Not provided'}</p>
            <p style="margin: 5px 0;"><strong>Teleconsultation Fee:</strong> ₹${teleconsultation_fee || 'Not provided'}</p>
            ${community_experience && community_experience !== 'Not provided' ? `<p style="margin: 5px 0;"><strong>Community Experience:</strong> ${community_experience}</p>` : ''}
          </div>

          <div style="background: #fce4ec; border-left: 4px solid #e91e63; padding: 15px; margin: 20px 0;">
            <p style="margin: 5px 0; color: #c2185b;"><strong>⏰ Submitted At:</strong> ${submitted_at || 'Not available'}</p>
            <p style="margin: 5px 0; color: #c2185b;"><strong>📧 Provider Email:</strong> ${email || 'Not provided'}</p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <p style="font-size: 14px; color: #666;">
              Please review this application in the admin dashboard and approve/reject accordingly.
            </p>
          </div>

          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
          
          <p style="font-size: 13px; color: #999; text-align: center;">
            This is an automated notification from SR CareHive Provider Registration System
          </p>
        </div>
      </div>
    `;

    // Send to admin emails
    const emails = adminEmails && Array.isArray(adminEmails) ? adminEmails : ['srcarehive@gmail.com', 'ns.srcarehive@gmail.com'];
    
    for (const adminEmail of emails) {
      await sendEmail({
        to: adminEmail,
        subject: `🆕 New Healthcare Provider Registration - ${full_name}`,
        html: emailHtml
      });
    }

    res.json({ success: true, message: 'Registration notification sent to admins' });
  } catch (e) {
    console.error('Error sending registration notification:', e);
    res.status(500).json({ error: 'Failed to send registration notification' });
  }
});

// Send confirmation email to user after registration
app.post('/api/provider/send-user-confirmation', async (req, res) => {
  try {
    const { userEmail, userName } = req.body || {};
    
    if (!userEmail || !userName) {
      return res.status(400).json({ error: 'userEmail and userName are required' });
    }

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1A4FCC 100%); padding: 30px; border-radius: 10px 10px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 28px;">✅ Registration Successful!</h1>
        </div>
        <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
          <p style="font-size: 16px; color: #333;">Dear <strong>${userName}</strong>,</p>
          
          <p style="font-size: 16px; color: #333; line-height: 1.6;">
            Thank you for registering as a healthcare provider with <strong>SR CareHive</strong>! 🎉
          </p>
          
          <div style="background: #f0f8ff; border-left: 4px solid #2260FF; padding: 15px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #2260FF;">📝 What's Next?</h3>
            <ol style="margin: 10px 0; padding-left: 20px; line-height: 1.8;">
              <li>Our team will review your application</li>
              <li>You will receive an email notification once your application is reviewed</li>
              <li>If approved, you can login to the provider dashboard using your registered credentials</li>
              <li>The review process typically takes 1-2 business days</li>
            </ol>
          </div>

          <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; color: #856404;">
              <strong>⏳ Current Status:</strong> <span style="color: #ff6f00; font-weight: bold;">PENDING REVIEW</span>
            </p>
          </div>

          <p style="font-size: 16px; color: #333; line-height: 1.6;">
            We appreciate your interest in joining our platform and look forward to working with you to provide quality healthcare services.
          </p>

          <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
          
          <p style="font-size: 13px; color: #999; text-align: center;">
            For any questions, contact us at <a href="mailto:srcarehive@gmail.com" style="color: #2260FF;">srcarehive@gmail.com</a>
          </p>
        </div>
      </div>
    `;

    await sendEmail({
      to: userEmail,
      subject: '✅ SR CareHive - Registration Received!',
      html: emailHtml
    });

    res.json({ success: true, message: 'Confirmation email sent to user' });
  } catch (e) {
    console.error('Error sending user confirmation email:', e);
    res.status(500).json({ error: 'Failed to send user confirmation email' });
  }
});

// List all appointments (admin view). Protected.
// Only returns appointments where nurse_visible is not explicitly false (includes null for backward compatibility)
app.get('/api/nurse/appointments', async (req, res) => {
  try {
    if (!(await isAuthed(req))) return res.status(401).json({ error: 'Unauthorized' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });
    
    // Fetch all appointments first
    const { data: allData, error } = await supabase
      .from('appointments')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) return res.status(500).json({ error: error.message });
    
    // Filter in JavaScript: include null and true, exclude false
    const data = (allData || []).filter(item => item.nurse_visible !== false);
    
    res.json({ items: data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Approve appointment with assignment details. Protected.
app.post('/api/nurse/appointments/:id/approve', async (req, res) => {
  try {
    if (!(await isAuthed(req))) return res.status(401).json({ error: 'Unauthorized' });
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
    if (!(await isAuthed(req))) return res.status(401).json({ error: 'Unauthorized' });
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
app.post('/api/pg/razorpay/create-order', checkRateLimit, validateOrigin, async (req, res) => {
  try {
  const { amount, currency = 'INR', receipt, notes, appointment } = req.body || {};
    if (!amount) return res.status(400).json({ error: 'amount is required (in rupees as string, e.g., "99.00")' });
    
    // Validate amount is reasonable (prevent abuse)
    const amountNum = parseFloat(amount);
    if (isNaN(amountNum) || amountNum <= 0 || amountNum > 1000000) {
      return res.status(400).json({ error: 'Invalid amount. Must be between 0 and 1,000,000 rupees.' });
    }
    
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
            aadhar_number: appointment.aadhar_number || null,
            primary_doctor_name: appointment.primary_doctor_name || null,
            primary_doctor_phone: appointment.primary_doctor_phone || null,
            primary_doctor_location: appointment.primary_doctor_location || null,
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

    // Log successful order creation for monitoring
    const ip = req.ip || req.connection.remoteAddress;
    console.log(`[PAYMENT] Order created: ${order.id} | Amount: ₹${amount} | IP: ${ip}`);
    
    // Note: keyId is intentionally returned here as it's required by Razorpay SDK (public key)
    // The key_secret remains secure on the server and is never exposed
    // Security is enforced through rate limiting, origin validation, and server-side signature verification
    res.json({ 
      orderId: order.id, 
      amount: order.amount, 
      currency: order.currency, 
      keyId: RAZORPAY_KEY_ID  // Public key - required for Razorpay checkout
    });
  } catch (err) {
    // Surface Razorpay error details when available
    const status = err?.statusCode || 500;
    const description = err?.error?.description || err?.message || 'Unknown error';
    const code = err?.error?.code;
    console.error('create-order error', { statusCode: status, description, code });
    res.status(status).json({ error: 'Internal error', message: description, code });
  }
});

// Security: Rate limiting middleware for payment endpoints
const paymentRateLimiter = new Map(); // IP -> { count, resetTime }
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15 minutes
const MAX_PAYMENT_REQUESTS = 10; // Max 10 payment requests per 15 min per IP

function checkRateLimit(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  const now = Date.now();
  
  let limiter = paymentRateLimiter.get(ip);
  if (!limiter || now > limiter.resetTime) {
    limiter = { count: 1, resetTime: now + RATE_LIMIT_WINDOW };
    paymentRateLimiter.set(ip, limiter);
    return next();
  }
  
  if (limiter.count >= MAX_PAYMENT_REQUESTS) {
    return res.status(429).json({ 
      error: 'Too many payment requests. Please try again later.',
      retryAfter: Math.ceil((limiter.resetTime - now) / 1000)
    });
  }
  
  limiter.count++;
  next();
}

// Security: Origin validation for payment endpoints
function validateOrigin(req, res, next) {
  const allowedOrigins = [
    'https://srcarehive.com',
    'https://www.srcarehive.com',
    'https://api.srcarehive.com',
    'http://localhost:3000',
    'http://localhost:5000',
    'http://localhost:5173',  
    'http://127.0.0.1:3000',
    'http://127.0.0.1:5000',
    'http://127.0.0.1:5173'   
  ];
  
  const origin = req.headers.origin || req.headers.referer;
  
  // Allow requests without origin (mobile apps)
  if (!origin) return next();
  
  // Check if origin is allowed
  const isAllowed = allowedOrigins.some(allowed => origin.startsWith(allowed));
  
  if (isAllowed) {
    return next();
  }
  
  console.warn(`[SECURITY] Blocked payment request from unauthorized origin: ${origin}`);
  return res.status(403).json({ error: 'Unauthorized origin' });
}

// Verify payment signature after checkout success
// Input: { razorpay_order_id, razorpay_payment_id, razorpay_signature }
// Output: { verified: true, details }
app.post('/api/pg/razorpay/verify', checkRateLimit, validateOrigin, async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};
    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({ error: 'Missing required payment verification fields' });
    }
    
    // Validate format of IDs to prevent injection
    if (!/^order_[A-Za-z0-9]+$/.test(razorpay_order_id)) {
      return res.status(400).json({ error: 'Invalid order ID format' });
    }
    if (!/^pay_[A-Za-z0-9]+$/.test(razorpay_payment_id)) {
      return res.status(400).json({ error: 'Invalid payment ID format' });
    }
    
    // Verify signature using HMAC SHA256 (most critical security check)
    const body = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expected = crypto.createHmac('sha256', RAZORPAY_KEY_SECRET).update(body).digest('hex');
    const verified = expected === razorpay_signature;
    
    if (!verified) {
      console.warn(`[SECURITY] Payment signature mismatch! Order: ${razorpay_order_id}`);
      return res.status(400).json({ verified: false, error: 'Payment signature verification failed' });
    }

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
              .select('*')  // Select ALL fields to ensure complete data for email
              .maybeSingle();
            if (!e1 && u1) dbAppt = u1;
          }
          if (!dbAppt) {
            // Try update by order_id (in case mapping lost)
            const { data: u2, error: e2 } = await supabase
              .from('appointments')
              .update(updatePayload)
              .eq('order_id', razorpay_order_id)
              .select('*')  // Select ALL fields to ensure complete data for email
              .maybeSingle();
            if (!e2 && u2) dbAppt = u2;
          }
          if (!dbAppt && appt?.id) {
            // CRITICAL FIX: Try to find existing appointment by ID from Flutter (most reliable)
            console.log('[PAYMENT] Attempting to find appointment by appt.id:', appt.id);
            const { data: u3, error: e3 } = await supabase
              .from('appointments')
              .update(updatePayload)
              .eq('id', appt.id)
              .select('*')
              .maybeSingle();
            if (!e3 && u3) {
              dbAppt = u3;
              console.log('[PAYMENT] ✅ Found and updated appointment by appt.id:', u3.id);
            }
          }
          if (!dbAppt) {
            // Final fallback: insert a fresh row ONLY if appt has complete data
            // WARNING: This should NOT execute for registration payments (draft should exist)
            console.warn('[PAYMENT] ⚠️ WARNING: No existing appointment found, attempting fresh insert');
            console.warn('[PAYMENT] Appt data available:', {
              has_full_name: !!appt.full_name,
              has_age: !!appt.age,
              has_phone: !!appt.phone,
              appt_keys: Object.keys(appt)
            });
            
            // Only insert if we have minimum required data
            if (!appt.full_name || !appt.phone) {
              console.error('[PAYMENT] ❌ CRITICAL: Cannot insert appointment - missing required fields!');
              console.error('[PAYMENT] This indicates the draft appointment was not created during order creation');
              throw new Error('Appointment data incomplete - draft should have been created during order creation');
            }
            
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
              patient_email: appt.patient_email || appt.email || null,
              aadhar_number: appt.aadhar_number || null,
              primary_doctor_name: appt.primary_doctor_name || null,
              primary_doctor_phone: appt.primary_doctor_phone || null,
              primary_doctor_location: appt.primary_doctor_location || null,
              status: 'pending',
              created_at: new Date().toISOString(),
              order_id: razorpay_order_id,
              payment_id: razorpay_payment_id,
            };
            const { data: d3, error: e3 } = await supabase.from('appointments').insert(basePayload).select().maybeSingle();
            if (!e3) {
              dbAppt = d3;
              console.log('[PAYMENT] ✅ Fresh appointment inserted with ID:', d3?.id);
              if (dbAppt?.id && basePayload.patient_email) appointmentEmailById.set(String(dbAppt.id), basePayload.patient_email);
            } else {
              console.error('[PAYMENT] ❌ Failed to insert appointment:', e3.message);
            }
          }
          appt.persisted = true;

          // IMPORTANT: Skip email here - Flutter will call /api/notify-registration-payment 
          // which sends comprehensive admin notifications with all details
          // This prevents duplicate emails to admin
          console.log('[PAYMENT] ✅ Payment verified. Email notifications will be sent via notification endpoint.');
          console.log('[PAYMENT] Appointment ID:', dbAppt?.id || appt?.id);
        } catch (dbErr) {
          console.error('Supabase insert failed', dbErr.message);
        }
      }
    }
    // Fallback: if no in-memory appointment (server restart), try to find existing appointment by order_id
    else if (supabase) {
      try {
        console.log('[FALLBACK] No in-memory appointment found. Trying database lookup...');
        // First try to find existing appointment by order_id
        const { data: existingAppt, error: findError } = await supabase
          .from('appointments')
          .select('*')
          .eq('order_id', razorpay_order_id)
          .maybeSingle();
        
        if (existingAppt) {
          // Update existing appointment with payment_id
          const { data: updated } = await supabase
            .from('appointments')
            .update({ 
              status: 'pending', 
              payment_id: razorpay_payment_id 
            })
            .eq('id', existingAppt.id)
            .select('*')
            .maybeSingle();
          
          console.log('[FALLBACK] ✅ Found and updated existing appointment:', existingAppt.id);
          console.log('[FALLBACK] Email notifications will be sent via notification endpoint (no duplicate emails)');
        } else {
          // No existing appointment found - create minimal record
          console.warn('[FALLBACK] ⚠️ No appointment data found for order:', razorpay_order_id);
          console.warn('[FALLBACK] Creating minimal appointment record (this should rarely happen)');
          const { data: d4 } = await supabase.from('appointments').insert({
            status: 'pending',
            created_at: new Date().toISOString(),
            order_id: razorpay_order_id,
            payment_id: razorpay_payment_id
          }).select('*').maybeSingle();
          
          if (d4) {
            console.log('[FALLBACK] ✅ Created minimal appointment:', d4.id);
          }
        }
      } catch (e) {
        console.error('[FALLBACK] ❌ Error in fallback processing:', e.message);
      }
    }

    // Log successful payment verification
    const ip = req.ip || req.connection.remoteAddress;
    console.log(`[PAYMENT] ✅ Verified: Order ${razorpay_order_id} | Payment ${razorpay_payment_id} | IP: ${ip}`);

    res.json({ verified: true, orderId: razorpay_order_id, paymentId: razorpay_payment_id });
  } catch (err) {
    const ip = req.ip || req.connection.remoteAddress;
    console.error(`[PAYMENT] ❌ Verification error | IP: ${ip} |`, err.message);
    res.status(500).json({ error: 'Internal error', message: err.message });
  }
});

// Optional: simple status endpoint for polling by orderId
app.get('/api/pg/razorpay/status/:orderId', checkRateLimit, (req, res) => {
  const appt = pendingAppointments.get(req.params.orderId);
  if (!appt) return res.status(404).json({ error: 'Not found' });
  // Only return safe, non-sensitive information
  res.json({
    orderId: appt.order_id,
    status: appt.status,
    amount: appt.amount,
    currency: appt.currency,
    created_at: appt.created_at
  });
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


// Query history with optional status filter. Protected.
app.get('/api/nurse/appointments/history', async (req, res) => {
  try {
    if (!(await isAuthed(req))) return res.status(401).json({ error: 'Unauthorized' });
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
      subject: 'Serechi email test',
      html: '<p>This is a test email from Serechi server. SMTP is working</p>'
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

// Delete user account (admin operation)
app.post('/api/admin/delete-user', async (req, res) => {
  try {
    const { user_id } = req.body || {};
    if (!user_id) return res.status(400).json({ error: 'user_id is required' });
    if (!supabase) return res.status(500).json({ error: 'Supabase not configured' });

    // Delete user from Supabase Auth using service role
    const { error } = await supabase.auth.admin.deleteUser(user_id);
    
    if (error) {
      console.error('Error deleting user:', error);
      return res.status(500).json({ error: error.message });
    }

    return res.json({ success: true, message: 'User deleted successfully' });
  } catch (e) {
    console.error('Error in delete-user endpoint:', e);
    return res.status(500).json({ error: 'Internal server error' });
  }
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

// ============================================================================
// PATIENT SIGNUP OTP ENDPOINTS (With Redis & Multi-Channel Support)
// ============================================================================

// Signup OTP Storage Functions
async function storeSignupOTP(identifier, otpData) {
  const key = `signup-otp:${identifier}`;
  const ttl = 120; // 2 minutes in seconds (as per existing signup OTP validity)
  
  try {
    if (redisEnabled) {
      await redis.setex(key, ttl, JSON.stringify(otpData));
      console.log(`✅ [REDIS] Stored signup OTP for: ${identifier}`);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] storeSignupOTP failed:', error.message);
  }
  
  // Fallback to in-memory (not ideal for signup but better than nothing)
  console.log(`⚠️ [FALLBACK] Using in-memory for signup OTP: ${identifier}`);
  if (!global.signupOTPs) global.signupOTPs = new Map();
  global.signupOTPs.set(identifier, otpData);
  return true;
}

async function getSignupOTP(identifier) {
  const key = `signup-otp:${identifier}`;
  
  try {
    if (redisEnabled) {
      const data = await redis.get(key);
      if (data) {
        console.log(`✅ [REDIS] Retrieved signup OTP for: ${identifier}`);
        return typeof data === 'string' ? JSON.parse(data) : data;
      }
      return null;
    }
  } catch (error) {
    console.error('❌ [REDIS] getSignupOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  if (!global.signupOTPs) global.signupOTPs = new Map();
  return global.signupOTPs.get(identifier) || null;
}

async function deleteSignupOTP(identifier) {
  const key = `signup-otp:${identifier}`;
  
  try {
    if (redisEnabled) {
      await redis.del(key);
      console.log(`✅ [REDIS] Deleted signup OTP for: ${identifier}`);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] deleteSignupOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  if (!global.signupOTPs) global.signupOTPs = new Map();
  global.signupOTPs.delete(identifier);
  return true;
}

// Send Signup OTP (NEW - Multi-Channel with Redis)
app.post('/api/send-signup-otp', async (req, res) => {
  try {
    let { email, phone, alternativePhone, name } = req.body;
    
    // Clean phone numbers - remove country code if present
    if (phone) {
      phone = phone.replace(/^\+91/, '').replace(/[^\d]/g, '');
      if (phone.length !== 10) {
        return res.status(400).json({ error: 'Invalid phone number. Must be 10 digits.' });
      }
    }
    if (alternativePhone) {
      alternativePhone = alternativePhone.replace(/^\+91/, '').replace(/[^\d]/g, '');
      if (alternativePhone.length !== 10) {
        return res.status(400).json({ error: 'Invalid alternative phone number. Must be 10 digits.' });
      }
    }
    
    // At least one contact method required
    if (!email && !phone && !alternativePhone) {
      return res.status(400).json({ 
        error: 'At least one contact method (email, phone, or alternative phone) is required' 
      });
    }

    // Generate OTP
    const otp = generateOTP();
    const now = Date.now();
    const expiresAt = now + (2 * 60 * 1000); // 2 minutes
    
    console.log(`[SIGNUP-OTP] 🔑 Generated OTP: ${otp}`);
    console.log(`[SIGNUP-OTP] 📧 Email: ${email || 'Not provided'}`);
    console.log(`[SIGNUP-OTP] 📱 Phone (cleaned): ${phone || 'Not provided'}`);
    console.log(`[SIGNUP-OTP] 📱 Alt Phone (cleaned): ${alternativePhone || 'Not provided'}`);
    
    // Use phone as primary identifier, fallback to email
    const identifier = phone || alternativePhone || email;
    
    // Store OTP in Redis
    await storeSignupOTP(identifier, {
      otp,
      expiresAt,
      attempts: 0,
      lastSentAt: now,
      email: email || null,
      phone: phone || null,
      alternativePhone: alternativePhone || null,
      name: name || 'User'
    });

    const deliveryChannels = [];
    let emailSuccess = false;
    let smsSuccess = false;
    let altSmsSuccess = false;

    // Send Email if provided
    if (email && email.trim()) {
      try {
        const emailHtml = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: #2260FF; padding: 20px; text-align: center;">
              <h1 style="color: white; margin: 0;">SR CareHive</h1>
            </div>
            <div style="padding: 30px; background: #f9f9f9;">
              <h2 style="color: #333;">Welcome to SR CareHive!</h2>
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

        await sendEmail({
          to: email,
          subject: 'SR CareHive - Your Verification Code',
          html: emailHtml
        });

        console.log(`[SIGNUP-OTP] ✅ Email sent to: ${email}`);
        emailSuccess = true;
        deliveryChannels.push('email');
      } catch (emailError) {
        console.error(`[SIGNUP-OTP] ❌ Email failed:`, emailError.message);
      }
    }

    // Send SMS to primary phone if provided
    if (phone && phone.trim()) {
      try {
        smsSuccess = await sendOTPViaTubelight(
          phone, 
          otp, 
          name || 'User',
          TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID,
          'registration'
        );
        if (smsSuccess) {
          console.log(`[SIGNUP-OTP] ✅ SMS sent to primary phone: ${phone.slice(0,6)}***`);
          deliveryChannels.push('SMS (primary)');
        }
      } catch (smsError) {
        console.error(`[SIGNUP-OTP] ❌ Primary SMS error:`, smsError.message);
      }
    }

    // Send SMS to alternative phone if provided and different from primary
    if (alternativePhone && alternativePhone.trim() && alternativePhone !== phone) {
      try {
        altSmsSuccess = await sendOTPViaTubelight(
          alternativePhone, 
          otp, 
          name || 'User',
          TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID,
          'registration'
        );
        if (altSmsSuccess) {
          console.log(`[SIGNUP-OTP] ✅ SMS sent to alt phone: ${alternativePhone.slice(0,6)}***`);
          deliveryChannels.push('SMS (alternative)');
        }
      } catch (smsError) {
        console.error(`[SIGNUP-OTP] ❌ Alternative SMS error:`, smsError.message);
      }
    }

    // Check if at least one channel succeeded
    if (deliveryChannels.length === 0) {
      console.error(`[SIGNUP-OTP] ❌ All delivery channels failed`);
      return res.status(500).json({ 
        error: 'Failed to send OTP via any channel. Please try again later.' 
      });
    }

    res.json({
      success: true,
      message: `OTP sent to ${deliveryChannels.join(', ')}. Please check.`,
      otp: process.env.NODE_ENV === 'development' ? otp : undefined, // Only in dev
      expiresIn: 120, // 2 minutes
      deliveryChannels: deliveryChannels
    });

  } catch (e) {
    console.error('[SIGNUP-OTP] ❌ Error:', e);
    res.status(500).json({ 
      error: 'Failed to send signup OTP', 
      details: e.message 
    });
  }
});

// Verify Signup OTP (NEW)
app.post('/api/verify-signup-otp', async (req, res) => {
  try {
    const { email, phone, alternativePhone, otp } = req.body;
    
    if (!otp) {
      return res.status(400).json({ error: 'OTP is required' });
    }

    // Use phone as primary identifier, fallback to email
    const identifier = phone || alternativePhone || email;
    
    if (!identifier) {
      return res.status(400).json({ 
        error: 'At least one contact method identifier is required' 
      });
    }

    console.log(`[SIGNUP-OTP-VERIFY] 🔍 Verifying OTP for: ${identifier}`);

    const otpData = await getSignupOTP(identifier);

    if (!otpData) {
      console.log(`[SIGNUP-OTP-VERIFY] ❌ No OTP found for: ${identifier}`);
      return res.status(400).json({ 
        error: 'No OTP found or OTP expired. Please request a new one.' 
      });
    }

    // Check expiry
    if (Date.now() > otpData.expiresAt) {
      console.log(`[SIGNUP-OTP-VERIFY] ❌ OTP expired for: ${identifier}`);
      await deleteSignupOTP(identifier);
      return res.status(400).json({ 
        error: 'OTP has expired. Please request a new one.' 
      });
    }

    // Check attempts (max 5)
    if (otpData.attempts >= 5) {
      console.log(`[SIGNUP-OTP-VERIFY] ❌ Max attempts exceeded for: ${identifier}`);
      await deleteSignupOTP(identifier);
      return res.status(429).json({ 
        error: 'Maximum verification attempts exceeded. Please request a new OTP.' 
      });
    }

    // Verify OTP
    if (otp.trim() !== otpData.otp) {
      console.log(`[SIGNUP-OTP-VERIFY] ❌ Invalid OTP for: ${identifier}`);
      
      // Increment attempts
      otpData.attempts += 1;
      await storeSignupOTP(identifier, otpData);
      
      return res.status(400).json({ 
        error: 'Invalid OTP. Please try again.',
        attemptsRemaining: 5 - otpData.attempts
      });
    }

    // Success! Delete OTP
    console.log(`[SIGNUP-OTP-VERIFY] ✅ OTP verified successfully for: ${identifier}`);
    await deleteSignupOTP(identifier);

    res.json({
      success: true,
      message: 'OTP verified successfully'
    });

  } catch (e) {
    console.error('[SIGNUP-OTP-VERIFY] ❌ Error:', e);
    res.status(500).json({ 
      error: 'Failed to verify OTP', 
      details: e.message 
    });
  }
});

// OLD Endpoint (DEPRECATED - Keep for backward compatibility)
app.post('/api/send-otp-email', async (req, res) => {
  try {
    const { email, otp } = req.body;
    
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: #2260FF; padding: 20px; text-align: center;">
          <h1 style="color: white; margin: 0;">Serechi</h1>
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

    console.log(`[DEPRECATED] [INFO] Sending OTP email to: ${email}`);
    
    await sendEmail({
      to: email,
      subject: 'Serechi - Your Verification Code',
      html
    });

    console.log(`[DEPRECATED] [SUCCESS] OTP email sent to: ${email}`);
    res.json({ success: true, message: 'OTP sent successfully' });
  } catch (e) {
    console.error('[DEPRECATED] [ERROR] send-otp-email:', e);
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

    const message = `Serechi Verification: Your OTP is ${otp}. Valid for 2 minutes. DO NOT share this code with anyone.`;

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

// 1. Registration Payment Notification (₹10)
app.post('/api/notify-registration-payment', async (req, res) => {
  try {
    const { appointmentId, nurseEmail, nurseName } = req.body;
    if (!appointmentId) {
      return res.status(400).json({ error: 'Missing appointmentId' });
    }
    // Fetch full appointment details from DB
    let appointment = null;
    try {
      console.log(`[DEBUG] Fetching appointment with ID: ${appointmentId}`);
      const { data, error } = await supabase
        .from('appointments')
        .select('*')
        .eq('id', appointmentId)
        .maybeSingle();
      
      if (error) {
        console.error('[ERROR] Supabase query error:', error);
        return res.status(500).json({ error: 'Database error', details: error.message });
      }
      
      appointment = data;
      console.log('[DEBUG] Raw appointment data from DB:', JSON.stringify(appointment, null, 2));
    } catch (err) {
      console.error('[ERROR] Could not fetch appointment:', err.message);
      return res.status(404).json({ error: 'Appointment not found' });
    }
    if (!appointment) {
      console.error('[ERROR] No appointment found with ID:', appointmentId);
      return res.status(404).json({ error: 'Appointment not found' });
    }
    const patientEmail = appointment.patient_email;
    const patientName = appointment.full_name;
    const patientPhone = appointment.phone;
    const paymentId = appointment.registration_payment_id || appointment.payment_id;
    const receiptId = appointment.registration_receipt_id;
    const amount = appointment.amount_rupees || 10;
    const date = appointment.date;
    const time = appointment.time;
    // Email to healthcare seeker
    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4acc 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Registration Successful!</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName || 'Healthcare seeker'}</strong>,</p>
          
          <p style="color: #555; line-height: 1.6;">
            Your registration payment of <strong style="color: #2260FF; font-size: 18px;">₹${amount || 10}</strong> has been received successfully! 🎉
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
              <li>Our healthcare provider will contact you shortly to confirm appointment details</li>
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

    // CRITICAL FIX: Use comprehensive admin notification instead of simple email
    // This ensures ALL appointment details are included in admin emails
    console.log('[EMAIL] Sending comprehensive admin notification with complete appointment data');
    console.log('[EMAIL] Appointment details:', {
      id: appointment.id,
      full_name: appointment.full_name,
      age: appointment.age,
      gender: appointment.gender,
      phone: appointment.phone,
      email: appointment.patient_email,
      address: appointment.address,
      problem: appointment.problem
    });
    
    // Check if critical fields are missing
    const missingFields = [];
    if (!appointment.full_name) missingFields.push('full_name');
    if (!appointment.age) missingFields.push('age');
    if (!appointment.gender) missingFields.push('gender');
    if (!appointment.phone) missingFields.push('phone');
    if (!appointment.patient_email) missingFields.push('patient_email');
    if (!appointment.address) missingFields.push('address');
    if (!appointment.problem) missingFields.push('problem');
    
    if (missingFields.length > 0) {
      console.error('[WARNING] ⚠️ Missing fields in appointment data:', missingFields.join(', '));
      console.error('[WARNING] This means data was not saved properly in the database during appointment creation!');
    } else {
      console.log('[SUCCESS] ✅ All critical fields present in appointment data');
    }

    // Send emails
    const emailPromises = [
      sendEmail({ 
        to: patientEmail, 
        subject: `Registration Payment Successful - Appointment #${appointmentId}`, 
        html: patientHtml 
      })
    ];
    
    // Send comprehensive admin notification to ALL admin emails
    // This includes complete patient details, medical info, contact details, etc.
    emailPromises.push(
      sendAdminNotification({
        appointment: appointment,
        type: 'REGISTRATION_PAYMENT',
        paymentDetails: {
          amount: amount || 10,
          paymentId: paymentId,
          orderId: receiptId
        }
      })
    );

    // Send SMS to healthcare seeker
    if (twilioClient && patientPhone) {
      try {
        let phone = patientPhone.trim();
        if (!phone.startsWith('+')) phone = `+91${phone}`;
        await twilioClient.messages.create({
          body: `SR CareHive: Registration payment ₹${amount || 10} received! Appointment #${appointmentId}. Our healthcare provider provider will contact you soon. Check email for details.`,
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
            Our healthcare provider has assessed your requirements and set the total service amount for your appointment.
          </p>

          <div style="background: #f3e5f5; padding: 25px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #9c27b0; text-align: center;">
            <h3 style="margin: 0 0 10px 0; color: #9c27b0;">Total Service Amount</h3>
            <p style="font-size: 36px; font-weight: bold; color: #7b1fa2; margin: 0;">₹${totalAmount}</p>
            <p style="color: #666; margin: 10px 0 0 0; font-size: 14px;">(Registration ₹10 already paid)</p>
          </div>

          ${nurseRemarks ? `
          <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #4caf50;">
            <h4 style="margin-top: 0; color: #2e7d32;">Service Breakdown</h4>
            <p style="color: #2e7d32; margin: 0; white-space: pre-wrap;">${nurseRemarks}</p>
          </div>
          ` : ''}

          <div style="background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ffc107;">
            <h4 style="margin-top: 0; color: #856404;">Payment Schedule</h4>
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
            ${nurseName ? `<p style="margin: 5px 0;"><strong>Healthcare Provider:</strong> ${nurseName}</p>` : ''}
          </div>

          <p style="color: #999; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
            Need clarification on the service charges? Please contact your healthcare provider.
            <br>Serechi | srcarehive@gmail.com
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
            <p style="color: #155724; margin: 10px 0;">Your appointment is confirmed. Our healthcare provider will visit you as scheduled.</p>
            <div style="background: white; padding: 15px; border-radius: 6px; margin-top: 15px;">
              <p style="margin: 5px 0;"><strong>Date:</strong> ${date || 'To be confirmed'}</p>
              <p style="margin: 5px 0;"><strong>Time:</strong> ${time || 'To be confirmed'}</p>
              ${nurseName ? `<p style="margin: 5px 0;"><strong>Healthcare Provider:</strong> ${nurseName}</p>` : ''}
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
            Serechi | srcarehive@gmail.com
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
                <p style="font-size: 20px; font-weight: bold; color: #009688; margin: 5px 0;">₹10</p>
              </div>
              <div style="text-align: center; margin: 10px;">
                <p style="color: #666; margin: 0; font-size: 12px;">PRE-VISIT (50%)</p>
                <p style="font-size: 20px; font-weight: bold; color: #009688; margin: 5px 0;">₹${Math.max(0, (totalPaid - 10 - amount)).toFixed(0)}</p>
              </div>
              <div style="text-align: center; margin: 10px;">
                <p style="color: #666; margin: 0; font-size: 12px;">FINAL (50%)</p>
                <p style="font-size: 20px; font-weight: bold; color: #009688; margin: 5px 0;">₹${amount}</p>
              </div>
            </div>
            <div style="border-top: 2px solid #00796b; margin: 15px 0; padding-top: 15px;">
              <p style="color: #666; margin: 0; font-size: 14px;">TOTAL PAID</p>
              <p style="font-size: 32px; font-weight: bold; color: #00796b; margin: 5px 0;">₹${totalPaid || (10 + amount * 2)}</p>
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
            <br>Serechi - Quality Home Care Services
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
          <p><strong>Total Paid:</strong> ₹${totalPaid || (10 + amount * 2)}</p>
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
          body: `SR CareHive: Final payment ₹${amount} received! Total paid ₹${totalPaid || (10 + amount * 2)}. Service complete. Thank you for choosing SR CareHive! `,
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
            ${nurseName ? `<p style="margin: 5px 0;"><strong>Healthcare Provider:</strong> ${nurseName}</p>` : ''}
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
           Serechi | srcarehive@gmail.com
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
      nurseProfessionalismRating,
      serviceQualityRating,
      communicationRating,
      punctualityRating,
      positiveFeedback,
      improvementSuggestions,
      additionalComments,
      wouldRecommend,
      satisfiedWithService
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
              Your Overall Rating: ${overallRating || 'N/A'} / 5
            </p>
            <div style="margin-top: 10px; text-align: left; color: #333;">
              <p><strong>Professionalism:</strong> ${nurseProfessionalismRating || 'N/A'} / 5</p>
              <p><strong>Service Quality:</strong> ${serviceQualityRating || 'N/A'} / 5</p>
              <p><strong>Communication:</strong> ${communicationRating || 'N/A'} / 5</p>
              <p><strong>Punctuality:</strong> ${punctualityRating || 'N/A'} / 5</p>
              <p><strong>Would Recommend:</strong> ${wouldRecommend ? 'Yes' : 'No'}</p>
              <p><strong>Satisfied with Service:</strong> ${satisfiedWithService ? 'Yes' : 'No'}</p>
              ${positiveFeedback ? `<p><strong>What you liked:</strong> ${positiveFeedback}</p>` : ''}
              ${improvementSuggestions ? `<p><strong>Suggestions for Improvement:</strong> ${improvementSuggestions}</p>` : ''}
              ${additionalComments ? `<p><strong>Additional Comments:</strong> ${additionalComments}</p>` : ''}
            </div>
          </div>
          <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h4 style="margin-top: 0;">Feedback Details</h4>
            <p style="margin: 5px 0;"><strong>Appointment ID:</strong> #${appointmentId}</p>
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
           Serechi | srcarehive@gmail.com | Thank you for choosing us!
          </p>
        </div>
      </div>
    `;

    // Admin notification email
    const adminHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #ffa726;">New Feedback Received</h2>
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <p><strong>Appointment ID:</strong> #${appointmentId}</p>
          <p><strong>Healthcare seeker:</strong> ${patientName || 'N/A'}</p>
          <p><strong>Overall Rating:</strong> ${'⭐'.repeat(overallRating || 0)} (${overallRating || 0}/5)</p>
          <p><strong>Professionalism:</strong> ${nurseProfessionalismRating || 'N/A'} / 5</p>
          <p><strong>Service Quality:</strong> ${serviceQualityRating || 'N/A'} / 5</p>
          <p><strong>Communication:</strong> ${communicationRating || 'N/A'} / 5</p>
          <p><strong>Punctuality:</strong> ${punctualityRating || 'N/A'} / 5</p>
          <p><strong>Would Recommend:</strong> ${wouldRecommend ? 'Yes' : 'No'}</p>
          <p><strong>Satisfied with Service:</strong> ${satisfiedWithService ? 'Yes' : 'No'}</p>
          ${positiveFeedback ? `<p><strong>What they liked:</strong> ${positiveFeedback}</p>` : ''}
          ${improvementSuggestions ? `<p><strong>Suggestions for Improvement:</strong> ${improvementSuggestions}</p>` : ''}
          ${additionalComments ? `<p><strong>Additional Comments:</strong> ${additionalComments}</p>` : ''}
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
    const existingOTP = await getPasswordResetOTP(normalizedEmail);
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
  .select('email, name, user_id, phone, alternative_phone')
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

    // Store OTP using Redis
    await storePasswordResetOTP(normalizedEmail, {
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

    // Send OTP email (sendEmail handles mailer initialization)
    console.log(`[OTP-RESET] Attempting to send OTP email...`);
    
    let smsSuccess = false;
    try {
      await sendEmail({
        to: normalizedEmail,
        subject: 'Your Password Reset OTP - SR CareHive',
        html: otpEmailHtml
      });

      console.log(`[SUCCESS] ✅ OTP email sent to: ${normalizedEmail}`);

      // Try SMS to both phone numbers if available
      if (patient.phone || patient.alternative_phone) {
        const phoneToTry = patient.phone || patient.alternative_phone;
        console.log(`[OTP-RESET] 📱 Trying SMS to: ${phoneToTry}`);
        try {
          smsSuccess = await sendOTPViaTubelight(
            phoneToTry, 
            otp, 
            patient.name,
            TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID,
            'patient password reset'
          );
        } catch (smsError) {
          console.error(`[OTP-RESET] ❌ SMS error:`, smsError.message);
        }
      }

      const channels = ['email'];
      if (smsSuccess) channels.push('SMS');

      res.json({ 
        success: true, 
        message: resend 
          ? `New OTP sent to your ${channels.join(' and ')}!` 
          : `OTP sent to your ${channels.join(' and ')}. Please check.`,
        expiresIn: 600,
        canResendAfter: 120,
        deliveryChannels: channels
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

    const otpData = await getPasswordResetOTP(normalizedEmail);

    if (!otpData) {
      console.log(`[OTP-VERIFY] No OTP found for: ${normalizedEmail}`);
      return res.status(400).json({ 
        error: 'Invalid or expired OTP. Please request a new one.' 
      });
    }

    // Check expiry
    if (Date.now() > otpData.expiresAt) {
      console.log(`[OTP-VERIFY] OTP expired for: ${normalizedEmail}`);
      await deletePasswordResetOTP(normalizedEmail);
      return res.status(400).json({ 
        error: 'OTP has expired. Please request a new one.' 
      });
    }

    // Check attempts (max 5 attempts)
    if (otpData.attempts >= 5) {
      console.log(`[OTP-VERIFY] Too many attempts for: ${normalizedEmail}`);
      await deletePasswordResetOTP(normalizedEmail);
      return res.status(429).json({ 
        error: 'Too many failed attempts. Please request a new OTP.' 
      });
    }

    // Verify OTP
    if (normalizedOTP !== otpData.otp) {
      otpData.attempts += 1;
      await storePasswordResetOTP(normalizedEmail, otpData);
      
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
    await storePasswordResetOTP(normalizedEmail, otpData);

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

    const otpData = await getPasswordResetOTP(normalizedEmail);

    if (!otpData || !otpData.verified) {
      console.log(`[PASSWORD-RESET] OTP not verified for: ${normalizedEmail}`);
      return res.status(400).json({ 
        error: 'OTP not verified. Please verify OTP first.' 
      });
    }

    // Check if OTP is still valid
    if (Date.now() > otpData.expiresAt) {
      console.log(`[PASSWORD-RESET] OTP expired for: ${normalizedEmail}`);
      await deletePasswordResetOTP(normalizedEmail);
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
    await deletePasswordResetOTP(normalizedEmail);

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

// Clean up expired OTPs every 5 minutes (Redis auto-expires, this is for fallback)
setInterval(() => {
  if (!redisEnabled) {
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
  }
}, 5 * 60 * 1000);

// ============================================================================
// HEALTHCARE PROVIDER (NURSE) PASSWORD RESET SYSTEM
// ============================================================================

// In-memory OTP storage for healthcare provider password reset
const providerPasswordResetOTPs = new Map(); // email -> { otp, expiresAt, attempts, lastSentAt, verified, providerId }

// Send OTP via email for healthcare provider password reset
app.post('/api/nurse/send-password-reset-otp', async (req, res) => {
  try {
    const { email, resend = false } = req.body;
    
    if (!email || !email.trim()) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    console.log(`[PROVIDER-RESET] ${resend ? 'Resend' : 'New'} request for email: ${normalizedEmail}`);

    // Validate email format
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(normalizedEmail)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    // Check for resend cooldown (2 minutes)
    const existingOTP = await getProviderPasswordResetOTP(normalizedEmail);
    if (existingOTP && existingOTP.lastSentAt) {
      const timeSinceLastSend = Date.now() - existingOTP.lastSentAt;
      const cooldownPeriod = 2 * 60 * 1000; // 2 minutes in milliseconds
      
      if (timeSinceLastSend < cooldownPeriod) {
        const remainingTime = Math.ceil((cooldownPeriod - timeSinceLastSend) / 1000); // seconds
        const minutes = Math.floor(remainingTime / 60);
        const seconds = remainingTime % 60;
        
        console.log(`[PROVIDER-RESET] Cooldown active for ${normalizedEmail}. Remaining: ${minutes}m ${seconds}s`);
        
        return res.status(429).json({ 
          error: `Please wait ${minutes > 0 ? minutes + ' minute(s) ' : ''}${seconds} second(s) before requesting a new OTP.`,
          remainingSeconds: remainingTime,
          canResendAt: existingOTP.lastSentAt + cooldownPeriod
        });
      }
    }

    if (!supabase) {
      console.error('[PROVIDER-RESET] ❌ Supabase client not initialized');
      console.error('[PROVIDER-RESET] ❌ Cannot query database!');
      return res.status(500).json({ 
        success: false,
        error: 'Database connection not available. Please contact administrator.',
        serviceError: true
      });
    }

    console.log(`[PROVIDER-RESET] 🔍 Database check starting...`);
    console.log(`[PROVIDER-RESET] 📧 Looking for email: "${normalizedEmail}"`);
    console.log(`[PROVIDER-RESET] 🔑 Using ${usingServiceRole ? 'SERVICE ROLE' : 'ANON'} key`);
    console.log(`[PROVIDER-RESET] 🗄️  Supabase initialized: ${supabaseInitialized}`);

    // Query database with MULTIPLE approaches to find the issue
    let provider = null;
    let providerId = null;
    
    try {
      console.log(`[PROVIDER-RESET] 🔍 Attempt 1: Direct query with explicit schema...`);
      
      // Query with 'full_name' and phone fields from healthcare_providers table
      const { data: attempt1Data, error: attempt1Error, count: attempt1Count } = await supabase
        .from('healthcare_providers')
        .select('id, email, full_name, mobile_number, alternative_mobile', { count: 'exact' })
        .ilike('email', normalizedEmail);

      console.log(`[PROVIDER-RESET] 📊 Attempt 1 - Count:`, attempt1Count);
      console.log(`[PROVIDER-RESET] 📊 Attempt 1 - Data:`, JSON.stringify(attempt1Data, null, 2));
      console.log(`[PROVIDER-RESET] 📊 Attempt 1 - Error:`, attempt1Error);

      if (attempt1Data && attempt1Data.length > 0) {
        provider = attempt1Data[0];
        providerId = attempt1Data[0].id;
        console.log(`[PROVIDER-RESET] ✅ FOUND via Attempt 1!`);
        console.log(`[PROVIDER-RESET] 👤 Provider: ${provider.email}`);
      }

      // If not found, try selecting ALL and filtering (debugging)
      if (!provider) {
        console.log(`[PROVIDER-RESET] 🔍 Attempt 2: Fetching ALL providers to check if table is accessible...`);
        
        const { data: allProviders, error: allError, count: totalCount } = await supabase
          .from('healthcare_providers')
          .select('id, email, full_name', { count: 'exact' })
          .limit(10);

        console.log(`[PROVIDER-RESET] 📊 Attempt 2 - Total count in table:`, totalCount);
        console.log(`[PROVIDER-RESET] 📊 Attempt 2 - First 10 emails:`, allProviders ? allProviders.map(p => p.email).join(', ') : 'none');
        console.log(`[PROVIDER-RESET] 📊 Attempt 2 - Error:`, allError);

        // Manual search in fetched data
        if (allProviders && allProviders.length > 0) {
          const found = allProviders.find(p => p.email.toLowerCase() === normalizedEmail);
          if (found) {
            provider = found;
            providerId = found.id;
            console.log(`[PROVIDER-RESET] ✅ FOUND via manual search in fetched data!`);
            console.log(`[PROVIDER-RESET] ⚠️  Query filter not working but manual search worked!`);
            console.log(`[PROVIDER-RESET] 👤 Provider email: ${provider.email}`);
          } else {
            console.log(`[PROVIDER-RESET] ❌ Not in first 10 records, checking if email matches any...`);
            const emailList = allProviders.map(p => `"${p.email}"`).join(', ');
            console.log(`[PROVIDER-RESET] 📝 Available emails: ${emailList}`);
            console.log(`[PROVIDER-RESET] 📝 Searching for: "${normalizedEmail}"`);
          }
        }
      }

      // If still not found, check nurses table
      if (!provider) {
        console.log(`[PROVIDER-RESET] 🔍 Attempt 3: Checking nurses table...`);
        
        const { data: nurseData, error: nurseError } = await supabase
          .from('nurses')
          .select('id, email, full_name')
          .ilike('email', normalizedEmail);

        console.log(`[PROVIDER-RESET] 📊 Nurses Query Data:`, JSON.stringify(nurseData, null, 2));
        console.log(`[PROVIDER-RESET] 📊 Nurses Query Error:`, nurseError ? JSON.stringify(nurseError, null, 2) : 'None');

        if (nurseData && nurseData.length > 0) {
          provider = nurseData[0];
          providerId = nurseData[0].id;
          console.log(`[PROVIDER-RESET] ✅ FOUND in nurses table!`);
          console.log(`[PROVIDER-RESET] 👤 Nurse: ${provider.email}`);
        } else {
          console.log(`[PROVIDER-RESET] ❌ NOT found in nurses table either`);
          
          // Fetch all nurses too for comparison
          const { data: allNurses } = await supabase
            .from('nurses')
            .select('email')
            .limit(5);
          console.log(`[PROVIDER-RESET] 📝 Sample nurse emails:`, allNurses ? allNurses.map(n => n.email).join(', ') : 'none');
        }
      }

    } catch (err) {
      console.error(`[PROVIDER-RESET] ❌ EXCEPTION during database query!`);
      console.error(`[PROVIDER-RESET] ❌ Error type:`, err.constructor.name);
      console.error(`[PROVIDER-RESET] ❌ Error message:`, err.message);
      console.error(`[PROVIDER-RESET] ❌ Error stack:`, err.stack);
    }

    // Final check - if provider not found in BOTH tables
    if (!provider) {
      console.log(`[PROVIDER-RESET] ❌ FINAL RESULT: Email NOT FOUND in any table`);
      console.log(`[PROVIDER-RESET] 📧 Searched for: "${normalizedEmail}"`);
      console.log(`[PROVIDER-RESET] 🗄️  Tables checked: healthcare_providers, nurses`);
      
      return res.status(404).json({ 
        success: false, 
        error: 'This email is not registered as a healthcare provider. Please check your email address or contact support.',
        notFound: true,
        searchedEmail: normalizedEmail
      });
    }

    console.log(`[PROVIDER-RESET] ✅ SUCCESS: Provider found! Proceeding with OTP generation...`);
    console.log(`[PROVIDER-RESET] 👤 Provider details:`, {
      id: provider.id,
      email: provider.email,
      full_name: provider.full_name
    });

    // Provider found - generate and send OTP
    console.log(`[PROVIDER-RESET] Provider FOUND: ${provider.email}`);

    // Generate 6-digit OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + (10 * 60 * 1000); // 10 minutes
    const lastSentAt = Date.now();

    // Store OTP using Redis
    await storeProviderPasswordResetOTP(normalizedEmail, {
      otp,
      expiresAt,
      attempts: 0,
      providerId: providerId,
      lastSentAt,
      verified: false
    });

    console.log(`[PROVIDER-RESET] 📧 OTP Generated: ${otp}`);
    console.log(`[PROVIDER-RESET] ⏰ Expires at: ${new Date(expiresAt).toLocaleString()}`);
    console.log(`[PROVIDER-RESET] 💾 OTP stored in memory for: ${normalizedEmail}`);

    console.log(`[PROVIDER-RESET] 📧 Preparing to send OTP email to: ${normalizedEmail}`);

    const otpEmailHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Password Reset OTP</h1>
        </div>
        
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
            Hello <strong>${provider.full_name}</strong>,
          </p>
          
          <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
            You requested to reset your password for your SR CareHive healthcare provider account. 
            Use the OTP below to verify your identity:
          </p>
          
          <div style="background: #f0f4ff; padding: 20px; border-radius: 8px; text-align: center; margin: 30px 0;">
            <p style="font-size: 14px; color: #666; margin: 0 0 10px 0;">Your OTP Code:</p>
            <p style="font-size: 36px; font-weight: bold; color: #2260FF; letter-spacing: 8px; margin: 0;">
              ${otp}
            </p>
          </div>
          
          <div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
            <p style="margin: 0; font-size: 14px; color: #856404;">
              ⏰ <strong>Important:</strong> This OTP will expire in <strong>10 minutes</strong>
            </p>
          </div>
          
          <div style="background: #d1ecf1; border-left: 4px solid #0c5460; padding: 15px; margin: 20px 0; border-radius: 4px;">
            <p style="margin: 0 0 10px 0; font-size: 14px; color: #0c5460;">
              <strong>Security Tips:</strong>
            </p>
            <ul style="margin: 0; padding-left: 20px; font-size: 14px; color: #0c5460;">
              <li>Never share this OTP with anyone</li>
              <li>SR CareHive will never ask for your OTP via phone or email</li>
              <li>If you didn't request this, please ignore this email</li>
            </ul>
          </div>
          
          <p style="font-size: 14px; color: #666; margin-top: 30px;">
            Best regards,<br>
            <strong>SR CareHive Team</strong>
          </p>
        </div>
        
        <div style="text-align: center; margin-top: 20px; padding: 20px; font-size: 12px; color: #999;">
          <p style="margin: 0;">© ${new Date().getFullYear()} SR CareHive. All rights reserved.</p>
          <p style="margin: 5px 0 0 0;">This is an automated message, please do not reply.</p>
        </div>
      </div>
    `;

    try {
      console.log(`[PROVIDER-RESET] 📤 Sending OTP email via sendEmail function...`);
      
      const emailResult = await sendEmail({
        to: normalizedEmail,
        subject: 'Password Reset OTP - SR CareHive Healthcare Provider',
        html: otpEmailHtml
      });

      console.log(`[PROVIDER-RESET] ✅ OTP email sent to ${normalizedEmail}`);

      // Try SMS to both phone numbers if available
      let smsSuccess = false;
      if (provider.mobile_number || provider.alternative_mobile) {
        const phoneToTry = provider.mobile_number || provider.alternative_mobile;
        console.log(`[PROVIDER-RESET] 📱 Trying SMS to: ${phoneToTry}`);
        try {
          smsSuccess = await sendOTPViaTubelight(
            phoneToTry, 
            otp, 
            provider.full_name,
            TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID,
            'provider password reset'
          );
        } catch (smsError) {
          console.error(`[PROVIDER-RESET] ❌ SMS error:`, smsError.message);
        }
      }

      const channels = ['email'];
      if (smsSuccess) channels.push('SMS');

      res.json({ 
        success: true, 
        message: `OTP sent to your ${channels.join(' and ')}!`,
        expiresIn: 600,
        canResendAfter: 120,
        deliveryChannels: channels
      });

    } catch (emailError) {
      // Remove OTP from memory if email failed
      await deleteProviderPasswordResetOTP(normalizedEmail);
      
      console.error('[PROVIDER-RESET] ❌ Failed to send OTP email:', emailError.message);
      console.error('[PROVIDER-RESET] ❌ Error details:', emailError);
      
      res.status(500).json({ 
        success: false,
        error: 'Failed to send OTP email. Please check your email address and try again.',
        details: emailError.message,
        emailFailed: true
      });
    }

  } catch (e) {
    console.error('[ERROR] send-password-reset-otp (provider):', e);
    res.status(500).json({ 
      error: 'Failed to process request', 
      details: e.message 
    });
  }
});

// Verify OTP for healthcare provider password reset
app.post('/api/nurse/verify-password-reset-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    console.log(`[PROVIDER-RESET] Verifying OTP for: ${normalizedEmail}`);

    const otpData = await getProviderPasswordResetOTP(normalizedEmail);

    if (!otpData) {
      console.log(`[PROVIDER-RESET] No OTP found for: ${normalizedEmail}`);
      return res.status(400).json({ 
        error: 'No OTP found. Please request a new OTP.' 
      });
    }

    // Check if this is a fake OTP (for non-existent users)
    if (otpData.isFake) {
      console.log(`[PROVIDER-RESET] Fake OTP attempted for: ${normalizedEmail}`);
      otpData.attempts += 1;
      await storeProviderPasswordResetOTP(normalizedEmail, otpData);
      
      const remainingAttempts = 5 - otpData.attempts;
      return res.status(400).json({ 
        error: `Invalid OTP. ${remainingAttempts} attempt(s) remaining.`,
        remainingAttempts 
      });
    }

    // Check if OTP is expired
    if (Date.now() > otpData.expiresAt) {
      console.log(`[PROVIDER-RESET] OTP expired for: ${normalizedEmail}`);
      await deleteProviderPasswordResetOTP(normalizedEmail);
      return res.status(400).json({ 
        error: 'OTP has expired. Please request a new one.' 
      });
    }

    // Check max attempts
    if (otpData.attempts >= 5) {
      console.log(`[PROVIDER-RESET] Max attempts reached for: ${normalizedEmail}`);
      await deleteProviderPasswordResetOTP(normalizedEmail);
      return res.status(429).json({ 
        error: 'Too many failed attempts. Please request a new OTP.' 
      });
    }

    // Verify OTP
    if (otp !== otpData.otp) {
      otpData.attempts += 1;
      await storeProviderPasswordResetOTP(normalizedEmail, otpData);
      
      const remainingAttempts = 5 - otpData.attempts;
      console.log(`[PROVIDER-RESET] Invalid OTP for: ${normalizedEmail}. ${remainingAttempts} attempts remaining`);
      
      return res.status(400).json({ 
        error: `Invalid OTP. ${remainingAttempts} attempt(s) remaining.`,
        remainingAttempts 
      });
    }

    // Mark OTP as verified
    otpData.verified = true;
    await storeProviderPasswordResetOTP(normalizedEmail, otpData);

    console.log(`[PROVIDER-RESET] ✅ OTP verified for: ${normalizedEmail}`);

    res.json({ 
      success: true, 
      message: 'OTP verified successfully. You can now reset your password.',
      providerId: otpData.providerId
    });

  } catch (e) {
    console.error('[ERROR] verify-password-reset-otp (provider):', e);
    res.status(500).json({ 
      error: 'Failed to verify OTP', 
      details: e.message 
    });
  }
});

// Reset password for healthcare provider with OTP (final step)
app.post('/api/nurse/reset-password-with-otp', async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;
    
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ error: 'Email, OTP, and new password are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    console.log(`[PROVIDER-RESET] Password reset attempt for: ${normalizedEmail}`);

    const otpData = await getProviderPasswordResetOTP(normalizedEmail);

    if (!otpData || !otpData.verified) {
      console.log(`[PROVIDER-RESET] OTP not verified for: ${normalizedEmail}`);
      return res.status(400).json({ 
        error: 'OTP not verified. Please verify OTP first.' 
      });
    }

    // Check if this is a fake OTP (for non-existent users)
    if (otpData.isFake) {
      console.log(`[PROVIDER-RESET] Password reset blocked - fake OTP for: ${normalizedEmail}`);
      await deleteProviderPasswordResetOTP(normalizedEmail);
      return res.status(400).json({ 
        error: 'Invalid request. Please try again.' 
      });
    }

    // Check if OTP is still valid
    if (Date.now() > otpData.expiresAt) {
      console.log(`[PROVIDER-RESET] OTP expired for: ${normalizedEmail}`);
      await deleteProviderPasswordResetOTP(normalizedEmail);
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

    // Hash the new password using bcrypt
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update password in healthcare_providers table
    const { data, error } = await supabase
      .from('healthcare_providers')
      .update({ password_hash: hashedPassword })
      .eq('id', otpData.providerId)
      .select();

    if (error) {
      console.error('[ERROR] Failed to update provider password:', error.message);
      return res.status(500).json({ 
        error: 'Failed to update password', 
        details: error.message 
      });
    }

    console.log(`[PROVIDER-RESET] ✅ Password reset successfully for: ${normalizedEmail}`);

    // Delete OTP after successful password reset
    await deleteProviderPasswordResetOTP(normalizedEmail);

    res.json({ 
      success: true, 
      message: 'Password reset successfully! You can now login with your new password.' 
    });

  } catch (e) {
    console.error('[ERROR] reset-password-with-otp (provider):', e);
    res.status(500).json({ 
      error: 'Failed to reset password', 
      details: e.message 
    });
  }
});

// Clean up expired provider password reset OTPs every 5 minutes (Redis auto-expires, this is for fallback)
setInterval(async () => {
  if (!redisEnabled) {
    const now = Date.now();
    let cleaned = 0;
    
    for (const [email, data] of providerPasswordResetOTPs.entries()) {
      if (now > data.expiresAt) {
        await deleteProviderPasswordResetOTP(email);
        cleaned++;
      }
    }
    
    if (cleaned > 0) {
      console.log(`[PROVIDER-RESET-CLEANUP] Removed ${cleaned} expired provider OTP(s)`);
       }
  }
}, 5 * 60 * 1000);

// Contact form submission endpoint
app.post('/api/contact', async (req, res) => {
  try {
    const { name, email, phone, subject, message } = req.body || {};
    if (!name || !email || !subject || !message) {
      return res.status(400).json({ error: 'Name, email, subject, and message are required.' });
    }

    // Store in DB if needed (already handled elsewhere)

    // Admin email template
    const adminHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">New Contact Form Submission</h1>
        </div>
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">A new contact form has been submitted:</p>
          <ul style="color: #555; font-size: 15px;">
            <li><strong>Name:</strong> ${name}</li>
            <li><strong>Email:</strong> ${email}</li>
            <li><strong>Phone:</strong> ${phone || '-'} </li>
            <li><strong>Subject:</strong> ${subject}</li>
            <li><strong>Message:</strong> ${message}</li>
          </ul>
        </div>
        <p style="color: #999; font-size: 12px; margin-top: 30px; text-align: center;">SR CareHive Contact Center</p>
      </div>
    `;

    // User thank you email template
    const userHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Thank You for Contacting Us!</h1>
        </div>
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${name}</strong>,</p>
          <p style="color: #555; line-height: 1.6;">Thank you for reaching out to SR CareHive. We have received your message and our team will contact you shortly.</p>
          <div style="background: #e8f5e9; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #4caf50;">
            <p style="margin: 0; color: #2e7d32;">Your submitted details:</p>
            <ul style="color: #333; font-size: 15px;">
              <li><strong>Subject:</strong> ${subject}</li>
              <li><strong>Message:</strong> ${message}</li>
            </ul>
          </div>
          <p style="color: #999; font-size: 12px; margin-top: 30px; text-align: center;">SR CareHive Team</p>
        </div>
      </div>
    `;

    // Send to both admins
    await Promise.all([
      sendEmail({ to: 'srcarehive@gmail.com', subject: `Contact Form Submission: ${subject}`, html: adminHtml }),
      sendEmail({ to: 'ns.srcarehive@gmail.com', subject: `Contact Form Submission: ${subject}`, html: adminHtml })
    ]);

    // Send thank you to user
    await sendEmail({ to: email, subject: 'Thank you for contacting SR CareHive', html: userHtml });

    res.json({ success: true, message: 'Contact form submitted and emails sent.' });
  } catch (e) {
    console.error('[ERROR] /api/contact:', e);
    res.status(500).json({ error: 'Failed to process contact form', details: e.message });
  }
});

// Appointment cancellation notification endpoint
app.post('/api/notify-appointment-cancelled', async (req, res) => {
  try {
    const {
      appointmentId,
      patientEmail,
      patientName,
      patientPhone,
      date,
      time,
      status,
      cancellationReason,
      registrationPaid,
      totalAmount,
      prePaid
    } = req.body || {};

    if (!appointmentId || !patientEmail || !patientName) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Format date and time in IST
    let formattedDate = 'N/A';
    let formattedDateTime = 'N/A';
    
    if (date) {
      const dateObj = new Date(date);
      
      // Format date in IST
      formattedDate = dateObj.toLocaleDateString('en-IN', { 
        timeZone: 'Asia/Kolkata',
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      });
      
      // Format full date-time in IST
      formattedDateTime = dateObj.toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      });
    }

    // Determine refund status
    let refundInfo = '';
    if (registrationPaid) {
      refundInfo = '₹10 registration fee';
    }
    if (prePaid && totalAmount) {
      const preAmount = totalAmount / 2;
      refundInfo = refundInfo 
        ? `${refundInfo} + ₹${preAmount} pre-payment = ₹${10 + preAmount} total`
        : `₹${preAmount} pre-payment`;
    }

    // Nurse notification email (to srcarehive@gmail.com and ns.srcarehive@gmail.com)
    const nurseHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🚫 Appointment Cancelled</h1>
        </div>
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;"><strong>Healthcare Seeker has cancelled their appointment.</strong></p>
          
          <div style="background: #fee2e2; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #dc2626;">
            <h3 style="margin-top: 0; color: #dc2626;">Appointment Details:</h3>
            <ul style="color: #555; font-size: 15px; line-height: 1.8;">
              <li><strong>Appointment ID:</strong> ${appointmentId}</li>
              <li><strong>Healthcare Seeker Name:</strong> ${patientName}</li>
              <li><strong>Healthcare Seeker Email:</strong> ${patientEmail}</li>
              <li><strong>Healthcare Seeker Phone:</strong> ${patientPhone}</li>
              <li><strong>Scheduled Date:</strong> ${formattedDate}</li>
              <li><strong>Scheduled Time:</strong> ${time}</li>
              <li><strong>Cancelled At:</strong> ${formattedDateTime} IST</li>
              <li><strong>Previous Status:</strong> ${status.toUpperCase()}</li>
            </ul>
          </div>

          ${cancellationReason && cancellationReason !== 'Not provided' ? `
          <div style="background: #fef3c7; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #f59e0b;">
            <h3 style="margin-top: 0; color: #f59e0b;">Cancellation Reason:</h3>
            <p style="color: #555; font-size: 15px; margin: 0;">${cancellationReason}</p>
          </div>
          ` : ''}

          ${refundInfo ? `
          <div style="background: #dbeafe; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3b82f6;">
            <h3 style="margin-top: 0; color: #3b82f6;">⚠️ Refund Required:</h3>
            <p style="color: #555; font-size: 15px; margin: 0;"><strong>${refundInfo}</strong></p>
            <p style="color: #666; font-size: 13px; margin-top: 10px;">Please process the refund manually within 5-7 business days.</p>
          </div>
          ` : `
          <div style="background: #d1fae5; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #10b981;">
            <p style="color: #065f46; font-size: 15px; margin: 0;">✅ No payment was made. No refund required.</p>
          </div>
          `}

          <p style="color: #666; font-size: 14px; margin-top: 20px;">Please check the dashboard for more details and take necessary action.</p>
        </div>
        <p style="color: #999; font-size: 12px; margin-top: 30px; text-align: center;">SR CareHive Admin System</p>
      </div>
    `;

    // Patient confirmation email
    const patientHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
        <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Appointment Cancelled</h1>
        </div>
        <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
          <p style="font-size: 16px; color: #333;">Dear <strong>${patientName}</strong>,</p>
          <p style="color: #555; line-height: 1.6;">Your healthcare provider appointment has been cancelled successfully.</p>
          
          <div style="background: #f3f4f6; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h3 style="margin-top: 0; color: #333;">Cancelled Appointment Details:</h3>
            <ul style="color: #555; font-size: 15px; line-height: 1.8;">
              <li><strong>Scheduled Date:</strong> ${formattedDate}</li>
              <li><strong>Scheduled Time:</strong> ${time}</li>
              <li><strong>Cancelled At:</strong> ${formattedDateTime} IST</li>
              <li><strong>Appointment ID:</strong> ${appointmentId}</li>
            </ul>
          </div>

          ${refundInfo ? `
          <div style="background: #dbeafe; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #3b82f6;">
            <h3 style="margin-top: 0; color: #3b82f6;">💰 Refund Information:</h3>
            <p style="color: #555; font-size: 15px; margin: 0;">Amount to be refunded: <strong>${refundInfo}</strong></p>
            <p style="color: #666; font-size: 13px; margin-top: 10px;">Your refund will be processed within <strong>5-7 business days</strong> to your original payment method.</p>
          </div>
          ` : ''}

          <p style="color: #555; line-height: 1.6; margin-top: 20px;">If you have any questions or concerns, please feel free to contact us.</p>
          
          <div style="text-align: center; margin-top: 30px;">
            <p style="color: #666; font-size: 14px;">Need to book another appointment?</p>
            <a href="${FRONTEND_URL || 'https://www.srcarehive.com'}" style="display: inline-block; background: #2260FF; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 10px;">Visit SR CareHive</a>
          </div>
        </div>
        <p style="color: #999; font-size: 12px; margin-top: 30px; text-align: center;">SR CareHive - Your Healthcare Partner</p>
      </div>
    `;

    // Send emails to both nurses
    await Promise.all([
      sendEmail({ 
        to: 'srcarehive@gmail.com', 
        subject: `🚫 Appointment Cancelled - ${patientName}`, 
        html: nurseHtml 
      }),
      sendEmail({ 
        to: 'ns.srcarehive@gmail.com', 
        subject: `🚫 Appointment Cancelled - ${patientName}`, 
        html: nurseHtml 
      })
    ]);

    // Send confirmation to patient
    await sendEmail({ 
      to: patientEmail, 
      subject: 'Appointment Cancelled - SR CareHive', 
      html: patientHtml 
    });

    console.log(`[SUCCESS] ✅ Cancellation notifications sent for appointment: ${appointmentId}`);
    res.json({ success: true, message: 'Cancellation notifications sent successfully' });

  } catch (e) {
    console.error('[ERROR] /api/notify-appointment-cancelled:', e);
    res.status(500).json({ error: 'Failed to send cancellation notifications', details: e.message });
  }
});

// ============================================================================
// DEBUG ENDPOINTS
// ============================================================================

// System status endpoint - shows configuration status
app.get('/api/debug/status', (req, res) => {
  res.json({
    timestamp: new Date().toISOString(),
    server: 'SR CareHive Backend',
    status: 'running',
    services: {
      database: {
        initialized: supabaseInitialized,
        usingServiceRole: usingServiceRole,
        available: !!supabase
      },
      email: {
        mailerExists: !!mailer,
        mailerReady: mailerReady,
        smtp: {
          host: SMTP_HOST || 'not set',
          port: SMTP_PORT || 'not set',
          user: SMTP_USER || 'not set',
          hasPassword: !!SMTP_PASS,
          secure: SMTP_SECURE
        }
      }
    },
    environment: {
      nodeEnv: process.env.NODE_ENV || 'development',
      port: PORT
    }
  });
});

// Check if email exists in database (for debugging)
app.get('/api/debug/check-email', async (req, res) => {
  try {
    const email = req.query.email;
    
    if (!email) {
      return res.status(400).json({ error: 'Email query parameter required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    
    console.log(`[DEBUG] Checking email: ${normalizedEmail}`);

    if (!supabase) {
      return res.status(500).json({ error: 'Supabase not initialized' });
    }

    // Check healthcare_providers with exact match
    const { data: hcpExact, error: hcpExactError } = await supabase
      .from('healthcare_providers')
      .select('id, email, name')
      .eq('email', normalizedEmail)
      .limit(1);

    // Check healthcare_providers with case-insensitive
    const { data: hcpIlike, error: hcpIlikeError } = await supabase
      .from('healthcare_providers')
      .select('id, email, name')
      .ilike('email', normalizedEmail)
      .limit(1);

    // Check nurses with exact match
    const { data: nurseExact, error: nurseExactError } = await supabase
      .from('nurses')
      .select('id, email, name')
      .eq('email', normalizedEmail)
      .limit(1);

    // Check nurses with case-insensitive
    const { data: nurseIlike, error: nurseIlikeError } = await supabase
      .from('nurses')
      .select('id, email, name')
      .ilike('email', normalizedEmail)
      .limit(1);

    res.json({
      searchedEmail: normalizedEmail,
      usingServiceRole: usingServiceRole,
      supabaseInitialized: supabaseInitialized,
      results: {
        healthcare_providers: {
          exactMatch: {
            found: !!(hcpExact && hcpExact.length > 0),
            count: hcpExact ? hcpExact.length : 0,
            data: hcpExact,
            error: hcpExactError
          },
          caseInsensitive: {
            found: !!(hcpIlike && hcpIlike.length > 0),
            count: hcpIlike ? hcpIlike.length : 0,
            data: hcpIlike,
            error: hcpIlikeError
          }
        },
        nurses: {
          exactMatch: {
            found: !!(nurseExact && nurseExact.length > 0),
            count: nurseExact ? nurseExact.length : 0,
            data: nurseExact,
            error: nurseExactError
          },
          caseInsensitive: {
            found: !!(nurseIlike && nurseIlike.length > 0),
            count: nurseIlike ? nurseIlike.length : 0,
            data: nurseIlike,
            error: nurseIlikeError
          }
        }
      },
      overallResult: (hcpExact && hcpExact.length > 0) || (hcpIlike && hcpIlike.length > 0) || 
                     (nurseExact && nurseExact.length > 0) || (nurseIlike && nurseIlike.length > 0) 
                     ? 'FOUND' : 'NOT FOUND'
    });

  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// EMAIL TESTING ENDPOINT (For debugging)
// ============================================================================
app.get('/api/test-email', async (req, res) => {
  try {
    console.log('[TEST-EMAIL] Received test email request');
    console.log('[TEST-EMAIL] Mailer status:', mailer ? 'Initialized' : 'Not initialized');
    console.log('[TEST-EMAIL] Mailer ready:', mailerReady);
    
    if (!mailer || !mailerReady) {
      return res.status(500).json({ 
        success: false,
        error: 'Email service not configured or not ready',
        mailer: mailer ? 'exists' : 'null',
        mailerReady: mailerReady,
        smtp: {
          host: SMTP_HOST || 'not set',
          port: SMTP_PORT || 'not set',
          user: SMTP_USER || 'not set',
          hasPassword: !!SMTP_PASS
        }
      });
    }

    const testEmail = req.query.email || 'srcarehive@gmail.com';
    
    console.log('[TEST-EMAIL] Sending test email to:', testEmail);
    
    await sendEmail({
      to: testEmail,
      subject: '✅ SR CareHive Email Test - ' + new Date().toLocaleString(),
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; background: #f0f4ff; border-radius: 10px;">
          <h2 style="color: #2260FF;">✅ Email Service Working!</h2>
          <p>This is a test email from SR CareHive backend.</p>
          <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
          <p><strong>SMTP Host:</strong> ${SMTP_HOST}</p>
          <p><strong>SMTP User:</strong> ${SMTP_USER}</p>
          <p>If you received this email, your SMTP configuration is correct! 🎉</p>
        </div>
      `
    });

    console.log('[TEST-EMAIL] ✅ Test email sent successfully');
    
    res.json({ 
      success: true,
      message: 'Test email sent successfully! Check inbox and spam folder.',
      sentTo: testEmail,
      smtp: {
        host: SMTP_HOST,
        port: SMTP_PORT,
        user: SMTP_USER
      }
    });

  } catch (e) {
    console.error('[TEST-EMAIL] ❌ Failed:', e);
    res.status(500).json({ 
      success: false,
      error: e.message,
      details: e.toString()
    });
  }
});

// ============================================================================
// PATIENT LOGIN OTP ENDPOINTS
// ============================================================================

// Send login OTP (validates credentials without logging in)
// NOW SUPPORTS: Email OR Phone Number (primary or alternative)
app.post('/send-login-otp', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ error: 'Email/Phone and password are required' });
    }

    const identifier = email.trim();
    console.log(`[LOGIN-OTP] Request for: ${identifier}`);

    // Detect if identifier is email or phone
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    const phoneRegex = /^[\d]{10}$/; // 10 digit phone number
    
    const isEmail = emailRegex.test(identifier);
    const isPhone = phoneRegex.test(identifier);
    
    if (!isEmail && !isPhone) {
      return res.status(400).json({ error: 'Invalid email or phone number format' });
    }

    const normalizedIdentifier = isEmail ? identifier.toLowerCase() : identifier;
    console.log(`[LOGIN-OTP] Type detected: ${isEmail ? 'EMAIL' : 'PHONE'}`);

    // Check cooldown (2 minutes) - use identifier as key
    const existingOTP = await getLoginOTP(normalizedIdentifier);
    if (existingOTP && existingOTP.lastSentAt) {
      const timeSinceLastSend = Date.now() - existingOTP.lastSentAt;
      const cooldownPeriod = 2 * 60 * 1000;
      
      if (timeSinceLastSend < cooldownPeriod) {
        const remainingTime = Math.ceil((cooldownPeriod - timeSinceLastSend) / 1000);
        const minutes = Math.floor(remainingTime / 60);
        const seconds = remainingTime % 60;
        
        return res.status(429).json({ 
          error: `Please wait ${minutes > 0 ? minutes + ' minute(s) ' : ''}${seconds} second(s) before requesting a new OTP.`,
          remainingSeconds: remainingTime
        });
      }
    }

    if (!supabase) {
      return res.status(500).json({ error: 'Database connection not available' });
    }

    // Step 1: Check if patient exists in patients table (by email OR phone)
    let patient = null;
    let patientEmail = null;
    
    if (isEmail) {
      // Search by email
      const { data, error: patientError } = await supabase
        .from('patients')
        .select('email, name, user_id, phone, alternative_phone')
        .eq('email', normalizedIdentifier)
        .maybeSingle();
      
      if (patientError || !data) {
        console.log(`[LOGIN-OTP] Patient not found by email: ${normalizedIdentifier}`);
        return res.status(401).json({ error: 'Invalid email/phone or password' });
      }
      patient = data;
      patientEmail = data.email;
    } else {
      // Search by phone (check both phone and alternative_phone)
      const { data, error: patientError } = await supabase
        .from('patients')
        .select('email, name, user_id, phone, alternative_phone')
        .or(`phone.eq.${normalizedIdentifier},alternative_phone.eq.${normalizedIdentifier}`)
        .maybeSingle();
      
      if (patientError || !data) {
        console.log(`[LOGIN-OTP] Patient not found by phone: ${normalizedIdentifier}`);
        return res.status(401).json({ error: 'Invalid email/phone or password' });
      }
      patient = data;
      patientEmail = data.email; // Need email for Supabase auth
      
      if (!patientEmail) {
        console.log(`[LOGIN-OTP] Patient found by phone but no email in record`);
        return res.status(401).json({ error: 'Account email not found. Please contact support.' });
      }
    }

    // Step 2: Verify password with Supabase Auth (always use email for auth)
    try {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: patientEmail, // Always use email for Supabase auth
        password: password.trim()
      });

      // Sign out immediately - we only validated credentials
      if (authData?.session) {
        await supabase.auth.signOut();
      }

      if (authError) {
        console.log(`[LOGIN-OTP] Invalid password for identifier: ${normalizedIdentifier}`);
        return res.status(401).json({ error: 'Invalid email/phone or password' });
      }
    } catch (authErr) {
      console.error(`[LOGIN-OTP] Auth error:`, authErr.message);
      return res.status(401).json({ error: 'Invalid email/phone or password' });
    }

    // Step 3: Credentials valid - Generate and send OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + (10 * 60 * 1000); // 10 minutes
    const lastSentAt = Date.now();

    // Store OTP with identifier as key (could be email or phone)
    await storeLoginOTP(normalizedIdentifier, {
      otp,
      expiresAt,
      attempts: 0,
      userId: patient.user_id,
      lastSentAt,
      password: password.trim(), // Store temporarily for final login
      email: patientEmail, // Store email for final Supabase login
      phone: patient.phone || null,
      alternative_phone: patient.alternative_phone || null,
      name: patient.name || 'User',
      loginType: isEmail ? 'email' : 'phone',
      identifier: normalizedIdentifier
    });

    console.log(`[LOGIN-OTP] OTP generated for ${normalizedIdentifier} (${isEmail ? 'email' : 'phone'}): ${otp}`);

    // Create OTP email
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
                <tr>
                  <td style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 40px 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Login Verification</h1>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 40px 30px;">
                    <p style="font-size: 16px; color: #333; margin: 0 0 20px;">Hello ${patient.name || 'there'},</p>
                    <p style="font-size: 14px; color: #666; line-height: 1.6; margin: 0 0 20px;">
                      You're attempting to log in to your SR CareHive account. Use the OTP below to complete your login:
                    </p>
                    <div style="background: linear-gradient(135deg, #2260FF 0%, #1a4fd6 100%); padding: 30px; text-align: center; border-radius: 8px; margin: 30px 0;">
                      <p style="margin: 0 0 10px; font-size: 14px; color: #ffffff; opacity: 0.9;">Your Login OTP</p>
                      <p style="margin: 0; font-size: 42px; font-weight: bold; color: #ffffff; letter-spacing: 8px; font-family: 'Courier New', monospace;">
                        ${otp}
                      </p>
                    </div>
                    <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
                      <p style="margin: 0; font-size: 13px; color: #856404;">
                        <strong>⚠️ Security Notice:</strong><br/>
                        • This OTP expires in <strong>10 minutes</strong><br/>
                        • You can request a new OTP after <strong>2 minutes</strong><br/>
                        • Never share this code with anyone<br/>
                        • If you didn't attempt to log in, ignore this email
                      </p>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #e0e0e0;">
                    <p style="margin: 0 0 10px; font-size: 14px; color: #2260FF; font-weight: bold;">SR CareHive</p>
                    <p style="margin: 0; font-size: 11px; color: #999;">
                      This is an automated email. Please do not reply.
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

    // Send OTP to the appropriate channel
    const channels = [];
    let emailSuccess = false;
    let smsSuccess = false;
    
    try {
      if (isEmail) {
        // User logged in with email - send OTP to email
        await sendEmail({
          to: patientEmail,
          subject: 'Login Verification OTP - SR CareHive',
          html: otpEmailHtml
        });
        console.log(`[LOGIN-OTP] ✅ Email sent to: ${patientEmail}`);
        emailSuccess = true;
        channels.push('email');
      } else {
        // User logged in with phone - send OTP to that phone via SMS
        console.log(`[LOGIN-OTP] 📱 Sending SMS to: ${normalizedIdentifier}`);
        try {
          smsSuccess = await sendOTPViaTubelight(
            normalizedIdentifier, 
            otp, 
            patient.name,
            TUBELIGHT_LOGIN_OTP_TEMPLATE_ID,
            'patient login'
          );
          if (smsSuccess) {
            console.log(`[LOGIN-OTP] ✅ SMS sent to: ${normalizedIdentifier}`);
            channels.push('SMS');
          } else {
            console.error(`[LOGIN-OTP] ❌ SMS failed for: ${normalizedIdentifier}`);
          }
        } catch (smsError) {
          console.error(`[LOGIN-OTP] ❌ SMS error:`, smsError.message);
        }
      }

      if (channels.length === 0) {
        return res.status(500).json({ error: 'Failed to send OTP. Please try again later.' });
      }

      res.json({ 
        success: true, 
        message: `OTP sent to your ${channels.join(' and ')}. Please check.`,
        expiresIn: 600,
        canResendAfter: 120,
        deliveryChannels: channels,
        loginType: isEmail ? 'email' : 'phone'
      });
    } catch (emailError) {
      console.error('[LOGIN-OTP] ❌ Email failed:', emailError.message);
      return res.status(500).json({ 
        error: 'Failed to send OTP email. Please try again later.'
      });
    }

  } catch (e) {
    console.error('[LOGIN-OTP] ❌ Error:', e);
    res.status(500).json({ 
      error: 'Failed to process login request', 
      details: e.message 
    });
  }
});

// Verify login OTP (NOW SUPPORTS: Email OR Phone)
app.post('/verify-login-otp', async (req, res) => {
  try {
    const { email, otp } = req.body; // 'email' param now accepts email OR phone
    
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email/Phone and OTP are required' });
    }

    const identifier = email.trim();
    const normalizedIdentifier = identifier.includes('@') ? identifier.toLowerCase() : identifier;
    const otpData = await getLoginOTP(normalizedIdentifier);

    if (!otpData) {
      return res.status(400).json({ 
        error: 'No OTP found. Please request a new one.',
        expired: true
      });
    }

    // Check expiry
    if (Date.now() > otpData.expiresAt) {
      await deleteLoginOTP(normalizedIdentifier);
      return res.status(400).json({ 
        error: 'OTP has expired. Please request a new one.',
        expired: true
      });
    }

    // Check attempts
    if (otpData.attempts >= 5) {
      await deleteLoginOTP(normalizedIdentifier);
      return res.status(429).json({ 
        error: 'Too many incorrect attempts. Please request a new OTP.',
        attemptsExceeded: true
      });
    }

    // Verify OTP
    if (otpData.otp !== otp.trim()) {
      otpData.attempts += 1;
      await storeLoginOTP(normalizedIdentifier, otpData);
      
      const remainingAttempts = 5 - otpData.attempts;
      return res.status(400).json({ 
        error: `Invalid OTP. ${remainingAttempts} attempt(s) remaining.`,
        remainingAttempts,
        invalidOtp: true
      });
    }

    // OTP verified - return success with credentials for final login
    await deleteLoginOTP(normalizedIdentifier);
    
    console.log(`[LOGIN-OTP] ✅ OTP verified for: ${normalizedIdentifier}`);
    
    // Return stored email (needed for Supabase login even if user used phone)
    res.json({ 
      success: true,
      message: 'OTP verified successfully',
      userId: otpData.userId,
      email: otpData.email || normalizedIdentifier // Use stored email
    });

  } catch (e) {
    console.error('[LOGIN-OTP] ❌ Verify error:', e);
    res.status(500).json({ 
      error: 'Failed to verify OTP', 
      details: e.message 
    });
  }
});

// Login OTP Storage Functions (Redis with fallback)
const loginOTPStore = new Map();

async function storeLoginOTP(email, otpData) {
  const key = `login-otp:${email.toLowerCase()}`;
  const ttl = 600; // 10 minutes in seconds
  
  try {
    if (redisEnabled) {
      await redis.setex(key, ttl, JSON.stringify(otpData));
      console.log(`[REDIS] ✅ Login OTP stored for: ${email}`);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] storeLoginOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  loginOTPStore.set(email.toLowerCase(), otpData);
  console.log(`[MEMORY] ✅ Login OTP stored (fallback) for: ${email}`);
  return true;
}

async function getLoginOTP(email) {
  const key = `login-otp:${email.toLowerCase()}`;
  
  try {
    if (redisEnabled) {
      const data = await redis.get(key);
      if (data) {
        console.log(`[REDIS] ✅ Login OTP retrieved for: ${email}`);
        return typeof data === 'string' ? JSON.parse(data) : data;
      }
      return null;
    }
  } catch (error) {
    console.error('❌ [REDIS] getLoginOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  const memData = loginOTPStore.get(email.toLowerCase());
  if (memData) {
    console.log(`[MEMORY] ✅ Login OTP retrieved (fallback) for: ${email}`);
  }
  return memData || null;
}

async function deleteLoginOTP(email) {
  const key = `login-otp:${email.toLowerCase()}`;
  
  try {
    if (redisEnabled) {
      await redis.del(key);
      console.log(`[REDIS] ✅ Login OTP deleted for: ${email}`);
      return true;
    }
  } catch (error) {
    console.error('❌ [REDIS] deleteLoginOTP failed:', error.message);
  }
  
  // Fallback to in-memory
  loginOTPStore.delete(email.toLowerCase());
  console.log(`[MEMORY] ✅ Login OTP deleted (fallback) for: ${email}`);
  return true;
}

// ============================================================================
// START SERVER
// ============================================================================

// Display Tubelight SMS Configuration Status on Startup
console.log('\n═══════════════════════════════════════════════════════════');
console.log('📱 TUBELIGHT SMS CONFIGURATION STATUS');
console.log('═══════════════════════════════════════════════════════════');
console.log('Username:', TUBELIGHT_USERNAME ? `✅ ${TUBELIGHT_USERNAME}` : '❌ NOT SET');
console.log('Password:', TUBELIGHT_PASSWORD ? '✅ SET (hidden)' : '❌ NOT SET');
console.log('Sender ID:', TUBELIGHT_SENDER_ID ? `✅ ${TUBELIGHT_SENDER_ID}` : '❌ NOT SET');
console.log('Entity ID:', TUBELIGHT_ENTITY_ID ? `✅ ${TUBELIGHT_ENTITY_ID}` : '❌ NOT SET');
console.log('───────────────────────────────────────────────────────────');
console.log('Template IDs:');
console.log('  Registration:', TUBELIGHT_REGISTRATION_OTP_TEMPLATE_ID || '❌ NOT SET');
console.log('  Login:', TUBELIGHT_LOGIN_OTP_TEMPLATE_ID || '❌ NOT SET');
console.log('  Patient Reset:', TUBELIGHT_PATIENT_RESET_OTP_TEMPLATE_ID || '❌ NOT SET');
console.log('  Provider Login:', TUBELIGHT_PROVIDER_LOGIN_OTP_TEMPLATE_ID || '❌ NOT SET');
console.log('  Provider Reset:', TUBELIGHT_PROVIDER_RESET_OTP_TEMPLATE_ID || '❌ NOT SET');
console.log('───────────────────────────────────────────────────────────');
console.log('SMS Status:', tubelightSMSEnabled ? '✅ ENABLED' : '❌ DISABLED');
console.log('═══════════════════════════════════════════════════════════\n');

app.listen(PORT, () => console.log(`Payment server (Razorpay) running on http://localhost:${PORT}`));
