/// Trade-in price book and quote engine. Mirrors server/src/growth.js so a
/// quote can be shown offline; the server's quote is the binding one.
library;

const kTradeInModels = <String, Map<String, double>>{
  'Apple': {
    'iPhone 16 Pro': 62000,
    'iPhone 16': 45000,
    'iPhone 15 Pro Max': 58000,
    'iPhone 15 Pro': 48000,
    'iPhone 15': 33000,
    'iPhone 14 Pro Max': 42000,
    'iPhone 14 Pro': 36000,
    'iPhone 14': 25000,
    'iPhone 13 Pro': 25000,
    'iPhone 13': 19000,
    'iPhone 12 Pro': 17000,
    'iPhone 12': 13000,
    'iPhone 11 Pro': 12000,
    'iPhone 11': 9000,
    'iPhone SE (2022)': 7000,
  },
  'Samsung': {
    'Galaxy S24 Ultra': 55000,
    'Galaxy S24': 32000,
    'Galaxy S23 Ultra': 38000,
    'Galaxy S23': 22000,
    'Galaxy S22': 13000,
    'Galaxy S21 FE': 9000,
    'Galaxy Z Fold5': 45000,
    'Galaxy Z Flip5': 25000,
    'Galaxy A54': 9000,
    'Galaxy M34': 6000,
  },
  'Google': {
    'Pixel 8 Pro': 30000,
    'Pixel 8': 20000,
    'Pixel 7 Pro': 16000,
    'Pixel 7a': 12000,
    'Pixel 7': 11000,
    'Pixel 6a': 7000,
  },
  'OnePlus': {
    'OnePlus 12': 30000,
    'OnePlus 12R': 22000,
    'OnePlus 11': 20000,
    'OnePlus 11R': 15000,
    'Nord CE 3': 7000,
  },
  'Xiaomi': {
    'Xiaomi 14': 28000,
    'Xiaomi 13 Pro': 22000,
    'Redmi Note 13 Pro': 11000,
    'Redmi Note 12 Pro': 7500,
  },
  'vivo': {'X100 Pro': 38000, 'X90 Pro': 24000, 'V29': 12000, 'V27': 9000},
  'Realme': {'GT 6': 18000, '11 Pro': 8000},
  'Nothing': {'Phone (2)': 15000, 'Phone (2a)': 11000, 'Phone (1)': 8000},
  'Motorola': {'Edge 50 Pro': 13000, 'Edge 40': 9000},
};

const kTradeInStorage = <String, double>{
  '64GB': 0.9,
  '128GB': 1,
  '256GB': 1.08,
  '512GB': 1.15,
  '1TB': 1.22,
};

/// A condition question with (label, value multiplier) answers.
class TradeQuestion {
  const TradeQuestion(this.id, this.title, this.hint, this.options);
  final String id;
  final String title;
  final String hint;
  final List<(String, double)> options;
}

const kTradeQuestions = [
  TradeQuestion(
    'power',
    'Does the phone turn on and work?',
    'Calls, touch and display respond normally',
    [('Turns on and works normally', 1), ('Does not turn on / dead', 0.15)],
  ),
  TradeQuestion(
    'screen',
    'Screen condition',
    'Look at it with the screen off, under light',
    [
      ('Flawless', 1),
      ('Minor scratches', 0.95),
      ('Visible scratches', 0.85),
      ('Cracked or dead pixels', 0.6),
    ],
  ),
  TradeQuestion('body', 'Body & back panel', 'Frame, back glass and corners', [
    ('Like new', 1),
    ('Minor scuffs', 0.95),
    ('Dents or cracked back', 0.82),
  ]),
  TradeQuestion(
    'battery',
    'Battery health',
    'iPhone: Settings > Battery > Battery Health',
    [('90% or more', 1), ('80% – 89%', 0.95), ('Below 80% / Service', 0.86)],
  ),
];

const kTradeFaults = <String, double>{
  'Face ID / Fingerprint': 0.15,
  'Camera': 0.15,
  'Speaker / Mic': 0.08,
  'Charging port': 0.08,
  'Wi-Fi / Bluetooth / SIM': 0.1,
  'Buttons': 0.05,
};

const kTradeExtras = <String, double>{
  'Original box': 0.02,
  'Original charger / cable': 0.01,
  'Purchase invoice': 0.02,
};

const kExchangeBonus = 1000.0;

class QuoteLine {
  const QuoteLine(this.label, this.amount);
  final String label;
  final double amount;
}

/// What the buyer told us about their old phone.
class TradeInDevice {
  const TradeInDevice({
    required this.brand,
    required this.model,
    this.storage = '128GB',
    this.answers = const {},
    this.faults = const {},
    this.extras = const {},
  });
  final String brand;
  final String model;
  final String storage;
  final Map<String, String> answers;
  final Set<String> faults;
  final Set<String> extras;

  bool get dead => answers['power'] == kTradeQuestions.first.options[1].$1;

  /// "Minor scratches • 2 faults"-style summary.
  String get conditionSummary {
    if (dead) return 'Not working';
    final parts = [
      answers['screen'] ?? 'Flawless screen',
      if (faults.isNotEmpty)
        '${faults.length} fault${faults.length > 1 ? 's' : ''}',
    ];
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'model': model,
    'storage': storage,
    'answers': answers,
    'faults': faults.toList(),
    'extras': extras.toList(),
  };

  factory TradeInDevice.fromJson(Map<String, dynamic> j) => TradeInDevice(
    brand: j['brand'] as String,
    model: j['model'] as String,
    storage: j['storage'] as String? ?? '128GB',
    answers: Map<String, String>.from(j['answers'] as Map? ?? const {}),
    faults: {...(j['faults'] as List? ?? const []).cast<String>()},
    extras: {...(j['extras'] as List? ?? const []).cast<String>()},
  );
}

/// Local quote (same rules as the server).
(double, List<QuoteLine>)? localQuote(
  TradeInDevice d, {
  double newPhonePrice = 0,
  double bonus = kExchangeBonus,
}) {
  final base = kTradeInModels[d.brand]?[d.model];
  if (base == null) return null;
  final lines = [QuoteLine('${d.model} base value', base)];
  var value = base;
  final sf = kTradeInStorage[d.storage] ?? 1;
  if (sf != 1) {
    lines.add(
      QuoteLine('Storage ${d.storage}', (base * sf - base).roundToDouble()),
    );
    value = base * sf;
  }
  for (final q in kTradeQuestions) {
    final pick = q.options.firstWhere(
      (o) => o.$1 == d.answers[q.id],
      orElse: () => q.options.first,
    );
    if (pick.$2 != 1) {
      final next = value * pick.$2;
      lines.add(QuoteLine(pick.$1, (next - value).roundToDouble()));
      value = next;
    }
  }
  if (!d.dead) {
    for (final f in d.faults) {
      final cut = kTradeFaults[f];
      if (cut == null) continue;
      lines.add(QuoteLine('$f not working', -(value * cut).roundToDouble()));
      value *= 1 - cut;
    }
    for (final e in d.extras) {
      final add = kTradeExtras[e];
      if (add == null) continue;
      lines.add(QuoteLine(e, (base * add).roundToDouble()));
      value += base * add;
    }
  }
  value = ((value / 50).round() * 50).toDouble();
  if (value < 500) value = 500;
  if (bonus > 0 && newPhonePrice >= 30000 && !d.dead) {
    lines.add(QuoteLine('GAMEX exchange bonus', bonus));
    value += bonus;
  }
  if (newPhonePrice > 0 && value > newPhonePrice * 0.9) {
    value = (newPhonePrice * 0.9).roundToDouble();
  }
  return (value, lines);
}

/// A quote the buyer can use at checkout.
class TradeInQuote {
  const TradeInQuote({
    required this.device,
    required this.amount,
    required this.lines,
    required this.expiresAt,
    this.serverId,
  });
  final TradeInDevice device;
  final double amount;
  final List<QuoteLine> lines;
  final DateTime expiresAt;

  /// Quote id on the GAMEX server (null when quoted offline).
  final String? serverId;

  bool get expired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'device': device.toJson(),
    'amount': amount,
    'lines': [
      for (final l in lines) {'label': l.label, 'amount': l.amount},
    ],
    'expiresAt': expiresAt.toIso8601String(),
    'serverId': serverId,
  };

  factory TradeInQuote.fromJson(Map<String, dynamic> j) => TradeInQuote(
    device: TradeInDevice.fromJson(j['device'] as Map<String, dynamic>),
    amount: (j['amount'] as num).toDouble(),
    lines: [
      for (final l in (j['lines'] as List? ?? const []).cast<Map>())
        QuoteLine(l['label'] as String, (l['amount'] as num).toDouble()),
    ],
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    serverId: j['serverId'] as String?,
  );
}
