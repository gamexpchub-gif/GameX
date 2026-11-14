import { useState } from 'react';
import { CalendarClock, CheckCircle2, MessageCircle, PhoneCall, Store, Video, XCircle } from 'lucide-react';
import { LiveCall, LiveStage, act, fmtDateTime, useDB, media } from '../store';
import { Badge, Button, Card, Empty, PageHeader, SearchInput, Tabs, cx, toast } from '../ui';
import { liveLabel, liveTone } from '../status';

const modeIcon: Record<string, typeof Video> = { 'Video Call': Video, 'WhatsApp Video': MessageCircle, 'Visit Store': Store };

export default function LiveReviews() {
  const live = useDB((d) => d.live);
  const sellers = useDB((d) => d.sellers);
  const [tab, setTab] = useState<'open' | LiveStage>('open');
  const [q, setQ] = useState('');
  const store = (id: string) => sellers.find((s) => s.id === id)?.storeName ?? id;

  const match = (l: LiveCall) => (tab === 'open' ? l.stage === 'pending' || l.stage === 'confirmed' : l.stage === tab);
  const list = live
    .filter((l) => match(l) && `${l.id} ${l.buyer} ${l.item} ${store(l.sellerId)}`.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => a.slot.localeCompare(b.slot));
  const done = live.filter((l) => l.stage === 'done');
  const conv = done.length ? Math.round((done.filter((l) => l.converted).length * 100) / done.length) : 0;
  const stale = live.filter((l) => l.stage === 'pending' && Date.now() - new Date(l.createdAt).getTime() > 2 * 36e5).length;

  const setStage = (l: LiveCall, stage: LiveStage) =>
    act('PATCH', `/live/${l.id}`, { stage }).then(() => toast(`${l.id} → ${liveLabel[stage]}`));

  return (
    <>
      <PageHeader title="Live Reviews" subtitle="Buyers asking to see a phone live before buying. Sellers handle them in the Seller app; you can step in." />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Waiting for seller', live.filter((l) => l.stage === 'pending').length, 'text-amber-600 bg-amber-50', CalendarClock],
          ['Confirmed', live.filter((l) => l.stage === 'confirmed').length, 'text-blue-600 bg-blue-50', Video],
          ['Completed', done.length, 'text-emerald-600 bg-emerald-50', CheckCircle2],
          ['Live → purchase', `${conv}%`, 'text-violet bg-violet-50', PhoneCall],
        ].map(([l, v, c, I]) => {
          const Icon = I as typeof Video;
          return (
            <Card key={l as string} className="flex items-center gap-4">
              <div className={cx('grid h-12 w-12 place-items-center rounded-2xl', c as string)}>
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
      {stale > 0 && <p className="mb-4 rounded-xl bg-rose-50 px-4 py-3 text-sm font-semibold text-rose-700">{stale} request(s) waiting more than 2 hours for the seller — consider calling them.</p>}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Tabs
          value={tab}
          onChange={setTab}
          items={[
            { id: 'open', label: 'Open', count: live.filter((l) => l.stage === 'pending' || l.stage === 'confirmed').length },
            { id: 'done', label: 'Completed', count: done.length },
            { id: 'declined', label: 'Declined', count: live.filter((l) => l.stage === 'declined').length },
          ]}
        />
        <div className="ml-auto">
          <SearchInput value={q} onChange={setQ} placeholder="Request, buyer, seller…" />
        </div>
      </div>
      {list.length === 0 ? (
        <Card>
          <Empty icon={Video} title="Nothing here" text="Live review requests from the GAMEX app appear here." />
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
          {list.map((l) => {
            const M = modeIcon[l.mode] ?? Video;
            return (
              <Card key={l.id}>
                <div className="flex items-start gap-3">
                  <img src={media(l.photo)} alt="" className="h-16 w-16 rounded-xl bg-gradient-to-br from-slate-50 to-blue-50 object-contain p-1" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-bold text-ink">{l.item}</p>
                    <p className="text-sm text-muted">
                      {l.buyer} • {l.language}
                    </p>
                    <p className="text-xs text-slate-400">
                      {l.id} • Seller: {store(l.sellerId)}
                    </p>
                  </div>
                  <Badge tone={liveTone[l.stage]} dot>
                    {l.stage === 'done' ? (l.converted ? 'Bought' : 'No sale') : liveLabel[l.stage]}
                  </Badge>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
                  <div className="flex items-center gap-2 rounded-xl bg-slate-50 px-3 py-2">
                    <M size={15} className="text-brand" /> {l.mode}
                  </div>
                  <div className="flex items-center gap-2 rounded-xl bg-slate-50 px-3 py-2">
                    <CalendarClock size={15} className="text-brand" /> {fmtDateTime(l.slot)}
                  </div>
                </div>
                {l.notes && <p className="mt-3 rounded-xl border border-dashed border-slate-200 px-3 py-2 text-sm text-muted">“{l.notes}”</p>}
                {(l.stage === 'pending' || l.stage === 'confirmed') && (
                  <div className="mt-4 flex gap-2">
                    {l.stage === 'pending' && (
                      <Button size="sm" className="flex-1" onClick={() => setStage(l, 'confirmed')}>
                        Confirm for seller
                      </Button>
                    )}
                    <Button size="sm" variant="ghost" icon={XCircle} onClick={() => setStage(l, 'declined')}>
                      Cancel
                    </Button>
                  </div>
                )}
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
