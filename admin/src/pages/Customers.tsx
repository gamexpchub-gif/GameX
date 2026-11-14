import { useMemo, useState } from 'react';
import { Ban, Crown, Mail, MapPin, Phone, Users } from 'lucide-react';
import { Customer, fmtDate, fmtDateTime, inr, log, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, PageHeader, SearchInput, Tabs, Td, Th } from '../ui';
import { cap, orderTone } from '../status';

const tierTone = { Silver: 'slate', Gold: 'amber', Platinum: 'violet' } as const;

export default function Customers() {
  const customers = useDB((d) => d.customers);
  const orders = useDB((d) => d.orders);
  const [q, setQ] = useState('');
  const [tab, setTab] = useState<'all' | 'Platinum' | 'Gold' | 'blocked'>('all');
  const [openId, setOpenId] = useState<string | null>(null);
  const open = customers.find((c) => c.id === openId) ?? null;

  const list = useMemo(
    () =>
      customers
        .filter(
          (c) =>
            (tab === 'all' || (tab === 'blocked' ? c.status === 'blocked' : c.tier === tab)) &&
            `${c.name} ${c.email} ${c.phone} ${c.city}`.toLowerCase().includes(q.toLowerCase()),
        )
        .sort((a, b) => b.spent - a.spent),
    [customers, q, tab],
  );

  const toggleBlock = (c: Customer) => {
    const status = c.status === 'blocked' ? 'active' : 'blocked';
    update((d) => ({ ...d, customers: d.customers.map((x) => (x.id === c.id ? { ...x, status } : x)) }));
    log(`${c.name} ${status === 'blocked' ? 'blocked' : 'unblocked'}`, 'customer');
  };

  return (
    <>
      <PageHeader title="Customers" subtitle={`${customers.length} registered buyers across India`} />
      <Card pad={false}>
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-100 p-4">
          <Tabs
            value={tab}
            onChange={setTab}
            items={[
              { id: 'all', label: 'All', count: customers.length },
              { id: 'Platinum', label: 'Platinum', count: customers.filter((c) => c.tier === 'Platinum').length },
              { id: 'Gold', label: 'Gold', count: customers.filter((c) => c.tier === 'Gold').length },
              { id: 'blocked', label: 'Blocked', count: customers.filter((c) => c.status === 'blocked').length },
            ]}
          />
          <div className="ml-auto">
            <SearchInput value={q} onChange={setQ} placeholder="Name, phone, city…" />
          </div>
        </div>
        {list.length === 0 ? (
          <Empty icon={Users} title="No customers" text="Try another search." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th>Customer</Th>
                  <Th>Phone</Th>
                  <Th>City</Th>
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
                            .join('')}
                        </div>
                        <div>
                          <p className="font-semibold">{c.name}</p>
                          <p className="text-xs text-muted">{c.email}</p>
                        </div>
                      </div>
                    </Td>
                    <Td>{c.phone}</Td>
                    <Td>{c.city}</Td>
                    <Td className="font-semibold">{c.orders}</Td>
                    <Td className="font-bold">{inr(c.spent)}</Td>
                    <Td>
                      <Badge tone={tierTone[c.tier]}>
                        {c.tier === 'Platinum' && <Crown size={11} />} {c.tier}
                      </Badge>
                    </Td>
                    <Td className="text-muted">{fmtDate(c.joinedAt)}</Td>
                    <Td>
                      <Badge tone={c.status === 'active' ? 'green' : 'red'} dot>
                        {cap(c.status)}
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
            <Button variant={open.status === 'blocked' ? 'secondary' : 'danger'} icon={Ban} onClick={() => toggleBlock(open)}>
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
                ['Since', fmtDate(open.joinedAt)],
              ].map(([l, v]) => (
                <div key={l} className="rounded-2xl bg-slate-50 p-3">
                  <p className="text-xs text-muted">{l}</p>
                  <p className="font-bold text-ink">{v}</p>
                </div>
              ))}
            </div>
            <div className="space-y-2 rounded-2xl border border-slate-200 p-4 text-sm text-muted">
              <p className="flex items-center gap-2">
                <Mail size={14} /> {open.email}
              </p>
              <p className="flex items-center gap-2">
                <Phone size={14} /> {open.phone}
              </p>
              <p className="flex items-center gap-2">
                <MapPin size={14} /> {open.city}, India
              </p>
            </div>
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Order history</p>
              <div className="space-y-2">
                {orders
                  .filter((o) => o.customerId === open.id)
                  .map((o) => (
                    <div key={o.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
                      <img src={o.image} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-semibold">{o.product}</p>
                        <p className="text-xs text-muted">
                          {o.id} • {fmtDateTime(o.createdAt)}
                        </p>
                      </div>
                      <Badge tone={orderTone[o.status]}>{cap(o.status)}</Badge>
                    </div>
                  ))}
              </div>
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
