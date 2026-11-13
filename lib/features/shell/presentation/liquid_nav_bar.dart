import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass.dart';

class LiquidNavItem {
  const LiquidNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

/// Floating frosted-glass bottom bar. The selection pill moves like a water
/// droplet: its leading edge races ahead, the tail catches up, it squishes
/// vertically mid-flight, sheds small droplets and lands with a ripple.
///
/// All sizes are expressed in the design's pixel grid (852 px wide) and
/// scaled to the device width so it matches the mockup exactly.
class LiquidNavBar extends StatefulWidget {
  const LiquidNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<LiquidNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Total height the bar occupies including its bottom margin, for a
  /// device of [width] with [bottomInset] safe area.
  static double occupiedHeight(double width, double bottomInset) {
    final k = width / 852;
    return 114 * k + math.max(bottomInset, 14 * k) + 10 * k;
  }

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..value = 1;
  late int _from = widget.currentIndex;
  late int _to = widget.currentIndex;

  @override
  void didUpdateWidget(LiquidNavBar old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != _to) {
      _from = _to;
      _to = widget.currentIndex;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final k = mq.size.width / 852;
    final barH = 114 * k;
    final n = widget.items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 * k,
        0,
        12 * k,
        math.max(mq.padding.bottom, 14 * k),
      ),
      child: Glass(
        radius: barH / 2,
        blur: 28,
        opacity: 0.62,
        child: SizedBox(
          height: barH,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / n;
              return Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, _) => CustomPaint(
                        painter: _LiquidPillPainter(
                          from: _from,
                          to: _to,
                          t: _c.value,
                          slot: slot,
                          pillWidth: 153 * k,
                          pillHeight: 97 * k,
                          dark: Theme.of(context).brightness == Brightness.dark,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _NavButton(
                            item: widget.items[i],
                            selected: i == widget.currentIndex,
                            k: k,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.k,
    required this.onTap,
  });

  final LiquidNavItem item;
  final bool selected;
  final double k;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? const Color(0xFFD5DAEA) : const Color(0xFF1B2030);
    final color = selected ? AppColors.primary : idle;
    Widget icon = Icon(
      selected ? item.activeIcon : item.icon,
      size: 44 * k,
      color: color,
    );
    if (item.badge > 0) {
      icon = Badge(
        label: Text(item.badge > 99 ? '99+' : '${item.badge}'),
        child: icon,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSlide(
              offset: Offset(0, selected ? -0.06 : 0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              child: AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                child: icon,
              ),
            ),
            SizedBox(height: 6 * k),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                fontSize: 19 * k,
                height: 1.1,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
              child: Text(item.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidPillPainter extends CustomPainter {
  _LiquidPillPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.slot,
    required this.pillWidth,
    required this.pillHeight,
    required this.dark,
  });

  final int from;
  final int to;
  final double t;
  final double slot;
  final double pillWidth;
  final double pillHeight;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final a = slot * (from + 0.5);
    final b = slot * (to + 0.5);
    final dir = b >= a ? 1.0 : -1.0;

    // Leading edge races ahead, trailing edge lags → liquid stretch.
    final lead = Curves.easeOutCubic.transform(t);
    final trail = Curves.easeInOutCubic.transform(t);
    final half = pillWidth / 2;
    // Damped wobble once it lands.
    final wobble = math.sin(t * math.pi * 3) * (1 - t) * 0.09 * pillWidth;

    double left, right;
    if (dir > 0) {
      right = a + (b - a) * lead + half;
      left = a + (b - a) * trail - half;
    } else {
      left = a + (b - a) * lead - half;
      right = a + (b - a) * trail + half;
    }
    left -= wobble / 2;
    right += wobble / 2;

    final squish = 1 - 0.16 * math.sin(math.pi * t);
    final h = pillHeight * squish;
    final rect = Rect.fromLTRB(left, cy - h / 2, right, cy + h / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));

    // Droplets shed behind while moving.
    if (t > 0.05 && t < 0.9 && from != to) {
      for (var i = 1; i <= 2; i++) {
        final dt = (t - 0.08 * i).clamp(0.0, 1.0);
        final x =
            a +
            (b - a) * Curves.easeInOutCubic.transform(dt) -
            dir * half * 0.55;
        final r = pillHeight * 0.12 * (1 - t) / i;
        canvas.drawCircle(
          Offset(x, cy + pillHeight * 0.18 * i * 0.5),
          r,
          Paint()..color = AppColors.primary.withValues(alpha: 0.12),
        );
      }
    }

    // Soft shadow under the droplet.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0xFF2846C8).withValues(alpha: dark ? 0.35 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Water body.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  const Color(0xFF3A4670).withValues(alpha: 0.9),
                  const Color(0xFF283152).withValues(alpha: 0.9),
                ]
              : [
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFE3EAFF).withValues(alpha: 0.95),
                ],
        ).createShader(rect),
    );

    // Caustic tint along the bottom.
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.bottom),
        width: rect.width * 0.9,
        height: rect.height * 0.7,
      ),
      Paint()
        ..color = AppColors.primary.withValues(alpha: dark ? 0.18 : 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();

    // Specular rim + top highlight.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.35 : 1),
            const Color(0xFFBFD0FF).withValues(alpha: 0.6),
          ],
        ).createShader(rect),
    );
    final hl = Rect.fromLTWH(
      rect.left + rect.width * 0.18,
      rect.top + rect.height * 0.08,
      rect.width * 0.64,
      rect.height * 0.16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hl, Radius.circular(hl.height)),
      Paint()
        ..color = Colors.white.withValues(alpha: dark ? 0.12 : 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Landing ripple.
    if (from != to && t > 0.35) {
      final rt = (t - 0.35) / 0.65;
      final r = pillHeight * (0.45 + 0.3 * rt);
      canvas.drawCircle(
        Offset(b, cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - rt) + 0.5
          ..color = AppColors.primary.withValues(alpha: 0.22 * (1 - rt)),
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidPillPainter old) =>
      old.t != t ||
      old.from != from ||
      old.to != to ||
      old.dark != dark ||
      old.slot != slot;
}
