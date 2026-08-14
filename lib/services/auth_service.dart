class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String? email;
}

abstract interface class AuthService {
  AppUser? get currentUser;

  Stream<AppUser?> get userChanges;

  /// Emits whenever the user opens a password-reset link. The UI should
  /// intercept this and show a "set new password" screen instead of routing
  /// them straight into the app, even though a session now exists.
  Stream<void> get passwordRecoveryRequested;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  /// Signs in (creating the account on first use) via Google OAuth. Opens a
  /// system browser; completion is observed through [userChanges].
  Future<void> signInWithGoogle();

  /// Sends a password-reset email containing a link back into the app.
  Future<void> resetPassword({required String email});

  /// Sets a new password for the current session, e.g. after following a
  /// password-reset link.
  Future<void> updatePassword({required String newPassword});

  Future<void> signOut();
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => 'AuthServiceException: $message';
}
