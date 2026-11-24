// Growth & money features: trade-in quotes, Make an Offer, price / stock
// alerts with push, wallet (cashback + Refer & Earn), bank offers and the
// festival sale. Mounted by index.js on the shared API routers.
import crypto from 'node:crypto';
import fs from 'node:fs';

const DAY = 864e5;
const HOUR = 36e5;

// ---------------------------------------------------------------- data ----

/** Trade-in base value (₹) of a fully working phone in good shape, 128GB. */
export const TRADE_IN_MODELS = {
  Apple: {
    'iPhone 16 Pro': 62000, 'iPhone 16': 45000, 'iPhone 15 Pro Max': 58000, 'iPhone 15 Pro': 48000, 'iPhone 15': 33000,
    'iPhone 14 Pro Max': 42000, 'iPhone 14 Pro': 36000, 'iPhone 14': 25000, 'iPhone 13 Pro': 25000, 'iPhone 13': 19000,
    'iPhone 12 Pro': 17000, 'iPhone 12': 13000, 'iPhone 11 Pro': 12000, 'iPhone 11': 9000, 'iPhone SE (2022)': 7000,
  },
  Samsung: {
    'Galaxy S24 Ultra': 55000, 'Galaxy S24': 32000, 'Galaxy S23 Ultra': 38000, 'Galaxy S23': 22000, 'Galaxy S22': 13000,
    'Galaxy S21 FE': 9000, 'Galaxy Z Fold5': 45000, 'Galaxy Z Flip5': 25000, 'Galaxy A54': 9000, 'Galaxy M34': 6000,
  },
  Google: { 'Pixel 8 Pro': 30000, 'Pixel 8': 20000, 'Pixel 7 Pro': 16000, 'Pixel 7a': 12000, 'Pixel 7': 11000, 'Pixel 6a': 7000 },
  OnePlus: { 'OnePlus 12': 30000, 'OnePlus 12R': 22000, 'OnePlus 11': 20000, 'OnePlus 11R': 15000, 'Nord CE 3': 7000 },
  Xiaomi: { 'Xiaomi 14': 28000, 'Xiaomi 13 Pro': 22000, 'Redmi Note 13 Pro': 11000, 'Redmi Note 12 Pro': 7500 },
  vivo: { 'X100 Pro': 38000, 'X90 Pro': 24000, 'V29': 12000, 'V27': 9000 },
  Realme: { 'GT 6': 18000, '11 Pro': 8000 },
  Nothing: { 'Phone (2)': 15000, 'Phone (2a)': 11000, 'Phone (1)': 8000 },
  Motorola: { 'Edge 50 Pro': 13000, 'Edge 40': 9000 },
};

const STORAGE_FACTOR = { '64GB': 0.9, '128GB': 1, '256GB': 1.08, '512GB': 1.15, '1TB': 1.22 };

/** Condition questions: id → options [label, multiplier]. */
export const TRADE_IN_QUESTIONS = {
  power: [['Turns on and works normally', 1], ['Does not turn on / dead', 0.15]],
  screen: [['Flawless', 1], ['Minor scratches', 0.95], ['Visible scratches', 0.85], ['Cracked or dead pixels', 0.6]],
  body: [['Like new', 1], ['Minor scuffs', 0.95], ['Dents or cracked back', 0.82]],
  battery: [['90% or more', 1], ['80% – 89%', 0.95], ['Below 80% / Service', 0.86]],
};
/** Faults (multi-select): label → value deducted. */
export const TRADE_IN_FAULTS = {
  'Face ID / Fingerprint': 0.15,
  'Camera': 0.15,
  'Speaker / Mic': 0.08,
  'Charging port': 0.08,
  'Wi-Fi / Bluetooth / SIM': 0.1,
  'Buttons': 0.05,
};
export const TRADE_IN_EXTRAS = { 'Original box': 0.02, 'Original charger / cable': 0.01, 'Purchase invoice': 0.02 };

export function quoteTradeIn({ brand, model, storage = '128GB', answers = {}, faults = [], extras = [] }, newPhonePrice = 0, bonus = 0) {
  const base = TRADE_IN_MODELS[brand]?.[model];
  if (!base) return null;
  const lines = [{ label: `${model} base value`, amount: base }];
  let value = base;
  const sf = STORAGE_FACTOR[storage] ?? 1;
  if (sf !== 1) {
    lines.push({ label: `Storage ${storage}`, amount: Math.round(base * sf - base) });
    value = base * sf;
  }
  for (const [q, opts] of Object.entries(TRADE_IN_QUESTIONS)) {
    const pick = opts.find(([label]) => label === answers[q]) || opts[0];
    if (pick[1] !== 1) {
      const next = value * pick[1];
      lines.push({ label: pick[0], amount: Math.round(next - value) });
      value = next;
    }
  }
  if (answers.power !== TRADE_IN_QUESTIONS.power[1][0]) {
    for (const f of faults) {
      const cut = TRADE_IN_FAULTS[f];
      if (!cut) continue;
      lines.push({ label: `${f} not working`, amount: -Math.round(value * cut) });
      value *= 1 - cut;
    }
    for (const e of extras) {
      const add = TRADE_IN_EXTRAS[e];
      if (!add) continue;
      lines.push({ label: e, amount: Math.round(base * add) });
      value += base * add;
    }
  }
  value = Math.max(500, Math.round(value / 50) * 50);
  if (bonus > 0 && newPhonePrice >= 30000 && answers.power !== TRADE_IN_QUESTIONS.power[1][0]) {
    lines.push({ label: 'GAMEX exchange bonus', amount: bonus });
    value += bonus;
  }
  if (newPhonePrice > 0) value = Math.min(value, Math.round(newPhonePrice * 0.9));
  return { amount: value, lines };
}

export function defaultPromo() {
  const t = Date.now();
  return {
    sale: {
      active: true,
      title: 'Diwali Dhamaka Sale',
      subtitle: 'Extra 5% off on flash deals • Bank offers • No-cost EMI',
      startsAt: new Date(t - 6 * HOUR).toISOString(),
      endsAt: new Date(t + 2 * DAY + 9 * HOUR).toISOString(),
      extraOffPercent: 5,
      maxExtraOff: 3000,
    },
    bankOffers: [
      { id: 'BO1', bank: 'HDFC Bank', kind: 'card', text: '10% instant discount on credit cards', percent: 10, flat: 0, maxOff: 3000, minOrder: 20000, active: true },
      { id: 'BO2', bank: 'ICICI Bank', kind: 'emi', text: '7.5% off on credit card EMI', percent: 7.5, flat: 0, maxOff: 2500, minOrder: 25000, active: true },
      { id: 'BO3', bank: 'SBI Card', kind: 'card', text: 'Flat ₹1,500 off on SBI credit cards', percent: 0, flat: 1500, maxOff: 1500, minOrder: 30000, active: true },
      { id: 'BO4', bank: 'Axis Bank', kind: 'any', text: '5% off on cards & EMI', percent: 5, flat: 0, maxOff: 2000, minOrder: 15000, active: true },
    ],
    referral: { referrerBonus: 500, friendBonus: 250 },
    cashbackRate: 0.02,
    cashbackCap: 1500,
    walletMaxPercent: 20,
    exchangeBonus: 1000,
  };
}

export function bankDiscount(offer, amount) {
  if (!offer || !offer.active || amount < (offer.minOrder || 0)) return 0;
  const raw = offer.flat ? offer.flat : (amount * offer.percent) / 100;
  return Math.round(Math.min(raw, offer.maxOff || raw));
}

// ---------------------------------------------------------------- push ----

let fcm = null; // { projectId, clientEmail, key, token, exp }
function fcmConfig() {
  if (fcm !== null) return fcm || null;
  const file = process.env.FCM_SERVICE_ACCOUNT;
  try {
    if (!file) throw new Error('not configured');
    const j = JSON.parse(fs.readFileSync(file, 'utf8'));
    fcm = { projectId: j.project_id, clientEmail: j.client_email, key: j.private_key, token: null, exp: 0 };
  } catch {
    fcm = false;
  }
  return fcm || null;
}

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');

async function fcmToken(cfg) {
  if (cfg.token && cfg.exp > Date.now() + 60e3) return cfg.token;
  const iat = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
    iss: cfg.clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  })}`;
  const sig = crypto.sign('RSA-SHA256', Buffer.from(unsigned), cfg.key).toString('base64url');
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${sig}`,
  });
  const j = await r.json();
  if (!j.access_token) throw new Error('FCM auth failed');
  cfg.token = j.access_token;
  cfg.exp = Date.now() + (j.expires_in || 3600) * 1000;
  return cfg.token;
}

/** Sends a push through Firebase Cloud Messaging when FCM_SERVICE_ACCOUNT is set. */
async function sendPush(tokens, n) {
  const cfg = fcmConfig();
  if (!cfg || !tokens.length) return 0;
  let sent = 0;
  try {
    const access = await fcmToken(cfg);
    for (const t of tokens) {
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${cfg.projectId}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${access}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: t,
            notification: { title: n.title, body: n.body },
            data: { link: n.link || '', kind: n.kind || 'info', id: n.id },
            android: { priority: 'high', notification: { channel_id: 'gamex_alerts' } },
          },
        }),
      });
      if (r.ok) sent++;
    }
  } catch (e) {
    console.warn('[push]', e.message);
  }
  return sent;
}

// --------------------------------------------------------------- mount ----

export function mountGrowth(ctx) {
  const { api, seller, admin, D, save, now, uid, find, notify, log, bad, titleOf, isLive } = ctx;

  function migrate() {
    const db = D();
    db.promo ??= defaultPromo();
    db.offers ??= [];
    db.alerts ??= [];
    db.pushTokens ??= [];
    db.customerNotifs ??= [];
    db.walletTx ??= [];
    db.tradeIns ??= [];
    for (const c of db.customers) c.referralCode ??= codeFor(c.id);
    if (!db.growthSeeded) {
      db.growthSeeded = true;
      // A few buyer offers so the seller app's Offers inbox has examples.
      const live = db.listings.filter((l) => l.sellerId === 'S1001' && l.status === 'active' && l.stock > 0).slice(0, 3);
      live.forEach((l, i) => {
        const c = db.customers[(i * 3) % db.customers.length];
        if (!c) return;
        const amount = Math.round((l.price * [0.88, 0.92, 0.85][i]) / 100) * 100;
        const at = new Date(Date.now() - (i + 1) * 47 * 6e4).toISOString();
        db.offers.push({
          id: `OF${7001 + i}`,
          listingId: l.id,
          sellerId: l.sellerId,
          customerId: c.id,
          customerName: c.name,
          listPrice: l.price,
          amount,
          counter: null,
          dealPrice: null,
          note: ['Can you do this price? Will buy today.', 'Paying via UPI, please accept.', ''][i],
          status: 'pending',
          createdAt: at,
          expiresAt: new Date(Date.parse(at) + DAY).toISOString(),
          dealExpiresAt: null,
          events: [{ l: `Offered ₹${amount.toLocaleString('en-IN')}`, a: at }],
        });
      });
    }
  }
  const codeFor = (id) => 'GX' + crypto.createHash('sha1').update(String(id)).digest('hex').slice(0, 6).toUpperCase();
  migrate();

  const money = (n) => `₹${Math.round(n).toLocaleString('en-IN')}`;

  /** In-app + push notification for a customer. */
  function notifyCustomer(customerId, title, body, kind = 'info', link = '') {
    const db = D();
    const n = { id: uid('CN'), customerId, title, body, kind, link, at: now(), read: false };
    db.customerNotifs.unshift(n);
    db.customerNotifs = db.customerNotifs.slice(0, 1000);
    const tokens = db.pushTokens.filter((t) => t.customerId === customerId).map((t) => t.token);
    sendPush(tokens, n).then((k) => {
      if (k) n.pushed = true;
    });
    return n;
  }

  // ------------------------------------------------------------ promo --
  api.get('/promo', (_, res) => {
    const p = D().promo;
    res.json({ ...p, bankOffers: p.bankOffers.filter((b) => b.active), serverTime: now() });
  });

  // --------------------------------------------------------- trade-in --
  api.get('/trade-in/models', (_, res) =>
    res.json({ models: TRADE_IN_MODELS, questions: TRADE_IN_QUESTIONS, faults: TRADE_IN_FAULTS, extras: TRADE_IN_EXTRAS, bonus: D().promo.exchangeBonus }),
  );

  api.post('/trade-in/quote', (req, res) => {
    const b = req.body || {};
    const q = quoteTradeIn(b, Number(b.newPhonePrice) || 0, D().promo.exchangeBonus);
    if (!q) return bad(res, 400, 'We do not buy this model yet');
    const t = {
      id: uid('TI'),
      customerId: b.customerId || 'guest',
      brand: b.brand,
      model: b.model,
      storage: b.storage || '128GB',
      answers: b.answers || {},
      faults: b.faults || [],
      extras: b.extras || [],
      amount: q.amount,
      lines: q.lines,
      status: 'quoted',
      orderId: null,
      createdAt: now(),
      expiresAt: new Date(Date.now() + 7 * DAY).toISOString(),
      events: [{ l: `Quoted ${money(q.amount)}`, a: now() }],
    };
    D().tradeIns.unshift(t);
    save();
    res.json(t);
  });

  api.get('/trade-ins', (req, res) => res.json(D().tradeIns.filter((t) => t.customerId === req.query.customerId)));

  // ----------------------------------------------------------- offers --
  const OFFER_MIN = 0.7;
  function expireOffers() {
    const t = now();
    for (const o of D().offers) {
      if (['pending', 'countered'].includes(o.status) && o.expiresAt < t) {
        o.status = 'expired';
        o.events.push({ l: 'Expired', a: t });
      }
      if (o.status === 'accepted' && o.dealExpiresAt < t) {
        o.status = 'expired';
        o.events.push({ l: 'Deal expired', a: t });
      }
    }
  }
  const offerView = (o) => {
    const l = find('listings', o.listingId);
    return { ...o, listing: l ? { id: l.id, title: titleOf(l), photo: l.photos?.[0], price: l.price, stock: units(l), live: isLive(l) } : null };
  };

  api.post('/offers', (req, res) => {
    expireOffers();
    const { listingId, customer = {}, amount, note = '' } = req.body || {};
    const l = find('listings', listingId);
    if (!l || !isLive(l) || units(l) <= 0) return bad(res, 404, 'This phone is not available');
    if (!customer.id) return bad(res, 401, 'Log in to make an offer');
    const a = Math.round(Number(amount));
    if (!(a > 0) || a >= l.price) return bad(res, 400, 'Offer must be below the current price');
    if (a < l.price * OFFER_MIN) return bad(res, 400, `Offers below ${money(l.price * OFFER_MIN)} are not accepted for this phone`);
    const mine = D().offers.filter((o) => o.listingId === l.id && o.customerId === customer.id);
    if (mine.some((o) => ['pending', 'countered', 'accepted'].includes(o.status))) return bad(res, 409, 'You already have an open offer on this phone');
    if (mine.length >= 3) return bad(res, 429, 'You can make up to 3 offers on a phone');
    const o = {
      id: uid('OF'),
      listingId: l.id,
      sellerId: l.sellerId,
      customerId: customer.id,
      customerName: customer.name || 'Customer',
      listPrice: l.price,
      amount: a,
      counter: null,
      dealPrice: null,
      note: String(note).slice(0, 200),
      status: 'pending',
      createdAt: now(),
      expiresAt: new Date(Date.now() + DAY).toISOString(),
      dealExpiresAt: null,
      events: [{ l: `Offered ${money(a)}`, a: now() }],
    };
    D().offers.unshift(o);
    notify(l.sellerId, `New offer: ${money(a)} 💬`, `${o.customerName} offered ${money(a)} for ${titleOf(l)} (listed ${money(l.price)}). Reply within 24 hours.`, 'offer');
    log(`Offer ${money(a)} on ${titleOf(l)}`, 'offer');
    save();
    res.json(offerView(o));
  });

  api.get('/offers', (req, res) => {
    expireOffers();
    res.json(D().offers.filter((o) => o.customerId === req.query.customerId).map(offerView));
  });

  /** Buyer reply to a counter-offer, or withdraw. */
  api.post('/offers/:id/respond', (req, res) => {
    expireOffers();
    const o = find('offers', req.params.id);
    const { customerId, action } = req.body || {};
    if (!o || o.customerId !== customerId) return bad(res, 404, 'Offer not found');
    if (action === 'withdraw' && ['pending', 'countered'].includes(o.status)) {
      o.status = 'withdrawn';
      o.events.push({ l: 'Withdrawn by buyer', a: now() });
    } else if (o.status !== 'countered') return bad(res, 409, 'Nothing to respond to');
    else if (action === 'accept') {
      o.status = 'accepted';
      o.dealPrice = o.counter;
      o.dealExpiresAt = new Date(Date.now() + 2 * DAY).toISOString();
      o.events.push({ l: `Buyer accepted ${money(o.counter)}`, a: now() });
      notify(o.sellerId, 'Counter-offer accepted 🤝', `${o.customerName} accepted ${money(o.counter)}. The deal is reserved for 48 hours.`, 'offer');
    } else if (action === 'reject') {
      o.status = 'rejected';
      o.events.push({ l: 'Buyer declined the counter', a: now() });
    } else return bad(res, 400, 'Unknown action');
    save();
    res.json(offerView(o));
  });

  seller.get('/offers', (req, res) => {
    expireOffers();
    res.json(D().offers.filter((o) => o.sellerId === req.seller.id).map(offerView));
  });

  seller.post('/offers/:id/:action', (req, res) => {
    expireOffers();
    const o = find('offers', req.params.id);
    if (!o || o.sellerId !== req.seller.id) return bad(res, 404, 'Offer not found');
    if (o.status !== 'pending') return bad(res, 409, `Offer is ${o.status}`);
    const l = find('listings', o.listingId);
    const title = l ? titleOf(l) : 'your phone';
    const link = `/product/${o.listingId}`;
    switch (req.params.action) {
      case 'accept':
        o.status = 'accepted';
        o.dealPrice = o.amount;
        o.dealExpiresAt = new Date(Date.now() + 2 * DAY).toISOString();
        o.events.push({ l: 'Seller accepted', a: now() });
        notifyCustomer(o.customerId, 'Offer accepted! 🎉', `${req.seller.storeName} accepted ${money(o.amount)} for ${title}. Buy within 48 hours.`, 'offer', link);
        break;
      case 'counter': {
        const c = Math.round(Number((req.body || {}).amount));
        if (!(c > o.amount) || (l && c >= l.price)) return bad(res, 400, 'Counter must be between the offer and the listed price');
        o.status = 'countered';
        o.counter = c;
        o.expiresAt = new Date(Date.now() + DAY).toISOString();
        o.events.push({ l: `Seller countered ${money(c)}`, a: now() });
        notifyCustomer(o.customerId, 'Counter-offer received', `${req.seller.storeName} can do ${money(c)} for ${title}. Reply within 24 hours.`, 'offer', link);
        break;
      }
      case 'reject':
        o.status = 'rejected';
        o.events.push({ l: `Seller declined${req.body?.reason ? ` • ${req.body.reason}` : ''}`, a: now() });
        notifyCustomer(o.customerId, 'Offer declined', `${req.seller.storeName} declined ${money(o.amount)} for ${title}. Try a different price.`, 'offer', link);
        break;
      default:
        return bad(res, 400, 'Unknown action');
    }
    save();
    res.json(offerView(o));
  });

  /** Price a buyer pays for a listing (honours an accepted offer). */
  function offerPrice(l, it, customerId) {
    if (!it.offerId) return { price: l.price };
    expireOffers();
    const o = find('offers', it.offerId);
    if (o && o.listingId === l.id && o.customerId === customerId && o.status === 'accepted') return { price: o.dealPrice, offer: o };
    return { price: l.price };
  }

  // ----------------------------------------------------------- alerts --
  api.get('/alerts', (req, res) => res.json(D().alerts.filter((a) => a.customerId === req.query.customerId && a.status === 'active')));

  api.post('/alerts', (req, res) => {
    const { customerId, listingId, type, targetPrice } = req.body || {};
    const l = find('listings', listingId);
    if (!customerId || !l || !['price', 'stock'].includes(type)) return bad(res, 400, 'Invalid alert');
    const db = D();
    db.alerts = db.alerts.filter((a) => !(a.customerId === customerId && a.listingId === listingId && a.type === type));
    const a = {
      id: uid('AL'),
      customerId,
      listingId,
      type,
      title: titleOf(l),
      priceAtSet: l.price,
      targetPrice: type === 'price' ? Math.round(Number(targetPrice) || l.price - 1) : null,
      status: 'active',
      createdAt: now(),
    };
    db.alerts.unshift(a);
    save();
    res.json(a);
  });

  api.delete('/alerts/:id', (req, res) => {
    const a = find('alerts', req.params.id);
    if (a && a.customerId === req.query.customerId) a.status = 'removed';
    save();
    res.json({ ok: true });
  });

  /** Call after a listing's price, stock or status changed. */
  function listingChanged(l, before) {
    const live = isLive(l) && units(l) > 0;
    for (const a of D().alerts) {
      if (a.status !== 'active' || a.listingId !== l.id) continue;
      if (a.type === 'price' && live && l.price < before.price && l.price <= a.targetPrice) {
        a.status = 'fired';
        a.firedAt = now();
        notifyCustomer(a.customerId, `Price drop: ${a.title} 📉`, `Now ${money(l.price)} (was ${money(a.priceAtSet)}). Grab it before it's gone!`, 'price', `/product/${l.id}`);
      }
      if (a.type === 'stock' && live && !(before.live && before.stock > 0)) {
        a.status = 'fired';
        a.firedAt = now();
        notifyCustomer(a.customerId, `Back in stock: ${a.title} 🔔`, `Available again at ${money(l.price)}. Only ${units(l)} left.`, 'stock', `/product/${l.id}`);
      }
    }
  }
  const units = (l) => (l.stock || 0) + (l.variants || []).reduce((t, v) => t + (v.stock || 0), 0);
  const snapshot = (l) => ({ price: l.price, stock: units(l), live: isLive(l) });

  // ------------------------------------------- notifications & push --
  api.get('/customers/:id/notifications', (req, res) => {
    const since = String(req.query.since || '');
    res.json(D().customerNotifs.filter((n) => n.customerId === req.params.id && (!since || n.at > since)).slice(0, 50));
  });

  api.post('/customers/:id/notifications/read', (req, res) => {
    for (const n of D().customerNotifs) if (n.customerId === req.params.id) n.read = true;
    save();
    res.json({ ok: true });
  });

  api.post('/push/register', (req, res) => {
    const { customerId, token, platform = 'android' } = req.body || {};
    if (!customerId || !token) return bad(res, 400, 'customerId and token required');
    const db = D();
    db.pushTokens = db.pushTokens.filter((t) => t.token !== token);
    db.pushTokens.push({ customerId, token, platform, at: now() });
    save();
    res.json({ ok: true, push: !!fcmConfig() });
  });

  // ----------------------------------------------- wallet & referral --
  function releaseDue(customerId) {
    const t = now();
    for (const x of D().walletTx) {
      if (x.customerId === customerId && x.status === 'pending' && x.releaseAt && x.releaseAt <= t) x.status = 'available';
    }
  }
  function walletOf(customerId) {
    releaseDue(customerId);
    const tx = D().walletTx.filter((x) => x.customerId === customerId);
    const sum = (s) => tx.filter((x) => x.status === s).reduce((a, x) => a + x.amount, 0);
    return { balance: Math.max(0, sum('available')), pending: sum('pending'), tx };
  }

  api.get('/wallet/:customerId', (req, res) => {
    const db = D();
    const c = find('customers', req.params.customerId);
    const w = walletOf(req.params.customerId);
    const friends = db.customers.filter((x) => x.referredBy === req.params.customerId);
    res.json({
      ...w,
      referralCode: c?.referralCode || codeFor(req.params.customerId),
      referredBy: c?.referredBy || null,
      friends: friends.map((f) => ({ name: f.name, joinedAt: f.referredAt, ordered: db.orders.some((o) => o.customerId === f.id && o.stage === 'delivered') })),
      promo: { referral: db.promo.referral, cashbackRate: db.promo.cashbackRate, cashbackCap: db.promo.cashbackCap, walletMaxPercent: db.promo.walletMaxPercent },
    });
  });

  api.post('/referrals/apply', (req, res) => {
    const db = D();
    const { customerId, code } = req.body || {};
    const c = find('customers', customerId);
    if (!c) return bad(res, 404, 'Log in first');
    if (c.referredBy) return bad(res, 409, 'You have already used a referral code');
    const ref = db.customers.find((x) => x.referralCode === String(code || '').trim().toUpperCase());
    if (!ref) return bad(res, 404, 'Invalid referral code');
    if (ref.id === c.id) return bad(res, 400, 'You cannot use your own code');
    if (db.orders.some((o) => o.customerId === c.id) || db.walletTx.some((x) => x.customerId === c.id && x.kind === 'cashback')) {
      return bad(res, 409, 'Referral codes work only before your first order');
    }
    const { referrerBonus, friendBonus } = db.promo.referral;
    c.referredBy = ref.id;
    c.referredAt = now();
    db.walletTx.unshift({ id: uid('WT'), customerId: c.id, amount: friendBonus, kind: 'referralBonus', status: 'available', label: `Welcome bonus • invited by ${ref.name}`, at: now() });
    db.walletTx.unshift({ id: uid('WT'), customerId: ref.id, amount: referrerBonus, kind: 'referral', status: 'pending', label: `${c.name} joined • unlocks on their first delivery`, friendId: c.id, at: now() });
    notifyCustomer(ref.id, 'Your friend joined GAMEX 🎁', `${c.name} used your code. ${money(referrerBonus)} unlocks when their first order is delivered.`, 'wallet', '/wallet');
    save();
    res.json(walletOf(c.id));
  });

  // ------------------------------------------------- order lifecycle --
  /**
   * Validates the money parts of an order (wallet, trade-in) before any
   * listing is reserved. Returns an error string or null.
   */
  function checkOrder(body) {
    const { customer = {}, amounts = {}, tradeInId } = body;
    const walletUse = Math.round(Number(amounts.walletUse) || 0);
    if (walletUse > 0) {
      const w = walletOf(customer.id);
      if (walletUse > w.balance) return 'Wallet balance changed. Please review your order.';
      const cap = ((Number(amounts.total) || 0) + walletUse) * (D().promo.walletMaxPercent / 100);
      if (walletUse > cap + 1) return `Wallet can pay up to ${D().promo.walletMaxPercent}% of an order`;
    }
    if (tradeInId) {
      const t = find('tradeIns', tradeInId);
      if (!t || t.status !== 'quoted' || t.expiresAt < now()) return 'Your trade-in quote has expired. Get a fresh quote.';
    }
    return null;
  }

  function onOrderPlaced(body, created) {
    const db = D();
    const { orderId, customer = {}, amounts = {}, tradeInId } = body;
    const cid = customer.id;
    const first = created[0] ? find('orders', created[0]) : null;
    const walletUse = Math.round(Number(amounts.walletUse) || 0);
    if (walletUse > 0 && cid) {
      db.walletTx.unshift({ id: uid('WT'), customerId: cid, amount: -walletUse, kind: 'spent', status: 'available', label: `Used on order ${orderId}`, orderId, at: now() });
    }
    const total = Number(amounts.total) || 0;
    if (cid && cid !== 'guest' && total > 0) {
      const cb = Math.min(db.promo.cashbackCap, Math.round(total * db.promo.cashbackRate));
      if (cb > 0) {
        db.walletTx.unshift({
          id: uid('WT'),
          customerId: cid,
          amount: cb,
          kind: 'cashback',
          status: 'pending',
          label: `${Math.round(db.promo.cashbackRate * 100)}% cashback • order ${orderId}`,
          orderId,
          // Marketplace orders release after delivery + return window.
          releaseAt: first ? null : new Date(Date.now() + 9 * DAY).toISOString(),
          at: now(),
        });
      }
    }
    if (tradeInId) {
      const t = find('tradeIns', tradeInId);
      if (t) {
        t.status = 'awaitingPickup';
        t.orderId = orderId;
        t.customerId = cid || t.customerId;
        t.events.push({ l: `Attached to order ${orderId} • pickup at delivery`, a: now() });
        if (first) first.tradeIn = { id: t.id, model: t.model, storage: t.storage, amount: t.amount, answers: t.answers, faults: t.faults };
      }
    }
    for (const id of created) {
      const o = find('orders', id);
      if (o) o.payable = Math.max(0, o.price - (o.tradeIn?.amount || 0));
    }
  }

  function onDelivered(o) {
    const db = D();
    const release = new Date(Date.now() + (o.returnDays ?? 7) * DAY).toISOString();
    for (const x of db.walletTx) if (x.orderId === o.orderId && x.kind === 'cashback' && x.status === 'pending') x.releaseAt = release;
    // First delivered order unlocks the referrer's reward.
    const c = find('customers', o.customerId);
    if (c?.referredBy) {
      const reward = db.walletTx.find((x) => x.kind === 'referral' && x.friendId === c.id && x.status === 'pending');
      if (reward) {
        reward.status = 'available';
        reward.label = `${c.name}'s first order delivered`;
        notifyCustomer(c.referredBy, `You earned ${money(reward.amount)} 🎉`, `${c.name}'s first GAMEX order was delivered. The money is in your wallet.`, 'wallet', '/wallet');
      }
    }
    if (o.tradeIn) {
      const t = find('tradeIns', o.tradeIn.id);
      if (t && t.status === 'awaitingPickup') {
        t.status = 'pickedUp';
        t.events.push({ l: 'Old phone collected at delivery', a: now() });
      }
    }
    notifyCustomer(o.customerId, 'Delivered ✅', `${o.item} was delivered. Enjoy your phone!`, 'order', `/order/${o.orderId}`);
  }

  function onCancelled(o) {
    const db = D();
    const siblings = db.orders.filter((x) => x.orderId === o.orderId);
    if (siblings.some((x) => !['cancelled'].includes(x.stage))) return;
    for (const x of db.walletTx) {
      if (x.orderId !== o.orderId) continue;
      if (x.kind === 'cashback' && x.status === 'pending') x.status = 'void';
      if (x.kind === 'spent' && x.status === 'available' && !x.refunded) {
        x.refunded = true;
        db.walletTx.unshift({ id: uid('WT'), customerId: x.customerId, amount: -x.amount, kind: 'refund', status: 'available', label: `Refund • order ${o.orderId} cancelled`, orderId: o.orderId, at: now() });
      }
    }
    if (o.tradeIn) {
      const t = find('tradeIns', o.tradeIn.id);
      if (t) {
        t.status = 'cancelled';
        t.events.push({ l: 'Order cancelled', a: now() });
      }
    }
    notifyCustomer(o.customerId, 'Order cancelled', `${o.item}: ${o.cancelReason || 'cancelled'}. Any wallet money used has been refunded.`, 'order', `/order/${o.orderId}`);
  }

  // ------------------------------------------------------------ admin --
  admin.put('/promo', (req, res) => {
    const p = D().promo;
    const { sale, referral, cashbackRate, cashbackCap, walletMaxPercent, exchangeBonus } = req.body || {};
    if (sale) Object.assign(p.sale, sale);
    if (referral) Object.assign(p.referral, referral);
    if (cashbackRate !== undefined) p.cashbackRate = Number(cashbackRate);
    if (cashbackCap !== undefined) p.cashbackCap = Number(cashbackCap);
    if (walletMaxPercent !== undefined) p.walletMaxPercent = Number(walletMaxPercent);
    if (exchangeBonus !== undefined) p.exchangeBonus = Number(exchangeBonus);
    log('Promotions updated', 'promo');
    save();
    res.json(p);
  });

  admin.post('/bank-offers', (req, res) => {
    const b = req.body || {};
    if (!b.bank || !b.text) return bad(res, 400, 'Bank and text required');
    const o = { id: uid('BO'), bank: b.bank, kind: b.kind || 'card', text: b.text, percent: Number(b.percent) || 0, flat: Number(b.flat) || 0, maxOff: Number(b.maxOff) || 0, minOrder: Number(b.minOrder) || 0, active: b.active !== false };
    D().promo.bankOffers.push(o);
    save();
    res.json(o);
  });

  admin.patch('/bank-offers/:id', (req, res) => {
    const o = D().promo.bankOffers.find((x) => x.id === req.params.id);
    if (!o) return bad(res, 404, 'Not found');
    Object.assign(o, req.body || {});
    save();
    res.json(o);
  });

  admin.delete('/bank-offers/:id', (req, res) => {
    const p = D().promo;
    p.bankOffers = p.bankOffers.filter((x) => x.id !== req.params.id);
    save();
    res.json({ ok: true });
  });

  const TRADE_FLOW = {
    pickup: [['awaitingPickup'], 'pickedUp', 'Old phone collected'],
    verify: [['pickedUp'], 'verified', 'Verified by GAMEX • credit confirmed'],
    adjust: [['pickedUp'], 'adjusted', 'Value adjusted after inspection'],
    reject: [['quoted', 'awaitingPickup', 'pickedUp'], 'rejected', 'Trade-in rejected'],
  };
  admin.post('/trade-ins/:id/:action', (req, res) => {
    const t = find('tradeIns', req.params.id);
    const flow = TRADE_FLOW[req.params.action];
    if (!t || !flow) return bad(res, 404, 'Not found');
    if (!flow[0].includes(t.status)) return bad(res, 409, `Trade-in is ${t.status}`);
    const { finalAmount, note = '' } = req.body || {};
    if (req.params.action === 'adjust') {
      const f = Math.round(Number(finalAmount));
      if (!(f >= 0) || f >= t.amount) return bad(res, 400, 'Adjusted value must be below the quote');
      t.finalAmount = f;
      const diff = t.amount - f;
      notifyCustomer(t.customerId, 'Trade-in value updated', `Our inspection found ${note || 'differences'} in your ${t.model}. Final value ${money(f)}; ${money(diff)} will be collected or adjusted.`, 'tradein', '');
    }
    if (req.params.action === 'verify') t.finalAmount = t.amount;
    t.status = flow[1];
    t.note = note;
    t.events.push({ l: `${flow[2]}${note ? ` • ${note}` : ''}`, a: now() });
    log(`Trade-in ${t.id} → ${t.status}`, 'tradein');
    save();
    res.json(t);
  });

  return { migrate, checkOrder, onOrderPlaced, onDelivered, onCancelled, offerPrice, codeFor, notifyCustomer, listingChanged, snapshot, sendPush };
}
