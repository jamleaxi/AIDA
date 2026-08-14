import 'package:aida/models/user_profile.dart';
import 'package:aida/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeController defaults', () {
    test('starts in system mode with no gender or override', () {
      final controller = ThemeController();

      expect(controller.mode, ThemeMode.system);
      expect(controller.isDark, isFalse);
      expect(controller.gender, isNull);
      expect(controller.accentOverride, isNull);
      expect(controller.effectiveAccent, isNull);
    });
  });

  group('setDark', () {
    test('updates mode, notifies, and persists', () async {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setDark(true);
      expect(controller.mode, ThemeMode.dark);
      expect(controller.isDark, isTrue);
      expect(notified, 1);

      await controller.setDark(false);
      expect(controller.mode, ThemeMode.light);
      expect(controller.isDark, isFalse);
      expect(notified, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });

  group('setGender', () {
    test('updates the profile-driven accent and notifies', () {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setGender(Gender.male);

      expect(controller.gender, Gender.male);
      expect(controller.effectiveAccent, Gender.male);
      expect(notified, 1);
    });

    test('is a no-op when the gender has not changed', () {
      final controller = ThemeController()..setGender(Gender.female);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setGender(Gender.female);

      expect(notified, 0);
    });
  });

  group('setAccentOverride', () {
    test('takes priority over gender in effectiveAccent', () async {
      final controller = ThemeController()..setGender(Gender.male);

      await controller.setAccentOverride(Gender.lgbtq);

      expect(controller.accentOverride, Gender.lgbtq);
      expect(controller.gender, Gender.male);
      expect(controller.effectiveAccent, Gender.lgbtq);
    });

    test('clearing the override falls back to gender', () async {
      final controller = ThemeController()..setGender(Gender.female);
      await controller.setAccentOverride(Gender.male);

      await controller.setAccentOverride(null);

      expect(controller.accentOverride, isNull);
      expect(controller.effectiveAccent, Gender.female);
    });

    test('persists the override and notifies', () async {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setAccentOverride(Gender.lgbtq);
      expect(notified, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_accent_override'), 'lgbtq+');

      await controller.setAccentOverride(null);
      final prefsAfterClear = await SharedPreferences.getInstance();
      expect(prefsAfterClear.getString('theme_accent_override'), isNull);
    });

    test('is a no-op when the override has not changed', () async {
      final controller = ThemeController();
      await controller.setAccentOverride(Gender.male);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setAccentOverride(Gender.male);

      expect(notified, 0);
    });
  });

  group('load', () {
    test('restores a previously persisted mode and accent override', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'theme_accent_override': 'male',
      });

      final controller = ThemeController();
      await controller.load();

      expect(controller.mode, ThemeMode.dark);
      expect(controller.accentOverride, Gender.male);
    });

    test(
      'falls back to system mode for an unrecognized stored value',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': 'garbage'});

        final controller = ThemeController();
        await controller.load();

        expect(controller.mode, ThemeMode.system);
      },
    );

    test('notifies listeners once loading completes', () async {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.load();

      expect(notified, 1);
    });
  });
}
