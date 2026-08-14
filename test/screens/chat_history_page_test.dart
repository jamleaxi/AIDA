import 'package:aida/models/chat_message.dart';
import 'package:aida/models/conversation_summary.dart';
import 'package:aida/screens/chat_history_page.dart';
import 'package:aida/services/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatRepository implements MessageRepository {
  List<ConversationSummary> conversations = const [];
  Object? fetchConversationsError;
  var fetchConversationsCallCount = 0;

  @override
  Future<void> saveMessage({
    required String conversationId,
    required String sender,
    required String content,
  }) async {}

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async => [];

  @override
  Future<List<ConversationSummary>> fetchConversations() async {
    fetchConversationsCallCount++;
    if (fetchConversationsError != null) throw fetchConversationsError!;
    return conversations;
  }
}

Future<String?> _pump(
  WidgetTester tester,
  _FakeChatRepository repository, {
  String? currentConversationId,
}) async {
  String? popped;
  await tester.pumpWidget(
    MaterialApp(
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (context) => ChatHistoryPage(
                    chatRepository: repository,
                    currentConversationId: currentConversationId,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  testWidgets('shows an illustrated empty state with no saved chats', (
    tester,
  ) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository);

    expect(find.text('No saved chats yet.'), findsOneWidget);
    expect(
      find.text('Conversations you have with AIDA will show up here.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
  });

  testWidgets('shows an error state when loading fails', (tester) async {
    final repository = _FakeChatRepository()
      ..fetchConversationsError = Exception('network down');
    await _pump(tester, repository);

    expect(find.textContaining('Could not load saved chats.'), findsOneWidget);
  });

  testWidgets('lists conversations with preview and message count', (
    tester,
  ) async {
    final repository = _FakeChatRepository()
      ..conversations = [
        ConversationSummary(
          conversationId: 'conv-1',
          preview: 'Hello there',
          updatedAt: DateTime.utc(2026, 8, 14, 10, 0),
          messageCount: 3,
        ),
        ConversationSummary(
          conversationId: 'conv-2',
          preview: '',
          updatedAt: DateTime.utc(2026, 8, 13, 10, 0),
          messageCount: 1,
        ),
      ];
    await _pump(tester, repository, currentConversationId: 'conv-1');

    expect(find.text('Hello there'), findsOneWidget);
    // Falls back to "New chat" when the preview is empty.
    expect(find.text('New chat'), findsOneWidget);
    expect(find.textContaining('3 messages'), findsOneWidget);
    expect(find.textContaining('1 message'), findsOneWidget);
    // The active conversation is labeled.
    expect(find.text('Current'), findsOneWidget);
  });

  testWidgets('tapping a conversation pops with its id', (tester) async {
    final repository = _FakeChatRepository()
      ..conversations = [
        ConversationSummary(
          conversationId: 'conv-1',
          preview: 'Hello there',
          updatedAt: DateTime.utc(2026, 8, 14, 10, 0),
          messageCount: 3,
        ),
      ];

    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) =>
                        ChatHistoryPage(chatRepository: repository),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hello there'));
    await tester.pumpAndSettle();

    expect(result, 'conv-1');
  });

  testWidgets('refresh reloads the conversation list', (tester) async {
    final repository = _FakeChatRepository();
    await _pump(tester, repository);

    expect(repository.fetchConversationsCallCount, 1);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.fetchConversationsCallCount, 2);
  });

  testWidgets('long-pressing enters selection mode with the item checked', (
    tester,
  ) async {
    final repository = _FakeChatRepository()
      ..conversations = [
        ConversationSummary(
          conversationId: 'conv-1',
          preview: 'Hello there',
          updatedAt: DateTime.utc(2026, 8, 14, 10, 0),
          messageCount: 1,
        ),
        ConversationSummary(
          conversationId: 'conv-2',
          preview: 'Second chat',
          updatedAt: DateTime.utc(2026, 8, 13, 10, 0),
          messageCount: 1,
        ),
      ];
    await _pump(tester, repository);

    await tester.longPress(find.text('Hello there'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    // Tapping a second item selects it too.
    await tester.tap(find.text('Second chat'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    // Canceling exits selection mode.
    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.text('Saved chats'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('the download menu offers "select" mode without exporting', (
    tester,
  ) async {
    final repository = _FakeChatRepository()
      ..conversations = [
        ConversationSummary(
          conversationId: 'conv-1',
          preview: 'Hello there',
          updatedAt: DateTime.utc(2026, 8, 14, 10, 0),
          messageCount: 1,
        ),
      ];
    await _pump(tester, repository);

    await tester.tap(find.byTooltip('Download saved chats'));
    await tester.pumpAndSettle();
    expect(find.text('Select chats to download'), findsOneWidget);

    await tester.tap(find.text('Select chats to download'));
    await tester.pumpAndSettle();

    // Entered selection mode without touching the export/share pipeline.
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
