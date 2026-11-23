import { useSyncExternalStore } from 'react';

// ---------- Types (shared with the GAMEX server) ----------
export type Grade = 'likeNew' | 'excellent' | 'good' | 'fair';
export type ListingStatus = 'active' | 'inReview' | 'paused' | 'draft' | 'rejected' | 'soldOut';

export interface Listing {
  id: string;
  sellerId: string;
  brand: string;
  model: string;
  ram: string;
  storage: string;
  color: string;
  grade: Grade;
  battery: number;
  imei: string;
  price: number;
  mrp: number;
  stock: number;
  warranty: number;
  photos: string[];
  status: ListingStatus;
  createdAt: string;
  submittedAt?: string;
  approvedAt?: string;
  views: number;
  sold: number;
  checks: Record<string, boolean>;
  accessories: string[];
  notes: string;
  featured: boolean;
  rejectReason: string | null;
  certificate?: string;
  qc: { by: string; at: string; decision: string; notes?: string } | null;
  defects?: Defect[];
  returnDays?: number;
}

/** A marked cosmetic defect on a listing photo (x/y are 0..1). */
export interface Defect {
  photo: number;
  x: number;
  y: number;
  label: string;
}

export interface FlowEvent {
  l: string;
  a: string;
}

export type ReturnStatus = 'requested' | 'pickup_scheduled' | 'picked_up' | 'refunded' | 'rejected';
export interface ReturnRequest {
  id: string;
  reason: string;
  details: string;
  pickupSlot: string | null;
  status: ReturnStatus;
  refund: number;
  note?: string;
  at: string;
  events: FlowEvent[];
}

export type ClaimStatus = 'submitted' | 'approved' | 'resolved' | 'rejected';
export interface Claim {
  id: string;
  orderId: string;
  listingId: string;
  sellerId: string;
  customerId: string | null;
  item: string;
  imei: string;
  issue: string;
  description: string;
  status: ClaimStatus;
  note: string;
  at: string;
  events: FlowEvent[];
}

export interface BlacklistEntry {
  imei: string;
  reason: string;
  at: string;
}

export type OrderStage = 'newOrder' | 'accepted' | 'packed' | 'shipped' | 'delivered' | 'cancelled' | 'returned';

export interface Order {
  id: string;
  orderId: string;
  sellerId: string;
  customerId: string;
  listingId: string;
  item: string;
  variant: string;
  photo: string;
  price: number;
  buyer: string;
  phone: string;
  address: string;
  city: string;
  pincode: string;
  payment: string;
  stage: OrderStage;
  placedAt: string;
  events: { l: string; a: string }[];
  awb: string | null;
  courier: string | null;
  cancelReason: string | null;
  deliveredAt?: string | null;
  returnDays?: number;
  warrantyMonths?: number;
  imei?: string;
  returnRequest?: ReturnRequest | null;
}

export type SellerStatus = 'pending' | 'approved' | 'suspended';
export interface Seller {
  id: string;
  phone: string;
  ownerName: string;
  storeName: string;
  city: string;
  gstin: string;
  bank: string;
  status: SellerStatus;
  online: boolean;
  rating: number;
  createdAt: string;
  suspendReason?: string;
}

export interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string;
  city: string;
  status: 'active' | 'blocked';
  createdAt: string;
}

export type LiveStage = 'pending' | 'confirmed' | 'done' | 'declined';
export interface LiveCall {
  id: string;
  sellerId: string;
  listingId: string;
  item: string;
  photo: string;
  buyer: string;
  phone: string;
  mode: string;
  language: string;
  slot: string;
  notes: string;
  stage: LiveStage;
  converted: boolean | null;
  createdAt: string;
}

export interface Payout {
  id: string;
  sellerId: string;
  amount: number;
  orders: number;
  at: string;
  utr: string;
}

export interface Banner {
  id: string;
  title: string;
  subtitle: string;
  image: string;
  cta: string;
  link: string;
  active: boolean;
  order: number;
}

export interface Coupon {
  id: string;
  code: string;
  type: 'percent' | 'flat';
  value: number;
  minOrder: number;
  maxDiscount: number;
  uses: number;
  limit: number;
  expiresAt: string;
  active: boolean;
}

export interface Activity {
  id: string;
  text: string;
  kind: string;
  at: string;
}

export interface Notice {
  id: string;
  sellerId: string | null;
  title: string;
  body: string;
  kind: string;
  at: string;
}

export interface Settings {
  storeName: string;
  supportPhone: string;
  supportEmail: string;
  freeShippingAbove: number;
  shippingFee: number;
  codEnabled: boolean;
  codFee: number;
  liveReviewEnabled: boolean;
  liveHoursFrom: number;
  liveHoursTo: number;
  maintenance: boolean;
  gstPercent: number;
  commissionRate: number;
  fixedFee: number;
}

export interface DB {
  sellers: Seller[];
  listings: Listing[];
  customers: Customer[];
  orders: Order[];
  live: LiveCall[];
  payouts: Payout[];
  notifications: Notice[];
  banners: Banner[];
  coupons: Coupon[];
  settings: Settings;
  activity: Activity[];
  checklist: string[];
  blacklist: BlacklistEntry[];
  claims: Claim[];
}

const EMPTY: DB = {
  sellers: [],
  listings: [],
  customers: [],
  orders: [],
  live: [],
  payouts: [],
  notifications: [],
  banners: [],
  coupons: [],
  activity: [],
  checklist: [],
  blacklist: [],
  claims: [],
  settings: {
    storeName: 'GAMEX',
    supportPhone: '',
    supportEmail: '',
    freeShippingAbove: 0,
    shippingFee: 0,
    codEnabled: true,
    codFee: 0,
    liveReviewEnabled: true,
    liveHoursFrom: 10,
    liveHoursTo: 21,
    maintenance: false,
    gstPercent: 18,
    commissionRate: 0.08,
    fixedFee: 49,
  },
};

// ---------- Paths ----------
/** App base, e.g. "/gamex". API and media live under it too. */
export const BASE = import.meta.env.BASE_URL.replace(/\/$/, '');
/** Server path ("/img/..", "/uploads/..") -> URL under the app base. */
export const media = (p: string) => (p && p.startsWith('/') ? `${BASE}${p}` : p);

// ---------- Session + live store ----------
const TOKEN_KEY = 'gamex_admin_token';
const readToken = () => {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
};

interface State {
  db: DB;
  token: string | null;
  loaded: boolean;
  error: string | null;
  syncedAt: number;
}
let state: State = { db: EMPTY, token: readToken(), loaded: false, error: null, syncedAt: 0 };
const listeners = new Set<() => void>();
const set = (p: Partial<State>) => {
  state = { ...state, ...p };
  listeners.forEach((l) => l());
};

export class ApiError extends Error {
  constructor(
    msg: string,
    public status: number,
  ) {
    super(msg);
  }
}

export async function api<T = unknown>(method: string, path: string, body?: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${BASE}/api${path}`, {
      method,
      headers: { 'content-type': 'application/json', ...(state.token ? { authorization: `Bearer ${state.token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError('Cannot reach the GAMEX server', 0);
  }
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && path !== '/admin/login') logout();
  if (!res.ok) throw new ApiError(data.error || `Request failed (${res.status})`, res.status);
  return data as T;
}

export async function login(email: string, password: string) {
  const { token } = await api<{ token: string }>('POST', '/admin/login', { email, password });
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    /* ignore */
  }
  set({ token });
  await refresh();
}

export function logout() {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* ignore */
  }
  set({ token: null, loaded: false, db: EMPTY });
}

let inflight: Promise<void> | null = null;
export function refresh(): Promise<void> {
  if (!state.token) return Promise.resolve();
  inflight ??= api<DB>('GET', '/admin/db')
    .then((db) => set({ db, loaded: true, error: null, syncedAt: Date.now() }))
    .catch((e: Error) => set({ error: e.message }))
    .finally(() => (inflight = null));
  return inflight;
}

/** Runs an admin action, then re-syncs. */
export async function act<T = unknown>(method: string, path: string, body?: unknown): Promise<T> {
  const r = await api<T>(method, `/admin${path}`, body);
  await refresh();
  return r;
}

setInterval(() => {
  if (state.token && document.visibilityState === 'visible') refresh();
}, 10000);

const subscribe = (l: () => void) => {
  listeners.add(l);
  return () => listeners.delete(l);
};
export const useSession = () => useSyncExternalStore(subscribe, () => state);
export function useDB<T>(sel: (d: DB) => T): T {
  return useSyncExternalStore(subscribe, () => sel(state.db));
}

// ---------- Helpers ----------
export const inr = (n: number) => '₹' + Math.round(n).toLocaleString('en-IN');
export const inrShort = (n: number) =>
  n >= 1e7 ? `₹${(n / 1e7).toFixed(2)}Cr` : n >= 1e5 ? `₹${(n / 1e5).toFixed(2)}L` : n >= 1e3 ? `₹${(n / 1e3).toFixed(1)}K` : inr(n);
export const fmtDate = (s: string) => new Date(s).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
export const fmtDateTime = (s: string) =>
  new Date(s).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: 'numeric', minute: '2-digit' });
export const ago = (s: string) => {
  const m = Math.round((Date.now() - new Date(s).getTime()) / 60000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  if (m < 1440) return `${Math.round(m / 60)}h ago`;
  return `${Math.round(m / 1440)}d ago`;
};
export const isRevenue = (o: Order) => !['cancelled', 'returned'].includes(o.stage);
export const title = (l: Listing) => `${l.brand} ${l.model}`;
export const gradeLabel: Record<Grade, string> = { likeNew: 'Like New', excellent: 'Excellent', good: 'Good', fair: 'Fair' };

/** Luhn check for IMEI numbers. */
export function validImei(s: string) {
  if (!/^\d{15}$/.test(s)) return false;
  let sum = 0;
  for (let i = 0; i < 15; i++) {
    let n = Number(s[14 - i]);
    if (i % 2 === 1) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 === 0;
}

/**
 * Edits banners / coupons / settings: applies [fn] locally for an instant UI,
 * then saves whichever of those collections changed to the server.
 */
export function update(fn: (d: DB) => DB) {
  const before = state.db;
  const next = fn(before);
  set({ db: next });
  const saves: Promise<unknown>[] = [];
  if (next.banners !== before.banners) saves.push(api('PUT', '/admin/banners', next.banners));
  if (next.coupons !== before.coupons) saves.push(api('PUT', '/admin/coupons', next.coupons));
  if (next.settings !== before.settings) saves.push(api('PUT', '/admin/settings', next.settings));
  Promise.all(saves)
    .catch((e: Error) => set({ error: e.message }))
    .finally(() => refresh());
}

/** Activity is recorded by the server; kept for page compatibility. */
export function log(text: string, kind: string) {
  void text;
  void kind;
}

export const resetDemo = () => act('POST', '/reset');
