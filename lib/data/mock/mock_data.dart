import '../models/product.dart';

/// Demo catalogue used until the super admin panel / backend API is ready.
abstract final class MockData {
  /// Built-in phone illustration spec understood by `AppImage`.
  /// [view] is `back`, `front` or `duo`.
  static String art(int color, [String view = 'back']) =>
      'art:phone/${color.toRadixString(16).toUpperCase()}/$view';

  /// Brands double as catalogue categories.
  static const categories = <Category>[
    Category(id: 'apple', name: 'Apple', icon: 'apple'),
    Category(id: 'samsung', name: 'Samsung', icon: 'samsung'),
    Category(id: 'google', name: 'Google', icon: 'google'),
    Category(id: 'oneplus', name: 'OnePlus', icon: 'oneplus'),
    Category(id: 'vivo', name: 'vivo', icon: 'vivo'),
    Category(id: 'xiaomi', name: 'Redmi', icon: 'xiaomi'),
    Category(id: 'realme', name: 'Realme', icon: 'realme'),
    Category(id: 'nothing', name: 'Nothing', icon: 'nothing'),
    Category(id: 'motorola', name: 'Motorola', icon: 'motorola'),
  ];

  /// The 4 default hero banners (replaced by admin-managed ones later).
  static final banners = <PromoBanner>[
    PromoBanner(
      id: 'b1',
      badge: 'GAMEX Certified',
      title: 'Premium\nSecond-Hand\nMobiles',
      highlights: const ['Verified', 'Tested', 'Trusted'],
      ctaLabel: 'Shop Now',
      gradient: const [0xFF041659, 0xFF032B76, 0xFF2967D2],
      image: 'asset:assets/images/home/hero_banner.png',
      link: '/category/all',
    ),
    PromoBanner(
      id: 'b2',
      badge: 'Exchange Offer',
      title: 'Trade-In &\nUpgrade\nToday',
      highlights: const ['Instant Quote', 'Free Pickup'],
      ctaLabel: 'Exchange Now',
      gradient: const [0xFF1E1065, 0xFF3B1FB0, 0xFF6D4BFF],
      image: 'asset:assets/images/home/hero_banner_violet.png',
      link: '/category/apple',
    ),
    PromoBanner(
      id: 'b3',
      badge: 'Smart EMI',
      title: '0% EMI on\nFlagship\nPhones',
      highlights: const ['No Cost', 'Easy Approval', '12 Months'],
      ctaLabel: 'Check EMI',
      gradient: const [0xFF06365E, 0xFF0A5BA8, 0xFF1C8BE0],
      image: 'asset:assets/images/home/hero_banner_teal.png',
      link: '/category/samsung',
    ),
    PromoBanner(
      id: 'b4',
      badge: '6 Month Warranty',
      title: 'Like-New\nPhones, Pro\nChecked',
      highlights: const ['70-Point Check', '7-Day Return'],
      ctaLabel: 'Explore',
      gradient: const [0xFF2A0E5C, 0xFF5A1F9E, 0xFF9B3FD6],
      image: 'asset:assets/images/home/hero_banner_magenta.png',
      link: '/category/google',
    ),
  ];

  static const _desc =
      'GAMEX Certified pre-owned phone. Passed our 70-point inspection covering '
      'display, battery health, cameras, speakers, sensors and network. '
      'Original parts, IMEI verified and factory reset. Comes with charger, '
      'warranty and a 7-day easy return.';

  static final products = <Product>[
    _p(
      'p17',
      'Realme GT 6',
      'Realme',
      'realme',
      34999,
      46999,
      4.5,
      1800,
      12,
      '256GB • Fluid Silver',
      0xFFC9CED8,
    ),
    _p(
      'p18',
      'Nothing Phone (2a)',
      'Nothing',
      'nothing',
      27999,
      36999,
      4.6,
      2400,
      9,
      '256GB • Milk White',
      0xFFEDEDEA,
      featured: true,
    ),
    _p(
      'p19',
      'Motorola Edge 50 Pro',
      'Motorola',
      'motorola',
      31999,
      42999,
      4.5,
      1300,
      14,
      '256GB • Luxe Lavender',
      0xFFB7A6D6,
    ),
    _p(
      'p1',
      'iPhone 14 Pro',
      'Apple',
      'apple',
      49999,
      69999,
      4.8,
      12500,
      14,
      '128GB • Deep Purple',
      0xFF5B3E96,
      featured: true,
      flash: true,
    ),
    _p(
      'p2',
      'iPhone 13',
      'Apple',
      'apple',
      38999,
      52999,
      4.7,
      8400,
      20,
      '128GB • Midnight',
      0xFF2B2F3A,
      featured: true,
    ),
    _p(
      'p3',
      'iPhone 15 Pro Max',
      'Apple',
      'apple',
      104999,
      129999,
      4.9,
      6100,
      6,
      '256GB • Natural Titanium',
      0xFFBDB6A8,
      featured: true,
      flash: true,
    ),
    _p(
      'p4',
      'iPhone 12',
      'Apple',
      'apple',
      27999,
      39999,
      4.5,
      9700,
      25,
      '64GB • Blue',
      0xFF2F6DB5,
      condition: 'Good Condition',
      warranty: 3,
    ),
    _p(
      'p5',
      'Galaxy S23 Ultra',
      'Samsung',
      'samsung',
      74999,
      99999,
      4.8,
      5300,
      9,
      '256GB • Phantom Black',
      0xFF22252B,
      featured: true,
      flash: true,
    ),
    _p(
      'p6',
      'Galaxy S22',
      'Samsung',
      'samsung',
      36999,
      49999,
      4.5,
      3900,
      18,
      '128GB • Green',
      0xFF3E5E52,
    ),
    _p(
      'p7',
      'Galaxy Z Flip5',
      'Samsung',
      'samsung',
      54999,
      74999,
      4.6,
      2100,
      7,
      '256GB • Lavender',
      0xFFB8A6D9,
      featured: true,
    ),
    _p(
      'p8',
      'Pixel 8 Pro',
      'Google',
      'google',
      59999,
      79999,
      4.7,
      2800,
      8,
      '128GB • Bay Blue',
      0xFF7FA6C9,
      featured: true,
      flash: true,
    ),
    _p(
      'p9',
      'Pixel 7a',
      'Google',
      'google',
      24999,
      32999,
      4.5,
      4100,
      22,
      '128GB • Charcoal',
      0xFF3A3D45,
      condition: 'Good Condition',
      warranty: 3,
    ),
    _p(
      'p10',
      'OnePlus 12',
      'OnePlus',
      'oneplus',
      52999,
      64999,
      4.7,
      3300,
      11,
      '256GB • Flowy Emerald',
      0xFF1F5E4B,
      featured: true,
    ),
    _p(
      'p11',
      'OnePlus 11R',
      'OnePlus',
      'oneplus',
      29999,
      39999,
      4.5,
      4700,
      15,
      '128GB • Sonic Black',
      0xFF26282E,
      flash: true,
    ),
    _p(
      'p12',
      'vivo X100 Pro',
      'vivo',
      'vivo',
      61999,
      84999,
      4.6,
      1500,
      5,
      '256GB • Asteroid Black',
      0xFF1E2230,
      featured: true,
    ),
    _p(
      'p13',
      'vivo V29',
      'vivo',
      'vivo',
      26999,
      36999,
      4.4,
      2200,
      19,
      '256GB • Peak Blue',
      0xFF2C5C9E,
    ),
    _p(
      'p14',
      'Xiaomi 14',
      'Xiaomi',
      'xiaomi',
      47999,
      62999,
      4.6,
      1900,
      10,
      '256GB • Jade Green',
      0xFF6E9C84,
      featured: true,
      flash: true,
    ),
    _p(
      'p15',
      'Redmi Note 13 Pro',
      'Xiaomi',
      'xiaomi',
      19999,
      27999,
      4.4,
      6300,
      30,
      '256GB • Aurora Purple',
      0xFF7B5EB8,
      condition: 'Good Condition',
      warranty: 3,
    ),
    _p(
      'p16',
      'iPhone 11',
      'Apple',
      'apple',
      21999,
      31999,
      4.4,
      15200,
      0,
      '64GB • White',
      0xFFEDEDEA,
      condition: 'Good Condition',
      warranty: 3,
    ),
  ];

  static const _photo = <String, String>{
    'p1': 'iphone14pro',
    'p2': 'iphone_midnight',
    'p3': 'iphone_titanium',
    'p4': 'iphone_blue',
    'p16': 'iphone_starlight',
  };

  /// iPhones use real product photos: the front+back shot first, then the
  /// front-only shot.
  static List<String> _images(String id, int color) {
    final photo = _photo[id];
    if (photo == null) {
      return [art(color, 'duo'), art(color, 'back'), art(color, 'front')];
    }
    return [
      'asset:assets/images/home/deal_$photo.png',
      'asset:assets/images/home/front_$photo.png',
    ];
  }

  static Product _p(
    String id,
    String name,
    String brand,
    String category,
    double price,
    double? oldPrice,
    double rating,
    int reviews,
    int stock,
    String variant,
    int color, {
    bool featured = false,
    bool flash = false,
    String condition = 'Excellent Condition',
    int warranty = 6,
  }) => Product(
    id: id,
    name: name,
    brand: brand,
    categoryId: category,
    description: _desc,
    price: price,
    oldPrice: oldPrice,
    images: _images(id, color),
    rating: rating,
    reviewCount: reviews,
    stock: stock,
    isFeatured: featured,
    isFlashSale: flash,
    variant: variant,
    condition: condition,
    warrantyMonths: warranty,
    verified: true,
    colors: [color],
    ram: _ram[id] ?? '8GB',
    batteryHealth: 84 + (id.hashCode % 15).abs(),
    soldCount: reviews * 3 + 120,
    specs: _specs(brand, name),
  );

  static const _ram = <String, String>{
    'p1': '6GB',
    'p2': '4GB',
    'p3': '8GB',
    'p4': '4GB',
    'p16': '4GB',
    'p5': '12GB',
    'p6': '8GB',
    'p7': '8GB',
    'p8': '12GB',
    'p9': '8GB',
    'p10': '12GB',
    'p11': '8GB',
    'p12': '16GB',
    'p13': '8GB',
    'p14': '12GB',
    'p15': '8GB',
    'p17': '12GB',
    'p18': '8GB',
    'p19': '12GB',
  };

  static Map<String, String> _specs(String brand, String name) {
    final apple = brand == 'Apple';
    return {
      'Display': apple
          ? '6.1" Super Retina XDR OLED, 120Hz'
          : '6.7" AMOLED, 120Hz, HDR10+',
      'Processor': apple
          ? 'Apple A-series Bionic'
          : 'Snapdragon 8 series / flagship',
      'Rear Camera': apple ? '48MP + 12MP + 12MP' : '50MP + 48MP + 12MP',
      'Front Camera': '12MP',
      'Battery': apple
          ? '3200 mAh, 20W fast charge'
          : '5000 mAh, 67W fast charge',
      'OS': apple ? 'iOS (latest supported)' : 'Android (latest supported)',
      'Network': '5G, Dual SIM (nano + eSIM)',
      'In the box': 'Phone, charging cable, SIM tool',
    };
  }

  // ───────────────────────── New listings feed ─────────────────────────

  static const _grades = [
    ('Like New', 1.06),
    ('Excellent Condition', 1.0),
    ('Good Condition', 0.9),
  ];

  /// Deterministic second-hand listing #n (id `<base>-l<n>`), so a listing
  /// can be re-created from its id alone.
  static Product listing(int n) {
    final base = products[(n * 7) % products.length];
    final (grade, factor) = _grades[n % _grades.length];
    final price =
        ((base.price * factor * (0.94 + (n % 5) * 0.03)) / 100).round() * 100 -
        1.0;
    return base.copyWith(
      id: '${base.id}-l$n',
      price: price,
      condition: grade,
      batteryHealth: 80 + (n * 13) % 20,
      stock: 1 + n % 4,
    );
  }

  static Product? byId(String id) {
    final m = RegExp(r'^(p\d+)-l(\d+)$').firstMatch(id);
    if (m != null) return listing(int.parse(m.group(2)!));
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}
