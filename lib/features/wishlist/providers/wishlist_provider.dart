import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../data/models/product.dart';

class WishlistNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    return ref
            .read(localStoreProvider)
            .readJson(
              LocalStore.wishlist,
              (json) => (json as List)
                  .map((e) => Product.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ) ??
        const [];
  }

  bool contains(String id) => state.any((p) => p.id == id);

  /// Returns true if the product is now in the wishlist.
  bool toggle(Product product) {
    final added = !contains(product.id);
    state = added
        ? [product, ...state]
        : state.where((p) => p.id != product.id).toList();
    ref
        .read(localStoreProvider)
        .writeJson(LocalStore.wishlist, state.map((p) => p.toJson()).toList());
    return added;
  }
}

final wishlistProvider = NotifierProvider<WishlistNotifier, List<Product>>(
  WishlistNotifier.new,
);

final isWishlistedProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(wishlistProvider).any((p) => p.id == id),
);
