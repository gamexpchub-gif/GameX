import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/product.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import '../../data/phone_intel.dart';
import '../../providers/discover_providers.dart';

Color verdictColor(PriceVerdict v) => switch (v) {
  PriceVerdict.great => TX.green,
  PriceVerdict.fair => TX.blue,
  PriceVerdict.high => const Color(0xFFEA580C),
};

IconData verdictIcon(PriceVerdict v) => switch (v) {
  PriceVerdict.great => Icons.local_offer_rounded,
  PriceVerdict.fair => Icons.thumb_up_alt_rounded,
  PriceVerdict.high => Icons.trending_up_rounded,
};

/// Small "Great Deal / Fair Price / Above Market" chip for cards.
class FairPriceChip extends StatelessWidget {
  const FairPriceChip({super.key, required this.fair, this.dense = false});
  final FairPrice fair;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = verdictColor(fair.verdict);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verdictIcon(fair.verdict), size: dense ? 11 : 14, color: c),
          SizedBox(width: dense ? 3 : 4),
          Flexible(
            child: Text(
              fair.verdict.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c,
                fontSize: dense ? 10.5 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fair Price meter for the product page: a gauge showing where this
/// price sits against GAMEX's market estimate for the same phone.
class FairPriceMeter extends ConsumerWidget {
  const FairPriceMeter({super.key, required this.product, this.price});
  final Product product;

  /// Price of the selected variant (defaults to the listing price).
  final double? price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    final base = fairPriceOf(product, market: pool);
    // Scale the estimate when the buyer picks another storage variant.
    final scale = price == null ? 1.0 : price! / product.price;
    final fair = FairPrice(
      price: price ?? product.price,
      market: (base.market * scale / 100).round() * 100,
      launch: base.launch,
      ageFactor: base.ageFactor,
      gradeFactor: base.gradeFactor,
      batteryFactor: base.batteryFactor,
      storageFactor: base.storageFactor * scale,
      comparables: base.comparables,
    );
    final c = verdictColor(fair.verdict);
    final pct = (fair.delta.abs() * 100).round();
    final line = switch (fair.verdict) {
      PriceVerdict.great =>
        '${formatPrice(fair.savings)} ($pct%) below the market price',
      PriceVerdict.fair =>
        fair.delta <= 0
            ? 'Right on the market price${pct > 0 ? ', $pct% below' : ''}'
            : 'Close to the market price, $pct% above',
      PriceVerdict.high => '$pct% above market. You could negotiate or compare',
    };
    return TCard(
      onTap: () => _explain(context, fair),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 70,
            child: CustomPaint(painter: _GaugePainter(fair.position)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Fair Price meter'.tr(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: TX.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: TX.faint,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  fair.verdict.label.tr(context),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: c,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: TX.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Market: ${formatPrice(fair.low)} – ${formatPrice(fair.high)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: TX.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _explain(BuildContext context, FairPrice f) {
    String pct(double x) {
      final v = ((x - 1) * 100).round();
      return v == 0 ? '±0%' : '${v > 0 ? '+' : ''}$v%';
    }

    final m = modelInfo(product);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How GAMEX prices this phone',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TX.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We estimate what this exact ${product.name} sells for today, '
                'then compare it with the asking price.',
                style: const TextStyle(color: TX.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              TCard(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  children: [
                    TRow(
                      'Launch price (${m.year})',
                      formatPrice(f.launch),
                      icon: Icons.new_releases_outlined,
                    ),
                    TRow(
                      'Age & resale value',
                      '${(f.ageFactor * 100).round()}% kept',
                      icon: Icons.history_rounded,
                    ),
                    TRow(
                      'Condition: ${gradeOf(product)}',
                      pct(f.gradeFactor),
                      icon: Icons.auto_awesome_outlined,
                    ),
                    TRow(
                      'Battery health ${batteryOf(product)}%',
                      pct(f.batteryFactor),
                      icon: Icons.battery_charging_full_rounded,
                    ),
                    TRow(
                      'Storage ${product.storage ?? ''}',
                      pct(f.storageFactor),
                      icon: Icons.sd_storage_outlined,
                    ),
                    if (f.comparables >= 3)
                      TRow(
                        'Similar listings on GAMEX',
                        '${f.comparables} compared',
                        icon: Icons.compare_arrows_rounded,
                      ),
                    TRow(
                      'Fair market value',
                      formatPrice(f.market),
                      icon: Icons.verified_outlined,
                      valueColor: TX.violet,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final v in PriceVerdict.values)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: verdictColor(v)
                              .withValues(alpha: v == f.verdict ? 0.16 : 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: v == f.verdict
                                ? verdictColor(v)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              v.label,
                              style: TextStyle(
                                color: verdictColor(v),
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              switch (v) {
                                PriceVerdict.great => '6%+ below',
                                PriceVerdict.fair => 'within ±6%',
                                PriceVerdict.high => '7%+ above',
                              },
                              style: const TextStyle(
                                fontSize: 11,
                                color: TX.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Estimates are a guide based on launch prices, typical resale '
                'value and listings on GAMEX. They are not a guarantee.',
                style: TextStyle(fontSize: 11.5, color: TX.faint, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.position);
  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.2;
    final r = math.min(size.width / 2, size.height) - stroke / 2;
    final center = Offset(size.width / 2, size.height - 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    const segments = [
      (0.0, 0.38, Color(0xFF22C55E)),
      (0.38, 0.64, Color(0xFF3B82F6)),
      (0.64, 1.0, Color(0xFFF97316)),
    ];
    for (final (a, b, c) in segments) {
      canvas.drawArc(
        rect,
        math.pi + a * math.pi + 0.025,
        (b - a) * math.pi - 0.05,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    // Needle.
    final angle = math.pi + position * math.pi;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * (r - 2);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFF0D1030)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6.5, Paint()..color = const Color(0xFF0D1030));
    canvas.drawCircle(center, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.position != position;
}
