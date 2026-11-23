import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../core/storage.dart';
import '../../../data/models/app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Customer authentication against the GAMEX server. A session token is
/// stored with [Api]; every API call sends it and the server ties orders,
/// wallet, offers and reviews to this account.
class AuthNotifier extends Notifier<AppUser?> {
  Api get _api => ref.read(apiProvider);

  @override
  AppUser? build() {
    // The server ended the session (expired / blocked): sign out locally.
    Api.onUnauthorized = () {
      if (state != null) logout(remote: false);
    };
    final user = ref
        .read(localStoreProvider)
        .readJson(
          LocalStore.user,
          (json) => AppUser.fromJson(json as Map<String, dynamic>),
        );
    // Accounts from the old offline demo have no server session.
    if (user != null && ref.read(apiProvider).token == null) {
      Future.microtask(
        () => ref.read(localStoreProvider).remove(LocalStore.user),
      );
      return null;
    }
    return user;
  }

  AppUser _fromServer(Map j) => AppUser(
    id: j['id'] as String,
    name: (j['name'] as String? ?? '').isEmpty
        ? 'GAMEX Customer'
        : j['name'] as String,
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String?,
    joinedAt: DateTime.tryParse('${j['createdAt']}'),
  );

  Future<void> _signedIn(Map j) async {
    await _api.setToken(j['token'] as String);
    await _setUser(_fromServer(j['customer'] as Map));
  }

  /// [identifier] is a mobile number or an email address.
  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    try {
      await _signedIn(
        await _api.post('/auth/login', {
          'identifier': identifier,
          'password': password,
        }) as Map,
      );
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      await _signedIn(
        await _api.post('/auth/register', {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        }) as Map,
      );
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? email,
  }) async {
    final u = state;
    if (u == null) return;
    try {
      final j =
          await _api.put('/auth/me', {'name': name, 'email': ?email}) as Map;
      await _setUser(_fromServer(j));
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> logout({bool remote = true}) async {
    if (remote) {
      try {
        await _api.post('/auth/logout');
      } catch (_) {}
    }
    state = null;
    await _api.setToken(null);
    await ref.read(localStoreProvider).remove(LocalStore.user);
  }

  /// Sets a new password after the number was verified with OTP.
  Future<void> setPassword(String password) async {
    try {
      await _api.post('/auth/reset-password', {'password': password});
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> _setUser(AppUser user) async {
    state = user;
    await ref
        .read(localStoreProvider)
        .writeJson(LocalStore.user, user.toJson());
  }

  /// Sends a 6-digit login code by SMS. Returns the code only when the
  /// server runs in OTP test mode.
  Future<String?> sendOtp(String phone) async {
    try {
      final j = await ref.read(apiProvider).post('/auth/otp/send', {
        'phone': phone,
      }) as Map;
      return j['devCode'] as String?;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Verifies the SMS code. Returns true when the account still needs a name.
  Future<bool> verifyOtp(String phone, String code) async {
    final Map j;
    try {
      j = await ref.read(apiProvider).post('/auth/otp/verify', {
        'phone': phone,
        'code': code,
      }) as Map;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
    final c = (j['customer'] as Map).cast<String, dynamic>();
    await ref
        .read(localStoreProvider)
        .writeString('session_token_v1', j['token'] as String);
    final name = (c['name'] as String? ?? '').trim();
    await _setUser(
      AppUser(
        id: c['id'] as String,
        name: name.isEmpty ? 'GAMEX Customer' : name,
        email: c['email'] as String? ?? '',
        phone: c['phone'] as String?,
      ),
    );
    return j['isNew'] == true;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
