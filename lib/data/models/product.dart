class Category {
  const Category({required this.id, required this.name, required this.icon});

  final String id;
  final String name;

  /// Icon key (e.g. 'phone', 'fashion'); mapped to a Material icon in the UI
  /// so the admin panel can pick icons later.
  final String icon;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon};
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.description,
    required this.price,
    required this.images,
    this.oldPrice,
    this.rating = 0,
    this.reviewCount = 0,
    this.stock = 0,
    this.sizes = const [],
    this.colors = const [],
    this.isFeatured = false,
    this.isFlashSale = false,
    this.variant,
    this.condition,
    this.warrantyMonths = 0,
    this.verified = false,
  });

  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final String description;
  final double price;
  final double? oldPrice;
  final List<String> images;
  final double rating;
  final int reviewCount;
  final int stock;
  final List<String> sizes;

  /// ARGB colour values.
  final List<int> colors;
  final bool isFeatured;
  final bool isFlashSale;

  /// e.g. "128GB • Deep Purple".
  final String? variant;

  /// Second-hand grade, e.g. "Excellent Condition".
  final String? condition;
  final int warrantyMonths;

  /// Passed GAMEX inspection.
  final bool verified;

  bool get inStock => stock > 0;

  int get discountPercent {
    final old = oldPrice;
    if (old == null || old <= price) return 0;
    return (((old - price) / old) * 100).round();
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    categoryId: json['categoryId'] as String,
    description: json['description'] as String,
    price: (json['price'] as num).toDouble(),
    oldPrice: (json['oldPrice'] as num?)?.toDouble(),
    images: List<String>.from(json['images'] as List),
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    reviewCount: json['reviewCount'] as int? ?? 0,
    stock: json['stock'] as int? ?? 0,
    sizes: List<String>.from(json['sizes'] as List? ?? const []),
    colors: List<int>.from(json['colors'] as List? ?? const []),
    isFeatured: json['isFeatured'] as bool? ?? false,
    isFlashSale: json['isFlashSale'] as bool? ?? false,
    variant: json['variant'] as String?,
    condition: json['condition'] as String?,
    warrantyMonths: json['warrantyMonths'] as int? ?? 0,
    verified: json['verified'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'categoryId': categoryId,
    'description': description,
    'price': price,
    'oldPrice': oldPrice,
    'images': images,
    'rating': rating,
    'reviewCount': reviewCount,
    'stock': stock,
    'sizes': sizes,
    'colors': colors,
    'isFeatured': isFeatured,
    'isFlashSale': isFlashSale,
    'variant': variant,
    'condition': condition,
    'warrantyMonths': warrantyMonths,
    'verified': verified,
  };
}

/// Home hero banner. Managed from the super admin panel later; until then
/// [MockData.banners] provides 4 defaults.
class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.badge,
    required this.title,
    required this.highlights,
    required this.ctaLabel,
    required this.gradient,
    this.art = 'art:phone/FF5B3E96/back',
    this.image,
    this.link,
  });

  final String id;

  /// Small pill above the title, e.g. "GAMEX Certified".
  final String badge;
  final String title;

  /// Shown as "Verified • Tested • Trusted".
  final List<String> highlights;
  final String ctaLabel;

  /// ARGB colours of the background gradient (left → right).
  final List<int> gradient;

  /// Built-in phone illustration (`art:` spec) used when [image] is null.
  final String art;

  /// Banner artwork: `asset:` path for the defaults, or a network URL
  /// uploaded from the admin panel. The badge/title/CTA are rendered live on
  /// top of it; leave [title] empty for artwork with text already baked in.
  final String? image;

  /// In-app route opened on tap, e.g. `/category/apple`.
  final String? link;

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
    id: json['id'] as String,
    badge: json['badge'] as String? ?? '',
    title: json['title'] as String,
    highlights: List<String>.from(json['highlights'] as List? ?? const []),
    ctaLabel: json['ctaLabel'] as String? ?? 'Shop Now',
    gradient: List<int>.from(json['gradient'] as List),
    art: json['art'] as String? ?? 'art:phone/FF5B3E96/back',
    image: json['image'] as String?,
    link: json['link'] as String?,
  );
}
