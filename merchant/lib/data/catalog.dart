// Product catalogue used when a seller creates a listing:
// category → brand → model, specification templates and the inspection
// checklist for each category. Pure data + search, no UI.

import 'package:material_ui/material_ui.dart';

class ProductCategory {
  const ProductCategory(
    this.name,
    this.plural,
    this.icon,
    this.brands, {
    this.hasImei = false,
  });

  /// Stored on the listing as `deviceType` ("Mobile Phone").
  final String name;

  /// Shown in breadcrumbs ("Mobiles").
  final String plural;
  final IconData icon;

  /// Brand → models (newest first).
  final Map<String, List<String>> brands;

  /// Phones have an IMEI; watches / earbuds / Wi-Fi tablets use a serial.
  final bool hasImei;
}

/// One search hit: "Mobiles › Apple › iPhone 15 Pro".
class CatalogHit {
  const CatalogHit(this.category, this.brand, [this.model]);
  final ProductCategory category;
  final String brand;
  final String? model;

  String get path => [
    category.plural,
    brand,
    ?model,
  ].join('  ›  ');
}

const _apple = [
  'iPhone 16 Pro Max', 'iPhone 16 Pro', 'iPhone 16 Plus', 'iPhone 16', 'iPhone 16e',
  'iPhone 15 Pro Max', 'iPhone 15 Pro', 'iPhone 15 Plus', 'iPhone 15',
  'iPhone 14 Pro Max', 'iPhone 14 Pro', 'iPhone 14 Plus', 'iPhone 14',
  'iPhone 13 Pro Max', 'iPhone 13 Pro', 'iPhone 13', 'iPhone 13 mini',
  'iPhone 12 Pro Max', 'iPhone 12 Pro', 'iPhone 12', 'iPhone 12 mini',
  'iPhone SE (3rd gen)', 'iPhone SE (2nd gen)',
  'iPhone 11 Pro Max', 'iPhone 11 Pro', 'iPhone 11',
  'iPhone XS Max', 'iPhone XS', 'iPhone XR', 'iPhone X',
  'iPhone 8 Plus', 'iPhone 8', 'iPhone 7 Plus', 'iPhone 7',
];

const _samsung = [
  'Galaxy S25 Ultra', 'Galaxy S25+', 'Galaxy S25', 'Galaxy S25 Edge', 'Galaxy S24 FE',
  'Galaxy S24 Ultra', 'Galaxy S24+', 'Galaxy S24', 'Galaxy S23 FE',
  'Galaxy S23 Ultra', 'Galaxy S23+', 'Galaxy S23', 'Galaxy S22 Ultra', 'Galaxy S22+',
  'Galaxy S22', 'Galaxy S21 FE', 'Galaxy S21 Ultra', 'Galaxy S21+', 'Galaxy S21',
  'Galaxy S20 FE', 'Galaxy S20 Ultra', 'Galaxy S20',
  'Galaxy Z Fold 6', 'Galaxy Z Flip 6', 'Galaxy Z Fold 5', 'Galaxy Z Flip 5',
  'Galaxy Z Fold 4', 'Galaxy Z Flip 4', 'Galaxy Z Fold 3', 'Galaxy Z Flip 3',
  'Galaxy Note 20 Ultra', 'Galaxy Note 20', 'Galaxy Note 10+',
  'Galaxy A56', 'Galaxy A55', 'Galaxy A36', 'Galaxy A35', 'Galaxy A26', 'Galaxy A25',
  'Galaxy A16', 'Galaxy A15', 'Galaxy A06', 'Galaxy A05s', 'Galaxy A54', 'Galaxy A34',
  'Galaxy A14', 'Galaxy A73', 'Galaxy A53', 'Galaxy A33', 'Galaxy A23', 'Galaxy A52s',
  'Galaxy A52', 'Galaxy A32', 'Galaxy A22', 'Galaxy A12',
  'Galaxy M55', 'Galaxy M35', 'Galaxy M15', 'Galaxy M34', 'Galaxy M14', 'Galaxy M54',
  'Galaxy M33', 'Galaxy M13', 'Galaxy M53', 'Galaxy M52', 'Galaxy M32', 'Galaxy M31',
  'Galaxy F55', 'Galaxy F54', 'Galaxy F34', 'Galaxy F15', 'Galaxy F14', 'Galaxy F23',
];

const _xiaomi = [
  'Xiaomi 15 Ultra', 'Xiaomi 15', 'Xiaomi 14 Ultra', 'Xiaomi 14', 'Xiaomi 14 CIVI',
  'Xiaomi 13 Pro', 'Xiaomi 12 Pro', 'Xiaomi 11T Pro', 'Xiaomi 11 Lite NE',
  'Mi 11X Pro', 'Mi 11X', 'Mi 10T Pro', 'Mi 10',
];

const _redmi = [
  'Redmi Note 14 Pro+', 'Redmi Note 14 Pro', 'Redmi Note 14', 'Redmi Note 13 Pro+',
  'Redmi Note 13 Pro', 'Redmi Note 13', 'Redmi Note 12 Pro+', 'Redmi Note 12 Pro',
  'Redmi Note 12', 'Redmi Note 11 Pro+', 'Redmi Note 11', 'Redmi Note 10 Pro Max',
  'Redmi Note 10 Pro', 'Redmi Note 10', 'Redmi 14C', 'Redmi 13C', 'Redmi 13',
  'Redmi 12', 'Redmi 12C', 'Redmi A4', 'Redmi A3', 'Redmi 10', 'Redmi 9A',
];

const _poco = [
  'POCO F7', 'POCO F6', 'POCO F5', 'POCO F4', 'POCO F1', 'POCO X7 Pro', 'POCO X7',
  'POCO X6 Pro', 'POCO X6', 'POCO X5 Pro', 'POCO X4 Pro', 'POCO X3 Pro', 'POCO M7 Pro',
  'POCO M6 Pro', 'POCO M6', 'POCO M5', 'POCO M4 Pro', 'POCO C75', 'POCO C65',
];

const _oneplus = [
  'OnePlus 13', 'OnePlus 13R', 'OnePlus 12', 'OnePlus 12R', 'OnePlus 11', 'OnePlus 11R',
  'OnePlus 10 Pro', 'OnePlus 10R', 'OnePlus 10T', 'OnePlus 9 Pro', 'OnePlus 9',
  'OnePlus 9R', 'OnePlus 8T', 'OnePlus 8 Pro', 'OnePlus 8', 'OnePlus 7T', 'OnePlus Open',
  'OnePlus Nord 4', 'OnePlus Nord 3', 'OnePlus Nord 2T', 'OnePlus Nord 2',
  'OnePlus Nord CE 4', 'OnePlus Nord CE 4 Lite', 'OnePlus Nord CE 3', 'OnePlus Nord CE 3 Lite',
  'OnePlus Nord CE 2', 'OnePlus Nord CE',
];

const _vivo = [
  'vivo X200 Pro', 'vivo X200', 'vivo X100 Pro', 'vivo X100', 'vivo X90 Pro', 'vivo X80 Pro',
  'vivo X Fold 3 Pro', 'vivo V50', 'vivo V40 Pro', 'vivo V40', 'vivo V30 Pro', 'vivo V30',
  'vivo V29 Pro', 'vivo V29', 'vivo V27 Pro', 'vivo V27', 'vivo V25 Pro', 'vivo V23 Pro',
  'vivo T4', 'vivo T3 Ultra', 'vivo T3 Pro', 'vivo T3', 'vivo T2 Pro', 'vivo T2',
  'vivo Y400', 'vivo Y300', 'vivo Y200', 'vivo Y100', 'vivo Y58', 'vivo Y56', 'vivo Y28',
  'vivo Y27', 'vivo Y22', 'vivo Y21', 'vivo Y18', 'vivo Y16',
];

const _iqoo = [
  'iQOO 13', 'iQOO 12', 'iQOO 11', 'iQOO 9 Pro', 'iQOO 9', 'iQOO Neo 10R', 'iQOO Neo 9 Pro',
  'iQOO Neo 7 Pro', 'iQOO Neo 7', 'iQOO Z10', 'iQOO Z9s Pro', 'iQOO Z9', 'iQOO Z9x',
  'iQOO Z7 Pro', 'iQOO Z7', 'iQOO Z6 Pro',
];

const _oppo = [
  'OPPO Find X8 Pro', 'OPPO Find X8', 'OPPO Find N3 Flip', 'OPPO Reno 13 Pro', 'OPPO Reno 13',
  'OPPO Reno 12 Pro', 'OPPO Reno 12', 'OPPO Reno 11 Pro', 'OPPO Reno 11', 'OPPO Reno 10 Pro+',
  'OPPO Reno 10 Pro', 'OPPO Reno 10', 'OPPO Reno 8 Pro', 'OPPO Reno 8', 'OPPO F29 Pro',
  'OPPO F27 Pro+', 'OPPO F25 Pro', 'OPPO F23', 'OPPO K12x', 'OPPO A5 Pro', 'OPPO A3 Pro',
  'OPPO A79', 'OPPO A78', 'OPPO A59', 'OPPO A58', 'OPPO A38', 'OPPO A18', 'OPPO A17',
];

const _realme = [
  'realme GT 7 Pro', 'realme GT 6', 'realme GT 6T', 'realme GT 2 Pro', 'realme GT Neo 3',
  'realme 14 Pro+', 'realme 14 Pro', 'realme 14x', 'realme 13 Pro+', 'realme 13 Pro',
  'realme 13', 'realme 12 Pro+', 'realme 12 Pro', 'realme 12', 'realme 11 Pro+',
  'realme 11 Pro', 'realme 11', 'realme 10 Pro+', 'realme 10 Pro', 'realme 9 Pro+',
  'realme Narzo 70 Turbo', 'realme Narzo 70 Pro', 'realme Narzo 60 Pro', 'realme Narzo 60',
  'realme P3 Pro', 'realme P3', 'realme P2 Pro', 'realme P1 Pro', 'realme P1',
  'realme C75', 'realme C65', 'realme C63', 'realme C55', 'realme C53', 'realme C35',
];

const _motorola = [
  'Motorola Edge 60 Pro', 'Motorola Edge 60 Fusion', 'Motorola Edge 50 Ultra',
  'Motorola Edge 50 Pro', 'Motorola Edge 50 Fusion', 'Motorola Edge 50 Neo',
  'Motorola Edge 50', 'Motorola Edge 40 Neo', 'Motorola Edge 40', 'Motorola Edge 30 Ultra',
  'Motorola Edge 30 Pro', 'Motorola Razr 50 Ultra', 'Motorola Razr 50', 'Motorola Razr 40 Ultra',
  'Moto G85', 'Moto G84', 'Moto G64', 'Moto G54', 'Moto G45', 'Moto G35', 'Moto G34',
  'Moto G24 Power', 'Moto G62', 'Moto G52', 'Moto E14', 'Moto E13',
];

const _google = [
  'Pixel 9 Pro XL', 'Pixel 9 Pro', 'Pixel 9 Pro Fold', 'Pixel 9', 'Pixel 9a', 'Pixel 8 Pro',
  'Pixel 8', 'Pixel 8a', 'Pixel 7 Pro', 'Pixel 7', 'Pixel 7a', 'Pixel 6 Pro', 'Pixel 6',
  'Pixel 6a', 'Pixel 5', 'Pixel 4a', 'Pixel 4 XL', 'Pixel 3 XL',
];

const _nothing = [
  'Nothing Phone (3)', 'Nothing Phone (3a) Pro', 'Nothing Phone (3a)', 'Nothing Phone (2a) Plus',
  'Nothing Phone (2a)', 'Nothing Phone (2)', 'Nothing Phone (1)',
];

/// All phone brands sold in India (main ones first).
const _phones = <String, List<String>>{
  'Apple': _apple,
  'Samsung': _samsung,
  'OnePlus': _oneplus,
  'Xiaomi': _xiaomi,
  'Redmi': _redmi,
  'POCO': _poco,
  'vivo': _vivo,
  'iQOO': _iqoo,
  'OPPO': _oppo,
  'Realme': _realme,
  'Google': _google,
  'Nothing': _nothing,
  'CMF by Nothing': ['CMF Phone 2 Pro', 'CMF Phone 1'],
  'Motorola': _motorola,
  'Nokia': ['Nokia G42', 'Nokia G21', 'Nokia X30', 'Nokia C32', 'Nokia C12', 'Nokia 105', 'Nokia 110 4G', 'Nokia 8.3', 'Nokia 7.2'],
  'HMD': ['HMD Fusion', 'HMD Crest Max', 'HMD Crest', 'HMD Skyline'],
  'Infinix': ['Infinix GT 20 Pro', 'Infinix GT 10 Pro', 'Infinix Zero 40', 'Infinix Zero 30', 'Infinix Note 40 Pro', 'Infinix Note 40', 'Infinix Note 30', 'Infinix Hot 50', 'Infinix Hot 40i', 'Infinix Hot 30', 'Infinix Smart 9', 'Infinix Smart 8'],
  'Tecno': ['Tecno Phantom V Fold 2', 'Tecno Phantom V Flip 2', 'Tecno Camon 30 Premier', 'Tecno Camon 30', 'Tecno Camon 20 Pro', 'Tecno Pova 6 Pro', 'Tecno Pova 6', 'Tecno Pova 5', 'Tecno Spark 30C', 'Tecno Spark 20', 'Tecno Spark Go'],
  'itel': ['itel S25 Ultra', 'itel P55', 'itel A70', 'itel A50', 'itel Color Pro', 'itel Zeno 10'],
  'Lava': ['Lava Agni 3', 'Lava Agni 2', 'Lava Blaze X', 'Lava Blaze Curve', 'Lava Blaze 2', 'Lava Storm', 'Lava Yuva 3', 'Lava O2'],
  'Honor': ['Honor Magic 6 Pro', 'Honor 200 Pro', 'Honor 200', 'Honor 90', 'Honor X9c', 'Honor X9b'],
  'Huawei': ['Huawei P30 Pro', 'Huawei P30', 'Huawei Nova 7i', 'Huawei Y9 Prime'],
  'Asus': ['ROG Phone 9', 'ROG Phone 8 Pro', 'ROG Phone 8', 'ROG Phone 7', 'ROG Phone 6', 'ROG Phone 5', 'Zenfone 11 Ultra', 'Zenfone 10', 'Zenfone 9', 'Zenfone Max Pro M2'],
  'Sony': ['Xperia 1 VI', 'Xperia 1 V', 'Xperia 5 V', 'Xperia 10 VI', 'Xperia 1 IV', 'Xperia XZ2'],
  'Micromax': ['Micromax IN Note 2', 'Micromax IN Note 1', 'Micromax IN 2b', 'Micromax IN 1b'],
  'Ai+': ['Ai+ Pulse', 'Ai+ Nova 5G'],
  'Acer': ['Acer Super ZX Pro', 'Acer Super ZX', 'Acer One 8'],
  'Lenovo': ['Lenovo Legion Duel 2', 'Lenovo K12 Note', 'Lenovo K10 Note'],
  'LG': ['LG Wing', 'LG Velvet', 'LG G8X ThinQ', 'LG V60 ThinQ'],
  'Nubia': ['Red Magic 10 Pro', 'Red Magic 9 Pro', 'Red Magic 8 Pro', 'Nubia Z60 Ultra'],
  'Black Shark': ['Black Shark 5 Pro', 'Black Shark 4', 'Black Shark 3'],
  'Jio': ['JioPhone Next', 'JioPhone Prima 2', 'JioBharat V3', 'JioBharat K1'],
  'Meizu': ['Meizu 21 Pro', 'Meizu 20 Pro'],
  'ZTE': ['ZTE Axon 40 Ultra', 'ZTE Blade A73'],
  'Alcatel': ['Alcatel V3 Ultra', 'Alcatel V3 Pro', 'Alcatel V3 Classic'],
  'Gionee': ['Gionee Max Pro', 'Gionee F8 Neo'],
  'Coolpad': ['Coolpad Cool 20', 'Coolpad Cool 6'],
  'Karbonn': ['Karbonn Titanium Jumbo 2', 'Karbonn K9 Smart'],
  'Intex': ['Intex Aqua Lions', 'Intex Indie 5'],
  'Panasonic': ['Panasonic Eluga Ray 810', 'Panasonic P100'],
  'HTC': ['HTC U23 Pro', 'HTC Desire 22 Pro', 'HTC U12+'],
  'BlackBerry': ['BlackBerry KEY2', 'BlackBerry KEYone', 'BlackBerry Evolve'],
  'Fairphone': ['Fairphone 5', 'Fairphone 4'],
  'Philips': ['Philips E209', 'Philips Xenium E185'],
};

const _tablets = <String, List<String>>{
  'Apple': [
    'iPad Pro 13" (M4)', 'iPad Pro 11" (M4)', 'iPad Pro 12.9" (6th gen)', 'iPad Pro 11" (4th gen)',
    'iPad Pro 12.9" (5th gen)', 'iPad Pro 11" (3rd gen)', 'iPad Air 13" (M3)', 'iPad Air 11" (M3)',
    'iPad Air 13" (M2)', 'iPad Air 11" (M2)', 'iPad Air (5th gen)', 'iPad Air (4th gen)',
    'iPad (A16)', 'iPad (10th gen)', 'iPad (9th gen)', 'iPad (8th gen)', 'iPad mini (A17 Pro)',
    'iPad mini (6th gen)', 'iPad mini (5th gen)',
  ],
  'Samsung': [
    'Galaxy Tab S10 Ultra', 'Galaxy Tab S10+', 'Galaxy Tab S10 FE', 'Galaxy Tab S9 Ultra',
    'Galaxy Tab S9+', 'Galaxy Tab S9', 'Galaxy Tab S9 FE+', 'Galaxy Tab S9 FE', 'Galaxy Tab S8 Ultra',
    'Galaxy Tab S8', 'Galaxy Tab S7 FE', 'Galaxy Tab S6 Lite', 'Galaxy Tab A9+', 'Galaxy Tab A9',
    'Galaxy Tab A8', 'Galaxy Tab A7 Lite',
  ],
  'Xiaomi': ['Xiaomi Pad 7', 'Xiaomi Pad 6', 'Xiaomi Pad 5'],
  'Redmi': ['Redmi Pad Pro', 'Redmi Pad SE', 'Redmi Pad'],
  'OnePlus': ['OnePlus Pad 2', 'OnePlus Pad', 'OnePlus Pad Go'],
  'Lenovo': ['Lenovo Tab P12', 'Lenovo Tab P11 Pro', 'Lenovo Tab P11', 'Lenovo Tab M11', 'Lenovo Tab M10', 'Lenovo Legion Tab'],
  'Realme': ['realme Pad 2', 'realme Pad', 'realme Pad mini'],
  'Honor': ['Honor Pad 9', 'Honor Pad X9', 'Honor Pad X8'],
  'Motorola': ['Moto Tab G70', 'Moto Tab G62', 'Moto Pad 60 Pro'],
  'OPPO': ['OPPO Pad 2', 'OPPO Pad Air'],
  'vivo': ['vivo Pad 3 Pro'],
  'POCO': ['POCO Pad'],
  'Nokia': ['Nokia T21', 'Nokia T20'],
  'Huawei': ['Huawei MatePad 11', 'Huawei MatePad T10'],
  'Microsoft': ['Surface Pro 11', 'Surface Pro 9', 'Surface Go 4', 'Surface Go 3'],
};

const _watches = <String, List<String>>{
  'Apple': [
    'Apple Watch Ultra 2', 'Apple Watch Ultra', 'Apple Watch Series 10', 'Apple Watch Series 9',
    'Apple Watch Series 8', 'Apple Watch Series 7', 'Apple Watch Series 6', 'Apple Watch SE (2nd gen)',
    'Apple Watch SE', 'Apple Watch Series 5',
  ],
  'Samsung': [
    'Galaxy Watch Ultra', 'Galaxy Watch 7', 'Galaxy Watch FE', 'Galaxy Watch 6 Classic',
    'Galaxy Watch 6', 'Galaxy Watch 5 Pro', 'Galaxy Watch 5', 'Galaxy Watch 4 Classic', 'Galaxy Watch 4',
  ],
  'Google': ['Pixel Watch 3', 'Pixel Watch 2', 'Pixel Watch'],
  'OnePlus': ['OnePlus Watch 3', 'OnePlus Watch 2', 'OnePlus Watch'],
  'Garmin': ['Garmin Fenix 8', 'Garmin Fenix 7', 'Garmin Epix Pro', 'Garmin Forerunner 965', 'Garmin Forerunner 265', 'Garmin Venu 3', 'Garmin Instinct 2'],
  'Amazfit': ['Amazfit Balance', 'Amazfit GTR 4', 'Amazfit GTS 4', 'Amazfit T-Rex 3', 'Amazfit Active', 'Amazfit Bip 5'],
  'Fitbit': ['Fitbit Sense 2', 'Fitbit Versa 4', 'Fitbit Charge 6', 'Fitbit Inspire 3'],
  'Huawei': ['Huawei Watch GT 5', 'Huawei Watch GT 4', 'Huawei Watch Fit 3'],
  'Noise': ['NoiseFit Halo', 'ColorFit Pro 5', 'ColorFit Ultra 3', 'NoiseFit Endeavour'],
  'boAt': ['boAt Lunar Discovery', 'boAt Wave Sigma', 'boAt Storm Call 3', 'boAt Xtend'],
  'Fire-Boltt': ['Fire-Boltt Phoenix', 'Fire-Boltt Ninja Call Pro', 'Fire-Boltt Invincible Plus'],
  'Xiaomi': ['Xiaomi Watch S3', 'Redmi Watch 5 Active', 'Xiaomi Smart Band 9'],
  'Realme': ['realme Watch S2', 'realme Watch 3 Pro'],
  'Nothing': ['CMF Watch Pro 2', 'CMF Watch Pro'],
};

const _audio = <String, List<String>>{
  'Apple': ['AirPods Pro (2nd gen)', 'AirPods Pro', 'AirPods 4', 'AirPods (3rd gen)', 'AirPods (2nd gen)', 'AirPods Max', 'Beats Studio Buds+', 'Beats Fit Pro'],
  'Samsung': ['Galaxy Buds 3 Pro', 'Galaxy Buds 3', 'Galaxy Buds FE', 'Galaxy Buds 2 Pro', 'Galaxy Buds 2', 'Galaxy Buds Live'],
  'Sony': ['WH-1000XM5', 'WH-1000XM4', 'WF-1000XM5', 'WF-1000XM4', 'WF-C700N', 'LinkBuds S'],
  'OnePlus': ['OnePlus Buds Pro 3', 'OnePlus Buds Pro 2', 'OnePlus Buds 3', 'OnePlus Nord Buds 3 Pro', 'OnePlus Nord Buds 2'],
  'Nothing': ['Nothing Ear', 'Nothing Ear (a)', 'Nothing Ear (2)', 'CMF Buds Pro 2', 'CMF Buds'],
  'Google': ['Pixel Buds Pro 2', 'Pixel Buds Pro', 'Pixel Buds A-Series'],
  'JBL': ['JBL Tour Pro 3', 'JBL Live Pro 2', 'JBL Tune Beam', 'JBL Tune 770NC', 'JBL Wave Beam'],
  'boAt': ['boAt Airdopes 141', 'boAt Airdopes 311 Pro', 'boAt Nirvana Ion', 'boAt Rockerz 450'],
  'Bose': ['QuietComfort Ultra Earbuds', 'QuietComfort Ultra Headphones', 'QuietComfort 45', 'QuietComfort Earbuds II'],
  'Realme': ['realme Buds Air 6 Pro', 'realme Buds Air 6', 'realme Buds T310'],
  'Noise': ['Noise Buds VS104', 'Noise Air Buds Pro 3'],
  'Xiaomi': ['Redmi Buds 6 Pro', 'Redmi Buds 5', 'Xiaomi Buds 5 Pro'],
  'Sennheiser': ['Momentum 4', 'Momentum True Wireless 4', 'Accentum Plus'],
  'Marshall': ['Marshall Major V', 'Marshall Motif II ANC'],
};

const kCategories = [
  ProductCategory('Mobile Phone', 'Mobiles', Icons.smartphone_rounded, _phones, hasImei: true),
  ProductCategory('Tablet', 'Tablets', Icons.tablet_android_rounded, _tablets),
  ProductCategory('Smartwatch', 'Smartwatches', Icons.watch_rounded, _watches),
  ProductCategory('Earbuds & Audio', 'Earbuds & Audio', Icons.headphones_rounded, _audio),
];

ProductCategory categoryOf(String deviceType) => kCategories.firstWhere(
  (c) => c.name == deviceType,
  orElse: () => kCategories.first,
);

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+]'), '');

/// Searches categories, brands and models. "iphone 13" → Mobiles › Apple ›
/// iPhone 13 (and 13 Pro, 13 mini…); "samsung" → every Samsung category.
List<CatalogHit> searchCatalog(String query, {int limit = 30}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final words = q.split(RegExp(r'\s+')).map(_norm).where((w) => w.isNotEmpty);
  final scored = <(CatalogHit, int)>[];
  for (final c in kCategories) {
    for (final e in c.brands.entries) {
      // brand-only hit ("sams" → Samsung in every category)
      if (_norm(e.key).startsWith(_norm(q))) {
        scored.add((CatalogHit(c, e.key), c == kCategories.first ? 50 : 40));
      }
      for (final m in e.value) {
        final hay = _norm('${e.key} $m ${c.plural}');
        if (!words.every(hay.contains)) continue;
        final nm = _norm(m);
        var s = 10;
        if (nm.startsWith(_norm(q))) s += 30;
        if (nm == _norm(q)) s += 40;
        if (c == kCategories.first) s += 5;
        s -= (nm.length / 6).round(); // shorter (closer) names first
        scored.add((CatalogHit(c, e.key, m), s));
      }
    }
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (h, _) in scored.take(limit)) h];
}

/// Battery health is shown only for Apple devices (iPhone / iPad / Watch):
/// other brands don't report a reliable percentage.
bool showsBatteryHealth(String brand, String deviceType) =>
    brand == 'Apple' && deviceType != 'Earbuds & Audio';

// ─────────────────────────── Specifications ───────────────────────────

class SpecField {
  const SpecField(this.group, this.key, [this.suggestions = const []]);
  final String group;
  final String key;
  final List<String> suggestions;
}

const _phoneSpecs = [
  SpecField('Display', 'Screen size', ['6.1"', '6.4"', '6.5"', '6.67"', '6.7"', '6.8"']),
  SpecField('Display', 'Display type', ['AMOLED', 'Super AMOLED', 'OLED', 'Super Retina XDR', 'LCD', 'LTPO AMOLED']),
  SpecField('Display', 'Refresh rate', ['60Hz', '90Hz', '120Hz', '144Hz']),
  SpecField('Display', 'Resolution', ['HD+', 'Full HD+', 'QHD+', '2556 × 1179']),
  SpecField('Performance', 'Processor', ['Apple A18', 'Apple A17 Pro', 'Apple A16 Bionic', 'Apple A15 Bionic', 'Snapdragon 8 Gen 3', 'Snapdragon 8 Gen 2', 'Snapdragon 7 Gen 3', 'Dimensity 9300', 'Dimensity 7200', 'Exynos 2400', 'Tensor G4']),
  SpecField('Performance', 'Operating system', ['iOS 18', 'iOS 17', 'Android 15', 'Android 14', 'Android 13']),
  SpecField('Camera', 'Rear camera', ['48MP + 12MP', '50MP + 12MP + 10MP', '200MP + 12MP + 10MP', '50MP + 8MP', '64MP + 8MP + 2MP']),
  SpecField('Camera', 'Front camera', ['12MP', '16MP', '32MP', '50MP']),
  SpecField('Camera', 'Video recording', ['4K @ 60fps', '4K @ 30fps', '8K @ 30fps', '1080p @ 60fps']),
  SpecField('Battery', 'Battery capacity', ['3,300 mAh', '4,000 mAh', '4,500 mAh', '5,000 mAh', '5,500 mAh', '6,000 mAh']),
  SpecField('Battery', 'Fast charging', ['20W', '25W', '33W', '45W', '67W', '80W', '100W']),
  SpecField('Battery', 'Wireless charging', ['Yes (MagSafe)', 'Yes (15W)', 'No']),
  SpecField('Connectivity', 'Wi-Fi', ['Wi-Fi 7', 'Wi-Fi 6E', 'Wi-Fi 6', 'Wi-Fi 5']),
  SpecField('Connectivity', 'Bluetooth', ['5.4', '5.3', '5.2', '5.0']),
  SpecField('Connectivity', 'NFC', ['Yes', 'No']),
  SpecField('Connectivity', 'Charging port', ['USB-C', 'Lightning']),
  SpecField('Build', 'Water resistance', ['IP68', 'IP67', 'IP65', 'IP54', 'None']),
  SpecField('Build', 'Weight', ['170 g', '190 g', '200 g', '220 g']),
  SpecField('Security', 'Unlock', ['Face ID', 'In-display fingerprint', 'Side fingerprint', 'Face unlock']),
  SpecField('General', 'Launch year', ['2025', '2024', '2023', '2022', '2021', '2020']),
];

const _tabletSpecs = [
  SpecField('Display', 'Screen size', ['8.3"', '10.9"', '11"', '12.4"', '12.9"', '13"']),
  SpecField('Display', 'Display type', ['Liquid Retina', 'Ultra Retina XDR', 'AMOLED', 'LCD']),
  SpecField('Display', 'Refresh rate', ['60Hz', '90Hz', '120Hz', '144Hz']),
  SpecField('Performance', 'Processor', ['Apple M4', 'Apple M2', 'Apple M1', 'Apple A16', 'Snapdragon 8 Gen 2', 'Dimensity 9000']),
  SpecField('Performance', 'Operating system', ['iPadOS 18', 'iPadOS 17', 'Android 14', 'Android 13']),
  SpecField('Connectivity', 'Connectivity', ['Wi-Fi only', 'Wi-Fi + Cellular']),
  SpecField('Battery', 'Battery capacity', ['7,600 mAh', '8,000 mAh', '10,000 mAh', '11,200 mAh']),
  SpecField('Extras', 'Stylus support', ['Apple Pencil Pro', 'Apple Pencil (USB-C)', 'S Pen included', 'No']),
  SpecField('Extras', 'Keyboard support', ['Yes', 'No']),
  SpecField('Camera', 'Rear camera', ['12MP', '13MP', '8MP']),
  SpecField('General', 'Launch year', ['2025', '2024', '2023', '2022', '2021']),
];

const _watchSpecs = [
  SpecField('Design', 'Case size', ['40mm', '41mm', '42mm', '44mm', '45mm', '46mm', '49mm']),
  SpecField('Design', 'Case material', ['Aluminium', 'Stainless steel', 'Titanium', 'Plastic']),
  SpecField('Design', 'Strap', ['Sport band', 'Sport loop', 'Silicone', 'Metal', 'Leather']),
  SpecField('Display', 'Display type', ['Always-On Retina', 'AMOLED', 'LCD']),
  SpecField('Features', 'Connectivity', ['GPS', 'GPS + Cellular', 'Bluetooth calling']),
  SpecField('Features', 'Health sensors', ['Heart rate, SpO2, ECG', 'Heart rate, SpO2', 'Heart rate']),
  SpecField('Features', 'Water resistance', ['50m (5 ATM)', '100m', 'IP68', 'IP67']),
  SpecField('Battery', 'Battery life', ['18 hours', '36 hours', '2 days', '7 days', '14 days']),
  SpecField('General', 'Works with', ['iPhone', 'Android', 'iPhone & Android']),
];

const _audioSpecs = [
  SpecField('Sound', 'Type', ['In-ear (TWS)', 'Over-ear', 'On-ear', 'Neckband']),
  SpecField('Sound', 'Noise cancellation', ['Active (ANC)', 'Adaptive ANC', 'ENC for calls', 'None']),
  SpecField('Sound', 'Driver size', ['10mm', '11mm', '12.4mm', '40mm']),
  SpecField('Battery', 'Battery life', ['6h + 24h case', '8h + 30h case', '30 hours', '40 hours']),
  SpecField('Connectivity', 'Bluetooth', ['5.4', '5.3', '5.2', '5.0']),
  SpecField('Connectivity', 'Charging', ['USB-C', 'Lightning', 'Wireless + USB-C', 'MagSafe']),
  SpecField('Build', 'Water resistance', ['IPX4', 'IP54', 'IPX5', 'None']),
];

List<SpecField> specTemplate(String deviceType) => switch (deviceType) {
  'Tablet' => _tabletSpecs,
  'Smartwatch' => _watchSpecs,
  'Earbuds & Audio' => _audioSpecs,
  _ => _phoneSpecs,
};

// ─────────────────────────── Inspection ───────────────────────────

class CheckGroup {
  const CheckGroup(this.title, this.icon, this.items);
  final String title;
  final IconData icon;
  final List<String> items;
}

/// What the seller tests before listing. Ticked = working; the buyer sees
/// every item with a tick or "not working / not checked".
List<CheckGroup> inspectionFor(String deviceType, String brand) {
  final apple = brand == 'Apple';
  return switch (deviceType) {
    'Smartwatch' => const [
      CheckGroup('Display & body', Icons.watch_rounded, ['Display & touch', 'Digital crown / buttons', 'Case & glass (no cracks)', 'Strap included & clean']),
      CheckGroup('Functions', Icons.favorite_border_rounded, ['Heart-rate & sensors', 'Charging', 'Bluetooth pairing', 'Speaker & microphone', 'Vibration']),
      CheckGroup('Account', Icons.lock_open_rounded, ['Unpaired / account removed']),
    ],
    'Earbuds & Audio' => const [
      CheckGroup('Sound', Icons.headphones_rounded, ['Left earbud / speaker', 'Right earbud / speaker', 'Microphone', 'Noise cancellation']),
      CheckGroup('Battery & case', Icons.battery_charging_full_rounded, ['Charging case', 'Battery holds charge', 'Pairing works']),
      CheckGroup('Body', Icons.cleaning_services_rounded, ['Clean & hygienic', 'No physical damage']),
    ],
    _ => [
      const CheckGroup('Screen', Icons.phone_iphone_rounded, ['Display & touch', 'No dead pixels / lines', 'Original display (not replaced)']),
      CheckGroup('Security', Icons.fingerprint_rounded, [apple ? 'Face ID / Touch ID' : 'Face ID / Fingerprint']),
      const CheckGroup('Camera & audio', Icons.photo_camera_outlined, ['Front & rear cameras', 'Flash & torch', 'Speakers & microphone', 'Earpiece (calls)']),
      CheckGroup('Connectivity', Icons.wifi_rounded, [
        if (deviceType == 'Mobile Phone') 'Calling & network',
        'Wi-Fi, Bluetooth & SIM',
        'GPS / location',
      ]),
      const CheckGroup('Hardware', Icons.memory_rounded, ['Charging port', 'Battery & charging', 'Buttons & vibration', 'Sensors (proximity, auto-rotate)']),
      const CheckGroup('Body', Icons.crop_portrait_rounded, ['Frame not bent / cracked', 'Back glass / panel intact']),
      CheckGroup('Account', Icons.lock_open_rounded, [apple ? 'No iCloud lock (Find My off)' : 'No iCloud / Google lock']),
    ],
  };
}

List<String> inspectionItems(String deviceType, String brand) => [
  for (final g in inspectionFor(deviceType, brand)) ...g.items,
];

// ─────────────────────────── Colours ───────────────────────────

/// Common phone colour names → swatch (for variants and the buyer app).
const kColourNames = <String, int>{
  'Black': 0xFF151515,
  'White': 0xFFF2F2F2,
  'Blue': 0xFF2F7BEF,
  'Purple': 0xFF8B55E8,
  'Green': 0xFF3DAA5C,
  'Red': 0xFFE53935,
  'Gold': 0xFFE2C08D,
  'Silver': 0xFFD9DCE1,
  'Grey': 0xFF8E8E93,
  'Pink': 0xFFF4B6C2,
  'Yellow': 0xFFF7D154,
  'Orange': 0xFFF08A3C,
  'Midnight': 0xFF1C2230,
  'Starlight': 0xFFF1E9DC,
  'Natural Titanium': 0xFFBFB6A8,
  'Black Titanium': 0xFF3A3A3C,
  'Blue Titanium': 0xFF3F4A5A,
  'White Titanium': 0xFFE8E6E1,
  'Desert Titanium': 0xFFC7A98A,
  'Deep Purple': 0xFF5B4B6A,
  'Space Black': 0xFF2B2B2D,
  'Graphite': 0xFF4A4A4C,
  'Sierra Blue': 0xFF9BB5CE,
  'Alpine Green': 0xFF55624C,
  'Phantom Black': 0xFF222222,
  'Cream': 0xFFF3EBDD,
  'Lavender': 0xFFC8B6E2,
  'Mint': 0xFFBFE3D0,
  'Titanium Gray': 0xFF7D7D7D,
};

int? colourHex(String name) {
  for (final e in kColourNames.entries) {
    if (e.key.toLowerCase() == name.trim().toLowerCase()) return e.value;
  }
  return null;
}
