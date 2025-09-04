// Minimal Express server to integrate PhiCommerce (ICICI) redirect flow.
// NOTE: Keep merchant secret ONLY on server. Do NOT expose to Flutter app.
// Start: npm install && npm start (runs on http://localhost:9090 by default)

import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

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
const PHI_BASE_URL = process.env.PHI_BASE_URL || 'https://qa.phicommerce.com/pg/api';
const INITIATE_SALE_URL = 'https://qa.phicommerce.com/pg/api/v2/initiateSale';
const MERCHANT_ID = process.env.PHI_MERCHANT_ID || 'T_03342';
const MERCHANT_SECRET = process.env.PHI_SECRET || 'abc';
// For hash mismatch debugging: allow overriding with PHI_FORCE_RETURN_URL (e.g. spec sample https URL)
// Determine return URL (priority: explicit force flag for QA sample URL > forced custom > configured local)
const QA_SAMPLE_RETURN = 'https://qa.phicommerce.com/pg/api/merchant';
let RETURN_URL = process.env.PHI_RETURN_URL || 'http://localhost:9090/api/pg/payment-processing/PAYPHI';
if (process.env.PHI_FORCE_QA_RETURN === 'true') {
  RETURN_URL = QA_SAMPLE_RETURN; // Force the documented QA merchant callback (often required in early UAT)
} else if (process.env.PHI_FORCE_RETURN_URL) {
  RETURN_URL = process.env.PHI_FORCE_RETURN_URL;
}
const DEFAULT_ADDL_PARAM1 = process.env.PHI_DEFAULT_ADDL_PARAM1 || '14';
const DEFAULT_ADDL_PARAM2 = process.env.PHI_DEFAULT_ADDL_PARAM2 || '15';
const CURRENCY_CODE = process.env.PHI_CURRENCY_CODE || '356';
const PAY_TYPE = process.env.PHI_PAY_TYPE || '0';

// Supabase client (uses anon key for dev; for production use service_role secret and secure server-side RLS policies)
let supabase = null;
if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
  supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
}

// In-memory pending appointment store: merchantTxnNo -> appointment payload (for dev only)
const pendingAppointments = new Map();

// Utility: format date as yyyyMMddHHmmss
function formatTxnDate(d = new Date()) {
  const pad = n => n.toString().padStart(2, '0');
  return (
    d.getFullYear().toString() +
    pad(d.getMonth() + 1) +
    pad(d.getDate()) +
    pad(d.getHours()) +
    pad(d.getMinutes()) +
    pad(d.getSeconds())
  );
}

// Generate merchant transaction number (ensure uniqueness) - keep length reasonable
function generateMerchantTxnNo() {
  // Pattern: yymmddHHMMss + 3 random digits -> length 15 similar to examples
  const d = new Date();
  const pad = n => n.toString().padStart(2,'0');
  const base = d.getFullYear().toString().slice(2) + pad(d.getMonth()+1) + pad(d.getDate()) + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
  const rand = Math.floor(Math.random()*900+100); // 3 digits
  return base + rand;
}

// Compute secure hash as per provided canonical sequence.
function computeSecureHash(fields, { noTrim = false } = {}) {
  const order = [
    'addlParam1',
    'addlParam2',
    'amount',
    'currencyCode',
    'customerEmailID',
    'customerMobileNo',
    'merchantId',
    'merchantTxnNo',
    'payType',
    'returnURL',
    'transactionType',
    'txnDate'
  ];
  const canonicalParts = order.map(k => {
    const raw = fields[k] == null ? '' : fields[k].toString();
    return noTrim ? raw : raw.trim();
  });
  const canonical = canonicalParts.join('');
  const hmac = crypto.createHmac('sha256', MERCHANT_SECRET);
  hmac.update(canonical, 'utf8');
  const digest = hmac.digest('hex');
  return { digest, canonical, order, canonicalParts };
}

// Experimental alternative sequences / mutations for diagnostics (not sent to gateway)
function computeDiagnosticVariants(baseFields) {
  const variants = [];
  // 1. Current official implementation
  variants.push({ label: 'current', ...computeSecureHash(baseFields) });
  // 2. Include paymentMode between payType and returnURL (spec ambiguity)
  if (baseFields.paymentMode) {
    const order = [
      'addlParam1','addlParam2','amount','currencyCode','customerEmailID','customerMobileNo','merchantId','merchantTxnNo','payType','paymentMode','returnURL','transactionType','txnDate'
    ];
    const canonicalParts = order.map(k => (baseFields[k] == null ? '' : baseFields[k].toString().trim()));
    const canonical = canonicalParts.join('');
    const digest = crypto.createHmac('sha256', MERCHANT_SECRET).update(canonical,'utf8').digest('hex');
    variants.push({ label: 'with_paymentMode', digest, canonical, order, canonicalParts });
  }
  // 3. Blank addlParams (some merchants keep them empty)
  const blankAddl = { ...baseFields, addlParam1: '', addlParam2: '' };
  variants.push({ label: 'blank_addlParams', ...computeSecureHash(blankAddl) });
  // 4. Amount stripped of trailing zeros (e.g., 1.00 -> 1) which some gateways normalize
  const strippedAmount = { ...baseFields, amount: parseFloat(baseFields.amount).toString() };
  variants.push({ label: 'stripped_amount', ...computeSecureHash(strippedAmount) });
  return variants;
}

// Produce hash according to selected variant label. Returns { digest, canonical, order, appliedFields }.
function computeVariantHash(baseFields, variantLabel) {
  switch ((variantLabel || 'current').trim()) {
    case 'with_paymentMode': {
      const order = ['addlParam1','addlParam2','amount','currencyCode','customerEmailID','customerMobileNo','merchantId','merchantTxnNo','payType','paymentMode','returnURL','transactionType','txnDate'];
      const canonicalParts = order.map(k => (baseFields[k] == null ? '' : baseFields[k].toString().trim()));
      const canonical = canonicalParts.join('');
      const digest = crypto.createHmac('sha256', MERCHANT_SECRET).update(canonical,'utf8').digest('hex');
      return { digest, canonical, order, appliedFields: { ...baseFields } };
    }
    case 'blank_addlParams': {
      const modified = { ...baseFields, addlParam1: '', addlParam2: '' };
      return { ...computeSecureHash(modified), appliedFields: modified };
    }
    case 'stripped_amount': {
      const modified = { ...baseFields, amount: parseFloat(baseFields.amount).toString() };
      return { ...computeSecureHash(modified), appliedFields: modified };
    }
    case 'current':
    default:
      return { ...computeSecureHash(baseFields), appliedFields: { ...baseFields } };
  }
}

// Initiate Sale (Redirect) endpoint consumed by Flutter app
app.post('/api/pg/payment/initiateSale', async (req, res) => {
  try {
  if (!process.env.PHI_SECRET) {
    return res.status(500).json({ error: 'Server misconfigured: PHI_SECRET missing.' });
  }
  if (MERCHANT_SECRET === 'abc') {
    if (process.env.DISALLOW_PLACEHOLDER_SECRET === 'true') {
      return res.status(500).json({ error: 'Placeholder secret abc blocked. Set real PHI_SECRET.' });
    }
    console.warn('[WARN] Using placeholder PHI_SECRET=abc. Ensure this matches UAT kit. Set DISALLOW_PLACEHOLDER_SECRET=true to forbid.');
  }
  const { amount = '1.00', customerEmailID, customerMobileNo, appointment, paymentMode, allowDisablePaymentMode, paymentOptionCodes } = req.body || {};
    const fallbackEmail = process.env.PHI_DEFAULT_EMAIL || 'srcarehive@gmail.com';
    const fallbackMobile = process.env.PHI_DEFAULT_MOBILE || '8923068966';
    const emailFinal = (customerEmailID || fallbackEmail).trim();
    let suppliedMobileRaw = (customerMobileNo || '').replace(/[^0-9]/g,'');
    let mobileRaw = suppliedMobileRaw || fallbackMobile;
    // If 10-digit, prepend 91; if starts with 0 and length 11 -> drop leading 0 then prepend 91; if already starts 91 keep; else truncate extras.
    if (/^0\d{10}$/.test(mobileRaw)) mobileRaw = mobileRaw.slice(1);
    if (/^\d{10}$/.test(mobileRaw)) mobileRaw = '91' + mobileRaw;
    if (/^91\d{10,}$/.test(mobileRaw) && mobileRaw.length > 12) mobileRaw = mobileRaw.slice(0,12); // trim over-length
    const strictMobile = process.env.PHI_STRICT_VALIDATE_MOBILE === 'true';
    if (!emailFinal || !/^\S+@\S+\.\S+$/.test(emailFinal)) {
      if (strictMobile) return res.status(400).json({ error: 'Invalid customerEmailID' });
    }
    if (!/^91\d{10}$/.test(mobileRaw)) {
      if (strictMobile) return res.status(400).json({ error: 'Invalid customerMobileNo after normalization (need 91 + 10 digits)' });
      console.warn('Mobile invalid, falling back to default', { supplied: suppliedMobileRaw, fallbackUsed: fallbackMobile });
      mobileRaw = '91' + fallbackMobile.replace(/[^0-9]/g,'').slice(-10);
      if (!/^91\d{10}$/.test(mobileRaw)) return res.status(400).json({ error: 'Unable to derive valid fallback mobile' });
    }
    const merchantTxnNo = generateMerchantTxnNo();
    const txnDate = formatTxnDate();
    // Normalize mobile: prepend 91 if 10 digits and missing country code
    const normalizedMobile = mobileRaw;

  const data = {
      merchantId: MERCHANT_ID,
      merchantTxnNo,
      amount: parseFloat(amount).toFixed(2),
      currencyCode: CURRENCY_CODE,
      payType: PAY_TYPE,
  customerEmailID: emailFinal,
      transactionType: 'SALE',
      txnDate,
      returnURL: RETURN_URL,
  customerMobileNo: normalizedMobile,
      addlParam1: DEFAULT_ADDL_PARAM1,
      addlParam2: DEFAULT_ADDL_PARAM2
    };

  // Optional payment mode restriction (UPI, NB, Cards etc.)
  const finalPaymentMode = paymentMode || process.env.PHI_PAYMENT_MODE;
  if (finalPaymentMode) data.paymentMode = finalPaymentMode; // DON'T add to canonical string.
  if (allowDisablePaymentMode) data.allowDisablePaymentMode = allowDisablePaymentMode;
  if (paymentOptionCodes) data.paymentOptionCodes = paymentOptionCodes; // e.g., specific bank code
  const variantLabel = process.env.PHI_HASH_VARIANT || 'current';
  const { digest, canonical, order, canonicalParts, appliedFields } = computeVariantHash(data, variantLabel);
  Object.assign(data, appliedFields); // In case variant mutated fields (amount, addlParams)
  data.secureHash = digest;

    // Diagnostic: compute digests using candidate secrets list (comma separated env) to detect secret mismatch quickly
    let altSecretDiagnostics = [];
    const diagSecretCsv = process.env.PHI_DIAG_CANDIDATE_SECRETS || (MERCHANT_SECRET === 'abc' ? '0' : '');
    if (diagSecretCsv) {
      const altSecrets = diagSecretCsv.split(',').map(s=>s.trim()).filter(s=>s && s!==MERCHANT_SECRET);
      for (const alt of altSecrets) {
        try {
          const h = crypto.createHmac('sha256', alt).update(canonical, 'utf8').digest('hex');
          altSecretDiagnostics.push({ candidateSecret: alt, digest: h });
        } catch (e) {
          altSecretDiagnostics.push({ candidateSecret: alt, error: e.message });
        }
      }
    }

    // Store appointment details temporarily (not persisted across restarts)
    if (appointment) {
      pendingAppointments.set(merchantTxnNo, {
        ...appointment,
        merchantTxnNo,
        amount: parseFloat(amount).toFixed(2),
        created_at: new Date().toISOString(),
        status: 'payment_pending'
      });
    }

    // Call PhiCommerce initiateSale
    const diagVariants = computeDiagnosticVariants(data);
    console.log('initiateSale request ->', JSON.stringify({
      merchantTxnNo,
      primaryHash: digest,
      canonical,
      hashVariantSelected: variantLabel,
  secretFingerprint: `${MERCHANT_SECRET.length}:${MERCHANT_SECRET[0]}...${MERCHANT_SECRET[MERCHANT_SECRET.length-1]}`,
      diagVariants: diagVariants.map(v => ({ label: v.label, digest: v.digest, canonical: v.canonical })),
      altSecretDiagnostics,
      postedFields: Object.keys(data).sort(),
      subset: { amount: data.amount, mobile: data.customerMobileNo, paymentMode: data.paymentMode, returnURL: data.returnURL }
    }, null, 2));
    let gatewayResp;
    let response;
    try {
      response = await fetch(INITIATE_SALE_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
      const text = await response.text();
      try { gatewayResp = JSON.parse(text); } catch { gatewayResp = { raw: text }; }
    } catch (fetchErr) {
      console.error('Fetch to PhiCommerce failed:', fetchErr);
      return res.status(502).json({ error: 'Fetch failed', message: fetchErr.message });
    }
    if (!response.ok) {
      console.error('Gateway non-200', response.status, gatewayResp);
      return res.status(502).json({ error: 'Gateway error', status: response.status, gatewayResp });
    }
    if (!gatewayResp.redirectURI || !gatewayResp.tranCtx) {
      console.error('Gateway missing redirectURI/tranCtx (likely hash mismatch)', JSON.stringify({
        merchantTxnNo,
        gatewayResp,
        primaryHash: digest,
        diagVariants: diagVariants.map(v => ({ label: v.label, digest: v.digest }))
      }, null, 2));
      return res.status(500).json({ error: 'Missing redirectURI/tranCtx', gatewayResp, hashTried: digest });
    }
    const redirectUrl = `${gatewayResp.redirectURI}?tranCtx=${encodeURIComponent(gatewayResp.tranCtx)}`;
    console.log('initiateSale success ->', JSON.stringify({
      merchantTxnNo,
      redirectUrl,
      hash: { digest, canonical, order, parts: canonicalParts },
      requestSubset: { amount: data.amount, paymentMode: data.paymentMode, mobile: data.customerMobileNo, returnURL: data.returnURL },
      gatewayResp
    }, null, 2));
    res.json({
      redirectUrl,
      merchantTxnNo,
      secureHash: digest,
      canonical,
      gateway: gatewayResp
    });
  } catch (err) {
    console.error('initiateSale error', err);
    res.status(500).json({ error: 'Internal error', message: err.message });
  }
});

// Return URL (callback) - PhiCommerce will redirect user here
// For now just logs and returns a simple page. Enhance to persist status & notify app via websocket / polling.
app.all('/api/pg/payment-processing/PAYPHI', async (req, res) => {
  console.log('--- Payment Return Callback ---');
  console.log('Query:', req.query);
  const merchantTxnNo = req.query.merchantTxnNo || req.query.merchanttxno || req.query.txnNo;
  const statusCode = req.query.responseCode || req.query.status;
  if (merchantTxnNo && pendingAppointments.has(merchantTxnNo)) {
    const appt = pendingAppointments.get(merchantTxnNo);
    appt.status = statusCode === 'R1000' ? 'paid' : 'unknown';
    // Persist appointment if paid and supabase available
    if (appt.status === 'paid' && supabase) {
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
            merchant_txn_no: merchantTxnNo
        });
        appt.persisted = true;
      } catch (dbErr) {
        console.error('Supabase insert failed', dbErr.message);
      }
    }
  }
  res.setHeader('Content-Type', 'text/html');
  res.end(`<html><body style=\"font-family:Arial;\"><h2>Payment Processed</h2><p>Txn: ${merchantTxnNo || 'N/A'} status: ${statusCode || 'N/A'}</p></body></html>`);
});

// Status polling endpoint for app (optional)
app.get('/api/pg/payment/status/:merchantTxnNo', (req, res) => {
  const appt = pendingAppointments.get(req.params.merchantTxnNo);
  if (!appt) return res.status(404).json({ error: 'Not found' });
  res.json(appt);
});

// Guess of STATUS secure hash order: amount + merchantId + merchantTxnNo + originalTxnNo + transactionType
function computeStatusSecureHash(data) {
  const order = ['amount','merchantId','merchantTxnNo','originalTxnNo','transactionType'];
  const canonical = order.map(k => (data[k] || '').toString().trim()).join('');
  const hmac = crypto.createHmac('sha256', MERCHANT_SECRET).update(canonical,'utf8').digest('hex');
  return { canonical, digest: hmac, order };
}

app.post('/api/pg/payment/status-check', async (req, res) => {
  try {
    const { merchantTxnNo } = req.body || {};
    if (!merchantTxnNo) return res.status(400).json({ error: 'merchantTxnNo required' });
    const appt = pendingAppointments.get(merchantTxnNo);
    const amount = appt?.amount || '1.00';
    const payload = {
      merchantId: MERCHANT_ID,
      merchantTxnNo,
      originalTxnNo: merchantTxnNo,
      amount: amount,
      transactionType: 'STATUS'
    };
    const { digest, canonical } = computeStatusSecureHash(payload);
    payload.secureHash = digest;
    let response, gatewayResp;
    try {
      response = await fetch('https://qa.phicommerce.com/pg/api/command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const text = await response.text();
      try { gatewayResp = JSON.parse(text); } catch { gatewayResp = { raw: text }; }
    } catch (fe) {
      return res.status(502).json({ error: 'Fetch failed', message: fe.message });
    }
    if (!response.ok) return res.status(502).json({ error: 'Gateway error', status: response.status, gatewayResp });
    res.json({ request: payload, canonical, gatewayResp });
  } catch (err) {
    res.status(500).json({ error: 'Internal error', message: err.message });
  }
});

// Debug: compute secure hash for arbitrary provided sale-like fields to compare with spec examples
app.post('/api/pg/payment/debug/hash', (req, res) => {
  try {
    const f = req.body || {};
    // Only pick relevant fields; allow overrides.
    const data = {
      addlParam1: f.addlParam1 || '',
      addlParam2: f.addlParam2 || '',
      amount: f.amount || '',
      currencyCode: f.currencyCode || '',
      customerEmailID: f.customerEmailID || '',
      customerMobileNo: f.customerMobileNo || '',
      merchantId: f.merchantId || MERCHANT_ID,
      merchantTxnNo: f.merchantTxnNo || '',
      payType: f.payType || '',
      returnURL: f.returnURL || '',
      transactionType: f.transactionType || '',
      txnDate: f.txnDate || ''
    };
    const { digest, canonical, order, canonicalParts } = computeSecureHash(data);
    res.json({ order, canonicalParts, canonical, digest, secretFingerprint: `${MERCHANT_SECRET.length}:${MERCHANT_SECRET[0]}...${MERCHANT_SECRET[MERCHANT_SECRET.length-1]}` });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Brute force variant matcher to identify which field variant the gateway used to produce a given secureHash
app.post('/api/pg/payment/debug/guess', (req, res) => {
  try {
    const {
      gatewayHash,
      base = {},
      candidateSecrets
    } = req.body || {};
    if (!gatewayHash) return res.status(400).json({ error: 'gatewayHash required' });
    const secretsToTry = Array.isArray(candidateSecrets) && candidateSecrets.length ? candidateSecrets : [MERCHANT_SECRET];
    const merchantId = base.merchantId || MERCHANT_ID;
    const merchantTxnNo = base.merchantTxnNo || 'TESTTXN001';
    const txnDate = base.txnDate || formatTxnDate();
    const email = base.customerEmailID || 'srcarehive@gmail.com';
    const amountBase = base.amount || '1.00';
    const payType = base.payType || '0';
    const transactionType = base.transactionType || 'SALE';
    const returnChoices = [
      'https://qa.phicommerce.com/pg/api/merchant',
      process.env.PHI_FORCE_RETURN_URL,
      process.env.PHI_RETURN_URL,
      'http://localhost:9090/api/pg/payment-processing/PAYPHI'
    ].filter(Boolean);
    const addl1Choices = [base.addlParam1, '14', 'Test1'].filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i);
    const addl2Choices = [base.addlParam2, '15', 'Test2'].filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i);
    const amountChoices = [amountBase, parseFloat(amountBase).toString()].filter((v,i,a)=>a.indexOf(v)===i);
    const mobileBase = base.customerMobileNo || '8923068966';
    const mobileRaw = mobileBase.replace(/[^0-9]/g,'').slice(-10);
    const mobileChoices = [
      '91'+mobileRaw,
      mobileRaw,
      '+91'+mobileRaw
    ].filter((v,i,a)=>a.indexOf(v)===i);
    const includePaymentModeChoices = [false, true];

    const matches = [];
    let tested = 0;
    outer: for (const secret of secretsToTry) {
      for (const add1 of addl1Choices) {
        for (const add2 of addl2Choices) {
          for (const amt of amountChoices) {
            for (const ret of returnChoices) {
              for (const mob of mobileChoices) {
                for (const incPM of includePaymentModeChoices) {
                  const fields = {
                    addlParam1: add1,
                    addlParam2: add2,
                    amount: amt,
                    currencyCode: base.currencyCode || CURRENCY_CODE,
                    customerEmailID: email,
                    customerMobileNo: mob,
                    merchantId,
                    merchantTxnNo,
                    payType,
                    returnURL: ret,
                    transactionType,
                    txnDate
                  };
                  // Inline hash with candidate secret
                  const order = ['addlParam1','addlParam2','amount','currencyCode','customerEmailID','customerMobileNo','merchantId','merchantTxnNo','payType','returnURL','transactionType','txnDate'];
                  const canonical = order.map(k => (fields[k] || '').toString().trim()).join('');
                  const digest = crypto.createHmac('sha256', secret).update(canonical,'utf8').digest('hex');
                  tested++;
                  if (digest === gatewayHash) {
                    matches.push({
                      digest,
                      canonical,
                      variant: { secretFingerprint: `${secret.length}:${secret[0]}...${secret[secret.length-1]}`, add1, add2, amt, ret, mob, includePaymentMode: incPM }
                    });
                    break outer;
                  }
                }
              }
            }
          }
        }
      }
    }
    res.json({ tested, matches, note: matches.length ? 'MATCH_FOUND' : 'No match in explored variants', secretsTried: secretsToTry.length });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Direct secret hash test: provide canonical OR fields and list of candidate secrets
app.post('/api/pg/payment/debug/secret-hash', (req, res) => {
  try {
    const { canonical, fields, secrets } = req.body || {};
    if (!canonical && !fields) return res.status(400).json({ error: 'Provide canonical or fields' });
    const list = Array.isArray(secrets) && secrets.length ? secrets : [MERCHANT_SECRET];
    let canon = canonical;
    if (!canon) {
      const base = {
        addlParam1: fields.addlParam1 || '',
        addlParam2: fields.addlParam2 || '',
        amount: fields.amount || '',
        currencyCode: fields.currencyCode || '',
        customerEmailID: fields.customerEmailID || '',
        customerMobileNo: fields.customerMobileNo || '',
        merchantId: fields.merchantId || '',
        merchantTxnNo: fields.merchantTxnNo || '',
        payType: fields.payType || '',
        returnURL: fields.returnURL || '',
        transactionType: fields.transactionType || '',
        txnDate: fields.txnDate || ''
      };
      canon = ['addlParam1','addlParam2','amount','currencyCode','customerEmailID','customerMobileNo','merchantId','merchantTxnNo','payType','returnURL','transactionType','txnDate'].map(k=> (base[k]||'').toString().trim()).join('');
    }
    const results = list.map(sec => ({
      secretFingerprint: `${sec.length}:${sec[0]}...${sec[sec.length-1]}`,
      digest: crypto.createHmac('sha256', sec).update(canon,'utf8').digest('hex')
    }));
    res.json({ canonical: canon, results });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, () => console.log(`Payment server running on http://localhost:${PORT}`));
