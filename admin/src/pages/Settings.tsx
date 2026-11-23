import { useEffect, useState } from 'react';
import { CheckCircle2, CircleDashed, RotateCcw, Save, ShieldAlert } from 'lucide-react';
import { Settings as S, act, api, inr, log, resetDemo, update, useDB } from '../store';
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
        <LaunchCard />
      </div>
    </>
  );
}

type Cfg = { otp: string; payments: string; push: boolean; courier: boolean; cod: { enabled: boolean; newAccountLimit: number; maxOpen: number } };

/** Live-service status (keys live in /etc/gamex.env on the server) + COD fraud limits. */
function LaunchCard() {
  const settings = useDB((d) => d.settings) as unknown as { codLimitNew?: number; codMaxOpen?: number };
  const [cfg, setCfg] = useState<Cfg | null>(null);
  const deletions = useDB((d) => d.deletionRequests ?? []);
  const [limit, setLimit] = useState(settings.codLimitNew ?? 15000);
  const [maxOpen, setMaxOpen] = useState(settings.codMaxOpen ?? 2);
  useEffect(() => {
    api<Cfg>('GET', '/config').then(setCfg).catch(() => setCfg(null));
  }, []);
  const items: [string, boolean, string, string][] = cfg
    ? [
        ['SMS OTP login', cfg.otp === 'msg91' || cfg.otp === 'twilio', cfg.otp === 'dev' ? 'Test mode (codes shown in app)' : cfg.otp === 'off' ? 'Off - add MSG91 or Twilio keys' : `Live via ${cfg.otp}`, 'MSG91_AUTH_KEY, MSG91_TEMPLATE_ID'],
        ['Payment gateway', cfg.payments === 'razorpay', cfg.payments === 'razorpay' ? 'Razorpay live' : 'Demo payments', 'RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET'],
        ['Push notifications', cfg.push, cfg.push ? 'Firebase connected' : 'In-app only - add Firebase', 'FCM_SERVICE_ACCOUNT'],
        ['Courier', cfg.courier, cfg.courier ? 'Shiprocket connected' : 'Simulated tracking', 'SHIPROCKET_EMAIL, SHIPROCKET_PASSWORD'],
      ]
    : [];
  return (
    <Card className="xl:col-span-2">
      <p className="mb-1 font-bold text-ink">Launch setup</p>
      <p className="mb-4 text-sm text-muted">Live services switch on when their keys are added to /etc/gamex.env on the server (see deploy/gamex.env.example), then restart GAMEX.</p>
      <div className="grid gap-3 md:grid-cols-2">
        {items.map(([t, on, text, keys]) => (
          <div key={t} className="flex items-start gap-3 rounded-xl border border-slate-100 p-3">
            {on ? <CheckCircle2 className="mt-0.5 text-emerald-500" size={20} /> : <CircleDashed className="mt-0.5 text-amber-500" size={20} />}
            <div>
              <p className="font-semibold text-ink">{t}</p>
              <p className="text-sm text-muted">{text}</p>
              {!on && <p className="mt-1 font-mono text-[11px] text-slate-400">{keys}</p>}
            </div>
          </div>
        ))}
        {!cfg && <p className="text-sm text-muted">Loading…</p>}
      </div>
      <div className="mt-5 flex flex-wrap items-end gap-4 rounded-xl bg-amber-50 p-4">
        <ShieldAlert className="text-amber-600" size={22} />
        <div className="min-w-[200px] flex-1">
          <p className="font-semibold text-ink">COD fraud protection</p>
          <p className="text-sm text-muted">New accounts (no delivered order) can use COD only up to this amount. Accounts with 2+ doorstep refusals lose COD.</p>
        </div>
        <Field label="New-account COD limit (₹)">
          <input type="number" className={inputCls} value={limit} onChange={(e) => setLimit(Number(e.target.value))} />
        </Field>
        <Field label="Max open COD orders">
          <input type="number" className={inputCls} value={maxOpen} onChange={(e) => setMaxOpen(Number(e.target.value))} />
        </Field>
        <Button
          icon={Save}
          onClick={() =>
            act('PUT', '/launch-settings', { codLimitNew: limit, codMaxOpen: maxOpen })
              .then(() => toast(`COD limits saved • ${inr(limit)} for new accounts`))
              .catch((e: Error) => toast(e.message))
          }
        >
          Save limits
        </Button>
      </div>
      <div className="mt-5 grid gap-3 md:grid-cols-2">
        <div className="rounded-xl border border-slate-100 p-4">
          <p className="font-semibold text-ink">Play Store links</p>
          <p className="mt-1 text-sm text-muted">Use these in Play Console → App content.</p>
          {['privacy', 'terms', 'refund-policy', 'delete-account'].map((p) => (
            <p key={p} className="mt-1 font-mono text-xs text-brand">
              https://admin.deencircle.online/gamex/{p}
            </p>
          ))}
        </div>
        <div className="rounded-xl border border-slate-100 p-4">
          <p className="font-semibold text-ink">Account deletion requests ({deletions.length})</p>
          {deletions.length === 0 ? (
            <p className="mt-1 text-sm text-muted">None yet.</p>
          ) : (
            deletions.slice(0, 8).map((d) => (
              <p key={d.id} className="mt-1 text-sm text-ink">
                +91 {d.phone} • {new Date(d.at).toLocaleDateString('en-IN')} {d.reason && <span className="text-muted">• {d.reason}</span>}
              </p>
            ))
          )}
        </div>
      </div>
    </Card>
  );
}
