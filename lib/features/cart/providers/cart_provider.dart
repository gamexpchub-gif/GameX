import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/product.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  static const maxPerItem = 10;

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  List<CartItem> build() {
    return ref
            .read(localStoreProvider)
            .readJson(
              LocalStore.cart,
              (json) => (json as List)
                  .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ) ??
        const [];
  }

  void _save(List<CartItem> items) {
    state = items;
    _store.writeJson(LocalStore.cart, items.map((e) => e.toJson()).toList());
  }

  void add(Product product, {int quantity = 1, String? size, int? color}) {
    final item = CartItem(
      product: product,
      quantity: quantity,
      size: size,
      color: color,
    );
    final items = [...state];
    final index = items.indexWhere((e) => e.key == item.key);
    if (index >= 0) {
      final q = (items[index].quantity + quantity).clamp(1, _limit(product));
      items[index] = items[index].copyWith(quantity: q);
    } else {
      items.add(item.copyWith(quantity: quantity.clamp(1, _limit(product))));
    }
    _save(items);
  }

  void setQuantity(String key, int quantity) {
    if (quantity <= 0) return remove(key);
    _save([
      for (final i in state)
        if (i.key == key)
          i.copyWith(quantity: quantity.clamp(1, _limit(i.product)))
        else
          i,
    ]);
  }

  void remove(String key) => _save(state.where((i) => i.key != key).toList());

  /// Removes several lines at once (e.g. the ones just ordered).
  void removeKeys(Set<String> keys) =>
      _save(state.where((i) => !keys.contains(i.key)).toList());

  void clear() => _save(const []);

  int _limit(Product p) => p.stock < maxPerItem ? p.stock : maxPerItem;
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold(0, (sum, i) => sum + i.quantity),
);

final cartSubtotalProvider = Provider<double>(
  (ref) => ref.watch(cartProvider).fold(0.0, (sum, i) => sum + i.total),
);

/// Lines the user un-ticked in the cart. New items are selected by default.
class DeselectedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String key) =>
      state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};

  void setAll(Iterable<String> keys, {required bool selected}) =>
      state = selected ? const {} : keys.toSet();

  void clear() => state = const {};
}

final deselectedProvider = NotifierProvider<DeselectedNotifier, Set<String>>(
  DeselectedNotifier.new,
);

/// Cart lines that will be checked out.
final selectedCartProvider = Provider<List<CartItem>>((ref) {
  final off = ref.watch(deselectedProvider);
  return ref.watch(cartProvider).where((i) => !off.contains(i.key)).toList();
});

class Coupon {
  const Coupon(
    this.code,
    this.rate,
    this.title, {
    this.minOrder = 0,
    this.maxDiscount,
  });
  final String code;
  final double rate;
  final String title;
  final double minOrder;
  final double? maxDiscount;
}

/// Coupons – will come from the admin panel later.
const coupons = <Coupon>[
  Coupon('GAMEX10', 0.10, '10% off on any phone', maxDiscount: 5000),
  Coupon(
    'WELCOME20',
    0.20,
    '20% off your first order',
    minOrder: 20000,
    maxDiscount: 8000,
  ),
  Coupon(
    'BKASH500',
    0,
    'Flat ৳500 off with bKash',
    minOrder: 15000,
    maxDiscount: 500,
  ),
];

const promoCodes = <String, double>{
  'GAMEX10': 0.10,
  'WELCOME20': 0.20,
  'BKASH500': 0,
};

Coupon? couponByCode(String? code) {
  for (final c in coupons) {
    if (c.code == code) return c;
  }
  return null;
}

/// Discount a coupon gives on [subtotal] (0 when not eligible).
double couponDiscount(Coupon c, double subtotal) {
  if (subtotal < c.minOrder) return 0;
  final raw = c.rate == 0 ? (c.maxDiscount ?? 0) : subtotal * c.rate;
  final capped = c.maxDiscount == null
      ? raw
      : raw.clamp(0, c.maxDiscount!).toDouble();
  return capped.roundToDouble();
}

class PromoNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Returns true when the code is valid and applied.
  bool apply(String code) {
    final c = code.trim().toUpperCase();
    if (!promoCodes.containsKey(c)) return false;
    state = c;
    return true;
  }

  void clear() => state = null;
}

final promoProvider = NotifierProvider<PromoNotifier, String?>(
  PromoNotifier.new,
);

class CartSummary {
  const CartSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    double? mrpTotal,
    this.itemCount = 0,
  }) : mrpTotal = mrpTotal ?? subtotal;

  /// Sum of selling prices.
  final double subtotal;
  final double deliveryFee;

  /// Coupon discount.
  final double discount;

  /// Sum of MRPs (crossed-out prices).
  final double mrpTotal;
  final int itemCount;

  double get mrpDiscount =>
      (mrpTotal - subtotal).clamp(0, double.infinity).toDouble();
  double get total => subtotal + deliveryFee - discount;

  /// Everything the customer saves vs. MRP.
  double get totalSavings => mrpDiscount + discount;

  static const freeDeliveryThreshold = 5000.0;
  static const standardDelivery = 120.0;
}

/// Summary of the *selected* cart lines.
final cartSummaryProvider = Provider<CartSummary>((ref) {
  final items = ref.watch(selectedCartProvider);
  final subtotal = items.fold(0.0, (s, i) => s + i.total);
  final mrp = items.fold(0.0, (s, i) => s + i.product.mrp * i.quantity);
  final coupon = couponByCode(ref.watch(promoProvider));
  final delivery =
      subtotal == 0 || subtotal >= CartSummary.freeDeliveryThreshold
      ? 0.0
      : CartSummary.standardDelivery;
  return CartSummary(
    subtotal: subtotal,
    deliveryFee: delivery,
    discount: coupon == null ? 0 : couponDiscount(coupon, subtotal),
    mrpTotal: mrp,
    itemCount: items.fold(0, (s, i) => s + i.quantity),
  );
});
