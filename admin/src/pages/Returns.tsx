import { useState } from 'react';
import { CheckCircle2, PackageX, RotateCcw, ShieldAlert, Truck, Wallet, Wrench, XCircle } from 'lucide-react';
import { Claim, ClaimStatus, Order, ReturnStatus, act, ago, fmtDateTime, inr, media, useDB } from '../store';
import { Badge, Button, Card, Empty, PageHeader, Tabs, cx, toast } from '../ui';
import type { Tone } from '../ui';

const returnTone: Record<ReturnStatus, Tone> = {
  requested: 'amber',
  pickup_scheduled: 'blue',
  picked_up: 'violet',
  refunded: 'green',
  rejected: 'red',
};
const returnLabel: Record<ReturnStatus, string> = {
  requested: 'Requested',
  pickup_scheduled: 'Pickup scheduled',
  picked_up: 'Picked up',
  refunded: 'Refunded',
  rejected: 'Rejected',
};
const claimTone: Record<ClaimStatus, Tone> = { submitted: 'amber', approved: 'blue', resolved: 'green', rejected: 'red' };
const claimLabel: Record<ClaimStatus, string> = { submitted: 'New', approved: 'In repair', resolved: 'Resolved', rejected: 'Rejected' };

export default function Returns() {
  const orders = useDB((d) => d.orders);
  const claims = useDB((d) => d.claims);
  const sellers = useDB((d) => d.sellers);
  const [tab, setTab] = useState<'returns' | 'claims' | 'refused' | 'refunds'>('returns');
  const refunds = orders.filter((o) => o.refund).sort((a, b) => b.refund!.at.localeCompare(a.refund!.at));
  const refundAct = (o: Order, action: string) => {
    const note = action === 'manual-done' ? window.prompt('UTR / reference of the bank or UPI transfer:', '') : '';
    if (action === 'manual-done' && note === null) return;
    act('POST', `/refunds/${o.id}`, { action, note })
      .then(() => toast(action === 'retry' ? 'Refund retried' : 'Refund marked as paid - buyer notified'))
      .catch((e: Error) => toast(e.message));
  };
  const store = (id: string) => sellers.find((s) => s.id === id)?.storeName ?? id;

  const returns = orders.filter((o) => o.returnRequest).sort((a, b) => b.returnRequest!.at.localeCompare(a.returnRequest!.at));
  const refused = orders.filter((o) => (o.cancelReason || '').startsWith('Refused at doorstep'));
  const openReturns = returns.filter((o) => !['refunded', 'rejected'].includes(o.returnRequest!.status)).length;
  const openClaims = claims.filter((c) => ['submitted', 'approved'].includes(c.status)).length;
  const refundedTotal = returns.filter((o) => o.returnRequest!.status === 'refunded').reduce((s, o) => s + o.returnRequest!.refund, 0);

  const doReturn = (o: Order, action: string) => {
    const note = action === 'reject' ? window.prompt('Reason for rejecting (shown to the buyer):', 'Phone returned with new damage') : undefined;
    if (action === 'reject' && !note) return;
    act('POST', `/returns/${o.id}/${action}`, { note })
      .then(() => toast('Return updated - buyer & seller apps synced'))
      .catch((e: Error) => toast(e.message));
  };
  const doClaim = (c: Claim, action: string) => {
    const note =
      action === 'reject'
        ? window.prompt('Reason (shown to the buyer):', 'Physical / liquid damage is not covered')
        : action === 'resolve'
          ? window.prompt('Resolution note:', 'Speaker replaced, tested OK')
          : undefined;
    if (action === 'reject' && !note) return;
    act('POST', `/claims/${c.id}/${action}`, { note })
      .then(() => toast('Claim updated'))
      .catch((e: Error) => toast(e.message));
  };

  return (
    <>
      <PageHeader title="Returns & Claims" subtitle="7-day returns, doorstep refusals and warranty claims from GAMEX buyers." />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Open returns', openReturns, 'from-amber-500 to-orange-500', RotateCcw],
          ['Open warranty claims', openClaims, 'from-brand to-violet', Wrench],
          ['Refused at doorstep', refused.length, 'from-rose-500 to-pink-500', PackageX],
          ['Refunded', inr(refundedTotal), 'from-emerald-500 to-teal-500', Wallet],
        ].map(([l, v, g, I]) => {
          const Icon = I as typeof Wrench;
          return (
            <Card key={l as string} className="flex items-center gap-4">
              <div className={cx('grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br text-white', g as string)}>
                <Icon size={22} />
              </div>
              <div>
                <p className="text-sm text-muted">{l as string}</p>
                <p className="text-2xl font-extrabold text-ink">{v as string}</p>
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
            { id: 'returns', label: 'Returns', count: returns.length },
            { id: 'claims', label: 'Warranty claims', count: claims.length },
            { id: 'refused', label: 'Refused at door', count: refused.length },
            { id: 'refunds', label: 'Refunds', count: refunds.filter((o) => ['manual', 'failed', 'pending'].includes(o.refund!.status)).length },
          ]}
        />
      </div>

      {tab === 'returns' &&
        (returns.length === 0 ? (
          <Card>
            <Empty icon={RotateCcw} title="No returns" text="Buyers can return within the listing's return window after delivery." />
          </Card>
        ) : (
          <div className="grid gap-4 lg:grid-cols-2">
            {returns.map((o) => {
              const r = o.returnRequest!;
              return (
                <Card key={o.id}>
                  <div className="flex gap-3">
                    <img src={media(o.photo)} alt="" className="h-16 w-16 rounded-xl bg-slate-50 object-contain" />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <p className="truncate font-bold text-ink">{o.item}</p>
                        <Badge tone={returnTone[r.status]} dot>
                          {returnLabel[r.status]}
                        </Badge>
                      </div>
                      <p className="text-sm text-muted">
                        {o.id} • {o.buyer} • {store(o.sellerId)}
                      </p>
                      <p className="text-xs text-slate-400">Requested {ago(r.at)} • refund {inr(r.refund)}</p>
                    </div>
                  </div>
                  <div className="mt-3 rounded-xl bg-amber-50 px-3 py-2 text-sm">
                    <b className="text-amber-800">{r.reason}</b>
                    {r.details && <p className="text-amber-900/80">{r.details}</p>}
                    {r.pickupSlot && <p className="mt-1 text-xs text-amber-800">Pickup: {r.pickupSlot}</p>}
                  </div>
                  {r.note && <p className="mt-2 text-sm text-rose-600">Note: {r.note}</p>}
                  <Timeline events={r.events} />
                  <div className="mt-3 flex flex-wrap gap-2">
                    {r.status === 'requested' && (
                      <Button size="sm" icon={Truck} onClick={() => doReturn(o, 'approve')}>
                        Approve & schedule pickup
                      </Button>
                    )}
                    {r.status === 'pickup_scheduled' && (
                      <Button size="sm" icon={Truck} onClick={() => doReturn(o, 'pickup')}>
                        Mark picked up
                      </Button>
                    )}
                    {r.status === 'picked_up' && (
                      <Button size="sm" variant="success" icon={Wallet} onClick={() => doReturn(o, 'refund')}>
                        QC passed • issue refund
                      </Button>
                    )}
                    {['requested', 'pickup_scheduled'].includes(r.status) && (
                      <Button size="sm" variant="danger" icon={XCircle} onClick={() => doReturn(o, 'reject')}>
                        Reject
                      </Button>
                    )}
                  </div>
                </Card>
              );
            })}
          </div>
        ))}

      {tab === 'claims' &&
        (claims.length === 0 ? (
          <Card>
            <Empty icon={ShieldAlert} title="No warranty claims" text="Buyers raise claims from the digital warranty card in the GAMEX app." />
          </Card>
        ) : (
          <div className="grid gap-4 lg:grid-cols-2">
            {claims.map((c) => (
              <Card key={c.id}>
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="font-bold text-ink">{c.item}</p>
                    <p className="text-sm text-muted">
                      {c.id} • order {c.orderId} • {store(c.sellerId)}
                    </p>
                    <p className="font-mono text-xs text-slate-400">IMEI {c.imei}</p>
                  </div>
                  <Badge tone={claimTone[c.status]} dot>
                    {claimLabel[c.status]}
                  </Badge>
                </div>
                <div className="mt-3 rounded-xl bg-blue-50 px-3 py-2 text-sm">
                  <b className="text-blue-800">{c.issue}</b>
                  {c.description && <p className="text-blue-900/80">{c.description}</p>}
                </div>
                {c.note && <p className="mt-2 text-sm text-muted">Note: {c.note}</p>}
                <Timeline events={c.events} />
                <div className="mt-3 flex flex-wrap gap-2">
                  {c.status === 'submitted' && (
                    <Button size="sm" icon={Wrench} onClick={() => doClaim(c, 'approve')}>
                      Approve & arrange repair
                    </Button>
                  )}
                  {c.status === 'approved' && (
                    <Button size="sm" variant="success" icon={CheckCircle2} onClick={() => doClaim(c, 'resolve')}>
                      Mark resolved
                    </Button>
                  )}
                  {['submitted', 'approved'].includes(c.status) && (
                    <Button size="sm" variant="danger" icon={XCircle} onClick={() => doClaim(c, 'reject')}>
                      Reject
                    </Button>
                  )}
                </div>
              </Card>
            ))}
          </div>
        ))}

      {tab === 'refunds' &&
        (refunds.length === 0 ? (
          <Card>
            <Empty icon={Wallet} title="No refunds yet" text="Refunds start automatically for returns, doorstep refusals and cancelled prepaid orders." />
          </Card>
        ) : (
          <Card pad={false} className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-muted">
                <tr>
                  {['Order', 'Buyer', 'Amount', 'Reason', 'Status', ''].map((h) => (
                    <th key={h} className="px-4 py-3 font-semibold">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {refunds.map((o) => {
                  const r = o.refund!;
                  const tone: Record<string, 'green' | 'amber' | 'red' | 'blue' | 'slate'> = { processed: 'green', 'manual-done': 'green', pending: 'blue', manual: 'amber', failed: 'red', demo: 'slate' };
                  const label: Record<string, string> = {
                    processed: 'Refunded (Razorpay)',
                    'manual-done': 'Paid manually',
                    pending: 'Processing (Razorpay)',
                    manual: 'Pay to bank / UPI',
                    failed: 'Failed',
                    demo: 'Demo payment',
                  };
                  return (
                    <tr key={o.id} className="border-t border-slate-100">
                      <td className="px-4 py-3">
                        <p className="font-semibold text-ink">{o.id}</p>
                        <p className="text-xs text-muted">{o.item}</p>
                      </td>
                      <td className="px-4 py-3">
                        {o.buyer}
                        <p className="text-xs text-muted">{o.phone}</p>
                      </td>
                      <td className="px-4 py-3 font-bold">{inr(r.amount)}</td>
                      <td className="px-4 py-3 text-muted">{r.reason}</td>
                      <td className="px-4 py-3">
                        <Badge tone={tone[r.status]} dot>
                          {label[r.status]}
                        </Badge>
                        {r.id && <p className="mt-1 font-mono text-[11px] text-slate-400">{r.id}</p>}
                        {r.note && <p className="mt-1 text-xs text-muted">Ref {r.note}</p>}
                        {r.error && <p className="mt-1 text-xs text-rose-600">{r.error}</p>}
                      </td>
                      <td className="px-4 py-3 text-right">
                        {r.status === 'failed' && (
                          <Button size="sm" variant="secondary" onClick={() => refundAct(o, 'retry')}>
                            Retry
                          </Button>
                        )}
                        {['manual', 'failed', 'demo'].includes(r.status) && (
                          <Button size="sm" variant="success" className="ml-2" onClick={() => refundAct(o, 'manual-done')}>
                            Mark paid
                          </Button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </Card>
        ))}

      {tab === 'refused' &&
        (refused.length === 0 ? (
          <Card>
            <Empty icon={PackageX} title="No doorstep refusals" text="Buyers can refuse after the open-box check if the phone doesn't match." />
          </Card>
        ) : (
          <div className="grid gap-4 lg:grid-cols-2">
            {refused.map((o) => (
              <Card key={o.id} className="flex gap-3">
                <img src={media(o.photo)} alt="" className="h-16 w-16 rounded-xl bg-slate-50 object-contain" />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-bold text-ink">{o.item}</p>
                  <p className="text-sm text-muted">
                    {o.id} • {o.buyer} • {store(o.sellerId)}
                  </p>
                  <p className="mt-1 text-sm text-rose-600">{o.cancelReason?.replace('Refused at doorstep: ', '')}</p>
                  <p className="text-xs text-slate-400">{fmtDateTime(o.events[o.events.length - 1].a)}</p>
                </div>
              </Card>
            ))}
          </div>
        ))}
    </>
  );
}

function Timeline({ events }: { events: { l: string; a: string }[] }) {
  return (
    <div className="mt-3 space-y-1">
      {[...events].reverse().map((e, i) => (
        <div key={i} className="flex items-center gap-2 text-xs">
          <span className={cx('h-2 w-2 rounded-full', i === 0 ? 'bg-brand' : 'bg-slate-300')} />
          <span className="font-medium text-ink">{e.l}</span>
          <span className="text-slate-400">{fmtDateTime(e.a)}</span>
        </div>
      ))}
    </div>
  );
}
