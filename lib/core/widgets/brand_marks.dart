import 'package:material_ui/material_ui.dart';

/// Brand logo: artwork cut from the design when available, otherwise the
/// code-drawn [BrandMark].
class BrandLogo extends StatelessWidget {
  const BrandLogo(
    this.brandKey, {
    super.key,
    required this.width,
    required this.height,
  });

  final String brandKey;
  final double width;
  final double height;

  static const _assets = {
    'apple',
    'samsung',
    'google',
    'oneplus',
    'vivo',
    'xiaomi',
  };

  @override
  Widget build(BuildContext context) {
    if (_assets.contains(brandKey)) {
      return Image.asset(
        'assets/images/home/brand_$brandKey.png',
        width: width,
        height: height,
        filterQuality: FilterQuality.medium,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: Center(child: BrandMark(brandKey, size: height * 0.72)),
    );
  }
}

/// Lightweight brand marks drawn with Flutter primitives (no image assets).
/// Swap for official logo assets supplied via the admin panel later.
class BrandMark extends StatelessWidget {
  const BrandMark(this.brandKey, {super.key, this.size = 40});

  final String brandKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = size;
    switch (brandKey) {
      case 'apple':
        return Icon(
          Icons.apple,
          size: s * 1.05,
          color: const Color(0xFF0B0B0F),
        );
      case 'samsung':
        return SizedBox(
          width: s * 1.5,
          height: s * 0.62,
          child: Transform.rotate(
            angle: -0.12,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1428A0),
                borderRadius: BorderRadius.all(Radius.elliptical(s, s * 0.32)),
              ),
              alignment: Alignment.center,
              child: Text(
                'SAMSUNG',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: s * 0.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        );
      case 'google':
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const SweepGradient(
            colors: [
              Color(0xFFEA4335),
              Color(0xFFFBBC05),
              Color(0xFF34A853),
              Color(0xFF4285F4),
              Color(0xFFEA4335),
            ],
            stops: [0.0, 0.3, 0.5, 0.75, 1.0],
            transform: GradientRotation(-1.4),
          ).createShader(r),
          child: Text(
            'G',
            style: TextStyle(
              fontSize: s * 1.05,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      case 'oneplus':
        return SizedBox(
          width: s * 0.95,
          height: s * 0.95,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  width: s * 0.78,
                  height: s * 0.78,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFEB0028),
                      width: s * 0.07,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: const Color(0xFFEB0028),
                      fontSize: s * 0.48,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: const Color(0xFFEB0028),
                      fontSize: s * 0.42,
                      height: 0.9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'vivo':
        return Text(
          'vivo',
          style: TextStyle(
            color: const Color(0xFF415FFF),
            fontSize: s * 0.72,
            height: 1,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        );
      case 'xiaomi':
        return Container(
          width: s * 0.92,
          height: s * 0.92,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6900),
            borderRadius: BorderRadius.circular(s * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'mi',
            style: TextStyle(
              color: Colors.white,
              fontSize: s * 0.5,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      case 'realme':
        return Container(
          width: s * 0.92,
          height: s * 0.92,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC915),
            borderRadius: BorderRadius.circular(s * 0.16),
          ),
          alignment: Alignment.center,
          child: Text(
            'R',
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: s * 0.72,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'nothing':
        return CustomPaint(size: Size(s * 0.8, s), painter: _DotNPainter());
      case 'motorola':
        return Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
            color: Color(0xFF1A57D6),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size(s * 0.66, s * 0.5),
            painter: _BatwingPainter(),
          ),
        );
      case 'others':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: s * 0.2,
                height: s * 0.2,
                margin: EdgeInsets.symmetric(horizontal: s * 0.05),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F1A3D),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        );
      default:
        return Icon(Icons.smartphone_rounded, size: s);
    }
  }
}

/// Dot-matrix "N" (Nothing).
class _DotNPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const rows = 7, cols = 5;
    final dx = size.width / cols, dy = size.height / rows;
    final r = dx * 0.32;
    final p = Paint()..color = const Color(0xFF111111);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final diag = (x - y * (cols - 1) / (rows - 1)).abs() < 0.5;
        if (x == 0 || x == cols - 1 || diag) {
          canvas.drawCircle(Offset(dx * (x + 0.5), dy * (y + 0.5)), r, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotNPainter oldDelegate) => false;
}

/// Simplified Motorola batwing "M".
class _BatwingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(w * 0.12, h * 0.1, w * 0.25, 0)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.75, 0)
      ..quadraticBezierTo(w * 0.88, h * 0.1, w, h);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BatwingPainter oldDelegate) => false;
}
