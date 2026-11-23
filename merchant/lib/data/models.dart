// Domain models for the GAMEX Seller app.

enum Grade {
  likeNew('Like New', 'No visible marks. Looks brand new.'),
  excellent('Excellent', 'Micro-scratches only visible up close.'),
  good('Good', 'Light, visible signs of use.'),
  fair('Fair', 'Noticeable scratches or dents. Fully working.');

  const Grade(this.label, this.description);
  final String label;
  final String description;
}

enum ListingStatus {
  active('Active'),
  inReview('In review'),
  paused('Paused'),
  draft('Draft'),
  rejected('Rejected'),
  soldOut('Sold out');

  const ListingStatus(this.label);
  final String label;
}

/// Fee rules applied to every sale.
abstract final class Fees {
  static const commissionRate = 0.08;
  static const fixedFee = 49;
  static const gstOnFees = 0.18;

  static double commission(num price) => price * commissionRate;
  static double totalFees(num price) =>
      (commission(price) + fixedFee) * (1 + gstOnFees);
  static double payout(num price) => price - totalFees(price);
}

const kChecklist = [
  'Display & touch',
  'Face ID / Fingerprint',
  'Front & rear cameras',
  'Speakers & microphone',
  'Wi-Fi, Bluetooth & SIM',
  'Charging port',
  'Buttons & vibration',
  'No iCloud / Google lock',
];

class Listing {
  const Listing({
    required this.id,
    required this.brand,
    required this.model,
    required this.ram,
    required this.storage,
    required this.color,
    required this.grade,
    required this.battery,
    required this.imei,
    required this.price,
    required this.mrp,
    required this.stock,
    required this.warrantyMonths,
    required this.photos,
    required this.status,
    required this.createdAt,
    this.views = 0,
    this.sold = 0,
    this.checks = const {},
    this.accessories = const [],
    this.notes = '',
    this.rejectReason,
    this.featured = false,
    this.certificate,
    this.qcBy,
    this.deviceType = 'Mobile Phone',
    this.network = '5G / 4G / 3G / 2G',
    this.sim = 'Dual SIM (Nano)',
    this.returnDays = 7,
    this.offerPercent = 0,
  });

  final String id;
  final String brand;
  final String model;
  final String ram;
  final String storage;
  final String color;
  final Grade grade;
  final int battery;
  final String imei;
  final int price;
  final int mrp;
  final int stock;
  final int warrantyMonths;

  /// `asset:<path>` or an absolute file path.
  final List<String> photos;
  final ListingStatus status;
  final DateTime createdAt;
  final int views;
  final int sold;
  final Map<String, bool> checks;
  final List<String> accessories;
  final String notes;
  final String? rejectReason;
  final bool featured;

  /// GAMEX QC certificate number, set when the listing passes QC.
  final String? certificate;
  final String? qcBy;
  final String deviceType;
  final String network;
  final String sim;

  /// 0 = no returns, otherwise 7 or 15 days.
  final int returnDays;

  /// Extra launch discount shown to buyers (0 = off).
  final int offerPercent;

  int get ageDays => DateTime.now().difference(createdAt).inDays;
  double get conversion => views == 0 ? 0 : sold * 100 / views;

  String get title => '$brand $model'.trim();
  String get variant => '$ram / $storage';
  int get discount => mrp > price ? (((mrp - price) / mrp) * 100).round() : 0;
  bool get lowStock => status == ListingStatus.active && stock <= 1;

  Listing copyWith({
    String? id,
    String? brand,
    String? model,
    String? ram,
    String? storage,
    String? color,
    Grade? grade,
    int? battery,
    String? imei,
    int? price,
    int? mrp,
    int? stock,
    int? warrantyMonths,
    List<String>? photos,
    ListingStatus? status,
    DateTime? createdAt,
    int? views,
    int? sold,
    Map<String, bool>? checks,
    List<String>? accessories,
    String? notes,
    String? deviceType,
    String? network,
    String? sim,
    int? returnDays,
    int? offerPercent,
  }) => Listing(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    ram: ram ?? this.ram,
    storage: storage ?? this.storage,
    color: color ?? this.color,
    grade: grade ?? this.grade,
    battery: battery ?? this.battery,
    imei: imei ?? this.imei,
    price: price ?? this.price,
    mrp: mrp ?? this.mrp,
    stock: stock ?? this.stock,
    warrantyMonths: warrantyMonths ?? this.warrantyMonths,
    photos: photos ?? this.photos,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    views: views ?? this.views,
    sold: sold ?? this.sold,
    checks: checks ?? this.checks,
    accessories: accessories ?? this.accessories,
    notes: notes ?? this.notes,
    rejectReason: rejectReason,
    featured: featured,
    certificate: certificate,
    qcBy: qcBy,
    deviceType: deviceType ?? this.deviceType,
    network: network ?? this.network,
    sim: sim ?? this.sim,
    returnDays: returnDays ?? this.returnDays,
    offerPercent: offerPercent ?? this.offerPercent,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'brand': brand,
    'model': model,
    'ram': ram,
    'storage': storage,
    'color': color,
    'grade': grade.name,
    'battery': battery,
    'imei': imei,
    'price': price,
    'mrp': mrp,
    'stock': stock,
    'warranty': warrantyMonths,
    'photos': photos,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'views': views,
    'sold': sold,
    'checks': checks,
    'accessories': accessories,
    'notes': notes,
    'rejectReason': rejectReason,
    'deviceType': deviceType,
    'network': network,
    'sim': sim,
    'returnDays': returnDays,
    'offerPercent': offerPercent,
  };

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
    id: j['id'] as String,
    brand: j['brand'] as String,
    model: j['model'] as String,
    ram: j['ram'] as String,
    storage: j['storage'] as String,
    color: j['color'] as String,
    grade: Grade.values.byName(j['grade'] as String),
    battery: (j['battery'] as num).toInt(),
    imei: j['imei'] as String,
    price: (j['price'] as num).toInt(),
    mrp: (j['mrp'] as num).toInt(),
    stock: (j['stock'] as num).toInt(),
    warrantyMonths: (j['warranty'] as num?)?.toInt() ?? 0,
    photos: (j['photos'] as List).cast<String>(),
    status: ListingStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    views: (j['views'] as num?)?.toInt() ?? 0,
    sold: (j['sold'] as num?)?.toInt() ?? 0,
    checks: (j['checks'] as Map? ?? {}).cast<String, bool>(),
    accessories: (j['accessories'] as List? ?? []).cast<String>(),
    notes: j['notes'] as String? ?? '',
    rejectReason: j['rejectReason'] as String?,
    featured: j['featured'] as bool? ?? false,
    certificate: j['certificate'] as String?,
    qcBy: (j['qc'] as Map?)?['by'] as String?,
    deviceType: j['deviceType'] as String? ?? 'Mobile Phone',
    network: j['network'] as String? ?? '5G / 4G / 3G / 2G',
    sim: j['sim'] as String? ?? 'Dual SIM (Nano)',
    returnDays: (j['returnDays'] as num?)?.toInt() ?? 7,
    offerPercent: (j['offerPercent'] as num?)?.toInt() ?? 0,
  );
}

enum OrderStage {
  newOrder('New'),
  accepted('To pack'),
  packed('Ready to ship'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled'),
  returned('Returned');

  const OrderStage(this.label);
  final String label;

  bool get open => index <= OrderStage.shipped.index;
}

class OrderEvent {
  const OrderEvent(this.label, this.at);
  final String label;
  final DateTime at;

  Map<String, Object?> toJson() => {'l': label, 'a': at.toIso8601String()};
  factory OrderEvent.fromJson(Map<String, dynamic> j) =>
      OrderEvent(j['l'] as String, DateTime.parse(j['a'] as String));
}

class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.listingId,
    required this.item,
    required this.variant,
    required this.photo,
    required this.price,
    required this.buyer,
    required this.phone,
    required this.address,
    required this.city,
    required this.pincode,
    required this.payment,
    required this.stage,
    required this.placedAt,
    required this.events,
    this.awb,
    this.courier,
    this.pickupAt,
    this.imeiVerified = false,
    this.cancelReason,
    this.returnRequest,
    this.tradeIn,
    this.offerId,
    this.listPrice,
  });

  final String id;
  final String listingId;
  final String item;
  final String variant;
  final String photo;
  final int price;
  final String buyer;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final String payment;
  final OrderStage stage;
  final DateTime placedAt;
  final List<OrderEvent> events;
  final String? awb;
  final String? courier;
  final DateTime? pickupAt;
  final bool imeiVerified;
  final String? cancelReason;

  /// Buyer's return request ({status, reason, details, pickupSlot}) or null.
  final Map<String, dynamic>? returnRequest;
  String? get returnStatus => returnRequest?['status'] as String?;

  /// Buyer's old phone to collect at delivery (GAMEX exchange).
  final Map<String, dynamic>? tradeIn;

  /// Sold through an accepted Make-an-Offer deal.
  final String? offerId;

  /// Listing price when the order was placed (differs from [price] for offers).
  final int? listPrice;

  /// New orders must be accepted within 4 hours; packing within 24.
  DateTime get slaDeadline => stage == OrderStage.newOrder
      ? placedAt.add(const Duration(hours: 4))
      : placedAt.add(const Duration(hours: 24));

  double get payout => Fees.payout(price);

  SellerOrder copyWith({
    OrderStage? stage,
    List<OrderEvent>? events,
    String? awb,
    String? courier,
    DateTime? pickupAt,
    bool? imeiVerified,
    String? cancelReason,
  }) => SellerOrder(
    id: id,
    listingId: listingId,
    item: item,
    variant: variant,
    photo: photo,
    price: price,
    buyer: buyer,
    phone: phone,
    address: address,
    city: city,
    pincode: pincode,
    payment: payment,
    stage: stage ?? this.stage,
    placedAt: placedAt,
    events: events ?? this.events,
    awb: awb ?? this.awb,
    courier: courier ?? this.courier,
    pickupAt: pickupAt ?? this.pickupAt,
    imeiVerified: imeiVerified ?? this.imeiVerified,
    cancelReason: cancelReason ?? this.cancelReason,
    returnRequest: returnRequest,
    tradeIn: tradeIn,
    offerId: offerId,
    listPrice: listPrice,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'listingId': listingId,
    'item': item,
    'variant': variant,
    'photo': photo,
    'price': price,
    'buyer': buyer,
    'phone': phone,
    'address': address,
    'city': city,
    'pincode': pincode,
    'payment': payment,
    'stage': stage.name,
    'placedAt': placedAt.toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
    'awb': awb,
    'courier': courier,
    'pickupAt': pickupAt?.toIso8601String(),
    'imeiVerified': imeiVerified,
    'cancelReason': cancelReason,
    'returnRequest': returnRequest,
    'tradeIn': tradeIn,
    'offerId': offerId,
    'listPrice': listPrice,
  };

  factory SellerOrder.fromJson(Map<String, dynamic> j) => SellerOrder(
    id: j['id'] as String,
    listingId: j['listingId'] as String,
    item: j['item'] as String,
    variant: j['variant'] as String,
    photo: j['photo'] as String,
    price: (j['price'] as num).toInt(),
    buyer: j['buyer'] as String,
    phone: j['phone'] as String,
    address: j['address'] as String? ?? '',
    city: j['city'] as String? ?? '',
    pincode: j['pincode'] as String? ?? '',
    payment: j['payment'] as String,
    stage: OrderStage.values.byName(j['stage'] as String),
    placedAt: DateTime.parse(j['placedAt'] as String),
    events: (j['events'] as List)
        .map((e) => OrderEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    awb: j['awb'] as String?,
    courier: j['courier'] as String?,
    pickupAt: j['pickupAt'] == null
        ? null
        : DateTime.parse(j['pickupAt'] as String),
    imeiVerified: j['imeiVerified'] as bool? ?? false,
    cancelReason: j['cancelReason'] as String?,
    returnRequest: (j['returnRequest'] as Map?)?.cast<String, dynamic>(),
    tradeIn: (j['tradeIn'] as Map?)?.cast<String, dynamic>(),
    offerId: j['offerId'] as String?,
    listPrice: (j['listPrice'] as num?)?.toInt(),
  );
}

enum LiveStage {
  pending('Pending'),
  confirmed('Confirmed'),
  done('Completed'),
  declined('Declined');

  const LiveStage(this.label);
  final String label;
}

class LiveCall {
  const LiveCall({
    required this.id,
    required this.listingId,
    required this.item,
    required this.photo,
    required this.buyer,
    required this.mode,
    required this.language,
    required this.slot,
    required this.notes,
    required this.stage,
    this.converted,
    this.messages = const [],
  });

  final String id;
  final String listingId;
  final String item;
  final String photo;
  final String buyer;
  final List<ChatMessage> messages;
  int get unread => messages.where((m) => m.fromBuyer && !m.seen).length;
  final String mode;
  final String language;
  final DateTime slot;
  final String notes;
  final LiveStage stage;
  final bool? converted;

  LiveCall copyWith({LiveStage? stage, DateTime? slot, bool? converted}) =>
      LiveCall(
        id: id,
        listingId: listingId,
        item: item,
        photo: photo,
        buyer: buyer,
        mode: mode,
        language: language,
        slot: slot ?? this.slot,
        notes: notes,
        stage: stage ?? this.stage,
        converted: converted ?? this.converted,
        messages: messages,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'listingId': listingId,
    'item': item,
    'photo': photo,
    'buyer': buyer,
    'mode': mode,
    'language': language,
    'slot': slot.toIso8601String(),
    'notes': notes,
    'stage': stage.name,
    'converted': converted,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory LiveCall.fromJson(Map<String, dynamic> j) => LiveCall(
    id: j['id'] as String,
    listingId: j['listingId'] as String,
    item: j['item'] as String,
    photo: j['photo'] as String,
    buyer: j['buyer'] as String,
    mode: j['mode'] as String,
    language: j['language'] as String,
    slot: DateTime.parse(j['slot'] as String),
    notes: j['notes'] as String,
    stage: LiveStage.values.byName(j['stage'] as String),
    converted: j['converted'] as bool?,
    messages: [
      for (final m in (j['messages'] as List? ?? const []))
        ChatMessage.fromJson(m as Map<String, dynamic>),
    ],
  );
}

class ChatMessage {
  const ChatMessage({
    required this.fromBuyer,
    required this.text,
    required this.at,
    this.seen = false,
  });
  final bool fromBuyer;
  final String text;
  final DateTime at;
  final bool seen;

  Map<String, Object?> toJson() => {
    'from': fromBuyer ? 'buyer' : 'seller',
    'text': text,
    'at': at.toIso8601String(),
    'seen': seen,
  };
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    fromBuyer: j['from'] == 'buyer',
    text: j['text'] as String? ?? '',
    at: DateTime.parse(j['at'] as String),
    seen: j['seen'] == true,
  );
}

class Payout {
  const Payout({
    required this.id,
    required this.amount,
    required this.orders,
    required this.at,
    required this.utr,
  });
  final String id;
  final double amount;
  final int orders;
  final DateTime at;
  final String utr;

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'orders': orders,
    'at': at.toIso8601String(),
    'utr': utr,
  };
  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
    id: j['id'] as String,
    amount: (j['amount'] as num).toDouble(),
    orders: (j['orders'] as num).toInt(),
    at: DateTime.parse(j['at'] as String),
    utr: j['utr'] as String,
  );
}

enum SellerStatus { pending, approved, suspended }

class Seller {
  const Seller({
    required this.id,
    required this.phone,
    required this.ownerName,
    required this.storeName,
    required this.city,
    this.gstin = '',
    this.bank = 'HDFC Bank •••• 4821',
    this.online = true,
    this.rating = 4.8,
    this.status = SellerStatus.approved,
    this.suspendReason,
  });

  final String id;
  final String phone;
  final String ownerName;
  final String storeName;
  final String city;
  final String gstin;
  final String bank;
  final bool online;
  final double rating;
  final SellerStatus status;
  final String? suspendReason;

  String get initials => storeName
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  Seller copyWith({
    String? ownerName,
    String? storeName,
    String? city,
    String? gstin,
    bool? online,
  }) => Seller(
    id: id,
    phone: phone,
    ownerName: ownerName ?? this.ownerName,
    storeName: storeName ?? this.storeName,
    city: city ?? this.city,
    gstin: gstin ?? this.gstin,
    bank: bank,
    online: online ?? this.online,
    rating: rating,
    status: status,
    suspendReason: suspendReason,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'phone': phone,
    'ownerName': ownerName,
    'storeName': storeName,
    'city': city,
    'gstin': gstin,
    'bank': bank,
    'online': online,
    'rating': rating,
    'status': status.name,
    'suspendReason': suspendReason,
  };
  factory Seller.fromJson(Map<String, dynamic> j) => Seller(
    id: j['id'] as String? ?? '',
    phone: j['phone'] as String,
    ownerName: j['ownerName'] as String,
    storeName: j['storeName'] as String,
    city: j['city'] as String,
    gstin: j['gstin'] as String? ?? '',
    bank: j['bank'] as String? ?? 'HDFC Bank •••• 4821',
    online: j['online'] as bool? ?? true,
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
    status:
        SellerStatus.values.asNameMap()[j['status']] ?? SellerStatus.pending,
    suspendReason: j['suspendReason'] as String?,
  );
}

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.at,
    required this.read,
  });
  final String id;
  final String title;
  final String body;

  /// order, live, qc, payout, account, promo, feature, announcement, info.
  final String kind;
  final DateTime at;
  final bool read;

  bool get isAnnouncement =>
      kind == 'promo' || kind == 'feature' || kind == 'announcement';

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind,
    'at': at.toIso8601String(),
    'read': read,
  };
  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String? ?? '',
    kind: j['kind'] as String? ?? 'info',
    at: DateTime.parse(j['at'] as String),
    read: j['read'] == true,
  );
}

class Insights {
  const Insights({this.demand = const [], this.pricing = const []});

  /// Most ordered models across GAMEX.
  final List<({String name, int orders})> demand;

  /// Your listings priced away from the market average.
  final List<({String id, String title, int price, int market})> pricing;

  Map<String, Object?> toJson() => {
    'demand': [
      for (final d in demand) {'name': d.name, 'orders': d.orders},
    ],
    'pricing': [
      for (final p in pricing)
        {'id': p.id, 'title': p.title, 'price': p.price, 'market': p.market},
    ],
  };
  factory Insights.fromJson(Map<String, dynamic> j) => Insights(
    demand: [
      for (final d in (j['demand'] as List? ?? []).cast<Map>())
        (name: d['name'] as String, orders: (d['orders'] as num).toInt()),
    ],
    pricing: [
      for (final p in (j['pricing'] as List? ?? []).cast<Map>())
        (
          id: p['id'] as String,
          title: p['title'] as String,
          price: (p['price'] as num).toInt(),
          market: (p['market'] as num).toInt(),
        ),
    ],
  );
}

/// A buyer's Make-an-Offer on one of the seller's listings.
class BuyerOffer {
  const BuyerOffer(this.j);
  final Map<String, dynamic> j;

  static DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse('$v');

  String get id => j['id'] as String;
  String get listingId => j['listingId'] as String;
  String get customerName => j['customerName'] as String? ?? 'Customer';
  int get listPrice => (j['listPrice'] as num).toInt();
  int get amount => (j['amount'] as num).toInt();
  int? get counter => (j['counter'] as num?)?.toInt();
  int? get dealPrice => (j['dealPrice'] as num?)?.toInt();
  String get note => j['note'] as String? ?? '';

  /// pending | countered | accepted | rejected | expired | withdrawn | used
  String get status => j['status'] as String;
  DateTime get createdAt => _d(j['createdAt']) ?? DateTime.now();
  DateTime? get expiresAt => _d(j['expiresAt']);
  String get title => (j['listing'] as Map?)?['title'] as String? ?? 'Listing';
  String? get photo => (j['listing'] as Map?)?['photo'] as String?;
  int? get currentPrice => ((j['listing'] as Map?)?['price'] as num?)?.toInt();

  int get percentOff => ((1 - amount / listPrice) * 100).round();
  bool get pending => status == 'pending';

  Map<String, dynamic> toJson() => j;
}
