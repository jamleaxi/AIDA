import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/chat_prefs.dart';
import '../services/chat_repository.dart';
import 'auth_page.dart';
import 'chat_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.aiService,
    required this.chatRepository,
    required this.chatPrefs,
  });

  final AuthService authService;
  final AiService aiService;
  final MessageRepository chatRepository;
  final ChatPrefs chatPrefs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authService.userChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return AuthPage(authService: authService);
        }

        return ChatPage(
          key: ValueKey(user.id),
          aiService: aiService,
          chatRepository: chatRepository,
          chatPrefs: chatPrefs,
          authService: authService,
          userId: user.id,
        );
      },
    );
  }
}
