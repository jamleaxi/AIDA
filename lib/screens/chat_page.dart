import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/user_profile.dart';
import '../services/ai_provider_controller.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/chat_preferences_controller.dart';
import '../services/chat_repository.dart';
import '../services/profile_repository.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../utils/philippine_time.dart';
import 'chat_history_page.dart';
import 'edit_gender_page.dart';
import 'edit_name_page.dart';

const _uuid = Uuid();

const _botAvatarAsset = 'lib/assets/aida.png';

final _timestampFormat = DateFormat('MMM d, y • hh:mm a');

extension _GenderAvatar on Gender {
  String get avatarAsset => switch (this) {
    Gender.male => 'lib/assets/male.png',
    Gender.female => 'lib/assets/female.png',
    Gender.lgbtq => 'lib/assets/lgbtq.png',
  };
}

extension _ProviderIcon on AiProvider {
  IconData get menuIcon => switch (this) {
    AiProvider.gemini => Icons.auto_awesome,
    AiProvider.groq => Icons.bolt,
  };

  Color get menuIconColor => switch (this) {
    AiProvider.gemini => const Color(0xFF8B5CF6),
    AiProvider.groq => const Color(0xFFF97316),
  };
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.aiProviderController,
    required this.chatRepository,
    required this.authService,
    required this.profileRepository,
    required this.themeController,
    required this.chatPreferencesController,
    required this.profile,
  });

  final AiProviderController aiProviderController;
  final MessageRepository chatRepository;
  final AuthService authService;
  final ProfileRepository profileRepository;
  final ThemeController themeController;
  final ChatPreferencesController chatPreferencesController;
  final UserProfile profile;

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
  late UserProfile _profile = widget.profile;

  @override
  void initState() {
    super.initState();
    widget.aiProviderController.addListener(_onProviderChanged);
    widget.themeController.addListener(_onProviderChanged);
    widget.chatPreferencesController.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _startNewConversation(),
    );
  }

  @override
  void dispose() {
    widget.aiProviderController.removeListener(_onProviderChanged);
    widget.themeController.removeListener(_onProviderChanged);
    widget.chatPreferencesController.removeListener(_onProviderChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  ChatMessage get _greeting => ChatMessage(
    text:
        'Hello, ${_profile.displayName}! I am AIDA. What\'s on your mind today?',
    isUser: false,
    createdAt: DateTime.now(),
  );

  void _startNewConversation() {
    setState(() {
      _conversationId = _uuid.v4();
      _messages = [_greeting];
      _isInitializing = false;
    });
  }

  Future<void> _loadConversation(String conversationId) async {
    setState(() => _isInitializing = true);

    List<ChatMessage> messages;
    try {
      final fetched = await widget.chatRepository.fetchMessages(conversationId);
      messages = fetched.isEmpty ? [_greeting] : fetched;
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load conversation $conversationId: $error\n$stackTrace',
      );
      messages = [_greeting];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that chat.')),
        );
      }
    }

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
      _startNewConversation();
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

  Future<void> _changeName() async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (context) => EditNamePage(
          profile: _profile,
          profileRepository: widget.profileRepository,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  Future<void> _changeGender() async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (context) => EditGenderPage(
          profile: _profile,
          profileRepository: widget.profileRepository,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
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

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'AIDA',
      applicationVersion: '1.0.0',
      applicationIcon: ClipOval(
        child: Image.asset(_botAvatarAsset, width: 48, height: 48, fit: BoxFit.cover),
      ),
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'AIDA is your AI Digital Assistant, here to chat and help '
            'with whatever is on your mind.',
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final conversationId = _conversationId;
    if (text.isEmpty || _isLoading || conversationId == null) return;

    setState(() {
      _messages = [
        ..._messages,
        ChatMessage(text: text, isUser: true, createdAt: DateTime.now()),
      ];
      _controller.clear();
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

    await _requestReply(
      text: text,
      conversationId: conversationId,
      pendingUserSave: saveUserMessage,
    );
  }

  Future<void> _retryMessage(int index) async {
    final conversationId = _conversationId;
    if (conversationId == null || _isLoading) return;
    if (index <= 0 || index >= _messages.length) return;
    if (!_messages[index].isError) return;

    final userMessage = _messages[index - 1];
    if (!userMessage.isUser) return;

    setState(() {
      _messages = List<ChatMessage>.from(_messages)..removeAt(index);
    });

    await _requestReply(text: userMessage.text, conversationId: conversationId);
  }

  Future<void> _requestReply({
    required String text,
    required String conversationId,
    Future<void>? pendingUserSave,
  }) async {
    setState(() => _isLoading = true);

    try {
      final reply = await widget.aiProviderController.generateReply(text);

      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(text: reply, isUser: false, createdAt: DateTime.now()),
        ];
      });

      if (pendingUserSave != null) await pendingUserSave;
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
          ChatMessage(
            text: error.userMessage,
            isUser: false,
            isError: true,
            createdAt: DateTime.now(),
          ),
        ];
      });
    } catch (error, stackTrace) {
      debugPrint('Unexpected chat error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(
            text: 'Sorry, something went wrong. Please try again.',
            isUser: false,
            isError: true,
            createdAt: DateTime.now(),
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
      appBar: _ChatAppBar(
        aiProviderController: widget.aiProviderController,
        themeController: widget.themeController,
        chatPreferencesController: widget.chatPreferencesController,
        isInitializing: _isInitializing,
        onNewChat: _confirmNewChat,
        onOpenHistory: _openHistory,
        onChangeName: _changeName,
        onChangeGender: _changeGender,
        onSignOut: _signOut,
        onAbout: _showAbout,
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
                        final message = _messages[index];
                        return MessageBubble(
                          message: message,
                          userGender: _profile.gender,
                          userName: _profile.displayName,
                          showTimestamp:
                              widget.chatPreferencesController.showTimestamps,
                          showName: widget.chatPreferencesController.showNames,
                          showActions:
                              widget.chatPreferencesController.showBubbleActions,
                          onRetry: message.isError && !_isLoading
                              ? () => _retryMessage(index)
                              : null,
                        );
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

class _MenuIconBadge extends StatelessWidget {
  const _MenuIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.aiProviderController,
    required this.themeController,
    required this.chatPreferencesController,
    required this.isInitializing,
    required this.onNewChat,
    required this.onOpenHistory,
    required this.onChangeName,
    required this.onChangeGender,
    required this.onSignOut,
    required this.onAbout,
  });

  final AiProviderController aiProviderController;
  final ThemeController themeController;
  final ChatPreferencesController chatPreferencesController;
  final bool isInitializing;
  final VoidCallback onNewChat;
  final VoidCallback onOpenHistory;
  final VoidCallback onChangeName;
  final VoidCallback onChangeGender;
  final VoidCallback onSignOut;
  final VoidCallback onAbout;

  @override
  Size get preferredSize => const Size.fromHeight(108);

  void _handleMenuSelection(String action) {
    switch (action) {
      case 'provider_gemini':
        aiProviderController.select(AiProvider.gemini);
      case 'provider_groq':
        aiProviderController.select(AiProvider.groq);
      case 'history':
        onOpenHistory();
      case 'change_name':
        onChangeName();
      case 'change_gender':
        onChangeGender();
      case 'toggle_theme':
        themeController.setDark(!themeController.isDark);
      case 'toggle_timestamps':
        chatPreferencesController.setShowTimestamps(
          !chatPreferencesController.showTimestamps,
        );
      case 'toggle_names':
        chatPreferencesController.setShowNames(
          !chatPreferencesController.showNames,
        );
      case 'toggle_bubble_actions':
        chatPreferencesController.setShowBubbleActions(
          !chatPreferencesController.showBubbleActions,
        );
      case 'about':
        onAbout();
      case 'sign_out':
        onSignOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDown = aiProviderController.allProvidersDown;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AidaColors.pink, AidaColors.pinkDeep],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 22,
                  backgroundImage: AssetImage(_botAvatarAsset),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AIDA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDown ? Colors.grey.shade400 : Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isDown
                                ? 'Unavailable'
                                : aiProviderController.current.label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('clearChatButton'),
                onPressed: isInitializing ? null : onNewChat,
                tooltip: 'New chat',
                icon: const Icon(Icons.edit_square, color: Colors.white, size: 20),
              ),
              PopupMenuButton<String>(
                key: const Key('chatMenuButton'),
                tooltip: 'Menu',
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: _handleMenuSelection,
                itemBuilder: (context) {
                  final available = aiProviderController.availableProviders;
                  final current = aiProviderController.current;
                  return [
                    for (final provider in available)
                      PopupMenuItem<String>(
                        value: 'provider_${provider.name}',
                        child: Row(
                          children: [
                            _MenuIconBadge(
                              icon: provider.menuIcon,
                              color: provider.menuIconColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(provider.label)),
                            if (provider == current)
                              const Icon(Icons.check, size: 18),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'history',
                      key: const Key('historyMenuItem'),
                      child: const Row(
                        children: [
                          _MenuIconBadge(
                            icon: Icons.history,
                            color: Color(0xFF6366F1),
                          ),
                          SizedBox(width: 12),
                          Text('Saved chats'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'change_name',
                      key: const Key('changeNameMenuItem'),
                      child: const Row(
                        children: [
                          _MenuIconBadge(
                            icon: Icons.badge_outlined,
                            color: AidaColors.teal,
                          ),
                          SizedBox(width: 12),
                          Text('Change name'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'change_gender',
                      key: const Key('changeGenderMenuItem'),
                      child: const Row(
                        children: [
                          _MenuIconBadge(
                            icon: Icons.wc_outlined,
                            color: AidaColors.pink,
                          ),
                          SizedBox(width: 12),
                          Text('Change gender'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'toggle_theme',
                      key: const Key('toggleThemeMenuItem'),
                      child: Row(
                        children: [
                          _MenuIconBadge(
                            icon: themeController.isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            color: AidaColors.navy,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Dark mode')),
                          Switch(
                            value: themeController.isDark,
                            onChanged: (value) {
                              Navigator.of(context).pop();
                              themeController.setDark(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_timestamps',
                      key: const Key('toggleTimestampsMenuItem'),
                      child: Row(
                        children: [
                          const _MenuIconBadge(
                            icon: Icons.schedule_outlined,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Show timestamps')),
                          Switch(
                            value: chatPreferencesController.showTimestamps,
                            onChanged: (value) {
                              Navigator.of(context).pop();
                              chatPreferencesController.setShowTimestamps(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_names',
                      key: const Key('toggleNamesMenuItem'),
                      child: Row(
                        children: [
                          const _MenuIconBadge(
                            icon: Icons.label_outline,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Show names')),
                          Switch(
                            value: chatPreferencesController.showNames,
                            onChanged: (value) {
                              Navigator.of(context).pop();
                              chatPreferencesController.setShowNames(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle_bubble_actions',
                      key: const Key('toggleBubbleActionsMenuItem'),
                      child: Row(
                        children: [
                          const _MenuIconBadge(
                            icon: Icons.ios_share_outlined,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Show copy/forward')),
                          Switch(
                            value: chatPreferencesController.showBubbleActions,
                            onChanged: (value) {
                              Navigator.of(context).pop();
                              chatPreferencesController.setShowBubbleActions(
                                value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'about',
                      key: const Key('aboutMenuItem'),
                      child: const Row(
                        children: [
                          _MenuIconBadge(
                            icon: Icons.info_outline,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 12),
                          Text('About'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'sign_out',
                      key: const Key('signOutMenuItem'),
                      child: Row(
                        children: [
                          _MenuIconBadge(
                            icon: Icons.logout,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sign out',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.userGender,
    required this.userName,
    required this.showTimestamp,
    required this.showName,
    required this.showActions,
    this.onRetry,
  });

  final ChatMessage message;
  final Gender userGender;
  final String userName;
  final bool showTimestamp;
  final bool showName;
  final bool showActions;
  final VoidCallback? onRetry;

  void _copyMessage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _forwardMessage() {
    SharePlus.instance.share(ShareParams(text: message.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = message.isError
        ? theme.colorScheme.errorContainer
        : message.isUser
        ? AidaColors.pink.withValues(alpha: isDark ? 0.35 : 0.16)
        : AidaColors.teal.withValues(alpha: isDark ? 0.28 : 0.16);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: message.isError
          ? theme.colorScheme.onErrorContainer
          : theme.colorScheme.onSurface,
      height: 1.35,
    );

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white,
      backgroundImage: AssetImage(
        message.isUser ? userGender.avatarAsset : _botAvatarAsset,
      ),
    );

    final bubbleColumn = Column(
      crossAxisAlignment: message.isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
            child: Text(
              message.isUser ? userName : 'AIDA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(message.isUser ? 16 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 16),
            ),
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
                        left: BorderSide(color: theme.colorScheme.primary, width: 3),
                      ),
                    ),
                  ),
                ),
        ),
        if (showTimestamp && message.createdAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
            child: Text(
              _timestampFormat.format(message.createdAt!.toPhilippineTime),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ),
        if (showActions && !message.isError)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BubbleActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Copy',
                onPressed: () => _copyMessage(context),
              ),
              const SizedBox(width: 2),
              _BubbleActionButton(
                icon: Icons.forward_rounded,
                tooltip: 'Forward',
                onPressed: _forwardMessage,
              ),
            ],
          ),
        if (message.isError && onRetry != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ),
      ],
    );

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.86,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: message.isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: message.isUser
              ? [Flexible(child: bubbleColumn), const SizedBox(width: 8), avatar]
              : [avatar, const SizedBox(width: 8), Flexible(child: bubbleColumn)],
        ),
      ),
    );
  }
}

class _BubbleActionButton extends StatelessWidget {
  const _BubbleActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AidaColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
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
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(20, 14, 8, 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                key: const Key('sendButton'),
                onPressed: isLoading ? null : onSend,
                tooltip: 'Send message',
                icon: const Icon(Icons.send_rounded, color: AidaColors.pink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
