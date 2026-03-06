// Hush License Server — Cloudflare Worker
// Endpoints:
//   POST /webhook       — Stripe webhook (checkout.session.completed)
//   GET  /success       — Post-payment redirect page
//   POST /activate      — App activates license with session_id + hardware_id
//   POST /validate      — App revalidates license periodically

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': 'https://tryhush.app',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    try {
      switch (url.pathname) {
        case '/webhook':
          return handleWebhook(request, env);
        case '/success':
          return handleSuccess(request, env);
        case '/activate':
          return handleActivate(request, env);
        case '/validate':
          return handleValidate(request, env);
        case '/health':
          return json({ status: 'ok', timestamp: Date.now() });
        default:
          return json({ error: 'Not found' }, 404);
      }
    } catch (err) {
      console.error('Unhandled error:', err);
      return json({ error: 'Internal server error' }, 500);
    }
  },
};

// ─── POST /webhook ───
// Stripe sends checkout.session.completed
async function handleWebhook(request, env) {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const body = await request.text();
  const signature = request.headers.get('stripe-signature');

  // Verify Stripe webhook signature
  const isValid = await verifyStripeSignature(body, signature, env.STRIPE_WEBHOOK_SECRET);
  if (!isValid) {
    return json({ error: 'Invalid signature' }, 401);
  }

  const event = JSON.parse(body);

  if (event.type !== 'checkout.session.completed') {
    return json({ received: true });
  }

  const session = event.data.object;
  const email = session.customer_details?.email || session.customer_email;
  const sessionId = session.id;

  if (!email) {
    return json({ error: 'No email found' }, 400);
  }

  // Store license keyed by session_id
  const license = {
    email,
    session_id: sessionId,
    devices: [],
    created_at: new Date().toISOString(),
    max_devices: parseInt(env.MAX_DEVICES) || 3,
  };

  await env.LICENSES.put(`session:${sessionId}`, JSON.stringify(license));
  await env.LICENSES.put(`email:${email}`, sessionId);

  return json({ received: true, email });
}

// ─── GET /success ───
// Post-payment redirect — shows session_id to copy into app
async function handleSuccess(request, env) {
  const url = new URL(request.url);
  const sessionId = url.searchParams.get('session_id');

  if (!sessionId) {
    return htmlPage('Erreur', '<p>Session ID manquant.</p>');
  }

  // Fetch email from Stripe
  let email = '';
  try {
    const stripeRes = await fetch(`https://api.stripe.com/v1/checkout/sessions/${sessionId}`, {
      headers: { 'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}` },
    });
    const stripeSession = await stripeRes.json();
    email = stripeSession.customer_details?.email || stripeSession.customer_email || '';

    // Ensure license exists in KV (in case webhook hasn't fired yet)
    const existing = await env.LICENSES.get(`session:${sessionId}`);
    if (!existing && email) {
      const license = {
        email,
        session_id: sessionId,
        devices: [],
        created_at: new Date().toISOString(),
        max_devices: parseInt(env.MAX_DEVICES) || 3,
      };
      await env.LICENSES.put(`session:${sessionId}`, JSON.stringify(license));
      await env.LICENSES.put(`email:${email}`, sessionId);
    }
  } catch (e) {
    console.error('Stripe fetch error:', e);
  }

  return htmlPage('Merci pour votre achat !', `
    <div style="text-align:center; max-width:500px; margin:0 auto;">
      <div style="font-size:64px; margin-bottom:24px;">🎉</div>
      <h1 style="font-size:28px; margin-bottom:16px;">Merci pour votre achat !</h1>
      <p style="color:#6e6e73; margin-bottom:32px;">
        Activation en cours... Retour vers Hush.
      </p>
      <p id="fallback" style="display:none; color:#6e6e73; font-size:14px;">
        Si Hush ne s'ouvre pas automatiquement,
        <a href="hush://activate?session_id=${sessionId}" style="color:#0071e3;">cliquez ici</a>.
      </p>
      <div id="manual" style="display:none; margin-top:32px;">
        <p style="color:#6e6e73; font-size:14px; margin-bottom:12px;">
          Ou copiez ce code dans Hush &rarr; Param&egrave;tres &rarr; Licence :
        </p>
        <div style="background:#f5f5f7; border-radius:12px; padding:20px; font-family:monospace; font-size:13px; word-break:break-all; margin-bottom:16px; border:1px solid #e5e5e7;">
          ${sessionId}
        </div>
        <button onclick="navigator.clipboard.writeText('${sessionId}').then(()=>{this.textContent='Copié ✓';this.style.background='#34c759'})"
          style="background:#0071e3; color:white; border:none; padding:14px 32px; border-radius:980px; font-size:16px; font-weight:600; cursor:pointer; transition:all 0.2s;">
          Copier le code
        </button>
      </div>
      ${email ? `<p style="color:#6e6e73; font-size:14px; margin-top:24px;">Confirmation envoy&eacute;e &agrave; ${email}</p>` : ''}
      <script>
        // Auto-redirect via deep link
        setTimeout(function() {
          window.location.href = 'hush://activate?session_id=${sessionId}';
        }, 1500);
        // Show fallback after 4s
        setTimeout(function() {
          document.getElementById('fallback').style.display = 'block';
        }, 4000);
        // Show manual copy after 8s
        setTimeout(function() {
          document.getElementById('manual').style.display = 'block';
        }, 8000);
      </script>
    </div>
  `);
}

// ─── POST /activate ───
// App sends { session_id, hardware_id } → receives JWT
async function handleActivate(request, env) {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const { session_id, hardware_id } = await request.json();

  if (!session_id || !hardware_id) {
    return json({ error: 'Missing session_id or hardware_id' }, 400);
  }

  const data = await env.LICENSES.get(`session:${session_id}`);
  if (!data) {
    return json({ error: 'License not found' }, 404);
  }

  const license = JSON.parse(data);

  // Check if hardware_id already registered
  if (license.devices.includes(hardware_id)) {
    const token = await generateJWT(license, hardware_id, env);
    return json({ success: true, token }, 200, CORS_HEADERS);
  }

  // Check device limit
  if (license.devices.length >= license.max_devices) {
    return json({
      error: `Device limit reached (${license.max_devices}). Deactivate a device first.`,
      devices: license.devices.length,
      max: license.max_devices,
    }, 403, CORS_HEADERS);
  }

  // Register new device
  license.devices.push(hardware_id);
  await env.LICENSES.put(`session:${session_id}`, JSON.stringify(license));

  const token = await generateJWT(license, hardware_id, env);
  return json({ success: true, token }, 200, CORS_HEADERS);
}

// ─── POST /validate ───
// App sends { token, hardware_id } → confirms validity
async function handleValidate(request, env) {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const { token, hardware_id } = await request.json();

  if (!token || !hardware_id) {
    return json({ error: 'Missing token or hardware_id' }, 400);
  }

  const payload = await verifyJWT(token, env);
  if (!payload) {
    return json({ valid: false, error: 'Invalid token' }, 200, CORS_HEADERS);
  }

  // Verify hardware_id matches
  if (payload.hardware_id !== hardware_id) {
    return json({ valid: false, error: 'Hardware mismatch' }, 200, CORS_HEADERS);
  }

  // Check license still exists and device is registered
  const data = await env.LICENSES.get(`session:${payload.sid}`);
  if (!data) {
    return json({ valid: false, error: 'License revoked' }, 200, CORS_HEADERS);
  }

  const license = JSON.parse(data);
  if (!license.devices.includes(hardware_id)) {
    return json({ valid: false, error: 'Device deactivated' }, 200, CORS_HEADERS);
  }

  return json({ valid: true, email: license.email }, 200, CORS_HEADERS);
}

// ─── JWT (Ed25519) ───
// ED25519_PRIVATE_KEY is stored as base64 in Worker secret
async function generateJWT(license, hardwareId, env) {
  const header = base64url(JSON.stringify({ alg: 'EdDSA', typ: 'JWT' }));
  const payload = base64url(JSON.stringify({
    sid: license.session_id,
    email: license.email,
    hardware_id: hardwareId,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60), // 1 year
  }));

  const data = `${header}.${payload}`;

  // Import Ed25519 private key
  const privateKeyBytes = Uint8Array.from(atob(env.ED25519_PRIVATE_KEY), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'raw',
    privateKeyBytes,
    { name: 'Ed25519' },
    false,
    ['sign']
  );

  const sig = await crypto.subtle.sign('Ed25519', key, new TextEncoder().encode(data));
  const signature = arrayToBase64url(new Uint8Array(sig));

  return `${data}.${signature}`;
}

async function verifyJWT(token, env) {
  try {
    const [header, payload, signature] = token.split('.');
    const data = `${header}.${payload}`;

    // Import Ed25519 public key (derived from private key)
    const privateKeyBytes = Uint8Array.from(atob(env.ED25519_PRIVATE_KEY), c => c.charCodeAt(0));
    const privateKey = await crypto.subtle.importKey(
      'raw',
      privateKeyBytes,
      { name: 'Ed25519' },
      true,
      ['sign']
    );
    // Export to get public key via PKCS8 → re-import is complex, so just re-sign and compare
    // Instead, store public key separately or verify by re-signing
    // Simpler: use the private key to verify on server side by re-generating the signature
    const expectedSig = await crypto.subtle.sign('Ed25519', privateKey, new TextEncoder().encode(data));
    const expectedB64 = arrayToBase64url(new Uint8Array(expectedSig));

    if (expectedB64 !== signature) return null;

    const decoded = JSON.parse(base64urlDecode(payload));

    // Check expiration
    if (decoded.exp && decoded.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return decoded;
  } catch {
    return null;
  }
}

function base64url(str) {
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function arrayToBase64url(arr) {
  return btoa(String.fromCharCode(...arr))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlDecode(str) {
  let b64 = str.replace(/-/g, '+').replace(/_/g, '/');
  const pad = b64.length % 4;
  if (pad) b64 += '='.repeat(4 - pad);
  return atob(b64);
}

// ─── Stripe Webhook Signature Verification ───
async function verifyStripeSignature(body, signature, secret) {
  if (!signature || !secret) return false;

  try {
    const parts = Object.fromEntries(
      signature.split(',').map(p => p.split('='))
    );
    const timestamp = parts.t;
    const sig = parts.v1;

    // Reject if timestamp is too old (5 min tolerance)
    const age = Math.floor(Date.now() / 1000) - parseInt(timestamp);
    if (age > 300) return false;

    const payload = `${timestamp}.${body}`;
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const expected = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload));
    const expectedHex = Array.from(new Uint8Array(expected))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return expectedHex === sig;
  } catch {
    return false;
  }
}

// ─── Helpers ───
function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS, ...extraHeaders },
  });
}

function htmlPage(title, body) {
  return new Response(`<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — Hush</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
      background: #fafafa;
      color: #1d1d1f;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 24px;
    }
  </style>
</head>
<body>${body}</body>
</html>`, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
