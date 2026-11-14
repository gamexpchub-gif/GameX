import { useState } from 'react';
import { Lock, Mail, ShieldCheck } from 'lucide-react';
import { login } from '../store';
import { Button, inputCls } from '../ui';

export default function Login() {
  const [email, setEmail] = useState('admin@gamex.in');
  const [pass, setPass] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.includes('@')) return setErr('Enter a valid email');
    if (!pass) return setErr('Enter your password');
    setErr('');
    setBusy(true);
    try {
      await login(email.trim(), pass);
    } catch (e) {
      setErr((e as Error).message);
      setBusy(false);
    }
  };

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      <div className="relative hidden overflow-hidden bg-ink lg:block">
        <div className="absolute -left-32 -top-32 h-[520px] w-[520px] rounded-full bg-brand/40 blur-[120px]" />
        <div className="absolute -bottom-40 right-0 h-[520px] w-[520px] rounded-full bg-violet/50 blur-[120px]" />
        <div className="relative flex h-full flex-col justify-between p-14 text-white">
          <div className="inline-flex w-fit rounded-xl bg-white px-3 py-2">
            <img src="/img/logo_gamex.png" alt="GAMEX" className="h-7" />
          </div>
          <div>
            <h1 className="max-w-md text-5xl font-extrabold leading-tight tracking-tight">Run the whole GAMEX marketplace from one place.</h1>
            <p className="mt-4 max-w-md text-lg text-slate-300">QC every phone, approve sellers, manage orders and customers — live with the Shop and Seller apps.</p>
            <div className="mt-10 grid max-w-lg grid-cols-3 gap-4">
              {[
                ['QC', 'Every listing checked'],
                ['KYC', 'Verified sellers only'],
                ['Live', 'Synced with both apps'],
              ].map(([v, l]) => (
                <div key={l} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <p className="text-2xl font-extrabold">{v}</p>
                  <p className="mt-1 text-xs text-slate-400">{l}</p>
                </div>
              ))}
            </div>
          </div>
          <p className="text-xs text-slate-500">© {new Date().getFullYear()} GAMEX • Buy Smart. Sell Smart.</p>
        </div>
      </div>
      <div className="flex items-center justify-center bg-[#F3F6FD] p-6">
        <form onSubmit={submit} className="w-full max-w-sm rounded-3xl border border-slate-200 bg-white p-8 shadow-card">
          <div className="mb-6 grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br from-brand to-violet text-white">
            <ShieldCheck />
          </div>
          <h2 className="text-2xl font-extrabold text-ink">Super Admin sign in</h2>
          <p className="mt-1 text-sm text-muted">Restricted area. Activity is logged.</p>
          <div className="mt-6 space-y-4">
            <div className="relative">
              <Mail size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input className={inputCls + ' pl-9'} value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
            </div>
            <div className="relative">
              <Lock size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input className={inputCls + ' pl-9'} type="password" value={pass} onChange={(e) => setPass(e.target.value)} placeholder="Password" />
            </div>
            {err && <p className="text-sm font-medium text-rose-600">{err}</p>}
            <Button type="submit" className="w-full" disabled={busy}>
              {busy ? 'Signing in…' : 'Sign in'}
            </Button>
          </div>
          <p className="mt-6 text-center text-xs text-slate-400">Default: admin@gamex.in / gamex@123 (change with ADMIN_PASSWORD)</p>
        </form>
      </div>
    </div>
  );
}
