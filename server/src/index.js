// GAMEX API server: one database shared by the shop app, the seller app
// and the super admin panel. Data is kept in data/db.json.
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import cors from 'cors';
import express from 'express';
import multer from 'multer';
import { CHECKLIST, buildSeed, imeiFrom, titleOf } from './seed.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DB_FILE = path.join(ROOT, 'data', 'db.json');
const UPLOADS = path.join(ROOT, 'uploads');
const ADMIN_DIST = path.resolve(ROOT, '..', 'admin', 'dist');
const PORT = Number(process.env.PORT || 8080);
const HOST = process.env.HOST || '0.0.0.0';
const ADMIN_BASE = (process.env.ADMIN_BASE || '/gamex').replace(/\/$/, '');
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@gamex.in';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'gamex@123';

// ---------------- Storage ----------------
let db;
try {
  db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
} catch {
  db = buildSeed();
}
// Bring databases created by older versions up to date.
function migrate() {
  db.blacklist ??= buildSeed().blacklist;
  db.claims ??= [];
  for (const l of db.listings) {
    l.defects ??= [];
    l.returnDays ??= 7;
    if (!l.certificate && ['active', 'soldOut', 'paused'].includes(l.status) && l.qc?.decision === 'approved') {
      l.certificate = `GXC-${l.id.replace('GXL', '')}-${crypto.randomInt(1000, 9999)}`;
    }
  }
  for (const o of db.orders) {
    o.otp ??= String(crypto.randomInt(1000, 9999));
    if (o.stage === 'delivered' || o.stage === 'returned') {
      o.deliveredAt ??= (o.events.find((e) => e.l === 'Delivered') || o.events[o.events.length - 1]).a;
    }
    const l = db.listings.find((x) => x.id === o.listingId);
    o.returnDays ??= l?.returnDays ?? 7;
    o.warrantyMonths ??= l?.warranty ?? 0;
    o.imei ??= l?.imei ?? null;
    o.certificate ??= l?.certificate ?? null;
    o.returnRequest ??= null;
  }
  for (const c of db.live) c.messages ??= [];
}
migrate();
let saveTimer;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    fs.mkdirSync(path.dirname(DB_FILE), { recursive: true });
    fs.writeFileSync(DB_FILE + '.tmp', JSON.stringify(db));
    fs.renameSync(DB_FILE + '.tmp', DB_FILE);
  }, 150);
}
save();

const now = () => new Date().toISOString();
const uid = (p) => `${p}${Date.now().toString(36).toUpperCase()}${crypto.randomInt(100, 999)}`;
const find = (col, id) => db[col].find((x) => x.id === id);
function log(text, kind) {
  db.activity.unshift({ id: uid('A'), text, kind, at: now() });
  db.activity = db.activity.slice(0, 80);
}
function notify(sellerId, title, body, kind = 'info') {
  db.notifications.unshift({ id: uid('N'), sellerId, title, body, kind, at: now(), read: [] });
  db.notifications = db.notifications.slice(0, 200);
}
const fees = (price) => (price * db.settings.commissionRate + db.settings.fixedFee) * 1.18;
const payout = (price) => price - fees(price);

// ---------------- App ----------------
const app = express();
app.set('trust proxy', 'loopback');
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '2mb' }));
// Everything is reachable both at / and under ADMIN_BASE (e.g. /gamex/api),
// so GAMEX can share a domain with another site that owns the root.
const site = express.Router();
site.use('/img', express.static(path.join(ROOT, 'public', 'img'), { maxAge: '7d' }));
site.use('/uploads', express.static(UPLOADS, { maxAge: '30d' }));

const upload = multer({
  storage: multer.diskStorage({
    destination: UPLOADS,
    filename: (_, f, cb) => cb(null, `${Date.now()}-${crypto.randomInt(1e6)}${path.extname(f.originalname || '.jpg').toLowerCase() || '.jpg'}`),
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_, f, cb) => cb(null, /^image\//.test(f.mimetype) || /\.(jpe?g|png|webp|heic)$/i.test(f.originalname)),
});

const api = express.Router();
site.use('/api', api);
app.use(ADMIN_BASE, site);
app.use(site);
const bad = (res, code, msg) => res.status(code).json({ error: msg });

api.get('/health', (_, res) => res.json({ ok: true, time: now(), listings: db.listings.length }));

api.post('/upload', upload.single('photo'), (req, res) => {
  if (!req.file) return bad(res, 400, 'No photo received');
  res.json({ url: `/uploads/${req.file.filename}` });
});

// ======================================================
// Shop app (customers)
// ======================================================
const sellerOf = (l) => find('sellers', l.sellerId);
const isLive = (l) => {
  const s = sellerOf(l);
  return ['active', 'soldOut'].includes(l.status) && s && s.status === 'approved' && s.online !== false;
};
const publicListing = (l) => {
  const s = sellerOf(l);
  return {
    ...l,
    imei: undefined,
    seller: s ? { id: s.id, storeName: s.storeName, city: s.city, rating: s.rating, since: s.createdAt, verified: s.status === 'approved' } : null,
  };
};
const luhn = (imei) => {
  if (!/^\d{15}$/.test(imei)) return false;
  return imeiFrom(imei.slice(0, 14)) === imei;
};
const blacklisted = (imei) => db.blacklist.find((b) => b.imei === imei) || null;
const deliveredAt = (o) => o.deliveredAt || (o.stage === 'delivered' ? o.events[o.events.length - 1].a : null);

api.get('/products', (_, res) => {
  res.json(
    db.listings
      .filter(isLive)
      .sort((a, b) => (b.approvedAt || b.createdAt).localeCompare(a.approvedAt || a.createdAt))
      .map(publicListing),
  );
});

api.get('/products/:id', (req, res) => {
  const l = find('listings', req.params.id);
  if (!l || !isLive(l)) return bad(res, 404, 'Not found');
  l.views = (l.views || 0) + 1;
  save();
  res.json(publicListing(l));
});

api.get('/banners', (_, res) => res.json(db.banners.filter((b) => b.active).sort((a, b) => a.order - b.order)));
api.get('/coupons', (_, res) => res.json(db.coupons.filter((c) => c.active && c.expiresAt > now())));

api.post('/customers/sync', (req, res) => {
  const { id, name, email = '', phone = '', city = '' } = req.body || {};
  if (!id || !name) return bad(res, 400, 'id and name required');
  let c = find('customers', id);
  if (!c) {
    c = { id, name, email, phone, city, status: 'active', createdAt: now() };
    db.customers.unshift(c);
    log(`New customer ${name} signed up`, 'customer');
  } else Object.assign(c, { name, email: email || c.email, phone: phone || c.phone, lastSeen: now() });
  save();
  res.json(c);
});

const STAGE_FOR_CUSTOMER = { newOrder: 'pending', accepted: 'confirmed', packed: 'confirmed', shipped: 'shipped', delivered: 'delivered', cancelled: 'cancelled', returned: 'cancelled' };

// ---------- Trust: certificate, IMEI, seller profile ----------
api.get('/certificates/:code', (req, res) => {
  const code = String(req.params.code).trim().toUpperCase();
  const l = db.listings.find((x) => (x.certificate || '').toUpperCase() === code);
  if (!l) return res.status(404).json({ valid: false, error: 'No GAMEX certificate with this number' });
  const s = sellerOf(l);
  res.json({
    valid: true,
    certificate: l.certificate,
    listingId: l.id,
    live: isLive(l),
    status: l.status,
    brand: l.brand,
    model: l.model,
    ram: l.ram,
    storage: l.storage,
    color: l.color,
    grade: l.grade,
    battery: l.battery,
    imei: l.imei,
    warranty: l.warranty,
    photo: l.photos[0],
    checks: l.checks,
    defects: l.defects || [],
    qc: l.qc ? { by: l.qc.by, at: l.qc.at } : null,
    seller: s ? { id: s.id, storeName: s.storeName, city: s.city } : null,
    blacklisted: !!blacklisted(l.imei),
  });
});

api.get('/imei/:imei', (req, res) => {
  const imei = String(req.params.imei).replace(/\D/g, '');
  if (imei.length !== 15) return bad(res, 400, 'IMEI must be 15 digits');
  const b = blacklisted(imei);
  const l = db.listings.find((x) => x.imei === imei);
  res.json({
    imei,
    validChecksum: luhn(imei),
    blacklisted: !!b,
    blacklistReason: b?.reason ?? null,
    reportedAt: b?.at ?? null,
    gamex: l
      ? { listingId: l.id, title: titleOf(l), certificate: l.certificate || null, status: l.status, live: isLive(l) }
      : null,
    checkedAt: now(),
  });
});

api.get('/sellers/:id/public', (req, res) => {
  const s = find('sellers', req.params.id);
  if (!s || s.status === 'pending') return bad(res, 404, 'Seller not found');
  const mine = db.orders.filter((o) => o.sellerId === s.id);
  const accepted = mine
    .map((o) => {
      const a = o.events.find((e) => e.l.startsWith('Accepted'));
      return a ? (new Date(a.a) - new Date(o.placedAt)) / 6e4 : null;
    })
    .filter((x) => x !== null && x >= 0);
  const rejected = mine.filter((o) => o.events.some((e) => e.l.startsWith('Rejected by seller'))).length;
  const listings = db.listings.filter((l) => l.sellerId === s.id);
  res.json({
    id: s.id,
    storeName: s.storeName,
    ownerName: s.ownerName.split(' ')[0],
    city: s.city,
    rating: s.rating,
    since: s.createdAt,
    verified: s.status === 'approved',
    gst: !!s.gstin,
    sold: listings.reduce((t, l) => t + (l.sold || 0), 0),
    delivered: mine.filter((o) => o.stage === 'delivered').length,
    responseMins: accepted.length ? Math.round(accepted.reduce((a, b) => a + b, 0) / accepted.length) : null,
    cancelRate: mine.length ? Math.round((rejected * 1000) / mine.length) / 10 : 0,
    listings: listings.filter(isLive).map(publicListing),
  });
});

api.post('/orders', (req, res) => {
  const { orderId, customer, address, payment, items } = req.body || {};
  if (!orderId || !customer || !address || !Array.isArray(items)) return bad(res, 400, 'Invalid order');
  const cust = find('customers', customer.id);
  if (cust && cust.status === 'blocked') return bad(res, 403, 'Your account is blocked. Contact support.');
  const created = [];
  items.forEach((it, i) => {
    const l = find('listings', it.listingId);
    if (!l) return;
    if (l.stock < (it.qty || 1)) return;
    l.stock -= it.qty || 1;
    l.sold = (l.sold || 0) + (it.qty || 1);
    if (l.stock <= 0) l.status = 'soldOut';
    const o = {
      id: items.length > 1 ? `${orderId}-${i + 1}` : orderId,
      orderId,
      sellerId: l.sellerId,
      customerId: customer.id,
      listingId: l.id,
      item: titleOf(l),
      variant: `${l.ram} / ${l.storage} • ${l.color}`,
      photo: l.photos[0],
      price: l.price * (it.qty || 1),
      buyer: address.fullName || customer.name,
      phone: address.phone || customer.phone || '',
      address: address.details ? `${address.details}, ${address.area || ''}` : '',
      city: address.city || '',
      pincode: address.pincode || '',
      payment,
      stage: 'newOrder',
      placedAt: now(),
      events: [{ l: 'Order placed', a: now() }],
      awb: null,
      courier: null,
      pickupAt: null,
      imeiVerified: false,
      cancelReason: null,
      otp: String(crypto.randomInt(1000, 9999)),
      deliveredAt: null,
      returnDays: l.returnDays ?? 7,
      warrantyMonths: l.warranty ?? 0,
      imei: l.imei,
      certificate: l.certificate || null,
      returnRequest: null,
    };
    db.orders.unshift(o);
    created.push(o.id);
    notify(l.sellerId, `New order ${o.id}`, `${o.item} • ₹${o.price.toLocaleString('en-IN')} — accept within 4 hours.`, 'order');
    log(`New order ${o.id} • ${o.item} (${sellerOf(l)?.storeName})`, 'order');
  });
  if (!created.length) return bad(res, 409, 'These phones are no longer available');
  save();
  res.json({ ids: created });
});

api.get('/orders/status', (req, res) => {
  const ids = String(req.query.ids || '').split(',').filter(Boolean);
  res.json(
    db.orders
      .filter((o) => ids.includes(o.orderId))
      .map((o) => {
        const s = find('sellers', o.sellerId);
        return {
          orderId: o.orderId,
          id: o.id,
          listingId: o.listingId,
          item: o.item,
          variant: o.variant,
          photo: o.photo,
          price: o.price,
          stage: o.stage,
          status: STAGE_FOR_CUSTOMER[o.stage],
          awb: o.awb,
          courier: o.courier,
          events: o.events,
          // The doorstep OTP is only needed once the phone is on its way.
          otp: o.stage === 'shipped' ? o.otp : null,
          deliveredAt: deliveredAt(o),
          returnDays: o.returnDays ?? 7,
          warrantyMonths: o.warrantyMonths ?? 0,
          imei: o.imei,
          certificate: o.certificate,
          returnRequest: o.returnRequest,
          claims: db.claims.filter((c) => c.orderId === o.id),
          seller: s ? { id: s.id, storeName: s.storeName, city: s.city, phone: s.phone } : null,
        };
      }),
  );
});

const DAY_MS = 864e5;

// Customer refuses the phone at the door after the open-box check.
api.post('/orders/:id/refuse', (req, res) => {
  const o = find('orders', req.params.id);
  if (!o) return bad(res, 404, 'Order not found');
  if (o.stage !== 'shipped') return bad(res, 409, 'You can refuse only while the order is out for delivery');
  const reason = String(req.body?.reason || 'Did not match the listing').slice(0, 200);
  o.stage = 'returned';
  o.cancelReason = `Refused at doorstep: ${reason}`;
  o.events.push({ l: `Refused at doorstep • ${reason}`, a: now() });
  const l = find('listings', o.listingId);
  if (l) {
    l.stock += 1;
    if (l.status === 'soldOut') l.status = 'active';
  }
  notify(o.sellerId, `Order ${o.id} refused at doorstep`, reason, 'order');
  log(`Order ${o.id} refused at doorstep (${reason})`, 'order');
  save();
  res.json({ ok: true });
});

// 7-day returns.
api.post('/returns', (req, res) => {
  const { orderId, reason, details = '', pickupSlot } = req.body || {};
  const o = find('orders', orderId);
  if (!o) return bad(res, 404, 'Order not found');
  const at = deliveredAt(o);
  if (o.stage !== 'delivered' || !at) return bad(res, 409, 'Only delivered orders can be returned');
  const days = o.returnDays ?? 7;
  if (!days) return bad(res, 409, 'This phone was sold without returns');
  if (Date.now() - new Date(at).getTime() > days * DAY_MS) return bad(res, 409, `The ${days}-day return window has ended`);
  if (o.returnRequest && o.returnRequest.status !== 'rejected') return bad(res, 409, 'A return is already in progress');
  o.returnRequest = {
    id: uid('RT'),
    reason: String(reason || 'Other').slice(0, 80),
    details: String(details).slice(0, 500),
    pickupSlot: pickupSlot || null,
    status: 'requested',
    refund: o.price,
    at: now(),
    events: [{ l: 'Return requested', a: now() }],
  };
  notify(o.sellerId, `Return requested for ${o.id}`, `${o.item}: ${o.returnRequest.reason}`, 'order');
  log(`Return requested • ${o.id} (${o.returnRequest.reason})`, 'order');
  save();
  res.json(o.returnRequest);
});

// Warranty claims.
api.post('/warranty-claims', (req, res) => {
  const { orderId, issue, description = '', customerId = null } = req.body || {};
  const o = find('orders', orderId);
  if (!o) return bad(res, 404, 'Order not found');
  const at = deliveredAt(o);
  if (o.stage !== 'delivered' || !at) return bad(res, 409, 'Warranty starts after delivery');
  const months = o.warrantyMonths ?? 0;
  if (!months) return bad(res, 409, 'This phone has no seller warranty');
  const ends = new Date(at);
  ends.setMonth(ends.getMonth() + months);
  if (Date.now() > ends.getTime()) return bad(res, 409, 'The warranty has expired');
  if (db.claims.some((c) => c.orderId === o.id && ['submitted', 'approved'].includes(c.status))) {
    return bad(res, 409, 'A claim for this phone is already open');
  }
  const c = {
    id: uid('WC'),
    orderId: o.id,
    listingId: o.listingId,
    sellerId: o.sellerId,
    customerId,
    item: o.item,
    imei: o.imei,
    issue: String(issue || 'Other').slice(0, 80),
    description: String(description).slice(0, 800),
    status: 'submitted',
    note: '',
    at: now(),
    events: [{ l: 'Claim submitted', a: now() }],
  };
  db.claims.unshift(c);
  notify(o.sellerId, `Warranty claim for ${o.id}`, `${c.issue}: ${c.description.slice(0, 80)}`, 'order');
  log(`Warranty claim ${c.id} • ${o.item} (${c.issue})`, 'claim');
  save();
  res.json(c);
});

api.post('/live', (req, res) => {
  const { listingId, customer, phone, mode, language, slot, notes } = req.body || {};
  const l = find('listings', listingId);
  if (!l) return bad(res, 404, 'Listing not found');
  const c = {
    id: uid('LV'),
    sellerId: l.sellerId,
    listingId,
    customerId: customer?.id || null,
    item: titleOf(l),
    photo: l.photos[0],
    buyer: customer?.name || 'GAMEX Customer',
    phone: phone || '',
    mode: mode || 'Video Call',
    language: language || 'English',
    slot: slot || now(),
    notes: notes || '',
    stage: 'pending',
    converted: null,
    createdAt: now(),
    messages: [],
  };
  db.live.unshift(c);
  notify(l.sellerId, 'New live review request', `${c.buyer} wants to see your ${c.item} live.`, 'live');
  log(`Live review requested for ${c.item}`, 'live');
  save();
  res.json(c);
});

api.get('/live/status', (req, res) => {
  const ids = String(req.query.ids || '').split(',').filter(Boolean);
  res.json(
    db.live
      .filter((c) => ids.includes(c.id))
      .map((c) => ({ id: c.id, stage: c.stage, slot: c.slot, unread: (c.messages || []).filter((m) => m.from === 'seller' && !m.seen).length })),
  );
});

const chatView = (c) => ({
  id: c.id,
  item: c.item,
  photo: c.photo,
  stage: c.stage,
  slot: c.slot,
  mode: c.mode,
  seller: (() => {
    const s = find('sellers', c.sellerId);
    return s ? { storeName: s.storeName, city: s.city } : null;
  })(),
  messages: c.messages || [],
});

api.get('/live/:id/messages', (req, res) => {
  const c = find('live', req.params.id);
  if (!c) return bad(res, 404, 'Not found');
  let changed = false;
  for (const m of c.messages || []) {
    if (m.from === 'seller' && !m.seen) {
      m.seen = true;
      changed = true;
    }
  }
  if (changed) save();
  res.json(chatView(c));
});

api.post('/live/:id/messages', (req, res) => {
  const c = find('live', req.params.id);
  if (!c) return bad(res, 404, 'Not found');
  const text = String(req.body?.text || '').trim().slice(0, 1000);
  if (!text) return bad(res, 400, 'Empty message');
  c.messages ??= [];
  c.messages.push({ id: uid('M'), from: 'buyer', text, at: now(), seen: false });
  const lastBuyer = c.messages.filter((m) => m.from === 'buyer').slice(-2, -1)[0];
  if (!lastBuyer || Date.now() - new Date(lastBuyer.at).getTime() > 5 * 6e4) {
    notify(c.sellerId, `Message from ${c.buyer}`, `${c.item}: ${text.slice(0, 80)}`, 'live');
  }
  save();
  res.json(chatView(c));
});

// ======================================================
// Seller app
// ======================================================
const normPhone = (p) => '+91 ' + String(p || '').replace(/\D/g, '').slice(-10);

api.post('/seller/login', (req, res) => {
  const phone = normPhone(req.body?.phone);
  const s = db.sellers.find((x) => normPhone(x.phone) === phone);
  if (!s) return bad(res, 404, 'Not registered');
  res.json(s);
});

api.post('/seller/register', (req, res) => {
  const { phone, ownerName, storeName, city, gstin = '' } = req.body || {};
  if (!phone || !ownerName || !storeName || !city) return bad(res, 400, 'Missing details');
  const p = normPhone(phone);
  let s = db.sellers.find((x) => normPhone(x.phone) === p);
  if (!s) {
    s = { id: uid('S'), phone: p, ownerName, storeName, city, gstin, bank: 'Bank not linked', status: 'pending', online: true, rating: 0, createdAt: now() };
    db.sellers.push(s);
    log(`${storeName} applied to sell (KYC pending)`, 'seller');
    notify(s.id, 'Welcome to GAMEX Seller 👋', 'Your KYC is under review. You can start adding listings now — they go live once your account is approved.', 'info');
    save();
  }
  res.json(s);
});

function sellerGuard(req, res, next) {
  const s = find('sellers', req.params.sid);
  if (!s) return bad(res, 404, 'Seller not found');
  req.seller = s;
  next();
}
const seller = express.Router({ mergeParams: true });
api.use('/seller/:sid', sellerGuard, seller);

function sellerInsights(sid) {
  const mine = db.listings.filter((l) => l.sellerId === sid);
  const brands = {};
  db.orders.forEach((o) => {
    const k = o.item.split(' ').slice(0, 3).join(' ');
    brands[k] = (brands[k] || 0) + 1;
  });
  const demand = Object.entries(brands)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([name, n]) => ({ name, orders: n }));
  const avg = (filter) => {
    const xs = db.listings.filter((l) => l.status === 'active' && filter(l));
    return xs.length ? xs.reduce((s, l) => s + l.price, 0) / xs.length : 0;
  };
  const pricing = mine
    .filter((l) => l.status === 'active')
    .map((l) => {
      const market = avg((x) => x.model === l.model && x.storage === l.storage);
      return { id: l.id, title: titleOf(l), price: l.price, market: Math.round(market) };
    })
    .filter((p) => p.market && Math.abs(p.price - p.market) / p.market > 0.02);
  return { demand, pricing };
}

seller.get('/bootstrap', (req, res) => {
  const sid = req.seller.id;
  res.json({
    seller: req.seller,
    listings: db.listings.filter((l) => l.sellerId === sid),
    orders: db.orders.filter((o) => o.sellerId === sid),
    live: db.live.filter((c) => c.sellerId === sid),
    claims: db.claims.filter((c) => c.sellerId === sid),
    payouts: db.payouts.filter((p) => p.sellerId === sid),
    notifications: db.notifications.filter((n) => n.sellerId === sid || n.sellerId === null).map((n) => ({ ...n, read: n.read.includes(sid) })),
    insights: sellerInsights(sid),
    fees: { commissionRate: db.settings.commissionRate, fixedFee: db.settings.fixedFee },
  });
});

seller.put('/', (req, res) => {
  const { storeName, ownerName, gstin, online, city } = req.body || {};
  Object.assign(req.seller, Object.fromEntries(Object.entries({ storeName, ownerName, gstin, online, city }).filter(([, v]) => v !== undefined)));
  save();
  res.json(req.seller);
});

seller.post('/listings', (req, res) => {
  const body = req.body || {};
  const submit = !!body.submit;
  const existing = body.id ? find('listings', body.id) : null;
  if (existing && existing.sellerId !== req.seller.id) return bad(res, 403, 'Not your listing');
  if (submit && body.imei && blacklisted(body.imei)) {
    return bad(res, 409, `This IMEI is on the blacklist (${blacklisted(body.imei).reason}). It cannot be sold on GAMEX.`);
  }
  if (submit && body.imei) {
    const dup = db.listings.find((l) => l.imei === body.imei && l.id !== body.id && !['soldOut'].includes(l.status));
    if (dup) return bad(res, 409, `This IMEI is already listed (${dup.id})`);
  }
  const fields = ['brand', 'model', 'ram', 'storage', 'color', 'grade', 'battery', 'imei', 'price', 'mrp', 'stock', 'warranty', 'photos', 'checks', 'accessories', 'notes', 'deviceType', 'network', 'sim', 'returnDays', 'offerPercent'];
  const l = existing || { id: body.id || uid('GXL'), sellerId: req.seller.id, createdAt: now(), views: 0, sold: 0, featured: false, qc: null };
  fields.forEach((f) => body[f] !== undefined && (l[f] = body[f]));
  l.status = submit ? 'inReview' : existing && !submit ? existing.status : 'draft';
  if (submit) {
    l.submittedAt = now();
    l.rejectReason = null;
    log(`${req.seller.storeName} submitted ${l.brand} ${l.model} for QC`, 'qc');
  }
  if (!existing) db.listings.unshift(l);
  save();
  res.json(l);
});

seller.patch('/listings/:id', (req, res) => {
  const l = find('listings', req.params.id);
  if (!l || l.sellerId !== req.seller.id) return bad(res, 404, 'Not found');
  const { stock, price, status } = req.body || {};
  if (typeof price === 'number' && price > 0) l.price = Math.round(price);
  if (typeof stock === 'number' && stock >= 0) {
    l.stock = Math.round(stock);
    if (l.stock === 0 && l.status === 'active') l.status = 'soldOut';
    if (l.stock > 0 && l.status === 'soldOut') l.status = 'active';
  }
  if (status === 'paused' && l.status === 'active') l.status = 'paused';
  if (status === 'active' && l.status === 'paused') l.status = 'active';
  save();
  res.json(l);
});

seller.delete('/listings/:id', (req, res) => {
  const l = find('listings', req.params.id);
  if (!l || l.sellerId !== req.seller.id) return bad(res, 404, 'Not found');
  db.listings = db.listings.filter((x) => x.id !== l.id);
  save();
  res.json({ ok: true });
});

function orderAction(o, action, body, who) {
  const ev = (label) => o.events.push({ l: label, a: now() });
  switch (action) {
    case 'accept':
      if (o.stage !== 'newOrder') return 'Order already handled';
      o.stage = 'accepted';
      ev(`Accepted by ${who}`);
      break;
    case 'reject':
      if (!['newOrder', 'accepted'].includes(o.stage)) return 'Too late to reject';
      o.stage = 'cancelled';
      o.cancelReason = body.reason || 'Rejected';
      ev(`Rejected by ${who} • ${o.cancelReason}`);
      {
        const l = find('listings', o.listingId);
        if (l) {
          l.stock += 1;
          if (l.status === 'soldOut') l.status = 'active';
        }
      }
      break;
    case 'pack':
      if (o.stage !== 'accepted') return 'Accept the order first';
      o.stage = 'packed';
      o.imeiVerified = true;
      ev('Packed • IMEI verified');
      break;
    case 'ship': {
      if (o.stage !== 'packed') return 'Pack the order first';
      const courier = body.courier || 'Delhivery';
      o.stage = 'shipped';
      o.courier = courier;
      o.awb = `${courier.slice(0, 2).toUpperCase()}${9100000000 + crypto.randomInt(99999999)}`;
      o.pickupAt = body.pickupAt || now();
      ev(`Handed to ${courier} • AWB ${o.awb}`);
      break;
    }
    case 'deliver':
      if (o.stage !== 'shipped') return 'Order is not shipped';
      // Open-box delivery: the buyer shares the OTP only after checking the phone.
      if (who === 'seller' && String(body.otp || '') !== String(o.otp)) return 'Wrong delivery OTP. Ask the buyer for the 4-digit OTP in their GAMEX app.';
      o.stage = 'delivered';
      o.deliveredAt = now();
      ev(who === 'seller' ? 'Delivered • open-box check done, OTP verified' : 'Delivered');
      break;
    case 'return':
      if (o.stage !== 'delivered') return 'Only delivered orders can be returned';
      o.stage = 'returned';
      ev('Return received');
      break;
    case 'cancel':
      if (!['newOrder', 'accepted', 'packed'].includes(o.stage)) return 'Cannot cancel now';
      o.stage = 'cancelled';
      o.cancelReason = body.reason || 'Cancelled by GAMEX';
      ev(`Cancelled by ${who} • ${o.cancelReason}`);
      break;
    default:
      return 'Unknown action';
  }
  return null;
}

seller.post('/orders/:id/:action', (req, res) => {
  const o = find('orders', req.params.id);
  if (!o || o.sellerId !== req.seller.id) return bad(res, 404, 'Order not found');
  const err = orderAction(o, req.params.action, req.body || {}, 'seller');
  if (err) return bad(res, 409, err);
  save();
  res.json(o);
});

seller.patch('/live/:id', (req, res) => {
  const c = find('live', req.params.id);
  if (!c || c.sellerId !== req.seller.id) return bad(res, 404, 'Not found');
  const { stage, converted, slot } = req.body || {};
  if (stage) c.stage = stage;
  if (converted !== undefined) c.converted = converted;
  if (slot) c.slot = slot;
  save();
  res.json(c);
});

seller.post('/live/:id/messages', (req, res) => {
  const c = find('live', req.params.id);
  if (!c || c.sellerId !== req.seller.id) return bad(res, 404, 'Not found');
  const text = String(req.body?.text || '').trim().slice(0, 1000);
  if (!text) return bad(res, 400, 'Empty message');
  c.messages ??= [];
  c.messages.push({ id: uid('M'), from: 'seller', text, at: now(), seen: false });
  save();
  res.json(c);
});

function available(sid) {
  const last = db.payouts.filter((p) => p.sellerId === sid).reduce((m, p) => (p.at > m ? p.at : m), '');
  let amount = 0;
  let count = 0;
  db.orders
    .filter((o) => o.sellerId === sid && o.stage === 'delivered')
    .forEach((o) => {
      const at = o.events[o.events.length - 1].a;
      if (Date.now() - new Date(at).getTime() >= 7 * 864e5 && at > last) {
        amount += payout(o.price);
        count++;
      }
    });
  return { amount, count };
}

seller.post('/withdraw', (req, res) => {
  const { amount, count } = available(req.seller.id);
  if (amount < 1) return bad(res, 409, 'Nothing to withdraw yet');
  const p = { id: uid('PO'), sellerId: req.seller.id, amount: Math.round(amount * 100) / 100, orders: count, at: now(), utr: `HDFCN${crypto.randomInt(1e7, 9e7)}` };
  db.payouts.unshift(p);
  log(`Payout ₹${Math.round(amount).toLocaleString('en-IN')} to ${req.seller.storeName}`, 'payout');
  save();
  res.json(p);
});

seller.post('/notifications/read', (req, res) => {
  db.notifications.forEach((n) => {
    if ((n.sellerId === req.seller.id || n.sellerId === null) && !n.read.includes(req.seller.id)) n.read.push(req.seller.id);
  });
  save();
  res.json({ ok: true });
});

// ======================================================
// Super admin
// ======================================================
const tokens = new Set();
const failed = new Map(); // ip -> { n, first, until }
const WINDOW = 15 * 6e4;
const safeEqual = (a, b) => {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};
api.post('/admin/login', (req, res) => {
  const ip = req.ip;
  const now = Date.now();
  let rec = failed.get(ip);
  if (!rec || (now - rec.first > WINDOW && rec.until < now)) rec = { n: 0, first: now, until: 0 };
  if (rec.until > now) return bad(res, 429, 'Too many attempts. Try again in 15 minutes.');
  const { email, password } = req.body || {};
  if (String(email).toLowerCase() !== ADMIN_EMAIL.toLowerCase() || !safeEqual(password, ADMIN_PASSWORD)) {
    rec.n += 1;
    if (rec.n >= 8) rec.until = now + WINDOW;
    failed.set(ip, rec);
    return bad(res, 401, 'Wrong email or password');
  }
  failed.delete(ip);
  const t = crypto.randomBytes(24).toString('hex');
  tokens.add(t);
  res.json({ token: t });
});
const admin = express.Router();
api.use(
  '/admin',
  (req, res, next) => (tokens.has(String(req.headers.authorization || '').replace('Bearer ', '')) ? next() : bad(res, 401, 'Please sign in again')),
  admin,
);

admin.get('/db', (_, res) => res.json({ ...db, checklist: CHECKLIST }));

admin.post('/listings/:id/qc', (req, res) => {
  const l = find('listings', req.params.id);
  if (!l) return bad(res, 404, 'Not found');
  const { decision, reason = '', inspector = 'Super Admin', checks = {}, defects } = req.body || {};
  const title = titleOf(l);
  if (Array.isArray(defects)) l.defects = defects.slice(0, 20);
  if (decision === 'approve' && blacklisted(l.imei)) return bad(res, 409, 'This IMEI is blacklisted - reject the listing instead.');
  if (decision === 'approve') {
    l.status = l.stock > 0 ? 'active' : 'soldOut';
    l.approvedAt = now();
    l.rejectReason = null;
    l.certificate = l.certificate || `GXC-${l.id.replace('GXL', '')}-${crypto.randomInt(1000, 9999)}`;
    notify(l.sellerId, 'Listing approved ✅', `${title} passed QC and is now live on GAMEX.`, 'qc');
  } else if (decision === 'reject' || decision === 'changes') {
    l.status = 'rejected';
    l.rejectReason = reason || 'Did not pass quality check';
    notify(l.sellerId, decision === 'changes' ? 'Changes requested ✏️' : 'Listing rejected', `${title}: ${l.rejectReason}`, 'qc');
  } else return bad(res, 400, 'Unknown decision');
  l.qc = { by: inspector, at: now(), decision: decision === 'approve' ? 'approved' : decision === 'changes' ? 'changes' : 'rejected', notes: reason, checks };
  log(`QC ${l.qc.decision}: ${title} (${sellerOf(l)?.storeName})`, 'qc');
  save();
  res.json(l);
});

admin.patch('/listings/:id', (req, res) => {
  const l = find('listings', req.params.id);
  if (!l) return bad(res, 404, 'Not found');
  const { featured, status, price, defects } = req.body || {};
  if (Array.isArray(defects)) l.defects = defects.slice(0, 20);
  if (featured !== undefined) l.featured = !!featured;
  if (status) {
    l.status = status;
    if (status === 'paused') notify(l.sellerId, 'Listing delisted by GAMEX', `${l.brand} ${l.model} was taken down. Contact seller support.`, 'qc');
  }
  if (typeof price === 'number') l.price = price;
  save();
  res.json(l);
});

admin.post('/orders/:id/:action', (req, res) => {
  const o = find('orders', req.params.id);
  if (!o) return bad(res, 404, 'Order not found');
  const err = orderAction(o, req.params.action, req.body || {}, 'GAMEX');
  if (err) return bad(res, 409, err);
  notify(o.sellerId, `Order ${o.id} updated by GAMEX`, `Status: ${o.stage}`, 'order');
  log(`Admin: order ${o.id} → ${o.stage}`, 'order');
  save();
  res.json(o);
});

admin.patch('/sellers/:id', (req, res) => {
  const s = find('sellers', req.params.id);
  if (!s) return bad(res, 404, 'Not found');
  const { status, reason } = req.body || {};
  if (status) {
    s.status = status;
    s.suspendReason = status === 'suspended' ? reason || 'Policy violation' : undefined;
    notify(
      s.id,
      status === 'approved' ? 'Your seller account is approved 🎉' : status === 'suspended' ? 'Account suspended' : 'Account under review',
      status === 'approved' ? 'Your listings can now go live after QC.' : status === 'suspended' ? s.suspendReason : 'We are reviewing your documents.',
      'account',
    );
    log(`Seller ${s.storeName} → ${status}`, 'seller');
  }
  save();
  res.json(s);
});

admin.post('/sellers/:id/payout', (req, res) => {
  const s = find('sellers', req.params.id);
  if (!s) return bad(res, 404, 'Not found');
  const { amount, count } = available(s.id);
  if (amount < 1) return bad(res, 409, 'No settled balance');
  const p = { id: uid('PO'), sellerId: s.id, amount: Math.round(amount * 100) / 100, orders: count, at: now(), utr: `HDFCN${crypto.randomInt(1e7, 9e7)}` };
  db.payouts.unshift(p);
  notify(s.id, 'Payout sent 💸', `₹${Math.round(amount).toLocaleString('en-IN')} sent to ${s.bank}. UTR ${p.utr}`, 'payout');
  save();
  res.json(p);
});

admin.get('/sellers/:id/balance', (req, res) => res.json(available(req.params.id)));

admin.post('/notify', (req, res) => {
  const { sellerId = null, title, body } = req.body || {};
  if (!title) return bad(res, 400, 'Title required');
  notify(sellerId, title, body || '', 'announcement');
  log(`Announcement sent: ${title}`, 'system');
  save();
  res.json({ ok: true });
});

admin.patch('/customers/:id', (req, res) => {
  const c = find('customers', req.params.id);
  if (!c) return bad(res, 404, 'Not found');
  if (req.body?.status) c.status = req.body.status;
  log(`Customer ${c.name} → ${c.status}`, 'customer');
  save();
  res.json(c);
});

admin.patch('/live/:id', (req, res) => {
  const c = find('live', req.params.id);
  if (!c) return bad(res, 404, 'Not found');
  Object.assign(c, req.body || {});
  save();
  res.json(c);
});

for (const col of ['banners', 'coupons']) {
  admin.put(`/${col}`, (req, res) => {
    if (!Array.isArray(req.body)) return bad(res, 400, 'Array expected');
    db[col] = req.body;
    save();
    res.json(db[col]);
  });
}
admin.put('/settings', (req, res) => {
  db.settings = { ...db.settings, ...(req.body || {}) };
  save();
  res.json(db.settings);
});
admin.post('/blacklist', (req, res) => {
  const imei = String(req.body?.imei || '').replace(/\D/g, '');
  if (imei.length !== 15) return bad(res, 400, 'IMEI must be 15 digits');
  if (blacklisted(imei)) return bad(res, 409, 'Already on the blacklist');
  db.blacklist.unshift({ imei, reason: String(req.body?.reason || 'Reported lost/stolen').slice(0, 120), at: now() });
  const hit = db.listings.filter((l) => l.imei === imei && ['active', 'inReview', 'paused'].includes(l.status));
  for (const l of hit) {
    l.status = 'rejected';
    l.rejectReason = 'IMEI reported lost/stolen. Contact GAMEX seller support.';
    notify(l.sellerId, 'Listing removed', `${l.brand} ${l.model}: IMEI is on the blacklist.`, 'qc');
  }
  log(`IMEI ${imei} blacklisted${hit.length ? ` (${hit.length} listing removed)` : ''}`, 'qc');
  save();
  res.json({ ok: true, removedListings: hit.length });
});

admin.delete('/blacklist/:imei', (req, res) => {
  db.blacklist = db.blacklist.filter((b) => b.imei !== req.params.imei);
  save();
  res.json({ ok: true });
});

const RETURN_FLOW = {
  approve: ['requested', 'pickup_scheduled', 'Return approved • pickup scheduled'],
  pickup: ['pickup_scheduled', 'picked_up', 'Phone picked up • on the way to QC'],
  refund: ['picked_up', 'refunded', 'Refund issued'],
};
admin.post('/returns/:orderId/:action', (req, res) => {
  const o = find('orders', req.params.orderId);
  if (!o?.returnRequest) return bad(res, 404, 'Return not found');
  const r = o.returnRequest;
  const a = req.params.action;
  if (a === 'reject') {
    if (!['requested', 'pickup_scheduled'].includes(r.status)) return bad(res, 409, 'Cannot reject now');
    r.status = 'rejected';
    r.note = String(req.body?.note || 'Return not eligible').slice(0, 200);
    r.events.push({ l: `Return rejected • ${r.note}`, a: now() });
  } else {
    const step = RETURN_FLOW[a];
    if (!step || r.status !== step[0]) return bad(res, 409, 'Wrong step');
    r.status = step[1];
    r.events.push({ l: step[2], a: now() });
    if (a === 'refund') {
      o.stage = 'returned';
      o.events.push({ l: `Return completed • refund ₹${o.price.toLocaleString('en-IN')}`, a: now() });
    }
  }
  notify(o.sellerId, `Return ${r.status.replace('_', ' ')} • ${o.id}`, o.item, 'order');
  log(`Return ${o.id} → ${r.status}`, 'order');
  save();
  res.json(r);
});

const CLAIM_FLOW = {
  approve: ['submitted', 'approved', 'Claim approved • repair pickup arranged'],
  resolve: ['approved', 'resolved', 'Repaired / replaced • claim closed'],
};
admin.post('/claims/:id/:action', (req, res) => {
  const c = find('claims', req.params.id);
  if (!c) return bad(res, 404, 'Claim not found');
  const a = req.params.action;
  if (a === 'reject') {
    if (!['submitted', 'approved'].includes(c.status)) return bad(res, 409, 'Cannot reject now');
    c.status = 'rejected';
    c.note = String(req.body?.note || 'Not covered by warranty').slice(0, 200);
    c.events.push({ l: `Claim rejected • ${c.note}`, a: now() });
  } else {
    const step = CLAIM_FLOW[a];
    if (!step || c.status !== step[0]) return bad(res, 409, 'Wrong step');
    c.status = step[1];
    if (req.body?.note) c.note = String(req.body.note).slice(0, 200);
    c.events.push({ l: step[2], a: now() });
  }
  notify(c.sellerId, `Warranty claim ${c.status} • ${c.item}`, c.issue, 'order');
  log(`Claim ${c.id} → ${c.status}`, 'claim');
  save();
  res.json(c);
});

admin.post('/reset', (_, res) => {
  db = buildSeed();
  migrate();
  save();
  res.json({ ok: true });
});

api.use((_, res) => bad(res, 404, 'Unknown endpoint'));

// ---------------- Admin panel (built) ----------------
// Built with base ADMIN_BASE (default /gamex) -> https://<domain>/gamex/dashboard
if (fs.existsSync(ADMIN_DIST)) {
  app.use(ADMIN_BASE, express.static(ADMIN_DIST, { index: false, maxAge: '1h' }));
  app.get([ADMIN_BASE, `${ADMIN_BASE}/*`], (_, res) => {
    res.setHeader('Cache-Control', 'no-cache');
    res.sendFile(path.join(ADMIN_DIST, 'index.html'));
  });
  app.get('/', (_, res) => res.redirect(`${ADMIN_BASE}/dashboard`));
} else {
  app.get('/', (_, res) => res.send('GAMEX API is running. Build the admin panel (cd admin && npm run build) to serve it here.'));
}

app.listen(PORT, HOST, () => {
  const ips = Object.values(os.networkInterfaces())
    .flat()
    .filter((i) => i && i.family === 'IPv4' && !i.internal)
    .map((i) => i.address);
  console.log(`\n  GAMEX server running on port ${PORT}`);
  console.log(`  Admin panel:   http://localhost:${PORT}${ADMIN_BASE}/dashboard`);
  ips.forEach((ip) => console.log(`  Phones (Wi-Fi): http://${ip}:${PORT}`));
  console.log(`  Admin login:   ${ADMIN_EMAIL}${process.env.ADMIN_PASSWORD ? " (password from env)" : " / " + ADMIN_PASSWORD}\n`);
});
