import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import {
  Bell,
  ChevronDown,
  Image,
  LayoutDashboard,
  LogOut,
  Menu,
  Package,
  Settings as SettingsIcon,
  ShieldCheck,
  Store,
  ShoppingBag,
  Ticket,
  Users,
  Video,
} from 'lucide-react';
import { ago, logout, refresh, useDB, useSession } from './store';
import { cx } from './ui';
import Dashboard from './pages/Dashboard';
import Products from './pages/Products';
import Orders from './pages/Orders';
import Customers from './pages/Customers';
import LiveReviews from './pages/LiveReviews';
import Banners from './pages/Banners';
import Coupons from './pages/Coupons';
import Settings from './pages/Settings';
import Login from './pages/Login';
import QcQueue from './pages/QcQueue';
import Sellers from './pages/Sellers';

export default function App() {
  const session = useSession();
  if (!session.token) return <Login />;
  return <Shell />;
}

function Shell() {
  const session = useSession();
  useEffect(() => {
    refresh();
  }, []);
  const [mobileOpen, setMobileOpen] = useState(false);
  const pendingOrders = useDB((d) => d.orders.filter((o) => o.stage === 'newOrder').length);
  const pendingLive = useDB((d) => d.live.filter((l) => l.stage === 'pending').length);
  const pendingQc = useDB((d) => d.listings.filter((l) => l.status === 'inReview').length);
  const pendingSellers = useDB((d) => d.sellers.filter((x) => x.status === 'pending').length);
  const nav = [
    { to: '/', label: 'Dashboard', icon: LayoutDashboard },
    { to: '/qc', label: 'QC Checking', icon: ShieldCheck, badge: pendingQc, live: true },
    { to: '/orders', label: 'Orders', icon: ShoppingBag, badge: pendingOrders },
    { to: '/products', label: 'Products', icon: Package },
    { to: '/sellers', label: 'Sellers', icon: Store, badge: pendingSellers },
    { to: '/customers', label: 'Customers', icon: Users },
    { to: '/live', label: 'Live Reviews', icon: Video, badge: pendingLive },
    { to: '/banners', label: 'Home Banners', icon: Image },
    { to: '/coupons', label: 'Coupons', icon: Ticket },
    { to: '/settings', label: 'Settings', icon: SettingsIcon },
  ];
  const loc = useLocation();
  const current = nav.find((n) => (n.to === '/' ? loc.pathname === '/' : loc.pathname.startsWith(n.to)));

  const sidebar = (
    <aside className="flex h-full w-[264px] flex-col bg-ink text-white">
      <div className="flex items-center gap-3 px-6 pb-6 pt-7">
        <div className="rounded-xl bg-white px-2.5 py-1.5">
          <img src="/img/logo_gamex.png" alt="GAMEX" className="h-6" />
        </div>
        <span className="rounded-md bg-white/10 px-2 py-0.5 text-[10px] font-bold uppercase tracking-widest text-blue-200">Super Admin</span>
      </div>
      <p className="px-6 pb-2 text-[11px] font-semibold uppercase tracking-widest text-slate-500">Menu</p>
      <nav className="flex-1 space-y-1 px-3">
        {nav.map((n) => (
          <NavLink
            key={n.to}
            to={n.to}
            end={n.to === '/'}
            onClick={() => setMobileOpen(false)}
            className={({ isActive }) =>
              cx(
                'group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold transition',
                isActive ? 'bg-gradient-to-r from-brand to-violet text-white shadow-lg shadow-brand/30' : 'text-slate-300 hover:bg-white/5 hover:text-white',
              )
            }
          >
            <n.icon size={18} />
            <span className="flex-1">{n.label}</span>
            {!!n.badge && (
              <span className={cx('rounded-full px-2 py-0.5 text-[11px] font-bold', n.live ? 'bg-rose-500 text-white' : 'bg-white/15 text-white')}>{n.badge}</span>
            )}
          </NavLink>
        ))}
      </nav>
      <div className="m-3 rounded-2xl bg-gradient-to-br from-[#2A1466] to-[#5B1E8F] p-4">
        <p className="flex items-center gap-2 text-sm font-bold">
          <span className={cx('h-2 w-2 rounded-full', session.error ? 'bg-rose-400' : 'bg-emerald-400')} />
          {session.error ? 'Server offline' : 'Live with apps'}
        </p>
        <p className="mt-1 text-xs text-violet-200">
          {session.error ? session.error : `Shop & Seller apps synced • ${session.syncedAt ? ago(new Date(session.syncedAt).toISOString()) : '…'}`}
        </p>
      </div>
      <button onClick={logout} className="mx-3 mb-5 flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-slate-400 hover:bg-white/5 hover:text-white">
        <LogOut size={18} /> Sign out
      </button>
    </aside>
  );

  return (
    <div className="flex h-screen overflow-hidden bg-[#F3F6FD]">
      <div className="hidden lg:block">{sidebar}</div>
      {mobileOpen && (
        <div className="fixed inset-0 z-40 flex lg:hidden">
          <div className="absolute inset-0 bg-black/40" onClick={() => setMobileOpen(false)} />
          <div className="relative">{sidebar}</div>
        </div>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar title={current?.label ?? ''} onMenu={() => setMobileOpen(true)} />
        <main className="flex-1 overflow-y-auto px-4 py-6 sm:px-8">
          <div className="mx-auto max-w-[1400px]">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/qc" element={<QcQueue />} />
              <Route path="/sellers" element={<Sellers />} />
              <Route path="/orders" element={<Orders />} />
              <Route path="/products" element={<Products />} />
              <Route path="/live" element={<LiveReviews />} />
              <Route path="/customers" element={<Customers />} />
              <Route path="/banners" element={<Banners />} />
              <Route path="/coupons" element={<Coupons />} />
              <Route path="/settings" element={<Settings />} />
              <Route path="*" element={<Navigate to="/" />} />
            </Routes>
          </div>
        </main>
      </div>
    </div>
  );
}

function Topbar({ title, onMenu }: { title: string; onMenu: () => void }) {
  const [open, setOpen] = useState(false);
  const activity = useDB((d) => d.activity).slice(0, 6);
  const navigate = useNavigate();
  return (
    <header className="flex h-16 shrink-0 items-center gap-4 border-b border-slate-200/70 bg-white/80 px-4 backdrop-blur sm:px-8">
      <button onClick={onMenu} className="rounded-lg p-2 text-muted hover:bg-slate-100 lg:hidden">
        <Menu size={20} />
      </button>
      <div className="text-sm text-muted">
        GAMEX <span className="mx-1.5 text-slate-300">/</span>
        <span className="font-semibold text-ink">{title}</span>
      </div>
      <div className="ml-auto flex items-center gap-3">
        <span className="hidden items-center gap-2 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700 sm:inline-flex">
          <span className="h-2 w-2 animate-pulse rounded-full bg-emerald-500" /> Store live
        </span>
        <div className="relative">
          <button onClick={() => setOpen((v) => !v)} className="relative rounded-xl p-2.5 text-muted hover:bg-slate-100">
            <Bell size={18} />
            <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-rose-500 ring-2 ring-white" />
          </button>
          {open && (
            <div className="absolute right-0 top-12 z-30 w-80 rounded-2xl border border-slate-200 bg-white p-2 shadow-2xl">
              <p className="px-3 py-2 text-xs font-bold uppercase tracking-wide text-muted">Recent activity</p>
              {activity.map((a) => (
                <button
                  key={a.id}
                  onClick={() => {
                    setOpen(false);
                    navigate(
                      ({ order: '/orders', live: '/live', qc: '/qc', seller: '/sellers', payout: '/sellers', customer: '/customers' } as Record<string, string>)[a.kind] ?? '/',
                    );
                  }}
                  className="block w-full rounded-xl px-3 py-2 text-left hover:bg-slate-50"
                >
                  <p className="text-sm font-medium text-ink">{a.text}</p>
                  <p className="text-xs text-muted">{ago(a.at)}</p>
                </button>
              ))}
            </div>
          )}
        </div>
        <div className="flex items-center gap-3 rounded-xl py-1 pl-1 pr-2 hover:bg-slate-50">
          <div className="grid h-9 w-9 place-items-center rounded-xl bg-gradient-to-br from-brand to-violet text-sm font-bold text-white">SA</div>
          <div className="hidden leading-tight sm:block">
            <p className="text-sm font-bold text-ink">Super Admin</p>
            <p className="text-xs text-muted">Owner</p>
          </div>
          <ChevronDown size={16} className="text-muted" />
        </div>
      </div>
    </header>
  );
}
