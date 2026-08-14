import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Tracks the user's light/dark preference and accent theme, persisting
/// both locally.
class ThemeController extends ChangeNotifier {
  static const _modePrefsKey = 'theme_mode';
  static const _accentPrefsKey = 'theme_accent_override';

  ThemeMode _mode = ThemeMode.system;
  Gender? _gender;
  Gender? _accentOverride;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  /// The gender-based "aesthetic" accent (pink/blue/rainbow) that defaults
  /// from the signed-in user's profile, or null before a profile has loaded.
  Gender? get gender => _gender;

  /// The user's manual accent choice from the menu, or null to follow
  /// [gender] automatically.
  Gender? get accentOverride => _accentOverride;

  /// The accent actually applied: the manual override if set, otherwise
  /// the profile's gender.
  Gender? get effectiveAccent => _accentOverride ?? _gender;

  /// Updates the gender-based accent theme. Called once the user's profile
  /// loads, and again whenever they change their gender preference.
  void setGender(Gender? gender) {
    if (_gender == gender) return;
    _gender = gender;
    notifyListeners();
  }

  /// Manually overrides the accent theme, ignoring gender. Pass null to
  /// go back to following the profile's gender automatically.
  Future<void> setAccentOverride(Gender? accent) async {
    if (_accentOverride == accent) return;
    _accentOverride = accent;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (accent == null) {
      await prefs.remove(_accentPrefsKey);
    } else {
      await prefs.setString(_accentPrefsKey, accent.value);
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString(_modePrefsKey);
    _mode = switch (storedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _accentOverride = Gender.tryParse(prefs.getString(_accentPrefsKey));
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modePrefsKey, dark ? 'dark' : 'light');
  }
}
