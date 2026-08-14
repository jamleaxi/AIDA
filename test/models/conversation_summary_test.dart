import 'package:aida/models/conversation_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores every field it is constructed with', () {
    final updatedAt = DateTime(2026, 8, 14, 10, 30);
    final summary = ConversationSummary(
      conversationId: 'conv-1',
      preview: 'Hello there',
      updatedAt: updatedAt,
      messageCount: 4,
    );

    expect(summary.conversationId, 'conv-1');
    expect(summary.preview, 'Hello there');
    expect(summary.updatedAt, updatedAt);
    expect(summary.messageCount, 4);
  });
}
