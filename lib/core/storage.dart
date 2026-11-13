import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

/// Small typed wrapper over SharedPreferences for JSON values.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static const cart = 'cart_v1';
  static const wishlist = 'wishlist_v1';
  static const orders = 'orders_v1';
  static const user = 'user_v1';
  static const themeMode = 'theme_mode_v1';
  static const recentSearches = 'recent_searches_v1';

  T? readJson<T>(String key, T Function(Object? json) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return parse(jsonDecode(raw));
    } catch (_) {
      // Corrupt or outdated data – start fresh instead of crashing.
      _prefs.remove(key);
      return null;
    }
  }

  Future<void> writeJson(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));

  String? readString(String key) => _prefs.getString(key);
  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> remove(String key) => _prefs.remove(key);
}

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPrefsProvider)),
);
