import 'dart:math' as math;

import '../../../data/models/product.dart';

/// What GAMEX knows about a phone model: launch price, year and how good it
/// is at the things buyers care about (0-10).
class ModelInfo {
  const ModelInfo({
    required this.launchPrice,
    required this.year,
    required this.chip,
    required this.gaming,
    required this.camera,
    required this.battery,
    this.is5G = true,
    this.display = '',
    this.batteryMah = 0,
  });

  /// Indian launch price of the variant most often resold (₹).
  final double launchPrice;
  final int year;
  final String chip;
  final int gaming;
  final int camera;
  final int battery;
  final bool is5G;
  final String display;
  final int batteryMah;

  int get allRounder => ((gaming + camera + battery) / 3).round();
}

/// Model knowledge base. Keys are matched against the product name
/// (longest key that the name contains wins).
const kModels = <String, ModelInfo>{
  'iPhone 11': ModelInfo(
    launchPrice: 64900,
    year: 2019,
    chip: 'A13 Bionic',
    gaming: 6,
    camera: 6,
    battery: 6,
    is5G: false,
    display: '6.1" LCD',
    batteryMah: 3110,
  ),
  'iPhone 12': ModelInfo(
    launchPrice: 79900,
    year: 2020,
    chip: 'A14 Bionic',
    gaming: 7,
    camera: 7,
    battery: 5,
    display: '6.1" OLED',
    batteryMah: 2815,
  ),
  'iPhone 13': ModelInfo(
    launchPrice: 79900,
    year: 2021,
    chip: 'A15 Bionic',
    gaming: 8,
    camera: 8,
    battery: 7,
    display: '6.1" OLED',
    batteryMah: 3240,
  ),
  'iPhone 14': ModelInfo(
    launchPrice: 79900,
    year: 2022,
    chip: 'A15 Bionic',
    gaming: 8,
    camera: 8,
    battery: 7,
    display: '6.1" OLED',
    batteryMah: 3279,
  ),
  'iPhone 14 Pro': ModelInfo(
    launchPrice: 129900,
    year: 2022,
    chip: 'A16 Bionic',
    gaming: 9,
    camera: 9,
    battery: 7,
    display: '6.1" OLED 120Hz',
    batteryMah: 3200,
  ),
  'iPhone 15': ModelInfo(
    launchPrice: 79900,
    year: 2023,
    chip: 'A16 Bionic',
    gaming: 8,
    camera: 8,
    battery: 7,
    display: '6.1" OLED',
    batteryMah: 3349,
  ),
  'iPhone 15 Pro': ModelInfo(
    launchPrice: 134900,
    year: 2023,
    chip: 'A17 Pro',
    gaming: 10,
    camera: 9,
    battery: 7,
    display: '6.1" OLED 120Hz',
    batteryMah: 3274,
  ),
  'iPhone 15 Pro Max': ModelInfo(
    launchPrice: 159900,
    year: 2023,
    chip: 'A17 Pro',
    gaming: 10,
    camera: 10,
    battery: 9,
    display: '6.7" OLED 120Hz',
    batteryMah: 4422,
  ),
  'Galaxy S22': ModelInfo(
    launchPrice: 72999,
    year: 2022,
    chip: 'Exynos 2200',
    gaming: 7,
    camera: 8,
    battery: 5,
    display: '6.1" AMOLED 120Hz',
    batteryMah: 3700,
  ),
  'Galaxy S23 Ultra': ModelInfo(
    launchPrice: 124999,
    year: 2023,
    chip: 'Snapdragon 8 Gen 2',
    gaming: 9,
    camera: 10,
    battery: 9,
    display: '6.8" AMOLED 120Hz',
    batteryMah: 5000,
  ),
  'Galaxy S24': ModelInfo(
    launchPrice: 79999,
    year: 2024,
    chip: 'Exynos 2400',
    gaming: 8,
    camera: 8,
    battery: 7,
    display: '6.2" AMOLED 120Hz',
    batteryMah: 4000,
  ),
  'Galaxy Z Flip5': ModelInfo(
    launchPrice: 99999,
    year: 2023,
    chip: 'Snapdragon 8 Gen 2',
    gaming: 7,
    camera: 7,
    battery: 5,
    display: '6.7" Foldable AMOLED',
    batteryMah: 3700,
  ),
  'Pixel 7a': ModelInfo(
    launchPrice: 43999,
    year: 2023,
    chip: 'Tensor G2',
    gaming: 6,
    camera: 8,
    battery: 6,
    display: '6.1" OLED 90Hz',
    batteryMah: 4385,
  ),
  'Pixel 8 Pro': ModelInfo(
    launchPrice: 106999,
    year: 2023,
    chip: 'Tensor G3',
    gaming: 7,
    camera: 10,
    battery: 8,
    display: '6.7" LTPO OLED 120Hz',
    batteryMah: 5050,
  ),
  'OnePlus 12': ModelInfo(
    launchPrice: 69999,
    year: 2024,
    chip: 'Snapdragon 8 Gen 3',
    gaming: 10,
    camera: 8,
    battery: 9,
    display: '6.82" AMOLED 120Hz',
    batteryMah: 5400,
  ),
  'OnePlus 11R': ModelInfo(
    launchPrice: 44999,
    year: 2023,
    chip: 'Snapdragon 8+ Gen 1',
    gaming: 8,
    camera: 6,
    battery: 9,
    display: '6.74" AMOLED 120Hz',
    batteryMah: 5000,
  ),
  'X100 Pro': ModelInfo(
    launchPrice: 89999,
    year: 2024,
    chip: 'Dimensity 9300',
    gaming: 9,
    camera: 10,
    battery: 9,
    display: '6.78" AMOLED 120Hz',
    batteryMah: 5400,
  ),
  'V29': ModelInfo(
    launchPrice: 36999,
    year: 2023,
    chip: 'Snapdragon 778G',
    gaming: 6,
    camera: 8,
    battery: 7,
    display: '6.78" AMOLED 120Hz',
    batteryMah: 4600,
  ),
  'Xiaomi 14': ModelInfo(
    launchPrice: 69999,
    year: 2024,
    chip: 'Snapdragon 8 Gen 3',
    gaming: 9,
    camera: 9,
    battery: 7,
    display: '6.36" AMOLED 120Hz',
    batteryMah: 4610,
  ),
  'Redmi Note 13 Pro': ModelInfo(
    launchPrice: 29999,
    year: 2024,
    chip: 'Snapdragon 7s Gen 2',
    gaming: 6,
    camera: 7,
    battery: 8,
    display: '6.67" AMOLED 120Hz',
    batteryMah: 5100,
  ),
  'GT 6': ModelInfo(
    launchPrice: 42999,
    year: 2024,
    chip: 'Snapdragon 8s Gen 3',
    gaming: 9,
    camera: 7,
    battery: 9,
    display: '6.78" AMOLED 120Hz',
    batteryMah: 5500,
  ),
  'Phone (2a)': ModelInfo(
    launchPrice: 27999,
    year: 2024,
    chip: 'Dimensity 7200 Pro',
    gaming: 6,
    camera: 6,
    battery: 8,
    display: '6.7" AMOLED 120Hz',
    batteryMah: 5000,
  ),
  'Phone (2)': ModelInfo(
    launchPrice: 44999,
    year: 2023,
    chip: 'Snapdragon 8+ Gen 1',
    gaming: 8,
    camera: 7,
    battery: 7,
    display: '6.7" LTPO OLED 120Hz',
    batteryMah: 4700,
  ),
  'Edge 50 Pro': ModelInfo(
    launchPrice: 35999,
    year: 2024,
    chip: 'Snapdragon 7 Gen 3',
    gaming: 6,
    camera: 7,
    battery: 7,
    display: '6.7" pOLED 144Hz',
    batteryMah: 4500,
  ),
};

final _keysByLength = kModels.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

/// Model info for [p]; falls back to an estimate built from its MRP.
ModelInfo modelInfo(Product p) {
  final name = p.name.toLowerCase();
  for (final k in _keysByLength) {
    if (name.contains(k.toLowerCase())) return kModels[k]!;
  }
  return ModelInfo(
    launchPrice: p.mrp,
    year: DateTime.now().year - 1,
    chip: p.specs['Processor'] ?? '—',
    gaming: 7,
    camera: 7,
    battery: 7,
    is5G: (p.specs['Network'] ?? '5G').contains('5G'),
  );
}

// ───────────────────────── Normalised attributes ─────────────────────────

/// "Like New" / "Excellent" / "Good" / "Fair".
String gradeOf(Product p) {
  final c = (p.condition ?? 'Excellent').replaceAll(' Condition', '').trim();
  return switch (c.toLowerCase()) {
    'like new' => 'Like New',
    'good' => 'Good',
    'fair' => 'Fair',
    _ => 'Excellent',
  };
}

const kGrades = ['Like New', 'Excellent', 'Good', 'Fair'];

int ramOf(Product p) =>
    int.tryParse(RegExp(r'\d+').firstMatch(p.ram ?? '')?.group(0) ?? '') ?? 0;

/// Storage in GB (1TB = 1024).
int storageOf(Product p) {
  final s = (p.storage ?? '').toUpperCase();
  final n = int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '') ?? 0;
  return s.contains('TB') ? n * 1024 : n;
}

int batteryOf(Product p) => p.batteryHealth == 0 ? 90 : p.batteryHealth;

const kCities = [
  'Mumbai',
  'Delhi',
  'Bengaluru',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Pune',
  'Ahmedabad',
];

/// City the phone ships from: the seller's city, or the GAMEX hub that
/// stocks the built-in catalogue item.
String shipsFrom(Product p) {
  if (p.sellerCity != null && p.sellerCity!.isNotEmpty) return p.sellerCity!;
  final h = p.id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  return kCities[h % kCities.length];
}

String sellerOf(Product p) => p.sellerName ?? 'GAMEX Official';

// ───────────────────────────── Fair price ─────────────────────────────

enum PriceVerdict {
  great('Great Deal'),
  fair('Fair Price'),
  high('Above Market');

  const PriceVerdict(this.label);
  final String label;
}

class FairPrice {
  const FairPrice({
    required this.price,
    required this.market,
    required this.launch,
    required this.ageFactor,
    required this.gradeFactor,
    required this.batteryFactor,
    required this.storageFactor,
    required this.comparables,
  });

  final double price;

  /// Estimated fair market value of this exact phone.
  final double market;
  final double launch;
  final double ageFactor;
  final double gradeFactor;
  final double batteryFactor;
  final double storageFactor;

  /// Number of similar listings that informed the estimate.
  final int comparables;

  double get low => _r(market * 0.94);
  double get high => _r(market * 1.06);

  /// Price vs market (-0.12 = 12% below market).
  double get delta => (price - market) / market;

  PriceVerdict get verdict => delta <= -0.06
      ? PriceVerdict.great
      : delta <= 0.07
      ? PriceVerdict.fair
      : PriceVerdict.high;

  /// 0 (cheapest end) … 1 (most expensive end) for the meter needle.
  double get position => ((delta + 0.25) / 0.5).clamp(0.0, 1.0);

  /// Rupees saved (positive) or overpaid (negative) against the market.
  double get savings => market - price;

  static double _r(double v) => (v / 100).round() * 100;
}

const _gradeFactor = {
  'Like New': 1.05,
  'Excellent': 1.0,
  'Good': 0.91,
  'Fair': 0.82,
};

/// Fair market value of [p], from its launch price, age, condition,
/// battery health and storage, blended with similar listings in [market]
/// when there are enough of them.
FairPrice fairPriceOf(Product p, {Iterable<Product> market = const []}) {
  final m = modelInfo(p);
  final age = math.max(0, DateTime.now().year - m.year);
  final apple = p.brand.toLowerCase() == 'apple';
  // Budget phones lose value more slowly in rupees than flagships.
  final budget = m.launchPrice < 50000;
  final ageFactor =
      (budget ? 0.95 : 0.92) *
      math.pow(budget ? 0.88 : 0.86, age) *
      (apple ? 1.08 : 1.0);
  final gradeFactor = _gradeFactor[gradeOf(p)]!;
  final batteryFactor = 1 + ((batteryOf(p) - 88) * 0.004).clamp(-0.08, 0.05);
  // Launch prices are for 128GB (Apple) / 256GB (Android) variants.
  final base = apple ? 128 : 256;
  final st = storageOf(p);
  final steps = st == 0 ? 0 : (math.log(st / base) / math.ln2).round();
  final storageFactor = 1 + steps * 0.08;
  var market0 =
      m.launchPrice * ageFactor * gradeFactor * batteryFactor * storageFactor;

  // Blend with comparable listings (same model, same grade, not this one).
  final comps = [
    for (final o in market)
      if (o.id != p.id &&
          modelInfo(o) == m &&
          gradeOf(o) == gradeOf(p) &&
          storageOf(o) == storageOf(p))
        o.price,
  ]..sort();
  if (comps.length >= 3) {
    final median = comps[comps.length ~/ 2];
    market0 = market0 * 0.6 + median * 0.4;
  }
  return FairPrice(
    price: p.price,
    market: FairPrice._r(market0),
    launch: m.launchPrice,
    ageFactor: ageFactor,
    gradeFactor: gradeFactor,
    batteryFactor: batteryFactor,
    storageFactor: storageFactor,
    comparables: comps.length,
  );
}
