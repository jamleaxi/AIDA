import 'package:shared_preferences/shared_preferences.dart';

class ChatPrefs {
  static const _lastConversationIdPrefix = 'last_conversation_id_';

  Future<String?> getLastConversationId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(userId));
  }

  Future<void> setLastConversationId(
    String userId,
    String conversationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), conversationId);
  }

  String _key(String userId) => '$_lastConversationIdPrefix$userId';
}
