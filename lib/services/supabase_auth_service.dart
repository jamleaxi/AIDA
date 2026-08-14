import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_service.dart';

/// Deep link Supabase redirects back to on Android/iOS after an OAuth flow
/// or a password-reset email link. Must also be registered as a Redirect URL
/// in the Supabase Dashboard (Authentication > URL Configuration), and match
/// the intent-filter / URL scheme configured for each native platform.
const _mobileRedirectTo = 'io.supabase.aida://login-callback/';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client) {
    _passwordRecoveryController.onListen = () {
      _passwordRecoverySubscription ??= _client.auth.onAuthStateChange.listen((
        state,
      ) {
        if (state.event == supabase.AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryController.add(null);
        }
      });
    };
  }

  final supabase.SupabaseClient _client;
  final _passwordRecoveryController = StreamController<void>.broadcast();
  StreamSubscription<supabase.AuthState>? _passwordRecoverySubscription;

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _client.auth.onAuthStateChange.map(
    (state) => _toAppUser(state.session?.user),
  );

  @override
  Stream<void> get passwordRecoveryRequested =>
      _passwordRecoveryController.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on supabase.AuthException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on supabase.AuthException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: kIsWeb ? null : _mobileRedirectTo,
      );
    } on supabase.AuthException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : _mobileRedirectTo,
      );
    } on supabase.AuthException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (error) {
      throw AuthServiceException(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AppUser? _toAppUser(supabase.User? user) {
    if (user == null) return null;
    return AppUser(id: user.id, email: user.email);
  }
}
