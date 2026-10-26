import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:altcha_lib/altcha_lib.dart' as altcha;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
final authProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

/// Proof of work against bots, what the ALTCHA widget does on the web
/// (README, „ALTCHA“). Isolates keep the UI responsive meanwhile; widget tests
/// solve on the main isolate, their fake clock doesn't wait for others.
final altchaSolverProvider = Provider<Future<altcha.Solution?> Function(altcha.Challenge)>(
  (ref) =>
      (challenge) => altcha.solveChallengeIsolates(
        challenge: challenge,
        deriveKey: altcha.deriveKey,
        concurrency: Platform.numberOfProcessors.clamp(1, 4),
      ),
);

class User {
  final String id;
  final String email;
  final String name;
  const User({required this.id, required this.email, required this.name});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(id: json['id'] as String, email: json['email'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}

/// The logged-in user, or null. Token and profile live in the platform
/// keychain / keystore, so the app starts logged in even when offline.
class AuthController extends AsyncNotifier<User?> {
  static const _tokenKey = 'session_token';
  static const _userKey = 'user';

  Api get _api => ref.read(apiProvider);
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  Future<User?> build() async {
    _api.onUnauthorized = () => unawaited(_clear());
    final token = await _storage.read(key: _tokenKey);
    final saved = await _storage.read(key: _userKey);
    if (token == null || saved == null) return null;
    _api.token = token;
    unawaited(refresh());
    return User.fromJson(jsonDecode(saved) as Map<String, dynamic>);
  }

  /// Offline keeps the saved user. An expired session logs out.
  Future<void> refresh() async {
    try {
      final user = (await _api.get('/auth/me') as Map<String, dynamic>)['user'];
      if (!ref.mounted) return;
      user == null ? await _clear() : await _save(User.fromJson(user as Map<String, dynamic>));
    } on OfflineException {
      // keep the saved user
    }
  }

  /// Mails a 6-digit code. A magic link can't open the app without
  /// universal links, a code can be typed in anywhere.
  Future<void> requestCode(String email) async =>
      _api.post('/auth/code', {'email': email, 'altcha': await _altcha()});

  /// The challenge goes back as the API sent it, its signature covers it.
  Future<String> _altcha() async {
    final challenge = await _api.get('/altcha') as Map<String, dynamic>;
    final solution = await ref.read(altchaSolverProvider)(altcha.Challenge.fromJson(challenge));
    return base64Encode(utf8.encode(jsonEncode({'challenge': challenge, 'solution': solution!.toJson()})));
  }

  Future<void> verifyCode(String email, String code) async {
    final json = await _api.post('/auth/code/verify', {'email': email, 'code': code}) as Map<String, dynamic>;
    final token = json['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _api.token = token;
    await _save(User.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<void> updateName(String name) async {
    final json = await _api.patch('/auth/me', {'name': name}) as Map<String, dynamic>;
    await _save(User.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on OfflineException {
      // Logging out locally must work offline too.
    }
    await _clear();
  }

  Future<void> _save(User user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    state = AsyncData(user);
  }

  // Logs out right away, the keychain catches up.
  Future<void> _clear() async {
    final storage = _storage;
    _api.token = null;
    state = const AsyncData(null);
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _userKey);
  }
}
