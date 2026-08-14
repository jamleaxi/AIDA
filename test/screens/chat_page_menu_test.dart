import 'dart:async';

import 'package:aida/models/chat_message.dart';
import 'package:aida/models/conversation_summary.dart';
import 'package:aida/models/user_profile.dart';
import 'package:aida/screens/chat_page.dart';
import 'package:aida/services/ai_provider_controller.dart';
import 'package:aida/services/ai_service.dart';
import 'package:aida/services/auth_service.dart';
import 'package:aida/services/chat_preferences_controller.dart';
import 'package:aida/services/chat_repository.dart';
import 'package:aida/services/profile_repository.dart';
import 'package:aida/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAiService implements AiService {
  @override
  Future<String> generateReply(String userMessage) async => 'reply';
  @override
  void close() {}
}

class _FakeChatRepository implements MessageRepository {
  Object? saveMessageError;
  Completer<void>? saveGate;

  @override
  Future<void> saveMessage({
    required String conversationId,
    required String sender,
    required String content,
  }) async {
    if (saveGate != null) await saveGate!.future;
    if (saveMessageError != null) throw saveMessageError!;
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async => [];
  @override
  Future<List<ConversationSummary>> fetchConversations() async => [];
}

class _FakeAuthService implements AuthService {
  var signOutCallCount = 0;

  @override
  AppUser? get currentUser =>
      const AppUser(id: 'user-1', email: 'a@example.com');
  @override
  Stream<AppUser?> get userChanges => const Stream.empty();
  @override
  Stream<void> get passwordRecoveryRequested => const Stream.empty();
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> resetPassword({required String email}) async {}
  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> fetchProfile(String userId) async => null;
  @override
  Future<void> saveProfile({
    required String userId,
    required String displayName,
    required Gender gender,
  }) async {}
}

const _profile = UserProfile(
  id: 'user-1',
  displayName: 'Jai',
  gender: Gender.female,
);

class _Harness {
  _Harness()
    : themeController = ThemeController(),
      chatPreferencesController = ChatPreferencesController(),
      authService = _FakeAuthService(),
      chatRepository = _FakeChatRepository();

  final ThemeController themeController;
  final ChatPreferencesController chatPreferencesController;
  final _FakeAuthService authService;
  final _FakeChatRepository chatRepository;

  Widget build() {
    return MaterialApp(
      home: ChatPage(
        aiProviderController: AiProviderController(
          services: {AiProvider.gemini: _FakeAiService()},
          initialProvider: AiProvider.gemini,
        ),
        chatRepository: chatRepository,
        authService: authService,
        profileRepository: _FakeProfileRepository(),
        themeController: themeController,
        chatPreferencesController: chatPreferencesController,
        profile: _profile,
      ),
    );
  }
}

Future<void> _openMenu(WidgetTester tester) async {
  // The menu now has enough items that it can overflow the default 600px
  // test surface, pushing the lowest items (e.g. "Sign out") off-screen.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.tap(find.byKey(const Key('chatMenuButton')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('toggling dark mode flips ThemeController.isDark', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(harness.themeController.isDark, isFalse);

    await _openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('toggleThemeMenuItem')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.themeController.isDark, isTrue);
  });

  testWidgets('toggling "Show timestamps" hides the greeting timestamp', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(harness.chatPreferencesController.showTimestamps, isTrue);

    await _openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('toggleTimestampsMenuItem')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.chatPreferencesController.showTimestamps, isFalse);
  });

  testWidgets('toggling "Show names" hides the AIDA name label', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.text('AIDA'), findsWidgets);

    await _openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('toggleNamesMenuItem')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.chatPreferencesController.showNames, isFalse);
  });

  testWidgets('toggling "Show share button" hides the bubble share action', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);

    await _openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('toggleBubbleActionsMenuItem')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.chatPreferencesController.showBubbleActions, isFalse);
    expect(find.byIcon(Icons.share_rounded), findsNothing);
  });

  group('theme color picker', () {
    testWidgets('selecting Blue sets an accent override matching male', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      expect(harness.themeController.accentOverride, isNull);

      await _openMenu(tester);
      await tester.tap(find.byKey(const Key('themeColorMenuItem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();

      expect(harness.themeController.accentOverride, Gender.male);
    });

    testWidgets('the current choice is checked when reopened', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await tester.tap(find.byKey(const Key('themeColorMenuItem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rainbow'));
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await tester.tap(find.byKey(const Key('themeColorMenuItem')));
      await tester.pumpAndSettle();

      final rainbowTile = find.ancestor(
        of: find.text('Rainbow'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: rainbowTile, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('choosing Auto clears the override', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await harness.themeController.setAccentOverride(Gender.male);

      await _openMenu(tester);
      await tester.tap(find.byKey(const Key('themeColorMenuItem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto (match gender)'));
      await tester.pumpAndSettle();

      expect(harness.themeController.accentOverride, isNull);
    });
  });

  group('text size picker', () {
    testWidgets(
      'selecting Large sets the text scale and is checked when reopened',
      (tester) async {
        final harness = _Harness();
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        expect(harness.chatPreferencesController.textScale, 1.0);

        await _openMenu(tester);
        await tester.tap(find.byKey(const Key('textSizeMenuItem')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Large'));
        await tester.pumpAndSettle();

        expect(harness.chatPreferencesController.textScale, 1.15);

        await _openMenu(tester);
        await tester.tap(find.byKey(const Key('textSizeMenuItem')));
        await tester.pumpAndSettle();

        final largeTile = find.ancestor(
          of: find.text('Large'),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(of: largeTile, matching: find.byIcon(Icons.check)),
          findsOneWidget,
        );
      },
    );

    testWidgets('scales the rendered message text', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('messageField')), 'Hello');
      await tester.tap(find.byKey(const Key('sendButton')));
      await tester.pumpAndSettle();

      final beforeSize = tester.getSize(find.text('Hello'));

      await _openMenu(tester);
      await tester.tap(find.byKey(const Key('textSizeMenuItem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extra large'));
      await tester.pumpAndSettle();

      final afterSize = tester.getSize(find.text('Hello'));
      expect(afterSize.height, greaterThan(beforeSize.height));
    });
  });

  group('message status indicator', () {
    testWidgets(
      'shows sending, then sent, for a message that saves successfully',
      (tester) async {
        final harness = _Harness();
        harness.chatRepository.saveGate = Completer<void>();
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('messageField')), 'Hello');
        await tester.tap(find.byKey(const Key('sendButton')));
        await tester.pump();

        expect(find.byKey(const Key('messageStatusSending')), findsOneWidget);

        harness.chatRepository.saveGate!.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('messageStatusSending')), findsNothing);
        expect(find.byKey(const Key('messageStatusSent')), findsOneWidget);
      },
    );

    testWidgets('shows a failed indicator when saving the message errors', (
      tester,
    ) async {
      final harness = _Harness();
      harness.chatRepository.saveMessageError = Exception('offline');
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('messageField')), 'Hello');
      await tester.tap(find.byKey(const Key('sendButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('messageStatusFailed')), findsOneWidget);
    });

    testWidgets('AIDA\'s own messages never show a status indicator', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('messageField')), 'Hello');
      await tester.tap(find.byKey(const Key('sendButton')));
      await tester.pumpAndSettle();

      // Exactly one status icon: the user's own message. AIDA's reply has none.
      expect(find.byKey(const Key('messageStatusSent')), findsOneWidget);
    });
  });

  testWidgets('starting a new chat resets the conversation after confirming', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('messageField')), 'Hello');
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearChatButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start new chat'));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsNothing);
    expect(find.textContaining('Hello, Jai!'), findsOneWidget);
  });

  testWidgets('canceling the new-chat dialog keeps the conversation', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('messageField')), 'Hello');
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clearChatButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('signing out calls AuthService.signOut', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    await _openMenu(tester);
    await tester.tap(find.byKey(const Key('signOutMenuItem')));
    await tester.pumpAndSettle();

    expect(harness.authService.signOutCallCount, 1);
  });
}
