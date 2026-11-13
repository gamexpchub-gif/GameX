import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Parsed `art:phone/<ARGB hex>/<view>` spec.
class PhoneArtSpec {
  const PhoneArtSpec(this.color, this.view);
  final Color color;
  final String view; // back | front | duo

  static PhoneArtSpec? tryParse(String url) {
    if (!url.startsWith('art:phone/')) return null;
    final parts = url.substring('art:phone/'.length).split('/');
    final value = int.tryParse(parts.first, radix: 16);
    if (value == null) return null;
    return PhoneArtSpec(Color(value), parts.length > 1 ? parts[1] : 'back');
  }
}

/// Phone aspect ratio (width / height).
const kPhoneAspect = 0.485;

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Back side of a modern flagship phone with a triple-camera module.
class PhoneBackPainter extends CustomPainter {
  const PhoneBackPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = Radius.circular(w * 0.17);
    final body = RRect.fromRectAndRadius(Offset.zero & size, r);

    // Metal frame.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _shade(color, 0.28),
            _shade(color, -0.12),
            _shade(color, 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );

    // Frosted glass back.
    final inset = w * 0.022;
    final glass = body.deflate(inset);
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = LinearGradient(
          colors: [_shade(color, 0.12), color, _shade(color, -0.08)],
          stops: const [0, 0.55, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(glass.outerRect),
    );

    // Diagonal sheen.
    canvas.save();
    canvas.clipRRect(glass);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.25, 0.42, 0.6],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    // Camera plateau.
    final bumpSize = w * 0.47;
    final bump = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.07, w * 0.07, bumpSize, bumpSize),
      Radius.circular(w * 0.13),
    );
    canvas.drawRRect(
      bump.shift(Offset(0, w * 0.012)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
    );
    canvas.drawRRect(
      bump,
      Paint()
        ..shader = LinearGradient(
          colors: [_shade(color, 0.16), _shade(color, -0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bump.outerRect),
    );
    canvas.drawRRect(
      bump,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    final b = bump.outerRect;
    Offset at(double x, double y) =>
        Offset(b.left + b.width * x, b.top + b.height * y);
    final lensR = b.width * 0.215;
    for (final c in [at(0.29, 0.28), at(0.29, 0.73), at(0.73, 0.5)]) {
      _lens(canvas, c, lensR);
    }
    // Flash + LiDAR.
    canvas.drawCircle(
      at(0.74, 0.18),
      lensR * 0.28,
      Paint()..color = const Color(0xFFF4EEDC),
    );
    canvas.drawCircle(
      at(0.74, 0.83),
      lensR * 0.26,
      Paint()..color = const Color(0xFF15161A),
    );
  }

  void _lens(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF55575E), Color(0xFF1B1C20), Color(0xFF6C6E75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r * 0.78, Paint()..color = const Color(0xFF0A0A0D));
    canvas.drawCircle(
      c,
      r * 0.58,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF3B3F8F),
            Color(0xFF14152A),
            Color(0xFF050507),
          ],
          stops: const [0, 0.55, 1],
          center: const Alignment(-0.3, -0.3),
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.58)),
    );
    canvas.drawCircle(
      c + Offset(-r * 0.22, -r * 0.22),
      r * 0.14,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(PhoneBackPainter old) => old.color != color;
}

/// Front side with an edge-to-edge screen, island and abstract wallpaper.
class PhoneFrontPainter extends CustomPainter {
  const PhoneFrontPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.17),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [_shade(color, 0.25), _shade(color, -0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    final bezel = body.deflate(w * 0.02);
    canvas.drawRRect(bezel, Paint()..color = const Color(0xFF050608));

    final screen = bezel.deflate(w * 0.03);
    canvas.save();
    canvas.clipRRect(screen);
    final rect = screen.outerRect;
    final deep = HSLColor.fromColor(color);
    final c1 = deep.withLightness(0.18).withSaturation(0.75).toColor();
    final c2 = deep.withLightness(0.5).withSaturation(0.85).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF04060F), c1, c2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );
    // Flowing ribbon wallpaper.
    for (var i = 0; i < 5; i++) {
      final path = Path()
        ..moveTo(rect.left - w * 0.2, rect.top + h * (0.35 + i * 0.09))
        ..cubicTo(
          rect.left + w * 0.4,
          rect.top + h * (0.1 + i * 0.06),
          rect.left + w * 0.7,
          rect.top + h * (0.85 - i * 0.05),
          rect.right + w * 0.3,
          rect.top + h * (0.45 + i * 0.07),
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * (0.12 - i * 0.015)
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.0),
              _shade(c2, 0.25).withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.05),
            ],
          ).createShader(rect)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.015),
      );
    }
    canvas.restore();

    // Dynamic island.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, screen.top + w * 0.08),
          width: w * 0.3,
          height: w * 0.085,
        ),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.black,
    );
    // Glass highlight.
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.center,
        ).createShader(bezel.outerRect),
    );
  }

  @override
  bool shouldRepaint(PhoneFrontPainter old) => old.color != color;
}

/// A single phone, back or front, sized to the given height.
class PhoneShape extends StatelessWidget {
  const PhoneShape({
    super.key,
    required this.color,
    required this.height,
    this.front = false,
  });

  final Color color;
  final double height;
  final bool front;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(height * kPhoneAspect, height),
        painter: front ? PhoneFrontPainter(color) : PhoneBackPainter(color),
      ),
    );
  }
}

/// Product image built from a [PhoneArtSpec]; fills its box on a soft
/// studio background.
class PhoneArt extends StatelessWidget {
  const PhoneArt({super.key, required this.spec, this.background = true});
  final PhoneArtSpec spec;
  final bool background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = math.min(c.maxHeight * 0.84, c.maxWidth * 1.45);
        Widget art;
        switch (spec.view) {
          case 'duo':
            final ph = math.min(c.maxHeight * 0.8, c.maxWidth * 1.15);
            art = SizedBox(
              width: ph * kPhoneAspect * 1.75,
              height: ph,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: ph * 0.02,
                    child: PhoneShape(color: spec.color, height: ph * 0.96),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: PhoneShape(
                      color: spec.color,
                      height: ph * 0.96,
                      front: true,
                    ),
                  ),
                ],
              ),
            );
          case 'front':
            art = PhoneShape(color: spec.color, height: h, front: true);
          default:
            art = PhoneShape(color: spec.color, height: h);
        }
        return Container(
          decoration: background
              ? const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFE9ECF5)],
                    radius: 0.9,
                  ),
                )
              : null,
          alignment: Alignment.center,
          child: art,
        );
      },
    );
  }
}
