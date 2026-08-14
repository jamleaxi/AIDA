// End-to-end tests that exercise the real app on a device/emulator, as
// opposed to the widget tests in test/ which run against the fake
// TestWidgetsFlutterBinding. This runs the real rendering pipeline, real
// gesture dispatch, and — critically — the real shared_preferences plugin
// instead of its mocked channel, so it also catches platform-channel issues
// widget tests can't see.
//
// Run with an emulator/device attached:
//   flutter test integration_test/app_test.dart -d <deviceId>
//
// Backend calls are avoided by injecting fakes into AidaApp, the same way
// test/widget_test.dart does — this test targets the UI and platform
// integration, not the Supabase project.
import 'package:aida/main.dart';
import 'package:aida/models/chat_message.dart';
import 'package:aida/models/conversation_summary.dart';
import 'package:aida/models/user_profile.dart';
import 'package:aida/services/ai_provider_controller.dart';
import 'package:aida/services/ai_service.dart';
import 'package:aida/services/auth_service.dart';
import 'package:aida/services/chat_repository.dart';
import 'package:aida/services/profile_repository.dart';
import 'package:aida/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _FakeAiService implements AiService {
  @override
  Future<String> generateReply(String userMessage) async =>
      'Hello from the integration test!';

  @override
  void close() {}
}

class _FakeChatRepository implements MessageRepository {
  @override
  Future<void> saveMessage({
    required String conversationId,
    required String sender,
    required String content,
  }) async {}

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async => [];

  @override
  Future<List<ConversationSummary>> fetchConversations() async => [];
}

class _FakeAuthService implements AuthService {
  static const _user = AppUser(
    id: 'integration-user',
    email: 'test@example.com',
  );

  var signOutCallCount = 0;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges => Stream.value(_user);

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
  UserProfile? profile = const UserProfile(
    id: 'integration-user',
    displayName: 'Integration Tester',
    gender: Gender.female,
  );

  @override
  Future<UserProfile?> fetchProfile(String userId) async => profile;

  @override
  Future<void> saveProfile({
    required String userId,
    required String displayName,
    required Gender gender,
  }) async {
    profile = UserProfile(id: userId, displayName: displayName, gender: gender);
  }
}

Widget _buildApp() {
  return AidaApp(
    aiProviderController: AiProviderController(
      services: {AiProvider.gemini: _FakeAiService()},
      initialProvider: AiProvider.gemini,
    ),
    chatRepository: _FakeChatRepository(),
    authService: _FakeAuthService(),
    profileRepository: _FakeProfileRepository(),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sends a message and displays the reply on a real device', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('messageField')), 'Hello AIDA');
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();

    expect(find.text('Hello AIDA'), findsOneWidget);
    expect(find.text('Hello from the integration test!'), findsOneWidget);
  });

  testWidgets(
    'dark mode toggle persists through the real shared_preferences plugin',
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chatMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('toggleThemeMenuItem')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );

      // A brand-new controller reads the real, on-device SharedPreferences
      // value written above — not a mocked channel like the widget tests use.
      final reloaded = ThemeController();
      await reloaded.load();
      expect(reloaded.isDark, isTrue);
    },
  );
}
