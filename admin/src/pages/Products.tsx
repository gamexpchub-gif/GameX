import { useMemo, useState } from 'react';
import { Download, Eye, Package, QrCode } from 'lucide-react';
import { Listing, ListingStatus, act, fmtDate, gradeLabel, inr, title, useDB, media } from '../store';
import { Badge, Button, Card, Empty, PageHeader, SearchInput, Tabs, Td, Th, Toggle, cx, inputCls, toast } from '../ui';
import { listingLabel, listingTone } from '../status';
import { Certificate } from './QcQueue';

type Tab = 'all' | ListingStatus;

export default function Products() {
  const listings = useDB((d) => d.listings);
  const sellers = useDB((d) => d.sellers);
  const [tab, setTab] = useState<Tab>('all');
  const [seller, setSeller] = useState('All');
  const [q, setQ] = useState('');
  const [cert, setCert] = useState<Listing | null>(null);
  const store = (id: string) => sellers.find((s) => s.id === id)?.storeName ?? id;

  const list = useMemo(
    () =>
      listings.filter(
        (l) =>
          (tab === 'all' || l.status === tab) &&
          (seller === 'All' || l.sellerId === seller) &&
          `${title(l)} ${l.id} ${l.imei} ${l.color}`.toLowerCase().includes(q.toLowerCase()),
      ),
    [listings, tab, seller, q],
  );
  const n = (t: Tab) => listings.filter((l) => t === 'all' || l.status === t).length;

  const exportCsv = () => {
    const rows = [['ID', 'Seller', 'Phone', 'Grade', 'Battery', 'IMEI', 'Price', 'MRP', 'Stock', 'Status', 'Certificate']].concat(
      list.map((l) => [l.id, store(l.sellerId), title(l), gradeLabel[l.grade], `${l.battery}%`, l.imei, String(l.price), String(l.mrp), String(l.stock), l.status, l.certificate ?? '']),
    );
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([rows.map((r) => r.map((c) => `"${c}"`).join(',')).join('\n')], { type: 'text/csv' }));
    a.download = 'gamex-listings.csv';
    a.click();
  };

  const setStatus = (l: Listing, status: ListingStatus) =>
    act('PATCH', `/listings/${l.id}`, { status })
      .then(() => toast(status === 'paused' ? 'Delisted — seller notified' : 'Listing is live again'))
      .catch((e: Error) => toast(e.message));

  return (
    <>
      <PageHeader
        title="Products"
        subtitle={`${listings.length} listings from ${sellers.length} sellers • ${listings.filter((l) => l.status === 'active').reduce((s, l) => s + l.stock, 0)} units live`}
        actions={
          <Button variant="secondary" icon={Download} onClick={exportCsv}>
            Export CSV
          </Button>
        }
      />
      <Card pad={false}>
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-100 p-4">
          <Tabs
            value={tab}
            onChange={setTab}
            items={[
              { id: 'all', label: 'All', count: n('all') },
              { id: 'active', label: 'Live', count: n('active') },
              { id: 'inReview', label: 'QC pending', count: n('inReview') },
              { id: 'rejected', label: 'Rejected', count: n('rejected') },
              { id: 'paused', label: 'Paused', count: n('paused') },
              { id: 'soldOut', label: 'Sold out', count: n('soldOut') },
            ]}
          />
          <select value={seller} onChange={(e) => setSeller(e.target.value)} className={cx(inputCls, '!w-48')}>
            <option value="All">All sellers</option>
            {sellers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.storeName}
              </option>
            ))}
          </select>
          <div className="ml-auto">
            <SearchInput value={q} onChange={setQ} placeholder="Model, ID, IMEI…" />
          </div>
        </div>
        {list.length === 0 ? (
          <Empty icon={Package} title="No listings" text="Try another filter." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50/70">
                <tr>
                  <Th>Phone</Th>
                  <Th>Seller</Th>
                  <Th>Condition</Th>
                  <Th>Price</Th>
                  <Th>Stock</Th>
                  <Th>Views / Sold</Th>
                  <Th>Status</Th>
                  <Th>Featured</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {list.map((l) => (
                  <tr key={l.id} className="hover:bg-slate-50/60">
                    <Td>
                      <div className="flex items-center gap-3">
                        <img src={media(l.photos[0])} alt="" className="h-12 w-12 rounded-xl bg-slate-50 object-contain" />
                        <div>
                          <p className="font-semibold">{title(l)}</p>
                          <p className="text-xs text-muted">
                            {l.id} • {l.ram}/{l.storage} • {l.color}
                          </p>
                        </div>
                      </div>
                    </Td>
                    <Td className="text-muted">{store(l.sellerId)}</Td>
                    <Td>
                      <Badge tone="blue">{gradeLabel[l.grade]}</Badge>
                      <p className="mt-1 text-xs text-muted">Battery {l.battery}%</p>
                    </Td>
                    <Td>
                      <p className="font-bold">{inr(l.price)}</p>
                      <p className="text-xs text-muted line-through">{inr(l.mrp)}</p>
                    </Td>
                    <Td className={cx('font-semibold', l.stock === 0 && 'text-rose-600')}>{l.stock}</Td>
                    <Td className="text-muted">
                      {l.views} / {l.sold}
                    </Td>
                    <Td>
                      <Badge tone={listingTone[l.status]} dot>
                        {listingLabel[l.status]}
                      </Badge>
                      <p className="mt-1 text-xs text-muted">{fmtDate(l.createdAt)}</p>
                    </Td>
                    <Td>
                      <Toggle checked={l.featured} onChange={(v) => act('PATCH', `/listings/${l.id}`, { featured: v })} />
                    </Td>
                    <Td className="text-right">
                      <div className="flex justify-end gap-1">
                        {l.certificate && (
                          <button title="QR certificate" onClick={() => setCert(l)} className="rounded-lg p-2 text-muted hover:bg-slate-100 hover:text-brand">
                            <QrCode size={16} />
                          </button>
                        )}
                        {l.status === 'active' && (
                          <Button size="sm" variant="danger" onClick={() => setStatus(l, 'paused')}>
                            Delist
                          </Button>
                        )}
                        {l.status === 'paused' && (
                          <Button size="sm" variant="secondary" icon={Eye} onClick={() => setStatus(l, 'active')}>
                            Relist
                          </Button>
                        )}
                      </div>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {cert && <Certificate listing={cert} seller={store(cert.sellerId)} onClose={() => setCert(null)} />}
    </>
  );
}
