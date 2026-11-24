// Customer authentication: password login / sign-up, OTP sessions (see
// launch.js) and a guard that ties every customer request to the logged-in
// account. Mounted on the API router BEFORE all other routes.
import crypto from 'node:crypto';

const hash = (s) => crypto.createHash('sha256').update(s).digest('hex');
const digits = (p) => String(p || '').replace(/\D/g, '').slice(-10);
const SESSION_DAYS = 90;

function hashPassword(pw) {
  const salt = crypto.randomBytes(16);
  const key = crypto.scryptSync(pw, salt, 32);
  return `scrypt$${salt.toString('hex')}$${key.toString('hex')}`;
}
function checkPassword(pw, stored) {
  const [alg, salt, key] = String(stored || '').split('$');
  if (alg !== 'scrypt' || !salt || !key) return false;
  const got = crypto.scryptSync(pw, Buffer.from(salt, 'hex'), 32);
  const want = Buffer.from(key, 'hex');
  return got.length === want.length && crypto.timingSafeEqual(got, want);
}

/** Routes a customer must be logged in for ("METHOD path-regex"). */
const PROTECTED = [
  'POST /orders$', 'GET /orders/status$', 'POST /orders/[^/]+/refuse$', 'GET /orders/[^/]+/tracking$',
  'POST /returns$', 'POST /warranty-claims$', 'POST /live$', 'GET /live/status$',
  'GET /trade-ins$', 'POST /offers$', 'GET /offers$', 'POST /offers/[^/]+/respond$',
  'GET /alerts$', 'POST /alerts$', 'DELETE /alerts/[^/]+$',
  'GET /customers/[^/]+/notifications$', 'POST /customers/[^/]+/notifications/read$', 'POST /push/register$',
  'GET /wallet/[^/]+$', 'POST /referrals/apply$', 'POST /customers/sync$',
  'POST /repairs$', 'GET /repairs$', 'POST /repairs/[^/]+/cancel$',
  'POST /sell-requests$', 'GET /sell-requests$', 'POST /sell-requests/[^/]+/cancel$',
  'GET /support/tickets', 'POST /support/tickets', 'GET /support/chat$', 'POST /support/chat/',
  'POST /reviews$', 'POST /payments/razorpay/order$', 'POST /auth/logout$', 'GET /auth/me$', 'PUT /auth/me$',
].map((r) => {
  const [m, p] = r.split(' ');
  return [m, new RegExp(`^${p}`)];
});

export function mountAuth(ctx) {
  const { api, D, save, now, uid, find, bad, log, codeFor } = ctx;

  function migrate() {
    D().sessions ??= [];
  }
  migrate();

  function issue(customerId) {
    const token = crypto.randomBytes(24).toString('base64url');
    const db = D();
    db.sessions.unshift({ token: hash(token), customerId, at: now() });
    db.sessions = db.sessions.slice(0, 20000);
    return token;
  }

  function sessionFor(req) {
    const h = String(req.headers.authorization || '');
    if (!h.startsWith('Bearer ')) return null;
    const t = hash(h.slice(7).trim());
    const s = D().sessions.find((x) => x.token === t);
    if (!s || Date.now() - Date.parse(s.at) > SESSION_DAYS * 864e5) return null;
    const c = find('customers', s.customerId);
    if (!c || c.status === 'blocked') return null;
    return { session: s, customer: c };
  }

  const view = (c) => ({ id: c.id, name: c.name, email: c.email, phone: c.phone, createdAt: c.createdAt, referralCode: c.referralCode });

  // ---- Guard: binds customer ids in every request to the session. ----
  api.use((req, res, next) => {
    const s = sessionFor(req);
    if (s) {
      const id = s.customer.id;
      req.customer = s.customer;
      // Path ids (wallet, notifications) must be the caller's own.
      req.url = req.url.replace(/^\/wallet\/[^/?]+/, `/wallet/${id}`).replace(/^\/customers\/[^/?]+\/notifications/, `/customers/${id}/notifications`);
      if (req.query && typeof req.query === 'object' && 'customerId' in req.query) req.query.customerId = id;
      const b = req.body;
      if (b && typeof b === 'object') {
        if (!Array.isArray(b)) b.customerId = id;
        if (b.customer && typeof b.customer === 'object') b.customer.id = id;
        if (req.path === '/customers/sync') b.id = id;
      }
    }
    const route = req.path;
    if (PROTECTED.some(([m, r]) => m === req.method && r.test(route)) && !s) {
      return bad(res, 401, 'Please log in to continue');
    }
    next();
  });

  // ---- Password accounts ----
  const fails = new Map();
  const tooMany = (key) => (fails.get(key) || []).filter((t) => Date.now() - t < 15 * 6e4).length >= 8;
  const fail = (key) => fails.set(key, [...(fails.get(key) || []), Date.now()].slice(-20));

  api.post('/auth/register', (req, res) => {
    const { name = '', email = '', phone = '', password = '' } = req.body || {};
    const p = digits(phone);
    const e = String(email).trim().toLowerCase();
    if (String(name).trim().length < 2) return bad(res, 400, 'Please enter your name');
    if (!/^[6-9]\d{9}$/.test(p)) return bad(res, 400, 'Enter a valid 10-digit mobile number');
    if (e && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) return bad(res, 400, 'Enter a valid email');
    if (String(password).length < 8) return bad(res, 400, 'Password must be at least 8 characters');
    const db = D();
    const existing = db.customers.find((c) => digits(c.phone) === p || (e && c.email?.toLowerCase() === e));
    if (existing?.password) return bad(res, 409, 'An account already exists with this number or email. Please log in.');
    const c = existing || { id: `C${hash(`gamex:${p}`).slice(0, 10).toUpperCase()}`, status: 'active', createdAt: now(), city: '' };
    Object.assign(c, { name: String(name).trim(), email: e, phone: `+91 ${p}`, password: hashPassword(String(password)) });
    c.referralCode ??= codeFor(c.id);
    if (!existing) {
      db.customers.unshift(c);
      log(`New customer ${c.name} signed up`, 'customer');
    }
    const token = issue(c.id);
    save();
    res.json({ token, customer: view(c) });
  });

  api.post('/auth/login', (req, res) => {
    const { identifier = '', password = '' } = req.body || {};
    const id = String(identifier).trim().toLowerCase();
    const key = `${req.ip}|${id}`;
    if (tooMany(key)) return bad(res, 429, 'Too many attempts. Try again in 15 minutes or use OTP login.');
    const p = digits(id);
    const c = D().customers.find((x) => (id.includes('@') ? x.email?.toLowerCase() === id : digits(x.phone) === p && p.length === 10));
    if (!c || !checkPassword(String(password), c.password)) {
      fail(key);
      return bad(res, 401, 'Incorrect mobile number / email or password');
    }
    if (c.status === 'blocked') return bad(res, 403, 'Your account is blocked. Contact support.');
    c.lastSeen = now();
    const token = issue(c.id);
    save();
    res.json({ token, customer: view(c) });
  });

  api.post('/auth/logout', (req, res) => {
    const t = hash(String(req.headers.authorization || '').slice(7).trim());
    const db = D();
    db.sessions = db.sessions.filter((s) => s.token !== t);
    save();
    res.json({ ok: true });
  });

  api.get('/auth/me', (req, res) => res.json(view(req.customer)));

  api.put('/auth/me', (req, res) => {
    const c = req.customer;
    const { name, email } = req.body || {};
    if (name !== undefined) {
      if (String(name).trim().length < 2) return bad(res, 400, 'Please enter your name');
      c.name = String(name).trim().slice(0, 60);
    }
    if (email !== undefined) {
      const e = String(email).trim().toLowerCase();
      if (e && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) return bad(res, 400, 'Enter a valid email');
      c.email = e;
    }
    save();
    res.json(view(c));
  });

  /** Password reset over OTP: verified phone sets a new password. */
  api.post('/auth/reset-password', (req, res) => {
    const { password = '' } = req.body || {};
    const s = sessionFor(req);
    if (!s) return bad(res, 401, 'Verify your number with OTP first');
    if (String(password).length < 8) return bad(res, 400, 'Password must be at least 8 characters');
    s.customer.password = hashPassword(String(password));
    save();
    res.json({ ok: true });
  });

  return { migrate, issue, sessionFor, uid };
}
