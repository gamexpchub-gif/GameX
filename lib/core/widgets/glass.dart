import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// Frosted "liquid glass" surface: background blur, translucent fill,
/// bright hairline edge and a soft drop shadow.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 24,
    this.opacity = 0.62,
    this.padding,
    this.shadow = true,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: shadow
            ? [
                // Outer-only so it never shows through the translucent glass.
                BoxShadow(
                  color: const Color(0xFF1C2B6B)
                      .withValues(alpha: dark ? 0.35 : 0.09),
                  blurRadius: 22,
                  blurStyle: BlurStyle.outer,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        const Color(0xFF232A40).withValues(alpha: opacity),
                        const Color(0xFF161B2B).withValues(alpha: opacity),
                      ]
                    : [
                        Colors.white.withValues(alpha: opacity + 0.15),
                        Colors.white.withValues(alpha: opacity - 0.1),
                      ],
              ),
              border: Border.all(
                color:
                    borderColor ??
                    Colors.white.withValues(alpha: dark ? 0.08 : 0.85),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soft blue-lavender backdrop with blurred colour blobs, used behind
/// glass surfaces so the frosting is visible.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget blob(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0E1222), Color(0xFF0B0E18)]
              : const [Color(0xFFECEFFC), Color(0xFFF4F5FB), Color(0xFFF1F3FA)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: blob(
              const Color(0xFFC9D5FF).withValues(alpha: dark ? 0.15 : 0.7),
              360,
            ),
          ),
          Positioned(
            top: 380,
            right: -140,
            child: blob(
              const Color(0xFFDCD3FF).withValues(alpha: dark ? 0.12 : 0.6),
              380,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: blob(
              const Color(0xFFD6E4FF).withValues(alpha: dark ? 0.12 : 0.6),
              340,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
