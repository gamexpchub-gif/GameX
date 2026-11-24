// After-sales & service features: live order tracking (with an optional
// Shiprocket integration), repair booking, Sell to GAMEX, and shared
// reviews / Q&A with "Verified Buyer". Mounted by index.js.
import crypto from 'node:crypto';
import { TRADE_IN_MODELS, quoteTradeIn } from './growth.js';

const HOUR = 36e5;
const DAY = 864e5;

/** Rough map position of Indian cities (0..1 inside the app's map box). */
export const CITY_XY = {
  Delhi: [0.36, 0.25], 'New Delhi': [0.36, 0.25], Gurugram: [0.35, 0.26], Noida: [0.37, 0.25],
  Jaipur: [0.3, 0.32], Lucknow: [0.47, 0.3], Chandigarh: [0.35, 0.18], Ahmedabad: [0.2, 0.44],
  Surat: [0.21, 0.5], Mumbai: [0.22, 0.56], Thane: [0.23, 0.55], Pune: [0.26, 0.59], Nagpur: [0.4, 0.5],
  Indore: [0.31, 0.45], Hyderabad: [0.39, 0.62], Bengaluru: [0.36, 0.78], Chennai: [0.45, 0.77],
  Kochi: [0.31, 0.88], Coimbatore: [0.34, 0.85], Kolkata: [0.7, 0.44], Patna: [0.6, 0.34],
  Bhubaneswar: [0.6, 0.5], Guwahati: [0.84, 0.31], Goa: [0.24, 0.67],
};
const xy = (c) => CITY_XY[c] || CITY_XY[(c || '').split(/[ ,/]/)[0]] || [0.4, 0.5];
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

/** States for GST (intra-state → CGST+SGST, inter-state → IGST). */
const CITY_STATE = {
  Mumbai: 'Maharashtra', Thane: 'Maharashtra', Pune: 'Maharashtra', Nagpur: 'Maharashtra',
  Delhi: 'Delhi', 'New Delhi': 'Delhi', Bengaluru: 'Karnataka', Hyderabad: 'Telangana', Chennai: 'Tamil Nadu',
  Kolkata: 'West Bengal', Ahmedabad: 'Gujarat', Surat: 'Gujarat', Jaipur: 'Rajasthan', Lucknow: 'Uttar Pradesh',
  Noida: 'Uttar Pradesh', Gurugram: 'Haryana', Chandigarh: 'Chandigarh', Kochi: 'Kerala', Goa: 'Goa',
};
export const stateOf = (city) => CITY_STATE[city] || CITY_STATE[(city || '').split(/[ ,/]/)[0]] || null;

// ------------------------------------------------------------ Shiprocket --
let sr = null; // { token, exp }
async function shiprocketToken() {
  const email = process.env.SHIPROCKET_EMAIL;
  const password = process.env.SHIPROCKET_PASSWORD;
  if (!email || !password) return null;
  if (sr && sr.exp > Date.now()) return sr.token;
  const r = await fetch('https://apiv2.shiprocket.in/v1/external/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const j = await r.json();
  if (!j.token) throw new Error('Shiprocket login failed');
  sr = { token: j.token, exp: Date.now() + 9 * DAY };
  return sr.token;
}

/** Live courier scans from Shiprocket for a real AWB, or null. */
async function shiprocketScans(awb) {
  try {
    const token = await shiprocketToken();
    if (!token || !awb) return null;
    const r = await fetch(`https://apiv2.shiprocket.in/v1/external/courier/track/awb/${encodeURIComponent(awb)}`, {
      headers: { authorization: `Bearer ${token}` },
    });
    const j = await r.json();
    const acts = j?.tracking_data?.shipment_track_activities;
    if (!Array.isArray(acts) || !acts.length) return null;
    return {
      scans: acts.map((a) => ({ l: a.activity || a['sr-status-label'] || 'Update', place: a.location || '', at: new Date(a.date).toISOString() })).reverse(),
      eta: j.tracking_data.etd ? new Date(j.tracking_data.etd).toISOString() : null,
      live: true,
    };
  } catch (e) {
    console.warn('[shiprocket]', e.message);
    return null;
  }
}

/** Books a real Shiprocket shipment for an order. Returns { awb, courier } or null. */
export async function createShiprocketShipment(o, seller) {
  try {
    const token = await shiprocketToken();
    if (!token) return null;
    if (!/^\d{6}$/.test(String(o.pincode || ''))) {
      console.warn('[shiprocket] order', o.id, 'has no PIN code - book manually');
      return null;
    }
    const h = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };
    const [first, ...rest] = String(o.buyer || 'Customer').split(' ');
    const created = await (
      await fetch('https://apiv2.shiprocket.in/v1/external/orders/create/adhoc', {
        method: 'POST',
        headers: h,
        body: JSON.stringify({
          order_id: o.id,
          order_date: o.placedAt.slice(0, 16).replace('T', ' '),
          pickup_location: process.env.SHIPROCKET_PICKUP || 'Primary',
          billing_customer_name: first,
          billing_last_name: rest.join(' ') || '.',
          billing_address: o.address || o.city,
          billing_city: o.city,
          billing_pincode: o.pincode,
          billing_state: o.state || stateOf(o.city) || o.city,
          billing_country: 'India',
          billing_email: 'orders@gamex.in',
          billing_phone: String(o.phone || '').replace(/\D/g, '').slice(-10),
          shipping_is_billing: true,
          order_items: [{ name: o.item, sku: o.listingId, units: 1, selling_price: o.price, hsn: 8517 }],
          payment_method: o.payment === 'COD' ? 'COD' : 'Prepaid',
          sub_total: o.payable ?? o.price,
          length: 18, breadth: 12, height: 6, weight: 0.5,
        }),
      })
    ).json();
    if (!created.shipment_id) throw new Error(created.message || 'order not created');
    const awb = await (
      await fetch('https://apiv2.shiprocket.in/v1/external/courier/assign/awb', { method: 'POST', headers: h, body: JSON.stringify({ shipment_id: created.shipment_id }) })
    ).json();
    const data = awb?.response?.data;
    if (!data?.awb_code) throw new Error(awb.message || 'AWB not assigned');
    await fetch('https://apiv2.shiprocket.in/v1/external/courier/generate/pickup', { method: 'POST', headers: h, body: JSON.stringify({ shipment_id: [created.shipment_id] }) });
    return { awb: data.awb_code, courier: data.courier_name || 'Shiprocket', shipmentId: created.shipment_id, seller: seller?.id };
  } catch (e) {
    console.warn('[shiprocket] create failed:', e.message);
    return null;
  }
}

export const courierLive = () => !!(process.env.SHIPROCKET_EMAIL && process.env.SHIPROCKET_PASSWORD);

/** Simulated courier scans for demo AWBs (no courier account connected). */
function simulatedScans(o, from, to) {
  const pick = Date.parse(o.pickupAt || o.events.find((e) => /^(Handed|Picked up)/.test(e.l))?.a || o.placedAt);
  const same = from === to;
  const total = same ? 20 * HOUR : (dist(xy(from), xy(to)) > 0.25 ? 60 : 40) * HOUR;
  const plan = same
    ? [
        [0, `Picked up from seller`, from],
        [3, `Reached ${from} hub`, from],
        [12, 'Out for delivery', to],
      ]
    : [
        [0, 'Picked up from seller', from],
        [4, `Reached ${from} hub`, from],
        [8, `Departed ${from} hub`, from],
        [total / HOUR - 16, `Arrived at ${to} hub`, to],
        [total / HOUR - 5, 'Out for delivery', to],
      ];
  const t = Date.now();
  const delivered = o.stage === 'delivered';
  const scans = plan
    .map(([h, l, place]) => ({ l, place, at: new Date(pick + h * HOUR).toISOString() }))
    .filter((s) => delivered || Date.parse(s.at) <= t);
  if (delivered) scans.push({ l: 'Delivered • OTP verified', place: to, at: o.deliveredAt || new Date(pick + total).toISOString() });
  return { scans, eta: new Date(pick + total).toISOString(), live: false };
}

// --------------------------------------------------------------- repairs --
/** Repair services: price = share of the model's value, within limits. */
export const REPAIRS = {
  screen: { label: 'Screen replacement', rate: 0.32, min: 1999, max: 24999, hours: 3 },
  battery: { label: 'Battery replacement', rate: 0.08, min: 1299, max: 6999, hours: 1 },
  backGlass: { label: 'Back glass', rate: 0.14, min: 1499, max: 12999, hours: 3 },
  charging: { label: 'Charging port', rate: 0.05, min: 999, max: 3499, hours: 2 },
  camera: { label: 'Camera', rate: 0.16, min: 1499, max: 14999, hours: 2 },
  speaker: { label: 'Speaker / mic', rate: 0.05, min: 899, max: 2999, hours: 1 },
  water: { label: 'Water damage check', rate: 0, min: 499, max: 499, hours: 24 },
  other: { label: 'Diagnosis (other issue)', rate: 0, min: 299, max: 299, hours: 24 },
};
const round99 = (v) => Math.ceil(v / 100) * 100 - 1;

export function repairQuote({ brand, model, issue, quality = 'original' }) {
  const r = REPAIRS[issue];
  if (!r) return null;
  const base = TRADE_IN_MODELS[brand]?.[model] ?? 15000;
  // Repairs track the new-phone cost (~2.4× the trade-in value).
  let price = Math.min(r.max, Math.max(r.min, base * 2.4 * r.rate));
  if (quality === 'compatible' && r.rate > 0) price = Math.max(r.min * 0.7, price * 0.65);
  return { issue, label: r.label, quality, price: round99(price), hours: r.hours, warrantyMonths: quality === 'original' ? 6 : 3 };
}

export function mountService(ctx) {
  const { api, seller, admin, D, save, now, uid, find, notify, log, bad, titleOf, notifyCustomer } = ctx;
  const money = (n) => `₹${Math.round(n).toLocaleString('en-IN')}`;

  function migrate() {
    const db = D();
    db.repairs ??= [];
    db.sellRequests ??= [];
    db.reviews ??= [];
    db.questions ??= [];
    db.purchases ??= [];
  }
  migrate();

  // ------------------------------------------------------------- tracking --
  const PROGRESS = { newOrder: 0.04, accepted: 0.12, packed: 0.2, cancelled: 0, returned: 1 };

  async function trackOne(o) {
    const s = find('sellers', o.sellerId);
    const from = s?.city || 'Mumbai';
    const to = o.city || 'Mumbai';
    let route = null;
    if (['shipped', 'delivered'].includes(o.stage)) {
      route = (courierLive() && (await shiprocketScans(o.awb))) || simulatedScans(o, from, to);
    }
    const scans = route?.scans || [];
    let progress = PROGRESS[o.stage] ?? 0;
    if (o.stage === 'delivered') progress = 1;
    else if (o.stage === 'shipped' && route) {
      const start = Date.parse(scans[0]?.at || o.pickupAt || o.placedAt);
      const end = Date.parse(route.eta);
      progress = Math.min(0.95, Math.max(0.25, 0.25 + ((Date.now() - start) / Math.max(1, end - start)) * 0.7));
    }
    const sellerState = stateOf(from);
    const buyerState = stateOf(to);
    return {
      id: o.id,
      orderId: o.orderId,
      item: o.item,
      variant: o.variant,
      photo: o.photo,
      price: o.price,
      stage: o.stage,
      courier: o.courier,
      awb: o.awb,
      otp: o.stage === 'shipped' ? o.otp : null,
      from: { city: from, xy: xy(from) },
      to: { city: to, xy: xy(to) },
      eta: route?.eta || null,
      live: route?.live || false,
      progress,
      events: o.events,
      scans,
      invoice: {
        number: `GMX/${new Date(o.placedAt).getFullYear()}/${o.id.replace(/\D/g, '').slice(-8)}`,
        date: o.placedAt,
        seller: { name: s?.storeName || 'GAMEX Official', gstin: s?.gstin || '', city: from, state: sellerState },
        buyer: { name: o.buyer, phone: o.phone, address: o.address, city: to, state: buyerState },
        hsn: '8517',
        interState: !!(sellerState && buyerState && sellerState !== buyerState),
        imei: o.imei || null,
        tradeIn: o.tradeIn ? { model: o.tradeIn.model, amount: o.tradeIn.amount } : null,
      },
    };
  }

  api.get('/orders/:orderId/tracking', async (req, res) => {
    const list = D().orders.filter((o) => o.orderId === req.params.orderId && o.customerId === req.customer?.id);
    if (!list.length) return bad(res, 404, 'Order not found');
    res.json(await Promise.all(list.map(trackOne)));
  });

  const ev = (x, l) => x.events.push({ l, a: now() });
  const mine = (col, req) => D()[col].filter((x) => x.customerId === req.query.customerId);

  // -------------------------------------------------------------- repairs --
  api.post('/repairs/quote', (req, res) => {
    const q = repairQuote(req.body || {});
    if (!q) return bad(res, 400, 'Unknown repair');
    res.json(q);
  });

  api.post('/repairs', (req, res) => {
    const b = req.body || {};
    if (!b.customerId || !b.phone || !b.model || !b.slot) return bad(res, 400, 'Phone, model and time slot are required');
    const q = repairQuote(b);
    if (!q) return bad(res, 400, 'Unknown repair');
    const r = {
      id: uid('RP'),
      customerId: b.customerId,
      name: b.name || 'Customer',
      phone: b.phone,
      brand: b.brand,
      model: b.model,
      issue: q.issue,
      label: q.label,
      quality: q.quality,
      price: q.price,
      warrantyMonths: q.warrantyMonths,
      mode: ['doorstep', 'pickup', 'store'].includes(b.mode) ? b.mode : 'pickup',
      slot: b.slot,
      address: b.address || '',
      city: b.city || '',
      notes: String(b.notes || '').slice(0, 300),
      technician: null,
      status: 'booked',
      createdAt: now(),
      events: [{ l: `Booked • ${q.label} • ₹${q.price.toLocaleString('en-IN')}`, a: now() }],
    };
    D().repairs.unshift(r);
    log(`Repair booked: ${r.model} • ${r.label}`, 'repair');
    save();
    res.json(r);
  });

  api.get('/repairs', (req, res) => res.json(mine('repairs', req)));

  api.post('/repairs/:id/cancel', (req, res) => {
    const r = find('repairs', req.params.id);
    if (!r || r.customerId !== req.body?.customerId) return bad(res, 404, 'Not found');
    if (!['booked', 'assigned'].includes(r.status)) return bad(res, 409, 'This repair can no longer be cancelled');
    r.status = 'cancelled';
    ev(r, 'Cancelled by customer');
    save();
    res.json(r);
  });

  const REPAIR_FLOW = {
    assign: [['booked'], 'assigned', (r, b) => `Technician ${b.technician || 'assigned'} will reach you in your slot`],
    start: [['assigned'], 'inRepair', () => 'Repair in progress'],
    complete: [['inRepair'], 'completed', (r) => `Repaired • ${r.warrantyMonths}-month repair warranty`],
    cancel: [['booked', 'assigned', 'inRepair'], 'cancelled', (r, b) => `Cancelled by GAMEX${b.note ? ` • ${b.note}` : ''}`],
  };
  admin.post('/repairs/:id/:action', (req, res) => {
    const r = find('repairs', req.params.id);
    const f = REPAIR_FLOW[req.params.action];
    if (!r || !f) return bad(res, 404, 'Not found');
    if (!f[0].includes(r.status)) return bad(res, 409, `Repair is ${r.status}`);
    const b = req.body || {};
    if (b.technician) r.technician = b.technician;
    r.status = f[1];
    const text = f[2](r, b);
    ev(r, text);
    notifyCustomer(r.customerId, `Repair ${r.status === 'completed' ? 'done ✅' : 'update'}: ${r.model}`, text, 'repair', '/repairs');
    save();
    res.json(r);
  });

  // ---------------------------------------------------------- sell phone --
  api.post('/sell-requests', (req, res) => {
    const b = req.body || {};
    const d = b.device || {};
    if (!b.customerId || !b.phone || !b.slot) return bad(res, 400, 'Phone number and pickup slot are required');
    const payout = b.payout || {};
    if (payout.method === 'upi' && !/^[\w.-]{2,}@[a-zA-Z]{2,}$/.test(payout.upi || '')) return bad(res, 400, 'Enter a valid UPI ID');
    if (payout.method === 'bank' && !(payout.account && payout.ifsc)) return bad(res, 400, 'Bank account and IFSC are required');
    const q = quoteTradeIn(d, 0, 0);
    if (!q) return bad(res, 400, 'We do not buy this model yet');
    const s = {
      id: uid('SL'),
      customerId: b.customerId,
      name: b.name || 'Customer',
      phone: b.phone,
      device: { brand: d.brand, model: d.model, storage: d.storage || '128GB', answers: d.answers || {}, faults: d.faults || [], extras: d.extras || [] },
      quote: q.amount,
      lines: q.lines,
      finalAmount: null,
      address: b.address || '',
      city: b.city || '',
      slot: b.slot,
      payout: { method: payout.method === 'bank' ? 'bank' : 'upi', upi: payout.upi || '', account: payout.account ? `•••• ${String(payout.account).slice(-4)}` : '', ifsc: payout.ifsc || '' },
      status: 'requested',
      createdAt: now(),
      events: [{ l: `Pickup requested • quote ₹${q.amount.toLocaleString('en-IN')}`, a: now() }],
    };
    D().sellRequests.unshift(s);
    log(`Sell request: ${d.model} for ₹${q.amount}`, 'sell');
    save();
    res.json(s);
  });

  api.get('/sell-requests', (req, res) => res.json(mine('sellRequests', req)));

  api.post('/sell-requests/:id/cancel', (req, res) => {
    const s = find('sellRequests', req.params.id);
    if (!s || s.customerId !== req.body?.customerId) return bad(res, 404, 'Not found');
    if (!['requested', 'scheduled'].includes(s.status)) return bad(res, 409, 'The phone has already been picked up');
    s.status = 'cancelled';
    ev(s, 'Cancelled by customer');
    save();
    res.json(s);
  });

  const SELL_FLOW = {
    schedule: [['requested'], 'scheduled', () => 'Pickup agent assigned'],
    pickup: [['scheduled'], 'pickedUp', () => 'Phone collected • inspection at GAMEX lab'],
    pay: [['pickedUp'], 'paid', (s) => `Paid ₹${(s.finalAmount ?? s.quote).toLocaleString('en-IN')} to ${s.payout.method === 'upi' ? s.payout.upi : `bank ${s.payout.account}`}`],
    reject: [['requested', 'scheduled', 'pickedUp'], 'rejected', (s, b) => `Not accepted${b.note ? ` • ${b.note}` : ''}`],
  };
  admin.post('/sell-requests/:id/:action', (req, res) => {
    const s = find('sellRequests', req.params.id);
    const f = SELL_FLOW[req.params.action];
    if (!s || !f) return bad(res, 404, 'Not found');
    if (!f[0].includes(s.status)) return bad(res, 409, `Request is ${s.status}`);
    const b = req.body || {};
    if (req.params.action === 'pay' && b.finalAmount !== undefined) {
      const v = Math.round(Number(b.finalAmount));
      if (!(v > 0) || v > s.quote) return bad(res, 400, 'Final amount must be between 1 and the quote');
      s.finalAmount = v;
    }
    s.status = f[1];
    const text = f[2](s, b);
    ev(s, text);
    notifyCustomer(s.customerId, `Sell ${s.device.model}: ${s.status === 'paid' ? 'payment sent 💸' : 'update'}`, text, 'sell', '/sell/requests');
    save();
    res.json(s);
  });

  // ------------------------------------------------ reviews & questions --
  /** Records what a customer bought (for "Verified Buyer"). */
  function recordPurchase(body) {
    const cid = body?.customer?.id;
    const keys = Array.isArray(body?.productKeys) ? body.productKeys.map(String).slice(0, 20) : [];
    if (!cid || cid === 'guest' || !keys.length) return;
    D().purchases.unshift({ customerId: cid, orderId: body.orderId, keys, at: now() });
  }
  const isBuyer = (cid, key) =>
    D().purchases.some((p) => p.customerId === cid && p.keys.includes(key)) ||
    D().orders.some((o) => o.customerId === cid && o.listingId === key && o.stage !== 'cancelled');

  const reviewView = (r) => ({ ...r, customerId: undefined });

  api.get('/reviews', (req, res) => {
    const key = String(req.query.key || '');
    const list = D().reviews.filter((r) => r.key === key && !r.hidden);
    res.json(list.map(reviewView));
  });

  api.post('/reviews', (req, res) => {
    const b = req.body || {};
    const rating = Math.round(Number(b.rating));
    if (!b.customerId || !b.key || !(rating >= 1 && rating <= 5)) return bad(res, 400, 'Rating and product are required');
    if (String(b.body || '').trim().length < 10) return bad(res, 400, 'Please write at least 10 characters');
    const db = D();
    const existing = db.reviews.find((r) => r.key === b.key && r.customerId === b.customerId);
    const r = existing || { id: uid('RV'), key: b.key, customerId: b.customerId, helpful: 0, createdAt: now() };
    Object.assign(r, {
      author: String(b.author || 'Customer').slice(0, 40),
      rating,
      title: String(b.title || '').slice(0, 80),
      body: String(b.body).slice(0, 1500),
      variant: b.variant || null,
      photos: (Array.isArray(b.photos) ? b.photos : []).filter((x) => typeof x === 'string' && x.startsWith('/uploads/')).slice(0, 6),
      verified: isBuyer(b.customerId, b.key),
      updatedAt: now(),
      hidden: false,
    });
    if (!existing) db.reviews.unshift(r);
    log(`New ${rating}★ review on ${b.key}${r.verified ? ' (verified buyer)' : ''}`, 'review');
    save();
    res.json(reviewView(r));
  });

  api.post('/reviews/:id/helpful', (req, res) => {
    const r = find('reviews', req.params.id);
    if (!r) return bad(res, 404, 'Not found');
    r.helpful = Math.max(0, (r.helpful || 0) + (req.body?.undo ? -1 : 1));
    save();
    res.json({ helpful: r.helpful });
  });

  const qView = (q) => ({ ...q, customerId: undefined });
  api.get('/questions', (req, res) => {
    const key = String(req.query.key || '');
    res.json(D().questions.filter((q) => q.key === key && !q.hidden).map(qView));
  });

  api.post('/questions', (req, res) => {
    const b = req.body || {};
    const text = String(b.text || '').trim();
    if (!b.key || text.length < 5) return bad(res, 400, 'Please type your question');
    const l = find('listings', b.key);
    const q = {
      id: uid('QN'),
      key: b.key,
      sellerId: l?.sellerId || null,
      customerId: b.customerId || null,
      author: String(b.author || 'Customer').slice(0, 40),
      text: text.slice(0, 300),
      answer: null,
      answeredBy: null,
      createdAt: now(),
      answeredAt: null,
    };
    D().questions.unshift(q);
    if (l) notify(l.sellerId, 'New question from a buyer ❓', `${titleOf(l)}: "${q.text}"`, 'question');
    save();
    res.json(qView(q));
  });

  function answer(q, text, by) {
    q.answer = String(text || '').trim().slice(0, 600);
    q.answeredBy = by;
    q.answeredAt = now();
    if (q.customerId) notifyCustomer(q.customerId, 'Your question was answered', `${by}: ${q.answer}`, 'question', q.key.startsWith('GXL') ? `/product/${q.key}` : '');
  }

  seller.get('/questions', (req, res) => res.json(D().questions.filter((q) => q.sellerId === req.seller.id)));

  seller.post('/questions/:id/answer', (req, res) => {
    const q = find('questions', req.params.id);
    if (!q || q.sellerId !== req.seller.id) return bad(res, 404, 'Not found');
    if (String(req.body?.answer || '').trim().length < 2) return bad(res, 400, 'Type an answer');
    answer(q, req.body.answer, req.seller.storeName);
    save();
    res.json(q);
  });

  admin.post('/questions/:id/answer', (req, res) => {
    const q = find('questions', req.params.id);
    if (!q) return bad(res, 404, 'Not found');
    if (String(req.body?.answer || '').trim().length < 2) return bad(res, 400, 'Type an answer');
    answer(q, req.body.answer, 'GAMEX');
    save();
    res.json(q);
  });

  admin.patch('/reviews/:id', (req, res) => {
    const r = find('reviews', req.params.id);
    if (!r) return bad(res, 404, 'Not found');
    r.hidden = !!req.body?.hidden;
    save();
    res.json(r);
  });

  admin.patch('/questions/:id', (req, res) => {
    const q = find('questions', req.params.id);
    if (!q) return bad(res, 404, 'Not found');
    q.hidden = !!req.body?.hidden;
    save();
    res.json(q);
  });

  /** After "ship": book a real courier pickup when Shiprocket is connected. */
  async function onShipped(o) {
    if (!courierLive()) return;
    const r = await createShiprocketShipment(o, find('sellers', o.sellerId));
    if (!r) return;
    Object.assign(o, { awb: r.awb, courier: r.courier, shiprocketId: r.shipmentId });
    o.events.push({ l: `Shiprocket booked ${r.courier} • AWB ${r.awb}`, a: now() });
    save();
  }

  return { migrate, trackOne, recordPurchase, onShipped };
}
