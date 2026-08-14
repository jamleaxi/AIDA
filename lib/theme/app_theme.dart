import 'package:flutter/material.dart';

import '../models/user_profile.dart';

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

  static const blue = Color(0xFF4C9BF0);
  static const blueDeep = Color(0xFF2F6FD1);

  static const rainbowRed = Color(0xFFFF6B6B);
  static const rainbowOrange = Color(0xFFFFA94D);
  static const rainbowYellow = Color(0xFFFFD93D);
  static const rainbowGreen = Color(0xFF6BCB77);
  static const rainbowBlue = Color(0xFF4D96FF);
  static const rainbowPurple = Color(0xFF9B72CF);

  static const rainbow = [
    rainbowRed,
    rainbowOrange,
    rainbowYellow,
    rainbowGreen,
    rainbowBlue,
    rainbowPurple,
  ];
}

/// Maps a user's chosen gender to the app's "aesthetic" accent — pink for
/// female, blue for male, and a rainbow gradient for LGBTQ+. Falls back to
/// the brand pink when no gender is known yet (e.g. before sign-in).
class GenderTheme {
  const GenderTheme._();

  static Color accent(Gender? gender) => switch (gender) {
    Gender.male => AidaColors.blue,
    Gender.lgbtq => AidaColors.rainbowPurple,
    Gender.female || null => AidaColors.pink,
  };

  static List<Color> appBarGradient(Gender? gender, {bool isDark = false}) {
    final colors = switch (gender) {
      Gender.male => [AidaColors.blue, AidaColors.blueDeep],
      Gender.lgbtq => AidaColors.rainbow,
      Gender.female || null => [AidaColors.pink, AidaColors.pinkDeep],
    };
    if (!isDark) return colors;
    return [for (final c in colors) _darken(c)];
  }

  static Color _darken(Color color, [double amount = 0.24]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light([Gender? gender]) => _build(Brightness.light, gender);

  static ThemeData dark([Gender? gender]) => _build(Brightness.dark, gender);

  static ThemeData _build(Brightness brightness, Gender? gender) {
    final isDark = brightness == Brightness.dark;
    final accent = GenderTheme.accent(gender);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      secondary: AidaColors.teal,
      surface: isDark ? AidaColors.surfaceDark : Colors.white,
    ).copyWith(primary: accent, tertiary: AidaColors.navy);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AidaColors.bgDark : AidaColors.bgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
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
          backgroundColor: accent,
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
