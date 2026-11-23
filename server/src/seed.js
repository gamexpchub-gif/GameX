// Demo data used the first time the server starts (or on reset).
// Listing / order / live shapes match the GAMEX Seller app JSON.

const DAY = 864e5;
const HOUR = 36e5;
const ago = (d = 0, h = 0, m = 0) => new Date(Date.now() - d * DAY - h * HOUR - m * 6e4).toISOString();
const ahead = (d = 0, h = 0) => new Date(Date.now() + d * DAY + h * HOUR).toISOString();

export const CHECKLIST = [
  'Display & touch',
  'Face ID / Fingerprint',
  'Front & rear cameras',
  'Speakers & microphone',
  'Wi-Fi, Bluetooth & SIM',
  'Charging port',
  'Buttons & vibration',
  'No iCloud / Google lock',
];
const allOk = () => Object.fromEntries(CHECKLIST.map((c) => [c, true]));

const IMG = ['deal_iphone14pro', 'deal_iphone_blue', 'deal_iphone_midnight', 'deal_iphone_purple', 'deal_iphone_starlight', 'deal_iphone_titanium'].map(
  (n) => `/img/${n}.png`,
);

/** Builds a Luhn-valid 15 digit IMEI from a 14 digit body. */
export function imeiFrom(body14) {
  let sum = 0;
  for (let i = 0; i < 14; i++) {
    let n = Number(body14[13 - i]);
    if (i % 2 === 0) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return body14 + ((10 - (sum % 10)) % 10);
}

/** "Apple iPhone 15", "Xiaomi 14" (no doubled brand). */
export function titleOf(l) {
  return l.model.toLowerCase().startsWith(l.brand.toLowerCase()) ? l.model : `${l.brand} ${l.model}`;
}

export function buildSeed() {
  let seed = 11;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
  const pick = (a) => a[Math.floor(rnd() * a.length)];

  const sellers = [
    { id: 'S1000', phone: '+91 8047182200', ownerName: 'GAMEX Retail', storeName: 'GAMEX Official', city: 'Mumbai', gstin: '27AACCG1234F1Z5', bank: 'ICICI Bank •••• 1180', status: 'approved', online: true, rating: 4.9, createdAt: ago(400) },
    { id: 'S1001', phone: '+91 9876543210', ownerName: 'Said Rahman', storeName: 'Mobile Point Andheri', city: 'Mumbai', gstin: '', bank: 'HDFC Bank •••• 4821', status: 'approved', online: true, rating: 4.8, createdAt: ago(160) },
    { id: 'S1002', phone: '+91 9811122233', ownerName: 'Aman Khanna', storeName: 'Galaxy Mobiles Delhi', city: 'Delhi', gstin: '07ABCDE1234F1Z2', bank: 'SBI •••• 7710', status: 'pending', online: true, rating: 0, createdAt: ago(1, 4) },
    { id: 'S1003', phone: '+91 9900011122', ownerName: 'Kiran Rao', storeName: 'TechHub Bengaluru', city: 'Bengaluru', gstin: '29AAACT9876K1Z1', bank: 'Axis Bank •••• 3394', status: 'approved', online: true, rating: 4.6, createdAt: ago(90) },
    { id: 'S1004', phone: '+91 9822233344', ownerName: 'Nikhil Shah', storeName: 'Phone Bazaar Pune', city: 'Pune', gstin: '', bank: 'Kotak •••• 5521', status: 'suspended', online: false, rating: 3.9, createdAt: ago(210), suspendReason: 'High cancellation rate (18%)' },
  ];

  const rows = [
    // seller, brand, model, ram, storage, colour, price, mrp, stock, status, grade
    ['S1001', 'Apple', 'iPhone 14 Pro', '6GB', '128GB', 'Deep Purple', 49999, 69999, 2, 'active', 'excellent'],
    ['S1001', 'Apple', 'iPhone 15', '6GB', '128GB', 'Blue', 54999, 69900, 3, 'active', 'likeNew'],
    ['S1001', 'Apple', 'iPhone 13', '4GB', '128GB', 'Midnight', 32999, 49900, 1, 'active', 'good'],
    ['S1001', 'Apple', 'iPhone 15 Pro Max', '8GB', '256GB', 'Natural Titanium', 104999, 159900, 1, 'active', 'likeNew'],
    ['S1001', 'Apple', 'iPhone 14', '6GB', '128GB', 'Starlight', 41999, 59900, 0, 'soldOut', 'excellent'],
    ['S1001', 'Samsung', 'Galaxy S23 Ultra', '12GB', '256GB', 'Phantom Black', 72699, 99999, 2, 'active', 'excellent'],
    ['S1001', 'Google', 'Pixel 8 Pro', '12GB', '128GB', 'Bay Blue', 61999, 84999, 1, 'inReview', 'likeNew'],
    ['S1001', 'OnePlus', 'OnePlus 12', '12GB', '256GB', 'Flowy Emerald', 45999, 64999, 2, 'paused', 'good'],
    ['S1003', 'Samsung', 'Galaxy Z Flip5', '8GB', '256GB', 'Lavender', 58299, 74999, 1, 'active', 'excellent'],
    ['S1003', 'Xiaomi', 'Xiaomi 14', '12GB', '256GB', 'Jade Green', 40599, 62999, 2, 'active', 'good'],
    ['S1003', 'Nothing', 'Phone (2)', '12GB', '256GB', 'Dark Grey', 29999, 44999, 1, 'inReview', 'excellent'],
    ['S1003', 'vivo', 'X100 Pro', '16GB', '256GB', 'Asteroid Black', 55799, 84999, 1, 'rejected', 'likeNew'],
    ['S1002', 'Apple', 'iPhone 12', '4GB', '64GB', 'Blue', 21999, 39900, 1, 'inReview', 'fair'],
    ['S1002', 'Samsung', 'Galaxy S24', '8GB', '256GB', 'Onyx Black', 52999, 74999, 1, 'inReview', 'likeNew'],
    ['S1000', 'Apple', 'iPhone 15 Pro', '8GB', '256GB', 'Black Titanium', 89999, 134900, 3, 'active', 'likeNew'],
    ['S1000', 'Realme', 'GT 6', '12GB', '256GB', 'Fluid Silver', 34899, 46999, 4, 'active', 'excellent'],
    ['S1004', 'Motorola', 'Edge 50 Pro', '12GB', '256GB', 'Luxe Lavender', 34899, 42999, 1, 'paused', 'good'],
  ];

  const listings = rows.map((r, i) => {
    const [sellerId, brand, model, ram, storage, color, price, mrp, stock, status, grade] = r;
    const created = ago(1 + i * 2, i);
    return {
      id: `GXL${48120 + i * 7}`,
      sellerId,
      brand,
      model,
      ram,
      storage,
      color,
      grade,
      battery: 84 + ((i * 5) % 16),
      imei: imeiFrom(`35${String(209876543210 + i * 1111111).slice(0, 12)}`),
      price,
      mrp,
      stock,
      warranty: i % 2 === 0 ? 6 : 3,
      photos: [IMG[i % IMG.length], IMG[(i + 3) % IMG.length]],
      status,
      createdAt: created,
      submittedAt: status === 'inReview' ? ago(0, 1 + (i % 5), 10) : created,
      views: 180 + ((i * 97) % 900),
      sold: status === 'inReview' ? 0 : 2 + ((i * 3) % 11),
      checks: allOk(),
      accessories: i % 2 === 0 ? ['Box', 'Charger', 'Bill'] : ['Cable'],
      notes: i === 2 ? 'Tiny scratch near the camera bump' : '',
      featured: i < 3 || sellerId === 'S1000',
      rejectReason: status === 'rejected' ? 'Photos do not show the IMEI screen. Please add a clear *#06# photo.' : null,
      qc:
        status === 'inReview' || status === 'draft'
          ? null
          : { by: 'Priya (QC Mumbai)', at: ago(i, 2), decision: status === 'rejected' ? 'rejected' : 'approved', notes: '' },
      certificate: ['active', 'soldOut', 'paused'].includes(status) ? `GXC-${48120 + i * 7}-${1000 + ((i * 7919) % 9000)}` : undefined,
      approvedAt: ['active', 'soldOut', 'paused'].includes(status) ? ago(i, 2) : undefined,
      returnDays: 7,
      defects:
        i === 2
          ? [{ photo: 0, x: 0.62, y: 0.22, label: 'Tiny scratch near camera' }, { photo: 0, x: 0.35, y: 0.78, label: 'Light scuff on frame' }]
          : grade === 'good'
            ? [{ photo: 0, x: 0.5, y: 0.85, label: 'Light signs of use on edge' }]
            : [],
    };
  });

  const first = ['Aarav', 'Vivaan', 'Aditya', 'Ishaan', 'Rohan', 'Ananya', 'Diya', 'Priya', 'Saanvi', 'Kavya', 'Arjun', 'Rahul', 'Neha', 'Sneha', 'Karan', 'Meera', 'Vikram', 'Pooja'];
  const last = ['Sharma', 'Verma', 'Patel', 'Iyer', 'Nair', 'Reddy', 'Gupta', 'Singh', 'Mehta', 'Kapoor', 'Das', 'Joshi'];
  const places = [
    ['Mumbai', '400053', 'Flat 12, Sea View Towers, Andheri West'],
    ['Bengaluru', '560038', '44, 12th Main, Indiranagar'],
    ['Delhi', '110017', 'B-21, Malviya Nagar'],
    ['Chennai', '600020', '7, 2nd Cross St, Adyar'],
    ['Pune', '411001', '19, Koregaon Park Lane 6'],
    ['Hyderabad', '500033', 'Plot 88, Jubilee Hills'],
    ['Jaipur', '302001', 'C-Scheme, Ashok Marg 14'],
    ['Kolkata', '700019', '22, Ballygunge Place'],
  ];
  const customers = Array.from({ length: 22 }, (_, i) => {
    const name = `${pick(first)} ${pick(last)}`;
    const place = places[i % places.length];
    return {
      id: `C${5001 + i}`,
      name,
      email: `${name.toLowerCase().replace(' ', '.')}${i}@mail.in`,
      phone: `+91 9${String(100000000 + Math.floor(rnd() * 899999999))}`,
      city: place[0],
      pincode: place[1],
      address: place[2],
      status: i === 9 ? 'blocked' : 'active',
      createdAt: ago(5 + Math.floor(rnd() * 300)),
    };
  });

  const plan = [
    ['newOrder', 0, 1], ['newOrder', 0, 3], ['accepted', 0, 6], ['packed', 1, 2], ['shipped', 2, 0], ['shipped', 3, 0],
    ['delivered', 5, 0], ['delivered', 9, 0], ['delivered', 12, 0], ['cancelled', 4, 0], ['returned', 15, 0], ['delivered', 20, 0],
    ['delivered', 7, 4], ['shipped', 1, 5], ['newOrder', 0, 2], ['delivered', 25, 0], ['delivered', 18, 0], ['accepted', 0, 9],
  ];
  const pays = ['UPI', 'Card', 'COD', 'UPI', 'EMI', 'UPI'];
  const sellable = listings.filter((l) => ['active', 'soldOut'].includes(l.status));
  const orders = plan.map(([stage, d, h], i) => {
    const l = sellable[i % sellable.length];
    const c = customers[(i * 5) % customers.length];
    const placed = new Date(Date.now() - d * DAY - h * HOUR - (12 + i * 7) * 6e4);
    const at = (ms) => new Date(placed.getTime() + ms).toISOString();
    const ev = [{ l: 'Order placed', a: placed.toISOString() }];
    const reached = (s) => ['accepted', 'packed', 'shipped', 'delivered', 'returned'].indexOf(stage) >= ['accepted', 'packed', 'shipped', 'delivered', 'returned'].indexOf(s);
    if (stage !== 'cancelled' && stage !== 'newOrder') {
      ev.push({ l: 'Accepted by seller', a: at(25 * 6e4) });
      if (reached('packed')) ev.push({ l: 'Packed • IMEI verified', a: at(3 * HOUR) });
      if (reached('shipped')) ev.push({ l: 'Picked up by Delhivery', a: at(20 * HOUR) });
      if (reached('delivered')) ev.push({ l: 'Delivered', a: at(2 * DAY) });
      if (stage === 'returned') ev.push({ l: 'Return received', a: at(6 * DAY) });
    }
    if (stage === 'cancelled') ev.push({ l: 'Cancelled by buyer', a: at(HOUR) });
    const shipped = reached('shipped') && stage !== 'cancelled' && stage !== 'newOrder';
    return {
      id: `GMX${241000 - i * 13}`,
      orderId: `GMX${241000 - i * 13}`,
      sellerId: l.sellerId,
      customerId: c.id,
      listingId: l.id,
      item: titleOf(l),
      variant: `${l.ram} / ${l.storage} • ${l.color}`,
      photo: l.photos[0],
      price: l.price,
      buyer: c.name,
      phone: c.phone,
      address: c.address,
      city: c.city,
      pincode: c.pincode,
      payment: pays[i % pays.length],
      stage,
      placedAt: placed.toISOString(),
      events: ev,
      awb: shipped ? `DL${9134500000 + i * 7919}` : null,
      courier: shipped ? 'Delhivery' : null,
      pickupAt: null,
      imeiVerified: shipped || stage === 'packed',
      cancelReason: stage === 'cancelled' ? 'Buyer changed mind' : null,
      otp: String(1000 + ((i * 3571) % 9000)),
      deliveredAt: reached('delivered') && stage !== 'cancelled' && stage !== 'newOrder' ? at(2 * DAY) : null,
      returnDays: l.returnDays ?? 7,
      warrantyMonths: l.warranty,
      imei: l.imei,
      certificate: l.certificate ?? null,
      returnRequest: null,
    };
  });

  const live = [
    [0, 'Kavya Sharma', 'Video Call', 'English', ahead(0, 3), 'Check camera focus & speaker', 'pending'],
    [3, 'Rahul Verma', 'WhatsApp Video', 'Hindi', ahead(1, 2), 'Show battery health in settings', 'pending'],
    [5, 'Saanvi Joshi', 'Video Call', 'English', ahead(1, 6), 'Any scratches on back glass?', 'confirmed'],
    [1, 'Karan Das', 'Visit Store', 'English', ago(1), '', 'done', true],
    [2, 'Neha Patel', 'Video Call', 'Hindi', ago(2), 'Want to see Face ID working', 'done', false],
    [8, 'Meera Kapoor', 'Video Call', 'English', ahead(0, 5), 'Hinge crease close-up please', 'pending'],
  ].map(([li, buyer, mode, language, slot, notes, stage, converted], i) => {
    const l = listings[li];
    return {
      id: `LV${700100 + i * 37}`,
      sellerId: l.sellerId,
      listingId: l.id,
      item: titleOf(l),
      photo: l.photos[0],
      buyer,
      phone: `+91 98${String(76543210 + i * 1379).slice(0, 8)}`,
      mode,
      language,
      slot,
      notes,
      stage,
      converted: converted ?? null,
      createdAt: ago(0, i + 1),
    };
  });

  const payouts = [];
  for (const s of ['S1001', 'S1003', 'S1000']) {
    for (let i = 0; i < 5; i++) {
      payouts.push({
        id: `PO${9120 - payouts.length}`,
        sellerId: s,
        amount: [84210, 132560, 61890, 98745, 151320][(i + s.length) % 5],
        orders: [2, 3, 1, 2, 3][i],
        at: ago(7 * (i + 1) + 3),
        utr: `HDFCN${52014800 + payouts.length * 3311}`,
      });
    }
  }

  const notifications = [
    { id: 'N1', sellerId: null, title: 'Diwali Mega Sale is coming 🎉', body: 'List your best iPhones before 20 Oct — featured slots are free for Gold sellers.', kind: 'promo', at: ago(0, 5), read: [] },
    { id: 'N2', sellerId: null, title: 'New: Live Review', body: 'Buyers can now ask to see your phone live. Sellers who accept close 3× more sales.', kind: 'feature', at: ago(2), read: [] },
    { id: 'N3', sellerId: 'S1001', title: 'Listing approved', body: 'Your Apple iPhone 15 passed QC and is now live.', kind: 'qc', at: ago(1, 3), read: [] },
  ];

  const blacklist = [
    { imei: imeiFrom('35693803564380'), reason: 'Reported stolen (FIR filed)', at: ago(20) },
    { imei: imeiFrom('86123405678901'), reason: 'Reported lost by owner', at: ago(9) },
    { imei: imeiFrom('35412309876543'), reason: 'Financed device - EMI unpaid', at: ago(4) },
  ];

  return {
    sellers,
    listings,
    blacklist,
    claims: [],
    customers,
    orders,
    live,
    payouts,
    notifications,
    banners: [
      { id: 'b1', title: 'Premium Second-Hand Mobiles', subtitle: 'Trusted • Verified • Affordable', image: '/img/hero_banner.png', cta: 'Explore Now', link: '/categories', active: true, order: 1 },
      { id: 'b2', title: 'iPhone Fest — Up to 45% Off', subtitle: 'Certified • 6M Warranty • Free Delivery', image: '/img/hero_banner_violet.png', cta: 'Shop iPhones', link: '/category/apple', active: true, order: 2 },
      { id: 'b3', title: 'Exchange & Save More', subtitle: 'Best Value • Instant Quote • Doorstep', image: '/img/hero_banner_teal.png', cta: 'Check Value', link: '/categories', active: true, order: 3 },
      { id: 'b4', title: 'Flash Sale Friday', subtitle: 'Extra ₹2,000 Off • UPI • Today Only', image: '/img/hero_banner_magenta.png', cta: 'Grab Deals', link: '/categories', active: true, order: 4 },
    ],
    coupons: [
      { id: 'cp1', code: 'GAMEX10', type: 'percent', value: 10, minOrder: 20000, maxDiscount: 3000, uses: 412, limit: 1000, expiresAt: ahead(20), active: true },
      { id: 'cp2', code: 'UPI500', type: 'flat', value: 500, minOrder: 10000, maxDiscount: 500, uses: 1290, limit: 5000, expiresAt: ahead(45), active: true },
      { id: 'cp3', code: 'WELCOME', type: 'flat', value: 1000, minOrder: 15000, maxDiscount: 1000, uses: 233, limit: 2000, expiresAt: ahead(90), active: true },
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
      commissionRate: 0.08,
      fixedFee: 49,
    },
    activity: [
      { id: 'a1', text: 'Galaxy Mobiles Delhi applied to sell (KYC pending)', kind: 'seller', at: ago(1, 4) },
      { id: 'a2', text: '4 listings waiting for QC', kind: 'qc', at: ago(0, 2) },
      { id: 'a3', text: 'New order GMX241000 • iPhone 14 Pro', kind: 'order', at: ago(0, 1) },
    ],
  };
}
