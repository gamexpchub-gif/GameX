import 'dart:math' as math;

/// A bank / lender that offers EMI on cards.
class EmiBank {
  const EmiBank(
    this.id,
    this.name,
    this.rate, {
    this.color = 0xFF2F6BFF,
    this.noCostTenures = const {3, 6},
    this.noCostMin9 = false,
  });
  final String id;
  final String name;

  /// Annual interest rate for standard EMI (e.g. 0.15 = 15% p.a.).
  final double rate;
  final int color;

  /// Tenures (months) offered at no cost.
  final Set<int> noCostTenures;

  /// Also no-cost for 9 months on orders of ₹30,000+.
  final bool noCostMin9;
}

const kEmiBanks = [
  EmiBank('hdfc', 'HDFC Bank', 0.15, color: 0xFF004C8F, noCostMin9: true),
  EmiBank('icici', 'ICICI Bank', 0.15, color: 0xFFB02A30, noCostMin9: true),
  EmiBank('sbi', 'SBI Card', 0.14, color: 0xFF1A5AA6),
  EmiBank('axis', 'Axis Bank', 0.15, color: 0xFF97144D),
  EmiBank('kotak', 'Kotak Bank', 0.16, color: 0xFFED1C24),
  EmiBank('bob', 'Bank of Baroda', 0.15, color: 0xFFF26522, noCostTenures: {3}),
];

const kEmiTenures = [3, 6, 9, 12, 18, 24];
const kEmiMinOrder = 5000.0;
const kNoCostMinOrder = 10000.0;
const kEmiProcessingFee = 199.0;

/// One EMI option for a price.
class EmiPlan {
  const EmiPlan({
    required this.bank,
    required this.months,
    required this.principal,
    required this.monthly,
    required this.interest,
    required this.noCost,
  });
  final EmiBank bank;
  final int months;
  final double principal;
  final double monthly;

  /// Interest the buyer pays (0 for no-cost EMI).
  final double interest;
  final bool noCost;

  /// Interest the bank charges that GAMEX gives back as an upfront
  /// discount on no-cost EMI.
  double get noCostDiscount =>
      noCost ? _interest(principal, bank.rate, months) : 0;

  double get total => principal + interest;

  String get label =>
      '${bank.name} • $months months${noCost ? ' • No-cost' : ''}';

  Map<String, dynamic> toJson() => {
    'bank': bank.id,
    'months': months,
    'monthly': monthly.round(),
    'noCost': noCost,
  };
}

/// Standard reducing-balance EMI.
double emiAmount(double principal, double annualRate, int months) {
  if (annualRate <= 0) return principal / months;
  final r = annualRate / 12;
  final f = math.pow(1 + r, months);
  return principal * r * f / (f - 1);
}

double _interest(double p, double rate, int n) => emiAmount(p, rate, n) * n - p;

bool isNoCost(EmiBank b, int months, double price) =>
    price >= kNoCostMinOrder &&
    (b.noCostTenures.contains(months) ||
        (months == 9 && b.noCostMin9 && price >= 30000));

EmiPlan emiPlan(EmiBank bank, int months, double price) {
  final noCost = isNoCost(bank, months, price);
  final monthly = noCost ? price / months : emiAmount(price, bank.rate, months);
  return EmiPlan(
    bank: bank,
    months: months,
    principal: price,
    monthly: monthly,
    interest: noCost ? 0 : monthly * months - price,
    noCost: noCost,
  );
}

List<EmiPlan> plansFor(EmiBank bank, double price) => [
  for (final m in kEmiTenures) emiPlan(bank, m, price),
];

/// Lowest monthly amount across banks ("EMI from ₹X/mo").
double lowestEmi(double price) {
  var best = double.infinity;
  for (final b in kEmiBanks) {
    for (final m in kEmiTenures) {
      best = math.min(best, emiPlan(b, m, price).monthly);
    }
  }
  return best;
}

/// Longest no-cost tenure available for [price].
int? bestNoCost(double price) {
  int? best;
  for (final b in kEmiBanks) {
    for (final m in kEmiTenures) {
      if (isNoCost(b, m, price) && (best == null || m > best)) best = m;
    }
  }
  return best;
}

// ───────────────────────────── Pay Later ─────────────────────────────

class PayLaterOption {
  const PayLaterOption(
    this.id,
    this.title,
    this.subtitle,
    this.limit, {
    this.parts = 1,
    this.days = 15,
    this.fee = 0,
  });
  final String id;
  final String title;
  final String subtitle;

  /// Maximum order value.
  final double limit;

  /// Number of equal parts.
  final int parts;

  /// Days until the (first) due date.
  final int days;
  final double fee;

  bool allows(double amount) => amount <= limit;

  List<(DateTime, double)> schedule(double amount, DateTime from) => [
    for (var i = 0; i < parts; i++)
      (
        from.add(Duration(days: parts == 1 ? days : 30 * i)),
        (amount + fee) / parts,
      ),
  ];
}

const kPayLater = [
  PayLaterOption(
    'pl15',
    'Pay in 15 days',
    'Get the phone now, pay later. No interest.',
    15000,
  ),
  PayLaterOption(
    'pl3',
    'Pay in 3',
    '3 interest-free parts: today, 30 and 60 days',
    40000,
    parts: 3,
  ),
  PayLaterOption(
    'cardless',
    'Cardless EMI',
    'No credit card needed. KYC with PAN & Aadhaar.',
    100000,
    parts: 6,
    fee: 499,
  ),
];
