// Launch integrations. Each one switches on when its keys are in the
// environment (/etc/gamex.env on the VPS) and falls back to a safe demo
// mode otherwise:
//   OTP SMS ........ MSG91_AUTH_KEY + MSG91_TEMPLATE_ID, or TWILIO_SID + TWILIO_TOKEN + TWILIO_FROM
//                    (OTP_DEV_MODE=1 shows the code in the app; testing only, never in production)
//   Payments ....... RAZORPAY_KEY_ID + RAZORPAY_KEY_SECRET
//   Push ........... FCM_SERVICE_ACCOUNT (see growth.js)
//   Courier ........ SHIPROCKET_EMAIL + SHIPROCKET_PASSWORD (see service.js)
//   App links ...... ANDROID_SHA256 (signing certificate fingerprint)
import crypto from 'node:crypto';

const MIN = 6e4;
const env = (k) => (process.env[k] || '').trim();

/** msg91 | twilio | dev (OTP_DEV_MODE=1, code returned to the app) | off */
export const otpProvider = () =>
  env('MSG91_AUTH_KEY') && env('MSG91_TEMPLATE_ID')
    ? 'msg91'
    : env('TWILIO_SID') && env('TWILIO_TOKEN') && env('TWILIO_FROM')
      ? 'twilio'
      : env('OTP_DEV_MODE') === '1'
        ? 'dev'
        : 'off';
export const paymentsLive = () => !!(env('RAZORPAY_KEY_ID') && env('RAZORPAY_KEY_SECRET'));

const digits = (p) => String(p || '').replace(/\D/g, '').slice(-10);
const hash = (s) => crypto.createHash('sha256').update(s).digest('hex');

async function sendSms(phone10, code) {
  const p = otpProvider();
  if (p === 'msg91') {
    const url = `https://control.msg91.com/api/v5/otp?template_id=${encodeURIComponent(env('MSG91_TEMPLATE_ID'))}&mobile=91${phone10}&otp=${code}`;
    const r = await fetch(url, { method: 'POST', headers: { authkey: env('MSG91_AUTH_KEY'), 'content-type': 'application/json' }, body: '{}' });
    const j = await r.json().catch(() => ({}));
    if (j.type === 'error') throw new Error(j.message || 'SMS failed');
    return;
  }
  if (p === 'twilio') {
    const sid = env('TWILIO_SID');
    const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: 'POST',
      headers: {
        authorization: `Basic ${Buffer.from(`${sid}:${env('TWILIO_TOKEN')}`).toString('base64')}`,
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ To: `+91${phone10}`, From: env('TWILIO_FROM'), Body: `${code} is your GAMEX login code. It expires in 5 minutes. Do not share it.` }),
    });
    if (!r.ok) throw new Error('SMS failed');
    return;
  }
  console.log(`[otp:dev] ${phone10} → ${code}`);
}

export function mountLaunch(ctx) {
  const { api, site, admin, D, save, now, uid, find, bad, log, adminBase } = ctx;

  function migrate() {
    const db = D();
    db.otps ??= [];
    db.sessions ??= [];
    db.payments ??= [];
    db.settings.codLimitNew ??= 15000;
    db.settings.codMaxOpen ??= 2;
    db.settings.codEnabled ??= true;
  }
  migrate();

  // ------------------------------------------------------------- config --
  api.get('/config', (_, res) =>
    res.json({
      otp: otpProvider(),
      payments: paymentsLive() ? 'razorpay' : 'demo',
      razorpayKey: paymentsLive() ? env('RAZORPAY_KEY_ID') : null,
      push: !!env('FCM_SERVICE_ACCOUNT'),
      courier: !!(env('SHIPROCKET_EMAIL') && env('SHIPROCKET_PASSWORD')),
      cod: { enabled: D().settings.codEnabled !== false, newAccountLimit: D().settings.codLimitNew, maxOpen: D().settings.codMaxOpen },
    }),
  );

  // ---------------------------------------------------------------- OTP --
  const ipHits = new Map();
  api.post('/auth/otp/send', async (req, res) => {
    if (otpProvider() === 'off') return bad(res, 503, 'SMS login is not set up yet. Use password login for now.');
    const phone = digits(req.body?.phone);
    if (!/^[6-9]\d{9}$/.test(phone)) return bad(res, 400, 'Enter a valid 10-digit mobile number');
    const db = D();
    const t = Date.now();
    const ip = req.ip || 'x';
    const hits = (ipHits.get(ip) || []).filter((x) => t - x < 60 * MIN);
    if (hits.length >= 20) return bad(res, 429, 'Too many attempts. Try again in an hour.');
    const recent = db.otps.filter((o) => o.phone === phone && t - Date.parse(o.at) < 10 * MIN);
    if (recent.length >= 3) return bad(res, 429, 'Too many codes sent. Try again in 10 minutes.');
    if (recent[0] && t - Date.parse(recent[0].at) < 30e3) return bad(res, 429, 'Please wait 30 seconds before asking for a new code.');
    const code = String(crypto.randomInt(100000, 999999));
    try {
      await sendSms(phone, code);
    } catch (e) {
      return bad(res, 502, `Could not send SMS: ${e.message}`);
    }
    ipHits.set(ip, [...hits, t]);
    db.otps.unshift({ phone, code: hash(`${phone}:${code}`), at: now(), tries: 0 });
    db.otps = db.otps.slice(0, 500);
    save();
    // Demo mode (no SMS provider yet) returns the code so testing works.
    res.json({ sent: true, provider: otpProvider(), ...(otpProvider() === 'dev' ? { devCode: code } : {}) });
  });

  api.post('/auth/otp/verify', (req, res) => {
    const phone = digits(req.body?.phone);
    const code = String(req.body?.code || '');
    const db = D();
    const o = db.otps.find((x) => x.phone === phone);
    if (!o || Date.now() - Date.parse(o.at) > 5 * MIN) return bad(res, 400, 'Code expired. Ask for a new one.');
    if (o.tries >= 5) return bad(res, 429, 'Too many wrong codes. Ask for a new one.');
    if (o.code !== hash(`${phone}:${code}`)) {
      o.tries++;
      save();
      return bad(res, 400, 'Wrong code. Check the SMS and try again.');
    }
    db.otps = db.otps.filter((x) => x.phone !== phone);
    const id = `C${hash(`gamex:${phone}`).slice(0, 10).toUpperCase()}`;
    let c = find('customers', id) || db.customers.find((x) => digits(x.phone) === phone);
    const isNew = !c;
    if (!c) {
      c = { id, name: '', email: '', phone: `+91 ${phone}`, city: '', status: 'active', createdAt: now() };
      db.customers.unshift(c);
      log(`New customer signed up with OTP (+91 ${phone.slice(0, 2)}xxxxxx${phone.slice(-2)})`, 'customer');
    }
    if (c.status === 'blocked') return bad(res, 403, 'Your account is blocked. Contact support.');
    c.lastSeen = now();
    const token = crypto.randomBytes(24).toString('base64url');
    db.sessions.unshift({ token: hash(token), customerId: c.id, at: now() });
    db.sessions = db.sessions.slice(0, 5000);
    save();
    res.json({ token, isNew: isNew || !c.name, customer: { id: c.id, name: c.name, email: c.email, phone: c.phone } });
  });

  // ------------------------------------------------------------ Razorpay --
  const rzpAuth = () => `Basic ${Buffer.from(`${env('RAZORPAY_KEY_ID')}:${env('RAZORPAY_KEY_SECRET')}`).toString('base64')}`;

  api.post('/payments/razorpay/order', async (req, res) => {
    const { orderId, amount, customerId } = req.body || {};
    const paise = Math.round(Number(amount) * 100);
    if (!orderId || !(paise >= 100)) return bad(res, 400, 'Invalid amount');
    if (!paymentsLive()) return res.json({ demo: true });
    try {
      const r = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: { authorization: rzpAuth(), 'content-type': 'application/json' },
        body: JSON.stringify({ amount: paise, currency: 'INR', receipt: orderId, notes: { orderId, customerId: customerId || '' } }),
      });
      const j = await r.json();
      if (!j.id) return bad(res, 502, j.error?.description || 'Payment gateway error');
      D().payments.unshift({ id: uid('PY'), orderId, rzpOrderId: j.id, amount: paise / 100, status: 'created', customerId, at: now() });
      save();
      res.json({ keyId: env('RAZORPAY_KEY_ID'), rzpOrderId: j.id, amount: paise, currency: 'INR' });
    } catch (e) {
      bad(res, 502, `Payment gateway unreachable: ${e.message}`);
    }
  });

  api.post('/payments/razorpay/verify', (req, res) => {
    const { rzpOrderId, paymentId, signature } = req.body || {};
    if (!paymentsLive()) return bad(res, 400, 'Payments are in demo mode');
    const expected = crypto.createHmac('sha256', env('RAZORPAY_KEY_SECRET')).update(`${rzpOrderId}|${paymentId}`).digest('hex');
    const ok = signature && expected.length === signature.length && crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
    const p = D().payments.find((x) => x.rzpOrderId === rzpOrderId);
    if (!ok) {
      if (p) p.status = 'failed';
      save();
      return bad(res, 400, 'Payment could not be verified');
    }
    if (p) Object.assign(p, { status: 'paid', paymentId, paidAt: now() });
    save();
    res.json({ ok: true });
  });

  // ------------------------------------------------------ COD protection --
  /** Returns an error message when this COD order must be paid online. */
  function checkCod(body) {
    if (body?.payment !== 'COD') {
      // With a live gateway, online orders need a verified payment.
      if (paymentsLive()) {
        const paid = D().payments.find((p) => p.orderId === body?.orderId && p.status === 'paid');
        if (!paid) return 'Payment not received. Please complete the payment.';
        if (Math.abs(paid.amount - (Number(body.amounts?.total) || 0)) > 1) return 'Paid amount does not match the order total.';
      }
      return null;
    }
    const db = D();
    const s = db.settings;
    if (s.codEnabled === false) return 'Cash on Delivery is paused. Please pay online.';
    const cid = body.customer?.id;
    const total = Number(body.amounts?.total) || 0;
    const mine = db.orders.filter((o) => o.customerId === cid);
    const delivered = mine.some((o) => o.stage === 'delivered');
    const openCod = new Set(mine.filter((o) => o.payment === 'COD' && ['newOrder', 'accepted', 'packed', 'shipped'].includes(o.stage)).map((o) => o.orderId));
    const refused = mine.filter((o) => (o.cancelReason || '').startsWith('Refused at doorstep')).length;
    if (refused >= 2) return 'Cash on Delivery is not available on this account. Please pay online.';
    if (openCod.size >= s.codMaxOpen) return `You already have ${openCod.size} Cash on Delivery orders on the way. Pay online for this one.`;
    if (!delivered && total > s.codLimitNew) return `Cash on Delivery is available up to ₹${s.codLimitNew.toLocaleString('en-IN')} on your first order. Please pay online.`;
    return null;
  }

  admin.put('/launch-settings', (req, res) => {
    const s = D().settings;
    const { codLimitNew, codMaxOpen, codEnabled } = req.body || {};
    if (codLimitNew !== undefined) s.codLimitNew = Math.max(0, Number(codLimitNew));
    if (codMaxOpen !== undefined) s.codMaxOpen = Math.max(1, Number(codMaxOpen));
    if (codEnabled !== undefined) s.codEnabled = !!codEnabled;
    save();
    res.json(s);
  });

  // ------------------------------------------- Share links & app links --
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  site.get('/p/:id', (req, res) => {
    const l = find('listings', req.params.id);
    const id = esc(req.params.id);
    const title = l ? `${l.brand} ${l.model} • ${l.storage}` : 'GAMEX phone';
    const price = l ? `₹${l.price.toLocaleString('en-IN')}` : '';
    const base = `${req.protocol}://${req.get('host')}${adminBase}`;
    const img = l?.photos?.[0] ? (l.photos[0].startsWith('/uploads/') ? `${base}${l.photos[0]}` : '') : '';
    const deep = `gamex://app/product/${id}`;
    res.set('content-type', 'text/html; charset=utf-8').send(`<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} ${esc(price)} | GAMEX</title>
<meta property="og:title" content="${esc(title)} for ${esc(price)}">
<meta property="og:description" content="GAMEX certified second-hand phone • QC checked • open-box delivery • 7-day returns">
${img ? `<meta property="og:image" content="${esc(img)}">` : ''}
<meta property="og:type" content="product">
<style>body{margin:0;font-family:system-ui,sans-serif;background:linear-gradient(135deg,#14104a,#3b23b8,#2f6bff);color:#fff;min-height:100vh;display:grid;place-items:center}
.c{max-width:420px;padding:32px;text-align:center}h1{font-size:24px;margin:8px 0}.p{font-size:32px;font-weight:800;margin:4px 0 20px}
a{display:block;margin:10px 0;padding:14px;border-radius:14px;text-decoration:none;font-weight:700}.a{background:#fff;color:#3b23b8}.b{border:1px solid #fff6;color:#fff}</style>
</head><body><div class="c"><div style="font-weight:900;letter-spacing:2px">GAME<span style="color:#8fb4ff">X</span></div>
<h1>${esc(title)}</h1><div class="p">${esc(price)}</div>
<a class="a" href="${deep}">Open in the GAMEX app</a>
<a class="b" href="https://play.google.com/store/apps/details?id=com.gamex.gamex_shop">Get the app</a></div>
<script>setTimeout(function(){location.href=${JSON.stringify(deep)}},300)</script></body></html>`);
  });

  /** Android App Links verification (served at /.well-known/assetlinks.json by nginx). */
  const assetlinks = (_, res) => {
    const fp = env('ANDROID_SHA256');
    res.json(
      fp
        ? [{ relation: ['delegate_permission/common.handle_all_urls'], target: { namespace: 'android_app', package_name: 'com.gamex.gamex_shop', sha256_cert_fingerprints: fp.split(',').map((x) => x.trim()) } }]
        : [],
    );
  };
  site.get('/.well-known/assetlinks.json', assetlinks);

  return { migrate, checkCod, assetlinks };
}
