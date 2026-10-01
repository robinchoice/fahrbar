import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../../../providers/supabase_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.read(supabaseClientProvider));
});

sealed class AuthStatus {
  const AuthStatus();
}

class AuthInitial extends AuthStatus {
  const AuthInitial();
}

class AuthLoading extends AuthStatus {
  const AuthLoading();
}

class AuthAuthenticated extends AuthStatus {
  const AuthAuthenticated();
}

class AuthUnauthenticated extends AuthStatus {
  const AuthUnauthenticated();
}

class AuthError extends AuthStatus {
  const AuthError(this.message);
  final String message;
}

class AuthConfirmationPending extends AuthStatus {
  const AuthConfirmationPending();
}

class AuthNotifier extends AutoDisposeNotifier<AuthStatus> {
  late AuthRepository _repo;

  @override
  AuthStatus build() {
    _repo = ref.read(authRepositoryProvider);

    // OAuth callbacks, email confirmation links, expired sessions and
    // sign-outs all arrive here, not as results of the calls below.
    final sub = _repo.authStateChanges.listen(
      (authState) {
        state = authState.session != null
            ? const AuthAuthenticated()
            : const AuthUnauthenticated();
      },
      onError: (Object e) {
        // A failed OAuth callback should show up on the login screen, a
        // failed background token refresh must not log the user out.
        if (_repo.currentUser == null) state = AuthError(e.toString());
      },
    );
    ref.onDispose(sub.cancel);

    final user = _repo.currentUser;
    return user != null ? const AuthAuthenticated() : const AuthUnauthenticated();
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthLoading();
    try {
      await _repo.signInWithEmail(email: email, password: password);
      state = const AuthAuthenticated();
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AuthLoading();
    try {
      await _repo.signUpWithEmail(email: email, password: password);
      // With email confirmation enabled, sign-up returns without a session.
      state = _repo.currentUser != null
          ? const AuthAuthenticated()
          : const AuthConfirmationPending();
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = const AuthLoading();
    try {
      // Only opens the browser; the session arrives via authStateChanges.
      await _repo.signInWithApple();
      if (state is AuthLoading) state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      // Only opens the browser; the session arrives via authStateChanges.
      await _repo.signInWithGoogle();
      if (state is AuthLoading) state = const AuthUnauthenticated();
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthUnauthenticated();
  }
}

final authNotifierProvider =
    AutoDisposeNotifierProvider<AuthNotifier, AuthStatus>(AuthNotifier.new);
