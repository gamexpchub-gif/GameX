import { useSyncExternalStore } from 'react';

// ---------- Types ----------
export type Grade = 'Like New' | 'Excellent' | 'Good' | 'Fair';
export type ProductStatus = 'active' | 'draft' | 'sold';

export interface Product {
  id: string;
  name: string;
  brand: string;
  variant: string;
  color: string;
  price: number;
  mrp: number;
  stock: number;
  grade: Grade;
  battery: number;
  imei: string;
  warrantyMonths: number;
  image: string;
  status: ProductStatus;
  featured: boolean;
  rating: number;
  sold: number;
  createdAt: string;
}

export type OrderStatus = 'pending' | 'confirmed' | 'packed' | 'shipped' | 'delivered' | 'cancelled' | 'returned';
export type PayMethod = 'UPI' | 'Card' | 'COD' | 'Wallet' | 'EMI';

export interface Order {
  id: string;
  customerId: string;
  customer: string;
  phone: string;
  city: string;
  productId: string;
  product: string;
  image: string;
  qty: number;
  amount: number;
  payment: PayMethod;
  paid: boolean;
  status: OrderStatus;
  createdAt: string;
  awb?: string;
}

export interface Customer {
  id: string;
  name: string;
  email: string;
  phone: string;
  city: string;
  orders: number;
  spent: number;
  joinedAt: string;
  status: 'active' | 'blocked';
  tier: 'Silver' | 'Gold' | 'Platinum';
}

export type LiveMode = 'Video Call' | 'WhatsApp Video' | 'Visit Store';
export type LiveStatus = 'requested' | 'scheduled' | 'live' | 'completed' | 'cancelled';

export interface LiveRequest {
  id: string;
  productId: string;
  product: string;
  image: string;
  customer: string;
  phone: string;
  mode: LiveMode;
  language: 'English' | 'Hindi';
  slot: string;
  notes: string;
  status: LiveStatus;
  agent?: string;
  converted?: boolean;
  createdAt: string;
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
  kind: 'order' | 'product' | 'live' | 'customer' | 'system';
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
}

export interface DB {
  products: Product[];
  orders: Order[];
  customers: Customer[];
  live: LiveRequest[];
  banners: Banner[];
  coupons: Coupon[];
  activity: Activity[];
  settings: Settings;
}

// ---------- Seed ----------
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
const pick = <T,>(a: T[]) => a[Math.floor(rnd() * a.length)];
const daysAgo = (d: number, h = 0) => new Date(Date.now() - d * 864e5 - h * 36e5).toISOString();
const imgs = ['deal_iphone14pro', 'deal_iphone_blue', 'deal_iphone_midnight', 'deal_iphone_purple', 'deal_iphone_starlight', 'deal_iphone_titanium'].map(
  (n) => `/img/${n}.png`,
);

const catalog: [string, string, string, string, number, number][] = [
  ['iPhone 14 Pro', 'Apple', '6GB / 128GB', 'Deep Purple', 49999, 69999],
  ['iPhone 15', 'Apple', '6GB / 128GB', 'Blue', 54999, 69900],
  ['iPhone 13', 'Apple', '4GB / 128GB', 'Midnight', 32999, 49900],
  ['iPhone 15 Pro Max', 'Apple', '8GB / 256GB', 'Natural Titanium', 104999, 159900],
  ['iPhone 14', 'Apple', '6GB / 128GB', 'Starlight', 41999, 59900],
  ['Galaxy S23 Ultra', 'Samsung', '12GB / 256GB', 'Phantom Black', 72699, 99999],
  ['Galaxy Z Flip5', 'Samsung', '8GB / 256GB', 'Lavender', 58299, 74999],
  ['Galaxy S24', 'Samsung', '8GB / 256GB', 'Onyx Black', 52999, 74999],
  ['Pixel 8 Pro', 'Google', '12GB / 128GB', 'Bay Blue', 61999, 84999],
  ['Pixel 7a', 'Google', '8GB / 128GB', 'Charcoal', 24999, 39999],
  ['OnePlus 12', 'OnePlus', '12GB / 256GB', 'Flowy Emerald', 45999, 64999],
  ['OnePlus Nord 4', 'OnePlus', '8GB / 256GB', 'Mercurial Silver', 23999, 32999],
  ['vivo X100 Pro', 'vivo', '16GB / 256GB', 'Asteroid Black', 55799, 84999],
  ['Xiaomi 14', 'Xiaomi', '12GB / 256GB', 'Jade Green', 40599, 62999],
  ['Realme GT 6', 'Realme', '12GB / 256GB', 'Fluid Silver', 34899, 46999],
  ['Nothing Phone (2)', 'Nothing', '12GB / 256GB', 'Dark Grey', 29999, 44999],
  ['Motorola Edge 50 Pro', 'Motorola', '12GB / 256GB', 'Luxe Lavender', 34899, 42999],
];
const grades: Grade[] = ['Like New', 'Excellent', 'Excellent', 'Good', 'Fair'];
const firstNames = ['Aarav', 'Vivaan', 'Aditya', 'Ishaan', 'Rohan', 'Ananya', 'Diya', 'Priya', 'Saanvi', 'Kavya', 'Arjun', 'Rahul', 'Neha', 'Sneha', 'Karan', 'Meera', 'Vikram', 'Pooja', 'Siddharth', 'Riya'];
const lastNames = ['Sharma', 'Verma', 'Patel', 'Iyer', 'Nair', 'Reddy', 'Gupta', 'Singh', 'Mehta', 'Kapoor', 'Das', 'Joshi'];
const cities = ['Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow'];

function buildSeed(): DB {
  seed = 7;
  const products: Product[] = catalog.map(([name, brand, variant, color, price, mrp], i) => ({
    id: `P${1001 + i}`,
    name,
    brand,
    variant,
    color,
    price,
    mrp,
    stock: i % 7 === 6 ? 0 : 1 + Math.floor(rnd() * 9),
    grade: pick(grades),
    battery: 82 + Math.floor(rnd() * 18),
    imei: `35${Math.floor(1e12 + rnd() * 9e12)}`,
    warrantyMonths: pick([3, 6, 6, 12]),
    image: imgs[i % imgs.length],
    status: i % 7 === 6 ? 'sold' : i === 16 ? 'draft' : 'active',
    featured: i < 5,
    rating: Math.round((4 + rnd()) * 10) / 10,
    sold: 20 + Math.floor(rnd() * 900),
    createdAt: daysAgo(i * 2),
  }));

  const customers: Customer[] = Array.from({ length: 28 }, (_, i) => {
    const name = `${pick(firstNames)} ${pick(lastNames)}`;
    return {
      id: `C${5001 + i}`,
      name,
      email: `${name.toLowerCase().replace(' ', '.')}${i}@mail.in`,
      phone: `+91 9${Math.floor(100000000 + rnd() * 899999999)}`,
      city: pick(cities),
      orders: 0,
      spent: 0,
      joinedAt: daysAgo(10 + Math.floor(rnd() * 300)),
      status: i === 9 ? 'blocked' : 'active',
      tier: 'Silver',
    };
  });

  const statuses: OrderStatus[] = ['delivered', 'delivered', 'delivered', 'shipped', 'packed', 'confirmed', 'pending', 'cancelled', 'returned', 'delivered'];
  const pays: PayMethod[] = ['UPI', 'UPI', 'UPI', 'Card', 'COD', 'Wallet', 'EMI'];
  const orders: Order[] = Array.from({ length: 64 }, (_, i) => {
    const c = pick(customers);
    const p = pick(products);
    const d = Math.floor((i / 64) * 30);
    const status = d < 2 ? pick<OrderStatus>(['pending', 'confirmed', 'packed']) : d < 5 ? pick<OrderStatus>(['shipped', 'packed', 'delivered']) : pick(statuses);
    const payment = pick(pays);
    const o: Order = {
      id: `GMX${(240000 + 1000 - i * 13).toString()}`,
      customerId: c.id,
      customer: c.name,
      phone: c.phone,
      city: c.city,
      productId: p.id,
      product: `${p.name} • ${p.variant}`,
      image: p.image,
      qty: 1,
      amount: p.price,
      payment,
      paid: payment !== 'COD' || status === 'delivered',
      status,
      createdAt: daysAgo(d, Math.floor(rnd() * 20)),
      awb: ['shipped', 'delivered'].includes(status) ? `BD${Math.floor(1e9 + rnd() * 9e9)}` : undefined,
    };
    if (status !== 'cancelled') {
      c.orders += 1;
      c.spent += o.amount;
    }
    return o;
  });
  customers.forEach((c) => (c.tier = c.spent > 150000 ? 'Platinum' : c.spent > 60000 ? 'Gold' : 'Silver'));

  const modes: LiveMode[] = ['Video Call', 'WhatsApp Video', 'Visit Store'];
  const liveStatuses: LiveStatus[] = ['requested', 'requested', 'scheduled', 'scheduled', 'live', 'completed', 'completed', 'completed', 'cancelled'];
  const live: LiveRequest[] = Array.from({ length: 18 }, (_, i) => {
    const p = products[i % products.length];
    const c = customers[(i * 3) % customers.length];
    const status = liveStatuses[i % liveStatuses.length];
    const slot = new Date();
    slot.setHours(10 + (i % 11), 0, 0, 0);
    slot.setDate(slot.getDate() + (status === 'completed' || status === 'cancelled' ? -1 - (i % 4) : i % 3));
    return {
      id: `LV${700100 + i * 37}`,
      productId: p.id,
      product: `${p.name} • ${p.variant}`,
      image: p.image,
      customer: c.name,
      phone: c.phone,
      mode: modes[i % 3],
      language: i % 3 === 1 ? 'Hindi' : 'English',
      slot: slot.toISOString(),
      notes: ['Check camera focus & speaker', 'Show battery health in settings', 'Any scratches on back glass?', '', 'Want to see Face ID working'][i % 5],
      status,
      agent: status === 'requested' ? undefined : pick(['Rohit (Mumbai Hub)', 'Sana (Delhi Hub)', 'Kiran (Bengaluru Hub)']),
      converted: status === 'completed' ? i % 2 === 0 : undefined,
      createdAt: daysAgo(i % 5, i),
    };
  });

  return {
    products,
    orders,
    customers,
    live,
    banners: [
      { id: 'b1', title: 'Premium Second-Hand Mobiles', subtitle: 'Trusted • Verified • Affordable', image: '/img/hero_banner.png', cta: 'Explore Now', link: '/categories', active: true, order: 1 },
      { id: 'b2', title: 'iPhone Fest — Up to 45% Off', subtitle: 'Certified iPhones with 6M warranty', image: '/img/hero_banner_violet.png', cta: 'Shop iPhones', link: '/category/apple', active: true, order: 2 },
      { id: 'b3', title: 'Exchange & Save More', subtitle: 'Get up to ₹15,000 on your old phone', image: '/img/hero_banner_teal.png', cta: 'Check Value', link: '/exchange', active: true, order: 3 },
      { id: 'b4', title: 'Flash Sale Friday', subtitle: 'Extra ₹2,000 off with UPI', image: '/img/hero_banner_magenta.png', cta: 'Grab Deals', link: '/category/all?flash=1', active: true, order: 4 },
    ],
    coupons: [
      { id: 'cp1', code: 'GAMEX10', type: 'percent', value: 10, minOrder: 20000, maxDiscount: 3000, uses: 412, limit: 1000, expiresAt: daysAgo(-20), active: true },
      { id: 'cp2', code: 'UPI500', type: 'flat', value: 500, minOrder: 10000, maxDiscount: 500, uses: 1290, limit: 5000, expiresAt: daysAgo(-45), active: true },
      { id: 'cp3', code: 'WELCOME', type: 'flat', value: 1000, minOrder: 15000, maxDiscount: 1000, uses: 233, limit: 2000, expiresAt: daysAgo(-90), active: true },
      { id: 'cp4', code: 'DIWALI25', type: 'percent', value: 25, minOrder: 40000, maxDiscount: 8000, uses: 980, limit: 1000, expiresAt: daysAgo(3), active: false },
    ],
    activity: [
      { id: 'a1', text: 'New order GMX241000 • iPhone 14 Pro', kind: 'order', at: daysAgo(0, 0.2) },
      { id: 'a2', text: 'Live review requested for Galaxy S23 Ultra', kind: 'live', at: daysAgo(0, 0.8) },
      { id: 'a3', text: 'Pixel 8 Pro stock updated to 4', kind: 'product', at: daysAgo(0, 2) },
      { id: 'a4', text: 'New customer Priya Nair joined', kind: 'customer', at: daysAgo(0, 3) },
      { id: 'a5', text: 'Order GMX240922 delivered in Pune', kind: 'order', at: daysAgo(0, 5) },
      { id: 'a6', text: 'Banner "Flash Sale Friday" published', kind: 'system', at: daysAgo(1, 1) },
    ],
    settings: {
      storeName: 'GAMEX',
      supportPhone: '+91 80 4718 2200',
      supportEmail: 'support@gamex.in',
      freeShippingAbove: 999,
      shippingFee: 120,
      codEnabled: true,
      codFee: 49,
      liveReviewEnabled: true,
      liveHoursFrom: 10,
      liveHoursTo: 21,
      maintenance: false,
      gstPercent: 18,
    },
  };
}

// ---------- Store ----------
const KEY = 'gamex_admin_db_v1';
let db: DB = (() => {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw) as DB;
  } catch {
    /* ignore */
  }
  return buildSeed();
})();
const listeners = new Set<() => void>();

function persist() {
  try {
    localStorage.setItem(KEY, JSON.stringify(db));
  } catch {
    /* ignore */
  }
}

export function update(fn: (d: DB) => DB) {
  db = fn(db);
  persist();
  listeners.forEach((l) => l());
}

export function log(text: string, kind: Activity['kind']) {
  update((d) => ({ ...d, activity: [{ id: crypto.randomUUID(), text, kind, at: new Date().toISOString() }, ...d.activity].slice(0, 40) }));
}

export function resetDemo() {
  db = buildSeed();
  persist();
  listeners.forEach((l) => l());
}

export function useDB<T>(sel: (d: DB) => T): T {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => sel(db),
  );
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
export const isRevenue = (o: Order) => !['cancelled', 'returned'].includes(o.status);
