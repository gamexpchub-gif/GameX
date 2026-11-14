import { useMemo, useState } from 'react';
import { Check, Download, MapPin, Phone, Printer, ShoppingBag, Truck, XCircle } from 'lucide-react';
import { Order, OrderStatus, fmtDateTime, inr, log, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, PageHeader, SearchInput, Tabs, Td, Th, cx, inputCls, toast } from '../ui';
import { cap, orderFlow, orderTone } from '../status';

type TabId = 'all' | 'new' | 'packed' | 'shipped' | 'delivered' | 'issues';
const match: Record<TabId, (o: Order) => boolean> = {
  all: () => true,
  new: (o) => o.status === 'pending' || o.status === 'confirmed',
  packed: (o) => o.status === 'packed',
  shipped: (o) => o.status === 'shipped',
  delivered: (o) => o.status === 'delivered',
  issues: (o) => o.status === 'cancelled' || o.status === 'returned',
};

export default function Orders() {
  const orders = useDB((d) => d.orders);
  const [tab, setTab] = useState<TabId>('all');
  const [q, setQ] = useState('');
  const [pay, setPay] = useState('All');
  const [openId, setOpenId] = useState<string | null>(null);
  const open = orders.find((o) => o.id === openId) ?? null;

  const list = useMemo(
    () =>
      orders.filter(
        (o) => match[tab](o) && (pay === 'All' || o.payment === pay) && `${o.id} ${o.customer} ${o.phone} ${o.product} ${o.city}`.toLowerCase().includes(q.toLowerCase()),
      ),
    [orders, tab, q, pay],
  );

  const setStatus = (o: Order, status: OrderStatus) => {
    update((d) => ({
      ...d,
      orders: d.orders.map((x) =>
        x.id === o.id
          ? {
              ...x,
              status,
              paid: status === 'delivered' ? true : x.paid,
              awb: status === 'shipped' && !x.awb ? `BD${Math.floor(1e9 + Math.random() * 9e9)}` : x.awb,
            }
          : x,
      ),
    }));
    log(`Order ${o.id} → ${cap(status)}`, 'order');
    toast(`Order ${o.id} marked ${status}`);
  };

  const exportCsv = () => {
    const rows = [['Order', 'Date', 'Customer', 'Phone', 'City', 'Product', 'Amount', 'Payment', 'Paid', 'Status']].concat(
      list.map((o) => [o.id, o.createdAt, o.customer, o.phone, o.city, o.product, String(o.amount), o.payment, o.paid ? 'Yes' : 'No', o.status]),
    );
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([rows.map((r) => r.map((c) => `"${c}"`).join(',')).join('\n')], { type: 'text/csv' }));
    a.download = 'gamex-orders.csv';
    a.click();
  };

  const n = (t: TabId) => orders.filter(match[t]).length;

  return (
    <>
      <PageHeader
        title="Orders"
        subtitle="Confirm, pack, ship and track every order."
        actions={
          <Button variant="secondary" icon={Download} onClick={exportCsv}>
            Export CSV
          </Button>
        }
      />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Needs action', n('new'), 'from-amber-500 to-orange-500'],
          ['Ready to ship', n('packed'), 'from-violet to-fuchsia-500'],
          ['In transit', n('shipped'), 'from-cyan-500 to-blue-500'],
          ['Delivered', n('delivered'), 'from-emerald-500 to-teal-500'],
        ].map(([l, v, g]) => (
          <Card key={l as string} className="flex items-center gap-4">
            <div className={cx('h-12 w-1.5 rounded-full bg-gradient-to-b', g as string)} />
            <div>
              <p className="text-sm text-muted">{l}</p>
              <p className="text-2xl font-extrabold text-ink">{v}</p>
            </div>
          </Card>
        ))}
      </div>
      <Card pad={false}>
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-100 p-4">
          <Tabs
            value={tab}
            onChange={setTab}
            items={[
              { id: 'all', label: 'All', count: n('all') },
              { id: 'new', label: 'New', count: n('new') },
              { id: 'packed', label: 'Packed', count: n('packed') },
              { id: 'shipped', label: 'Shipped', count: n('shipped') },
              { id: 'delivered', label: 'Delivered', count: n('delivered') },
              { id: 'issues', label: 'Cancelled / Returns', count: n('issues') },
            ]}
          />
          <div className="ml-auto flex items-center gap-2">
            <select value={pay} onChange={(e) => setPay(e.target.value)} className={cx(inputCls, '!w-32')}>
              {['All', 'UPI', 'Card', 'COD', 'Wallet', 'EMI'].map((p) => (
                <option key={p}>{p}</option>
              ))}
            </select>
            <SearchInput value={q} onChange={setQ} placeholder="Order ID, customer, phone…" />
          </div>
        </div>
        {list.length === 0 ? (
          <Empty icon={ShoppingBag} title="No orders here" text="Orders matching this filter will show up here." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th>Order</Th>
                  <Th>Customer</Th>
                  <Th>Product</Th>
                  <Th>Amount</Th>
                  <Th>Payment</Th>
                  <Th>Status</Th>
                  <Th className="text-right">Action</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {list.map((o) => {
                  const next = orderFlow[orderFlow.indexOf(o.status) + 1];
                  return (
                    <tr key={o.id} onClick={() => setOpenId(o.id)} className="cursor-pointer hover:bg-slate-50/60">
                      <Td>
                        <p className="font-bold text-brand">{o.id}</p>
                        <p className="text-xs text-muted">{fmtDateTime(o.createdAt)}</p>
                      </Td>
                      <Td>
                        <p className="font-semibold">{o.customer}</p>
                        <p className="text-xs text-muted">{o.city}</p>
                      </Td>
                      <Td>
                        <div className="flex items-center gap-3">
                          <img src={o.image} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                          <span className="max-w-[220px] truncate">{o.product}</span>
                        </div>
                      </Td>
                      <Td className="font-bold">{inr(o.amount)}</Td>
                      <Td>
                        <div className="flex items-center gap-2">
                          <span className="font-medium">{o.payment}</span>
                          <Badge tone={o.paid ? 'green' : 'amber'}>{o.paid ? 'Paid' : 'Due'}</Badge>
                        </div>
                      </Td>
                      <Td>
                        <Badge tone={orderTone[o.status]} dot>
                          {cap(o.status)}
                        </Badge>
                      </Td>
                      <Td className="text-right">
                        {next ? (
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={(e) => {
                              e.stopPropagation();
                              setStatus(o, next);
                            }}
                          >
                            Mark {next}
                          </Button>
                        ) : (
                          <span className="text-xs text-muted">—</span>
                        )}
                      </Td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Drawer
        open={!!open}
        onClose={() => setOpenId(null)}
        title={open ? `Order ${open.id}` : ''}
        footer={
          open && (
            <>
              <Button variant="secondary" icon={Printer} onClick={() => window.print()}>
                Invoice
              </Button>
              {!['cancelled', 'returned', 'delivered'].includes(open.status) && (
                <Button variant="danger" icon={XCircle} onClick={() => setStatus(open, 'cancelled')}>
                  Cancel order
                </Button>
              )}
              {open.status === 'delivered' && (
                <Button variant="danger" onClick={() => setStatus(open, 'returned')}>
                  Mark returned
                </Button>
              )}
            </>
          )
        }
      >
        {open && (
          <div className="space-y-5">
            <div className="flex items-center gap-4 rounded-2xl bg-gradient-to-br from-slate-50 to-blue-50 p-4">
              <img src={open.image} alt="" className="h-20 w-20 object-contain" />
              <div className="flex-1">
                <p className="font-bold text-ink">{open.product}</p>
                <p className="text-sm text-muted">Qty {open.qty}</p>
                <p className="mt-1 text-xl font-extrabold">{inr(open.amount)}</p>
              </div>
              <Badge tone={orderTone[open.status]} dot>
                {cap(open.status)}
              </Badge>
            </div>

            {!['cancelled', 'returned'].includes(open.status) && (
              <div>
                <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted">Fulfilment</p>
                <div className="flex items-center">
                  {orderFlow.map((s, i) => {
                    const done = orderFlow.indexOf(open.status) >= i;
                    return (
                      <div key={s} className="flex flex-1 items-center last:flex-none">
                        <button
                          onClick={() => setStatus(open, s)}
                          title={`Set ${s}`}
                          className={cx('grid h-9 w-9 place-items-center rounded-full border-2 text-xs font-bold', done ? 'border-brand bg-brand text-white' : 'border-slate-200 bg-white text-slate-400')}
                        >
                          {done ? <Check size={16} /> : i + 1}
                        </button>
                        {i < orderFlow.length - 1 && <div className={cx('mx-1 h-0.5 flex-1', orderFlow.indexOf(open.status) > i ? 'bg-brand' : 'bg-slate-200')} />}
                      </div>
                    );
                  })}
                </div>
                <div className="mt-2 flex justify-between text-[11px] font-semibold text-muted">
                  {orderFlow.map((s) => (
                    <span key={s}>{cap(s)}</span>
                  ))}
                </div>
              </div>
            )}

            <div className="grid gap-3 rounded-2xl border border-slate-200 p-4 text-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted">Customer</p>
              <p className="font-bold text-ink">{open.customer}</p>
              <p className="flex items-center gap-2 text-muted">
                <Phone size={14} /> {open.phone}
              </p>
              <p className="flex items-center gap-2 text-muted">
                <MapPin size={14} /> {open.city}, India
              </p>
            </div>

            <div className="grid grid-cols-2 gap-3 rounded-2xl border border-slate-200 p-4 text-sm">
              <div>
                <p className="text-xs text-muted">Placed</p>
                <p className="font-semibold">{fmtDateTime(open.createdAt)}</p>
              </div>
              <div>
                <p className="text-xs text-muted">Payment</p>
                <p className="font-semibold">
                  {open.payment} • {open.paid ? 'Paid' : 'Due on delivery'}
                </p>
              </div>
              <div>
                <p className="text-xs text-muted">Courier AWB</p>
                <p className="flex items-center gap-1 font-semibold">
                  <Truck size={14} /> {open.awb ?? 'Not shipped'}
                </p>
              </div>
              <div>
                <p className="text-xs text-muted">Item total</p>
                <p className="font-semibold">{inr(open.amount)}</p>
              </div>
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
