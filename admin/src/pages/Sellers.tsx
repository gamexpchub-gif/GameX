import { useMemo, useState } from 'react';
import { Ban, BadgeCheck, Megaphone, Phone, Send, Store, Wallet } from 'lucide-react';
import { Seller, act, ago, fmtDate, fmtDateTime, inr, inrShort, isRevenue, title, useDB, media } from '../store';
import { Badge, Button, Card, Drawer, Empty, Field, PageHeader, SearchInput, Tabs, Td, Th, cx, inputCls, toast } from '../ui';
import { listingLabel, listingTone, sellerLabel, sellerTone } from '../status';

type Tab = 'all' | 'pending' | 'approved' | 'suspended';

export default function Sellers() {
  const sellers = useDB((d) => d.sellers);
  const listings = useDB((d) => d.listings);
  const orders = useDB((d) => d.orders);
  const [tab, setTab] = useState<Tab>('all');
  const [q, setQ] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const [broadcast, setBroadcast] = useState(false);

  const stats = useMemo(() => {
    const m: Record<string, { live: number; qc: number; orders: number; gmv: number; cancels: number }> = {};
    sellers.forEach((s) => (m[s.id] = { live: 0, qc: 0, orders: 0, gmv: 0, cancels: 0 }));
    listings.forEach((l) => {
      if (!m[l.sellerId]) return;
      if (l.status === 'active') m[l.sellerId].live++;
      if (l.status === 'inReview') m[l.sellerId].qc++;
    });
    orders.forEach((o) => {
      if (!m[o.sellerId]) return;
      m[o.sellerId].orders++;
      if (isRevenue(o)) m[o.sellerId].gmv += o.price;
      if (o.events.some((e) => e.l.startsWith('Rejected by seller'))) m[o.sellerId].cancels++;
    });
    return m;
  }, [sellers, listings, orders]);

  const list = sellers
    .filter((s) => (tab === 'all' || s.status === tab) && `${s.storeName} ${s.ownerName} ${s.phone} ${s.city}`.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => (a.status === 'pending' ? -1 : 0) - (b.status === 'pending' ? -1 : 0) || (stats[b.id]?.gmv ?? 0) - (stats[a.id]?.gmv ?? 0));
  const n = (t: Tab) => sellers.filter((s) => t === 'all' || s.status === t).length;
  const open = sellers.find((s) => s.id === openId) ?? null;

  return (
    <>
      <PageHeader
        title="Sellers"
        subtitle="Approve KYC, monitor performance, pay out and message your marketplace sellers."
        actions={
          <Button icon={Megaphone} onClick={() => setBroadcast(true)}>
            Announce to sellers
          </Button>
        }
      />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Total sellers', sellers.length, 'text-brand bg-brand-50'],
          ['KYC pending', n('pending'), 'text-amber-600 bg-amber-50'],
          ['Live listings', listings.filter((l) => l.status === 'active').length, 'text-emerald-600 bg-emerald-50'],
          ['Marketplace GMV', inrShort(Object.values(stats).reduce((s, x) => s + x.gmv, 0)), 'text-violet bg-violet-50'],
        ].map(([l, v, c]) => (
          <Card key={l as string} className="flex items-center gap-4">
            <div className={cx('grid h-12 w-12 place-items-center rounded-2xl', c as string)}>
              <Store size={22} />
            </div>
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
              { id: 'pending', label: 'KYC pending', count: n('pending') },
              { id: 'approved', label: 'Approved', count: n('approved') },
              { id: 'suspended', label: 'Suspended', count: n('suspended') },
            ]}
          />
          <div className="ml-auto">
            <SearchInput value={q} onChange={setQ} placeholder="Store, owner, phone…" />
          </div>
        </div>
        {list.length === 0 ? (
          <Empty icon={Store} title="No sellers" text="Sellers who sign up in the GAMEX Seller app appear here." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th>Store</Th>
                  <Th>Status</Th>
                  <Th>Live / QC</Th>
                  <Th>Orders</Th>
                  <Th>GMV</Th>
                  <Th>Rating</Th>
                  <Th>Joined</Th>
                  <Th className="text-right">Action</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {list.map((s) => (
                  <tr key={s.id} onClick={() => setOpenId(s.id)} className="cursor-pointer hover:bg-slate-50/60">
                    <Td>
                      <div className="flex items-center gap-3">
                        <div className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-brand to-violet text-xs font-bold text-white">
                          {s.storeName
                            .split(' ')
                            .slice(0, 2)
                            .map((w) => w[0])
                            .join('')}
                        </div>
                        <div>
                          <p className="font-semibold">{s.storeName}</p>
                          <p className="text-xs text-muted">
                            {s.ownerName} • {s.city}
                          </p>
                        </div>
                      </div>
                    </Td>
                    <Td>
                      <Badge tone={sellerTone[s.status]} dot>
                        {sellerLabel[s.status]}
                      </Badge>
                    </Td>
                    <Td>
                      <span className="font-semibold">{stats[s.id]?.live}</span>
                      <span className="text-muted"> / {stats[s.id]?.qc}</span>
                    </Td>
                    <Td>{stats[s.id]?.orders}</Td>
                    <Td className="font-bold">{inr(stats[s.id]?.gmv ?? 0)}</Td>
                    <Td>{s.rating ? `★ ${s.rating}` : '—'}</Td>
                    <Td className="text-muted">{fmtDate(s.createdAt)}</Td>
                    <Td className="text-right">
                      {s.status === 'pending' ? (
                        <Button
                          size="sm"
                          variant="success"
                          onClick={(e) => {
                            e.stopPropagation();
                            act('PATCH', `/sellers/${s.id}`, { status: 'approved' }).then(() => toast(`${s.storeName} approved`));
                          }}
                        >
                          Approve KYC
                        </Button>
                      ) : (
                        <span className="text-xs text-muted">View</span>
                      )}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {open && <SellerDrawer seller={open} stats={stats[open.id]} onClose={() => setOpenId(null)} />}
      {broadcast && <Broadcast onClose={() => setBroadcast(false)} />}
    </>
  );
}

function SellerDrawer({
  seller: s,
  stats,
  onClose,
}: {
  seller: Seller;
  stats?: { live: number; qc: number; orders: number; gmv: number; cancels: number };
  onClose: () => void;
}) {
  const listings = useDB((d) => d.listings).filter((l) => l.sellerId === s.id);
  const payouts = useDB((d) => d.payouts).filter((p) => p.sellerId === s.id);
  const orders = useDB((d) => d.orders).filter((o) => o.sellerId === s.id);
  const [msg, setMsg] = useState('');
  const [reason, setReason] = useState('');
  const [balance, setBalance] = useState<number | null>(null);
  const cancelRate = orders.length ? ((stats?.cancels ?? 0) * 100) / orders.length : 0;

  const setStatus = async (status: string) => {
    if (status === 'suspended' && !reason.trim()) return toast('Write a reason for the seller');
    await act('PATCH', `/sellers/${s.id}`, { status, reason });
    toast(`${s.storeName} ${status}`);
  };

  return (
    <Drawer
      open
      wide
      onClose={onClose}
      title={s.storeName}
      footer={
        <>
          {s.status !== 'approved' && (
            <Button variant="success" icon={BadgeCheck} onClick={() => setStatus('approved')}>
              {s.status === 'suspended' ? 'Reinstate' : 'Approve KYC'}
            </Button>
          )}
          {s.status !== 'suspended' && (
            <Button variant="danger" icon={Ban} onClick={() => setStatus('suspended')}>
              Suspend
            </Button>
          )}
        </>
      }
    >
      <div className="space-y-5">
        <div className="flex items-center gap-4">
          <div className="grid h-16 w-16 place-items-center rounded-2xl bg-gradient-to-br from-brand to-violet text-xl font-bold text-white">
            {s.storeName
              .split(' ')
              .slice(0, 2)
              .map((w) => w[0])
              .join('')}
          </div>
          <div className="flex-1">
            <p className="text-lg font-bold text-ink">{s.storeName}</p>
            <p className="text-sm text-muted">
              {s.ownerName} • {s.city} • since {fmtDate(s.createdAt)}
            </p>
            <div className="mt-1 flex gap-2">
              <Badge tone={sellerTone[s.status]} dot>
                {sellerLabel[s.status]}
              </Badge>
              <Badge tone={s.online ? 'green' : 'slate'}>{s.online ? 'Store online' : 'Holiday mode'}</Badge>
            </div>
          </div>
        </div>
        {s.suspendReason && s.status === 'suspended' && <p className="rounded-xl bg-rose-50 px-3 py-2 text-sm text-rose-700">Suspended: {s.suspendReason}</p>}

        <div className="grid grid-cols-4 gap-3">
          {[
            ['GMV', inrShort(stats?.gmv ?? 0)],
            ['Orders', String(stats?.orders ?? 0)],
            ['Live', String(stats?.live ?? 0)],
            ['Cancel %', `${cancelRate.toFixed(1)}%`],
          ].map(([l, v]) => (
            <div key={l} className="rounded-2xl bg-slate-50 p-3">
              <p className="text-xs text-muted">{l}</p>
              <p className="font-bold text-ink">{v}</p>
            </div>
          ))}
        </div>

        <div className="grid gap-3 rounded-2xl border border-slate-200 p-4 text-sm sm:grid-cols-2">
          <p className="flex items-center gap-2">
            <Phone size={14} className="text-muted" /> {s.phone}
          </p>
          <p>
            <span className="text-muted">GSTIN:</span> {s.gstin || 'Not provided'}
          </p>
          <p>
            <span className="text-muted">Bank:</span> {s.bank}
          </p>
          <p>
            <span className="text-muted">KYC:</span> PAN & Aadhaar {s.status === 'pending' ? 'submitted — review' : 'verified'}
          </p>
        </div>

        {s.status !== 'approved' && (
          <Field label="Reason (shown to seller when suspending)">
            <input className={inputCls} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. High cancellation rate" />
          </Field>
        )}

        <div className="rounded-2xl border border-slate-200 p-4">
          <div className="flex items-center justify-between">
            <p className="font-bold text-ink">Payouts</p>
            <div className="flex gap-2">
              <Button size="sm" variant="secondary" onClick={() => act<{ amount: number }>('GET', `/sellers/${s.id}/balance`).then((b) => setBalance(b.amount))}>
                Check balance
              </Button>
              <Button
                size="sm"
                icon={Wallet}
                onClick={() =>
                  act('POST', `/sellers/${s.id}/payout`)
                    .then(() => {
                      toast('Payout sent');
                      setBalance(0);
                    })
                    .catch((e: Error) => toast(e.message))
                }
              >
                Pay now
              </Button>
            </div>
          </div>
          {balance !== null && <p className="mt-2 text-sm text-muted">Settled & unpaid: <b className="text-ink">{inr(balance)}</b></p>}
          <div className="mt-3 space-y-1">
            {payouts.slice(0, 5).map((p) => (
              <div key={p.id} className="flex justify-between text-sm">
                <span className="text-muted">
                  {fmtDate(p.at)} • UTR {p.utr}
                </span>
                <b>{inr(p.amount)}</b>
              </div>
            ))}
            {payouts.length === 0 && <p className="text-sm text-muted">No payouts yet.</p>}
          </div>
        </div>

        <div>
          <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Listings ({listings.length})</p>
          <div className="space-y-2">
            {listings.slice(0, 8).map((l) => (
              <div key={l.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-2">
                <img src={media(l.photos[0])} alt="" className="h-10 w-10 rounded-lg bg-slate-50 object-contain" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{title(l)}</p>
                  <p className="text-xs text-muted">
                    {inr(l.price)} • {ago(l.createdAt)}
                  </p>
                </div>
                <Badge tone={listingTone[l.status]}>{listingLabel[l.status]}</Badge>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-2xl border border-slate-200 p-4">
          <p className="mb-2 font-bold text-ink">Message this seller</p>
          <div className="flex gap-2">
            <input className={inputCls} value={msg} onChange={(e) => setMsg(e.target.value)} placeholder="Shows in their app notifications" />
            <Button
              icon={Send}
              disabled={!msg.trim()}
              onClick={() =>
                act('POST', '/notify', { sellerId: s.id, title: 'Message from GAMEX', body: msg }).then(() => {
                  setMsg('');
                  toast('Sent to seller app');
                })
              }
            >
              Send
            </Button>
          </div>
          <p className="mt-2 text-xs text-muted">Last order: {orders[0] ? fmtDateTime(orders[0].placedAt) : '—'}</p>
        </div>
      </div>
    </Drawer>
  );
}

function Broadcast({ onClose }: { onClose: () => void }) {
  const [t, setT] = useState('');
  const [b, setB] = useState('');
  return (
    <Drawer
      open
      onClose={onClose}
      title="Announce to all sellers"
      footer={
        <Button
          icon={Megaphone}
          disabled={!t.trim()}
          onClick={() =>
            act('POST', '/notify', { sellerId: null, title: t, body: b }).then(() => {
              toast('Announcement sent to every seller app');
              onClose();
            })
          }
        >
          Send announcement
        </Button>
      }
    >
      <div className="space-y-4">
        <Field label="Title">
          <input className={inputCls} value={t} onChange={(e) => setT(e.target.value)} placeholder="e.g. Diwali Mega Sale is coming 🎉" />
        </Field>
        <Field label="Message">
          <textarea className={inputCls + ' h-28 py-2'} value={b} onChange={(e) => setB(e.target.value)} />
        </Field>
        <p className="text-sm text-muted">Appears on every seller's home page ("From GAMEX") and in their notifications.</p>
      </div>
    </Drawer>
  );
}
