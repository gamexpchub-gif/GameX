import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { ArrowRight, IndianRupee, ShieldCheck, ShoppingBag, Store, Users } from 'lucide-react';
import { ago, inr, inrShort, isRevenue, title, useDB } from '../store';
import { Badge, Card, PageHeader, Stat, Tabs } from '../ui';
import { orderLabel, orderTone } from '../status';

const DAY = 864e5;
const COLORS = ['#1F5BFF', '#6A3DF5', '#22C55E', '#F59E0B', '#EC4899', '#06B6D4', '#94A3B8', '#0B1230'];

export default function Dashboard() {
  const orders = useDB((d) => d.orders);
  const listings = useDB((d) => d.listings);
  const sellers = useDB((d) => d.sellers);
  const customers = useDB((d) => d.customers);
  const activity = useDB((d) => d.activity);
  const [range, setRange] = useState<'7' | '30'>('30');

  const s = useMemo(() => {
    const now = Date.now();
    const inWin = (iso: string, a: number, b: number) => {
      const t = now - new Date(iso).getTime();
      return t >= a * DAY && t < b * DAY;
    };
    const rev = (a: number, b: number) => orders.filter((o) => isRevenue(o) && inWin(o.placedAt, a, b)).reduce((x, o) => x + o.price, 0);
    const cnt = (a: number, b: number) => orders.filter((o) => inWin(o.placedAt, a, b)).length;
    const pct = (c: number, p: number) => (p ? ((c - p) / p) * 100 : c ? 100 : 0);
    const days = Number(range);
    const series = Array.from({ length: days }, (_, i) => {
      const from = days - 1 - i;
      const day = orders.filter((o) => inWin(o.placedAt, from, from + 1));
      return {
        day: new Date(now - from * DAY).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' }),
        revenue: day.filter(isRevenue).reduce((x, o) => x + o.price, 0),
      };
    });
    const by = <K extends string>(key: (o: (typeof orders)[0]) => K) =>
      Object.entries(
        orders.filter(isRevenue).reduce<Record<string, number>>((m, o) => {
          m[key(o)] = (m[key(o)] ?? 0) + o.price;
          return m;
        }, {}),
      )
        .map(([name, value]) => ({ name, value }))
        .sort((a, b) => b.value - a.value);
    return {
      rev7: rev(0, 7),
      revDelta: pct(rev(0, 7), rev(7, 14)),
      ord7: cnt(0, 7),
      ordDelta: pct(cnt(0, 7), cnt(7, 14)),
      series,
      byBrand: by((o) => o.item.split(' ')[0]),
      bySeller: by((o) => sellers.find((x) => x.id === o.sellerId)?.storeName ?? o.sellerId).slice(0, 5),
      byPay: ['UPI', 'Card', 'COD', 'Wallet', 'EMI'].map((m) => ({ name: m, value: orders.filter((o) => o.payment === m).length })),
      total: orders.filter(isRevenue).reduce((x, o) => x + o.price, 0),
    };
  }, [orders, sellers, range]);

  const qc = listings.filter((l) => l.status === 'inReview');
  const kyc = sellers.filter((x) => x.status === 'pending');
  const newOrders = orders.filter((o) => o.stage === 'newOrder');

  return (
    <>
      <PageHeader
        title="Marketplace overview"
        subtitle="Live numbers from the GAMEX Shop app, Seller app and QC desk."
        actions={<Tabs value={range} onChange={setRange} items={[{ id: '7', label: '7 days' }, { id: '30', label: '30 days' }]} />}
      />

      {(qc.length > 0 || kyc.length > 0 || newOrders.length > 0) && (
        <div className="mb-5 grid gap-3 md:grid-cols-3">
          {[
            [qc.length, 'listings waiting for QC', '/qc', 'from-amber-500 to-orange-500', ShieldCheck],
            [kyc.length, 'sellers waiting for KYC approval', '/sellers', 'from-violet to-fuchsia-500', Store],
            [newOrders.length, 'new orders not yet accepted', '/orders', 'from-brand to-cyan-500', ShoppingBag],
          ].map(([n, t, to, g, I]) => {
            const Icon = I as typeof Store;
            return (
              <Link key={t as string} to={to as string} className={`flex items-center gap-3 rounded-2xl bg-gradient-to-r ${g} p-4 text-white shadow-lg transition hover:brightness-110`}>
                <Icon size={22} />
                <p className="flex-1 text-sm">
                  <b className="text-xl">{n as number}</b> {t as string}
                </p>
                <ArrowRight size={18} />
              </Link>
            );
          })}
        </div>
      )}

      <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-4">
        <Stat label="GMV (7d)" value={inrShort(s.rev7)} delta={s.revDelta} icon={IndianRupee} gradient="bg-gradient-to-br from-brand to-violet" />
        <Stat label="Orders (7d)" value={String(s.ord7)} delta={s.ordDelta} icon={ShoppingBag} gradient="bg-gradient-to-br from-emerald-500 to-teal-500" />
        <Stat
          label="Active sellers"
          value={String(sellers.filter((x) => x.status === 'approved').length)}
          icon={Store}
          gradient="bg-gradient-to-br from-amber-500 to-orange-500"
          hint={`${listings.filter((l) => l.status === 'active').length} live listings`}
        />
        <Stat label="Customers" value={customers.length.toLocaleString('en-IN')} icon={Users} gradient="bg-gradient-to-br from-rose-500 to-pink-500" hint={`${customers.filter((c) => c.status === 'blocked').length} blocked`} />
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm font-medium text-muted">Marketplace GMV</p>
              <p className="mt-1 text-2xl font-extrabold text-ink">{inr(s.series.reduce((x, d) => x + d.revenue, 0))}</p>
            </div>
            <Badge tone="green" dot>
              Lifetime {inrShort(s.total)}
            </Badge>
          </div>
          <div className="mt-4 h-72">
            <ResponsiveContainer>
              <AreaChart data={s.series} margin={{ left: 0, right: 8, top: 8 }}>
                <defs>
                  <linearGradient id="rv" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#1F5BFF" stopOpacity={0.28} />
                    <stop offset="100%" stopColor="#1F5BFF" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid vertical={false} stroke="#EEF1F7" />
                <XAxis dataKey="day" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: '#8A93AD' }} minTickGap={24} />
                <YAxis tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: '#8A93AD' }} tickFormatter={(v) => inrShort(v)} width={64} />
                <Tooltip formatter={(v: number) => [inr(v), 'GMV']} contentStyle={{ borderRadius: 12, border: '1px solid #E3E8F5' }} />
                <Area type="monotone" dataKey="revenue" stroke="#1F5BFF" strokeWidth={2.5} fill="url(#rv)" isAnimationActive={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>
        <Card>
          <p className="text-sm font-medium text-muted">Sales by brand</p>
          <div className="relative h-52">
            <ResponsiveContainer>
              <PieChart>
                <Pie data={s.byBrand} dataKey="value" innerRadius={62} outerRadius={88} paddingAngle={2} stroke="none" isAnimationActive={false}>
                  {s.byBrand.map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(v: number) => inr(v)} contentStyle={{ borderRadius: 12 }} />
              </PieChart>
            </ResponsiveContainer>
            <div className="pointer-events-none absolute inset-0 grid place-items-center text-center">
              <div>
                <p className="text-xs text-muted">Top brand</p>
                <p className="text-lg font-extrabold text-ink">{s.byBrand[0]?.name ?? '—'}</p>
              </div>
            </div>
          </div>
          <div className="space-y-2">
            {s.byBrand.slice(0, 5).map((b, i) => (
              <div key={b.name} className="flex items-center gap-3 text-sm">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: COLORS[i] }} />
                <span className="flex-1 font-medium">{b.name}</span>
                <span className="font-semibold text-muted">{inrShort(b.value)}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card className="xl:col-span-2" pad={false}>
          <div className="flex items-center justify-between px-5 pt-5">
            <p className="font-bold text-ink">Latest orders</p>
            <Link to="/orders" className="inline-flex items-center gap-1 text-sm font-semibold text-brand">
              View all <ArrowRight size={14} />
            </Link>
          </div>
          <div className="mt-3 divide-y divide-slate-100">
            {orders.slice(0, 6).map((o) => (
              <div key={o.id} className="flex items-center gap-4 px-5 py-3">
                <img src={o.photo} alt="" className="h-11 w-11 rounded-xl bg-slate-50 object-contain" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{o.item}</p>
                  <p className="text-xs text-muted">
                    {o.id} • {o.buyer} • {sellers.find((x) => x.id === o.sellerId)?.storeName}
                  </p>
                </div>
                <Badge tone={orderTone[o.stage]} dot>
                  {orderLabel[o.stage]}
                </Badge>
                <p className="w-24 text-right text-sm font-bold">{inr(o.price)}</p>
              </div>
            ))}
          </div>
        </Card>
        <Card>
          <p className="font-bold text-ink">Top sellers</p>
          <div className="mt-3 space-y-3">
            {s.bySeller.map((b, i) => (
              <div key={b.name}>
                <div className="mb-1 flex justify-between text-sm">
                  <span className="font-medium">
                    {i + 1}. {b.name}
                  </span>
                  <span className="font-semibold text-muted">{inrShort(b.value)}</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-slate-100">
                  <div className="h-full rounded-full bg-gradient-to-r from-brand to-violet" style={{ width: `${(b.value / (s.bySeller[0]?.value || 1)) * 100}%` }} />
                </div>
              </div>
            ))}
          </div>
          <p className="mt-5 font-bold text-ink">Payment mix</p>
          <div className="mt-2 h-32">
            <ResponsiveContainer>
              <BarChart data={s.byPay}>
                <XAxis dataKey="name" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: '#8A93AD' }} />
                <Tooltip cursor={{ fill: '#F3F6FD' }} contentStyle={{ borderRadius: 12 }} />
                <Bar dataKey="value" name="Orders" radius={[8, 8, 0, 0]} fill="#6A3DF5" isAnimationActive={false} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <div className="mt-5 grid gap-5 lg:grid-cols-2">
        <Card>
          <div className="flex items-center justify-between">
            <p className="font-bold text-ink">QC queue</p>
            <Link to="/qc" className="inline-flex items-center gap-1 text-sm font-semibold text-brand">
              Open QC <ArrowRight size={14} />
            </Link>
          </div>
          <div className="mt-3 space-y-2">
            {qc.length === 0 && <p className="py-8 text-center text-sm text-muted">Queue is clear 🎉</p>}
            {qc.slice(0, 4).map((l) => (
              <Link to="/qc" key={l.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3 hover:bg-slate-50">
                <img src={l.photos[0]} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{title(l)}</p>
                  <p className="text-xs text-muted">
                    {sellers.find((x) => x.id === l.sellerId)?.storeName} • {ago(l.submittedAt ?? l.createdAt)}
                  </p>
                </div>
                <b className="text-sm">{inr(l.price)}</b>
              </Link>
            ))}
          </div>
        </Card>
        <Card>
          <p className="font-bold text-ink">Activity</p>
          <div className="mt-3 space-y-3">
            {activity.slice(0, 7).map((a) => (
              <div key={a.id} className="flex gap-3">
                <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-brand" />
                <div>
                  <p className="text-sm text-ink">{a.text}</p>
                  <p className="text-xs text-muted">{ago(a.at)}</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  );
}
