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

class AuthNotifier extends AutoDisposeNotifier<AuthStatus> {
  late AuthRepository _repo;

  @override
  AuthStatus build() {
    _repo = ref.read(authRepositoryProvider);
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
      state = const AuthAuthenticated();
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = const AuthLoading();
    try {
      await _repo.signInWithApple();
      state = const AuthAuthenticated();
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      await _repo.signInWithGoogle();
      state = const AuthAuthenticated();
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
