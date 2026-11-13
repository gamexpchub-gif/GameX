import 'package:material_ui/material_ui.dart';

/// Brand palette for GameX Shop.
abstract final class AppColors {
  static const primary = Color(0xFF5B3DF5);
  static const primaryDark = Color(0xFF3F24C9);
  static const accent = Color(0xFFFF6B3D);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFE11D48);
  static const star = Color(0xFFFFB400);

  // Light surfaces
  static const background = Color(0xFFF6F7FB);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  // Dark surfaces
  static const backgroundDark = Color(0xFF0E0F14);
  static const surfaceDark = Color(0xFF181A22);
  static const borderDark = Color(0xFF2A2D38);

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6D4BFF), Color(0xFF3F24C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
