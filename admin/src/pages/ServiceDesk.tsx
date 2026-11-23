import { useState } from 'react';
import { CalendarClock, CheckCircle2, HandCoins, MessageCircleQuestion, Star, PackageCheck, Smartphone, Truck, UserCog, Wrench, XCircle } from 'lucide-react';
import { ServiceJob, act, ago, fmtDateTime, inr, useDB } from '../store';
import { Badge, Button, Card, Empty, PageHeader, Tabs, cx, toast } from '../ui';
import type { Tone } from '../ui';

const tone: Record<string, Tone> = {
  booked: 'blue',
  assigned: 'violet',
  inRepair: 'amber',
  completed: 'green',
  requested: 'blue',
  scheduled: 'violet',
  pickedUp: 'amber',
  paid: 'green',
  rejected: 'red',
  cancelled: 'slate',
};
const label: Record<string, string> = {
  booked: 'Booked',
  assigned: 'Technician assigned',
  inRepair: 'In repair',
  completed: 'Completed',
  requested: 'Pickup requested',
  scheduled: 'Pickup scheduled',
  pickedUp: 'Collected • inspecting',
  paid: 'Paid',
  rejected: 'Rejected',
  cancelled: 'Cancelled',
};
const modeLabel: Record<string, string> = { pickup: 'Pickup & drop', doorstep: 'Doorstep', store: 'Walk-in' };

export default function ServiceDesk() {
  const repairs = useDB((d) => d.repairs);
  const sells = useDB((d) => d.sellRequests);
  const [tab, setTab] = useState<'repairs' | 'sell' | 'qa' | 'reviews'>('repairs');
  const questions = useDB((d) => d.questions);
  const reviews = useDB((d) => d.reviews);
  const listings = useDB((d) => d.listings);
  const titleOf = (key: string) => {
    const l = listings.find((x) => x.id === key);
    return l ? `${l.brand} ${l.model}` : key;
  };

  const run = (kind: 'repairs' | 'sell-requests', j: ServiceJob, action: string) => {
    let body: Record<string, unknown> = {};
    if (action === 'assign') {
      const t = window.prompt('Technician name:', 'Ravi Kumar');
      if (!t) return;
      body = { technician: t };
    }
    if (action === 'pay') {
      const v = window.prompt(`Final amount (quote ${inr(j.quote ?? 0)}):`, String(j.quote ?? 0));
      if (!v) return;
      body = { finalAmount: Number(v) };
    }
    if (action === 'cancel' || action === 'reject') {
      const note = window.prompt('Reason (shown to the customer):', action === 'reject' ? 'Phone is iCloud locked' : 'Part not available');
      if (!note) return;
      body = { note };
    }
    act('POST', `/${kind}/${j.id}/${action}`, body)
      .then(() => toast('Updated - customer notified'))
      .catch((e: Error) => toast(e.message));
  };

  const open = (l: ServiceJob[], done: string[]) => l.filter((x) => !done.includes(x.status)).length;
  const revenue = repairs.filter((r) => r.status === 'completed').reduce((s, r) => s + (r.price ?? 0), 0);
  const bought = sells.filter((s) => s.status === 'paid').reduce((s, x) => s + (x.finalAmount ?? x.quote ?? 0), 0);

  return (
    <>
      <PageHeader title="Service Desk" subtitle="Repair bookings and phones customers are selling to GAMEX." />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Open repairs', open(repairs, ['completed', 'cancelled']), 'from-rose-500 to-pink-500', Wrench],
          ['Repair revenue', inr(revenue), 'from-brand to-violet', CheckCircle2],
          ['Open sell pickups', open(sells, ['paid', 'rejected', 'cancelled']), 'from-amber-500 to-orange-500', Truck],
          ['Phones bought', `${sells.filter((s) => s.status === 'paid').length} • ${inr(bought)}`, 'from-emerald-500 to-teal-500', HandCoins],
        ].map(([l, v, g, I]) => {
          const Icon = I as typeof Wrench;
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
            { id: 'repairs', label: 'Repairs', count: repairs.length },
            { id: 'sell', label: 'Sell to GAMEX', count: sells.length },
            { id: 'qa', label: 'Buyer Q&A', count: questions.filter((q) => !q.answer).length },
            { id: 'reviews', label: 'Reviews', count: reviews.length },
          ]}
        />
      </div>
      {tab === 'qa' && (
        <div className="grid gap-4 lg:grid-cols-2">
          {questions.length === 0 && (
            <Card>
              <Empty icon={MessageCircleQuestion} title="No questions yet" text="Buyers ask from the product page. Sellers answer in the seller app; GAMEX can answer here." />
            </Card>
          )}
          {questions.map((q) => (
            <Card key={q.id}>
              <p className="text-xs font-semibold text-muted">{titleOf(q.key)}</p>
              <p className="mt-1 font-bold text-ink">Q: {q.text}</p>
              <p className="text-xs text-slate-400">
                {q.author} • {ago(q.createdAt)}
              </p>
              {q.answer ? (
                <p className="mt-2 text-sm text-emerald-700">
                  A: {q.answer} <span className="text-slate-400">— {q.answeredBy}</span>
                </p>
              ) : (
                <div className="mt-3 flex gap-2">
                  <Button
                    size="sm"
                    icon={MessageCircleQuestion}
                    onClick={() => {
                      const a = window.prompt('Answer as GAMEX:');
                      if (a) act('POST', `/questions/${q.id}/answer`, { answer: a }).then(() => toast('Answer posted'));
                    }}
                  >
                    Answer as GAMEX
                  </Button>
                  <Button size="sm" variant="danger" icon={XCircle} onClick={() => act('PATCH', `/questions/${q.id}`, { hidden: true })}>
                    Hide
                  </Button>
                </div>
              )}
            </Card>
          ))}
        </div>
      )}

      {tab === 'reviews' && (
        <div className="grid gap-4 lg:grid-cols-2">
          {reviews.length === 0 && (
            <Card>
              <Empty icon={Star} title="No reviews yet" text="Reviews from buyers appear here. Verified buyers are marked automatically." />
            </Card>
          )}
          {reviews.map((r) => (
            <Card key={r.id} className={cx(r.hidden && 'opacity-50')}>
              <div className="flex items-start justify-between gap-2">
                <div>
                  <p className="font-bold text-ink">
                    {'★'.repeat(r.rating)}
                    <span className="text-slate-300">{'★'.repeat(5 - r.rating)}</span> {r.title}
                  </p>
                  <p className="text-xs text-muted">
                    {r.author} • {titleOf(r.key)} • {ago(r.createdAt)}
                  </p>
                </div>
                {r.verified ? <Badge tone="green" dot>Verified buyer</Badge> : <Badge tone="slate">Not verified</Badge>}
              </div>
              <p className="mt-2 text-sm text-ink">{r.body}</p>
              <div className="mt-3">
                <Button size="sm" variant={r.hidden ? 'secondary' : 'danger'} onClick={() => act('PATCH', `/reviews/${r.id}`, { hidden: !r.hidden })}>
                  {r.hidden ? 'Show again' : 'Hide review'}
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {(tab === 'qa' || tab === 'reviews') ? null : (tab === 'repairs' ? repairs : sells).length === 0 ? (
        <Card>
          <Empty
            icon={tab === 'repairs' ? Wrench : Smartphone}
            title={tab === 'repairs' ? 'No repair bookings yet' : 'No sell requests yet'}
            text={tab === 'repairs' ? 'Customers book repairs from the Repair section of the app.' : 'Customers get an instant quote and request a pickup from "Sell your phone".'}
          />
        </Card>
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          {(tab === 'repairs' ? repairs : sells).map((j) => {
            const repair = tab === 'repairs';
            const model = repair ? `${j.brand} ${j.model}` : `${j.device?.brand} ${j.device?.model} • ${j.device?.storage}`;
            return (
              <Card key={j.id}>
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate font-bold text-ink">{model}</p>
                    <p className="text-sm text-muted">
                      {j.id} • {j.name} • {j.phone}
                    </p>
                  </div>
                  <Badge tone={tone[j.status]} dot>
                    {label[j.status] ?? j.status}
                  </Badge>
                </div>
                <div className={cx('mt-3 rounded-xl px-3 py-2 text-sm', repair ? 'bg-rose-50 text-rose-900' : 'bg-emerald-50 text-emerald-900')}>
                  {repair ? (
                    <>
                      <b>{j.label}</b> • {j.quality === 'original' ? 'Original part' : 'Compatible part'} • {modeLabel[j.mode ?? 'pickup']} •{' '}
                      <b>{inr(j.price ?? 0)}</b>
                      {j.technician && <p className="text-xs">Technician: {j.technician}</p>}
                      {j.notes && <p className="text-xs italic">"{j.notes}"</p>}
                    </>
                  ) : (
                    <>
                      Quote <b>{inr(j.quote ?? 0)}</b>
                      {j.finalAmount != null && j.finalAmount !== j.quote && <> • final <b>{inr(j.finalAmount)}</b></>} • pay to{' '}
                      {j.payout?.method === 'upi' ? j.payout.upi : `bank ${j.payout?.account} (${j.payout?.ifsc})`}
                      <p className="text-xs">{Object.values(j.device?.answers ?? {}).join(' • ') || 'Working, flawless'}</p>
                    </>
                  )}
                </div>
                <p className="mt-2 flex items-center gap-1.5 text-sm text-muted">
                  <CalendarClock size={14} /> {fmtDateTime(j.slot)} • {j.address || 'Walk-in'} {j.city && `• ${j.city}`}
                </p>
                <ul className="mt-2 space-y-1 text-xs text-muted">
                  {[...j.events].reverse().slice(0, 3).map((e, i) => (
                    <li key={i} className="flex justify-between gap-2">
                      <span>{e.l}</span>
                      <span className="shrink-0 text-slate-400">{ago(e.a)}</span>
                    </li>
                  ))}
                </ul>
                <div className="mt-3 flex flex-wrap gap-2">
                  {repair && j.status === 'booked' && (
                    <Button size="sm" icon={UserCog} onClick={() => run('repairs', j, 'assign')}>
                      Assign technician
                    </Button>
                  )}
                  {repair && j.status === 'assigned' && (
                    <Button size="sm" icon={Wrench} onClick={() => run('repairs', j, 'start')}>
                      Start repair
                    </Button>
                  )}
                  {repair && j.status === 'inRepair' && (
                    <Button size="sm" variant="success" icon={CheckCircle2} onClick={() => run('repairs', j, 'complete')}>
                      Mark repaired
                    </Button>
                  )}
                  {repair && ['booked', 'assigned', 'inRepair'].includes(j.status) && (
                    <Button size="sm" variant="danger" icon={XCircle} onClick={() => run('repairs', j, 'cancel')}>
                      Cancel
                    </Button>
                  )}
                  {!repair && j.status === 'requested' && (
                    <Button size="sm" icon={Truck} onClick={() => run('sell-requests', j, 'schedule')}>
                      Schedule pickup
                    </Button>
                  )}
                  {!repair && j.status === 'scheduled' && (
                    <Button size="sm" icon={PackageCheck} onClick={() => run('sell-requests', j, 'pickup')}>
                      Mark collected
                    </Button>
                  )}
                  {!repair && j.status === 'pickedUp' && (
                    <Button size="sm" variant="success" icon={HandCoins} onClick={() => run('sell-requests', j, 'pay')}>
                      Inspected • pay customer
                    </Button>
                  )}
                  {!repair && ['requested', 'scheduled', 'pickedUp'].includes(j.status) && (
                    <Button size="sm" variant="danger" icon={XCircle} onClick={() => run('sell-requests', j, 'reject')}>
                      Reject
                    </Button>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
