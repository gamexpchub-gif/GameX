import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/commerce_api.dart';
import 'notification_service.dart';

/// Firebase project values, passed at build time:
///   flutter build apk --release \
///     --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
///     --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
/// (Firebase console → Project settings → Your apps → Android app.)
/// Without them the app still works and checks for notifications when open.
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool get pushConfigured =>
    _apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty;

FirebaseOptions get _options => const FirebaseOptions(
  apiKey: _apiKey,
  appId: _appId,
  messagingSenderId: _senderId,
  projectId: _projectId,
);

/// Messages that arrive while the app is closed are shown by Android
/// itself (they carry a `notification`), so nothing else to do here.
@pragma('vm:entry-point')
Future<void> _background(RemoteMessage m) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
}

class PushService {
  PushService(this._ref);
  final Ref _ref;
  bool _started = false;

  /// Sets up FCM, asks for permission and registers this device's token
  /// with the GAMEX server for the logged-in customer.
  Future<void> start() async {
    if (_started || !pushConfigured || kIsWeb) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }
      FirebaseMessaging.onBackgroundMessage(_background);
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      // The registration token is what FCM HTTP v1 sends to.
      // ignore: deprecated_member_use
      final token = await m.getToken();
      if (token != null) await _register(token);
      // ignore: deprecated_member_use
      m.onTokenRefresh.listen(_register);
      // In the foreground: refresh the feed (it shows the notification).
      FirebaseMessaging.onMessage.listen(
        (_) => _ref.read(notificationFeedProvider.notifier).refresh(),
      );
      // Tapped a notification: open its page.
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final first = await m.getInitialMessage();
      if (first != null) _open(first);
    } catch (e) {
      _started = false;
      debugPrint('Push not available: $e');
    }
  }

  Future<void> _register(String token) async {
    if (_ref.read(authProvider) == null) return;
    try {
      await _ref
          .read(commerceApiProvider)
          .registerPushToken(token, Platform.isIOS ? 'ios' : 'android');
    } catch (_) {}
  }

  /// Re-sends the token after login.
  Future<void> onLogin() async {
    if (!_started) return start();
    try {
      // ignore: deprecated_member_use
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _register(t);
    } catch (_) {}
  }

  void _open(RemoteMessage m) {
    final link = m.data['link'] as String?;
    if (link != null && link.startsWith('/')) appRouter.push(link);
  }
}

final pushServiceProvider = Provider<PushService>(PushService.new);
