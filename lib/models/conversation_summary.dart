class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.preview,
    required this.updatedAt,
    required this.messageCount,
  });

  final String conversationId;
  final String preview;
  final DateTime updatedAt;
  final int messageCount;
}
