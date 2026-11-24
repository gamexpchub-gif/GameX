import { useMemo, useRef, useState } from 'react';
import { ArrowDown, ArrowUp, CalendarClock, Edit3, ExternalLink, ImagePlus, Plus, Smartphone, Trash2 } from 'lucide-react';
import { BASE, Banner, log, update, useDB, media } from '../store';
import { Badge, Button, Card, Drawer, Field, PageHeader, Tabs, Toggle, cx, inputCls, toast } from '../ui';

const presets = ['hero_banner', 'hero_banner_violet', 'hero_banner_teal', 'hero_banner_magenta'].map((n) => `/img/${n}.png`);
const colours = ['#6D28D9', '#4F46E5', '#2563EB', '#0F766E', '#15803D', '#C2410C', '#E11D48', '#111827'];

/** Pages of the GAMEX app a banner button can open. */
const LINKS: [string, string][] = [
  ['/categories', 'All categories'],
  ['/explore', 'Explore all phones'],
  ['/category/apple', 'Brand: Apple'],
  ['/category/samsung', 'Brand: Samsung'],
  ['/category/oneplus', 'Brand: OnePlus'],
  ['/category/xiaomi', 'Brand: Xiaomi / Redmi'],
  ['/category/vivo', 'Brand: vivo'],
  ['/category/google', 'Brand: Google Pixel'],
  ['/sale', 'Flash sale'],
  ['/trade-in', 'Exchange / trade-in'],
  ['/sell', 'Sell your phone to GAMEX'],
  ['/repair', 'Book a repair'],
  ['/emi', 'EMI calculator'],
  ['/finder', 'Phone finder quiz'],
  ['/compare', 'Compare phones'],
  ['/trust', 'Trust & certificates'],
  ['/setup', 'Phone setup help'],
  ['/wallet', 'Wallet & referral'],
];

const blank = (placement: 'hero' | 'promo', order: number): Banner => ({
  id: '',
  title: '',
  subtitle: '',
  image: placement === 'hero' ? presets[0] : '',
  cta: placement === 'hero' ? 'Shop Now' : 'Open',
  link: '/categories',
  active: true,
  order,
  placement,
  color: colours[0],
  startsAt: null,
  endsAt: null,
});

const isLiveNow = (b: Banner) => {
  const t = new Date().toISOString();
  return b.active && (!b.startsAt || b.startsAt <= t) && (!b.endsAt || b.endsAt > t);
};
const toLocal = (iso?: string | null) => (iso ? new Date(new Date(iso).getTime() - new Date().getTimezoneOffset() * 6e4).toISOString().slice(0, 16) : '');
const fromLocal = (v: string) => (v ? new Date(v).toISOString() : null);

export default function Banners() {
  const raw = useDB((d) => d.banners);
  const [tab, setTab] = useState<'hero' | 'promo'>('hero');
  const banners = useMemo(() => [...raw].filter((b) => (b.placement || 'hero') === tab).sort((a, b) => a.order - b.order), [raw, tab]);
  const [edit, setEdit] = useState<Banner | null>(null);
  const [preview, setPreview] = useState(0);
  const [busy, setBusy] = useState(false);
  const file = useRef<HTMLInputElement>(null);
  const live = banners.filter(isLiveNow);
  const count = (p: 'hero' | 'promo') => raw.filter((b) => (b.placement || 'hero') === p).length;

  const save = () => {
    if (!edit) return;
    if (!edit.title.trim()) return toast('Title is required');
    if (edit.placement === 'hero' && !edit.image) return toast('Pick or upload an image');
    if (!edit.link.trim()) return toast('Choose what the button opens');
    if (edit.startsAt && edit.endsAt && edit.endsAt <= edit.startsAt) return toast('End time must be after the start time');
    const isNew = !edit.id;
    const b = isNew ? { ...edit, id: crypto.randomUUID(), order: Math.max(0, ...raw.map((x) => x.order)) + 1 } : edit;
    update((d) => ({ ...d, banners: isNew ? [...d.banners, b] : d.banners.map((x) => (x.id === b.id ? b : x)) }));
    log(`Banner "${b.title}" ${isNew ? 'created' : 'updated'}`, 'system');
    toast('Banner saved — live in the app');
    setEdit(null);
  };

  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= banners.length) return;
    const a = banners[i];
    const b = banners[j];
    update((d) => ({ ...d, banners: d.banners.map((x) => (x.id === a.id ? { ...x, order: b.order } : x.id === b.id ? { ...x, order: a.order } : x)) }));
  };

  const upload = async (f: File) => {
    if (f.size > 8 * 1024 * 1024) return toast('Image must be under 8 MB');
    setBusy(true);
    try {
      const fd = new FormData();
      fd.append('photo', f);
      const r = await fetch(`${BASE}/api/upload`, { method: 'POST', body: fd });
      const j = await r.json();
      if (!r.ok || !j.url) throw new Error(j.error || 'Upload failed');
      set('image', j.url);
      toast('Image uploaded');
    } catch (e) {
      toast((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const set = <K extends keyof Banner>(k: K, v: Banner[K]) => setEdit((e) => (e ? { ...e, [k]: v } : e));
  const shown = live[preview % Math.max(live.length, 1)];
  const linkLabel = (l: string) => LINKS.find(([p]) => p === l)?.[1] || l;

  return (
    <>
      <PageHeader
        title="Home Banners"
        subtitle="Top carousel slides automatically every 4 seconds. Promo cards appear lower on the home screen with a button."
        actions={
          <Button icon={Plus} onClick={() => setEdit(blank(tab, 0))}>
            {tab === 'hero' ? 'New banner' : 'New promo card'}
          </Button>
        }
      />
      <div className="mb-5">
        <Tabs
          value={tab}
          onChange={(v) => {
            setTab(v);
            setPreview(0);
          }}
          items={[
            { id: 'hero', label: 'Top carousel', count: count('hero') },
            { id: 'promo', label: 'Promo cards', count: count('promo') },
          ]}
        />
      </div>
      <div className="grid gap-6 xl:grid-cols-[1fr_340px]">
        <div className="space-y-4">
          {banners.length === 0 && (
            <Card>
              <p className="text-center text-sm text-muted">Nothing here yet. Press “{tab === 'hero' ? 'New banner' : 'New promo card'}”.</p>
            </Card>
          )}
          {banners.map((b, i) => (
            <Card key={b.id} className="flex flex-col gap-4 sm:flex-row sm:items-center">
              <div className="flex flex-row gap-1 sm:flex-col">
                <button onClick={() => move(i, -1)} disabled={i === 0} className="rounded-lg p-1.5 text-muted hover:bg-slate-100 disabled:opacity-30">
                  <ArrowUp size={16} />
                </button>
                <span className="self-center text-center text-xs font-bold text-muted">{i + 1}</span>
                <button onClick={() => move(i, 1)} disabled={i === banners.length - 1} className="rounded-lg p-1.5 text-muted hover:bg-slate-100 disabled:opacity-30">
                  <ArrowDown size={16} />
                </button>
              </div>
              {b.image ? (
                <img src={media(b.image)} alt="" className="h-28 w-full rounded-xl object-cover sm:w-64" />
              ) : (
                <div className="flex h-28 w-full flex-col justify-between rounded-xl p-3 text-white sm:w-64" style={{ background: `linear-gradient(135deg, ${b.color || colours[0]}, #111827)` }}>
                  <p className="text-sm font-extrabold leading-tight">{b.title}</p>
                  <span className="w-fit rounded-full bg-white px-2 py-0.5 text-[10px] font-bold" style={{ color: b.color }}>
                    {b.cta} →
                  </span>
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="font-bold text-ink">{b.title}</p>
                  <Badge tone={isLiveNow(b) ? 'green' : b.active ? 'amber' : 'slate'} dot>
                    {isLiveNow(b) ? 'Live' : b.active ? 'Scheduled' : 'Hidden'}
                  </Badge>
                </div>
                <p className="mt-1 text-sm text-muted">{b.subtitle}</p>
                <p className="mt-2 flex flex-wrap items-center gap-1 text-xs text-slate-500">
                  Button “{b.cta}” → <span className="font-semibold text-ink">{linkLabel(b.link)}</span>
                  {!b.link.startsWith('/') && <ExternalLink size={12} />}
                </p>
                {(b.startsAt || b.endsAt) && (
                  <p className="mt-1 flex items-center gap-1 text-xs text-slate-500">
                    <CalendarClock size={12} />
                    {b.startsAt ? new Date(b.startsAt).toLocaleString('en-IN') : 'now'} → {b.endsAt ? new Date(b.endsAt).toLocaleString('en-IN') : 'no end'}
                  </p>
                )}
              </div>
              <div className="flex items-center gap-2">
                <Toggle checked={b.active} onChange={(v) => update((d) => ({ ...d, banners: d.banners.map((x) => (x.id === b.id ? { ...x, active: v } : x)) }))} />
                <button onClick={() => setEdit({ ...b, placement: b.placement || 'hero' })} className="rounded-lg p-2 text-muted hover:bg-slate-100 hover:text-brand">
                  <Edit3 size={16} />
                </button>
                <button
                  onClick={() => confirm('Delete this banner?') && update((d) => ({ ...d, banners: d.banners.filter((x) => x.id !== b.id) }))}
                  className="rounded-lg p-2 text-muted hover:bg-rose-50 hover:text-rose-600"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </Card>
          ))}
        </div>

        <Card className="h-fit xl:sticky xl:top-0">
          <p className="flex items-center gap-2 font-bold text-ink">
            <Smartphone size={18} /> App preview
          </p>
          <div className="mx-auto mt-4 w-[260px] rounded-[36px] border-[10px] border-ink bg-[#EEF2FC] p-3 shadow-2xl">
            <div className="mx-auto mb-3 h-4 w-20 rounded-full bg-ink" />
            <img src={media('/img/logo_gamex.png')} alt="" className="h-5" />
            <div className="mt-2 h-7 rounded-full bg-white" />
            {tab === 'promo' && <div className="mt-3 h-24 rounded-2xl bg-white/70" />}
            {shown ? (
              tab === 'hero' ? (
                <div className="relative mt-3 overflow-hidden rounded-2xl">
                  <img src={media(shown.image)} alt="" className="h-32 w-full object-cover" />
                  <div className="absolute inset-0 bg-gradient-to-r from-ink/70 to-transparent p-3 text-white">
                    <p className="max-w-[60%] text-[13px] font-extrabold leading-tight">{shown.title}</p>
                    <p className="mt-1 max-w-[60%] text-[9px] opacity-80">{shown.subtitle}</p>
                    <span className="mt-2 inline-block rounded-full bg-brand px-2 py-1 text-[9px] font-bold">{shown.cta} →</span>
                  </div>
                </div>
              ) : (
                <div
                  className="relative mt-3 flex h-24 flex-col justify-between overflow-hidden rounded-2xl bg-cover bg-center p-3 text-white"
                  style={{ backgroundImage: shown.image ? `linear-gradient(90deg, #000a, #0000), url(${media(shown.image)})` : `linear-gradient(135deg, ${shown.color || colours[0]}, #111827)` }}
                >
                  <div>
                    <p className="text-[12px] font-extrabold leading-tight">{shown.title}</p>
                    <p className="mt-0.5 text-[8px] opacity-85">{shown.subtitle}</p>
                  </div>
                  <span className="w-fit rounded-full bg-white px-2 py-0.5 text-[9px] font-bold" style={{ color: shown.color }}>
                    {shown.cta} →
                  </span>
                </div>
              )
            ) : (
              <div className="mt-3 grid h-32 place-items-center rounded-2xl bg-white text-xs text-muted">No live banners</div>
            )}
            <div className="mt-2 flex justify-center gap-1">
              {live.map((b, i) => (
                <button key={b.id} onClick={() => setPreview(i)} className={cx('h-1.5 rounded-full', i === preview % live.length ? 'w-5 bg-brand' : 'w-1.5 bg-slate-300')} />
              ))}
            </div>
            <div className="mt-3 grid grid-cols-5 gap-1.5">
              {Array.from({ length: 10 }).map((_, i) => (
                <div key={i} className="aspect-square rounded-lg bg-white" />
              ))}
            </div>
          </div>
        </Card>
      </div>

      <Drawer
        open={!!edit}
        onClose={() => setEdit(null)}
        title={edit?.id ? 'Edit banner' : edit?.placement === 'promo' ? 'New promo card' : 'New banner'}
        footer={
          <>
            <Button variant="secondary" onClick={() => setEdit(null)}>
              Cancel
            </Button>
            <Button onClick={save}>Save banner</Button>
          </>
        }
      >
        {edit && (
          <div className="space-y-4">
            <Field label="Where it shows">
              <div className="grid grid-cols-2 gap-2">
                {(['hero', 'promo'] as const).map((p) => (
                  <button
                    key={p}
                    onClick={() => set('placement', p)}
                    className={cx('rounded-xl border-2 px-3 py-2 text-sm font-semibold', edit.placement === p ? 'border-brand bg-brand/5 text-brand' : 'border-slate-200 text-muted')}
                  >
                    {p === 'hero' ? 'Top carousel' : 'Promo card'}
                  </button>
                ))}
              </div>
            </Field>
            {edit.placement !== 'promo' && (
              <div className="grid grid-cols-2 gap-2">
                {presets.map((p) => (
                  <button key={p} onClick={() => set('image', p)} className={cx('overflow-hidden rounded-xl border-2', edit.image === p ? 'border-brand' : 'border-transparent')}>
                    <img src={media(p)} alt="" className="h-20 w-full object-cover" />
                  </button>
                ))}
              </div>
            )}
            <Field label={edit.placement === 'promo' ? 'Background image (optional)' : 'Or your own image'}>
              <div className="flex gap-2">
                <input className={inputCls} placeholder="Upload or paste an image URL" value={edit.image} onChange={(e) => set('image', e.target.value)} />
                <Button variant="secondary" icon={ImagePlus} disabled={busy} onClick={() => file.current?.click()}>
                  {busy ? 'Uploading…' : 'Upload'}
                </Button>
                <input ref={file} type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && upload(e.target.files[0])} />
              </div>
              {edit.image && !presets.includes(edit.image) && <img src={media(edit.image)} alt="" className="mt-2 h-24 w-full rounded-xl object-cover" />}
              <p className="mt-1 text-xs text-muted">{edit.placement === 'promo' ? 'Wide image, about 1000 × 400 px.' : 'About 1080 × 520 px, text on the left side.'}</p>
            </Field>
            {edit.placement === 'promo' && (
              <Field label="Card colour">
                <div className="flex flex-wrap gap-2">
                  {colours.map((c) => (
                    <button key={c} onClick={() => set('color', c)} className={cx('h-8 w-8 rounded-full ring-offset-2', edit.color === c && 'ring-2 ring-brand')} style={{ background: c }} />
                  ))}
                  <input type="color" value={edit.color || colours[0]} onChange={(e) => set('color', e.target.value)} className="h-8 w-10 cursor-pointer rounded" />
                </div>
              </Field>
            )}
            <Field label="Title">
              <input className={inputCls} value={edit.title} onChange={(e) => set('title', e.target.value)} />
            </Field>
            <Field label="Subtitle">
              <input className={inputCls} value={edit.subtitle} onChange={(e) => set('subtitle', e.target.value)} placeholder="Short line • separated • by dots" />
            </Field>
            <Field label="Button text">
              <input className={inputCls} value={edit.cta} onChange={(e) => set('cta', e.target.value)} />
            </Field>
            <Field label="Button opens">
              <select
                className={inputCls}
                value={LINKS.some(([p]) => p === edit.link) ? edit.link : '__custom'}
                onChange={(e) => set('link', e.target.value === '__custom' ? (edit.link.startsWith('/') && LINKS.some(([p]) => p === edit.link) ? 'https://' : edit.link) : e.target.value)}
              >
                {LINKS.map(([p, label]) => (
                  <option key={p} value={p}>
                    {label}
                  </option>
                ))}
                <option value="__custom">Custom link (web address or app path)…</option>
              </select>
              {!LINKS.some(([p]) => p === edit.link) && (
                <input className={cx(inputCls, 'mt-2')} value={edit.link} onChange={(e) => set('link', e.target.value)} placeholder="https://… or /product/GXL…" />
              )}
              <p className="mt-1 text-xs text-muted">App paths start with “/”. Web links open in the browser.</p>
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Show from (optional)">
                <input type="datetime-local" className={inputCls} value={toLocal(edit.startsAt)} onChange={(e) => set('startsAt', fromLocal(e.target.value))} />
              </Field>
              <Field label="Until (optional)">
                <input type="datetime-local" className={inputCls} value={toLocal(edit.endsAt)} onChange={(e) => set('endsAt', fromLocal(e.target.value))} />
              </Field>
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-slate-200 p-4">
              <p className="font-semibold text-ink">Show in app</p>
              <Toggle checked={edit.active} onChange={(v) => set('active', v)} />
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
