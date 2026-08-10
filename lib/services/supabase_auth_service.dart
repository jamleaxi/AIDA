import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_service.dart';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final supabase.SupabaseClient _client;

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _client.auth.onAuthStateChange.map(
        (state) => _toAppUser(state.session?.user),
      );

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
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AppUser? _toAppUser(supabase.User? user) {
    if (user == null) return null;
    return AppUser(id: user.id, email: user.email);
  }
}
