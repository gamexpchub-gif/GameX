import 'package:material_ui/material_ui.dart';

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
      default:
        return Icon(Icons.smartphone_rounded, size: s);
    }
  }
}
