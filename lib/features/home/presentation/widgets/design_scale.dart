import 'package:material_ui/material_ui.dart';

/// The home screen is laid out on the design mockup's pixel grid
/// (852 px wide). `context.k` converts design pixels to logical pixels
/// so every size, gap and font matches the mockup on any screen width.
extension DesignScale on BuildContext {
  double get k => MediaQuery.sizeOf(this).width / 852;
}

abstract final class HomeColors {
  static const ink = Color(0xFF0B1020);
  static const inkSoft = Color(0xFF1F2433);
  static const muted = Color(0xFF3F4A6B);
  static const hint = Color(0xFF3F4660);
  static const blue = Color(0xFF1F4FEA);
  static const blueDeep = Color(0xFF0B1A4A);
  static const red = Color(0xFFE5283B);
  static const green = Color(0xFF15803D);
  static const greenBg = Color(0xFFD9F7E3);
  static const amber = Color(0xFFE59A00);
}
