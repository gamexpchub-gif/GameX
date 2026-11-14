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
  defaultValue: 'https://admin.deencircle.online/hisab',
);
const _kApiKey = 'api_url_v1';

/// HTTP client for the GAMEX server.
class Api {
  Api(this._prefs);
  final SharedPreferences _prefs;
  final _client = http.Client();

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
    if (res.statusCode >= 400) {
      final msg = body is Map && body['error'] is String
          ? body['error'] as String
          : 'Request failed (${res.statusCode})';
      throw ApiException(msg, status: res.statusCode);
    }
    return body;
  }

  static const _json = {'content-type': 'application/json'};

  Future<dynamic> get(String p) => _send(() => _client.get(_u(p)));
  Future<dynamic> post(String p, [Object? body]) => _send(
    () => _client.post(_u(p), headers: _json, body: jsonEncode(body ?? {})),
  );
  Future<dynamic> put(String p, Object body) =>
      _send(() => _client.put(_u(p), headers: _json, body: jsonEncode(body)));
  Future<dynamic> patch(String p, Object body) =>
      _send(() => _client.patch(_u(p), headers: _json, body: jsonEncode(body)));
  Future<dynamic> delete(String p) => _send(() => _client.delete(_u(p)));

  /// Uploads a local image and returns its server path.
  Future<String> upload(String filePath) async {
    final res = await _send(() async {
      final req = http.MultipartRequest('POST', _u('/upload'))
        ..files.add(await http.MultipartFile.fromPath('photo', filePath));
      return http.Response.fromStream(await _client.send(req));
    });
    return (res as Map)['url'] as String;
  }
}

final apiProvider = Provider<Api>((ref) => Api(ref.watch(sharedPrefsProvider)));
