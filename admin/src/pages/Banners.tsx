import { useMemo, useState } from 'react';
import { ArrowDown, ArrowUp, Edit3, Plus, Smartphone, Trash2 } from 'lucide-react';
import { Banner, log, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Field, PageHeader, Toggle, cx, inputCls, toast } from '../ui';

const presets = ['hero_banner', 'hero_banner_violet', 'hero_banner_teal', 'hero_banner_magenta'].map((n) => `/img/${n}.png`);

export default function Banners() {
  const raw = useDB((d) => d.banners);
  const banners = useMemo(() => [...raw].sort((a, b) => a.order - b.order), [raw]);
  const [edit, setEdit] = useState<Banner | null>(null);
  const [preview, setPreview] = useState(0);
  const active = banners.filter((b) => b.active);

  const save = () => {
    if (!edit) return;
    if (!edit.title.trim()) return toast('Title is required');
    const isNew = !edit.id;
    const b = isNew ? { ...edit, id: crypto.randomUUID(), order: banners.length + 1 } : edit;
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

  const set = <K extends keyof Banner>(k: K, v: Banner[K]) => setEdit((e) => (e ? { ...e, [k]: v } : e));
  const shown = active[preview % Math.max(active.length, 1)];

  return (
    <>
      <PageHeader
        title="Home Banners"
        subtitle="The hero carousel on the GAMEX app home screen. Drag order with the arrows."
        actions={
          <Button
            icon={Plus}
            onClick={() => setEdit({ id: '', title: '', subtitle: '', image: presets[0], cta: 'Shop Now', link: '/categories', active: true, order: 0 })}
          >
            New banner
          </Button>
        }
      />
      <div className="grid gap-6 xl:grid-cols-[1fr_340px]">
        <div className="space-y-4">
          {banners.map((b, i) => (
            <Card key={b.id} className="flex flex-col gap-4 sm:flex-row sm:items-center">
              <div className="flex flex-col gap-1">
                <button onClick={() => move(i, -1)} disabled={i === 0} className="rounded-lg p-1.5 text-muted hover:bg-slate-100 disabled:opacity-30">
                  <ArrowUp size={16} />
                </button>
                <span className="text-center text-xs font-bold text-muted">{i + 1}</span>
                <button onClick={() => move(i, 1)} disabled={i === banners.length - 1} className="rounded-lg p-1.5 text-muted hover:bg-slate-100 disabled:opacity-30">
                  <ArrowDown size={16} />
                </button>
              </div>
              <img src={b.image} alt="" className="h-28 w-full rounded-xl object-cover sm:w-64" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="font-bold text-ink">{b.title}</p>
                  <Badge tone={b.active ? 'green' : 'slate'} dot>
                    {b.active ? 'Live' : 'Hidden'}
                  </Badge>
                </div>
                <p className="mt-1 text-sm text-muted">{b.subtitle}</p>
                <p className="mt-2 text-xs text-slate-400">
                  Button “{b.cta}” → <span className="font-mono">{b.link}</span>
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Toggle checked={b.active} onChange={(v) => update((d) => ({ ...d, banners: d.banners.map((x) => (x.id === b.id ? { ...x, active: v } : x)) }))} />
                <button onClick={() => setEdit({ ...b })} className="rounded-lg p-2 text-muted hover:bg-slate-100 hover:text-brand">
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
            <img src="/img/logo_gamex.png" alt="" className="h-5" />
            <div className="mt-2 h-7 rounded-full bg-white" />
            {shown ? (
              <div className="relative mt-3 overflow-hidden rounded-2xl">
                <img src={shown.image} alt="" className="h-32 w-full object-cover" />
                <div className="absolute inset-0 bg-gradient-to-r from-ink/70 to-transparent p-3 text-white">
                  <p className="max-w-[60%] text-[13px] font-extrabold leading-tight">{shown.title}</p>
                  <p className="mt-1 max-w-[60%] text-[9px] opacity-80">{shown.subtitle}</p>
                  <span className="mt-2 inline-block rounded-full bg-brand px-2 py-1 text-[9px] font-bold">{shown.cta} →</span>
                </div>
              </div>
            ) : (
              <div className="mt-3 grid h-32 place-items-center rounded-2xl bg-white text-xs text-muted">No live banners</div>
            )}
            <div className="mt-2 flex justify-center gap-1">
              {active.map((b, i) => (
                <button key={b.id} onClick={() => setPreview(i)} className={cx('h-1.5 rounded-full', i === preview % active.length ? 'w-5 bg-brand' : 'w-1.5 bg-slate-300')} />
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
        title={edit?.id ? 'Edit banner' : 'New banner'}
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
            <div className="grid grid-cols-2 gap-2">
              {presets.map((p) => (
                <button key={p} onClick={() => set('image', p)} className={cx('overflow-hidden rounded-xl border-2', edit.image === p ? 'border-brand' : 'border-transparent')}>
                  <img src={p} alt="" className="h-20 w-full object-cover" />
                </button>
              ))}
            </div>
            <Field label="Or image URL">
              <input className={inputCls} value={edit.image} onChange={(e) => set('image', e.target.value)} />
            </Field>
            <Field label="Title">
              <input className={inputCls} value={edit.title} onChange={(e) => set('title', e.target.value)} />
            </Field>
            <Field label="Subtitle">
              <input className={inputCls} value={edit.subtitle} onChange={(e) => set('subtitle', e.target.value)} />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Button text">
                <input className={inputCls} value={edit.cta} onChange={(e) => set('cta', e.target.value)} />
              </Field>
              <Field label="Opens">
                <input className={inputCls} value={edit.link} onChange={(e) => set('link', e.target.value)} />
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
