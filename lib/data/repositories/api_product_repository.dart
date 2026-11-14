import '../../core/api.dart';
import '../mock/mock_data.dart';
import '../models/product.dart';
import 'product_repository.dart';

/// Catalogue backed by the GAMEX server: approved seller listings come first,
/// followed by the built-in catalogue. Falls back to the built-in catalogue
/// whenever the server can't be reached.
class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._api, [ProductRepository? fallback])
    : _mock = fallback ?? MockProductRepository();

  final Api _api;
  final ProductRepository _mock;

  List<Product>? _cache;
  DateTime _cachedAt = DateTime(2000);

  static const _brandToCategory = {
    'apple': 'apple',
    'samsung': 'samsung',
    'google': 'google',
    'oneplus': 'oneplus',
    'vivo': 'vivo',
    'xiaomi': 'xiaomi',
    'redmi': 'xiaomi',
    'realme': 'realme',
    'nothing': 'nothing',
    'motorola': 'motorola',
  };

  static const _grades = {
    'likeNew': 'Like New Condition',
    'excellent': 'Excellent Condition',
    'good': 'Good Condition',
    'fair': 'Fair Condition',
  };

  /// `/img/x.png` → bundled asset; `/uploads/..` → server URL.
  String _image(String path) {
    if (path.startsWith('/img/')) {
      return 'asset:assets/images/home/${path.substring(5)}';
    }
    if (path.startsWith('/')) return _api.media(path);
    return path;
  }

  Product _toProduct(Map<String, dynamic> j) {
    final brand = j['brand'] as String;
    final model = j['model'] as String;
    final name =
        brand == 'Apple' || model.toLowerCase().startsWith(brand.toLowerCase())
        ? model
        : '$brand $model';
    final seller = j['seller'] as Map?;
    final acc = (j['accessories'] as List? ?? const []).cast<String>();
    final notes = j['notes'] as String? ?? '';
    final checks = (j['checks'] as Map? ?? const {}).length;
    return Product(
      id: j['id'] as String,
      name: name,
      brand: brand,
      categoryId: _brandToCategory[brand.toLowerCase()] ?? 'apple',
      description: [
        'Certified pre-owned $brand $model in ${_grades[j['grade']]?.toLowerCase() ?? 'great condition'}.',
        'Battery health ${j['battery']}%. Passed all $checks GAMEX function checks and IMEI verification.',
        if (notes.isNotEmpty) 'Seller note: $notes.',
        if (acc.isNotEmpty) 'In the box: ${acc.join(', ')}.',
      ].join(' '),
      price: (j['price'] as num).toDouble(),
      oldPrice: (j['mrp'] as num?)?.toDouble(),
      images: [
        for (final p in (j['photos'] as List? ?? const []).cast<String>())
          _image(p),
      ],
      rating: (seller?['rating'] as num?)?.toDouble() ?? 4.6,
      reviewCount: (j['sold'] as num?)?.toInt() ?? 0,
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      isFeatured: j['featured'] == true,
      variant: '${j['storage']} • ${j['color']}',
      condition: _grades[j['grade']],
      warrantyMonths: (j['warranty'] as num?)?.toInt() ?? 0,
      verified: true,
      ram: j['ram'] as String?,
      batteryHealth: (j['battery'] as num?)?.toInt() ?? 0,
      soldCount: (j['sold'] as num?)?.toInt() ?? 0,
      specs: {
        'Sold by':
            '${seller?['storeName'] ?? 'GAMEX Seller'}, ${seller?['city'] ?? ''}',
        'Memory': '${j['ram']} RAM • ${j['storage']}',
        'Colour': j['color'] as String,
        'Battery health': '${j['battery']}%',
        if (j['certificate'] != null)
          'GAMEX certificate': j['certificate'] as String,
        'Warranty': (j['warranty'] as num? ?? 0) == 0
            ? 'No warranty'
            : '${j['warranty']} months seller warranty',
        if (acc.isNotEmpty) 'In the box': acc.join(', '),
      },
    );
  }

  Future<List<Product>> _server() async {
    final c = _cache;
    if (c != null && DateTime.now().difference(_cachedAt).inSeconds < 20) {
      return c;
    }
    try {
      final list = await _api.get('/products') as List;
      _cache = [for (final e in list) _toProduct(e as Map<String, dynamic>)];
      _cachedAt = DateTime.now();
    } catch (_) {
      _cache ??= const [];
    }
    return _cache!;
  }

  @override
  Future<List<Category>> categories() => _mock.categories();

  @override
  Future<List<PromoBanner>> banners() async {
    try {
      final list = (await _api.get('/banners') as List).cast<Map>();
      if (list.isEmpty) return await _mock.banners();
      final defaults = MockData.banners;
      return [
        for (var i = 0; i < list.length; i++)
          PromoBanner(
            id: list[i]['id'] as String,
            badge: defaults[i % defaults.length].badge,
            title: _wrap(list[i]['title'] as String),
            highlights: [
              for (final h in (list[i]['subtitle'] as String? ?? '').split('•'))
                if (h.trim().isNotEmpty) h.trim(),
            ].take(3).toList(),
            ctaLabel: list[i]['cta'] as String? ?? 'Shop Now',
            gradient: defaults[i % defaults.length].gradient,
            image: _image(list[i]['image'] as String? ?? ''),
            link: list[i]['link'] as String?,
          ),
      ];
    } catch (_) {
      return _mock.banners();
    }
  }

  /// Breaks a banner title into short lines for the hero layout.
  static String _wrap(String t) {
    if (t.contains('\n')) return t;
    final words = t.split(' ');
    final lines = <String>[];
    var cur = '';
    for (final w in words) {
      if (cur.isNotEmpty &&
          (cur.length + w.length + 1) > 13 &&
          lines.length < 2) {
        lines.add(cur);
        cur = w;
      } else {
        cur = cur.isEmpty ? w : '$cur $w';
      }
    }
    lines.add(cur);
    return lines.join('\n');
  }

  bool _matches(Product p, String? categoryId, String? query) {
    if (categoryId != null &&
        categoryId != 'all' &&
        p.categoryId != categoryId) {
      return false;
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
    }
    return true;
  }

  @override
  Future<List<Product>> products({
    String? categoryId,
    String? query,
    ProductSort sort = ProductSort.popular,
  }) async {
    final results = await Future.wait([
      _server(),
      _mock.products(categoryId: categoryId, query: query, sort: sort),
    ]);
    final server = results[0].where((p) => _matches(p, categoryId, query));
    final all = [...server, ...results[1]];
    switch (sort) {
      case ProductSort.priceLow:
        all.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceHigh:
        all.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.rating:
        all.sort((a, b) => b.rating.compareTo(a.rating));
      case ProductSort.popular:
      case ProductSort.newest:
        break;
    }
    return all;
  }

  @override
  Future<Product?> byId(String id) async {
    if (!id.startsWith('GXL')) return _mock.byId(id);
    try {
      return _toProduct(
        await _api.get('/products/$id') as Map<String, dynamic>,
      );
    } catch (_) {
      for (final p in _cache ?? const <Product>[]) {
        if (p.id == id) return p;
      }
      return null;
    }
  }

  @override
  Future<List<Product>> newListings({
    required int page,
    int pageSize = 12,
  }) async {
    final mock = await _mock.newListings(page: page, pageSize: pageSize);
    if (page != 0) return mock;
    final server = await _server();
    // Keep the page full so the feed keeps paging.
    return [...server, ...mock];
  }
}
