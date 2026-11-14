import { useMemo, useState } from 'react';
import { Ban, Crown, Mail, MapPin, Phone, Users } from 'lucide-react';
import { act, ago, fmtDate, fmtDateTime, inr, isRevenue, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, PageHeader, SearchInput, Tabs, Td, Th, toast } from '../ui';
import { orderLabel, orderTone } from '../status';

type Tier = 'Silver' | 'Gold' | 'Platinum';
const tierTone = { Silver: 'slate', Gold: 'amber', Platinum: 'violet' } as const;

export default function Customers() {
  const customers = useDB((d) => d.customers);
  const orders = useDB((d) => d.orders);
  const live = useDB((d) => d.live);
  const [q, setQ] = useState('');
  const [tab, setTab] = useState<'all' | 'Platinum' | 'Gold' | 'new' | 'blocked'>('all');
  const [openId, setOpenId] = useState<string | null>(null);

  const rows = useMemo(
    () =>
      customers.map((c) => {
        const mine = orders.filter((o) => o.customerId === c.id);
        const spent = mine.filter(isRevenue).reduce((s, o) => s + o.price, 0);
        const tier: Tier = spent > 150000 ? 'Platinum' : spent > 60000 ? 'Gold' : 'Silver';
        return { ...c, orders: mine.length, spent, tier, isNew: Date.now() - new Date(c.createdAt).getTime() < 7 * 864e5 };
      }),
    [customers, orders],
  );
  const list = rows
    .filter(
      (c) =>
        (tab === 'all' || (tab === 'blocked' ? c.status === 'blocked' : tab === 'new' ? c.isNew : c.tier === tab)) &&
        `${c.name} ${c.email} ${c.phone} ${c.city}`.toLowerCase().includes(q.toLowerCase()),
    )
    .sort((a, b) => b.spent - a.spent);
  const open = rows.find((c) => c.id === openId) ?? null;

  const toggle = (id: string, blocked: boolean, name: string) =>
    act('PATCH', `/customers/${id}`, { status: blocked ? 'active' : 'blocked' }).then(() => toast(`${name} ${blocked ? 'unblocked' : 'blocked — cannot place orders'}`));

  return (
    <>
      <PageHeader title="Customers" subtitle={`${customers.length} buyers registered from the GAMEX app`} />
      <Card pad={false}>
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-100 p-4">
          <Tabs
            value={tab}
            onChange={setTab}
            items={[
              { id: 'all', label: 'All', count: rows.length },
              { id: 'new', label: 'New this week', count: rows.filter((c) => c.isNew).length },
              { id: 'Platinum', label: 'Platinum', count: rows.filter((c) => c.tier === 'Platinum').length },
              { id: 'Gold', label: 'Gold', count: rows.filter((c) => c.tier === 'Gold').length },
              { id: 'blocked', label: 'Blocked', count: rows.filter((c) => c.status === 'blocked').length },
            ]}
          />
          <div className="ml-auto">
            <SearchInput value={q} onChange={setQ} placeholder="Name, phone, city…" />
          </div>
        </div>
        {list.length === 0 ? (
          <Empty icon={Users} title="No customers" text="People who sign up in the GAMEX app appear here." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th>Customer</Th>
                  <Th>Phone</Th>
                  <Th>Orders</Th>
                  <Th>Lifetime value</Th>
                  <Th>Tier</Th>
                  <Th>Joined</Th>
                  <Th>Status</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {list.map((c) => (
                  <tr key={c.id} onClick={() => setOpenId(c.id)} className="cursor-pointer hover:bg-slate-50/60">
                    <Td>
                      <div className="flex items-center gap-3">
                        <div className="grid h-9 w-9 place-items-center rounded-full bg-gradient-to-br from-brand to-violet text-xs font-bold text-white">
                          {c.name
                            .split(' ')
                            .map((s) => s[0])
                            .slice(0, 2)
                            .join('')}
                        </div>
                        <div>
                          <p className="font-semibold">
                            {c.name} {c.isNew && <Badge tone="cyan">New</Badge>}
                          </p>
                          <p className="text-xs text-muted">{c.email || c.city}</p>
                        </div>
                      </div>
                    </Td>
                    <Td>{c.phone || '—'}</Td>
                    <Td className="font-semibold">{c.orders}</Td>
                    <Td className="font-bold">{inr(c.spent)}</Td>
                    <Td>
                      <Badge tone={tierTone[c.tier]}>
                        {c.tier === 'Platinum' && <Crown size={11} />} {c.tier}
                      </Badge>
                    </Td>
                    <Td className="text-muted">{fmtDate(c.createdAt)}</Td>
                    <Td>
                      <Badge tone={c.status === 'active' ? 'green' : 'red'} dot>
                        {c.status === 'active' ? 'Active' : 'Blocked'}
                      </Badge>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Drawer
        open={!!open}
        onClose={() => setOpenId(null)}
        title="Customer profile"
        footer={
          open && (
            <Button variant={open.status === 'blocked' ? 'secondary' : 'danger'} icon={Ban} onClick={() => toggle(open.id, open.status === 'blocked', open.name)}>
              {open.status === 'blocked' ? 'Unblock customer' : 'Block customer'}
            </Button>
          )
        }
      >
        {open && (
          <div className="space-y-5">
            <div className="flex items-center gap-4">
              <div className="grid h-16 w-16 place-items-center rounded-2xl bg-gradient-to-br from-brand to-violet text-xl font-bold text-white">
                {open.name
                  .split(' ')
                  .map((s) => s[0])
                  .slice(0, 2)
                  .join('')}
              </div>
              <div>
                <p className="text-lg font-bold text-ink">{open.name}</p>
                <Badge tone={tierTone[open.tier]}>{open.tier} member</Badge>
              </div>
            </div>
            <div className="grid grid-cols-3 gap-3">
              {[
                ['Orders', String(open.orders)],
                ['Spent', inr(open.spent)],
                ['Live views', String(live.filter((l) => (l as { customerId?: string }).customerId === open.id).length)],
              ].map(([l, v]) => (
                <div key={l} className="rounded-2xl bg-slate-50 p-3">
                  <p className="text-xs text-muted">{l}</p>
                  <p className="font-bold text-ink">{v}</p>
                </div>
              ))}
            </div>
            <div className="space-y-2 rounded-2xl border border-slate-200 p-4 text-sm text-muted">
              <p className="flex items-center gap-2">
                <Mail size={14} /> {open.email || '—'}
              </p>
              <p className="flex items-center gap-2">
                <Phone size={14} /> {open.phone || '—'}
              </p>
              <p className="flex items-center gap-2">
                <MapPin size={14} /> {open.city || '—'}
              </p>
              <p>Joined {fmtDate(open.createdAt)} ({ago(open.createdAt)})</p>
            </div>
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Order history</p>
              <div className="space-y-2">
                {orders
                  .filter((o) => o.customerId === open.id)
                  .map((o) => (
                    <div key={o.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
                      <img src={o.photo} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-semibold">{o.item}</p>
                        <p className="text-xs text-muted">
                          {o.id} • {fmtDateTime(o.placedAt)}
                        </p>
                      </div>
                      <Badge tone={orderTone[o.stage]}>{orderLabel[o.stage]}</Badge>
                    </div>
                  ))}
                {open.orders === 0 && <p className="text-sm text-muted">No orders yet.</p>}
              </div>
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
