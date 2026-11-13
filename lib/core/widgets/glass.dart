import 'package:material_ui/material_ui.dart';

/// Frosted surface used across the home screen.
///
/// Deliberately does NOT use `BackdropFilter`: live blur on many cards (and
/// on the bottom bar while scrolling) was the main cause of jank on Android.
/// A translucent fill + bright hairline edge + outer-only shadow gives the
/// same look on the light backdrop at a fraction of the GPU cost.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.color,
    this.padding,
    this.shadow = true,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final bool shadow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            color ??
            (dark
                ? const Color(0xFF1B2133).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.72)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              borderColor ??
              (dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.95)),
          width: 1.2,
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: const Color(0xFF2A3D8F)
                      .withValues(alpha: dark ? 0.3 : 0.07),
                  blurRadius: 18,
                  blurStyle: BlurStyle.outer,
                ),
              ]
            : null,
      ),
      // Own Material so ListTiles / InkWells inside show their ripples.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Soft blue-lavender page backdrop sampled from the design.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0E1222), Color(0xFF0B0E18)]
              : const [
                  Color(0xFFF0F4FF),
                  Color(0xFFE6EDFD),
                  Color(0xFFEEF2FD),
                  Color(0xFFF5F7FE),
                ],
          stops: dark ? null : const [0, 0.25, 0.5, 1],
        ),
      ),
      child: child,
    );
  }
}
