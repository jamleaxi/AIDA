import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/ai_provider_controller.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/chat_prefs.dart';
import '../services/chat_repository.dart';
import 'chat_history_page.dart';

const _uuid = Uuid();

const _greeting = ChatMessage(
  text: 'Hello! I am AIDA. What would you like to learn today?',
  isUser: false,
);

enum _StartupChoice { continueChat, newChat }

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.aiProviderController,
    required this.chatRepository,
    required this.chatPrefs,
    required this.authService,
    required this.userId,
  });

  final AiProviderController aiProviderController;
  final MessageRepository chatRepository;
  final ChatPrefs chatPrefs;
  final AuthService authService;
  final String userId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = const [];
  String? _conversationId;
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    widget.aiProviderController.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    widget.aiProviderController.removeListener(_onProviderChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final lastConversationId = await widget.chatPrefs.getLastConversationId(
      widget.userId,
    );

    if (!mounted) return;

    if (lastConversationId == null) {
      await _startNewConversation();
      return;
    }

    final choice = await showDialog<_StartupChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome back'),
        content: const Text(
          'Would you like to continue your last chat or start a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_StartupChoice.newChat),
            child: const Text('New chat'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_StartupChoice.continueChat),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (choice == _StartupChoice.continueChat) {
      await _loadConversation(lastConversationId);
    } else {
      await _startNewConversation();
    }
  }

  Future<void> _startNewConversation() async {
    final conversationId = _uuid.v4();
    await widget.chatPrefs.setLastConversationId(widget.userId, conversationId);

    if (!mounted) return;
    setState(() {
      _conversationId = conversationId;
      _messages = [_greeting];
      _isInitializing = false;
    });
  }

  Future<void> _loadConversation(String conversationId) async {
    setState(() => _isInitializing = true);

    List<ChatMessage> messages;
    try {
      final fetched = await widget.chatRepository.fetchMessages(
        conversationId,
      );
      messages = fetched.isEmpty ? [_greeting] : fetched;
    } catch (error, stackTrace) {
      debugPrint('Could not load conversation $conversationId: $error\n$stackTrace');
      messages = [_greeting];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that chat.')),
        );
      }
    }

    await widget.chatPrefs.setLastConversationId(widget.userId, conversationId);

    if (!mounted) return;
    setState(() {
      _conversationId = conversationId;
      _messages = messages;
      _isInitializing = false;
    });
    _scrollToBottom();
  }

  Future<void> _confirmNewChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new chat?'),
        content: const Text(
          'Your current conversation is saved and you can revisit it from Saved chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start new chat'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _startNewConversation();
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.authService.signOut();
    } catch (error, stackTrace) {
      debugPrint('Sign out failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Future<void> _openHistory() async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => ChatHistoryPage(
          chatRepository: widget.chatRepository,
          currentConversationId: _conversationId,
        ),
      ),
    );

    if (selectedId != null && selectedId != _conversationId) {
      await _loadConversation(selectedId);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final conversationId = _conversationId;
    if (text.isEmpty || _isLoading || conversationId == null) return;

    setState(() {
      _messages = [..._messages, ChatMessage(text: text, isUser: true)];
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    // Message history is best-effort and must not delay the AI response,
    // but the assistant's save must wait for this one so rows land in order.
    final saveUserMessage = _saveMessage(
      conversationId: conversationId,
      sender: 'user',
      content: text,
    );
    unawaited(saveUserMessage);

    try {
      final reply = await widget.aiProviderController.activeService
          .generateReply(text);

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ChatMessage(text: reply, isUser: false)];
      });

      await saveUserMessage;
      unawaited(
        _saveMessage(
          conversationId: conversationId,
          sender: 'assistant',
          content: reply,
        ),
      );
    } on AiServiceException catch (error, stackTrace) {
      debugPrint('AI request failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(text: error.userMessage, isUser: false),
        ];
      });
    } catch (error, stackTrace) {
      debugPrint('Unexpected chat error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          const ChatMessage(
            text: 'Sorry, something went wrong. Please try again.',
            isUser: false,
          ),
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _saveMessage({
    required String conversationId,
    required String sender,
    required String content,
  }) async {
    try {
      await widget.chatRepository.saveMessage(
        conversationId: conversationId,
        sender: sender,
        content: content,
      );
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
      appBar: AppBar(
        title: const Text('AIDA'),
        centerTitle: true,
        actions: [
          _ProviderMenuButton(controller: widget.aiProviderController),
          IconButton(
            key: const Key('historyButton'),
            onPressed: _isInitializing ? null : _openHistory,
            tooltip: 'Saved chats',
            icon: const Icon(Icons.history),
          ),
          IconButton(
            key: const Key('clearChatButton'),
            onPressed: _isInitializing ? null : _confirmNewChat,
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            key: const Key('signOutButton'),
            onPressed: _signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : Column(
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

class _ProviderMenuButton extends StatelessWidget {
  const _ProviderMenuButton({required this.controller});

  final AiProviderController controller;

  @override
  Widget build(BuildContext context) {
    final availableProviders = controller.availableProviders;

    return PopupMenuButton<AiProvider>(
      key: const Key('providerMenuButton'),
      tooltip: 'AI provider',
      initialValue: controller.current,
      onSelected: controller.select,
      itemBuilder: (context) => [
        for (final provider in availableProviders)
          CheckedPopupMenuItem<AiProvider>(
            value: provider,
            checked: provider == controller.current,
            child: Text(provider.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 20),
            const SizedBox(width: 6),
            Text(controller.current.label),
            if (availableProviders.length > 1)
              const Icon(Icons.arrow_drop_down, size: 20),
          ],
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
