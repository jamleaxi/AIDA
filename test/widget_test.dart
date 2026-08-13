import 'package:aida/main.dart';
import 'package:aida/models/chat_message.dart';
import 'package:aida/models/conversation_summary.dart';
import 'package:aida/services/ai_provider_controller.dart';
import 'package:aida/services/ai_service.dart';
import 'package:aida/services/auth_service.dart';
import 'package:aida/services/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sends a message and displays a reply', (tester) async {
    await tester.pumpWidget(
      AidaApp(
        aiProviderController: AiProviderController(
          services: {AiProvider.gemini: _FakeAiService()},
          initialProvider: AiProvider.gemini,
        ),
        chatRepository: _FakeRepository(),
        authService: _FakeAuthService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('messageField')),
      'Hello',
    );
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Test reply'), findsOneWidget);
  });

  testWidgets('retries a failed message and shows the reply', (tester) async {
    final flakyService = _FlakyAiService();

    await tester.pumpWidget(
      AidaApp(
        aiProviderController: AiProviderController(
          services: {AiProvider.gemini: flakyService},
          initialProvider: AiProvider.gemini,
        ),
        chatRepository: _FakeRepository(),
        authService: _FakeAuthService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('messageField')),
      'Hello',
    );
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();

    expect(find.text('Network error. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Network error. Please try again.'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Recovered reply'), findsOneWidget);
  });
}

class _FakeAiService implements AiService {
  @override
  Future<String> generateReply(String userMessage) async => 'Test reply';

  @override
  void close() {}
}

class _FlakyAiService implements AiService {
  var _callCount = 0;

  @override
  Future<String> generateReply(String userMessage) async {
    _callCount++;
    if (_callCount == 1) {
      throw const AiServiceException('Network error. Please try again.');
    }
    return 'Recovered reply';
  }

  @override
  void close() {}
}

class _FakeRepository implements MessageRepository {
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
  static const _user = AppUser(id: 'test-user', email: 'test@example.com');

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges => Stream.value(_user);

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}
