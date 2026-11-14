import 'cart_item.dart';

enum PaymentMethod {
  cashOnDelivery('Cash on Delivery'),
  bkash('UPI'),
  nagad('Wallets'),
  card('Debit / Credit Card');

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
  });

  /// "Home", "Office" or "Other".
  final String label;
  final String fullName;
  final String phone;
  final String city;
  final String area;
  final String details;

  String get oneLine => '$details, $area, $city';

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    fullName: json['fullName'] as String,
    phone: json['phone'] as String,
    city: json['city'] as String,
    area: json['area'] as String,
    details: json['details'] as String,
    label: json['label'] as String? ?? 'Home',
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'city': city,
    'area': area,
    'details': details,
    'label': label,
  };

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.city == city &&
      other.area == area &&
      other.details == details &&
      other.label == label;

  @override
  int get hashCode => Object.hash(fullName, phone, city, area, details, label);
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

  double get total => subtotal + deliveryFee - discount;

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
  };
}
