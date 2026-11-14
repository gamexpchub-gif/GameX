import { useState } from 'react';
import { Plus, Ticket, Trash2 } from 'lucide-react';
import { Coupon, fmtDate, inr, log, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Field, PageHeader, Toggle, inputCls, toast } from '../ui';

export default function Coupons() {
  const coupons = useDB((d) => d.coupons);
  const [edit, setEdit] = useState<Coupon | null>(null);

  const save = () => {
    if (!edit) return;
    if (!/^[A-Z0-9]{4,15}$/.test(edit.code)) return toast('Code: 4–15 letters/numbers');
    if (edit.value <= 0) return toast('Enter a discount value');
    const isNew = !edit.id;
    const c = isNew ? { ...edit, id: crypto.randomUUID() } : edit;
    update((d) => ({ ...d, coupons: isNew ? [c, ...d.coupons] : d.coupons.map((x) => (x.id === c.id ? c : x)) }));
    log(`Coupon ${c.code} ${isNew ? 'created' : 'updated'}`, 'system');
    toast('Coupon saved');
    setEdit(null);
  };
  const set = <K extends keyof Coupon>(k: K, v: Coupon[K]) => setEdit((e) => (e ? { ...e, [k]: v } : e));

  return (
    <>
      <PageHeader
        title="Coupons"
        subtitle="Discount codes customers can apply at checkout."
        actions={
          <Button
            icon={Plus}
            onClick={() =>
              setEdit({ id: '', code: '', type: 'percent', value: 10, minOrder: 10000, maxDiscount: 2000, uses: 0, limit: 1000, expiresAt: new Date(Date.now() + 30 * 864e5).toISOString(), active: true })
            }
          >
            New coupon
          </Button>
        }
      />
      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        {coupons.map((c) => {
          const expired = new Date(c.expiresAt).getTime() < Date.now();
          const pct = Math.min(100, (c.uses / c.limit) * 100);
          return (
            <Card key={c.id} className="relative overflow-hidden">
              <div className="absolute -right-6 -top-6 h-24 w-24 rounded-full bg-gradient-to-br from-brand/10 to-violet/20" />
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className="grid h-11 w-11 place-items-center rounded-xl bg-gradient-to-br from-brand to-violet text-white">
                    <Ticket size={20} />
                  </div>
                  <div>
                    <p className="font-mono text-lg font-extrabold tracking-wider text-ink">{c.code}</p>
                    <p className="text-sm font-semibold text-brand">{c.type === 'percent' ? `${c.value}% off (max ${inr(c.maxDiscount)})` : `${inr(c.value)} off`}</p>
                  </div>
                </div>
                <Badge tone={expired ? 'red' : c.active ? 'green' : 'slate'} dot>
                  {expired ? 'Expired' : c.active ? 'Active' : 'Paused'}
                </Badge>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-2 text-sm">
                <div className="rounded-xl bg-slate-50 px-3 py-2">
                  <p className="text-xs text-muted">Min order</p>
                  <p className="font-semibold">{inr(c.minOrder)}</p>
                </div>
                <div className="rounded-xl bg-slate-50 px-3 py-2">
                  <p className="text-xs text-muted">Expires</p>
                  <p className="font-semibold">{fmtDate(c.expiresAt)}</p>
                </div>
              </div>
              <div className="mt-4">
                <div className="mb-1 flex justify-between text-xs">
                  <span className="text-muted">Redeemed</span>
                  <span className="font-semibold">
                    {c.uses.toLocaleString('en-IN')} / {c.limit.toLocaleString('en-IN')}
                  </span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-slate-100">
                  <div className="h-full rounded-full bg-gradient-to-r from-brand to-violet" style={{ width: `${pct}%` }} />
                </div>
              </div>
              <div className="mt-4 flex items-center justify-between">
                <Toggle checked={c.active} onChange={(v) => update((d) => ({ ...d, coupons: d.coupons.map((x) => (x.id === c.id ? { ...x, active: v } : x)) }))} />
                <div className="flex gap-2">
                  <Button size="sm" variant="secondary" onClick={() => setEdit({ ...c })}>
                    Edit
                  </Button>
                  <button
                    onClick={() => confirm(`Delete ${c.code}?`) && update((d) => ({ ...d, coupons: d.coupons.filter((x) => x.id !== c.id) }))}
                    className="rounded-lg p-2 text-muted hover:bg-rose-50 hover:text-rose-600"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            </Card>
          );
        })}
      </div>

      <Drawer
        open={!!edit}
        onClose={() => setEdit(null)}
        title={edit?.id ? `Edit ${edit.code}` : 'New coupon'}
        footer={
          <>
            <Button variant="secondary" onClick={() => setEdit(null)}>
              Cancel
            </Button>
            <Button onClick={save}>Save coupon</Button>
          </>
        }
      >
        {edit && (
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Field label="Code">
                <input className={inputCls + ' font-mono uppercase'} value={edit.code} onChange={(e) => set('code', e.target.value.toUpperCase().replace(/\s/g, ''))} placeholder="SAVE10" />
              </Field>
            </div>
            <Field label="Type">
              <select className={inputCls} value={edit.type} onChange={(e) => set('type', e.target.value as Coupon['type'])}>
                <option value="percent">Percentage</option>
                <option value="flat">Flat ₹</option>
              </select>
            </Field>
            <Field label={edit.type === 'percent' ? 'Discount %' : 'Discount ₹'}>
              <input type="number" className={inputCls} value={edit.value} onChange={(e) => set('value', Number(e.target.value))} />
            </Field>
            <Field label="Minimum order ₹">
              <input type="number" className={inputCls} value={edit.minOrder} onChange={(e) => set('minOrder', Number(e.target.value))} />
            </Field>
            <Field label="Max discount ₹">
              <input type="number" className={inputCls} value={edit.maxDiscount} onChange={(e) => set('maxDiscount', Number(e.target.value))} />
            </Field>
            <Field label="Usage limit">
              <input type="number" className={inputCls} value={edit.limit} onChange={(e) => set('limit', Number(e.target.value))} />
            </Field>
            <Field label="Expires on">
              <input
                type="date"
                className={inputCls}
                value={edit.expiresAt.slice(0, 10)}
                onChange={(e) => e.target.value && set('expiresAt', new Date(e.target.value).toISOString())}
              />
            </Field>
          </div>
        )}
      </Drawer>
    </>
  );
}
