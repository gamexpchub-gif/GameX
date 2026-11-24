import { useEffect, useMemo, useState } from 'react';
import QRCode from 'qrcode';
import {
  AlertTriangle,
  BadgeCheck,
  Battery,
  CheckCircle2,
  Clock,
  Fingerprint,
  ImageOff,
  Printer,
  QrCode,
  ShieldCheck,
  Store,
  XCircle,
  Crosshair,
  Ban,
  Trash2,
} from 'lucide-react';
import { Defect, Listing, act, ago, fmtDateTime, gradeLabel, inr, title, useDB, validImei, media } from '../store';
import { Badge, Button, Card, Drawer, Empty, PageHeader, SearchInput, Tabs, cx, inputCls, toast } from '../ui';
import { listingLabel, listingTone, sellerLabel, sellerTone } from '../status';

const INSPECTOR_CHECKS = [
  'Photos are real, clear & match the model',
  'IMEI screen photo matches the IMEI entered',
  'Condition grade matches the photos',
  'Battery health is believable for the grade',
  'Price is fair for this condition',
  'No stolen / blacklisted / locked device signs',
];
const REJECT_REASONS = [
  'Photos do not show the IMEI screen (*#06#). Please add one.',
  'Photos are blurry or look like stock images. Upload real photos.',
  'Condition grade does not match the photos.',
  'Price is far above the market rate for this condition.',
  'IMEI appears blacklisted / reported lost.',
];

type Tab = 'queue' | 'approved' | 'rejected';

export default function QcQueue() {
  const listings = useDB((d) => d.listings);
  const sellers = useDB((d) => d.sellers);
  const [tab, setTab] = useState<Tab>('queue');
  const [q, setQ] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const [cert, setCert] = useState<Listing | null>(null);
  const [showBlacklist, setShowBlacklist] = useState(false);
  const open = listings.find((l) => l.id === openId) ?? null;
  const sellerName = (id: string) => sellers.find((s) => s.id === id)?.storeName ?? id;

  const lists: Record<Tab, Listing[]> = {
    queue: listings.filter((l) => l.status === 'inReview').sort((a, b) => (a.submittedAt ?? a.createdAt).localeCompare(b.submittedAt ?? b.createdAt)),
    approved: listings.filter((l) => l.qc?.decision === 'approved').sort((a, b) => (b.qc!.at).localeCompare(a.qc!.at)),
    rejected: listings.filter((l) => l.status === 'rejected'),
  };
  const list = lists[tab].filter((l) => `${title(l)} ${l.id} ${l.imei} ${sellerName(l.sellerId)}`.toLowerCase().includes(q.toLowerCase()));
  const today = listings.filter((l) => l.qc && Date.now() - new Date(l.qc.at).getTime() < 864e5);
  const oldest = lists.queue[0];

  return (
    <>
      <PageHeader
        title="QC Checking"
        subtitle="Every phone a seller lists is inspected here before it appears in the GAMEX app."
        actions={
          <Button variant="secondary" icon={Ban} onClick={() => setShowBlacklist(true)}>
            IMEI Blacklist
          </Button>
        }
      />
      <div className="mb-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ['Waiting for QC', lists.queue.length, 'from-amber-500 to-orange-500', Clock],
          ['Checked today', today.length, 'from-brand to-violet', ShieldCheck],
          ['Approval rate', `${today.length ? Math.round((today.filter((l) => l.qc?.decision === 'approved').length * 100) / today.length) : 100}%`, 'from-emerald-500 to-teal-500', BadgeCheck],
          ['Oldest in queue', oldest ? ago(oldest.submittedAt ?? oldest.createdAt) : '—', 'from-rose-500 to-pink-500', AlertTriangle],
        ].map(([l, v, g, I]) => {
          const Icon = I as typeof Clock;
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

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Tabs
          value={tab}
          onChange={setTab}
          items={[
            { id: 'queue', label: 'Queue', count: lists.queue.length },
            { id: 'approved', label: 'Approved', count: lists.approved.length },
            { id: 'rejected', label: 'Rejected', count: lists.rejected.length },
          ]}
        />
        <div className="ml-auto">
          <SearchInput value={q} onChange={setQ} placeholder="Model, IMEI, seller…" />
        </div>
      </div>

      {list.length === 0 ? (
        <Card>
          <Empty icon={ShieldCheck} title={tab === 'queue' ? 'Queue is clear 🎉' : 'Nothing here'} text="New listings from the Seller app appear here instantly." />
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
          {list.map((l) => {
            const s = sellers.find((x) => x.id === l.sellerId);
            const dup = listings.some((x) => x.id !== l.id && x.imei === l.imei);
            return (
              <Card key={l.id} className="cursor-pointer transition hover:-translate-y-0.5 hover:shadow-lg" pad={false}>
                <div onClick={() => setOpenId(l.id)} className="p-4">
                  <div className="flex gap-4">
                    <div className="relative h-28 w-28 shrink-0 overflow-hidden rounded-2xl bg-gradient-to-br from-slate-50 to-blue-50">
                      {l.photos[0] ? <img src={media(l.photos[0])} alt="" className="h-full w-full object-contain p-2" /> : <ImageOff className="m-auto mt-10 text-slate-300" />}
                      <span className="absolute bottom-1.5 left-1.5 rounded-md bg-ink/80 px-1.5 py-0.5 text-[10px] font-bold text-white">{l.photos.length} photos</span>
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <p className="truncate font-bold text-ink">{title(l)}</p>
                        <Badge tone={listingTone[l.status]} dot>
                          {listingLabel[l.status]}
                        </Badge>
                      </div>
                      <p className="text-sm text-muted">
                        {l.ram} / {l.storage} • {l.color}
                      </p>
                      <p className="mt-1 text-lg font-extrabold">{inr(l.price)}</p>
                      <p className="flex items-center gap-1 text-xs text-muted">
                        <Store size={12} /> {s?.storeName ?? l.sellerId} • {ago(l.submittedAt ?? l.createdAt)}
                      </p>
                    </div>
                  </div>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <Badge tone="blue">{gradeLabel[l.grade]}</Badge>
                    {l.battery != null && <Badge tone={l.battery >= 85 ? 'green' : 'amber'}>Battery {l.battery}%</Badge>}
                    <Badge tone={validImei(l.imei) && !dup ? 'green' : 'red'}>{!validImei(l.imei) ? 'IMEI invalid' : dup ? 'IMEI duplicate' : 'IMEI valid'}</Badge>
                    {s && s.status !== 'approved' && <Badge tone={sellerTone[s.status]}>Seller {sellerLabel[s.status]}</Badge>}
                  </div>
                  {l.status === 'rejected' && l.rejectReason && <p className="mt-3 rounded-xl bg-rose-50 px-3 py-2 text-xs text-rose-700">{l.rejectReason}</p>}
                </div>
                <div className="flex gap-2 border-t border-slate-100 px-4 py-3">
                  {l.status === 'inReview' ? (
                    <Button size="sm" className="flex-1" icon={ShieldCheck} onClick={() => setOpenId(l.id)}>
                      Start inspection
                    </Button>
                  ) : l.certificate ? (
                    <Button size="sm" variant="secondary" className="flex-1" icon={QrCode} onClick={() => setCert(l)}>
                      QR certificate
                    </Button>
                  ) : (
                    <Button size="sm" variant="secondary" className="flex-1" onClick={() => setOpenId(l.id)}>
                      View details
                    </Button>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {open && <Inspection key={open.id} listing={open} onClose={() => setOpenId(null)} onCertified={(l) => setCert(l)} />}
      {showBlacklist && <BlacklistDrawer onClose={() => setShowBlacklist(false)} />}
      {cert && <Certificate listing={cert} seller={sellerName(cert.sellerId)} onClose={() => setCert(null)} />}
    </>
  );
}

function Inspection({ listing: l, onClose, onCertified }: { listing: Listing; onClose: () => void; onCertified: (l: Listing) => void }) {
  const listings = useDB((d) => d.listings);
  const sellers = useDB((d) => d.sellers);
  const sellerChecks = useDB((d) => d.checklist);
  const blacklist = useDB((d) => d.blacklist);
  const seller = sellers.find((s) => s.id === l.sellerId);
  const [photo, setPhoto] = useState(0);
  const [defects, setDefects] = useState<Defect[]>(l.defects ?? []);
  const [marking, setMarking] = useState(false);
  const [checks, setChecks] = useState<Record<string, boolean>>({});
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const dup = listings.filter((x) => x.id !== l.id && x.imei === l.imei);
  const market = useMemo(() => {
    const xs = listings.filter((x) => x.id !== l.id && x.model === l.model && x.storage === l.storage && ['active', 'soldOut'].includes(x.status));
    return xs.length ? xs.reduce((s, x) => s + x.price, 0) / xs.length : 0;
  }, [listings, l]);
  const priceDiff = market ? ((l.price - market) / market) * 100 : 0;
  const discount = l.mrp > l.price ? Math.round(((l.mrp - l.price) / l.mrp) * 100) : 0;
  const allChecked = INSPECTOR_CHECKS.every((c) => checks[c]);
  const pending = l.status === 'inReview';

  const auto = [
    { ok: validImei(l.imei), label: validImei(l.imei) ? 'IMEI passes checksum' : 'IMEI fails checksum', icon: Fingerprint },
    { ok: !blacklist.some((b) => b.imei === l.imei), label: blacklist.some((b) => b.imei === l.imei) ? 'IMEI is on the BLACKLIST' : 'IMEI not on blacklist', icon: Ban },
    { ok: dup.length === 0, label: dup.length ? `IMEI also on ${dup.map((d) => d.id).join(', ')}` : 'IMEI not listed elsewhere', icon: Fingerprint },
    { ok: l.photos.length >= 2, label: `${l.photos.length} photo(s) uploaded`, icon: ImageOff },
    ...(l.battery != null ? [{ ok: l.battery >= 80, label: `Battery health ${l.battery}%`, icon: Battery }] : []),
    { ok: !market || Math.abs(priceDiff) <= 15, label: market ? `Price ${priceDiff >= 0 ? '+' : ''}${priceDiff.toFixed(0)}% vs market ${inr(market)}` : 'No market comparison yet', icon: AlertTriangle },
    { ok: seller?.status === 'approved', label: seller ? `Seller ${sellerLabel[seller.status]}` : 'Unknown seller', icon: Store },
  ];

  const decide = async (decision: 'approve' | 'reject' | 'changes') => {
    if (decision !== 'approve' && !reason.trim()) return toast('Pick or write a reason for the seller');
    setBusy(true);
    try {
      const updated = await act<Listing>('POST', `/listings/${l.id}/qc`, { decision, reason, checks, defects, inspector: 'Super Admin' });
      toast(decision === 'approve' ? (seller?.status === 'approved' ? 'Approved — now live in the GAMEX app' : 'Approved — goes live once the seller passes KYC') : decision === 'changes' ? 'Changes requested — seller notified' : 'Rejected — seller notified');
      onClose();
      if (decision === 'approve') onCertified(updated);
    } catch (e) {
      toast((e as Error).message);
      setBusy(false);
    }
  };

  return (
    <Drawer
      open
      wide
      onClose={onClose}
      title={`QC • ${title(l)}`}
      footer={
        pending ? (
          <>
            <Button variant="danger" icon={XCircle} disabled={busy} onClick={() => decide('reject')}>
              Reject
            </Button>
            <Button variant="secondary" disabled={busy} onClick={() => decide('changes')}>
              Request changes
            </Button>
            <Button variant="success" icon={BadgeCheck} disabled={busy || !allChecked} onClick={() => decide('approve')}>
              {allChecked ? 'Approve & certify' : `Tick all ${INSPECTOR_CHECKS.length} checks`}
            </Button>
          </>
        ) : undefined
      }
    >
      <div className="space-y-5">
        <div className="grid gap-4 sm:grid-cols-[1fr_200px]">
          <div>
            <DefectPhoto
              src={l.photos[photo]}
              photoIndex={photo}
              defects={defects}
              marking={marking}
              onAdd={(d) => setDefects((x) => [...x, d])}
            />
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <Button size="sm" variant={marking ? 'primary' : 'secondary'} icon={Crosshair} onClick={() => setMarking((m) => !m)}>
                {marking ? 'Click the photo to mark' : 'Mark defects'}
              </Button>
              {!pending && (
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={() => act('PATCH', `/listings/${l.id}`, { defects }).then(() => toast('Defect markers saved - buyers see them on the inspection report'))}
                >
                  Save markers
                </Button>
              )}
              <span className="text-xs text-muted">{defects.length} marker(s) • shown to buyers</span>
            </div>
            {defects.length > 0 && (
              <div className="mt-2 space-y-1">
                {defects.map((d, i) => (
                  <div key={i} className="flex items-center gap-2 rounded-lg bg-rose-50 px-2 py-1 text-xs text-rose-700">
                    <span className="grid h-5 w-5 place-items-center rounded-full bg-rose-500 text-[10px] font-bold text-white">{i + 1}</span>
                    <span className="flex-1">
                      Photo {d.photo + 1}: {d.label}
                    </span>
                    <button onClick={() => setDefects((x) => x.filter((_, k) => k !== i))} className="font-bold hover:text-rose-900">
                      ✕
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
          <div className="space-y-2">
            <p className="text-2xl font-extrabold text-ink">{inr(l.price)}</p>
            <p className="text-sm text-muted">
              MRP <span className="line-through">{inr(l.mrp)}</span> • {discount}% off
            </p>
            <Badge tone="blue">{gradeLabel[l.grade]}</Badge>
            <p className="text-sm text-ink">
              {l.ram} / {l.storage}
              <br />
              {l.color}
            </p>
            <p className="font-mono text-xs text-muted">IMEI {l.imei}</p>
            <p className="text-xs text-muted">Stock {l.stock} • Warranty {l.warranty}M</p>
            <p className="text-xs text-muted">Submitted {fmtDateTime(l.submittedAt ?? l.createdAt)}</p>
          </div>
        </div>
        <div className="flex gap-2 overflow-x-auto">
          {l.photos.map((p, i) => (
            <button key={p + i} onClick={() => setPhoto(i)} className={cx('h-16 w-16 shrink-0 rounded-xl border-2 bg-slate-50 p-1', i === photo ? 'border-brand' : 'border-transparent')}>
              <img src={media(p)} alt="" className="h-full w-full object-contain" />
            </button>
          ))}
        </div>

        <div className="rounded-2xl border border-slate-200 p-4">
          <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted">Automatic checks</p>
          <div className="grid gap-2 sm:grid-cols-2">
            {auto.map((a) => (
              <div key={a.label} className={cx('flex items-center gap-2 rounded-xl px-3 py-2 text-sm', a.ok ? 'bg-emerald-50 text-emerald-800' : 'bg-rose-50 text-rose-700')}>
                {a.ok ? <CheckCircle2 size={16} /> : <AlertTriangle size={16} />}
                {a.label}
              </div>
            ))}
          </div>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Seller's function checks</p>
            {sellerChecks.map((c) => (
              <p key={c} className="flex items-center gap-2 py-0.5 text-sm">
                {l.checks?.[c] ? <CheckCircle2 size={14} className="text-emerald-600" /> : <XCircle size={14} className="text-rose-500" />} {c}
              </p>
            ))}
            <p className="mt-2 text-xs text-muted">In the box: {l.accessories?.length ? l.accessories.join(', ') : 'Phone only'}</p>
            {l.notes && <p className="mt-1 text-xs text-muted">Seller note: “{l.notes}”</p>}
            {!!l.variants?.length && (
              <div className="mt-3">
                <p className="text-xs font-bold uppercase tracking-wide text-muted">Variants ({l.variants.length + 1} options)</p>
                <div className="mt-1 space-y-1 text-xs">
                  <p>
                    <b>Main:</b> {l.ram} / {l.storage} • {l.color} — {inr(l.price)} • {l.stock} pcs
                  </p>
                  {l.variants.map((v) => (
                    <p key={v.id}>
                      {v.ram ? `${v.ram} / ` : ''}
                      {v.storage} • {v.color} — {inr(v.price)}
                      {v.mrp > v.price ? ` (MRP ${inr(v.mrp)})` : ''} • {v.stock} pcs
                    </p>
                  ))}
                </div>
              </div>
            )}
            {!!l.highlights?.length && (
              <div className="mt-3 flex gap-2 overflow-x-auto">
                {l.highlights.map((h, i) => (
                  <div key={i} className="w-28 shrink-0">
                    <img src={media(h.image)} alt="" className="h-20 w-28 rounded-lg object-cover" />
                    <p className="mt-1 truncate text-[11px] font-semibold">{h.title}</p>
                  </div>
                ))}
              </div>
            )}
            {!!l.specs?.length && (
              <details className="mt-3 text-xs">
                <summary className="cursor-pointer font-bold text-muted">Specifications ({l.specs.length})</summary>
                <table className="mt-1 w-full">
                  <tbody>
                    {l.specs.map((r, i) => (
                      <tr key={i} className="border-t border-slate-100">
                        <td className="py-1 pr-2 text-muted">{r.group}</td>
                        <td className="py-1 pr-2">{r.k}</td>
                        <td className="py-1 font-semibold">{r.v}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </details>
            )}
          </div>
          <div className="rounded-2xl border border-slate-200 p-4">
            <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Seller</p>
            <p className="font-bold text-ink">{seller?.storeName}</p>
            <p className="text-sm text-muted">
              {seller?.ownerName} • {seller?.city}
            </p>
            <p className="text-sm text-muted">{seller?.phone}</p>
            {seller && (
              <div className="mt-2 flex gap-2">
                <Badge tone={sellerTone[seller.status]}>{sellerLabel[seller.status]}</Badge>
                <Badge tone="slate">★ {seller.rating || 'New'}</Badge>
              </div>
            )}
            <p className="mt-2 text-xs text-muted">{listings.filter((x) => x.sellerId === l.sellerId).length} listings by this seller</p>
          </div>
        </div>

        {pending ? (
          <>
            <div className="rounded-2xl border-2 border-brand/30 bg-brand-50/40 p-4">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-brand">Inspector checklist</p>
              {INSPECTOR_CHECKS.map((c) => (
                <label key={c} className="flex cursor-pointer items-center gap-2 py-1 text-sm">
                  <input type="checkbox" className="h-4 w-4 accent-brand" checked={!!checks[c]} onChange={(e) => setChecks((x) => ({ ...x, [c]: e.target.checked }))} />
                  {c}
                </label>
              ))}
            </div>
            <div>
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Message to seller (for reject / changes)</p>
              <div className="mb-2 flex flex-wrap gap-2">
                {REJECT_REASONS.map((r) => (
                  <button key={r} onClick={() => setReason(r)} className={cx('rounded-full border px-3 py-1 text-xs', reason === r ? 'border-brand bg-brand-50 text-brand' : 'border-slate-200 text-muted')}>
                    {r.split('.')[0]}
                  </button>
                ))}
              </div>
              <textarea className={inputCls + ' h-20 py-2'} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Explain what needs to change…" />
            </div>
          </>
        ) : (
          l.qc && (
            <div className="rounded-2xl bg-slate-50 p-4 text-sm">
              <p className="font-bold text-ink">
                QC {l.qc.decision} by {l.qc.by}
              </p>
              <p className="text-muted">{fmtDateTime(l.qc.at)}</p>
              {l.qc.notes && <p className="mt-1 text-muted">{l.qc.notes}</p>}
            </div>
          )
        )}
      </div>
    </Drawer>
  );
}

export function Certificate({ listing: l, seller, onClose }: { listing: Listing; seller: string; onClose: () => void }) {
  const [qr, setQr] = useState('');
  const payload = `GAMEX-CERT|${l.certificate}|${l.id}|${l.imei}|${l.grade}|${l.battery}`;
  useEffect(() => {
    QRCode.toDataURL(payload, { width: 360, margin: 1, color: { dark: '#0B1230', light: '#FFFFFF' } }).then(setQr);
  }, [payload]);
  return (
    <div className="fixed inset-0 z-[55] grid place-items-center bg-ink/50 p-4 backdrop-blur-sm" onClick={onClose}>
      <div className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl" onClick={(e) => e.stopPropagation()}>
        <div id="cert" className="rounded-2xl border-2 border-ink p-5">
          <div className="flex items-center justify-between">
            <img src={media('/img/logo_gamex.png')} alt="GAMEX" className="h-6" />
            <span className="rounded-md bg-emerald-600 px-2 py-0.5 text-[10px] font-bold uppercase tracking-widest text-white">QC Passed</span>
          </div>
          <p className="mt-4 text-xs font-semibold uppercase tracking-widest text-muted">Certificate of inspection</p>
          <p className="text-xl font-extrabold text-ink">{title(l)}</p>
          <p className="text-sm text-muted">
            {l.ram} / {l.storage} • {l.color}
          </p>
          <div className="mt-4 flex gap-4">
            {qr ? <img src={qr} alt="QR" className="h-36 w-36 rounded-lg" /> : <div className="h-36 w-36 rounded-lg bg-slate-100" />}
            <div className="space-y-1 text-sm">
              <p>
                <span className="text-muted">Cert no.</span>
                <br />
                <b className="font-mono">{l.certificate}</b>
              </p>
              <p>
                <span className="text-muted">IMEI</span>
                <br />
                <b className="font-mono text-xs">{l.imei}</b>
              </p>
              <p>
                <span className="text-muted">Grade • Battery</span>
                <br />
                <b>
                  {gradeLabel[l.grade]}{l.battery != null ? ` • ${l.battery}%` : ''}
                </b>
              </p>
            </div>
          </div>
          <p className="mt-3 text-xs text-muted">
            Seller: {seller} • Checked {l.qc ? fmtDateTime(l.qc.at) : ''} by {l.qc?.by}
          </p>
        </div>
        <div className="mt-4 flex gap-2">
          <Button variant="secondary" className="flex-1" onClick={onClose}>
            Close
          </Button>
          <Button
            className="flex-1"
            icon={Printer}
            onClick={() => {
              const w = window.open('', '_blank', 'width=480,height=640');
              if (!w) return;
              w.document.write(`<html><head><title>${l.certificate}</title></head><body style="font-family:Inter,Arial;padding:24px">
                <h2 style="margin:0">GAMEX • QC Passed</h2><p>${title(l)} — ${l.ram} / ${l.storage} • ${l.color}</p>
                <img src="${qr}" width="220"/><p><b>${l.certificate}</b><br/>IMEI ${l.imei}<br/>${gradeLabel[l.grade]}${l.battery != null ? ` • Battery ${l.battery}%` : ''}</p>
                <script>window.onload=()=>window.print()</script></body></html>`);
              w.document.close();
            }}
          >
            Print label
          </Button>
        </div>
      </div>
    </div>
  );
}


/** Photo with numbered defect markers; click to add one while marking. */
function DefectPhoto({
  src,
  photoIndex,
  defects,
  marking,
  onAdd,
}: {
  src?: string;
  photoIndex: number;
  defects: Defect[];
  marking: boolean;
  onAdd: (d: Defect) => void;
}) {
  const [aspect, setAspect] = useState(1);
  if (!src) {
    return (
      <div className="grid h-72 place-items-center rounded-2xl bg-slate-50">
        <ImageOff className="text-slate-300" size={40} />
      </div>
    );
  }
  return (
    <div className="grid h-72 place-items-center overflow-hidden rounded-2xl bg-gradient-to-br from-slate-50 to-blue-50 p-4">
      <div
        className={cx('relative h-full max-w-full', marking && 'cursor-crosshair')}
        style={{ aspectRatio: aspect }}
        onClick={(e) => {
          if (!marking) return;
          const r = e.currentTarget.getBoundingClientRect();
          const x = (e.clientX - r.left) / r.width;
          const y = (e.clientY - r.top) / r.height;
          const label = window.prompt('Describe this defect (buyers will see it):', 'Light scratch');
          if (label && label.trim()) onAdd({ photo: photoIndex, x: Math.round(x * 1000) / 1000, y: Math.round(y * 1000) / 1000, label: label.trim().slice(0, 80) });
        }}
      >
        <img
          src={media(src)}
          alt=""
          className="h-full w-full object-contain"
          onLoad={(e) => setAspect(e.currentTarget.naturalWidth / e.currentTarget.naturalHeight || 1)}
        />
        {defects.map((d, i) =>
          d.photo === photoIndex ? (
            <span
              key={i}
              title={d.label}
              className="absolute grid h-6 w-6 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border-2 border-white bg-rose-500 text-[11px] font-bold text-white shadow-lg"
              style={{ left: `${d.x * 100}%`, top: `${d.y * 100}%` }}
            >
              {i + 1}
            </span>
          ) : null,
        )}
      </div>
    </div>
  );
}

/** IMEI blacklist manager (lost / stolen / financed devices). */
export function BlacklistDrawer({ onClose }: { onClose: () => void }) {
  const list = useDB((d) => d.blacklist);
  const [imei, setImei] = useState('');
  const [reason, setReason] = useState('Reported stolen');
  const add = () =>
    act<{ removedListings: number }>('POST', '/blacklist', { imei, reason })
      .then((r) => {
        toast(r.removedListings ? `Blacklisted - ${r.removedListings} live listing removed` : 'IMEI blacklisted');
        setImei('');
      })
      .catch((e: Error) => toast(e.message));
  return (
    <Drawer open onClose={onClose} title="IMEI Blacklist">
      <div className="space-y-4">
        <p className="text-sm text-muted">
          Blacklisted phones can't be listed, fail QC, and show as <b>blacklisted</b> in the customer app's IMEI checker. Listings with the IMEI are removed
          immediately.
        </p>
        <div className="space-y-2 rounded-2xl border border-slate-200 p-4">
          <input className={inputCls + ' font-mono'} value={imei} onChange={(e) => setImei(e.target.value.replace(/\D/g, '').slice(0, 15))} placeholder="15-digit IMEI" />
          <select className={inputCls} value={reason} onChange={(e) => setReason(e.target.value)}>
            {['Reported stolen', 'Reported lost by owner', 'Financed device - EMI unpaid', 'Fraud / chargeback', 'Blocked on CEIR'].map((r) => (
              <option key={r}>{r}</option>
            ))}
          </select>
          <Button className="w-full" icon={Ban} disabled={imei.length !== 15} onClick={add}>
            Add to blacklist
          </Button>
        </div>
        <div className="space-y-2">
          {list.map((b) => (
            <div key={b.imei} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
              <div className="grid h-9 w-9 place-items-center rounded-lg bg-rose-50 text-rose-600">
                <Ban size={16} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-mono text-sm font-bold">{b.imei}</p>
                <p className="text-xs text-muted">
                  {b.reason} • {ago(b.at)}
                </p>
              </div>
              <button
                title="Remove"
                onClick={() => confirm(`Remove ${b.imei} from the blacklist?`) && act('DELETE', `/blacklist/${b.imei}`).then(() => toast('Removed'))}
                className="rounded-lg p-2 text-muted hover:bg-slate-100"
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))}
        </div>
      </div>
    </Drawer>
  );
}
