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
  };

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
    id: j['id'] as String,
    brand: j['brand'] as String,
    model: j['model'] as String,
    ram: j['ram'] as String,
    storage: j['storage'] as String,
    color: j['color'] as String,
    grade: Grade.values.byName(j['grade'] as String),
    battery: j['battery'] as int,
    imei: j['imei'] as String,
    price: j['price'] as int,
    mrp: j['mrp'] as int,
    stock: j['stock'] as int,
    warrantyMonths: j['warranty'] as int,
    photos: (j['photos'] as List).cast<String>(),
    status: ListingStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    views: j['views'] as int? ?? 0,
    sold: j['sold'] as int? ?? 0,
    checks: (j['checks'] as Map? ?? {}).cast<String, bool>(),
    accessories: (j['accessories'] as List? ?? []).cast<String>(),
    notes: j['notes'] as String? ?? '',
    rejectReason: j['rejectReason'] as String?,
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
  };

  factory SellerOrder.fromJson(Map<String, dynamic> j) => SellerOrder(
    id: j['id'] as String,
    listingId: j['listingId'] as String,
    item: j['item'] as String,
    variant: j['variant'] as String,
    photo: j['photo'] as String,
    price: j['price'] as int,
    buyer: j['buyer'] as String,
    phone: j['phone'] as String,
    address: j['address'] as String,
    city: j['city'] as String,
    pincode: j['pincode'] as String,
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
  });

  final String id;
  final String listingId;
  final String item;
  final String photo;
  final String buyer;
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
    orders: j['orders'] as int,
    at: DateTime.parse(j['at'] as String),
    utr: j['utr'] as String,
  );
}

class Seller {
  const Seller({
    required this.phone,
    required this.ownerName,
    required this.storeName,
    required this.city,
    this.gstin = '',
    this.bank = 'HDFC Bank •••• 4821',
    this.online = true,
    this.rating = 4.8,
  });

  final String phone;
  final String ownerName;
  final String storeName;
  final String city;
  final String gstin;
  final String bank;
  final bool online;
  final double rating;

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
    phone: phone,
    ownerName: ownerName ?? this.ownerName,
    storeName: storeName ?? this.storeName,
    city: city ?? this.city,
    gstin: gstin ?? this.gstin,
    bank: bank,
    online: online ?? this.online,
    rating: rating,
  );

  Map<String, Object?> toJson() => {
    'phone': phone,
    'ownerName': ownerName,
    'storeName': storeName,
    'city': city,
    'gstin': gstin,
    'bank': bank,
    'online': online,
    'rating': rating,
  };
  factory Seller.fromJson(Map<String, dynamic> j) => Seller(
    phone: j['phone'] as String,
    ownerName: j['ownerName'] as String,
    storeName: j['storeName'] as String,
    city: j['city'] as String,
    gstin: j['gstin'] as String? ?? '',
    bank: j['bank'] as String? ?? 'HDFC Bank •••• 4821',
    online: j['online'] as bool? ?? true,
    rating: (j['rating'] as num?)?.toDouble() ?? 4.8,
  );
}
