import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/chat_message.dart';
import '../models/conversation_summary.dart';
import '../services/chat_repository.dart';
import '../utils/philippine_time.dart';

final _exportTimestampFormat = DateFormat('MMM d, y • hh:mm a');

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
  List<ConversationSummary> _conversations = const [];
  bool _selectionMode = false;
  bool _isExporting = false;
  final Set<String> _selectedIds = {};

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

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String conversationId) {
    setState(() {
      if (!_selectedIds.remove(conversationId)) {
        _selectedIds.add(conversationId);
      }
    });
  }

  Future<void> _showDownloadOptions() async {
    if (_conversations.isEmpty) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download all saved chats'),
              onTap: () => Navigator.of(context).pop('all'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Select chats to download'),
              onTap: () => Navigator.of(context).pop('select'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (choice == 'all') {
      await _exportConversations(_conversations);
    } else if (choice == 'select') {
      setState(() {
        _selectionMode = true;
        _selectedIds.clear();
      });
    }
  }

  Future<void> _downloadSelected() async {
    final selected = _conversations
        .where((c) => _selectedIds.contains(c.conversationId))
        .toList();
    await _exportConversations(selected);
  }

  Future<void> _exportConversations(List<ConversationSummary> conversations) async {
    if (conversations.isEmpty) return;

    setState(() => _isExporting = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Preparing export…')),
          ],
        ),
      ),
    );

    try {
      final entries = <MapEntry<ConversationSummary, List<ChatMessage>>>[];
      for (final summary in conversations) {
        final messages = await widget.chatRepository.fetchMessages(
          summary.conversationId,
        );
        entries.add(MapEntry(summary, messages));
      }

      final transcript = _buildTranscript(entries);
      final bytes = Uint8List.fromList(utf8.encode(transcript));
      final fileName =
          'aida_chats_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now().toPhilippineTime)}.txt';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: 'text/plain')],
          subject: 'AIDA chat export',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Chat export failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export chats. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isExporting = false;
          _selectionMode = false;
          _selectedIds.clear();
        });
      }
    }
  }

  String _buildTranscript(
    List<MapEntry<ConversationSummary, List<ChatMessage>>> entries,
  ) {
    final buffer = StringBuffer()
      ..writeln('AIDA Chat Export')
      ..writeln('Generated ${_exportTimestampFormat.format(DateTime.now().toPhilippineTime)}')
      ..writeln();

    for (final entry in entries) {
      final summary = entry.key;
      final messages = entry.value;
      final divider = '=' * 40;

      buffer
        ..writeln(divider)
        ..writeln(summary.preview.isEmpty ? 'New chat' : summary.preview)
        ..writeln(
          'Updated ${_exportTimestampFormat.format(summary.updatedAt.toPhilippineTime)}',
        )
        ..writeln(divider);

      for (final message in messages) {
        final sender = message.isUser ? 'You' : 'AIDA';
        final time = message.createdAt != null
            ? _exportTimestampFormat.format(message.createdAt!.toPhilippineTime)
            : 'unknown time';
        buffer
          ..writeln('[$time] $sender:')
          ..writeln(message.text)
          ..writeln();
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                onPressed: _cancelSelection,
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close),
              )
            : null,
        title: Text(
          _selectionMode ? '${_selectedIds.length} selected' : 'Saved chats',
        ),
        actions: _selectionMode
            ? [
                IconButton(
                  key: const Key('downloadSelectedButton'),
                  onPressed: _isExporting || _selectedIds.isEmpty
                      ? null
                      : _downloadSelected,
                  tooltip: 'Download selected',
                  icon: const Icon(Icons.download_outlined),
                ),
              ]
            : [
                IconButton(
                  key: const Key('downloadChatsButton'),
                  onPressed: _isExporting ? null : _showDownloadOptions,
                  tooltip: 'Download saved chats',
                  icon: const Icon(Icons.download_outlined),
                ),
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
          _conversations = conversations;
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
              final isSelected = _selectedIds.contains(
                conversation.conversationId,
              );
              return ListTile(
                leading: _selectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) =>
                            _toggleSelected(conversation.conversationId),
                      )
                    : Icon(
                        isCurrent
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                      ),
                title: Text(
                  conversation.preview.isEmpty
                      ? 'New chat'
                      : conversation.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${dateFormat.format(conversation.updatedAt.toPhilippineTime)} · '
                  '${conversation.messageCount} message'
                  '${conversation.messageCount == 1 ? '' : 's'}',
                ),
                selected: isCurrent || isSelected,
                trailing: !_selectionMode && isCurrent
                    ? const Text('Current')
                    : null,
                onTap: _selectionMode
                    ? () => _toggleSelected(conversation.conversationId)
                    : () => Navigator.of(context).pop(conversation.conversationId),
                onLongPress: _selectionMode
                    ? null
                    : () {
                        setState(() {
                          _selectionMode = true;
                          _selectedIds.add(conversation.conversationId);
                        });
                      },
              );
            },
          );
        },
      ),
    );
  }
}
