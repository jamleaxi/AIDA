import 'package:aida/services/chat_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults every preference to shown', () {
    final controller = ChatPreferencesController();

    expect(controller.showTimestamps, isTrue);
    expect(controller.showNames, isTrue);
    expect(controller.showBubbleActions, isTrue);
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

  test('load restores previously persisted preferences', () async {
    SharedPreferences.setMockInitialValues({
      'show_timestamps': false,
      'show_names': false,
      'show_bubble_actions': false,
    });

    final controller = ChatPreferencesController();
    await controller.load();

    expect(controller.showTimestamps, isFalse);
    expect(controller.showNames, isFalse);
    expect(controller.showBubbleActions, isFalse);
  });

  test('load defaults to true for preferences never persisted', () async {
    final controller = ChatPreferencesController();

    await controller.load();

    expect(controller.showTimestamps, isTrue);
    expect(controller.showNames, isTrue);
    expect(controller.showBubbleActions, isTrue);
  });
}
