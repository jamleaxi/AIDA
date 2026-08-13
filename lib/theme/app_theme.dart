import 'package:flutter/material.dart';

/// Brand colors sampled from `lib/assets/aida-logo.png`.
class AidaColors {
  const AidaColors._();

  static const pink = Color(0xFFF0609A);
  static const pinkDeep = Color(0xFFE0457F);
  static const teal = Color(0xFF4ECDC0);
  static const navy = Color(0xFF1D3A5F);
  static const bgLight = Color(0xFFE3F4FC);
  static const bgDark = Color(0xFF10192B);
  static const surfaceDark = Color(0xFF182338);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AidaColors.pink,
      brightness: brightness,
      secondary: AidaColors.teal,
      surface: isDark ? AidaColors.surfaceDark : Colors.white,
    ).copyWith(
      primary: AidaColors.pink,
      tertiary: AidaColors.navy,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AidaColors.bgDark : AidaColors.bgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AidaColors.pink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AidaColors.surfaceDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AidaColors.pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
