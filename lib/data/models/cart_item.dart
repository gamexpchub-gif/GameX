import 'product.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.size,
    this.color,
    this.protection,
    this.offerId,
  });

  final Product product;
  final int quantity;
  final String? size;
  final int? color;

  /// Protection plan id (see `kProtectionPlans`), null when none.
  final String? protection;

  /// Accepted Make-an-Offer deal this line is priced from.
  final String? offerId;

  /// The same product with a different size/colour is a separate line.
  String get key => '${product.id}|${size ?? ''}|${color ?? ''}';

  double get total => product.price * quantity;

  CartItem copyWith({
    int? quantity,
    String? Function()? protection,
    String? Function()? offerId,
    Product? product,
  }) => CartItem(
    product: product ?? this.product,
    quantity: quantity ?? this.quantity,
    size: size,
    color: color,
    protection: protection == null ? this.protection : protection(),
    offerId: offerId == null ? this.offerId : offerId(),
  );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: Product.fromJson(json['product'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
    size: json['size'] as String?,
    color: json['color'] as int?,
    protection: json['protection'] as String?,
    offerId: json['offerId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'size': size,
    'color': color,
    if (protection != null) 'protection': protection,
    if (offerId != null) 'offerId': offerId,
  };
}
