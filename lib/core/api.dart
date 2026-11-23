import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status = 0});
  final String message;
  final int status;
  bool get offline => status == 0;
  @override
  String toString() => message;
}

/// Default server: the live GAMEX server. Override at build time with
/// `--dart-define=API_URL=http://192.168.1.5:8080` for local testing.
const kDefaultApi = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://admin.deencircle.online/gamex',
);
const _kApiKey = 'api_url_v1';

/// HTTP client for the GAMEX server.
class Api {
  Api(this._prefs);
  final SharedPreferences _prefs;
  final _client = http.Client();

  /// Session token sent as `Authorization: Bearer`.
  static const tokenKey = 'session_token_v1';

  /// Called when the server says the session is no longer valid.
  static void Function()? onUnauthorized;

  String? get token => _prefs.getString(tokenKey);
  Future<void> setToken(String? t) =>
      t == null ? _prefs.remove(tokenKey) : _prefs.setString(tokenKey, t);

  Map<String, String> get _auth {
    final t = token;
    return t == null ? const {} : {'authorization': 'Bearer $t'};
  }

  String get baseUrl => _prefs.getString(_kApiKey) ?? kDefaultApi;
  Future<void> setBaseUrl(String url) {
    var u = url.trim();
    if (!u.startsWith('http')) u = 'http://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // A bare IP / localhost means a local dev server on port 8080.
    final local = RegExp(
      r'^http://(localhost|127\.0\.0\.1|10\.|192\.168\.|172\.)',
    ).hasMatch(u);
    if (local && !RegExp(r':\d+$').hasMatch(u)) u = '$u:8080';
    return _prefs.setString(_kApiKey, u);
  }

  /// Absolute URL for a server path such as `/uploads/a.jpg`.
  String media(String path) => '$baseUrl$path';

  Uri _u(String path) => Uri.parse('$baseUrl/api$path');

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const ApiException('Server is not responding');
    } on SocketException {
      throw const ApiException('Can\'t reach the GAMEX server');
    } on http.ClientException {
      throw const ApiException('Can\'t reach the GAMEX server');
    }
    final body = res.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    if (res.statusCode >= 400) {
      final msg = body is Map && body['error'] is String
          ? body['error'] as String
          : 'Request failed (${res.statusCode})';
      throw ApiException(msg, status: res.statusCode);
    }
    return body;
  }

  Map<String, String> get _json => {
    'content-type': 'application/json',
    ..._auth,
  };

  Future<dynamic> get(String p) =>
      _send(() => _client.get(_u(p), headers: _auth));
  Future<dynamic> post(String p, [Object? body]) => _send(
    () => _client.post(_u(p), headers: _json, body: jsonEncode(body ?? {})),
  );
  Future<dynamic> put(String p, Object body) =>
      _send(() => _client.put(_u(p), headers: _json, body: jsonEncode(body)));
  Future<dynamic> patch(String p, Object body) =>
      _send(() => _client.patch(_u(p), headers: _json, body: jsonEncode(body)));
  Future<dynamic> delete(String p) =>
      _send(() => _client.delete(_u(p), headers: _auth));

  /// Uploads a local image and returns its server path.
  Future<String> upload(String filePath) async {
    final res = await _send(() async {
      final req = http.MultipartRequest('POST', _u('/upload'))
        ..headers.addAll(_auth)
        ..files.add(await http.MultipartFile.fromPath('photo', filePath));
      return http.Response.fromStream(await _client.send(req));
    });
    return (res as Map)['url'] as String;
  }
}

final apiProvider = Provider<Api>((ref) => Api(ref.watch(sharedPrefsProvider)));
