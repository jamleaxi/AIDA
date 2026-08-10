import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/conversation_summary.dart';

abstract interface class MessageRepository {
  Future<void> saveMessage({
    required String conversationId,
    required String sender,
    required String content,
  });

  Future<List<ChatMessage>> fetchMessages(String conversationId);

  Future<List<ConversationSummary>> fetchConversations();
}

class ChatRepository implements MessageRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> saveMessage({
    required String conversationId,
    required String sender,
    required String content,
  }) async {
    final normalizedSender = sender.trim();
    final normalizedContent = content.trim();
    if (normalizedSender.isEmpty || normalizedContent.isEmpty) return;

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender': normalizedSender,
      'content': normalizedContent,
    });
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select('sender, content, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at');

    final messages = (rows as List)
        .map((row) => row as Map<String, dynamic>)
        .map(
          (row) => ChatMessage(
            text: row['content'] as String? ?? '',
            isUser: row['sender'] == 'user',
            createdAt: _parseTimestamp(row['created_at']),
          ),
        )
        .toList();

    return _fixSwappedPairs(messages);
  }

  // Messages always alternate user -> assistant. Older rows saved before a
  // race-condition fix can have an assistant reply timestamped just before
  // its own user message; swap those adjacent pairs back into order.
  List<ChatMessage> _fixSwappedPairs(List<ChatMessage> messages) {
    final result = List<ChatMessage>.from(messages);
    for (var i = 0; i < result.length - 1; i++) {
      if (!result[i].isUser && result[i + 1].isUser) {
        final swapped = result[i];
        result[i] = result[i + 1];
        result[i + 1] = swapped;
      }
    }
    return result;
  }

  @override
  Future<List<ConversationSummary>> fetchConversations() async {
    final rows = await _client
        .from('messages')
        .select('conversation_id, sender, content, created_at')
        .order('created_at');

    final byConversation = <String, List<Map<String, dynamic>>>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final conversationId = map['conversation_id'] as String?;
      if (conversationId == null) continue;
      byConversation.putIfAbsent(conversationId, () => []).add(map);
    }

    final summaries = byConversation.entries.map((entry) {
      final messages = entry.value;
      final last = messages.last;
      final firstUserMessage = messages.firstWhere(
        (m) => m['sender'] == 'user',
        orElse: () => last,
      );
      return ConversationSummary(
        conversationId: entry.key,
        preview: (firstUserMessage['content'] as String? ?? '').trim(),
        updatedAt: _parseTimestamp(last['created_at']) ?? DateTime.now(),
        messageCount: messages.length,
      );
    }).toList();

    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  DateTime? _parseTimestamp(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
