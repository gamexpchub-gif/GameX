import { useState } from 'react';
import { RotateCcw, Save } from 'lucide-react';
import { Settings as S, inr, log, resetDemo, update, useDB } from '../store';
import { Button, Card, Field, PageHeader, Toggle, inputCls, toast } from '../ui';

export default function Settings() {
  const settings = useDB((d) => d.settings);
  const [s, setS] = useState<S>(settings);
  const set = <K extends keyof S>(k: K, v: S[K]) => setS((x) => ({ ...x, [k]: v }));
  const dirty = JSON.stringify(s) !== JSON.stringify(settings);

  const row = (title: string, text: string, k: 'codEnabled' | 'liveReviewEnabled' | 'maintenance') => (
    <div className="flex items-center justify-between gap-4 py-3">
      <div>
        <p className="font-semibold text-ink">{title}</p>
        <p className="text-sm text-muted">{text}</p>
      </div>
      <Toggle checked={s[k]} onChange={(v) => set(k, v)} />
    </div>
  );

  return (
    <>
      <PageHeader
        title="Settings"
        subtitle="Store-wide configuration used by the GAMEX app."
        actions={
          <Button
            icon={Save}
            disabled={!dirty}
            onClick={() => {
              update((d) => ({ ...d, settings: s }));
              log('Store settings updated', 'system');
              toast('Settings saved');
            }}
          >
            Save changes
          </Button>
        }
      />
      <div className="grid gap-5 xl:grid-cols-2">
        <Card>
          <p className="mb-4 font-bold text-ink">Store profile</p>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Store name">
              <input className={inputCls} value={s.storeName} onChange={(e) => set('storeName', e.target.value)} />
            </Field>
            <Field label="GST %">
              <input type="number" className={inputCls} value={s.gstPercent} onChange={(e) => set('gstPercent', Number(e.target.value))} />
            </Field>
            <Field label="Support phone">
              <input className={inputCls} value={s.supportPhone} onChange={(e) => set('supportPhone', e.target.value)} />
            </Field>
            <Field label="Support email">
              <input className={inputCls} value={s.supportEmail} onChange={(e) => set('supportEmail', e.target.value)} />
            </Field>
          </div>
        </Card>
        <Card>
          <p className="mb-4 font-bold text-ink">Shipping & payments</p>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Free shipping above ₹" hint={`Orders under ${inr(s.freeShippingAbove)} pay shipping`}>
              <input type="number" className={inputCls} value={s.freeShippingAbove} onChange={(e) => set('freeShippingAbove', Number(e.target.value))} />
            </Field>
            <Field label="Shipping fee ₹">
              <input type="number" className={inputCls} value={s.shippingFee} onChange={(e) => set('shippingFee', Number(e.target.value))} />
            </Field>
            <Field label="COD fee ₹">
              <input type="number" className={inputCls} value={s.codFee} onChange={(e) => set('codFee', Number(e.target.value))} />
            </Field>
          </div>
          <div className="mt-2 divide-y divide-slate-100">{row('Cash on Delivery', 'Allow COD at checkout', 'codEnabled')}</div>
        </Card>
        <Card>
          <p className="mb-2 font-bold text-ink">Live Review</p>
          <div className="divide-y divide-slate-100">{row('Accept live review requests', 'Shows "Request Live View" on product pages', 'liveReviewEnabled')}</div>
          <div className="mt-3 grid grid-cols-2 gap-4">
            <Field label="Slots from (hour)">
              <input type="number" min={0} max={23} className={inputCls} value={s.liveHoursFrom} onChange={(e) => set('liveHoursFrom', Number(e.target.value))} />
            </Field>
            <Field label="Slots until (hour)">
              <input type="number" min={0} max={23} className={inputCls} value={s.liveHoursTo} onChange={(e) => set('liveHoursTo', Number(e.target.value))} />
            </Field>
          </div>
        </Card>
        <Card>
          <p className="mb-2 font-bold text-ink">Danger zone</p>
          <div className="divide-y divide-slate-100">
            {row('Maintenance mode', 'Temporarily close the store in the app', 'maintenance')}
            <div className="flex items-center justify-between gap-4 py-3">
              <div>
                <p className="font-semibold text-ink">Reset demo data</p>
                <p className="text-sm text-muted">Restore the sample products, orders and customers</p>
              </div>
              <Button
                variant="danger"
                icon={RotateCcw}
                onClick={() => {
                  if (confirm('Reset all admin data to the demo seed?')) {
                    resetDemo();
                    toast('Demo data restored');
                  }
                }}
              >
                Reset
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </>
  );
}
