import { useEffect, useState } from 'react';
import {
  BadgePercent,
  BellRing,
  CheckCircle2,
  Flame,
  Gift,
  Handshake,
  Landmark,
  Plus,
  Repeat2,
  Save,
  Trash2,
  Truck,
  Wallet,
  XCircle,
} from 'lucide-react';
import { BankOffer, Promo, TradeIn, TradeInStatus, act, ago, fmtDateTime, inr, useDB } from '../store';
import { Badge, Button, Card, Empty, Field, PageHeader, Tabs, Toggle, cx, inputCls, toast } from '../ui';
import type { Tone } from '../ui';

const tradeTone: Record<TradeInStatus, Tone> = {
  quoted: 'slate',
  awaitingPickup: 'amber',
  pickedUp: 'blue',
  verified: 'green',
  adjusted: 'violet',
  rejected: 'red',
  cancelled: 'red',
};
const tradeLabel: Record<TradeInStatus, string> = {
  quoted: 'Quoted',
  awaitingPickup: 'Pickup at delivery',
  pickedUp: 'Collected',
  verified: 'Verified',
  adjusted: 'Value adjusted',
  rejected: 'Rejected',
  cancelled: 'Cancelled',
};
const offerTone: Record<string, Tone> = {
  pending: 'blue',
  countered: 'amber',
  accepted: 'green',
  used: 'green',
  rejected: 'red',
  expired: 'slate',
  withdrawn: 'slate',
};

/** datetime-local value <-> ISO */
const toLocal = (iso: string) => {
  const d = new Date(iso);
  return new Date(d.getTime() - d.getTimezoneOffset() * 6e4).toISOString().slice(0, 16);
};
const fromLocal = (v: string) => new Date(v).toISOString();

export default function Growth() {
  const db = useDB((d) => d);
  const [tab, setTab] = useState<'tradein' | 'offers' | 'promo' | 'wallet'>('tradein');
  const promo = db.promo;
  const store = (id: string) => db.sellers.find((s) => s.id === id)?.storeName ?? id;
  const customer = (id: string) => db.customers.find((c) => c.id === id)?.name ?? id;
  const title = (id: string) => {
    const l = db.listings.find((x) => x.id === id);
    return l ? `${l.brand} ${l.model}` : id;
  };

  const openTrades = db.tradeIns.filter((t) => ['awaitingPickup', 'pickedUp'].includes(t.status));
  const openOffers = db.offers.filter((o) => ['pending', 'countered'].includes(o.status));
  const closed = db.offers.filter((o) => ['accepted', 'used'].includes(o.status)).length;
  const decided = db.offers.filter((o) => !['pending', 'countered'].includes(o.status)).length;
  const walletOut = db.walletTx.filter((x) => x.status === 'available' && x.amount > 0).reduce((s, x) => s + x.amount, 0);
  const activeAlerts = db.alerts.filter((a) => a.status === 'active').length;

  return (
    <>
      <PageHeader
        title="Growth & Payments"
        subtitle="Trade-ins, Make an Offer, festival sale, bank offers, wallet & referrals, price alerts."
      />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Trade-ins to collect', openTrades.length, 'from-emerald-500 to-teal-500', Repeat2],
          ['Open offers', `${openOffers.length} • ${decided ? Math.round((closed * 100) / decided) : 0}% closed`, 'from-amber-500 to-orange-500', Handshake],
          ['Wallet credited', inr(walletOut), 'from-brand to-violet', Wallet],
          ['Active price alerts', `${activeAlerts} • ${db.pushTokens.length} devices`, 'from-rose-500 to-pink-500', BellRing],
        ].map(([l, v, g, I]) => {
          const Icon = I as typeof Wallet;
          return (
            <Card key={l as string} className="flex items-center gap-4">
              <div className={cx('grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br text-white', g as string)}>
                <Icon size={22} />
              </div>
              <div className="min-w-0">
                <p className="text-sm text-muted">{l as string}</p>
                <p className="truncate text-xl font-extrabold text-ink">{v as string}</p>
              </div>
            </Card>
          );
        })}
      </div>
      <div className="mb-4">
        <Tabs
          value={tab}
          onChange={setTab}
          items={[
            { id: 'tradein', label: 'Trade-ins', count: db.tradeIns.filter((t) => t.status !== 'quoted').length },
            { id: 'offers', label: 'Offers', count: db.offers.length },
            { id: 'promo', label: 'Sale & bank offers' },
            { id: 'wallet', label: 'Wallet & referrals', count: db.walletTx.length },
          ]}
        />
      </div>

      {tab === 'tradein' && <TradeIns items={db.tradeIns.filter((t) => t.status !== 'quoted')} quotes={db.tradeIns.length} customer={customer} />}

      {tab === 'offers' &&
        (db.offers.length === 0 ? (
          <Card>
            <Empty icon={Handshake} title="No offers yet" text="Buyers make offers from the product page. Sellers reply in the seller app." />
          </Card>
        ) : (
          <Card pad={false} className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-muted">
                <tr>
                  {['Phone', 'Buyer', 'Seller', 'Listed', 'Offer', 'Counter / deal', 'Status', 'When'].map((h) => (
                    <th key={h} className="px-4 py-3 font-semibold">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {db.offers.map((o) => (
                  <tr key={o.id} className="border-t border-slate-100">
                    <td className="px-4 py-3 font-semibold text-ink">{title(o.listingId)}</td>
                    <td className="px-4 py-3">{o.customerName}</td>
                    <td className="px-4 py-3">{store(o.sellerId)}</td>
                    <td className="px-4 py-3">{inr(o.listPrice)}</td>
                    <td className="px-4 py-3 font-bold">
                      {inr(o.amount)} <span className="text-xs font-normal text-muted">(-{Math.round((1 - o.amount / o.listPrice) * 100)}%)</span>
                    </td>
                    <td className="px-4 py-3">{o.dealPrice ? inr(o.dealPrice) : o.counter ? inr(o.counter) : '—'}</td>
                    <td className="px-4 py-3">
                      <Badge tone={offerTone[o.status]} dot>
                        {o.status}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-muted">{ago(o.createdAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        ))}

      {tab === 'promo' && promo && <PromoEditor promo={promo} />}

      {tab === 'wallet' && promo && <WalletTab customer={customer} />}
    </>
  );
}

function TradeIns({ items, quotes, customer }: { items: TradeIn[]; quotes: number; customer: (id: string) => string }) {
  const run = (t: TradeIn, action: string) => {
    let body: Record<string, unknown> = {};
    if (action === 'adjust') {
      const v = window.prompt(`Final value for ${t.model} (quoted ${inr(t.amount)}):`, String(Math.round(t.amount * 0.85)));
      if (!v) return;
      const note = window.prompt('What was different? (shown to the buyer)', 'Deep scratches on the screen') ?? '';
      body = { finalAmount: Number(v), note };
    }
    if (action === 'reject') {
      const note = window.prompt('Reason (shown to the buyer):', 'Phone is iCloud locked');
      if (!note) return;
      body = { note };
    }
    act('POST', `/trade-ins/${t.id}/${action}`, body)
      .then(() => toast('Trade-in updated'))
      .catch((e: Error) => toast(e.message));
  };
  if (!items.length) {
    return (
      <Card>
        <Empty icon={Repeat2} title="No trade-ins on orders yet" text={`${quotes} instant quote(s) given. Trade-ins appear here once used on an order.`} />
      </Card>
    );
  }
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {items.map((t) => (
        <Card key={t.id}>
          <div className="flex items-start justify-between gap-2">
            <div>
              <p className="font-bold text-ink">
                {t.brand} {t.model} • {t.storage}
              </p>
              <p className="text-sm text-muted">
                {t.id} • {customer(t.customerId)} • order {t.orderId}
              </p>
            </div>
            <Badge tone={tradeTone[t.status]} dot>
              {tradeLabel[t.status]}
            </Badge>
          </div>
          <div className="mt-3 flex items-end justify-between rounded-xl bg-emerald-50 px-3 py-2">
            <div className="text-sm text-emerald-900">
              {Object.values(t.answers).join(' • ') || 'Working, flawless'}
              {t.faults.length > 0 && <p className="text-rose-600">Faults: {t.faults.join(', ')}</p>}
              {t.extras.length > 0 && <p className="text-emerald-700">With: {t.extras.join(', ')}</p>}
            </div>
            <div className="text-right">
              <p className="text-xs text-emerald-700">{t.finalAmount !== undefined && t.finalAmount !== t.amount ? 'Final' : 'Quoted'}</p>
              <p className="text-xl font-extrabold text-emerald-700">{inr(t.finalAmount ?? t.amount)}</p>
            </div>
          </div>
          {t.note && <p className="mt-2 text-sm text-muted">Note: {t.note}</p>}
          <ul className="mt-3 space-y-1 text-xs text-muted">
            {[...t.events].reverse().slice(0, 4).map((e, i) => (
              <li key={i} className="flex justify-between gap-2">
                <span>{e.l}</span>
                <span className="shrink-0 text-slate-400">{fmtDateTime(e.a)}</span>
              </li>
            ))}
          </ul>
          <div className="mt-3 flex flex-wrap gap-2">
            {t.status === 'awaitingPickup' && (
              <Button size="sm" icon={Truck} onClick={() => run(t, 'pickup')}>
                Mark collected
              </Button>
            )}
            {t.status === 'pickedUp' && (
              <>
                <Button size="sm" variant="success" icon={CheckCircle2} onClick={() => run(t, 'verify')}>
                  Verify • confirm value
                </Button>
                <Button size="sm" variant="secondary" icon={BadgePercent} onClick={() => run(t, 'adjust')}>
                  Adjust value
                </Button>
              </>
            )}
            {['awaitingPickup', 'pickedUp'].includes(t.status) && (
              <Button size="sm" variant="danger" icon={XCircle} onClick={() => run(t, 'reject')}>
                Reject
              </Button>
            )}
          </div>
        </Card>
      ))}
    </div>
  );
}

function PromoEditor({ promo }: { promo: Promo }) {
  const [sale, setSale] = useState(promo.sale);
  const [p, setP] = useState({
    referrerBonus: promo.referral.referrerBonus,
    friendBonus: promo.referral.friendBonus,
    cashbackPercent: Math.round(promo.cashbackRate * 1000) / 10,
    cashbackCap: promo.cashbackCap,
    walletMaxPercent: promo.walletMaxPercent,
    exchangeBonus: promo.exchangeBonus,
  });
  const [nb, setNb] = useState<Partial<BankOffer>>({ bank: '', kind: 'card', text: '', percent: 10, flat: 0, maxOff: 2000, minOrder: 15000 });
  useEffect(() => setSale(promo.sale), [promo.sale]);

  const saveSale = () =>
    act('PUT', '/promo', { sale })
      .then(() => toast('Festival sale saved - live in the shop app'))
      .catch((e: Error) => toast(e.message));
  const saveRewards = () =>
    act('PUT', '/promo', {
      referral: { referrerBonus: Number(p.referrerBonus), friendBonus: Number(p.friendBonus) },
      cashbackRate: Number(p.cashbackPercent) / 100,
      cashbackCap: Number(p.cashbackCap),
      walletMaxPercent: Number(p.walletMaxPercent),
      exchangeBonus: Number(p.exchangeBonus),
    })
      .then(() => toast('Rewards saved'))
      .catch((e: Error) => toast(e.message));
  const now = Date.now();
  const live = sale.active && Date.parse(sale.startsAt) < now && Date.parse(sale.endsAt) > now;

  return (
    <div className="grid gap-5 xl:grid-cols-2">
      <Card>
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Flame className="text-rose-500" size={20} />
            <h3 className="font-bold text-ink">Festival flash sale</h3>
            <Badge tone={live ? 'green' : 'slate'} dot>
              {live ? 'Live' : sale.active ? 'Scheduled' : 'Off'}
            </Badge>
          </div>
          <Toggle checked={sale.active} onChange={(v) => setSale({ ...sale, active: v })} />
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Title">
            <input className={inputCls} value={sale.title} onChange={(e) => setSale({ ...sale, title: e.target.value })} />
          </Field>
          <Field label="Subtitle">
            <input className={inputCls} value={sale.subtitle} onChange={(e) => setSale({ ...sale, subtitle: e.target.value })} />
          </Field>
          <Field label="Starts">
            <input type="datetime-local" className={inputCls} value={toLocal(sale.startsAt)} onChange={(e) => setSale({ ...sale, startsAt: fromLocal(e.target.value) })} />
          </Field>
          <Field label="Ends" hint="Countdown shown on the app home page">
            <input type="datetime-local" className={inputCls} value={toLocal(sale.endsAt)} onChange={(e) => setSale({ ...sale, endsAt: fromLocal(e.target.value) })} />
          </Field>
          <Field label="Extra off on flash deals (%)">
            <input type="number" className={inputCls} value={sale.extraOffPercent} onChange={(e) => setSale({ ...sale, extraOffPercent: Number(e.target.value) })} />
          </Field>
          <Field label="Max extra off (₹)">
            <input type="number" className={inputCls} value={sale.maxExtraOff} onChange={(e) => setSale({ ...sale, maxExtraOff: Number(e.target.value) })} />
          </Field>
        </div>
        <div className="mt-4 flex justify-end">
          <Button icon={Save} onClick={saveSale}>
            Save sale
          </Button>
        </div>
      </Card>

      <Card>
        <div className="mb-4 flex items-center gap-2">
          <Gift className="text-violet" size={20} />
          <h3 className="font-bold text-ink">Rewards, wallet & exchange</h3>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Referrer reward (₹)" hint="Unlocks when the friend's first order is delivered">
            <input type="number" className={inputCls} value={p.referrerBonus} onChange={(e) => setP({ ...p, referrerBonus: Number(e.target.value) })} />
          </Field>
          <Field label="Friend welcome bonus (₹)">
            <input type="number" className={inputCls} value={p.friendBonus} onChange={(e) => setP({ ...p, friendBonus: Number(e.target.value) })} />
          </Field>
          <Field label="Cashback (%)">
            <input type="number" step="0.5" className={inputCls} value={p.cashbackPercent} onChange={(e) => setP({ ...p, cashbackPercent: Number(e.target.value) })} />
          </Field>
          <Field label="Cashback cap per order (₹)">
            <input type="number" className={inputCls} value={p.cashbackCap} onChange={(e) => setP({ ...p, cashbackCap: Number(e.target.value) })} />
          </Field>
          <Field label="Wallet can pay up to (% of order)">
            <input type="number" className={inputCls} value={p.walletMaxPercent} onChange={(e) => setP({ ...p, walletMaxPercent: Number(e.target.value) })} />
          </Field>
          <Field label="Exchange bonus (₹)" hint="Added to trade-ins on phones above ₹30,000">
            <input type="number" className={inputCls} value={p.exchangeBonus} onChange={(e) => setP({ ...p, exchangeBonus: Number(e.target.value) })} />
          </Field>
        </div>
        <div className="mt-4 flex justify-end">
          <Button icon={Save} onClick={saveRewards}>
            Save rewards
          </Button>
        </div>
      </Card>

      <Card className="xl:col-span-2">
        <div className="mb-4 flex items-center gap-2">
          <Landmark className="text-brand" size={20} />
          <h3 className="font-bold text-ink">Bank offers</h3>
          <span className="text-sm text-muted">Applied automatically at checkout when the buyer pays with that bank</span>
        </div>
        <div className="space-y-2">
          {promo.bankOffers.map((b) => (
            <div key={b.id} className="flex flex-wrap items-center gap-3 rounded-xl border border-slate-100 px-3 py-2">
              <Toggle checked={b.active} onChange={(v) => act('PATCH', `/bank-offers/${b.id}`, { active: v }).catch((e: Error) => toast(e.message))} />
              <div className="min-w-0 flex-1">
                <p className="font-semibold text-ink">
                  {b.bank} <Badge tone="slate">{b.kind}</Badge>
                </p>
                <p className="text-sm text-muted">
                  {b.text} • {b.flat ? `flat ${inr(b.flat)}` : `${b.percent}% up to ${inr(b.maxOff)}`} • min {inr(b.minOrder)}
                </p>
              </div>
              <Button size="sm" variant="danger" icon={Trash2} onClick={() => window.confirm(`Delete ${b.bank} offer?`) && act('DELETE', `/bank-offers/${b.id}`).then(() => toast('Deleted'))}>
                Delete
              </Button>
            </div>
          ))}
        </div>
        <div className="mt-4 grid gap-3 rounded-xl bg-slate-50 p-3 sm:grid-cols-3 lg:grid-cols-7">
          <input className={inputCls} placeholder="Bank (e.g. HDFC Bank)" value={nb.bank} onChange={(e) => setNb({ ...nb, bank: e.target.value })} />
          <select className={inputCls} value={nb.kind} onChange={(e) => setNb({ ...nb, kind: e.target.value as BankOffer['kind'] })}>
            <option value="card">Card</option>
            <option value="emi">EMI</option>
            <option value="any">Card & EMI</option>
          </select>
          <input className={cx(inputCls, 'lg:col-span-2')} placeholder="Text shown to buyers" value={nb.text} onChange={(e) => setNb({ ...nb, text: e.target.value })} />
          <input type="number" className={inputCls} placeholder="%" value={nb.percent} onChange={(e) => setNb({ ...nb, percent: Number(e.target.value) })} />
          <input type="number" className={inputCls} placeholder="Max off ₹" value={nb.maxOff} onChange={(e) => setNb({ ...nb, maxOff: Number(e.target.value) })} />
          <Button
            icon={Plus}
            onClick={() =>
              act('POST', '/bank-offers', nb)
                .then(() => {
                  toast('Bank offer added');
                  setNb({ ...nb, bank: '', text: '' });
                })
                .catch((e: Error) => toast(e.message))
            }
          >
            Add
          </Button>
        </div>
      </Card>
    </div>
  );
}

function WalletTab({ customer }: { customer: (id: string) => string }) {
  const tx = useDB((d) => d.walletTx);
  const customers = useDB((d) => d.customers) as unknown as { id: string; name: string; referredBy?: string }[];
  const referred = customers.filter((c) => c.referredBy);
  return (
    <div className="grid gap-5 xl:grid-cols-3">
      <Card className="xl:col-span-2" pad={false}>
        <div className="border-b border-slate-100 px-5 py-3 font-bold text-ink">Wallet transactions</div>
        {tx.length === 0 ? (
          <Empty icon={Wallet} title="No wallet activity yet" text="Cashback, referral rewards and wallet payments appear here." />
        ) : (
          <table className="w-full text-sm">
            <tbody>
              {tx.slice(0, 100).map((x) => (
                <tr key={x.id} className="border-t border-slate-100">
                  <td className="px-5 py-2.5">
                    <p className="font-semibold text-ink">{customer(x.customerId)}</p>
                    <p className="text-xs text-muted">{x.label}</p>
                  </td>
                  <td className="px-3 py-2.5">
                    <Badge tone={x.status === 'available' ? 'green' : x.status === 'pending' ? 'amber' : 'slate'}>{x.status}</Badge>
                  </td>
                  <td className={cx('px-5 py-2.5 text-right font-bold', x.amount < 0 ? 'text-ink' : 'text-emerald-600')}>
                    {x.amount < 0 ? '−' : '+'}
                    {inr(Math.abs(x.amount))}
                  </td>
                  <td className="px-5 py-2.5 text-right text-xs text-muted">{ago(x.at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <Card>
        <p className="mb-3 font-bold text-ink">Referrals ({referred.length})</p>
        {referred.length === 0 ? (
          <p className="text-sm text-muted">No referrals yet. Every customer gets a code like GX5CC1B4 in Wallet & Refer.</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {referred.map((c) => (
              <li key={c.id} className="flex justify-between gap-2">
                <span className="font-semibold text-ink">{c.name}</span>
                <span className="text-muted">invited by {customer(c.referredBy!)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
