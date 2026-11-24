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
import express from 'express';

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
    db.settings.demoCatalog ??= true;
  }
  migrate();

  // ------------------------------------------------------------- config --
  api.get('/config', (_, res) =>
    res.json({
      otp: otpProvider(),
      payments: paymentsLive() ? 'razorpay' : 'demo',
      razorpayKey: paymentsLive() ? env('RAZORPAY_KEY_ID') : null,
      push: !!env('FCM_SERVICE_ACCOUNT'),
      aiSupport: !!env('ANTHROPIC_API_KEY'),
      courier: !!(env('SHIPROCKET_EMAIL') && env('SHIPROCKET_PASSWORD')),
      demoCatalog: D().settings.demoCatalog !== false,
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

  /**
   * Checks (and uses up) an SMS code. Returns [status, error] on failure or
   * null when the code is right.
   */
  function checkOtp(phone, code) {
    const db = D();
    const o = db.otps.find((x) => x.phone === phone);
    if (!o || Date.now() - Date.parse(o.at) > 5 * MIN) return [400, 'Code expired. Ask for a new one.'];
    if (o.tries >= 5) return [429, 'Too many wrong codes. Ask for a new one.'];
    if (o.code !== hash(`${phone}:${String(code)}`)) {
      o.tries++;
      save();
      return [400, 'Wrong code. Check the SMS and try again.'];
    }
    db.otps = db.otps.filter((x) => x.phone !== phone);
    return null;
  }

  api.post('/auth/otp/verify', (req, res) => {
    const phone = digits(req.body?.phone);
    const err = checkOtp(phone, req.body?.code || '');
    if (err) return bad(res, err[0], err[1]);
    const db = D();
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

  // ------------------------------------------------------------- Refunds --
  /**
   * Refunds [amount] of an order. Online payments go back through Razorpay
   * automatically; COD / demo orders are marked for a manual bank/UPI refund
   * that the admin confirms. Never throws.
   */
  async function refund(o, amount, reason) {
    const rupees = Math.max(0, Math.round(Number(amount) || 0));
    const base = { amount: rupees, reason, at: now() };
    if (!rupees) return;
    if (o.refund && ['processed', 'pending', 'manual-done'].includes(o.refund.status)) return;
    const online = o.payment !== 'COD' && o.paymentId;
    if (!online) {
      o.refund = { ...base, status: o.payment === 'COD' ? 'manual' : 'demo' };
      o.events.push({ l: o.payment === 'COD' ? `Refund ₹${rupees.toLocaleString('en-IN')} to be paid to the buyer's bank/UPI` : `Refund ₹${rupees.toLocaleString('en-IN')} (demo payment)`, a: now() });
      save();
      return;
    }
    if (!paymentsLive()) {
      o.refund = { ...base, status: 'demo' };
      save();
      return;
    }
    try {
      const r = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(o.paymentId)}/refund`, {
        method: 'POST',
        headers: { authorization: rzpAuth(), 'content-type': 'application/json' },
        body: JSON.stringify({ amount: rupees * 100, speed: 'normal', notes: { orderId: o.id, reason } }),
      });
      const j = await r.json();
      if (!j.id) throw new Error(j.error?.description || 'refund failed');
      o.refund = { ...base, status: j.status === 'processed' ? 'processed' : 'pending', id: j.id };
      o.events.push({ l: `Refund ₹${rupees.toLocaleString('en-IN')} sent to the original payment method (${j.id})`, a: now() });
      ctx.notifyCustomer?.(o.customerId, 'Refund started 💸', `₹${rupees.toLocaleString('en-IN')} for ${o.item} is on its way to your original payment method (5-7 working days).`, 'order', `/order/${o.orderId}`);
    } catch (e) {
      o.refund = { ...base, status: 'failed', error: e.message };
      o.events.push({ l: `Refund failed • ${e.message}`, a: now() });
    }
    save();
  }

  admin.post('/refunds/:id', async (req, res) => {
    const o = find('orders', req.params.id);
    if (!o) return bad(res, 404, 'Order not found');
    const { action, note = '', amount } = req.body || {};
    if (action === 'retry') {
      if (o.refund?.status !== 'failed') return bad(res, 409, 'Only failed refunds can be retried');
      const amt = o.refund.amount;
      o.refund = null;
      await refund(o, amt, 'Retry');
      return res.json(o.refund);
    }
    if (action === 'manual-done') {
      if (!o.refund || !['manual', 'failed', 'demo'].includes(o.refund.status)) return bad(res, 409, 'Nothing to confirm');
      o.refund.status = 'manual-done';
      o.refund.note = String(note).slice(0, 120);
      o.refund.doneAt = now();
      o.events.push({ l: `Refund paid manually${note ? ` • ${note}` : ''}`, a: now() });
      ctx.notifyCustomer?.(o.customerId, 'Refund paid 💸', `₹${o.refund.amount.toLocaleString('en-IN')} for ${o.item} has been sent${note ? ` (ref ${note})` : ''}.`, 'order', `/order/${o.orderId}`);
      save();
      return res.json(o.refund);
    }
    if (action === 'issue') {
      await refund(o, amount ?? o.payable ?? o.price, String(note || 'Refund by GAMEX'));
      return res.json(o.refund);
    }
    bad(res, 400, 'Unknown action');
  });

  /** Razorpay webhook (Dashboard → Webhooks, secret = RAZORPAY_WEBHOOK_SECRET). */
  api.post('/payments/razorpay/webhook', (req, res) => {
    const secret = env('RAZORPAY_WEBHOOK_SECRET');
    if (!secret) return bad(res, 404, 'Webhook not configured');
    const sig = String(req.headers['x-razorpay-signature'] || '');
    const expected = crypto.createHmac('sha256', secret).update(req.rawBody || '').digest('hex');
    if (!sig || sig.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) {
      return bad(res, 400, 'Bad signature');
    }
    const ev = req.body?.event || '';
    const db = D();
    if (ev.startsWith('refund.')) {
      const r = req.body.payload?.refund?.entity;
      const o = db.orders.find((x) => x.refund?.id === r?.id);
      if (o && r) {
        o.refund.status = ev === 'refund.processed' ? 'processed' : ev === 'refund.failed' ? 'failed' : o.refund.status;
        o.events.push({ l: `Refund ${o.refund.status}`, a: now() });
      }
    } else if (ev === 'payment.captured') {
      const p = req.body.payload?.payment?.entity;
      const rec = db.payments.find((x) => x.rzpOrderId === p?.order_id);
      if (rec && rec.status !== 'paid') Object.assign(rec, { status: 'paid', paymentId: p.id, paidAt: now() });
    }
    save();
    res.json({ ok: true });
  });

  admin.put('/launch-settings', (req, res) => {
    const s = D().settings;
    const { codLimitNew, codMaxOpen, codEnabled, demoCatalog } = req.body || {};
    if (demoCatalog !== undefined) s.demoCatalog = !!demoCatalog;
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

  // ------------------------------------------------ Policy pages (Play Store) --
  const page = (title, body) => `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} | GAMEX</title><style>body{margin:0;font-family:system-ui,sans-serif;color:#0d1030;background:#f6f4ff}
header{background:linear-gradient(135deg,#14104a,#3b23b8,#2f6bff);color:#fff;padding:28px 20px}h1{margin:6px 0 0;font-size:26px}
main{max-width:760px;margin:0 auto;padding:20px;line-height:1.6}h2{font-size:18px;margin-top:28px}a{color:#3b23b8}
.card{background:#fff;border-radius:16px;padding:18px;box-shadow:0 8px 24px #5b4bd614}input,textarea,button{font:inherit;width:100%;box-sizing:border-box;padding:12px;border-radius:12px;border:1px solid #ddd;margin:6px 0}
button{background:#3b5bff;color:#fff;border:0;font-weight:700}</style></head><body><header><div style="font-weight:900;letter-spacing:2px">GAME<span style="color:#8fb4ff">X</span></div><h1>${title}</h1></header><main>${body}
<p style="margin-top:32px;color:#666;font-size:13px">Questions: support@gamex.in • Last updated ${new Date().toISOString().slice(0, 10)}</p></main></body></html>`;
  const html = (res, t, b) => res.set('content-type', 'text/html; charset=utf-8').send(page(t, b));

  site.get('/privacy', (_, res) =>
    html(res, 'Privacy Policy', `<div class="card">
<p>GAMEX ("we") runs a marketplace for certified second-hand phones in India. This policy explains what we collect and why.</p>
<h2>What we collect</h2><ul>
<li><b>Account:</b> name, mobile number, email (for login with OTP, order updates).</li>
<li><b>Orders:</b> delivery address, items, payment status. Card/UPI details are handled by our payment partner (Razorpay) and never stored by GAMEX.</li>
<li><b>Trade-in, repair and sell requests:</b> phone model, condition answers, IMEI when inspected, payout UPI/bank details.</li>
<li><b>Reviews and questions</b> you post, including photos.</li>
<li><b>Device:</b> push-notification token, app version; microphone only for voice search and the health check; camera only for QR scanning, health check and review photos.</li></ul>
<h2>Why we use it</h2><p>To deliver orders, verify phones, prevent fraud (e.g. Cash on Delivery limits, IMEI blacklist checks), process refunds and warranty claims, send updates you asked for, and improve the app.</p>
<h2>Who we share it with</h2><p>Only what is needed: the seller of your order, courier partners (name, phone, address), payment partner, SMS and notification providers. We never sell your data.</p>
<h2>Your choices</h2><p>You can update your profile in the app, turn off notifications, and request deletion of your account at <a href="delete-account">Delete my account</a>. We keep invoices and order records as required by Indian tax law.</p>
<h2>Security</h2><p>Data is sent over HTTPS and stored on servers in India with restricted access.</p></div>`),
  );

  site.get('/terms', (_, res) =>
    html(res, 'Terms of Sale', `<div class="card">
<p>Phones on GAMEX are pre-owned devices sold by verified sellers and inspected by GAMEX QC before listing.</p>
<h2>Condition and inspection</h2><p>Each listing shows its grade, battery health, defects and a GAMEX QC certificate linked to the IMEI. Open-box delivery lets you check the phone before sharing the delivery OTP.</p>
<h2>Prices and payment</h2><p>Prices include GST. Online payments are processed by Razorpay. Cash on Delivery may be limited for new accounts or high-value orders.</p>
<h2>Offers, trade-in and wallet</h2><p>Accepted offers are held for 48 hours. Trade-in values are confirmed at pickup and may be revised if the condition differs. Wallet cashback is credited after the return window and can pay part of an order.</p>
<h2>Warranty and returns</h2><p>See the <a href="refund-policy">Return & Refund Policy</a>. Seller warranty and GAMEX protection plans cover hardware faults, not physical or liquid damage unless the plan says so.</p></div>`),
  );

  site.get('/refund-policy', (_, res) =>
    html(res, 'Return & Refund Policy', `<div class="card">
<h2>7-day returns</h2><p>Request a return from the order page within the return window shown on the order (usually 7 days after delivery). We arrange a free pickup.</p>
<h2>Inspection</h2><p>Returned phones are checked against the delivery condition and IMEI. Returns with new damage or a changed IMEI can be rejected.</p>
<h2>Refunds</h2><p>Approved refunds go back to the original payment method within 5-7 working days; Cash on Delivery orders are refunded to your bank / UPI. Wallet money used is returned to the wallet.</p>
<h2>Refused at the door</h2><p>If the phone does not match the listing during open-box delivery, refuse it and you are not charged.</p></div>`),
  );

  site.get('/delete-account', (_, res) =>
    html(res, 'Delete my GAMEX account', `<div class="card">
<p>Enter the mobile number of your GAMEX account. We will verify it and delete your account and personal data within 30 days. Invoices required by law are kept.</p>
<form method="post" action="delete-account"><input name="phone" placeholder="Mobile number" required pattern="[0-9 +]{10,14}">
<textarea name="reason" placeholder="Reason (optional)" rows="3"></textarea><button>Request deletion</button></form></div>`),
  );

  site.post('/delete-account', express.urlencoded({ extended: false }), (req, res) => {
    const phone = digits(req.body?.phone);
    if (phone.length !== 10) return html(res, 'Delete my GAMEX account', '<div class="card"><p>Please enter a valid 10-digit mobile number. <a href="delete-account">Try again</a>.</p></div>');
    const db = D();
    db.deletionRequests ??= [];
    db.deletionRequests.unshift({ id: uid('DR'), phone, reason: String(req.body?.reason || '').slice(0, 300), at: now(), status: 'requested' });
    log(`Account deletion requested (+91 ${phone.slice(0, 2)}xxxxxx${phone.slice(-2)})`, 'customer');
    save();
    html(res, 'Request received', '<div class="card"><p>We received your request. Our team will confirm by SMS and delete your account within 30 days.</p></div>');
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

  return { migrate, checkCod, assetlinks, checkOtp, refund };
}
