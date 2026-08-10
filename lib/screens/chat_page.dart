import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/chat_repository.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.aiService,
    required this.chatRepository,
  });

  final AiService aiService;
  final MessageRepository chatRepository;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessage> _messages = const [
    ChatMessage(
      text: 'Hello! I am AIDA. What would you like to learn today?',
      isUser: false,
    ),
  ].toList();

  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    // Message history is best-effort and must not delay the AI response.
    unawaited(_saveMessage(sender: 'user', content: text));

    try {
      final reply = await widget.aiService.generateReply(text);

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });

      unawaited(_saveMessage(sender: 'assistant', content: reply));
    } on AiServiceException catch (error, stackTrace) {
      debugPrint('AI request failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: error.userMessage, isUser: false));
      });
    } catch (error, stackTrace) {
      debugPrint('Unexpected chat error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages.add(
          const ChatMessage(
            text: 'Sorry, something went wrong. Please try again.',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _saveMessage({
    required String sender,
    required String content,
  }) async {
    try {
      await widget.chatRepository.saveMessage(sender: sender, content: content);
    } catch (error, stackTrace) {
      // Saving history should not prevent the user from receiving an AI reply.
      debugPrint('Could not save $sender message: $error\n$stackTrace');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIDA'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                key: const Key('messageList'),
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(),
              ),
            _MessageComposer(
              controller: _controller,
              isLoading: _isLoading,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.35,
    );

    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: 0.82,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: message.isUser
              ? Text(message.text, style: textStyle)
              : MarkdownBody(
            data: message.text,
            selectable: true,
            softLineBreak: true,
            imageBuilder: (uri, title, alt) => Text(
              alt?.isNotEmpty == true ? alt! : 'Image',
              style: textStyle?.copyWith(fontStyle: FontStyle.italic),
            ),
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: textStyle,
              pPadding: EdgeInsets.zero,
              strong: textStyle?.copyWith(fontWeight: FontWeight.bold),
              em: textStyle?.copyWith(fontStyle: FontStyle.italic),
              blockSpacing: 10,
              listIndent: 20,
              code: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
                backgroundColor: theme.colorScheme.surfaceContainer,
              ),
              codeblockPadding: const EdgeInsets.all(10),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              blockquotePadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              blockquoteDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('messageField'),
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !isLoading,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const Key('sendButton'),
            onPressed: isLoading ? null : onSend,
            tooltip: 'Send message',
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}