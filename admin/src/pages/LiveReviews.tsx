import { useMemo, useState } from 'react';
import { CalendarClock, CheckCircle2, MessageCircle, Phone, PhoneCall, Radio, Store, Video, XCircle } from 'lucide-react';
import { LiveRequest, LiveStatus, fmtDateTime, log, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, Field, PageHeader, SearchInput, Tabs, cx, inputCls, toast } from '../ui';
import { cap, liveTone } from '../status';

const agents = ['Rohit (Mumbai Hub)', 'Sana (Delhi Hub)', 'Kiran (Bengaluru Hub)'];
const modeIcon = { 'Video Call': Video, 'WhatsApp Video': MessageCircle, 'Visit Store': Store };

export default function LiveReviews() {
  const live = useDB((d) => d.live);
  const [tab, setTab] = useState<'queue' | 'today' | LiveStatus>('queue');
  const [q, setQ] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const open = live.find((l) => l.id === openId) ?? null;

  const isToday = (s: string) => new Date(s).toDateString() === new Date().toDateString();
  const filters: Record<string, (l: LiveRequest) => boolean> = {
    queue: (l) => ['requested', 'scheduled', 'live'].includes(l.status),
    today: (l) => isToday(l.slot) && l.status !== 'cancelled',
    completed: (l) => l.status === 'completed',
    cancelled: (l) => l.status === 'cancelled',
  };
  const list = useMemo(
    () =>
      live
        .filter((l) => filters[tab](l) && `${l.id} ${l.customer} ${l.product} ${l.phone}`.toLowerCase().includes(q.toLowerCase()))
        .sort((a, b) => new Date(a.slot).getTime() - new Date(b.slot).getTime()),
    [live, tab, q],
  );

  const patch = (l: LiveRequest, p: Partial<LiveRequest>, msg: string) => {
    update((d) => ({ ...d, live: d.live.map((x) => (x.id === l.id ? { ...x, ...p } : x)) }));
    log(`Live review ${l.id}: ${msg}`, 'live');
    toast(msg);
  };

  const done = live.filter((l) => l.status === 'completed');
  const conv = done.length ? Math.round((done.filter((l) => l.converted).length / done.length) * 100) : 0;
  const cnt = (k: string) => live.filter(filters[k]).length;

  return (
    <>
      <PageHeader
        title="Live Reviews"
        subtitle="Customers asked to see a phone live before buying. Assign an expert and go live."
        actions={
          <span className="inline-flex items-center gap-2 rounded-xl bg-rose-50 px-3 py-2 text-sm font-bold text-rose-600">
            <Radio size={16} className="animate-pulse" /> {live.filter((l) => l.status === 'live').length} live now
          </span>
        }
      />

      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['New requests', live.filter((l) => l.status === 'requested').length, 'Awaiting confirmation', 'text-amber-600 bg-amber-50', CalendarClock],
          ['Scheduled', live.filter((l) => l.status === 'scheduled').length, 'Upcoming sessions', 'text-blue-600 bg-blue-50', Video],
          ['Completed', done.length, 'All time', 'text-emerald-600 bg-emerald-50', CheckCircle2],
          ['Conversion', `${conv}%`, 'Live view → purchase', 'text-violet bg-violet-50', PhoneCall],
        ].map(([l, v, h, c, Icon]) => {
          const I = Icon as typeof Video;
          return (
            <Card key={l as string} className="flex items-center gap-4">
              <div className={cx('grid h-12 w-12 place-items-center rounded-2xl', c as string)}>
                <I size={22} />
              </div>
              <div>
                <p className="text-sm text-muted">{l as string}</p>
                <p className="text-2xl font-extrabold text-ink">{v as string}</p>
                <p className="text-xs text-slate-400">{h as string}</p>
              </div>
            </Card>
          );
        })}
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Tabs
          value={tab}
          onChange={setTab}
          items={[
            { id: 'queue', label: 'Queue', count: cnt('queue') },
            { id: 'today', label: 'Today', count: cnt('today') },
            { id: 'completed', label: 'Completed', count: cnt('completed') },
            { id: 'cancelled', label: 'Cancelled', count: cnt('cancelled') },
          ]}
        />
        <div className="ml-auto">
          <SearchInput value={q} onChange={setQ} placeholder="Request ID, customer…" />
        </div>
      </div>

      {list.length === 0 ? (
        <Card>
          <Empty icon={Video} title="Nothing in this list" text="New live review requests from the app appear here instantly." />
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
          {list.map((l) => {
            const M = modeIcon[l.mode];
            return (
              <Card key={l.id} className={cx('cursor-pointer transition hover:-translate-y-0.5 hover:shadow-lg', l.status === 'live' && 'ring-2 ring-rose-400')}>
                <div onClick={() => setOpenId(l.id)}>
                  <div className="flex items-start gap-3">
                    <img src={l.image} alt="" className="h-16 w-16 rounded-xl bg-gradient-to-br from-slate-50 to-blue-50 object-contain p-1" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-bold text-ink">{l.product}</p>
                      <p className="text-sm text-muted">
                        {l.customer} • {l.language}
                      </p>
                      <p className="mt-1 text-xs text-slate-400">{l.id}</p>
                    </div>
                    <Badge tone={liveTone[l.status]} dot>
                      {l.status === 'live' ? 'LIVE' : cap(l.status)}
                    </Badge>
                  </div>
                  <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
                    <div className="flex items-center gap-2 rounded-xl bg-slate-50 px-3 py-2">
                      <M size={15} className="text-brand" /> <span className="font-medium">{l.mode}</span>
                    </div>
                    <div className="flex items-center gap-2 rounded-xl bg-slate-50 px-3 py-2">
                      <CalendarClock size={15} className="text-brand" />
                      <span className="font-medium">{fmtDateTime(l.slot)}</span>
                    </div>
                  </div>
                  {l.notes && <p className="mt-3 rounded-xl border border-dashed border-slate-200 px-3 py-2 text-sm text-muted">“{l.notes}”</p>}
                  {l.agent && <p className="mt-3 text-xs text-muted">Expert: <span className="font-semibold text-ink">{l.agent}</span></p>}
                </div>
                <div className="mt-4 flex gap-2">
                  {l.status === 'requested' && (
                    <Button size="sm" className="flex-1" onClick={() => patch(l, { status: 'scheduled', agent: l.agent ?? agents[0] }, 'Confirmed & scheduled')}>
                      Confirm slot
                    </Button>
                  )}
                  {l.status === 'scheduled' && (
                    <Button size="sm" className="flex-1 !from-rose-500 !to-pink-500" icon={Radio} onClick={() => patch(l, { status: 'live' }, 'Session is live')}>
                      Go live
                    </Button>
                  )}
                  {l.status === 'live' && (
                    <>
                      <Button size="sm" variant="success" className="flex-1" onClick={() => patch(l, { status: 'completed', converted: true }, 'Completed — customer purchased')}>
                        Bought
                      </Button>
                      <Button size="sm" variant="secondary" className="flex-1" onClick={() => patch(l, { status: 'completed', converted: false }, 'Completed')}>
                        No purchase
                      </Button>
                    </>
                  )}
                  {['requested', 'scheduled'].includes(l.status) && (
                    <Button size="sm" variant="ghost" icon={XCircle} onClick={() => patch(l, { status: 'cancelled' }, 'Request cancelled')}>
                      Cancel
                    </Button>
                  )}
                  {l.status === 'completed' && <Badge tone={l.converted ? 'green' : 'slate'}>{l.converted ? 'Converted to order' : 'Did not buy'}</Badge>}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Drawer open={!!open} onClose={() => setOpenId(null)} title={open ? `Live review ${open.id}` : ''}>
        {open && (
          <div className="space-y-5">
            <div className="rounded-2xl bg-gradient-to-br from-[#0E1033] via-[#2A1466] to-[#5B1E8F] p-5 text-white">
              <div className="flex items-center gap-4">
                <img src={open.image} alt="" className="h-20 w-20 rounded-xl bg-white/10 object-contain p-1" />
                <div>
                  <span className="rounded-md bg-rose-500 px-2 py-0.5 text-[10px] font-bold tracking-widest">LIVE REVIEW</span>
                  <p className="mt-2 font-bold">{open.product}</p>
                  <p className="text-sm text-violet-200">{fmtDateTime(open.slot)} • {open.mode}</p>
                </div>
              </div>
            </div>
            <div className="grid gap-3 rounded-2xl border border-slate-200 p-4 text-sm">
              <p className="font-bold text-ink">{open.customer}</p>
              <a href={`tel:${open.phone}`} className="flex items-center gap-2 font-medium text-brand">
                <Phone size={14} /> {open.phone}
              </a>
              <p className="text-muted">Preferred language: {open.language}</p>
              {open.notes && <p className="text-muted">Notes: {open.notes}</p>}
            </div>
            <Field label="Assigned expert">
              <select className={inputCls} value={open.agent ?? ''} onChange={(e) => patch(open, { agent: e.target.value }, `Assigned to ${e.target.value}`)}>
                <option value="" disabled>
                  Choose an expert…
                </option>
                {agents.map((a) => (
                  <option key={a}>{a}</option>
                ))}
              </select>
            </Field>
            <Field label="Reschedule">
              <input
                type="datetime-local"
                className={inputCls}
                defaultValue={new Date(new Date(open.slot).getTime() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16)}
                onChange={(e) => e.target.value && patch(open, { slot: new Date(e.target.value).toISOString(), status: 'scheduled' }, 'Rescheduled')}
              />
            </Field>
            <div className="rounded-2xl border border-slate-200 p-4">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Inspection checklist to show live</p>
              {['IMEI matches listing', 'Battery health in Settings', 'Screen — white & black test', 'Body — all four sides', 'Cameras — front & rear', 'Speakers, mic & Face ID/fingerprint'].map((c) => (
                <label key={c} className="flex items-center gap-2 py-1 text-sm">
                  <input type="checkbox" className="accent-brand" /> {c}
                </label>
              ))}
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
