import 'package:material_ui/material_ui.dart';

/// Brand palette for GAMEX (matched to the home screen design).
abstract final class AppColors {
  static const primary = Color(0xFF1F4FEA);
  static const primaryDark = Color(0xFF0B2A9E);
  static const accent = Color(0xFFFF6B3D);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFE5283B);
  static const star = Color(0xFFF5B400);

  // Light surfaces
  static const background = Color(0xFFF2F4FC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0B1020);
  static const textSecondary = Color(0xFF4A5372);
  static const border = Color(0xFFE3E7F3);

  // Dark surfaces
  static const backgroundDark = Color(0xFF0B0E18);
  static const surfaceDark = Color(0xFF151A28);
  static const borderDark = Color(0xFF262C3D);

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF2E63FF), Color(0xFF1437C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Logo wordmark gradient.
  static const logoGradient = LinearGradient(
    colors: [Color(0xFF0A2BD8), Color(0xFF2F6BFF), Color(0xFF7FB2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
