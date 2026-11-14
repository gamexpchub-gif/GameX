import 'package:material_ui/material_ui.dart';

/// GAMEX Seller palette (matches the shopper app).
abstract final class C {
  static const primary = Color(0xFF1F5BFF);
  static const violet = Color(0xFF6A3DF5);
  static const ink = Color(0xFF0B1230);
  static const muted = Color(0xFF5B6380);
  static const faint = Color(0xFF98A1BC);
  static const bg = Color(0xFFF3F6FD);
  static const border = Color(0xFFE3E8F5);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF08A00);
  static const red = Color(0xFFE5283B);
  static const cyan = Color(0xFF0891B2);
  static const night = Color(0xFF0E1033);

  static const brandGradient = LinearGradient(
    colors: [primary, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const nightGradient = LinearGradient(
    colors: [Color(0xFF0E1033), Color(0xFF2A1466), Color(0xFF5B1E8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.primary,
    primary: C.primary,
    secondary: C.violet,
    error: C.red,
    surface: Colors.white,
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: C.border),
  );
  const btnText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: C.bg,
      foregroundColor: C.ink,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: C.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: const BorderSide(color: C.primary, width: 1.6),
      ),
      labelStyle: const TextStyle(fontFamily: 'Inter', color: C.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: btnText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: C.ink,
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: btnText,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: const BorderSide(color: C.border),
      backgroundColor: Colors.white,
      selectedColor: C.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: C.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 70,
      backgroundColor: Colors.white,
      indicatorColor: C.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? C.primary : C.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? C.primary : C.muted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: C.border, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
