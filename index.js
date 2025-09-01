#!/usr/bin/env node
// Simple CLI + helper to generate an HMAC SHA-256 secure hash (ICICI PG style)
// Usage examples (PowerShell):
//   node index.js --msg "sample message" --key "yourSecretKey"
//   node index.js --file params.json --key "yourSecretKey"
//   $env:HMAC_KEY="yourSecretKey"; node index.js --msg "sample message"
//   npm run hash -- --msg "sample message" --key "yourSecretKey"
// Optional flags:
//   --algo sha256|sha512 (default sha256)
//   --upper  (return uppercase hex)
//   --base64 (output Base64 instead of hex)
//   --trim   (trim message before hashing)
//   --sort   (when building from key=value pairs JSON, sort keys)
//   --quiet  (output digest only)
// Security note: NEVER commit or echo real production secret keys.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function computeHmac(message, key, { algo = 'sha256', output = 'hex', uppercase = false } = {}) {
	if (typeof message !== 'string') {
		throw new Error('Message must be a string');
	}
	if (!key) {
		throw new Error('Missing secret key');
	}
	const hmac = crypto.createHmac(algo.toLowerCase(), key);
	hmac.update(message, 'utf8');
	let digest = hmac.digest(output);
	if (uppercase && output === 'hex') digest = digest.toUpperCase();
	return digest;
}

function buildCanonicalString(obj, { sortKeys = true }) {
	if (!obj || typeof obj !== 'object') return '';
	const keys = Object.keys(obj);
	if (sortKeys) keys.sort();
	// Typical payment gateway canonical format: key=value joined by &
	return keys.map(k => `${k}=${obj[k]}`.trim()).join('&');
}

function parseArgs(argv) {
	const args = {};
	for (let i = 2; i < argv.length; i++) {
		const a = argv[i];
		if (a.startsWith('--')) {
			const key = a.slice(2);
			const next = argv[i + 1];
			if (!next || next.startsWith('--')) {
				args[key] = true; // boolean flag
			} else {
				args[key] = next;
				i++;
			}
		}
	}
	return args;
}

function loadMessageFromFile(filePath, { sort = false } = {}) {
	const full = path.resolve(process.cwd(), filePath);
	const raw = fs.readFileSync(full, 'utf8');
	// If JSON, build canonical string from object
	try {
		const parsed = JSON.parse(raw);
		if (parsed && typeof parsed === 'object') {
			return buildCanonicalString(parsed, { sortKeys: sort });
		}
	} catch (_) {
		// Not JSON, treat as raw text
	}
	return raw;
}

function showUsage() {
	console.log(`HMAC Secure Hash Generator\n\n` +
		`Options:\n` +
		`  --msg    "string"   Message to hash (or set MESSAGE env var)\n` +
		`  --file   params.json  Load message (or JSON key/value object) from file\n` +
		`  --key    secret      Secret key (or set HMAC_KEY env var)\n` +
		`  --algo   sha256|...  Hash algorithm (default sha256)\n` +
		`  --upper             Uppercase hex output\n` +
		`  --base64            Output Base64 instead of hex\n` +
		`  --trim              Trim message before hashing\n` +
		`  --sort              Sort keys when JSON -> canonical string\n` +
		`  --quiet             Digest only output\n\n` +
		`Examples:\n` +
		`  node index.js --msg "orderId=123&amount=100.00" --key "myKey"\n` +
		`  node index.js --file data.json --key "myKey" --sort --upper\n` +
		`  $env:HMAC_KEY="myKey"; $env:MESSAGE="orderId=123"; node index.js\n`);
}

if (require.main === module) {
	const args = parseArgs(process.argv);

	// ICICI specific mode (field order & no delimiter per UAT hashKey sequence)
	if (args.icici) {
		const key = args.key || process.env.HMAC_KEY || process.env.SECRET_KEY;
		if (!key) {
			console.error('Provide --key (merchant secret key) for ICICI hash generation.');
			process.exit(1);
		}
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
		const data = {};
		order.concat(['paymentMode','allowDisablePaymentMode','paymentOptionCodes']).forEach(f => { if (args[f]) data[f] = args[f]; });
		if (!data.merchantId) data.merchantId = 'T_03342';
		if (!data.amount) data.amount = '1.00';
		if (!data.currencyCode) data.currencyCode = '356';
		if (!data.payType) data.payType = '0';
		if (!data.transactionType) data.transactionType = 'SALE';
		if (!data.returnURL) data.returnURL = 'https://qa.phicommerce.com/pg/api/merchant';
		if (!data.merchantTxnNo) {
			const now = new Date();
			data.merchantTxnNo = now.getTime().toString();
		}
		if (!data.txnDate) {
			const d = new Date();
			const pad = n => n.toString().padStart(2,'0');
			data.txnDate = d.getFullYear().toString() + pad(d.getMonth()+1) + pad(d.getDate()) + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
		}
		const canonical = order.map(f => (data[f] || '').toString().trim()).join('');
		const digest = computeHmac(canonical, key, { algo: 'sha256', output: 'hex', uppercase: false });
		data.secureHash = digest;
		if (!args.quiet) {
			console.log('ICICI canonical order:', order.join(' + '));
			console.log('Canonical string   :', canonical);
			console.log('Secure Hash        :', digest);
			console.log('ICICI Request JSON :');
		}
		console.log(JSON.stringify(data, null, 2));
		process.exit(0);
	}

	// If gateway mode requested, handle early and exit (delegates to later block removed)
	if (args.gateway) {
		const key = args.key || process.env.HMAC_KEY || process.env.SECRET_KEY;
		if (!key) {
			console.error('Provide --key for gateway hash generation.');
			process.exit(1);
		}
		const data = {};
		const possible = ['merchantId','merchantTxnNo','amount','currencyCode','payType','customerEmailID','transactionType','txnDate','returnURL','customerMobileNo','addlParam1','addlParam2'];
		possible.forEach(p => { if (args[p]) data[p] = args[p]; });
		if (!data.merchantTxnNo) {
			const now = new Date();
			data.merchantTxnNo = now.getTime().toString();
		}
		if (!data.txnDate) {
			const d = new Date();
			const pad = n => n.toString().padStart(2,'0');
			data.txnDate = d.getFullYear().toString() + pad(d.getMonth()+1) + pad(d.getDate()) + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds());
		}
		const { digest, canonical } = computeGatewaySecureHash(data, key, { delimiter: args.delim || '&', uppercase: !!args.upper });
		data.secureHash = digest;
		if (!args.quiet) {
			console.log('Canonical String :', canonical);
			console.log('Secure Hash      :', digest);
			console.log('Request JSON --->');
		}
		console.log(JSON.stringify(data, null, 2));
		process.exit(0);
	}

	if (args.help || args.h) {
		showUsage();
		process.exit(0);
	}

	let message = args.msg || process.env.MESSAGE;
	if (args.file) {
		try {
			message = loadMessageFromFile(args.file, { sort: !!args.sort });
		} catch (err) {
			console.error('Failed to read file:', err.message);
			process.exit(1);
		}
	}
	if (!message) {
		console.error('No message provided. Use --msg, --file, or MESSAGE env var.');
		showUsage();
		process.exit(1);
	}
	if (args.trim) message = message.trim();

	const key = args.key || process.env.HMAC_KEY || process.env.SECRET_KEY;
	if (!key) {
		console.error('No secret key provided. Use --key or HMAC_KEY env var.');
		process.exit(1);
	}

	const algo = (args.algo || 'sha256').toLowerCase();
	const output = args.base64 ? 'base64' : 'hex';
	try {
		const digest = computeHmac(message, key, { algo, output, uppercase: !!args.upper });
		if (args.quiet) {
			process.stdout.write(digest + '\n');
		} else {
			console.log('Message    :', message);
			console.log('Algorithm  :', algo);
			console.log('Output     :', output + (args.upper ? ' (uppercase)' : ''));
			console.log('HMAC Digest:', digest);
		}
	} catch (err) {
		console.error('Error computing HMAC:', err.message);
		process.exit(1);
	}
}

// Export for programmatic use
module.exports = { computeHmac, buildCanonicalString };

// --- ICICI (generic) helper section --------------------------------------------------
// Because different gateways specify different canonical string rules, this helper lets
// you choose the field order and delimiter used when computing the secure hash.
// Adjust fieldOrder and delimiter per the official ICICI PG documentation you received.

function computeGatewaySecureHash(data, secretKey, {
	fieldOrder = [
		'merchantId',
		'merchantTxnNo',
		'amount',
		'currencyCode',
		'payType',
		'customerEmailID',
		'transactionType',
		'txnDate',
		'returnURL',
		// add further fields if spec requires (customerMobileNo, addlParam1, addlParam2, ...)
	],
	delimiter = '&', // Some gateways use | or & ; confirm with docs.
	algo = 'sha256',
	uppercase = false,
	output = 'hex'
} = {}) {
	const parts = fieldOrder.map(f => (data[f] ?? '').toString().trim());
	const canonical = parts.join(delimiter);
	const digest = computeHmac(canonical, secretKey, { algo, output, uppercase });
	return { digest, canonical, fieldOrder, delimiter };
}

// Quick CLI trigger: node index.js --gateway --key "secret" (plus other --X args matching field names)
// (Gateway branch now handled earlier in main block above)
module.exports.computeGatewaySecureHash = computeGatewaySecureHash;

