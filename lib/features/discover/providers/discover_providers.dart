import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_config.dart';
import '../../../core/storage.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/product.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../data/phone_intel.dart';

/// Everything a buyer can discover: marketplace listings, the GAMEX
/// catalogue and the newest certified listings.
final discoverPoolProvider = FutureProvider<List<Product>>((ref) async {
  final all = await ref.watch(allProductsProvider.future);
  final seen = <String>{};
  return [
    for (final p in [
      ...all,
      if (ref.watch(appConfigProvider).asData?.value.demoCatalog ?? true)
        for (var n = 0; n < 48; n++) MockData.listing(n),
    ])
      if (seen.add(p.id)) p,
  ];
});

// ───────────────────────────── Compare ─────────────────────────────

const kMaxCompare = 3;

enum CompareResult { added, removed, full }

class CompareNotifier extends Notifier<List<Product>> {
  static const _key = 'compare_v1';

  @override
  List<Product> build() =>
      ref
          .read(localStoreProvider)
          .readJson(
            _key,
            (j) => [
              for (final e in j as List)
                Product.fromJson(e as Map<String, dynamic>),
            ],
          ) ??
      const [];

  void _save(List<Product> l) {
    state = l;
    ref.read(localStoreProvider).writeJson(_key, [
      for (final p in l) p.toJson(),
    ]);
  }

  bool contains(String id) => state.any((p) => p.id == id);

  CompareResult toggle(Product p) {
    if (contains(p.id)) {
      _save(state.where((x) => x.id != p.id).toList());
      return CompareResult.removed;
    }
    if (state.length >= kMaxCompare) return CompareResult.full;
    _save([...state, p]);
    return CompareResult.added;
  }

  void replaceAll(List<Product> list) => _save(list.take(kMaxCompare).toList());

  void clear() => _save(const []);
}

final compareProvider = NotifierProvider<CompareNotifier, List<Product>>(
  CompareNotifier.new,
);

final isComparedProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(compareProvider).any((p) => p.id == id),
);

// ───────────────────────────── Recently viewed ─────────────────────────────

class RecentlyViewedNotifier extends Notifier<List<Product>> {
  static const _key = 'recently_viewed_v1';
  static const max = 20;

  @override
  List<Product> build() =>
      ref
          .read(localStoreProvider)
          .readJson(
            _key,
            (j) => [
              for (final e in j as List)
                Product.fromJson(e as Map<String, dynamic>),
            ],
          ) ??
      const [];

  void record(Product p) {
    if (state.isNotEmpty && state.first.id == p.id) return;
    state = [p, ...state.where((x) => x.id != p.id)].take(max).toList();
    ref.read(localStoreProvider).writeJson(_key, [
      for (final x in state) x.toJson(),
    ]);
  }

  void clear() {
    state = const [];
    ref.read(localStoreProvider).remove(_key);
  }
}

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedNotifier, List<Product>>(
      RecentlyViewedNotifier.new,
    );

// ───────────────────────────── For you ─────────────────────────────

class Recommendation {
  const Recommendation(this.product, this.reason, this.fair);
  final Product product;
  final String reason;
  final FairPrice fair;
}

/// "Picked for you": learns brands and budget from what the buyer viewed,
/// wishlisted and put in the cart, then ranks the pool by match + value.
/// With no history it shows the best-value phones right now.
final recommendationsProvider = FutureProvider<List<Recommendation>>((
  ref,
) async {
  final pool = await ref.watch(discoverPoolProvider.future);
  final viewed = ref.watch(recentlyViewedProvider);
  final wished = ref.watch(wishlistProvider);
  final cart = [for (final c in ref.watch(cartProvider)) c.product];

  final signals = <(Product, double)>[
    for (final (i, p) in viewed.take(10).indexed) (p, 1.0 - i * 0.06),
    for (final p in wished) (p, 1.2),
    for (final p in cart) (p, 1.5),
  ];
  final brandW = <String, double>{};
  final prices = <double>[];
  for (final (p, w) in signals) {
    brandW[p.brand] = (brandW[p.brand] ?? 0) + w;
    prices.add(p.price);
  }
  prices.sort();
  final median = prices.isEmpty ? null : prices[prices.length ~/ 2];
  final exclude = {for (final (p, _) in signals) p.id};
  final topBrand = brandW.entries.isEmpty
      ? null
      : (brandW.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
  final anchor = viewed.isNotEmpty
      ? viewed.first
      : wished.isNotEmpty
      ? wished.first
      : null;

  final scored = <(Recommendation, double)>[];
  final models = <String>{};
  for (final p in pool) {
    if (!p.inStock || exclude.contains(p.id)) continue;
    final fair = fairPriceOf(p, market: pool);
    var s = -fair.delta * 8; // value for money
    String reason;
    if (median == null) {
      reason = fair.verdict == PriceVerdict.great
          ? '${_k(fair.savings)} below market'
          : 'Top rated ${gradeOf(p).toLowerCase()} pick';
      s += p.rating;
    } else {
      final bw = brandW[p.brand] ?? 0;
      s += bw * 1.6;
      final ratio = p.price / median;
      final inBand = ratio > 0.65 && ratio < 1.35;
      if (inBand) s += 2.5;
      if (ratio > 1.6) s -= 3;
      if (anchor != null &&
          modelInfo(p) == modelInfo(anchor) &&
          p.id != anchor.id) {
        s += 2;
        reason = p.price < anchor.price
            ? 'Same ${anchor.name}, ${_k(anchor.price - p.price)} cheaper'
            : 'Another ${anchor.name} option';
      } else if (p.brand == topBrand && inBand) {
        reason = 'Because you like ${p.brand}';
      } else if (inBand) {
        reason = 'In your budget';
      } else {
        reason = fair.verdict == PriceVerdict.great
            ? 'Great deal right now'
            : 'Popular on GAMEX';
      }
    }
    scored.add((Recommendation(p, reason, fair), s));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [
    for (final (r, _) in scored)
      if (models.add('${r.product.name}|${r.product.storage}')) r,
  ].take(10).toList();
});

String _k(double v) => '₹${(v.abs() / 1000).toStringAsFixed(1)}K';

// ───────────────────────────── PIN code ─────────────────────────────

class PinNotifier extends Notifier<String?> {
  static const _key = 'delivery_pin_v1';

  @override
  String? build() => ref.read(localStoreProvider).readString(_key);

  void set(String pin) {
    state = pin;
    ref.read(localStoreProvider).writeString(_key, pin);
  }
}

final deliveryPinProvider = NotifierProvider<PinNotifier, String?>(
  PinNotifier.new,
);
