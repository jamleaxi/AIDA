import 'package:aida/main.dart';
import 'package:aida/services/ai_service.dart';
import 'package:aida/services/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sends a message and displays a reply', (tester) async {
    await tester.pumpWidget(
      AidaApp(
        aiService: _FakeAiService(),
        chatRepository: _FakeRepository(),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('messageField')),
      'Hello',
    );
    await tester.tap(find.byKey(const Key('sendButton')));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Test reply'), findsOneWidget);
  });
}

class _FakeAiService implements AiService {
  @override
  Future<String> generateReply(String userMessage) async => 'Test reply';

  @override
  void close() {}
}

class _FakeRepository implements MessageRepository {
  @override
  Future<void> saveMessage({
    required String sender,
    required String content,
  }) async {}
}