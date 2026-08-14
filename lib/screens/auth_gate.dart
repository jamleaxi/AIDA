import 'dart:async';

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
import 'offline_status_page.dart';
import 'onboarding_page.dart';
import 'reset_password_page.dart';
import 'splash_screen.dart';

class AuthGate extends StatefulWidget {
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
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _passwordRecoveryPending = false;
  StreamSubscription<void>? _recoverySubscription;

  @override
  void initState() {
    super.initState();
    _recoverySubscription = widget.authService.passwordRecoveryRequested.listen(
      (_) {
        if (mounted) setState(() => _passwordRecoveryPending = true);
      },
    );
  }

  @override
  void dispose() {
    _recoverySubscription?.cancel();
    super.dispose();
  }

  void _completePasswordRecovery() {
    setState(() => _passwordRecoveryPending = false);
  }

  @override
  Widget build(BuildContext context) {
    // A password-reset link signs the user into a real session, but they
    // must set a new password before going any further into the app.
    if (_passwordRecoveryPending) {
      return ResetPasswordPage(
        authService: widget.authService,
        onComplete: _completePasswordRecovery,
      );
    }

    return StreamBuilder<AppUser?>(
      stream: widget.authService.userChanges,
      initialData: widget.authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return AuthPage(authService: widget.authService);
        }

        return _ProfileGate(
          key: ValueKey(user.id),
          userId: user.id,
          profileRepository: widget.profileRepository,
          aiProviderController: widget.aiProviderController,
          chatRepository: widget.chatRepository,
          authService: widget.authService,
          themeController: widget.themeController,
          chatPreferencesController: widget.chatPreferencesController,
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
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = widget.profileRepository.fetchProfile(widget.userId).then((
      profile,
    ) {
      if (profile != null) widget.themeController.setGender(profile.gender);
      return profile;
    });
  }

  void _retryLoadProfile() {
    setState(_loadProfile);
  }

  void _onOnboardingComplete(UserProfile profile) {
    widget.themeController.setGender(profile.gender);
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
          return const Scaffold(body: SplashBody());
        }

        // Most commonly a failed profile lookup means the device is offline.
        // Show that instead of misreading it as "no profile yet" and sending
        // the user into onboarding to re-enter their name and gender.
        if (snapshot.hasError) {
          return OfflineStatusPage(onRetry: _retryLoadProfile);
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
