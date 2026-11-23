import 'package:material_ui/material_ui.dart';

/// Add-on protection for a phone, priced as a share of the phone's price.
class ProtectionPlan {
  const ProtectionPlan({
    required this.id,
    required this.title,
    required this.short,
    required this.icon,
    required this.rate,
    required this.min,
    required this.max,
    required this.months,
    required this.covers,
    this.popular = false,
  });
  final String id;
  final String title;

  /// Short label for chips ("Screen 1yr").
  final String short;
  final IconData icon;
  final double rate;
  final double min;
  final double max;
  final int months;
  final List<String> covers;
  final bool popular;

  double priceFor(double phonePrice) {
    final raw = (phonePrice * rate).clamp(min, max);
    return ((raw / 100).ceil() * 100 - 1).toDouble();
  }
}

const kProtectionPlans = [
  ProtectionPlan(
    id: 'screen',
    title: 'Screen Damage Protection',
    short: 'Screen 1yr',
    icon: Icons.phone_android_rounded,
    rate: 0.045,
    min: 699,
    max: 4999,
    months: 12,
    covers: [
      '1 free screen replacement in 12 months',
      'Cracks, drops and display failure',
      'Free pickup & drop, repaired in 72 hours',
    ],
  ),
  ProtectionPlan(
    id: 'ext6',
    title: 'Extended Warranty +6 months',
    short: '+6 mo warranty',
    icon: Icons.verified_user_rounded,
    rate: 0.03,
    min: 499,
    max: 2999,
    months: 6,
    covers: [
      'Starts after the seller warranty ends',
      'Hardware faults: battery, speaker, charging, cameras',
      'Unlimited repairs up to the phone value',
    ],
  ),
  ProtectionPlan(
    id: 'ext12',
    title: 'Extended Warranty +12 months',
    short: '+12 mo warranty',
    icon: Icons.workspace_premium_rounded,
    rate: 0.05,
    min: 899,
    max: 4999,
    months: 12,
    covers: [
      'A full extra year after the seller warranty',
      'Hardware faults: battery, speaker, charging, cameras',
      'Unlimited repairs up to the phone value',
    ],
  ),
  ProtectionPlan(
    id: 'total',
    title: 'Total Care',
    short: 'Total Care',
    icon: Icons.shield_rounded,
    rate: 0.08,
    min: 1499,
    max: 8999,
    months: 12,
    popular: true,
    covers: [
      'Screen + liquid + accidental damage',
      '+12 months extended warranty',
      'Doorstep repair, 2 claims a year',
    ],
  ),
];

ProtectionPlan? protectionById(String? id) {
  for (final p in kProtectionPlans) {
    if (p.id == id) return p;
  }
  return null;
}

/// Accessories and other non-phone products are never protected.
bool canProtect(String categoryId) => categoryId != kAccessoryCategory;

const kAccessoryCategory = 'accessories';
