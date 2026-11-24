import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../router.dart';
import 'api.dart';
import 'storage.dart';

/// Firebase values for the seller app, passed at build time (same Firebase
/// project as the buyer app, Android app id com.gamex.seller):
///   flutter build apk --release --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=... \
///     --dart-define=FIREBASE_PROJECT_ID=...
/// Without them the app still shows notifications while it is running.
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool get _pushConfigured =>
    _apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty;

const _options = FirebaseOptions(
  apiKey: _apiKey,
  appId: _appId,
  messagingSenderId: _senderId,
  projectId: _projectId,
);

@pragma('vm:entry-point')
Future<void> _background(RemoteMessage m) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
}

/// Shows new server notifications (orders, buyer questions, QC results,
/// payouts) as phone notifications, and registers for FCM push when the
/// app was built with Firebase values.
class SellerAlerts {
  SellerAlerts(this._ref);
  final Ref _ref;

  static const _seenKey = 'seller_notif_seen_v1';
  static const channelId = 'gamex_alerts';
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _pushStarted = false;

  static String linkFor(String kind) => switch (kind) {
    'question' => '/questions',
    'order' => '/orders',
    'live' => '/live',
    'offer' => '/offers',
    'qc' => '/listings',
    'payout' => '/earnings',
    _ => '/home',
  };

  void _open(String? link) {
    if (link != null && link.startsWith('/')) {
      _ref.read(routerProvider).push(link);
    }
  }

  Future<void> _init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (r) => _open(r.payload),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          'Orders & questions',
          description: 'New orders, buyer questions, QC results and payouts',
          importance: Importance.high,
        ),
      );
      await android?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // tests / unsupported platform
    }
  }

  /// Called after every sync with the seller's notification list.
  Future<void> onSync(List<Notice> notices) async {
    if (notices.isEmpty) return;
    final store = _ref.read(localStoreProvider);
    final seen = DateTime.tryParse(store.readJson(_seenKey, (j) => j as String) ?? '');
    final newest = notices
        .map((n) => n.at)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    await store.writeJson(_seenKey, newest.toIso8601String());
    // First sync after install / login: don't replay old notifications.
    if (seen == null) return;
    final fresh = [
      for (final n in notices)
        if (n.at.isAfter(seen) && !n.read) n,
    ];
    if (fresh.isEmpty) return;
    await _init();
    if (!_ready) return;
    for (final n in fresh.take(3)) {
      try {
        await _plugin.show(
          id: n.id.hashCode & 0x7fffffff,
          title: n.title,
          body: n.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              'Orders & questions',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: linkFor(n.kind),
        );
      } catch (_) {}
    }
  }

  /// Registers this phone for push messages for [sellerId].
  Future<void> startPush(String sellerId, Future<void> Function() refresh) async {
    if (_pushStarted || !_pushConfigured || kIsWeb) return;
    _pushStarted = true;
    try {
      await _init();
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
      FirebaseMessaging.onBackgroundMessage(_background);
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      Future<void> register(String token) async {
        try {
          await _ref.read(apiProvider).post('/seller/$sellerId/push/register', {
            'token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
          });
        } catch (_) {}
      }

      // ignore: deprecated_member_use
      final token = await m.getToken();
      if (token != null) await register(token);
      // ignore: deprecated_member_use
      m.onTokenRefresh.listen(register);
      // In the foreground the sync shows the notification.
      FirebaseMessaging.onMessage.listen((_) => refresh());
      FirebaseMessaging.onMessageOpenedApp.listen(
        (msg) => _open(msg.data['link'] as String?),
      );
      final first = await m.getInitialMessage();
      if (first != null) _open(first.data['link'] as String?);
    } catch (e) {
      _pushStarted = false;
      debugPrint('Push not available: $e');
    }
  }
}

final sellerAlertsProvider = Provider<SellerAlerts>(SellerAlerts.new);
