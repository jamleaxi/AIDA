import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks display preferences for the chat screen and persists them locally.
class ChatPreferencesController extends ChangeNotifier {
  static const _showTimestampsKey = 'show_timestamps';
  static const _showNamesKey = 'show_names';
  static const _showBubbleActionsKey = 'show_bubble_actions';
  static const _textScaleKey = 'text_scale';
  static const defaultTextScale = 1.0;

  bool _showTimestamps = true;
  bool _showNames = true;
  bool _showBubbleActions = true;
  double _textScale = defaultTextScale;

  bool get showTimestamps => _showTimestamps;

  bool get showNames => _showNames;

  bool get showBubbleActions => _showBubbleActions;

  /// Multiplier applied to chat message text (bubbles, names, timestamps).
  double get textScale => _textScale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _showTimestamps = prefs.getBool(_showTimestampsKey) ?? true;
    _showNames = prefs.getBool(_showNamesKey) ?? true;
    _showBubbleActions = prefs.getBool(_showBubbleActionsKey) ?? true;
    _textScale = prefs.getDouble(_textScaleKey) ?? defaultTextScale;
    notifyListeners();
  }

  Future<void> setShowTimestamps(bool value) async {
    _showTimestamps = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTimestampsKey, value);
  }

  Future<void> setShowNames(bool value) async {
    _showNames = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showNamesKey, value);
  }

  Future<void> setShowBubbleActions(bool value) async {
    _showBubbleActions = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showBubbleActionsKey, value);
  }

  Future<void> setTextScale(double value) async {
    _textScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, value);
  }
}
