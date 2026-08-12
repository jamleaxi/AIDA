class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.createdAt,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final DateTime? createdAt;
  final bool isError;
}
