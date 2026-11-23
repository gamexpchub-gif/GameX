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

/// Local demo authentication. Replace the bodies of [login] / [register]
/// with real API calls once the backend is ready; the UI stays unchanged.
class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => ref
      .read(localStoreProvider)
      .readJson(
        LocalStore.user,
        (json) => AppUser.fromJson(json as Map<String, dynamic>),
      );

  /// [identifier] is a mobile number or an email address.
  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (password.length < 6) {
      throw const AuthException('Incorrect mobile number or password');
    }
    final isEmail = identifier.contains('@');
    final name = isEmail ? identifier.split('@').first : 'GAMEX Customer';
    await _setUser(
      AppUser(
        id: identifier.hashCode.toRadixString(16),
        name: name.isEmpty
            ? 'Customer'
            : name[0].toUpperCase() + name.substring(1),
        email: isEmail ? identifier : '',
        phone: isEmail ? null : identifier,
      ),
    );
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

  /// Demo password reset: pretends to send an OTP.
  Future<void> requestPasswordReset(String identifier) =>
      Future<void>.delayed(const Duration(milliseconds: 800));

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _setUser(
      AppUser(
        id: email.hashCode.toRadixString(16),
        name: name,
        email: email,
        phone: phone,
      ),
    );
  }

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? email,
  }) async {
    final u = state;
    if (u == null) return;
    await _setUser(
      AppUser(
        id: u.id,
        name: name,
        email: email ?? u.email,
        phone: phone,
        joinedAt: u.joinedAt,
      ),
    );
  }

  Future<void> logout() async {
    state = null;
    await ref.read(localStoreProvider).remove(LocalStore.user);
  }

  Future<void> _setUser(AppUser input) async {
    final user = input.joinedAt != null
        ? input
        : AppUser(
            id: input.id,
            name: input.name,
            email: input.email,
            phone: input.phone,
            joinedAt: state?.id == input.id
                ? state?.joinedAt ?? DateTime.now()
                : DateTime.now(),
          );
    state = user;
    await ref
        .read(localStoreProvider)
        .writeJson(LocalStore.user, user.toJson());
    // Register the customer with GAMEX so the admin panel can see them.
    ref.read(apiProvider).post('/customers/sync', {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone ?? '',
    }).ignore();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
