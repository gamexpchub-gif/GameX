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

/// Promo codes – will come from the admin panel later.
const promoCodes = <String, double>{'GAMEX10': 0.10, 'WELCOME20': 0.20};

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
  });

  final double subtotal;
  final double deliveryFee;
  final double discount;

  double get total => subtotal + deliveryFee - discount;

  static const freeDeliveryThreshold = 5000.0;
  static const standardDelivery = 120.0;
}

final cartSummaryProvider = Provider<CartSummary>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final promo = ref.watch(promoProvider);
  final rate = promo == null ? 0.0 : promoCodes[promo] ?? 0.0;
  final delivery =
      subtotal == 0 || subtotal >= CartSummary.freeDeliveryThreshold
      ? 0.0
      : CartSummary.standardDelivery;
  return CartSummary(
    subtotal: subtotal,
    deliveryFee: delivery,
    discount: (subtotal * rate).roundToDouble(),
  );
});
