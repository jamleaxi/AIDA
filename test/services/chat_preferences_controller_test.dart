import 'package:aida/services/chat_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults every preference to shown, at normal text size', () {
    final controller = ChatPreferencesController();

    expect(controller.showTimestamps, isTrue);
    expect(controller.showNames, isTrue);
    expect(controller.showBubbleActions, isTrue);
    expect(controller.textScale, 1.0);
  });

  test('setShowTimestamps updates, notifies, and persists', () async {
    final controller = ChatPreferencesController();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setShowTimestamps(false);

    expect(controller.showTimestamps, isFalse);
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_timestamps'), isFalse);
  });

  test('setShowNames updates, notifies, and persists', () async {
    final controller = ChatPreferencesController();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setShowNames(false);

    expect(controller.showNames, isFalse);
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_names'), isFalse);
  });

  test('setShowBubbleActions updates, notifies, and persists', () async {
    final controller = ChatPreferencesController();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setShowBubbleActions(false);

    expect(controller.showBubbleActions, isFalse);
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('show_bubble_actions'), isFalse);
  });

  test('setTextScale updates, notifies, and persists', () async {
    final controller = ChatPreferencesController();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setTextScale(1.3);

    expect(controller.textScale, 1.3);
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('text_scale'), 1.3);
  });

  test('load restores previously persisted preferences', () async {
    SharedPreferences.setMockInitialValues({
      'show_timestamps': false,
      'show_names': false,
      'show_bubble_actions': false,
      'text_scale': 0.85,
    });

    final controller = ChatPreferencesController();
    await controller.load();

    expect(controller.showTimestamps, isFalse);
    expect(controller.showNames, isFalse);
    expect(controller.showBubbleActions, isFalse);
    expect(controller.textScale, 0.85);
  });

  test('load defaults to shown/1.0 for preferences never persisted', () async {
    final controller = ChatPreferencesController();

    await controller.load();

    expect(controller.showTimestamps, isTrue);
    expect(controller.showNames, isTrue);
    expect(controller.showBubbleActions, isTrue);
    expect(controller.textScale, 1.0);
  });
}
