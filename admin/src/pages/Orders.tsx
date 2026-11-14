import { useMemo, useState } from 'react';
import { Check, Download, MapPin, Phone, ShoppingBag, Store, Truck, XCircle } from 'lucide-react';
import { Order, act, fmtDateTime, inr, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, PageHeader, SearchInput, Tabs, Td, Th, cx, inputCls, toast } from '../ui';
import { nextAction, orderFlow, orderLabel, orderTone } from '../status';

type TabId = 'all' | 'new' | 'ship' | 'transit' | 'delivered' | 'issues';
const match: Record<TabId, (o: Order) => boolean> = {
  all: () => true,
  new: (o) => o.stage === 'newOrder',
  ship: (o) => o.stage === 'accepted' || o.stage === 'packed',
  transit: (o) => o.stage === 'shipped',
  delivered: (o) => o.stage === 'delivered',
  issues: (o) => o.stage === 'cancelled' || o.stage === 'returned',
};

export default function Orders() {
  const orders = useDB((d) => d.orders);
  const sellers = useDB((d) => d.sellers);
  const [tab, setTab] = useState<TabId>('all');
  const [q, setQ] = useState('');
  const [pay, setPay] = useState('All');
  const [openId, setOpenId] = useState<string | null>(null);
  const open = orders.find((o) => o.id === openId) ?? null;
  const store = (id: string) => sellers.find((s) => s.id === id)?.storeName ?? id;

  const list = useMemo(
    () =>
      orders.filter(
        (o) =>
          match[tab](o) &&
          (pay === 'All' || o.payment === pay) &&
          `${o.id} ${o.buyer} ${o.phone} ${o.item} ${o.city} ${o.awb ?? ''}`.toLowerCase().includes(q.toLowerCase()),
      ),
    [orders, tab, q, pay],
  );
  const n = (t: TabId) => orders.filter(match[t]).length;

  const run = (o: Order, action: string, body?: object) =>
    act('POST', `/orders/${o.id}/${action}`, body)
      .then(() => toast(`Order ${o.id} updated — seller & buyer apps synced`))
      .catch((e: Error) => toast(e.message));

  const exportCsv = () => {
    const rows = [['Order', 'Date', 'Seller', 'Buyer', 'Phone', 'City', 'Item', 'Amount', 'Payment', 'Stage', 'AWB']].concat(
      list.map((o) => [o.id, o.placedAt, store(o.sellerId), o.buyer, o.phone, o.city, o.item, String(o.price), o.payment, o.stage, o.awb ?? '']),
    );
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([rows.map((r) => r.map((c) => `"${c}"`).join(',')).join('\n')], { type: 'text/csv' }));
    a.download = 'gamex-orders.csv';
    a.click();
  };

  return (
    <>
      <PageHeader
        title="Orders"
        subtitle="Every marketplace order across all sellers. Step in when a seller is late."
        actions={
          <Button variant="secondary" icon={Download} onClick={exportCsv}>
            Export CSV
          </Button>
        }
      />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Not accepted', n('new'), 'from-amber-500 to-orange-500'],
          ['To pack & ship', n('ship'), 'from-violet to-fuchsia-500'],
          ['In transit', n('transit'), 'from-cyan-500 to-blue-500'],
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
              { id: 'ship', label: 'To ship', count: n('ship') },
              { id: 'transit', label: 'Shipped', count: n('transit') },
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
            <SearchInput value={q} onChange={setQ} placeholder="Order, buyer, AWB…" />
          </div>
        </div>
        {list.length === 0 ? (
          <Empty icon={ShoppingBag} title="No orders here" text="Orders from the GAMEX app appear here instantly." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th>Order</Th>
                  <Th>Item</Th>
                  <Th>Seller</Th>
                  <Th>Buyer</Th>
                  <Th>Amount</Th>
                  <Th>Status</Th>
                  <Th className="text-right">Action</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {list.map((o) => {
                  const next = nextAction[o.stage];
                  const late = o.stage === 'newOrder' && Date.now() - new Date(o.placedAt).getTime() > 4 * 36e5;
                  return (
                    <tr key={o.id} onClick={() => setOpenId(o.id)} className="cursor-pointer hover:bg-slate-50/60">
                      <Td>
                        <p className="font-bold text-brand">{o.id}</p>
                        <p className="text-xs text-muted">{fmtDateTime(o.placedAt)}</p>
                      </Td>
                      <Td>
                        <div className="flex items-center gap-3">
                          <img src={o.photo} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                          <span className="max-w-[200px] truncate">{o.item}</span>
                        </div>
                      </Td>
                      <Td className="text-muted">{store(o.sellerId)}</Td>
                      <Td>
                        <p className="font-semibold">{o.buyer}</p>
                        <p className="text-xs text-muted">{o.city}</p>
                      </Td>
                      <Td>
                        <p className="font-bold">{inr(o.price)}</p>
                        <p className="text-xs text-muted">{o.payment}</p>
                      </Td>
                      <Td>
                        <Badge tone={orderTone[o.stage]} dot>
                          {orderLabel[o.stage]}
                        </Badge>
                        {late && <p className="mt-1 text-xs font-semibold text-rose-600">Seller late &gt; 4h</p>}
                      </Td>
                      <Td className="text-right">
                        {next ? (
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={(e) => {
                              e.stopPropagation();
                              run(o, next[0], next[0] === 'ship' ? { courier: 'Delhivery' } : undefined);
                            }}
                          >
                            {next[1]}
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
              {['newOrder', 'accepted', 'packed'].includes(open.stage) && (
                <Button variant="danger" icon={XCircle} onClick={() => run(open, 'cancel', { reason: 'Cancelled by GAMEX support' })}>
                  Cancel order
                </Button>
              )}
              {open.stage === 'delivered' && (
                <Button variant="danger" onClick={() => run(open, 'return')}>
                  Mark returned
                </Button>
              )}
              {nextAction[open.stage] && (
                <Button onClick={() => run(open, nextAction[open.stage]![0], { courier: 'Delhivery' })}>{nextAction[open.stage]![1]}</Button>
              )}
            </>
          )
        }
      >
        {open && (
          <div className="space-y-5">
            <div className="flex items-center gap-4 rounded-2xl bg-gradient-to-br from-slate-50 to-blue-50 p-4">
              <img src={open.photo} alt="" className="h-20 w-20 object-contain" />
              <div className="flex-1">
                <p className="font-bold text-ink">{open.item}</p>
                <p className="text-sm text-muted">{open.variant}</p>
                <p className="mt-1 text-xl font-extrabold">{inr(open.price)}</p>
              </div>
              <Badge tone={orderTone[open.stage]} dot>
                {orderLabel[open.stage]}
              </Badge>
            </div>
            {!['cancelled', 'returned'].includes(open.stage) && (
              <div className="flex items-center">
                {orderFlow.map((s, i) => {
                  const done = orderFlow.indexOf(open.stage) >= i;
                  return (
                    <div key={s} className="flex flex-1 items-center last:flex-none">
                      <div className={cx('grid h-8 w-8 place-items-center rounded-full border-2 text-xs font-bold', done ? 'border-brand bg-brand text-white' : 'border-slate-200 text-slate-400')}>
                        {done ? <Check size={15} /> : i + 1}
                      </div>
                      {i < orderFlow.length - 1 && <div className={cx('mx-1 h-0.5 flex-1', orderFlow.indexOf(open.stage) > i ? 'bg-brand' : 'bg-slate-200')} />}
                    </div>
                  );
                })}
              </div>
            )}
            <div className="grid gap-2 rounded-2xl border border-slate-200 p-4 text-sm">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted">Buyer</p>
              <p className="font-bold">{open.buyer}</p>
              <p className="flex items-center gap-2 text-muted">
                <Phone size={14} /> {open.phone}
              </p>
              <p className="flex items-center gap-2 text-muted">
                <MapPin size={14} /> {open.address}, {open.city} {open.pincode}
              </p>
            </div>
            <div className="grid grid-cols-2 gap-3 rounded-2xl border border-slate-200 p-4 text-sm">
              <div>
                <p className="text-xs text-muted">Seller</p>
                <p className="flex items-center gap-1 font-semibold">
                  <Store size={14} /> {store(open.sellerId)}
                </p>
              </div>
              <div>
                <p className="text-xs text-muted">Payment</p>
                <p className="font-semibold">{open.payment}</p>
              </div>
              <div>
                <p className="text-xs text-muted">Courier / AWB</p>
                <p className="flex items-center gap-1 font-semibold">
                  <Truck size={14} /> {open.awb ? `${open.courier} ${open.awb}` : 'Not shipped'}
                </p>
              </div>
              <div>
                <p className="text-xs text-muted">Seller receives</p>
                <p className="font-semibold">{inr(open.price - (open.price * 0.08 + 49) * 1.18)}</p>
              </div>
            </div>
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Timeline</p>
              {[...open.events].reverse().map((e, i) => (
                <div key={i} className="flex gap-3 py-1.5">
                  <span className={cx('mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full', i === 0 ? 'bg-brand' : 'bg-slate-300')} />
                  <div>
                    <p className="text-sm font-medium">{e.l}</p>
                    <p className="text-xs text-muted">{fmtDateTime(e.a)}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
