import 'package:shared_preferences/shared_preferences.dart';

class ChatPrefs {
  static const _lastConversationIdKey = 'last_conversation_id';

  Future<String?> getLastConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConversationIdKey);
  }

  Future<void> setLastConversationId(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastConversationIdKey, conversationId);
  }
}
