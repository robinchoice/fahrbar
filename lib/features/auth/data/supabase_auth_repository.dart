import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';

// Deep link back into the app, registered in Info.plist, AndroidManifest.xml
// and supabase/config.toml. On web the auth server redirects to the site URL.
const _redirectUrl = kIsWeb ? null : 'de.fahrbar://login-callback';

// An in-app browser view would stay open on iOS after the redirect.
const _authScreenLaunchMode =
    kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _redirectUrl,
    );
  }

  @override
  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirectUrl,
      authScreenLaunchMode: _authScreenLaunchMode,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      authScreenLaunchMode: _authScreenLaunchMode,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
