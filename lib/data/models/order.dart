import 'cart_item.dart';

enum PaymentMethod {
  cashOnDelivery('Cash on Delivery'),
  bkash('UPI'),
  nagad('Wallets'),
  card('Debit / Credit Card'),
  emi('EMI'),
  payLater('Pay Later');

  const PaymentMethod(this.label);
  final String label;
}

enum OrderStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);
  final String label;
}

class Address {
  const Address({
    required this.fullName,
    required this.phone,
    required this.city,
    required this.area,
    required this.details,
    this.label = 'Home',
    this.pincode = '',
    this.state = '',
    this.landmark = '',
    this.lat,
    this.lng,
  });

  /// "Home", "Office" or "Other".
  final String label;
  final String fullName;
  final String phone;
  final String city;
  final String area;

  /// House / flat, building and street.
  final String details;
  final String pincode;
  final String state;
  final String landmark;

  /// Map position when picked with "Use my current location".
  final double? lat;
  final double? lng;

  String get oneLine => [
    details,
    if (landmark.isNotEmpty) 'near $landmark',
    area,
    city,
    if (state.isNotEmpty && pincode.isNotEmpty) '$state $pincode'
    else if (pincode.isNotEmpty) pincode,
  ].where((s) => s.trim().isNotEmpty).join(', ');

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    area: json['area'] as String? ?? '',
    details: json['details'] as String? ?? '',
    label: json['label'] as String? ?? 'Home',
    pincode: json['pincode'] as String? ?? '',
    state: json['state'] as String? ?? '',
    landmark: json['landmark'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'city': city,
    'area': area,
    'details': details,
    'label': label,
    'pincode': pincode,
    'state': state,
    'landmark': landmark,
    'lat': ?lat,
    'lng': ?lng,
  };

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.city == city &&
      other.area == area &&
      other.details == details &&
      other.label == label &&
      other.pincode == pincode;

  @override
  int get hashCode =>
      Object.hash(fullName, phone, city, area, details, label, pincode);
}

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.address,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.createdAt,
    this.status = OrderStatus.pending,
    this.lines = const [],
    this.paymentNote,
    this.tradeIn,
  });

  final String id;
  final List<CartItem> items;
  final Address address;
  final PaymentMethod paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final DateTime createdAt;
  final OrderStatus status;

  /// Extra price lines (label, amount): protection plans add, trade-in,
  /// wallet, bank and festival discounts subtract (negative amounts).
  final List<(String, double)> lines;

  /// e.g. "No-cost EMI • HDFC Bank • 6 × ₹8,333".
  final String? paymentNote;

  /// Trade-in attached to this order (model, amount, condition…).
  final Map<String, dynamic>? tradeIn;

  double get total =>
      subtotal + deliveryFee - discount + lines.fold(0.0, (s, l) => s + l.$2);

  /// True when any item was sold by a GAMEX marketplace seller.
  bool get hasSellerItems => items.any((i) => i.product.id.startsWith('GXL'));

  Order withStatus(OrderStatus s) => Order(
    id: id,
    items: items,
    address: address,
    paymentMethod: paymentMethod,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    discount: discount,
    createdAt: createdAt,
    status: s,
    lines: lines,
    paymentNote: paymentNote,
    tradeIn: tradeIn,
  );

  /// Expected delivery (4 days after ordering) / actual delivery (2 days).
  DateTime get expectedDelivery => createdAt.add(const Duration(days: 4));
  DateTime get deliveredAt => createdAt.add(const Duration(days: 2));

  bool get isProcessing =>
      status == OrderStatus.pending || status == OrderStatus.confirmed;
  bool get isShipped => status == OrderStatus.shipped;
  bool get isDelivered => status == OrderStatus.delivered;
  bool get isReturned => status == OrderStatus.cancelled;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    items: (json['items'] as List)
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    address: Address.fromJson(json['address'] as Map<String, dynamic>),
    paymentMethod: PaymentMethod.values.byName(json['paymentMethod'] as String),
    subtotal: (json['subtotal'] as num).toDouble(),
    deliveryFee: (json['deliveryFee'] as num).toDouble(),
    discount: (json['discount'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: OrderStatus.values.byName(json['status'] as String),
    lines: [
      for (final l in (json['lines'] as List? ?? const []).cast<Map>())
        (l['label'] as String, (l['amount'] as num).toDouble()),
    ],
    paymentNote: json['paymentNote'] as String?,
    tradeIn: (json['tradeIn'] as Map?)?.cast<String, dynamic>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'items': items.map((e) => e.toJson()).toList(),
    'address': address.toJson(),
    'paymentMethod': paymentMethod.name,
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'discount': discount,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    if (lines.isNotEmpty)
      'lines': [
        for (final l in lines) {'label': l.$1, 'amount': l.$2},
      ],
    if (paymentNote != null) 'paymentNote': paymentNote,
    if (tradeIn != null) 'tradeIn': tradeIn,
  };
}
