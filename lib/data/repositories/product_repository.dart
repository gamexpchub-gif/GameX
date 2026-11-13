import '../mock/mock_data.dart';
import '../models/product.dart';

enum ProductSort {
  popular('Most popular'),
  newest('Newest'),
  priceLow('Price: Low to High'),
  priceHigh('Price: High to Low'),
  rating('Top rated');

  const ProductSort(this.label);
  final String label;
}

/// Catalogue data source. The app only talks to this interface, so the mock
/// implementation can be swapped for the real admin-panel API later without
/// touching any screen.
abstract interface class ProductRepository {
  Future<List<Category>> categories();
  Future<List<PromoBanner>> banners();
  Future<List<Product>> products({
    String? categoryId,
    String? query,
    ProductSort sort = ProductSort.popular,
  });
  Future<Product?> byId(String id);

  /// Newest second-hand listings, paged (0-based). Empty when exhausted.
  Future<List<Product>> newListings({required int page, int pageSize = 12});
}

class MockProductRepository implements ProductRepository {
  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<Category>> categories() async {
    await Future<void>.delayed(_latency);
    return MockData.categories;
  }

  @override
  Future<List<PromoBanner>> banners() async {
    await Future<void>.delayed(_latency);
    return MockData.banners;
  }

  @override
  Future<List<Product>> products({
    String? categoryId,
    String? query,
    ProductSort sort = ProductSort.popular,
  }) async {
    await Future<void>.delayed(_latency);
    var list = MockData.products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    switch (sort) {
      case ProductSort.popular:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      case ProductSort.newest:
        list = list.reversed.toList();
      case ProductSort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  @override
  Future<Product?> byId(String id) async {
    await Future<void>.delayed(_latency);
    return MockData.byId(id);
  }

  static const _maxListings = 240;

  @override
  Future<List<Product>> newListings({
    required int page,
    int pageSize = 12,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final start = page * pageSize;
    if (start >= _maxListings) return const [];
    return [
      for (var n = start; n < start + pageSize && n < _maxListings; n++)
        MockData.listing(n),
    ];
  }
}
