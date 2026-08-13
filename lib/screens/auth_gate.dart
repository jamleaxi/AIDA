import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/ai_provider_controller.dart';
import '../services/auth_service.dart';
import '../services/chat_preferences_controller.dart';
import '../services/chat_repository.dart';
import '../services/profile_repository.dart';
import '../services/theme_controller.dart';
import 'auth_page.dart';
import 'chat_page.dart';
import 'onboarding_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.aiProviderController,
    required this.chatRepository,
    required this.profileRepository,
    required this.themeController,
    required this.chatPreferencesController,
  });

  final AuthService authService;
  final AiProviderController aiProviderController;
  final MessageRepository chatRepository;
  final ProfileRepository profileRepository;
  final ThemeController themeController;
  final ChatPreferencesController chatPreferencesController;

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

        return _ProfileGate(
          key: ValueKey(user.id),
          userId: user.id,
          profileRepository: profileRepository,
          aiProviderController: aiProviderController,
          chatRepository: chatRepository,
          authService: authService,
          themeController: themeController,
          chatPreferencesController: chatPreferencesController,
        );
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({
    super.key,
    required this.userId,
    required this.profileRepository,
    required this.aiProviderController,
    required this.chatRepository,
    required this.authService,
    required this.themeController,
    required this.chatPreferencesController,
  });

  final String userId;
  final ProfileRepository profileRepository;
  final AiProviderController aiProviderController;
  final MessageRepository chatRepository;
  final AuthService authService;
  final ThemeController themeController;
  final ChatPreferencesController chatPreferencesController;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileRepository.fetchProfile(widget.userId);
  }

  void _onOnboardingComplete(UserProfile profile) {
    setState(() {
      _profileFuture = Future.value(profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return OnboardingPage(
            userId: widget.userId,
            profileRepository: widget.profileRepository,
            onComplete: _onOnboardingComplete,
          );
        }

        return ChatPage(
          aiProviderController: widget.aiProviderController,
          chatRepository: widget.chatRepository,
          authService: widget.authService,
          profileRepository: widget.profileRepository,
          themeController: widget.themeController,
          chatPreferencesController: widget.chatPreferencesController,
          profile: profile,
        );
      },
    );
  }
}
