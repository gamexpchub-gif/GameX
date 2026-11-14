import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  T? readJson<T>(String key, T Function(Object? json) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return parse(jsonDecode(raw));
    } catch (_) {
      _prefs.remove(key);
      return null;
    }
  }

  Future<void> writeJson(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPrefsProvider)),
);
