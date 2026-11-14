import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { ArrowRight, IndianRupee, Package, ShoppingBag, Users, Video } from 'lucide-react';
import { ago, inr, inrShort, isRevenue, useDB } from '../store';
import { Badge, Card, PageHeader, Stat, Tabs } from '../ui';
import { cap, liveTone, orderTone } from '../status';

const DAY = 864e5;

export default function Dashboard() {
  const orders = useDB((d) => d.orders);
  const products = useDB((d) => d.products);
  const customers = useDB((d) => d.customers);
  const live = useDB((d) => d.live);
  const activity = useDB((d) => d.activity);
  const [range, setRange] = useState<'7' | '30'>('30');

  const stats = useMemo(() => {
    const now = Date.now();
    const inWin = (s: string, from: number, to: number) => {
      const t = now - new Date(s).getTime();
      return t >= from * DAY && t < to * DAY;
    };
    const rev = (a: number, b: number) => orders.filter((o) => isRevenue(o) && inWin(o.createdAt, a, b)).reduce((s, o) => s + o.amount, 0);
    const cnt = (a: number, b: number) => orders.filter((o) => inWin(o.createdAt, a, b)).length;
    const pct = (c: number, p: number) => (p ? ((c - p) / p) * 100 : 100);
    const days = Number(range);
    const series = Array.from({ length: days }, (_, i) => {
      const from = days - 1 - i;
      const dt = new Date(now - from * DAY);
      const dayOrders = orders.filter((o) => inWin(o.createdAt, from, from + 1));
      return {
        day: dt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' }),
        revenue: dayOrders.filter(isRevenue).reduce((s, o) => s + o.amount, 0),
        orders: dayOrders.length,
      };
    });
    const byBrand = Object.entries(
      orders.filter(isRevenue).reduce<Record<string, number>>((m, o) => {
        const b = products.find((p) => p.id === o.productId)?.brand ?? 'Other';
        m[b] = (m[b] ?? 0) + o.amount;
        return m;
      }, {}),
    )
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);
    const byPay = ['UPI', 'Card', 'COD', 'Wallet', 'EMI'].map((m) => ({ name: m, value: orders.filter((o) => o.payment === m).length }));
    return {
      revenue: rev(0, 7),
      revDelta: pct(rev(0, 7), rev(7, 14)),
      orders: cnt(0, 7),
      ordDelta: pct(cnt(0, 7), cnt(7, 14)),
      series,
      byBrand,
      byPay,
      total: orders.filter(isRevenue).reduce((s, o) => s + o.amount, 0),
    };
  }, [orders, products, range]);

  const liveDone = live.filter((l) => l.status === 'completed');
  const conv = liveDone.length ? (liveDone.filter((l) => l.converted).length / liveDone.length) * 100 : 0;
  const lowStock = products.filter((p) => p.status === 'active' && p.stock <= 2);
  const colors = ['#1F5BFF', '#6A3DF5', '#22C55E', '#F59E0B', '#EC4899', '#06B6D4', '#94A3B8', '#0B1230'];

  return (
    <>
      <PageHeader
        title="Good to see you, Admin 👋"
        subtitle="Here's what's happening across GAMEX today."
        actions={<Tabs value={range} onChange={setRange} items={[{ id: '7', label: '7 days' }, { id: '30', label: '30 days' }]} />}
      />

      <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-4">
        <Stat label="Revenue (7d)" value={inrShort(stats.revenue)} delta={stats.revDelta} icon={IndianRupee} gradient="bg-gradient-to-br from-brand to-violet" />
        <Stat label="Orders (7d)" value={String(stats.orders)} delta={stats.ordDelta} icon={ShoppingBag} gradient="bg-gradient-to-br from-emerald-500 to-teal-500" />
        <Stat label="Customers" value={customers.length.toLocaleString('en-IN')} delta={8.4} icon={Users} gradient="bg-gradient-to-br from-amber-500 to-orange-500" />
        <Stat
          label="Live → Purchase"
          value={`${conv.toFixed(0)}%`}
          icon={Video}
          gradient="bg-gradient-to-br from-rose-500 to-pink-500"
          hint={`${live.filter((l) => l.status === 'requested').length} requests waiting`}
        />
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm font-medium text-muted">Revenue overview</p>
              <p className="mt-1 text-2xl font-extrabold text-ink">{inr(stats.series.reduce((s, d) => s + d.revenue, 0))}</p>
            </div>
            <Badge tone="green" dot>
              Lifetime {inrShort(stats.total)}
            </Badge>
          </div>
          <div className="mt-4 h-72">
            <ResponsiveContainer>
              <AreaChart data={stats.series} margin={{ left: 0, right: 8, top: 8 }}>
                <defs>
                  <linearGradient id="rv" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#1F5BFF" stopOpacity={0.28} />
                    <stop offset="100%" stopColor="#1F5BFF" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid vertical={false} stroke="#EEF1F7" />
                <XAxis dataKey="day" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: '#8A93AD' }} minTickGap={24} />
                <YAxis tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: '#8A93AD' }} tickFormatter={(v) => inrShort(v)} width={64} />
                <Tooltip
                  formatter={(v: number, n) => (n === 'revenue' ? [inr(v), 'Revenue'] : [v, 'Orders'])}
                  contentStyle={{ borderRadius: 12, border: '1px solid #E3E8F5', boxShadow: '0 10px 30px -10px rgba(11,18,48,.2)' }}
                />
                <Area type="monotone" dataKey="revenue" stroke="#1F5BFF" strokeWidth={2.5} fill="url(#rv)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card>
          <p className="text-sm font-medium text-muted">Sales by brand</p>
          <div className="relative h-52">
            <ResponsiveContainer>
              <PieChart>
                <Pie data={stats.byBrand} dataKey="value" innerRadius={62} outerRadius={88} paddingAngle={2} stroke="none">
                  {stats.byBrand.map((_, i) => (
                    <Cell key={i} fill={colors[i % colors.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(v: number) => inr(v)} contentStyle={{ borderRadius: 12 }} />
              </PieChart>
            </ResponsiveContainer>
            <div className="pointer-events-none absolute inset-0 grid place-items-center text-center">
              <div>
                <p className="text-xs text-muted">Top brand</p>
                <p className="text-lg font-extrabold text-ink">{stats.byBrand[0]?.name}</p>
              </div>
            </div>
          </div>
          <div className="mt-2 space-y-2">
            {stats.byBrand.slice(0, 5).map((b, i) => (
              <div key={b.name} className="flex items-center gap-3 text-sm">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: colors[i] }} />
                <span className="flex-1 font-medium text-ink">{b.name}</span>
                <span className="font-semibold text-muted">{inrShort(b.value)}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card className="xl:col-span-2" pad={false}>
          <div className="flex items-center justify-between px-5 pt-5">
            <p className="font-bold text-ink">Recent orders</p>
            <Link to="/orders" className="inline-flex items-center gap-1 text-sm font-semibold text-brand">
              View all <ArrowRight size={14} />
            </Link>
          </div>
          <div className="mt-3 divide-y divide-slate-100">
            {orders.slice(0, 6).map((o) => (
              <div key={o.id} className="flex items-center gap-4 px-5 py-3">
                <img src={o.image} alt="" className="h-11 w-11 rounded-xl bg-slate-50 object-contain" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-ink">{o.product}</p>
                  <p className="text-xs text-muted">
                    {o.id} • {o.customer} • {o.city}
                  </p>
                </div>
                <Badge tone={orderTone[o.status]} dot>
                  {cap(o.status)}
                </Badge>
                <p className="w-24 text-right text-sm font-bold text-ink">{inr(o.amount)}</p>
              </div>
            ))}
          </div>
        </Card>

        <Card>
          <p className="font-bold text-ink">Payment mix</p>
          <div className="mt-3 h-44">
            <ResponsiveContainer>
              <BarChart data={stats.byPay}>
                <XAxis dataKey="name" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: '#8A93AD' }} />
                <Tooltip cursor={{ fill: '#F3F6FD' }} contentStyle={{ borderRadius: 12 }} />
                <Bar dataKey="value" name="Orders" radius={[8, 8, 0, 0]} fill="#6A3DF5" />
              </BarChart>
            </ResponsiveContainer>
          </div>
          <p className="mt-4 font-bold text-ink">Activity</p>
          <div className="mt-2 space-y-3">
            {activity.slice(0, 4).map((a) => (
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

      <div className="mt-5 grid gap-5 lg:grid-cols-2">
        <Card>
          <div className="flex items-center justify-between">
            <p className="font-bold text-ink">Live review queue</p>
            <Link to="/live" className="inline-flex items-center gap-1 text-sm font-semibold text-brand">
              Open queue <ArrowRight size={14} />
            </Link>
          </div>
          <div className="mt-3 space-y-2">
            {live
              .filter((l) => ['requested', 'scheduled', 'live'].includes(l.status))
              .slice(0, 4)
              .map((l) => (
                <div key={l.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
                  <img src={l.image} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ink">{l.product}</p>
                    <p className="text-xs text-muted">
                      {l.customer} • {l.mode} • {new Date(l.slot).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: 'numeric' })}
                    </p>
                  </div>
                  <Badge tone={liveTone[l.status]} dot>
                    {cap(l.status)}
                  </Badge>
                </div>
              ))}
          </div>
        </Card>
        <Card>
          <div className="flex items-center justify-between">
            <p className="font-bold text-ink">Low stock alerts</p>
            <Link to="/products" className="inline-flex items-center gap-1 text-sm font-semibold text-brand">
              Manage <ArrowRight size={14} />
            </Link>
          </div>
          <div className="mt-3 space-y-2">
            {lowStock.length === 0 && <p className="py-8 text-center text-sm text-muted">All products are well stocked 🎉</p>}
            {lowStock.slice(0, 4).map((p) => (
              <div key={p.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
                <div className="grid h-10 w-10 place-items-center rounded-lg bg-amber-50 text-amber-600">
                  <Package size={18} />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-ink">{p.name}</p>
                  <p className="text-xs text-muted">
                    {p.variant} • {p.grade}
                  </p>
                </div>
                <Badge tone={p.stock === 0 ? 'red' : 'amber'}>{p.stock === 0 ? 'Out of stock' : `${p.stock} left`}</Badge>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  );
}
