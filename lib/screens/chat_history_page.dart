import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation_summary.dart';
import '../services/chat_repository.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({
    super.key,
    required this.chatRepository,
    this.currentConversationId,
  });

  final MessageRepository chatRepository;
  final String? currentConversationId;

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  late Future<List<ConversationSummary>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = widget.chatRepository.fetchConversations();
  }

  void _reload() {
    setState(() {
      _conversationsFuture = widget.chatRepository.fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved chats'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ConversationSummary>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load saved chats.\n${snapshot.error}'),
              ),
            );
          }

          final conversations = snapshot.data ?? const [];
          if (conversations.isEmpty) {
            return const Center(child: Text('No saved chats yet.'));
          }

          final dateFormat = DateFormat('MMM d, y · h:mm a');

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final isCurrent =
                  conversation.conversationId == widget.currentConversationId;
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.chat_bubble : Icons.chat_bubble_outline,
                ),
                title: Text(
                  conversation.preview.isEmpty
                      ? 'New chat'
                      : conversation.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${dateFormat.format(conversation.updatedAt.toLocal())} · '
                  '${conversation.messageCount} message'
                  '${conversation.messageCount == 1 ? '' : 's'}',
                ),
                selected: isCurrent,
                trailing: isCurrent ? const Text('Current') : null,
                onTap: () =>
                    Navigator.of(context).pop(conversation.conversationId),
              );
            },
          );
        },
      ),
    );
  }
}
