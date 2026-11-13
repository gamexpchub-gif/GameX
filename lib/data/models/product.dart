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
  };
}

class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    this.categoryId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String image;
  final String? categoryId;
}
