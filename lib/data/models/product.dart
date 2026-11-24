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

/// A colour / storage option of a marketplace listing with its own price.
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.color,
    required this.storage,
    required this.price,
    required this.mrp,
    required this.stock,
    this.ram,
    this.colorValue,
    this.image,
  });

  /// 'base' = the listing's main option.
  final String id;
  final String color;
  final String storage;
  final String? ram;
  final double price;
  final double mrp;
  final int stock;

  /// ARGB swatch, when known.
  final int? colorValue;
  final String? image;

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
    id: j['id'] as String,
    color: j['color'] as String? ?? '',
    storage: j['storage'] as String? ?? '',
    ram: j['ram'] as String?,
    price: (j['price'] as num).toDouble(),
    mrp: (j['mrp'] as num?)?.toDouble() ?? (j['price'] as num).toDouble(),
    stock: (j['stock'] as num?)?.toInt() ?? 0,
    colorValue: (j['colorValue'] as num?)?.toInt(),
    image: j['image'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color,
    'storage': storage,
    'ram': ram,
    'price': price,
    'mrp': mrp,
    'stock': stock,
    'colorValue': colorValue,
    'image': image,
  };
}

/// Seller highlight photo with a caption.
class ProductHighlight {
  const ProductHighlight({required this.image, this.title = '', this.text = ''});
  final String image;
  final String title;
  final String text;

  factory ProductHighlight.fromJson(Map<String, dynamic> j) => ProductHighlight(
    image: j['image'] as String,
    title: j['title'] as String? ?? '',
    text: j['text'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {'image': image, 'title': title, 'text': text};
}

/// Grouped specification row (Display › Refresh rate › 120Hz).
class SpecEntry {
  const SpecEntry(this.group, this.key, this.value);
  final String group;
  final String key;
  final String value;

  factory SpecEntry.fromJson(Map<String, dynamic> j) => SpecEntry(
    j['group'] as String? ?? 'General',
    j['k'] as String? ?? '',
    j['v'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {'group': group, 'k': key, 'v': value};
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
    this.ram,
    this.batteryHealth = 0,
    this.soldCount = 0,
    this.specs = const {},
    this.sellerId,
    this.sellerName,
    this.sellerCity,
    this.certificate,
    this.checks = const {},
    this.defects = const [],
    this.returnDays = 7,
    this.variants = const [],
    this.variantId,
    this.highlights = const [],
    this.specRows = const [],
    this.deviceType = 'Mobile Phone',
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

  /// e.g. "8GB".
  final String? ram;

  /// Battery health in percent (second-hand phones), 0 when unknown.
  final int batteryHealth;
  final int soldCount;

  /// Key specifications, e.g. {'Display': '6.1" OLED 120Hz'}.
  final Map<String, String> specs;

  /// Marketplace seller (null for the built-in GAMEX catalogue).
  final String? sellerId;
  final String? sellerName;
  final String? sellerCity;

  /// GAMEX QC certificate number (e.g. GXC-48120-1000).
  final String? certificate;

  /// Seller function checks ({'Display & touch': true, ...}).
  final Map<String, bool> checks;

  /// Cosmetic defects marked on the photos by GAMEX QC.
  final List<PhotoDefect> defects;

  /// Days the buyer can return after delivery (0 = no returns).
  final int returnDays;

  /// Every colour / storage option (marketplace listings). Empty for the
  /// built-in catalogue.
  final List<ProductVariant> variants;

  /// Option picked on the product page ('base' or a variant id).
  final String? variantId;
  final List<ProductHighlight> highlights;

  /// Seller's grouped specifications.
  final List<SpecEntry> specRows;

  /// Mobile Phone, Tablet, Smartwatch, Earbuds & Audio.
  final String deviceType;

  bool get isMarketplace => sellerId != null;

  bool get inStock => stock > 0;

  /// Storage part of [variant] ("128GB").
  String? get storage => variant?.split('•').first.trim();

  /// Colour name part of [variant] ("Deep Purple").
  String? get colorName {
    final parts = variant?.split('•');
    return parts == null || parts.length < 2 ? null : parts[1].trim();
  }

  /// "8GB / 128GB" (falls back to storage only).
  String? get memoryLabel {
    final s = storage;
    if (s == null) return ram;
    return ram == null ? s : '$ram / $s';
  }

  /// MRP (the crossed-out price).
  double get mrp => oldPrice ?? price;

  Product copyWith({
    String? id,
    double? price,
    double? oldPrice,
    String? variant,
    String? condition,
    String? ram,
    int? batteryHealth,
    int? stock,
    List<int>? colors,
    String? variantId,
    List<String>? images,
  }) => Product(
    id: id ?? this.id,
    name: name,
    brand: brand,
    categoryId: categoryId,
    description: description,
    price: price ?? this.price,
    oldPrice: oldPrice ?? this.oldPrice,
    images: images ?? this.images,
    rating: rating,
    reviewCount: reviewCount,
    stock: stock ?? this.stock,
    sizes: sizes,
    colors: colors ?? this.colors,
    isFeatured: isFeatured,
    isFlashSale: isFlashSale,
    variant: variant ?? this.variant,
    condition: condition ?? this.condition,
    warrantyMonths: warrantyMonths,
    verified: verified,
    ram: ram ?? this.ram,
    batteryHealth: batteryHealth ?? this.batteryHealth,
    soldCount: soldCount,
    specs: specs,
    sellerId: sellerId,
    sellerName: sellerName,
    sellerCity: sellerCity,
    certificate: certificate,
    checks: checks,
    defects: defects,
    returnDays: returnDays,
    variants: variants,
    variantId: variantId ?? this.variantId,
    highlights: highlights,
    specRows: specRows,
    deviceType: deviceType,
  );

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
    ram: json['ram'] as String?,
    batteryHealth: json['batteryHealth'] as int? ?? 0,
    soldCount: json['soldCount'] as int? ?? 0,
    specs: Map<String, String>.from(json['specs'] as Map? ?? const {}),
    sellerId: json['sellerId'] as String?,
    sellerName: json['sellerName'] as String?,
    sellerCity: json['sellerCity'] as String?,
    certificate: json['certificate'] as String?,
    checks: Map<String, bool>.from(json['checks'] as Map? ?? const {}),
    defects: [
      for (final d in (json['defects'] as List? ?? const []))
        PhotoDefect.fromJson(d as Map<String, dynamic>),
    ],
    returnDays: (json['returnDays'] as num?)?.toInt() ?? 7,
    variants: [
      for (final v in (json['variants'] as List? ?? const []))
        ProductVariant.fromJson(v as Map<String, dynamic>),
    ],
    variantId: json['variantId'] as String?,
    highlights: [
      for (final v in (json['highlights'] as List? ?? const []))
        ProductHighlight.fromJson(v as Map<String, dynamic>),
    ],
    specRows: [
      for (final v in (json['specRows'] as List? ?? const []))
        SpecEntry.fromJson(v as Map<String, dynamic>),
    ],
    deviceType: json['deviceType'] as String? ?? 'Mobile Phone',
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
    'ram': ram,
    'batteryHealth': batteryHealth,
    'soldCount': soldCount,
    'specs': specs,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'sellerCity': sellerCity,
    'certificate': certificate,
    'checks': checks,
    'defects': [for (final d in defects) d.toJson()],
    'returnDays': returnDays,
    if (variants.isNotEmpty) 'variants': [for (final v in variants) v.toJson()],
    'variantId': ?variantId,
    if (highlights.isNotEmpty)
      'highlights': [for (final h in highlights) h.toJson()],
    if (specRows.isNotEmpty) 'specRows': [for (final r in specRows) r.toJson()],
    'deviceType': deviceType,
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

/// A cosmetic defect marked on a listing photo (x/y are 0..1 of the image).
class PhotoDefect {
  const PhotoDefect({
    required this.photo,
    required this.x,
    required this.y,
    required this.label,
  });

  final int photo;
  final double x;
  final double y;
  final String label;

  factory PhotoDefect.fromJson(Map<String, dynamic> j) => PhotoDefect(
    photo: (j['photo'] as num?)?.toInt() ?? 0,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    label: j['label'] as String? ?? 'Defect',
  );

  Map<String, dynamic> toJson() => {
    'photo': photo,
    'x': x,
    'y': y,
    'label': label,
  };
}
