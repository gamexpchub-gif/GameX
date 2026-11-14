import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product.dart';
import '../../../core/api.dart';
import '../../../data/repositories/api_product_repository.dart';
import '../../../data/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ApiProductRepository(ref.watch(apiProvider)),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(productRepositoryProvider).categories(),
);

final bannersProvider = FutureProvider<List<PromoBanner>>(
  (ref) => ref.watch(productRepositoryProvider).banners(),
);

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
