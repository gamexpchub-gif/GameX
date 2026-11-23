import '../../../data/models/product.dart';
import 'phone_intel.dart';

/// What a buyer cares about most (Phone Finder & smart search).
enum Priority {
  gaming('Gaming', 'Smooth BGMI / COD at high FPS'),
  camera('Camera', 'Sharp photos, night shots & video'),
  battery('Battery', 'Lasts all day, fast charging'),
  allRounder('All-rounder', 'A bit of everything, no compromise');

  const Priority(this.label, this.hint);
  final String label;
  final String hint;

  int scoreOf(ModelInfo m) => switch (this) {
    gaming => m.gaming,
    camera => m.camera,
    battery => m.battery,
    allRounder => m.allRounder,
  };
}

enum DiscoverSort {
  relevance('Relevance'),
  bestDeal('Best deal first'),
  priceLow('Price: Low to High'),
  priceHigh('Price: High to Low'),
  battery('Battery health'),
  newest('Newest model'),
  rating('Seller rating');

  const DiscoverSort(this.label);
  final String label;
}

const kMinPrice = 5000.0;
const kMaxPrice = 160000.0;
const kRamOptions = [4, 6, 8, 12, 16];
const kStorageOptions = [64, 128, 256, 512];
const kBrands = [
  'Apple',
  'Samsung',
  'Google',
  'OnePlus',
  'vivo',
  'Xiaomi',
  'Realme',
  'Nothing',
  'Motorola',
];

/// All Smart Filter settings. Immutable; use [copyWith].
class PhoneFilter {
  const PhoneFilter({
    this.text = '',
    this.minPrice = kMinPrice,
    this.maxPrice = kMaxPrice,
    this.brands = const {},
    this.grades = const {},
    this.minBattery = 0,
    this.ram = const {},
    this.storage = const {},
    this.only5G = false,
    this.warranty = false,
    this.minRating = 0,
    this.city,
    this.inStock = true,
    this.priority,
    this.sort = DiscoverSort.relevance,
  });

  final String text;
  final double minPrice;
  final double maxPrice;
  final Set<String> brands;
  final Set<String> grades;
  final int minBattery;
  final Set<int> ram;
  final Set<int> storage;
  final bool only5G;
  final bool warranty;
  final double minRating;
  final String? city;
  final bool inStock;
  final Priority? priority;
  final DiscoverSort sort;

  bool get hasBudget => minPrice > kMinPrice || maxPrice < kMaxPrice;

  /// Number of active filters (excluding text & sort) for the badge.
  int get count =>
      (hasBudget ? 1 : 0) +
      (brands.isEmpty ? 0 : 1) +
      (grades.isEmpty ? 0 : 1) +
      (minBattery > 0 ? 1 : 0) +
      (ram.isEmpty ? 0 : 1) +
      (storage.isEmpty ? 0 : 1) +
      (only5G ? 1 : 0) +
      (warranty ? 1 : 0) +
      (minRating > 0 ? 1 : 0) +
      (city != null ? 1 : 0) +
      (priority != null ? 1 : 0);

  PhoneFilter copyWith({
    String? text,
    double? minPrice,
    double? maxPrice,
    Set<String>? brands,
    Set<String>? grades,
    int? minBattery,
    Set<int>? ram,
    Set<int>? storage,
    bool? only5G,
    bool? warranty,
    double? minRating,
    String? Function()? city,
    bool? inStock,
    Priority? Function()? priority,
    DiscoverSort? sort,
  }) => PhoneFilter(
    text: text ?? this.text,
    minPrice: minPrice ?? this.minPrice,
    maxPrice: maxPrice ?? this.maxPrice,
    brands: brands ?? this.brands,
    grades: grades ?? this.grades,
    minBattery: minBattery ?? this.minBattery,
    ram: ram ?? this.ram,
    storage: storage ?? this.storage,
    only5G: only5G ?? this.only5G,
    warranty: warranty ?? this.warranty,
    minRating: minRating ?? this.minRating,
    city: city == null ? this.city : city(),
    inStock: inStock ?? this.inStock,
    priority: priority == null ? this.priority : priority(),
    sort: sort ?? this.sort,
  );

  /// Clears every filter but keeps the search text.
  PhoneFilter cleared() => PhoneFilter(text: text);

  bool matches(Product p) {
    if (inStock && !p.inStock) return false;
    if (p.price < minPrice || p.price > maxPrice) return false;
    if (brands.isNotEmpty &&
        !brands.any((b) => b.toLowerCase() == p.brand.toLowerCase())) {
      return false;
    }
    if (grades.isNotEmpty && !grades.contains(gradeOf(p))) return false;
    if (minBattery > 0 && batteryOf(p) < minBattery) return false;
    if (ram.isNotEmpty) {
      final r = ramOf(p);
      if (!ram.any((x) => x == 16 ? r >= 16 : r == x)) return false;
    }
    if (storage.isNotEmpty) {
      final s = storageOf(p);
      if (!storage.any((x) => x == 512 ? s >= 512 : s == x)) return false;
    }
    if (only5G && !modelInfo(p).is5G) return false;
    if (warranty && p.warrantyMonths <= 0) return false;
    if (minRating > 0 && p.rating < minRating) return false;
    if (city != null && shipsFrom(p) != city) return false;
    if (text.trim().isNotEmpty) {
      final hay = '${p.name} ${p.brand} ${p.variant ?? ''} ${p.ram ?? ''}'
          .toLowerCase();
      for (final w in text.toLowerCase().split(RegExp(r'\s+'))) {
        if (w.isNotEmpty && !hay.contains(w)) return false;
      }
    }
    return true;
  }

  /// Filters and sorts [pool]. [market] informs the fair-price estimate.
  List<Product> apply(List<Product> pool) {
    final list = pool.where(matches).toList();
    final deal = <String, double>{};
    double dealOf(Product p) =>
        deal[p.id] ??= fairPriceOf(p, market: pool).delta;
    double relevance(Product p) {
      final m = modelInfo(p);
      var s = -dealOf(p) * 10 + p.rating;
      if (priority != null) s += priority!.scoreOf(m) * 1.5;
      return s;
    }

    switch (sort) {
      case DiscoverSort.relevance:
        list.sort((a, b) => relevance(b).compareTo(relevance(a)));
      case DiscoverSort.bestDeal:
        list.sort((a, b) => dealOf(a).compareTo(dealOf(b)));
      case DiscoverSort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case DiscoverSort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case DiscoverSort.battery:
        list.sort((a, b) => batteryOf(b).compareTo(batteryOf(a)));
      case DiscoverSort.newest:
        list.sort((a, b) => modelInfo(b).year.compareTo(modelInfo(a).year));
      case DiscoverSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }
}

// ───────────────────────────── Smart search ─────────────────────────────

const _brandAliases = {
  'iphone': 'Apple',
  'apple': 'Apple',
  'samsung': 'Samsung',
  'galaxy': 'Samsung',
  'google': 'Google',
  'pixel': 'Google',
  'oneplus': 'OnePlus',
  'one plus': 'OnePlus',
  'vivo': 'vivo',
  'xiaomi': 'Xiaomi',
  'redmi': 'Xiaomi',
  'mi': 'Xiaomi',
  'realme': 'Realme',
  'nothing': 'Nothing',
  'motorola': 'Motorola',
  'moto': 'Motorola',
};

double? _money(String n, String? k, {bool loose = true}) {
  final v = double.tryParse(n.replaceAll(',', ''));
  if (v == null) return null;
  final unit = (k ?? '').toLowerCase();
  if (!loose && unit.isEmpty && v < 1000) return null;
  if (unit == 'k' || unit.startsWith('hazar') || unit.startsWith('thousand')) {
    return v * 1000;
  }
  if (unit == 'l' || unit.startsWith('lakh') || unit.startsWith('lac')) {
    return v * 100000;
  }
  return v < 1000 ? v * 1000 : v;
}

/// Turns natural language ("5G samsung under 30k with good camera",
/// "iphone 40 hazar er niche", "8gb ram battery valo") into a filter.
/// Words that only express intent are removed from the free text.
PhoneFilter parseSmartQuery(
  String input, [
  PhoneFilter base = const PhoneFilter(),
]) {
  var q =
      ' ${input.toLowerCase().replaceAll('₹', ' ').replaceAll('rs.', ' ').replaceAll('rs ', ' ')} ';
  var f = base.cleared();

  // Budget: "under 30k", "below 40000", "30k er niche", "upto 25 hazar",
  // "20k-30k", "between 20000 and 30000", "above 50k".
  final num = r'(\d[\d,]*(?:\.\d+)?)\s*(k|l|lakh|lac|hazar|thousand)?';
  final range = RegExp('(?:between\\s+)?$num\\s*(?:-|to|and|theke)\\s*$num');
  final under = RegExp(
    '(?:under|below|upto|up to|within|less than|max|budget|<)\\s*$num|$num\\s*(?:er|r)?\\s*(?:niche|nicher|moddhe|modhye|or less|max)',
  );
  final over = RegExp(
    '(?:above|over|more than|min|>)\\s*$num|$num\\s*(?:er|r)?\\s*(?:upore|beshi|plus|\\+)',
  );
  final mr = range.firstMatch(q);
  if (mr != null) {
    final a = _money(mr.group(1)!, mr.group(2) ?? mr.group(4), loose: false);
    final b = _money(mr.group(3)!, mr.group(4), loose: false);
    if (a != null && b != null && b > a && a >= 1000) {
      f = f.copyWith(minPrice: a, maxPrice: b);
      q = q.replaceFirst(range, ' ');
    }
  }
  final mu = under.firstMatch(q);
  if (mu != null) {
    final v = _money(mu.group(1) ?? mu.group(3)!, mu.group(2) ?? mu.group(4));
    if (v != null) f = f.copyWith(maxPrice: v.clamp(kMinPrice, kMaxPrice));
    q = q.replaceFirst(under, ' ');
  }
  final mo = over.firstMatch(q);
  if (mo != null) {
    final v = _money(mo.group(1) ?? mo.group(3)!, mo.group(2) ?? mo.group(4));
    if (v != null) f = f.copyWith(minPrice: v.clamp(kMinPrice, kMaxPrice));
    q = q.replaceFirst(over, ' ');
  }

  // RAM / storage.
  final ram = RegExp(r'(\d{1,2})\s*gb\s*ram|ram\s*(\d{1,2})\s*gb')
      .firstMatch(q);
  if (ram != null) {
    final v = int.parse(ram.group(1) ?? ram.group(2)!);
    f = f.copyWith(ram: {v >= 16 ? 16 : v});
    q = q.replaceFirst(ram.group(0)!, ' ');
  }
  final st = RegExp(r'(64|128|256|512)\s*gb|1\s*tb').firstMatch(q);
  if (st != null) {
    f = f.copyWith(storage: {int.tryParse(st.group(1) ?? '') ?? 512});
    q = q.replaceFirst(st.group(0)!, ' ');
  }

  // Flags.
  if (RegExp(r'\b5g\b').hasMatch(q)) {
    f = f.copyWith(only5G: true);
    q = q.replaceAll(RegExp(r'\b5g\b'), ' ');
  }
  if (RegExp(r'\bwarrant(y|ee)\b').hasMatch(q)) {
    f = f.copyWith(warranty: true);
    q = q.replaceAll(RegExp(r'\b(with\s+)?warrant(y|ee)\b'), ' ');
  }
  if (RegExp(r'like\s*new|brand\s*new|fresh').hasMatch(q)) {
    f = f.copyWith(grades: {'Like New'});
    q = q.replaceAll(RegExp(r'like\s*new|brand\s*new|fresh'), ' ');
  }
  final batt = RegExp(r'battery\s*(?:health)?\s*(\d{2})\s*%?\+?').firstMatch(q);
  if (batt != null) {
    f = f.copyWith(minBattery: int.parse(batt.group(1)!));
    q = q.replaceFirst(batt.group(0)!, ' ');
  }

  // Priority words.
  const prio = {
    Priority.gaming: r'\b(gaming|game|games|bgmi|pubg|cod|free ?fire)\b',
    Priority.camera: r'\b(camera|photo|photos|selfie|video|vlog)\b',
    Priority.battery: r'\b(battery|backup|charge|charging)\b',
  };
  for (final e in prio.entries) {
    final r = RegExp(e.value);
    if (r.hasMatch(q)) {
      f = f.copyWith(priority: () => e.key);
      q = q.replaceAll(r, ' ');
      break;
    }
  }

  // City.
  for (final c in kCities) {
    final r = RegExp('\\b(in|near|from)?\\s*${c.toLowerCase()}\\b');
    if (r.hasMatch(q)) {
      f = f.copyWith(city: () => c);
      q = q.replaceAll(r, ' ');
    }
  }
  if (RegExp(r'bangalore').hasMatch(q)) {
    f = f.copyWith(city: () => 'Bengaluru');
    q = q.replaceAll('bangalore', ' ');
  }

  // Brands: "iphone" stays in the text too when followed by a model number.
  final brands = <String>{};
  for (final e in _brandAliases.entries) {
    final r = RegExp('\\b${e.key}\\b');
    if (r.hasMatch(q)) {
      brands.add(e.value);
      final keepModel = RegExp('\\b${e.key}\\s+\\d').hasMatch(q);
      if (!keepModel) q = q.replaceAll(r, ' ');
    }
  }
  if (brands.isNotEmpty) f = f.copyWith(brands: brands);

  // Filler words (English + Banglish).
  q = q.replaceAll(
    RegExp(
      r'\b(phone|phones|mobile|mobiles|smartphone|best|good|valo|bhalo|bhalo|er|r|jonno|with|and|for|a|an|the|i|want|need|chai|dorkar|ekta|show|me|please|plz|price|dam|kom|cheap|sasta|second ?hand|used|refurbished|rupees|rupee|taka|tk|ache|ase|koto)\b',
    ),
    ' ',
  );
  q = q
      .replaceAll(RegExp(r'[^a-z0-9() ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return f.copyWith(
    text: q.trim(),
    sort: f.priority != null ? DiscoverSort.relevance : base.sort,
  );
}

/// Short human labels for the active filters ("Under ₹30K", "5G", ...).
List<String> filterLabels(PhoneFilter f) {
  String k(double v) => v >= 100000
      ? '₹${(v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1)}L'
      : '₹${(v / 1000).round()}K';
  return [
    if (f.hasBudget)
      f.minPrice <= kMinPrice
          ? 'Under ${k(f.maxPrice)}'
          : f.maxPrice >= kMaxPrice
          ? 'Above ${k(f.minPrice)}'
          : '${k(f.minPrice)} – ${k(f.maxPrice)}',
    ...f.brands,
    ...f.grades,
    if (f.minBattery > 0) 'Battery ${f.minBattery}%+',
    for (final r in f.ram) r == 16 ? '16GB+ RAM' : '${r}GB RAM',
    for (final s in f.storage) s == 512 ? '512GB+' : '${s}GB',
    if (f.only5G) '5G',
    if (f.warranty) 'With warranty',
    if (f.minRating > 0) 'Seller ${f.minRating}★+',
    if (f.city != null) 'Ships from ${f.city}',
    if (f.priority != null) 'Best for ${f.priority!.label.toLowerCase()}',
  ];
}
