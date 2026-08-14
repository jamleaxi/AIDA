/// Delivery status for a message the user sent. Always null for AIDA's own
/// messages — only the user's outgoing messages need a save-status indicator.
enum MessageStatus { sending, sent, failed }

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.createdAt,
    this.isError = false,
    this.status,
  });

  final String text;
  final bool isUser;
  final DateTime? createdAt;
  final bool isError;

  /// Mutable so the chat screen can flip sending → sent/failed on the same
  /// object already in the message list, without needing a stable id to
  /// find-and-replace it.
  MessageStatus? status;
}
