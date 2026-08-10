import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class MessageRepository {
  Future<void> saveMessage({required String sender, required String content});
}

class ChatRepository implements MessageRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> saveMessage({
    required String sender,
    required String content,
  }) async {
    final normalizedSender = sender.trim();
    final normalizedContent = content.trim();
    if (normalizedSender.isEmpty || normalizedContent.isEmpty) return;

    await _client.from('messages').insert({
      'sender': normalizedSender,
      'content': normalizedContent,
    });
  }
}