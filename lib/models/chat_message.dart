class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.createdAt,
  });

  final String text;
  final bool isUser;
  final DateTime? createdAt;
}
