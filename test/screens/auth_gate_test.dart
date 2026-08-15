import 'dart:async';

import 'package:aida/models/conversation_summary.dart';
import 'package:aida/models/chat_message.dart';
import 'package:aida/models/user_profile.dart';
import 'package:aida/screens/auth_gate.dart';
import 'package:aida/screens/offline_status_page.dart';
import 'package:aida/screens/onboarding_page.dart';
import 'package:aida/screens/reset_password_page.dart';
import 'package:aida/services/ai_provider_controller.dart';
import 'package:aida/services/ai_service.dart';
import 'package:aida/services/auth_service.dart';
import 'package:aida/services/chat_preferences_controller.dart';
import 'package:aida/services/chat_repository.dart';
import 'package:aida/services/connectivity_service.dart';
import 'package:aida/services/profile_repository.dart';
import 'package:aida/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({AppUser? initialUser}) : _currentUser = initialUser;

  AppUser? _currentUser;
  final _userController = StreamController<AppUser?>.broadcast();
  final _recoveryController = StreamController<void>.broadcast();

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get userChanges => _userController.stream;

  @override
  Stream<void> get passwordRecoveryRequested => _recoveryController.stream;

  void emitUser(AppUser? user) {
    _currentUser = user;
    _userController.add(user);
  }

  void emitPasswordRecovery() => _recoveryController.add(null);

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
  Future<void> signOut() async {}
}

class _FakeProfileRepository implements ProfileRepository {
  UserProfile? profileToReturn;
  Object? errorToThrow;
  var fetchCallCount = 0;

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    fetchCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn;
  }

  @override
  Future<void> saveProfile({
    required String userId,
    required String displayName,
    required Gender gender,
  }) async {}
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

class _FakeAiService implements AiService {
  @override
  Future<String> generateReply(String userMessage) async => 'reply';
  @override
  void close() {}
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({this.connected = true});

  bool connected;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> hasConnection() async => connected;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool value) {
    connected = value;
    _controller.add(value);
  }
}

Widget _buildAuthGate({
  required _FakeAuthService authService,
  required _FakeProfileRepository profileRepository,
  ConnectivityService? connectivityService,
}) {
  return MaterialApp(
    home: AuthGate(
      authService: authService,
      aiProviderController: AiProviderController(
        services: {AiProvider.gemini: _FakeAiService()},
        initialProvider: AiProvider.gemini,
      ),
      chatRepository: _FakeChatRepository(),
      profileRepository: profileRepository,
      themeController: ThemeController(),
      chatPreferencesController: ChatPreferencesController(),
      connectivityService: connectivityService ?? _FakeConnectivityService(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows AuthPage when signed out', (tester) async {
    final authService = _FakeAuthService();
    final profileRepository = _FakeProfileRepository();

    await tester.pumpWidget(
      _buildAuthGate(
        authService: authService,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
  });

  testWidgets(
    'shows OfflineStatusPage instead of AuthPage when signed out with no connection',
    (tester) async {
      final authService = _FakeAuthService();
      final profileRepository = _FakeProfileRepository();
      final connectivityService = _FakeConnectivityService(connected: false);

      await tester.pumpWidget(
        _buildAuthGate(
          authService: authService,
          profileRepository: profileRepository,
          connectivityService: connectivityService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineStatusPage), findsOneWidget);
      expect(find.text('Sign in to continue'), findsNothing);

      connectivityService.emit(true);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.byType(OfflineStatusPage), findsNothing);
    },
  );

  testWidgets('shows OfflineStatusPage when the profile lookup fails', (
    tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AppUser(id: 'user-1', email: 'a@example.com'),
    );
    final profileRepository = _FakeProfileRepository()
      ..errorToThrow = Exception('no network');

    await tester.pumpWidget(
      _buildAuthGate(
        authService: authService,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OfflineStatusPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(profileRepository.fetchCallCount, 1);
  });

  testWidgets('retrying after an offline error re-fetches the profile', (
    tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AppUser(id: 'user-1', email: 'a@example.com'),
    );
    final profileRepository = _FakeProfileRepository()
      ..errorToThrow = Exception('no network');

    await tester.pumpWidget(
      _buildAuthGate(
        authService: authService,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OfflineStatusPage), findsOneWidget);

    // Simulate the connection coming back before retrying.
    profileRepository.errorToThrow = null;
    profileRepository.profileToReturn = const UserProfile(
      id: 'user-1',
      displayName: 'Jai',
      gender: Gender.female,
    );

    await tester.tap(find.byKey(const Key('offlineRetryButton')));
    await tester.pumpAndSettle();

    expect(profileRepository.fetchCallCount, 2);
    expect(find.byType(OfflineStatusPage), findsNothing);
    expect(find.text('AIDA'), findsWidgets);
  });

  testWidgets('shows OnboardingPage when there is no saved profile', (
    tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AppUser(id: 'user-1', email: 'a@example.com'),
    );
    final profileRepository = _FakeProfileRepository();

    await tester.pumpWidget(
      _buildAuthGate(
        authService: authService,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Welcome to AIDA'), findsOneWidget);
  });

  testWidgets('shows ChatPage once a profile is found', (tester) async {
    final authService = _FakeAuthService(
      initialUser: const AppUser(id: 'user-1', email: 'a@example.com'),
    );
    final profileRepository = _FakeProfileRepository()
      ..profileToReturn = const UserProfile(
        id: 'user-1',
        displayName: 'Jai',
        gender: Gender.male,
      );

    await tester.pumpWidget(
      _buildAuthGate(
        authService: authService,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('messageField')), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets(
    'shows ResetPasswordPage when a password-recovery link is opened, '
    'even while signed in',
    (tester) async {
      final authService = _FakeAuthService(
        initialUser: const AppUser(id: 'user-1', email: 'a@example.com'),
      );
      final profileRepository = _FakeProfileRepository()
        ..profileToReturn = const UserProfile(
          id: 'user-1',
          displayName: 'Jai',
          gender: Gender.male,
        );

      await tester.pumpWidget(
        _buildAuthGate(
          authService: authService,
          profileRepository: profileRepository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordPage), findsNothing);

      authService.emitPasswordRecovery();
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsOneWidget);

      // Completing the reset returns to the normal signed-in flow.
      await tester.enterText(
        find.byKey(const Key('newPasswordField')),
        'newpass1',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordField')),
        'newpass1',
      );
      await tester.tap(find.byKey(const Key('resetPasswordSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsNothing);
      expect(find.byKey(const Key('messageField')), findsOneWidget);
    },
  );
}
