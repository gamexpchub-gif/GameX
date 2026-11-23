import '../../../data/models/product.dart';
import 'protection.dart';

/// `acc:<icon>/<ARGB hex>` image spec, drawn by [AppImage].
String accImage(String icon, int color) =>
    'acc:$icon/${color.toRadixString(16).padLeft(8, '0')}';

class _Acc {
  const _Acc(
    this.key,
    this.name,
    this.icon,
    this.color,
    this.price,
    this.mrp,
    this.rating,
    this.reviews,
    this.desc, {
    this.brand,
    this.forModel = false,
    this.tag,
  });
  final String key;
  final String name;
  final String icon;
  final int color;
  final double price;
  final double mrp;
  final double rating;
  final int reviews;
  final String desc;

  /// Only for this phone brand (null = any).
  final String? brand;

  /// Name ends with "for (phone model)".
  final bool forModel;

  /// Short reason shown in cross-sell ("Most added").
  final String? tag;
}

const _all = [
  _Acc(
    'case-clear',
    'Clear MagSafe Case',
    'case',
    0xFF8FB4FF,
    899,
    1499,
    4.6,
    2140,
    'Crystal-clear, anti-yellowing case with built-in magnets and raised camera lip.',
    brand: 'Apple',
    forModel: true,
    tag: 'Most added',
  ),
  _Acc(
    'case-armor',
    'Rugged Armor Case',
    'case',
    0xFF334155,
    699,
    1299,
    4.5,
    3120,
    'Military-grade drop protection with air-cushion corners.',
    forModel: true,
    tag: 'Most added',
  ),
  _Acc(
    'glass',
    'Tempered Glass (2-pack)',
    'glass',
    0xFF22D3EE,
    399,
    799,
    4.4,
    5480,
    '9H hardness, edge-to-edge fit, easy install frame included.',
    forModel: true,
    tag: 'Must have',
  ),
  _Acc(
    'lens',
    'Camera Lens Protector',
    'lens',
    0xFFA78BFA,
    299,
    599,
    4.3,
    1280,
    'Sapphire-coated rings that protect every camera lens.',
    forModel: true,
  ),
  _Acc(
    'charger-20',
    '20W USB-C Fast Charger',
    'charger',
    0xFFF1F5F9,
    1299,
    1900,
    4.7,
    4210,
    '0-50% in 30 minutes. Phones are shipped without a charger.',
    brand: 'Apple',
    tag: 'No charger in box',
  ),
  _Acc(
    'charger-45',
    '45W Super Fast Charger',
    'charger',
    0xFF0F172A,
    1499,
    2999,
    4.6,
    2650,
    'PD 3.0 PPS charger with a 1m USB-C cable.',
    brand: 'Samsung',
    tag: 'No charger in box',
  ),
  _Acc(
    'charger-65',
    '65W Fast Charger + Cable',
    'charger',
    0xFFEF4444,
    1499,
    2499,
    4.5,
    1980,
    'Fast-charges most Android phones and laptops.',
    tag: 'No charger in box',
  ),
  _Acc(
    'cable-l',
    'USB-C to Lightning Cable',
    'cable',
    0xFFE2E8F0,
    499,
    1299,
    4.4,
    2240,
    'Braided, 1.2m, MFi certified.',
    brand: 'Apple',
  ),
  _Acc(
    'cable-c',
    'Braided USB-C Cable 1.5m',
    'cable',
    0xFF64748B,
    399,
    899,
    4.4,
    3300,
    '60W, nylon braided, 10,000+ bend tested.',
  ),
  _Acc(
    'buds',
    'GAMEX Buds Pro (ANC)',
    'buds',
    0xFF111827,
    2499,
    4999,
    4.5,
    1890,
    'Active noise cancellation, 32h battery, low-latency gaming mode.',
  ),
  _Acc(
    'powerbank',
    '10000mAh Power Bank 22.5W',
    'battery',
    0xFF16A34A,
    1199,
    2199,
    4.4,
    2760,
    'Slim power bank, charges a phone ~2 times.',
  ),
];

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

Product _product(_Acc a, {String? model}) => Product(
  id: 'acc-${a.key}${model == null || !a.forModel ? '' : '-${_slug(model)}'}',
  name: model == null || !a.forModel ? a.name : '${a.name} for $model',
  brand: 'GAMEX',
  categoryId: kAccessoryCategory,
  description: a.desc,
  price: a.price,
  oldPrice: a.mrp,
  images: [accImage(a.icon, a.color)],
  rating: a.rating,
  reviewCount: a.reviews,
  stock: 50,
  warrantyMonths: 6,
  verified: true,
  condition: 'Brand New',
  specs: {'Type': a.icon, if (a.tag != null) 'tag': a.tag!},
);

/// Accessories that fit [phone], most useful first.
List<Product> accessoriesFor(Product phone) {
  final brand = phone.brand;
  final apple = brand.toLowerCase() == 'apple';
  final model = phone.name;
  final picked = <_Acc>[
    for (final a in _all)
      if (a.brand == null || a.brand!.toLowerCase() == brand.toLowerCase()) a,
  ];
  // Apple gets the clear case; others the armor case. Android brands other
  // than Samsung get the generic 65W charger.
  picked.removeWhere(
    (a) =>
        (apple && a.key == 'case-armor') ||
        (!apple && a.key == 'cable-l') ||
        (brand.toLowerCase() == 'samsung' && a.key == 'charger-65') ||
        (apple && a.key == 'charger-65'),
  );
  return [for (final a in picked) _product(a, model: model)];
}

/// Accessories for everything in a cart, without duplicates or items
/// already in it.
List<Product> crossSellFor(Iterable<Product> phones, Set<String> inCart) {
  final seen = <String>{...inCart};
  return [
    for (final p in phones)
      for (final a in accessoriesFor(p))
        if (seen.add(a.id)) a,
  ];
}

String? accessoryTag(Product p) => p.specs['tag'];

bool isAccessory(Product p) => p.categoryId == kAccessoryCategory;
