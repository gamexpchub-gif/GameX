import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/storage.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/commerce_api.dart';

/// Server notifications (offer replies, price drops, back in stock, wallet,
/// orders) shown as real system notifications.
///
/// The app checks the GAMEX server when it opens, when it comes back to the
/// foreground and every 45 seconds while open. When the server is set up
/// with Firebase (FCM_SERVICE_ACCOUNT) the same notifications are also sent
/// as push messages to registered devices.
class NotificationFeed extends Notifier<List<CustomerNotif>> {
  static const _seenKey = 'notif_seen_at_v1';
  static const channelId = 'gamex_alerts';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _busy = false;

  @override
  List<CustomerNotif> build() {
    ref.listen(authProvider, (prev, next) {
      if (next?.id != prev?.id) {
        state = const [];
        refresh(silent: true);
      }
    });
    return const [];
  }

  int get unread => state.where((n) => !n.read).length;

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final link = r.payload;
          if (link != null && link.startsWith('/')) appRouter.push(link);
        },
      );
      _ready = true;
    } catch (_) {
      // Not available (tests, unsupported platform).
    }
  }

  /// Asks for notification permission (Android 13+, iOS). Call when the
  /// buyer turns on an alert or makes an offer.
  Future<bool> requestPermission() async {
    await _init();
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the feed; shows a system notification for each new item
  /// unless [silent].
  Future<void> refresh({bool silent = false}) async {
    if (_busy || ref.read(authProvider) == null) return;
    _busy = true;
    try {
      final api = ref.read(commerceApiProvider);
      final list = await api.notifications();
      final store = ref.read(localStoreProvider);
      final seen = DateTime.tryParse(store.readString(_seenKey) ?? '');
      final fresh = [
        for (final n in list)
          if (!n.read && (seen == null || n.at.isAfter(seen))) n,
      ];
      state = list;
      if (list.isNotEmpty) {
        await store.writeString(_seenKey, list.first.at.toIso8601String());
      }
      if (!silent && seen != null) {
        for (final n in fresh.take(3)) {
          await _show(n);
        }
      }
      if (fresh.any((n) => n.kind == 'offer')) ref.invalidate(myOffersProvider);
      if (fresh.any((n) => n.kind == 'wallet')) ref.invalidate(walletProvider);
      if (fresh.any((n) => n.kind == 'price' || n.kind == 'stock')) {
        ref.invalidate(myAlertsProvider);
      }
    } catch (_) {
      // Offline: try again later.
    } finally {
      _busy = false;
    }
  }

  Future<void> _show(CustomerNotif n) async {
    await _init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: n.id.hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        payload: n.link,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Deals & alerts',
            channelDescription:
                'Price drops, back in stock, offers, orders and wallet',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF3B5BFF),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    state = [
      for (final n in state) CustomerNotif({...n.j, 'read': true}),
    ];
    try {
      await ref.read(commerceApiProvider).markNotificationsRead();
    } catch (_) {}
  }
}

final notificationFeedProvider =
    NotifierProvider<NotificationFeed, List<CustomerNotif>>(
      NotificationFeed.new,
    );

final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationFeedProvider).where((n) => !n.read).length,
);

/// Keeps the notification feed fresh while the app is running.
class NotificationsHost extends ConsumerStatefulWidget {
  const NotificationsHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<NotificationsHost> createState() => _NotificationsHostState();
}

class _NotificationsHostState extends ConsumerState<NotificationsHost>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _feed.refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _feed.refresh(),
    );
  }

  NotificationFeed get _feed => ref.read(notificationFeedProvider.notifier);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _feed.refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
