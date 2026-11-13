import 'package:material_ui/material_ui.dart';

/// The home screen is laid out on the design mockup's pixel grid
/// (852 px wide). `context.k` converts design pixels to logical pixels
/// so every size, gap and font matches the mockup on any screen width.
extension DesignScale on BuildContext {
  double get k => MediaQuery.sizeOf(this).width / 852;
}

/// Colours sampled from the design mockup.
abstract final class HomeColors {
  static const ink = Color(0xFF0B1020);
  static const inkSoft = Color(0xFF1F2433);
  static const muted = Color(0xFF3B4A75);
  static const hint = Color(0xFF3F4660);
  static const blue = Color(0xFF0052FF);
  static const blueDeep = Color(0xFF0A1A4A);
  static const red = Color(0xFFE5283B);
  static const green = Color(0xFF138A4A);
  static const greenBg = Color(0xFFC6F3E2);
  static const amber = Color(0xFFD9822B);
  static const grey = Color(0xFF8C95B0);

  static const searchFill = Color(0xFFE3EBFF);
  static const cardFill = Color(0xFFEDF2FF);
}
