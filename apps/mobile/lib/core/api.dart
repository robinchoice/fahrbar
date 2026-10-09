import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'messages.dart';

final httpClientProvider = Provider((ref) => http.Client());
final apiProvider = Provider((ref) => Api(ref.watch(httpClientProvider), '$apiUrl/api/v1'));

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// No response from the server (offline, timeout, DNS), safe to retry later.
class OfflineException implements Exception {
  final String message;
  const OfflineException(this.message);

  @override
  String toString() => message;
}

/// JSON client for the Hono API. Native clients have no cookie jar and send
/// the session token as a bearer token.
class Api {
  final http.Client _client;
  final String _baseUrl;
  String? token;

  /// Language of error texts and mails, set by localeProvider.
  AppLocale locale = AppLocale.de;

  /// Called when the server rejects our session token.
  void Function()? onUnauthorized;

  /// The last failed calls, newest first. Feedback sends them along.
  final recentErrors = <String>[];

  Api(this._client, this._baseUrl);

  Future<dynamic> get(String path) => send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => send('POST', path, body);
  Future<dynamic> patch(String path, Object? body) => send('PATCH', path, body);
  Future<dynamic> delete(String path) => send('DELETE', path);

  Future<dynamic> send(String method, String path, [Object? body]) async {
    final auth = token;
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers['accept'] = 'application/json'
      ..headers['accept-language'] = locale.name
      ..headers['content-type'] = 'application/json';
    if (auth != null) request.headers['authorization'] = 'Bearer $auth';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 20)));
    } catch (e) {
      debugPrint('API $method $path failed: $e');
      _noteError(method, path, 'offline');
      throw OfflineException(locale.messages.offline);
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      _noteError(method, path, response.statusCode);
      if (response.statusCode == 401 && auth != null) onUnauthorized?.call();
      String message;
      try {
        message = (jsonDecode(text) as Map<String, dynamic>)['error'] as String;
      } catch (_) {
        message = locale.messages.serverError(response.statusCode);
      }
      throw ApiException(response.statusCode, message);
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  void _noteError(String method, String path, Object status) {
    recentErrors.insert(0, '$method /api/v1$path → $status');
    if (recentErrors.length > 5) recentErrors.removeLast();
  }
}
