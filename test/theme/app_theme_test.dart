import 'package:aida/models/user_profile.dart';
import 'package:aida/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenderTheme.accent', () {
    test('maps female and null to brand pink', () {
      expect(GenderTheme.accent(Gender.female), AidaColors.pink);
      expect(GenderTheme.accent(null), AidaColors.pink);
    });

    test('maps male to blue', () {
      expect(GenderTheme.accent(Gender.male), AidaColors.blue);
    });

    test('maps lgbtq to the rainbow accent purple', () {
      expect(GenderTheme.accent(Gender.lgbtq), AidaColors.rainbowPurple);
    });
  });

  group('GenderTheme.appBarGradient', () {
    test('female and male each resolve to a two-color gradient', () {
      expect(GenderTheme.appBarGradient(Gender.female), [
        AidaColors.pink,
        AidaColors.pinkDeep,
      ]);
      expect(GenderTheme.appBarGradient(Gender.male), [
        AidaColors.blue,
        AidaColors.blueDeep,
      ]);
    });

    test('lgbtq resolves to the full rainbow', () {
      expect(GenderTheme.appBarGradient(Gender.lgbtq), AidaColors.rainbow);
    });

    test('dark mode darkens every color but keeps the same count', () {
      for (final gender in [null, Gender.female, Gender.male, Gender.lgbtq]) {
        final light = GenderTheme.appBarGradient(gender);
        final dark = GenderTheme.appBarGradient(gender, isDark: true);

        expect(dark.length, light.length);
        for (var i = 0; i < light.length; i++) {
          final lightLightness = HSLColor.fromColor(light[i]).lightness;
          final darkLightness = HSLColor.fromColor(dark[i]).lightness;
          expect(
            darkLightness,
            lessThan(lightLightness),
            reason: 'color $i should be darker in dark mode',
          );
        }
      }
    });

    test('darkening never drops lightness below zero', () {
      // rainbowYellow is already fairly light; guards against clamp bugs if
      // the darken amount is ever increased.
      final dark = GenderTheme.appBarGradient(Gender.lgbtq, isDark: true);
      for (final color in dark) {
        expect(HSLColor.fromColor(color).lightness, greaterThanOrEqualTo(0));
      }
    });
  });

  group('AppTheme', () {
    test('light() and dark() set the matching brightness', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('colorScheme.primary follows the gender accent', () {
      expect(AppTheme.light(Gender.male).colorScheme.primary, AidaColors.blue);
      expect(
        AppTheme.dark(Gender.lgbtq).colorScheme.primary,
        AidaColors.rainbowPurple,
      );
    });

    test('scaffold background differs between light and dark', () {
      expect(AppTheme.light().scaffoldBackgroundColor, AidaColors.bgLight);
      expect(AppTheme.dark().scaffoldBackgroundColor, AidaColors.bgDark);
    });

    test('app bar background matches the accent color', () {
      expect(
        AppTheme.light(Gender.female).appBarTheme.backgroundColor,
        AidaColors.pink,
      );
    });

    test('defaults to the pink accent with no gender', () {
      expect(AppTheme.light().colorScheme.primary, AidaColors.pink);
    });
  });
}
