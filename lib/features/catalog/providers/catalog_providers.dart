import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product.dart';
import '../../../core/api.dart';
import '../../../core/app_config.dart';
import '../../../data/repositories/api_product_repository.dart';
import '../../../data/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ApiProductRepository(
    ref.watch(apiProvider),
    null,
    ref.watch(appConfigProvider).asData?.value.demoCatalog ?? true,
  ),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(productRepositoryProvider).categories(),
);

final bannersProvider = FutureProvider<List<PromoBanner>>(
  (ref) => ref.watch(productRepositoryProvider).banners(),
);

/// Promo cards lower on the home screen (Admin → Banners → "Promo card").
class PromoCard {
  const PromoCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.link,
    required this.color,
    this.image,
  });
  final String id;
  final String title;
  final String subtitle;
  final String cta;

  /// In-app route (`/trade-in`) or a web address (`https://…`).
  final String link;
  final int color;
  final String? image;
}

int _hex(Object? v, int fallback) {
  final s = (v as String? ?? '').replaceFirst('#', '');
  final n = int.tryParse(s, radix: 16);
  if (n == null) return fallback;
  return s.length <= 6 ? 0xFF000000 | n : n;
}

final promoCardsProvider = FutureProvider<List<PromoCard>>((ref) async {
  final api = ref.watch(apiProvider);
  try {
    final list = await api.get('/banners?placement=promo') as List;
    return [
      for (final b in list.cast<Map<String, dynamic>>())
        if ((b['placement'] ?? 'hero') == 'promo')
          PromoCard(
            id: b['id'] as String,
            title: b['title'] as String? ?? '',
            subtitle: b['subtitle'] as String? ?? '',
            cta: (b['cta'] as String?)?.trim().isNotEmpty == true
                ? b['cta'] as String
                : 'Open',
            link: b['link'] as String? ?? '',
            color: _hex(b['color'], 0xFF4F46E5),
            image: (b['image'] as String?)?.isNotEmpty == true
                ? (b['image'] as String).startsWith('/')
                      ? api.media(b['image'] as String)
                      : b['image'] as String
                : null,
          ),
    ];
  } catch (_) {
    return const [];
  }
});

typedef ProductQuery = ({String? categoryId, String? query, ProductSort sort});

final productsProvider = FutureProvider.family<List<Product>, ProductQuery>((
  ref,
  q,
) {
  return ref
      .watch(productRepositoryProvider)
      .products(categoryId: q.categoryId, query: q.query, sort: q.sort);
});

final allProductsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).products(),
);

final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final all = await ref.watch(allProductsProvider.future);
  return all.where((p) => p.isFeatured).toList();
});

final flashSaleProductsProvider = FutureProvider<List<Product>>((ref) async {
  final all = await ref.watch(allProductsProvider.future);
  return all.where((p) => p.isFlashSale).toList();
});

final productByIdProvider = FutureProvider.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).byId(id),
);

final categoryByIdProvider = FutureProvider.family<Category?, String>((
  ref,
  id,
) async {
  final cats = await ref.watch(categoriesProvider.future);
  for (final c in cats) {
    if (c.id == id) return c;
  }
  return null;
});
