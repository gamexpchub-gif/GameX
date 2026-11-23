import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/invoice.dart';
import '../data/tracking.dart';

/// Live order tracking: courier map, status, delivery OTP, scans and the
/// GST invoice.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.invalidate(trackingProvider(widget.orderId)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trackingProvider(widget.orderId));
    return TrustScaffold(
      title: 'Track order',
      subtitle: '#${widget.orderId}',
      trailing: IconButton(
        onPressed: () => ref.invalidate(trackingProvider(widget.orderId)),
        icon: const Icon(Icons.refresh_rounded, color: TX.ink),
      ),
      children: async.when(
        loading: () => const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
        error: (e, _) => [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'Could not load tracking\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TX.muted),
            ),
          ),
        ],
        data: (list) {
          if (list.isEmpty) return const [Text('No shipments yet')];
          final s = list[_index.clamp(0, list.length - 1)];
          return [
            if (list.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < list.length; i++)
                      ButtonSegment(value: i, label: Text('Item ${i + 1}')),
                  ],
                  selected: {_index},
                  onSelectionChanged: (v) => setState(() => _index = v.first),
                ),
              ),
            _MapCard(s: s),
            const SizedBox(height: 12),
            _StatusCard(s: s),
            if (s.otp != null) ...[
              const SizedBox(height: 12),
              _OtpCard(otp: s.otp!),
            ],
            if (s.awb != null) ...[
              const SizedBox(height: 12),
              _CourierCard(s: s),
            ],
            const TTitle('Shipment updates'),
            _Timeline(s: s),
            const SizedBox(height: 14),
            if (s.stage != 'cancelled')
              TGhost(
                label: 'Download GST invoice',
                icon: Icons.receipt_long_rounded,
                color: TX.violet,
                onTap: () async {
                  try {
                    await shareInvoice(s);
                  } catch (e) {
                    if (context.mounted) {
                      tSnack(
                        context,
                        'Could not create the invoice: $e',
                        error: true,
                      );
                    }
                  }
                },
              ),
          ];
        },
      ),
    );
  }
}

// ───────────────────────────── Map ─────────────────────────────

class _MapCard extends StatefulWidget {
  const _MapCard({required this.s});
  final Shipment s;

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      height: 270,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF4FF), Color(0xFFF6F0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: TX.soft(0.08),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => CustomPaint(
                painter: _RoutePainter(
                  from: cityXY(s.from),
                  to: cityXY(s.to),
                  progress: s.progress,
                  pulse: _pulse.value,
                  fromLabel: s.from,
                  toLabel: s.to,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    s.live ? Icons.sensors_rounded : Icons.route_rounded,
                    size: 15,
                    color: s.live ? TX.green : TX.violet,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    s.live ? 'Live from ${s.courier}' : '${s.from} → ${s.to}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: TX.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: TX.chip,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${(s.progress * 100).round()}% of the way',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simplified outline of India in the same 0..1 space as [kCityXY].
const _india = [
  (0.33, 0.02),
  (0.40, 0.06),
  (0.42, 0.12),
  (0.48, 0.20),
  (0.55, 0.27),
  (0.66, 0.31),
  (0.73, 0.31),
  (0.76, 0.27),
  (0.95, 0.24),
  (0.97, 0.32),
  (0.88, 0.41),
  (0.80, 0.38),
  (0.77, 0.45),
  (0.72, 0.47),
  (0.65, 0.50),
  (0.58, 0.56),
  (0.50, 0.66),
  (0.47, 0.72),
  (0.46, 0.80),
  (0.42, 0.86),
  (0.36, 0.96),
  (0.32, 0.90),
  (0.28, 0.80),
  (0.24, 0.68),
  (0.21, 0.58),
  (0.18, 0.50),
  (0.10, 0.46),
  (0.08, 0.42),
  (0.14, 0.38),
  (0.18, 0.30),
  (0.24, 0.24),
  (0.28, 0.16),
  (0.30, 0.08),
];

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.pulse,
    required this.fromLabel,
    required this.toLabel,
  });
  final (double, double) from;
  final (double, double) to;
  final double progress;
  final double pulse;
  final String fromLabel;
  final String toLabel;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the map (taller than wide) into the card.
    final h = size.height * 0.92;
    final w = h * 0.86;
    final ox = (size.width - w) / 2;
    final oy = (size.height - h) / 2;
    Offset p((double, double) v) => Offset(ox + v.$1 * w, oy + v.$2 * h);

    final outline = Path()..moveTo(p(_india.first).dx, p(_india.first).dy);
    for (final v in _india.skip(1)) {
      outline.lineTo(p(v).dx, p(v).dy);
    }
    outline.close();
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFDCE6FF), Color(0xFFE9DEFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFB9C6F5),
    );
    // Other cities as faint dots.
    for (final c in kCityXY.values.toSet()) {
      canvas.drawCircle(p(c), 1.8, Paint()..color = const Color(0xFF9AA8D8));
    }

    final a = p(from);
    var b = p(to);
    if ((a - b).distance < 8) b = a + const Offset(26, 14);
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final n = Offset(-(b.dy - a.dy), b.dx - a.dx);
    final ctrl =
        mid +
        n /
            (n.distance == 0 ? 1 : n.distance) *
            math.max(28, (b - a).distance * 0.35);
    Offset at(double t) {
      final u = 1 - t;
      return a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
    }

    // Dashed full route.
    final dash = Paint()
      ..color = const Color(0xFF8E9CC8)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var t = 0.0; t < 1; t += 0.04) {
      canvas.drawLine(at(t), at(math.min(1, t + 0.02)), dash);
    }
    // Travelled part.
    final done = Path()..moveTo(a.dx, a.dy);
    for (var t = 0.0; t <= progress; t += 0.01) {
      final q = at(t);
      done.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFF17B6FF), Color(0xFF8E3DFF)],
        ).createShader(Rect.fromPoints(a, b)),
    );

    void pin(Offset c, Color color, String label, {bool above = true}) {
      canvas.drawCircle(c, 9, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(c, 5.5, Paint()..color = color);
      canvas.drawCircle(c, 2.2, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D1030),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, above ? -24 : 10));
    }

    pin(a, const Color(0xFF2F6BFF), fromLabel, above: a.dy <= b.dy);
    if (fromLabel != toLabel) {
      pin(b, const Color(0xFF16A34A), toLabel, above: b.dy < a.dy);
    }

    // Courier position with a pulse.
    final c = at(progress.clamp(0.0, 1.0));
    canvas.drawCircle(
      c,
      10 + pulse * 14,
      Paint()
        ..color = const Color(0xFF8E3DFF).withValues(alpha: (1 - pulse) * 0.35),
    );
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 9, Paint()..color = const Color(0xFF8E3DFF));
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.local_shipping_rounded.codePoint),
        style: TextStyle(
          fontSize: 12,
          fontFamily: Icons.local_shipping_rounded.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, c - Offset(icon.width / 2, icon.height / 2));
  }

  @override
  bool shouldRepaint(_RoutePainter o) =>
      o.progress != progress || o.pulse != pulse;
}

// ───────────────────────────── Cards ─────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.s});
  final Shipment s;

  @override
  Widget build(BuildContext context) {
    final cancelled = s.stage == 'cancelled';
    final eta = s.eta;
    final now = DateTime.now();
    final etaText = s.stage == 'delivered'
        ? 'Delivered${s.scans.isEmpty ? '' : ' on ${DateFormat('EEE, d MMM').format(s.scans.last.at.toLocal())}'}'
        : cancelled
        ? 'This shipment was cancelled'
        : eta == null
        ? 'Delivery date after the seller packs'
        : eta.isBefore(now) || DateUtils.isSameDay(eta, now)
        ? 'Arriving today'
        : 'Arriving by ${DateFormat('EEE, d MMM').format(eta.toLocal())}';
    const steps = ['Ordered', 'Packed', 'Shipped', 'Delivered'];
    return TCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: AppImage(
                  _img(s.photo),
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.item,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                    Text(
                      '${s.variant} • ${formatPrice(s.price)}',
                      style: const TextStyle(fontSize: 12, color: TX.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            etaText,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: cancelled
                  ? TX.red
                  : s.stage == 'delivered'
                  ? TX.green
                  : TX.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (!cancelled)
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: i <= s.step ? TX.violet : TX.line,
                        child: Icon(
                          i < s.step || s.stage == 'delivered'
                              ? Icons.check_rounded
                              : Icons.circle,
                          size: i < s.step || s.stage == 'delivered' ? 14 : 6,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: i <= s.step ? TX.ink : TX.faint,
                        ),
                      ),
                    ],
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: i < s.step ? TX.chip : null,
                          color: i < s.step ? null : TX.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

String _img(String p) =>
    p.startsWith('/img/') ? 'asset:assets/images/home/${p.substring(5)}' : p;

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.otp});
  final String otp;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: TX.night,
      borderRadius: BorderRadius.circular(22),
      boxShadow: TX.soft(0.2),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DELIVERY OTP',
                style: TextStyle(
                  color: Color(0xFFC9D2FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                otp.split('').join(' '),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Open the box and check the phone first. Share the OTP only when you are happy.',
                style: TextStyle(
                  color: Color(0xFFC9D2FF),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_open_rounded, color: Color(0xFFFFC542), size: 40),
      ],
    ),
  );
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.s});
  final Shipment s;

  @override
  Widget build(BuildContext context) => TCard(
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    child: Row(
      children: [
        const TIcon(Icons.local_shipping_rounded, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.courier ?? 'Courier',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: TX.ink,
                ),
              ),
              Text(
                'AWB ${s.awb}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: TX.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy AWB',
          icon: const Icon(Icons.copy_rounded, color: TX.violet),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: s.awb!));
            tSnack(context, 'AWB copied');
          },
        ),
      ],
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.s});
  final Shipment s;

  @override
  Widget build(BuildContext context) {
    final items = [for (final sc in s.scans) sc]
      ..sort((a, b) => b.at.compareTo(a.at));
    if (items.isEmpty) {
      return const TCard(
        child: Text(
          'Courier updates appear here once the seller hands over your phone.',
          style: TextStyle(color: TX.muted),
        ),
      );
    }
    final f = DateFormat('d MMM, h:mm a');
    return TCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        children: [
          for (final (i, sc) in items.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: i == 0 ? TX.chip : null,
                          color: i == 0 ? null : TX.line,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      if (i < items.length - 1)
                        Expanded(child: Container(width: 2, color: TX.line)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sc.label,
                            style: TextStyle(
                              fontWeight: i == 0
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: TX.ink,
                            ),
                          ),
                          Text(
                            '${sc.place.isEmpty ? '' : '${sc.place} • '}${f.format(sc.at.toLocal())}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TX.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
