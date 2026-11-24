// Help Center: articles, support tickets and live chat with the GAMEX
// Assistant (Claude) that hands over to a human agent when needed.
//
// The assistant uses Claude when ANTHROPIC_API_KEY is set on the server;
// without it a built-in rule-based assistant answers common questions
// (order status, returns, refunds, warranty, payments) and offers an agent.
import Anthropic from '@anthropic-ai/sdk';

const MODEL = 'claude-opus-5-5';
const AGENT_HOURS = { from: 9, to: 21 }; // IST

export const HELP_ARTICLES = [
  { id: 'h1', topic: 'orders', title: 'Where is my order?', body: 'Open Orders in the app to see live tracking. Phones are packed within 24 hours and delivered in 2–5 days. You get an SMS and app notification with the courier and AWB number when the parcel is shipped. Share the 4-digit delivery OTP only when the parcel is in your hands.' },
  { id: 'h2', topic: 'orders', title: 'Can I cancel my order?', body: 'You can cancel any time before the phone is shipped from Orders › Cancel. Prepaid orders are refunded automatically to the original payment method. After shipping you can refuse the parcel at the door, or request a return after delivery.' },
  { id: 'h3', topic: 'returns', title: 'How do returns work?', body: 'Most phones have a 7-day return window from delivery (shown on the product page). Go to Orders › Return, choose a reason and a pickup slot. A courier collects the phone, GAMEX checks it, and your refund starts the same day the check passes. Phones must be returned with the box, accessories and without iCloud / Google lock.' },
  { id: 'h4', topic: 'refunds', title: 'When will I get my refund?', body: 'Refunds to UPI arrive in 1–3 days, to cards and net banking in 5–7 business days, to the GAMEX Wallet instantly. Cash-on-delivery orders are refunded by bank transfer / UPI after you share your account details — you get the UTR number in the app.' },
  { id: 'h5', topic: 'warranty', title: 'What does the GAMEX warranty cover?', body: 'Every certified phone has seller warranty (usually 6 months, shown on the product page) covering functional defects: display, battery, cameras, speakers, charging, network. Physical or liquid damage is not covered. Raise a claim from Orders › Warranty with photos; we repair or replace within 7 working days.' },
  { id: 'h6', topic: 'payments', title: 'Payment options & Cash on Delivery', body: 'Pay with UPI, cards, net banking, wallets, EMI or Pay Later. Cash on Delivery is available on most phones; on your first order COD is allowed up to ₹15,000 and a small COD fee applies. Online payments are protected by Razorpay.' },
  { id: 'h7', topic: 'payments', title: 'EMI and Pay Later', body: 'No-cost EMI is available on selected cards for orders above ₹10,000. Use the EMI calculator on the product page to compare plans. Pay Later options appear at checkout when you are eligible.' },
  { id: 'h8', topic: 'quality', title: 'What does “GAMEX Certified” mean?', body: 'Each phone is checked by the seller on a detailed checklist and verified by the GAMEX quality team: IMEI is blacklist-free, functions are tested and cosmetic marks are photographed. Open the Inspection Report on any product to see every check.' },
  { id: 'h9', topic: 'sell', title: 'Exchange or sell my old phone', body: 'Get an instant quote in Trade-in / Sell Your Phone. Exchange value is deducted from your new order; when you sell to GAMEX the amount is paid to your UPI the same day the phone is picked up and checked.' },
  { id: 'h10', topic: 'repairs', title: 'Book a repair', body: 'Choose Repairs in the app, pick the issue (screen, battery, charging…) and a doorstep pickup slot. You approve the final quote before work starts; repairs carry a 6-month repair warranty.' },
  { id: 'h11', topic: 'account', title: 'Change my number, email or password', body: 'Go to Account › Account Settings to edit your name and email. Use “Forgot password” on the login screen to set a new password with an OTP. Your mobile number is your login, so contact support to change it.' },
  { id: 'h12', topic: 'account', title: 'Delete my account and data', body: 'Account › Privacy & Security › Delete account, or visit the delete-account page on our website. We remove your profile within 30 days; invoices are kept as required by law.' },
];

export const HELP_TOPICS = [
  { id: 'orders', title: 'Orders & delivery', icon: 'local_shipping' },
  { id: 'returns', title: 'Returns', icon: 'assignment_return' },
  { id: 'refunds', title: 'Refunds', icon: 'currency_rupee' },
  { id: 'payments', title: 'Payments & EMI', icon: 'payments' },
  { id: 'warranty', title: 'Warranty', icon: 'verified_user' },
  { id: 'quality', title: 'Phone quality', icon: 'workspace_premium' },
  { id: 'sell', title: 'Sell & exchange', icon: 'swap_horiz' },
  { id: 'repairs', title: 'Repairs', icon: 'build' },
  { id: 'account', title: 'Account & privacy', icon: 'person' },
];

export const TICKET_CATEGORIES = ['Order & delivery', 'Return & refund', 'Payment', 'Warranty & repair', 'Product quality', 'Sell / exchange', 'Account', 'Other'];

const REPLY_SCHEMA = {
  type: 'object',
  properties: {
    reply: { type: 'string', description: 'Message to the customer, plain text, max ~120 words.' },
    handoff: { type: 'boolean', description: 'true when a human agent must take over.' },
    suggestions: { type: 'array', items: { type: 'string' }, description: 'Up to 3 short follow-up taps for the customer.' },
    topic: { type: 'string', enum: ['orders', 'returns', 'refunds', 'payments', 'warranty', 'quality', 'sell', 'repairs', 'account', 'other'] },
  },
  required: ['reply', 'handoff', 'suggestions', 'topic'],
  additionalProperties: false,
};

export function mountSupport(ctx) {
  const { api, admin, D, save, now, uid, find, bad, log, notifyCustomer } = ctx;
  const claude = process.env.ANTHROPIC_API_KEY ? new Anthropic() : null;
  const money = (n) => `₹${Math.round(Number(n) || 0).toLocaleString('en-IN')}`;
  const text = (v, n) => String(v ?? '').trim().slice(0, n);

  function migrate() {
    const db = D();
    db.tickets ??= [];
    db.chats ??= [];
    if (!db.helpArticles) db.helpArticles = HELP_ARTICLES.map((a) => ({ ...a }));
  }
  migrate();

  const agentsOnline = () => {
    const h = Number(new Date().toLocaleString('en-GB', { hour: '2-digit', hour12: false, timeZone: 'Asia/Kolkata' }));
    return h >= AGENT_HOURS.from && h < AGENT_HOURS.to;
  };
  const msg = (from, body, extra = {}) => ({ id: uid('M'), from, text: body, at: now(), ...extra });
  const ordersOf = (cid) => D().orders.filter((o) => o.customerId === cid).slice(0, 8);
  const stageLabel = {
    newOrder: 'placed, waiting for the seller',
    accepted: 'accepted, being packed',
    packed: 'packed, ready to ship',
    shipped: 'shipped',
    delivered: 'delivered',
    cancelled: 'cancelled',
    returned: 'returned',
  };

  // ---------------------------------------------------------- tickets --
  const ticketView = (t) => ({ ...t, customerId: undefined });
  const slaHours = (priority) => (priority === 'urgent' ? 4 : priority === 'high' ? 12 : 24);

  function createTicket(c, { subject, category, orderId, body, photos = [], source = 'app', priority }) {
    const order = orderId ? D().orders.find((o) => (o.id === orderId || o.orderId === orderId) && o.customerId === c.id) : null;
    const pri = priority || (category === 'Payment' || category === 'Return & refund' ? 'high' : 'normal');
    const t = {
      id: uid('TK'),
      customerId: c.id,
      name: c.name,
      phone: c.phone || '',
      subject: text(subject, 120) || category,
      category: TICKET_CATEGORIES.includes(category) ? category : 'Other',
      orderId: order ? order.id : null,
      orderItem: order ? order.item : null,
      priority: pri,
      status: 'open',
      source,
      assignee: null,
      messages: [msg('customer', text(body, 3000), { author: c.name, photos: photos.slice(0, 6) })],
      createdAt: now(),
      updatedAt: now(),
      slaDueAt: new Date(Date.now() + slaHours(pri) * 36e5).toISOString(),
      unreadCustomer: false,
      unreadAdmin: true,
      rating: null,
    };
    t.messages.push(msg('system', `Ticket ${t.id} created. Our team replies within ${slaHours(pri)} hours — usually much sooner.`));
    D().tickets.unshift(t);
    log(`Support ticket ${t.id} • ${t.category} • ${c.name}`, 'support');
    return t;
  }

  api.get('/support/home', (req, res) => {
    const c = req.customer;
    const db = D();
    res.json({
      topics: HELP_TOPICS,
      articles: db.helpArticles,
      categories: TICKET_CATEGORIES,
      contact: { phone: db.settings.supportPhone, email: db.settings.supportEmail, hours: '9 AM – 9 PM, all days', agentsOnline: agentsOnline() },
      ai: !!claude,
      openTickets: c ? db.tickets.filter((t) => t.customerId === c.id && !['resolved', 'closed'].includes(t.status)).length : 0,
      unread: c ? db.tickets.filter((t) => t.customerId === c.id && t.unreadCustomer).length + db.chats.filter((x) => x.customerId === c.id && x.unreadCustomer).length : 0,
    });
  });

  api.get('/support/tickets', (req, res) => res.json(D().tickets.filter((t) => t.customerId === req.customer.id).map(ticketView)));

  api.post('/support/tickets', (req, res) => {
    const b = req.body || {};
    if (text(b.text, 3000).length < 10) return bad(res, 400, 'Please describe the problem (at least 10 characters)');
    const open = D().tickets.filter((t) => t.customerId === req.customer.id && ['open', 'awaiting_customer'].includes(t.status));
    if (open.length >= 5) return bad(res, 429, 'You already have 5 open tickets. Please reply on an existing ticket.');
    const t = createTicket(req.customer, { subject: b.subject, category: b.category, orderId: b.orderId, body: b.text, photos: Array.isArray(b.photos) ? b.photos.map((p) => text(p, 300)) : [] });
    save();
    res.json(ticketView(t));
  });

  const myTicket = (req, res) => {
    const t = find('tickets', req.params.id);
    if (!t || t.customerId !== req.customer.id) {
      bad(res, 404, 'Ticket not found');
      return null;
    }
    return t;
  };

  api.get('/support/tickets/:id', (req, res) => {
    const t = myTicket(req, res);
    if (!t) return;
    if (t.unreadCustomer) {
      t.unreadCustomer = false;
      save();
    }
    res.json(ticketView(t));
  });

  api.post('/support/tickets/:id/messages', (req, res) => {
    const t = myTicket(req, res);
    if (!t) return;
    const body = text(req.body?.text, 3000);
    const photos = Array.isArray(req.body?.photos) ? req.body.photos.map((p) => text(p, 300)).slice(0, 6) : [];
    if (!body && !photos.length) return bad(res, 400, 'Type a message');
    if (t.status === 'closed') return bad(res, 409, 'This ticket is closed. Please open a new one.');
    t.messages.push(msg('customer', body, { author: req.customer.name, photos }));
    if (t.status !== 'open') {
      if (t.status === 'resolved') t.messages.push(msg('system', 'Ticket reopened by customer'));
      t.status = 'open';
    }
    t.unreadAdmin = true;
    t.updatedAt = now();
    save();
    res.json(ticketView(t));
  });

  api.post('/support/tickets/:id/close', (req, res) => {
    const t = myTicket(req, res);
    if (!t) return;
    const stars = Math.round(Number(req.body?.rating) || 0);
    t.status = 'closed';
    if (stars >= 1 && stars <= 5) t.rating = { stars, comment: text(req.body?.comment, 500), at: now() };
    t.messages.push(msg('system', `Ticket closed by customer${t.rating ? ` • rated ${stars}★` : ''}`));
    t.updatedAt = now();
    t.unreadAdmin = true;
    save();
    res.json(ticketView(t));
  });

  // ------------------------------------------------------------- chat --
  const chatView = (c) => (c ? { ...c, customerId: undefined, agentsOnline: agentsOnline(), ai: !!claude } : null);
  const activeChat = (cid) => D().chats.find((x) => x.customerId === cid && x.mode !== 'closed') || null;

  function greeting(c) {
    const first = String(c.name || '').split(' ')[0] || 'there';
    return msg('ai', `Hi ${first}! 👋 I'm the GAMEX Assistant. I can track orders, explain returns, refunds and warranty, or connect you to our support team. How can I help?`, {
      suggestions: ['Where is my order?', 'Return or refund', 'Talk to an agent'],
    });
  }

  api.get('/support/chat', (req, res) => {
    const x = activeChat(req.customer.id);
    if (x?.unreadCustomer) {
      x.unreadCustomer = false;
      save();
    }
    res.json(chatView(x));
  });

  api.post('/support/chat/start', (req, res) => {
    let x = activeChat(req.customer.id);
    if (!x) {
      x = { id: uid('CH'), customerId: req.customer.id, name: req.customer.name, phone: req.customer.phone || '', mode: 'ai', messages: [greeting(req.customer)], createdAt: now(), updatedAt: now(), ticketId: null, agent: null, unreadAdmin: false, unreadCustomer: false, rating: null };
      D().chats.unshift(x);
      D().chats = D().chats.slice(0, 5000);
      save();
    }
    res.json(chatView(x));
  });

  api.post('/support/chat/messages', async (req, res) => {
    const c = req.customer;
    const x = activeChat(c.id);
    if (!x) return bad(res, 404, 'Start a chat first');
    const body = text(req.body?.text, 1000);
    if (!body) return bad(res, 400, 'Type a message');
    x.messages.push(msg('customer', body));
    x.updatedAt = now();
    if (x.mode !== 'ai') {
      // A human is (or will be) handling this chat.
      x.unreadAdmin = true;
      save();
      return res.json(chatView(x));
    }
    if (/\b(agent|human|person|executive|call me|talk to (someone|support))\b/i.test(body)) {
      handoff(c, x, 'Customer asked for an agent');
      save();
      return res.json(chatView(x));
    }
    save();
    let out;
    try {
      out = claude ? await askClaude(c, x) : ruleBased(c, body);
    } catch (e) {
      console.warn('[support] assistant failed:', e?.status || '', e?.message);
      out = ruleBased(c, body);
    }
    x.messages.push(msg('ai', out.reply, { suggestions: (out.suggestions || []).slice(0, 3) }));
    x.topic = out.topic || x.topic;
    if (out.handoff) handoff(c, x, `Assistant handed over (${out.topic || 'other'})`);
    x.updatedAt = now();
    save();
    res.json(chatView(x));
  });

  api.post('/support/chat/agent', (req, res) => {
    const x = activeChat(req.customer.id);
    if (!x) return bad(res, 404, 'Start a chat first');
    if (x.mode === 'ai') handoff(req.customer, x, 'Customer asked for an agent');
    save();
    res.json(chatView(x));
  });

  api.post('/support/chat/end', (req, res) => {
    const x = activeChat(req.customer.id);
    if (!x) return res.json(null);
    const stars = Math.round(Number(req.body?.rating) || 0);
    if (stars >= 1 && stars <= 5) x.rating = { stars, at: now() };
    x.mode = 'closed';
    x.messages.push(msg('system', 'Chat ended'));
    x.updatedAt = now();
    save();
    res.json(chatView(x));
  });

  function handoff(c, x, reason) {
    x.mode = 'waiting';
    x.unreadAdmin = true;
    const transcript = x.messages
      .filter((m) => m.from !== 'system')
      .slice(-12)
      .map((m) => `${m.from === 'customer' ? c.name : 'Assistant'}: ${m.text}`)
      .join('\n');
    if (!x.ticketId) {
      const t = createTicket(c, { subject: `Live chat: ${x.messages.filter((m) => m.from === 'customer').slice(-1)[0]?.text?.slice(0, 80) || 'Help needed'}`, category: topicToCategory(x.topic), body: transcript || 'Customer requested an agent from live chat', source: 'chat' });
      x.ticketId = t.id;
    }
    x.messages.push(
      msg(
        'system',
        agentsOnline()
          ? 'Connecting you to a GAMEX support agent — usually under 3 minutes. You can keep typing here.'
          : `Our agents are available 9 AM – 9 PM. We've created ticket ${x.ticketId} and will reply here and by notification as soon as we're back.`,
      ),
    );
    log(`Live chat ${x.id} handed to agents • ${reason}`, 'support');
  }

  const topicToCategory = (t) =>
    ({ orders: 'Order & delivery', returns: 'Return & refund', refunds: 'Return & refund', payments: 'Payment', warranty: 'Warranty & repair', repairs: 'Warranty & repair', quality: 'Product quality', sell: 'Sell / exchange', account: 'Account' })[t] || 'Other';

  // -------------------------------------------------------- assistant --
  function contextFor(c) {
    const orders = ordersOf(c.id).map((o) => {
      const parts = [`${o.id}: ${o.item} (${o.variant || ''}) ${money(o.price)}, ${o.payment}, ${stageLabel[o.stage] || o.stage}, placed ${o.placedAt.slice(0, 10)}`];
      if (o.awb) parts.push(`courier ${o.courier || ''} AWB ${o.awb}`);
      if (o.deliveredAt) parts.push(`delivered ${o.deliveredAt.slice(0, 10)}, return window ${o.returnDays ?? 7} days`);
      if (o.returnRequest) parts.push(`return ${o.returnRequest.status}`);
      if (o.refund) parts.push(`refund ${money(o.refund.amount)} ${o.refund.status}`);
      if (o.cancelReason) parts.push(`cancel reason: ${o.cancelReason}`);
      return `- ${parts.join('; ')}`;
    });
    const tickets = D()
      .tickets.filter((t) => t.customerId === c.id && t.status !== 'closed')
      .slice(0, 5)
      .map((t) => `- ${t.id} "${t.subject}" (${t.status})`);
    return [
      `Customer: ${c.name}, phone ${c.phone || 'n/a'}, member since ${String(c.createdAt || '').slice(0, 10)}.`,
      `Today: ${now().slice(0, 10)}. Human agents ${agentsOnline() ? 'are online now' : 'are offline (back at 9 AM IST)'}.`,
      orders.length ? `Recent orders:\n${orders.join('\n')}` : 'No orders yet.',
      tickets.length ? `Open support tickets:\n${tickets.join('\n')}` : 'No open tickets.',
    ].join('\n\n');
  }

  function policyPrompt() {
    const s = D().settings;
    const articles = D()
      .helpArticles.map((a) => `### ${a.title}\n${a.body}`)
      .join('\n\n');
    return `You are the GAMEX Assistant, the live-chat support agent of GAMEX — an Indian marketplace for certified second-hand phones, tablets and watches.

How to answer:
- Be warm, short and concrete: 1–4 sentences, plain text, no markdown headings. Use ₹ and Indian formats. Reply in the customer's language (English, Hindi, Bengali or Hinglish/Banglish as they write).
- Use the customer's order data below to answer about their orders: quote the order ID, status, courier and refund status exactly. Never invent tracking numbers, dates, amounts or policies that are not given here.
- You cannot change orders, issue refunds, cancel, or edit accounts yourself. Tell the customer where to do it in the app (Orders › Cancel / Return / Warranty) or hand over to an agent.
- Set handoff=true when: the customer is upset or reports fraud, a wrong/damaged/fake product, a payment taken without an order, a refund that is late versus the policy, anything needing a manual action, or you cannot solve it after one attempt. Then tell them an agent will take over.
- suggestions: up to 3 very short follow-up taps the customer is likely to need next (e.g. "Track order GMX123", "Return policy", "Talk to an agent"). Empty if none fit.
- Never ask for card numbers, CVV, OTP or passwords. Delivery OTP is only for the delivery person at the door.

Store facts: free delivery above ${money(s.freeShippingAbove)} (else ${money(s.shippingFee)}), COD fee ${money(s.codFee)}, first-order COD limit ${money(s.codLimitNew ?? 15000)}, support phone ${s.supportPhone}, email ${s.supportEmail}, agents 9 AM – 9 PM IST every day.

Help Center articles (the official policy):
${articles}`;
  }

  async function askClaude(c, x) {
    const history = x.messages.filter((m) => m.from === 'customer' || m.from === 'ai' || m.from === 'agent').slice(-24);
    const messages = [];
    for (const m of history) {
      const role = m.from === 'customer' ? 'user' : 'assistant';
      const content = m.from === 'agent' ? `[GAMEX agent ${m.author || ''}]: ${m.text}` : m.text;
      if (messages.length && messages[messages.length - 1].role === role) messages[messages.length - 1].content += `\n\n${content}`;
      else messages.push({ role, content });
    }
    while (messages.length && messages[0].role !== 'user') messages.shift();
    const r = await claude.beta.messages.create(
      {
        model: MODEL,
        max_tokens: 4000,
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        output_config: { effort: 'low', format: { type: 'json_schema', schema: REPLY_SCHEMA } },
        system: [
          { type: 'text', text: policyPrompt(), cache_control: { type: 'ephemeral' } },
          { type: 'text', text: `Customer context (private, for answering only):\n${contextFor(c)}` },
        ],
        messages,
      },
      { timeout: 45_000 },
    );
    if (r.stop_reason === 'refusal') {
      return { reply: "I'm not able to help with that here, so I'm connecting you to our support team.", handoff: true, suggestions: [], topic: 'other' };
    }
    const raw = r.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
    const j = JSON.parse(raw);
    return { reply: text(j.reply, 1500) || 'Sorry, could you rephrase that?', handoff: !!j.handoff, suggestions: Array.isArray(j.suggestions) ? j.suggestions.map((s) => text(s, 40)).filter(Boolean) : [], topic: j.topic };
  }

  /** Offline assistant: keyword intents + the customer's own orders. */
  function ruleBased(c, body) {
    const q = body.toLowerCase();
    const orders = ordersOf(c.id);
    const art = (id) => D().helpArticles.find((a) => a.id === id)?.body || '';
    const has = (...w) => w.some((x) => q.includes(x));
    if (has('where', 'track', 'status', 'deliver', 'kobe', 'kab', 'order')) {
      if (!orders.length) return { reply: "I couldn't find any orders on your account yet. If you ordered with another number, please log in with it — or tell me the order ID.", handoff: false, suggestions: ['Talk to an agent'], topic: 'orders' };
      const lines = orders.slice(0, 3).map((o) => `• ${o.id} — ${o.item}: ${stageLabel[o.stage] || o.stage}${o.awb ? ` (${o.courier || 'courier'} AWB ${o.awb})` : ''}`);
      return { reply: `Here are your latest orders:\n${lines.join('\n')}\nOpen Orders for live tracking.`, handoff: false, suggestions: ['Cancel an order', 'Return or refund', 'Talk to an agent'], topic: 'orders' };
    }
    if (has('refund', 'money back', 'taka', 'paisa')) {
      const r = orders.find((o) => o.refund);
      const mine = r ? ` Your refund for ${r.id} (${money(r.refund.amount)}) is ${r.refund.status}.` : '';
      return { reply: art('h4') + mine, handoff: false, suggestions: ['Return policy', 'Talk to an agent'], topic: 'refunds' };
    }
    if (has('return', 'replace', 'exchange product')) return { reply: art('h3'), handoff: false, suggestions: ['When will I get my refund?', 'Talk to an agent'], topic: 'returns' };
    if (has('cancel')) return { reply: art('h2'), handoff: false, suggestions: ['Where is my order?'], topic: 'orders' };
    if (has('warranty', 'repair', 'not working', 'problem', 'issue', 'kharap', 'kharab')) return { reply: art('h5'), handoff: false, suggestions: ['Book a repair', 'Talk to an agent'], topic: 'warranty' };
    if (has('cod', 'cash', 'pay', 'upi', 'card', 'emi')) return { reply: art('h6'), handoff: false, suggestions: ['EMI options'], topic: 'payments' };
    if (has('sell', 'trade', 'exchange')) return { reply: art('h9'), handoff: false, suggestions: [], topic: 'sell' };
    if (has('fake', 'fraud', 'damaged', 'broken', 'wrong', 'scam', 'complain')) return { reply: "I'm sorry about this. I'm connecting you to a support agent right away so we can fix it.", handoff: true, suggestions: [], topic: 'quality' };
    if (has('hi', 'hello', 'hey', 'namaste', 'thanks', 'thank')) return { reply: 'Happy to help! Ask me about your orders, returns, refunds, warranty or payments.', handoff: false, suggestions: ['Where is my order?', 'Return or refund', 'Talk to an agent'], topic: 'other' };
    return { reply: "I'm not sure I understood. I can help with orders, returns, refunds, warranty and payments — or connect you to an agent.", handoff: false, suggestions: ['Where is my order?', 'Return or refund', 'Talk to an agent'], topic: 'other' };
  }

  // ------------------------------------------------------------ admin --
  admin.post('/support/tickets/:id/reply', (req, res) => {
    const t = find('tickets', req.params.id);
    if (!t) return bad(res, 404, 'Not found');
    const body = text(req.body?.text, 3000);
    if (!body) return bad(res, 400, 'Type a reply');
    const agent = text(req.body?.agent, 40) || 'GAMEX Support';
    t.messages.push(msg('agent', body, { author: agent }));
    t.status = req.body?.status && ['open', 'awaiting_customer', 'resolved', 'closed'].includes(req.body.status) ? req.body.status : 'awaiting_customer';
    t.assignee ??= agent;
    t.unreadCustomer = true;
    t.unreadAdmin = false;
    t.firstResponseAt ??= now();
    t.updatedAt = now();
    notifyCustomer(t.customerId, `Reply on ticket ${t.id} 💬`, body.slice(0, 140), 'support', `/support/ticket/${t.id}`);
    save();
    res.json(t);
  });

  admin.patch('/support/tickets/:id', (req, res) => {
    const t = find('tickets', req.params.id);
    if (!t) return bad(res, 404, 'Not found');
    const { status, priority, assignee, read } = req.body || {};
    if (status && ['open', 'awaiting_customer', 'resolved', 'closed'].includes(status) && status !== t.status) {
      t.status = status;
      t.messages.push(msg('system', `Status changed to ${status.replace('_', ' ')}`));
      if (status === 'resolved') {
        t.unreadCustomer = true;
        notifyCustomer(t.customerId, `Ticket ${t.id} resolved ✅`, 'Tap to rate our support or reopen if you still need help.', 'support', `/support/ticket/${t.id}`);
      }
    }
    if (priority && ['normal', 'high', 'urgent'].includes(priority)) t.priority = priority;
    if (assignee !== undefined) t.assignee = text(assignee, 40) || null;
    if (read) t.unreadAdmin = false;
    t.updatedAt = now();
    save();
    res.json(t);
  });

  admin.post('/support/chats/:id/reply', (req, res) => {
    const x = find('chats', req.params.id);
    if (!x) return bad(res, 404, 'Not found');
    if (x.mode === 'closed') return bad(res, 409, 'This chat has ended');
    const body = text(req.body?.text, 2000);
    if (!body) return bad(res, 400, 'Type a reply');
    const agent = text(req.body?.agent, 40) || 'GAMEX Support';
    if (x.mode !== 'agent') x.messages.push(msg('system', `${agent} joined the chat`));
    x.mode = 'agent';
    x.agent = agent;
    x.messages.push(msg('agent', body, { author: agent }));
    x.unreadCustomer = true;
    x.unreadAdmin = false;
    x.updatedAt = now();
    notifyCustomer(x.customerId, `${agent} replied 💬`, body.slice(0, 140), 'support', '/support/chat');
    save();
    res.json(x);
  });

  admin.post('/support/chats/:id/close', (req, res) => {
    const x = find('chats', req.params.id);
    if (!x) return bad(res, 404, 'Not found');
    x.mode = 'closed';
    x.messages.push(msg('system', 'Chat closed by GAMEX Support'));
    x.unreadAdmin = false;
    x.updatedAt = now();
    const t = x.ticketId ? find('tickets', x.ticketId) : null;
    if (t && !['resolved', 'closed'].includes(t.status)) {
      t.status = 'resolved';
      t.messages.push(msg('system', 'Resolved in live chat'));
      t.updatedAt = now();
    }
    save();
    res.json(x);
  });

  admin.post('/support/chats/:id/read', (req, res) => {
    const x = find('chats', req.params.id);
    if (!x) return bad(res, 404, 'Not found');
    x.unreadAdmin = false;
    save();
    res.json(x);
  });

  return { migrate, aiEnabled: () => !!claude };
}
