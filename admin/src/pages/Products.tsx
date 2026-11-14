import { useMemo, useState } from 'react';
import { Copy, Download, Edit3, LayoutGrid, List, Package, Plus, Star, Trash2 } from 'lucide-react';
import { Grade, Product, inr, log, update, useDB } from '../store';
import { Badge, Button, Card, Drawer, Empty, Field, PageHeader, SearchInput, Tabs, Td, Th, Toggle, cx, inputCls, toast } from '../ui';

const blank: Product = {
  id: '',
  name: '',
  brand: 'Apple',
  variant: '6GB / 128GB',
  color: '',
  price: 0,
  mrp: 0,
  stock: 1,
  grade: 'Excellent',
  battery: 90,
  imei: '',
  warrantyMonths: 6,
  image: '/img/deal_iphone14pro.png',
  status: 'draft',
  featured: false,
  rating: 4.5,
  sold: 0,
  createdAt: '',
};
const brands = ['Apple', 'Samsung', 'Google', 'OnePlus', 'vivo', 'Xiaomi', 'Realme', 'Nothing', 'Motorola'];
const grades: Grade[] = ['Like New', 'Excellent', 'Good', 'Fair'];
const gradeTone = { 'Like New': 'green', Excellent: 'blue', Good: 'violet', Fair: 'amber' } as const;
const images = ['deal_iphone14pro', 'deal_iphone_blue', 'deal_iphone_midnight', 'deal_iphone_purple', 'deal_iphone_starlight', 'deal_iphone_titanium'];

export default function Products() {
  const products = useDB((d) => d.products);
  const [q, setQ] = useState('');
  const [tab, setTab] = useState<'all' | 'active' | 'draft' | 'sold'>('all');
  const [brand, setBrand] = useState('All');
  const [view, setView] = useState<'table' | 'grid'>('table');
  const [edit, setEdit] = useState<Product | null>(null);
  const [sel, setSel] = useState<string[]>([]);

  const list = useMemo(
    () =>
      products.filter(
        (p) =>
          (tab === 'all' || p.status === tab) &&
          (brand === 'All' || p.brand === brand) &&
          `${p.name} ${p.id} ${p.imei} ${p.color}`.toLowerCase().includes(q.toLowerCase()),
      ),
    [products, q, tab, brand],
  );
  const count = (s: string) => products.filter((p) => s === 'all' || p.status === s).length;

  const save = () => {
    if (!edit) return;
    if (!edit.name.trim() || edit.price <= 0) return toast('Name and price are required');
    if (edit.mrp < edit.price) return toast('MRP must be ≥ selling price');
    const isNew = !edit.id;
    const p = isNew ? { ...edit, id: `P${1001 + products.length + Math.floor(Math.random() * 900)}`, createdAt: new Date().toISOString() } : edit;
    update((d) => ({ ...d, products: isNew ? [p, ...d.products] : d.products.map((x) => (x.id === p.id ? p : x)) }));
    log(`${isNew ? 'Added' : 'Updated'} product ${p.name}`, 'product');
    toast(isNew ? 'Product published' : 'Changes saved');
    setEdit(null);
  };

  const remove = (ids: string[]) => {
    if (!confirm(`Delete ${ids.length} product(s)? This cannot be undone.`)) return;
    update((d) => ({ ...d, products: d.products.filter((p) => !ids.includes(p.id)) }));
    setSel([]);
    toast('Deleted');
  };

  const bulkStatus = (status: Product['status']) => {
    update((d) => ({ ...d, products: d.products.map((p) => (sel.includes(p.id) ? { ...p, status } : p)) }));
    toast(`${sel.length} product(s) marked ${status}`);
    setSel([]);
  };

  const exportCsv = () => {
    const rows = [['ID', 'Name', 'Brand', 'Variant', 'Colour', 'Grade', 'Battery', 'IMEI', 'Price', 'MRP', 'Stock', 'Status']].concat(
      list.map((p) => [p.id, p.name, p.brand, p.variant, p.color, p.grade, `${p.battery}%`, p.imei, String(p.price), String(p.mrp), String(p.stock), p.status]),
    );
    const blob = new Blob([rows.map((r) => r.map((c) => `"${c}"`).join(',')).join('\n')], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'gamex-products.csv';
    a.click();
  };

  const set = <K extends keyof Product>(k: K, v: Product[K]) => setEdit((e) => (e ? { ...e, [k]: v } : e));

  return (
    <>
      <PageHeader
        title="Products"
        subtitle={`${products.length} listings • ${products.filter((p) => p.status === 'active').reduce((s, p) => s + p.stock, 0)} units in stock`}
        actions={
          <>
            <Button variant="secondary" icon={Download} onClick={exportCsv}>
              Export
            </Button>
            <Button icon={Plus} onClick={() => setEdit({ ...blank })}>
              Add product
            </Button>
          </>
        }
      />
      <Card pad={false}>
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-100 p-4">
          <Tabs
            value={tab}
            onChange={setTab}
            items={[
              { id: 'all', label: 'All', count: count('all') },
              { id: 'active', label: 'Active', count: count('active') },
              { id: 'draft', label: 'Draft', count: count('draft') },
              { id: 'sold', label: 'Sold out', count: count('sold') },
            ]}
          />
          <select value={brand} onChange={(e) => setBrand(e.target.value)} className={cx(inputCls, '!w-36')}>
            {['All', ...brands].map((b) => (
              <option key={b}>{b}</option>
            ))}
          </select>
          <div className="ml-auto flex items-center gap-2">
            <SearchInput value={q} onChange={setQ} placeholder="Search name, ID, IMEI…" />
            <div className="flex rounded-xl border border-slate-200 p-0.5">
              {(['table', 'grid'] as const).map((v) => (
                <button key={v} onClick={() => setView(v)} className={cx('rounded-lg p-2', view === v ? 'bg-slate-100 text-ink' : 'text-slate-400')}>
                  {v === 'table' ? <List size={16} /> : <LayoutGrid size={16} />}
                </button>
              ))}
            </div>
          </div>
        </div>
        {sel.length > 0 && (
          <div className="flex items-center gap-2 bg-brand-50 px-4 py-2.5 text-sm">
            <span className="font-semibold text-brand">{sel.length} selected</span>
            <Button size="sm" variant="secondary" onClick={() => bulkStatus('active')}>
              Publish
            </Button>
            <Button size="sm" variant="secondary" onClick={() => bulkStatus('draft')}>
              Move to draft
            </Button>
            <Button size="sm" variant="danger" icon={Trash2} onClick={() => remove(sel)}>
              Delete
            </Button>
          </div>
        )}
        {list.length === 0 ? (
          <Empty icon={Package} title="No products found" text="Try a different search or filter." />
        ) : view === 'table' ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th className="w-10">
                    <input
                      type="checkbox"
                      checked={sel.length === list.length}
                      onChange={(e) => setSel(e.target.checked ? list.map((p) => p.id) : [])}
                    />
                  </Th>
                  <Th>Product</Th>
                  <Th>Condition</Th>
                  <Th>Battery</Th>
                  <Th>Price</Th>
                  <Th>Stock</Th>
                  <Th>Status</Th>
                  <Th>Featured</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {list.map((p) => (
                  <tr key={p.id} className="hover:bg-slate-50/60">
                    <Td>
                      <input type="checkbox" checked={sel.includes(p.id)} onChange={(e) => setSel((s) => (e.target.checked ? [...s, p.id] : s.filter((x) => x !== p.id)))} />
                    </Td>
                    <Td>
                      <div className="flex items-center gap-3">
                        <img src={p.image} alt="" className="h-12 w-12 rounded-xl bg-slate-50 object-contain" />
                        <div>
                          <p className="font-semibold">{p.name}</p>
                          <p className="text-xs text-muted">
                            {p.id} • {p.variant} • {p.color}
                          </p>
                        </div>
                      </div>
                    </Td>
                    <Td>
                      <Badge tone={gradeTone[p.grade]}>{p.grade}</Badge>
                    </Td>
                    <Td>
                      <div className="flex items-center gap-2">
                        <div className="h-1.5 w-16 overflow-hidden rounded-full bg-slate-100">
                          <div className={cx('h-full rounded-full', p.battery >= 90 ? 'bg-emerald-500' : p.battery >= 85 ? 'bg-amber-500' : 'bg-rose-500')} style={{ width: `${p.battery}%` }} />
                        </div>
                        <span className="text-xs font-semibold">{p.battery}%</span>
                      </div>
                    </Td>
                    <Td>
                      <p className="font-bold">{inr(p.price)}</p>
                      <p className="text-xs text-muted line-through">{inr(p.mrp)}</p>
                    </Td>
                    <Td>
                      <span className={cx('font-semibold', p.stock === 0 ? 'text-rose-600' : p.stock <= 2 ? 'text-amber-600' : '')}>{p.stock}</span>
                    </Td>
                    <Td>
                      <Badge tone={p.status === 'active' ? 'green' : p.status === 'draft' ? 'slate' : 'red'} dot>
                        {p.status === 'sold' ? 'Sold out' : p.status === 'active' ? 'Active' : 'Draft'}
                      </Badge>
                    </Td>
                    <Td>
                      <Toggle
                        checked={p.featured}
                        onChange={(v) => update((d) => ({ ...d, products: d.products.map((x) => (x.id === p.id ? { ...x, featured: v } : x)) }))}
                      />
                    </Td>
                    <Td className="text-right">
                      <div className="flex justify-end gap-1">
                        <button title="Edit" onClick={() => setEdit({ ...p })} className="rounded-lg p-2 text-muted hover:bg-slate-100 hover:text-brand">
                          <Edit3 size={16} />
                        </button>
                        <button
                          title="Duplicate"
                          onClick={() => setEdit({ ...p, id: '', name: `${p.name} (copy)`, imei: '', status: 'draft' })}
                          className="rounded-lg p-2 text-muted hover:bg-slate-100 hover:text-brand"
                        >
                          <Copy size={16} />
                        </button>
                        <button title="Delete" onClick={() => remove([p.id])} className="rounded-lg p-2 text-muted hover:bg-rose-50 hover:text-rose-600">
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="grid gap-4 p-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {list.map((p) => (
              <div key={p.id} className="group rounded-2xl border border-slate-200 p-3 transition hover:shadow-card">
                <div className="relative rounded-xl bg-gradient-to-br from-slate-50 to-blue-50 p-4">
                  <img src={p.image} alt="" className="mx-auto h-40 object-contain" />
                  <div className="absolute left-2 top-2">
                    <Badge tone={gradeTone[p.grade]}>{p.grade}</Badge>
                  </div>
                  {p.featured && (
                    <Star size={18} className="absolute right-2 top-2 fill-amber-400 text-amber-400" />
                  )}
                </div>
                <p className="mt-3 font-bold text-ink">{p.name}</p>
                <p className="text-xs text-muted">
                  {p.variant} • {p.color}
                </p>
                <div className="mt-2 flex items-end justify-between">
                  <div>
                    <p className="text-lg font-extrabold">{inr(p.price)}</p>
                    <p className="text-xs text-muted">Stock {p.stock} • Battery {p.battery}%</p>
                  </div>
                  <Button size="sm" variant="secondary" icon={Edit3} onClick={() => setEdit({ ...p })}>
                    Edit
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      <Drawer
        open={!!edit}
        onClose={() => setEdit(null)}
        title={edit?.id ? `Edit ${edit.name}` : 'Add new product'}
        wide
        footer={
          <>
            <Button variant="secondary" onClick={() => setEdit(null)}>
              Cancel
            </Button>
            <Button onClick={save}>{edit?.id ? 'Save changes' : 'Publish product'}</Button>
          </>
        }
      >
        {edit && (
          <div className="space-y-5">
            <div>
              <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-muted">Photo</span>
              <div className="flex gap-2">
                {images.map((n) => {
                  const src = `/img/${n}.png`;
                  return (
                    <button
                      key={n}
                      onClick={() => set('image', src)}
                      className={cx('rounded-xl border-2 bg-slate-50 p-1', edit.image === src ? 'border-brand' : 'border-transparent')}
                    >
                      <img src={src} alt="" className="h-16 w-16 object-contain" />
                    </button>
                  );
                })}
              </div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Product name">
                <input className={inputCls} value={edit.name} onChange={(e) => set('name', e.target.value)} placeholder="iPhone 14 Pro" />
              </Field>
              <Field label="Brand">
                <select className={inputCls} value={edit.brand} onChange={(e) => set('brand', e.target.value)}>
                  {brands.map((b) => (
                    <option key={b}>{b}</option>
                  ))}
                </select>
              </Field>
              <Field label="RAM / Storage">
                <input className={inputCls} value={edit.variant} onChange={(e) => set('variant', e.target.value)} />
              </Field>
              <Field label="Colour">
                <input className={inputCls} value={edit.color} onChange={(e) => set('color', e.target.value)} />
              </Field>
              <Field label="Selling price (₹)">
                <input type="number" className={inputCls} value={edit.price || ''} onChange={(e) => set('price', Number(e.target.value))} />
              </Field>
              <Field label="MRP (₹)" hint={edit.mrp > edit.price && edit.price > 0 ? `${Math.round(((edit.mrp - edit.price) / edit.mrp) * 100)}% off shown in app` : undefined}>
                <input type="number" className={inputCls} value={edit.mrp || ''} onChange={(e) => set('mrp', Number(e.target.value))} />
              </Field>
              <Field label="Stock">
                <input type="number" className={inputCls} value={edit.stock} onChange={(e) => set('stock', Number(e.target.value))} />
              </Field>
              <Field label="Warranty (months)">
                <select className={inputCls} value={edit.warrantyMonths} onChange={(e) => set('warrantyMonths', Number(e.target.value))}>
                  {[0, 3, 6, 12].map((m) => (
                    <option key={m} value={m}>
                      {m === 0 ? 'No warranty' : `${m} months`}
                    </option>
                  ))}
                </select>
              </Field>
            </div>
            <div className="rounded-2xl border border-slate-200 p-4">
              <p className="font-bold text-ink">Condition & inspection</p>
              <div className="mt-3 flex flex-wrap gap-2">
                {grades.map((g) => (
                  <button
                    key={g}
                    onClick={() => set('grade', g)}
                    className={cx('rounded-xl border px-3 py-2 text-sm font-semibold', edit.grade === g ? 'border-brand bg-brand-50 text-brand' : 'border-slate-200 text-muted')}
                  >
                    {g}
                  </button>
                ))}
              </div>
              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                <Field label={`Battery health — ${edit.battery}%`}>
                  <input type="range" min={70} max={100} value={edit.battery} onChange={(e) => set('battery', Number(e.target.value))} className="w-full accent-brand" />
                </Field>
                <Field label="IMEI">
                  <input className={inputCls} value={edit.imei} onChange={(e) => set('imei', e.target.value.replace(/\D/g, '').slice(0, 15))} placeholder="15 digits" />
                </Field>
              </div>
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-slate-200 p-4">
              <div>
                <p className="font-semibold text-ink">Publish to app</p>
                <p className="text-xs text-muted">Visible in New Listings and search</p>
              </div>
              <Toggle checked={edit.status === 'active'} onChange={(v) => set('status', v ? 'active' : 'draft')} />
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-slate-200 p-4">
              <div>
                <p className="font-semibold text-ink">Featured on Home</p>
                <p className="text-xs text-muted">Shows in "Top Deals" rail</p>
              </div>
              <Toggle checked={edit.featured} onChange={(v) => set('featured', v)} />
            </div>
          </div>
        )}
      </Drawer>
    </>
  );
}
