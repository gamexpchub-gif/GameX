import 'models.dart';

const _imgs = [
  'asset:assets/img/deal_iphone14pro.png',
  'asset:assets/img/deal_iphone_blue.png',
  'asset:assets/img/deal_iphone_midnight.png',
  'asset:assets/img/deal_iphone_purple.png',
  'asset:assets/img/deal_iphone_starlight.png',
  'asset:assets/img/deal_iphone_titanium.png',
];

DateTime _ago({int d = 0, int h = 0, int m = 0}) =>
    DateTime.now().subtract(Duration(days: d, hours: h, minutes: m));

Map<String, bool> _allOk() => {for (final c in kChecklist) c: true};

List<Listing> seedListings() {
  const rows = [
    // brand, model, ram, storage, colour, price, mrp, stock, status
    (
      'Apple',
      'iPhone 14 Pro',
      '6GB',
      '128GB',
      'Deep Purple',
      49999,
      69999,
      2,
      ListingStatus.active,
    ),
    (
      'Apple',
      'iPhone 15',
      '6GB',
      '128GB',
      'Blue',
      54999,
      69900,
      3,
      ListingStatus.active,
    ),
    (
      'Apple',
      'iPhone 13',
      '4GB',
      '128GB',
      'Midnight',
      32999,
      49900,
      1,
      ListingStatus.active,
    ),
    (
      'Apple',
      'iPhone 15 Pro Max',
      '8GB',
      '256GB',
      'Natural Titanium',
      104999,
      159900,
      1,
      ListingStatus.active,
    ),
    (
      'Apple',
      'iPhone 14',
      '6GB',
      '128GB',
      'Starlight',
      41999,
      59900,
      0,
      ListingStatus.soldOut,
    ),
    (
      'Samsung',
      'Galaxy S23 Ultra',
      '12GB',
      '256GB',
      'Phantom Black',
      72699,
      99999,
      2,
      ListingStatus.active,
    ),
    (
      'Google',
      'Pixel 8 Pro',
      '12GB',
      '128GB',
      'Bay Blue',
      61999,
      84999,
      1,
      ListingStatus.inReview,
    ),
    (
      'OnePlus',
      'OnePlus 12',
      '12GB',
      '256GB',
      'Flowy Emerald',
      45999,
      64999,
      2,
      ListingStatus.paused,
    ),
    (
      'Samsung',
      'Galaxy Z Flip5',
      '8GB',
      '256GB',
      'Lavender',
      58299,
      74999,
      1,
      ListingStatus.draft,
    ),
  ];
  const grades = [
    Grade.excellent,
    Grade.likeNew,
    Grade.good,
    Grade.likeNew,
    Grade.excellent,
    Grade.excellent,
    Grade.likeNew,
    Grade.good,
    Grade.excellent,
  ];
  return [
    for (var i = 0; i < rows.length; i++)
      Listing(
        id: 'GXL${48120 + i * 7}',
        brand: rows[i].$1,
        model: rows[i].$2,
        ram: rows[i].$3,
        storage: rows[i].$4,
        color: rows[i].$5,
        price: rows[i].$6,
        mrp: rows[i].$7,
        stock: rows[i].$8,
        status: rows[i].$9,
        grade: grades[i],
        battery: 84 + (i * 5) % 16,
        imei: '35${(209876543210 + i * 1111111).toString()}${i % 10}',
        warrantyMonths: i.isEven ? 6 : 3,
        photos: [_imgs[i % _imgs.length], _imgs[(i + 3) % _imgs.length]],
        createdAt: _ago(d: 2 + i * 3),
        views: 180 + i * 97 % 900,
        sold: 2 + (i * 3) % 11,
        checks: _allOk(),
        accessories: i.isEven ? ['Box', 'Charger', 'Bill'] : ['Cable'],
      ),
  ];
}

List<SellerOrder> seedOrders(List<Listing> l) {
  const buyers = [
    (
      'Aarav Sharma',
      'Mumbai',
      '400053',
      'Flat 12, Sea View Towers, Andheri West',
    ),
    ('Priya Nair', 'Bengaluru', '560038', '44, 12th Main, Indiranagar'),
    ('Rohan Gupta', 'Delhi', '110017', 'B-21, Malviya Nagar'),
    ('Kavya Iyer', 'Chennai', '600020', '7, 2nd Cross St, Adyar'),
    ('Arjun Mehta', 'Pune', '411001', '19, Koregaon Park Lane 6'),
    ('Sneha Reddy', 'Hyderabad', '500033', 'Plot 88, Jubilee Hills'),
    ('Vikram Singh', 'Jaipur', '302001', 'C-Scheme, Ashok Marg 14'),
    ('Meera Kapoor', 'Kolkata', '700019', '22, Ballygunge Place'),
  ];
  const plan = [
    (OrderStage.newOrder, 0, 1),
    (OrderStage.newOrder, 0, 3),
    (OrderStage.accepted, 0, 6),
    (OrderStage.packed, 1, 2),
    (OrderStage.shipped, 2, 0),
    (OrderStage.shipped, 3, 0),
    (OrderStage.delivered, 5, 0),
    (OrderStage.delivered, 9, 0),
    (OrderStage.delivered, 12, 0),
    (OrderStage.cancelled, 4, 0),
    (OrderStage.returned, 15, 0),
    (OrderStage.delivered, 20, 0),
  ];
  const pays = ['UPI', 'Card', 'COD', 'UPI', 'EMI', 'UPI'];
  return [
    for (var i = 0; i < plan.length; i++)
      () {
        final item = l[i % 6];
        final b = buyers[i % buyers.length];
        final placed = _ago(d: plan[i].$2, h: plan[i].$3, m: 12 + i * 7);
        final stage = plan[i].$1;
        final ev = <OrderEvent>[OrderEvent('Order placed', placed)];
        if (stage.index >= OrderStage.accepted.index &&
            stage != OrderStage.cancelled) {
          ev.add(
            OrderEvent(
              'Accepted by you',
              placed.add(const Duration(minutes: 25)),
            ),
          );
        }
        if (stage.index >= OrderStage.packed.index &&
            stage != OrderStage.cancelled) {
          ev.add(
            OrderEvent(
              'Packed • IMEI verified',
              placed.add(const Duration(hours: 3)),
            ),
          );
        }
        if (stage.index >= OrderStage.shipped.index &&
            stage != OrderStage.cancelled) {
          ev.add(
            OrderEvent(
              'Picked up by Delhivery',
              placed.add(const Duration(hours: 20)),
            ),
          );
        }
        if (stage == OrderStage.delivered || stage == OrderStage.returned) {
          ev.add(OrderEvent('Delivered', placed.add(const Duration(days: 2))));
        }
        if (stage == OrderStage.returned) {
          ev.add(
            OrderEvent('Return received', placed.add(const Duration(days: 6))),
          );
        }
        if (stage == OrderStage.cancelled) {
          ev.add(
            OrderEvent(
              'Cancelled by buyer',
              placed.add(const Duration(hours: 1)),
            ),
          );
        }
        final shipped =
            stage.index >= OrderStage.shipped.index &&
            stage != OrderStage.cancelled;
        return SellerOrder(
          id: 'GMX${241000 - i * 13}',
          listingId: item.id,
          item: item.title,
          variant: '${item.variant} • ${item.color}',
          photo: item.photos.first,
          price: item.price,
          buyer: b.$1,
          phone: '+91 98${(76543210 + i * 1379).toString().substring(0, 8)}',
          address: b.$4,
          city: b.$2,
          pincode: b.$3,
          payment: pays[i % pays.length],
          stage: stage,
          placedAt: placed,
          events: ev,
          awb: shipped ? 'DL${(9134500000 + i * 7919)}' : null,
          courier: shipped ? 'Delhivery' : null,
          imeiVerified:
              stage.index >= OrderStage.packed.index &&
              stage != OrderStage.cancelled,
          cancelReason: stage == OrderStage.cancelled
              ? 'Buyer changed mind'
              : null,
        );
      }(),
  ];
}

List<LiveCall> seedLive(List<Listing> l) {
  final now = DateTime.now();
  DateTime at(int day, int hour) =>
      DateTime(now.year, now.month, now.day + day, hour);
  return [
    LiveCall(
      id: 'LV700100',
      listingId: l[0].id,
      item: l[0].title,
      photo: l[0].photos.first,
      buyer: 'Kavya Sharma',
      mode: 'Video Call',
      language: 'English',
      slot: at(0, 18),
      notes: 'Check camera focus & speaker',
      stage: LiveStage.pending,
    ),
    LiveCall(
      id: 'LV700137',
      listingId: l[3].id,
      item: l[3].title,
      photo: l[3].photos.first,
      buyer: 'Rahul Verma',
      mode: 'WhatsApp Video',
      language: 'Hindi',
      slot: at(1, 12),
      notes: 'Show battery health in settings',
      stage: LiveStage.pending,
    ),
    LiveCall(
      id: 'LV700174',
      listingId: l[5].id,
      item: l[5].title,
      photo: l[5].photos.first,
      buyer: 'Saanvi Joshi',
      mode: 'Video Call',
      language: 'English',
      slot: at(1, 16),
      notes: 'Any scratches on back glass?',
      stage: LiveStage.confirmed,
    ),
    LiveCall(
      id: 'LV700211',
      listingId: l[1].id,
      item: l[1].title,
      photo: l[1].photos.first,
      buyer: 'Karan Das',
      mode: 'Visit Store',
      language: 'English',
      slot: at(-1, 15),
      notes: '',
      stage: LiveStage.done,
      converted: true,
    ),
    LiveCall(
      id: 'LV700248',
      listingId: l[2].id,
      item: l[2].title,
      photo: l[2].photos.first,
      buyer: 'Neha Patel',
      mode: 'Video Call',
      language: 'Hindi',
      slot: at(-2, 11),
      notes: 'Want to see Face ID working',
      stage: LiveStage.done,
      converted: false,
    ),
  ];
}

List<Payout> seedPayouts() => [
  for (var i = 0; i < 6; i++)
    Payout(
      id: 'PO${9120 - i}',
      amount: [84210.0, 132560.0, 61890.0, 98745.0, 151320.0, 72400.0][i],
      orders: [2, 3, 1, 2, 3, 2][i],
      at: _ago(d: 7 * (i + 1) + 3),
      utr: 'HDFCN${52014800 + i * 3311}',
    ),
];
