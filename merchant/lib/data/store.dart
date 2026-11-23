import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/storage.dart';
import 'models.dart';

const _kSeller = 'seller_v2';
const _kCache = 'seller_cache_v2';

/// Client-side id for a new listing (the server keeps it).
String newListingId() =>
    'GXL${DateTime.now().millisecondsSinceEpoch % 100000}${Random().nextInt(90) + 10}';

// ---------------- Session ----------------

class SellerNotifier extends Notifier<Seller?> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  Seller? build() =>
      _s.readJson(_kSeller, (j) => Seller.fromJson(j as Map<String, dynamic>));

  Future<void> set(Seller seller) async {
    state = seller;
    await _s.writeJson(_kSeller, seller.toJson());
  }

  Future<void> signOut() async {
    state = null;
    await _s.remove(_kSeller);
    await _s.remove(_kCache);
  }
}

final sellerProvider = NotifierProvider<SellerNotifier, Seller?>(
  SellerNotifier.new,
);

/// Sign-in helpers (before a session exists).
class AuthApi {
  AuthApi(this._api);
  final Api _api;

  /// Returns the seller for [phone], or null when not registered yet.
  Future<Seller?> login(String phone) async {
    try {
      final j = await _api.post('/seller/login', {'phone': phone});
      return Seller.fromJson(j as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Seller> register({
    required String phone,
    required String ownerName,
    required String storeName,
    required String city,
    String gstin = '',
  }) async {
    final j = await _api.post('/seller/register', {
      'phone': phone,
      'ownerName': ownerName,
      'storeName': storeName,
      'city': city,
      'gstin': gstin,
    });
    return Seller.fromJson(j as Map<String, dynamic>);
  }
}

final authApiProvider = Provider((ref) => AuthApi(ref.watch(apiProvider)));

// ---------------- Synced seller data ----------------

class SellerData {
  const SellerData({
    this.listings = const [],
    this.orders = const [],
    this.live = const [],
    this.payouts = const [],
    this.notices = const [],
    this.offers = const [],
    this.insights = const Insights(),
    this.syncedAt,
    this.syncing = false,
    this.error,
  });

  final List<Listing> listings;
  final List<SellerOrder> orders;
  final List<LiveCall> live;
  final List<Payout> payouts;
  final List<Notice> notices;
  final List<BuyerOffer> offers;
  final Insights insights;
  final DateTime? syncedAt;
  final bool syncing;

  /// Last sync error (e.g. server unreachable); data shown is from cache.
  final String? error;

  bool get loaded => syncedAt != null;

  SellerData copyWith({
    List<Listing>? listings,
    List<SellerOrder>? orders,
    List<LiveCall>? live,
    List<Payout>? payouts,
    List<Notice>? notices,
    List<BuyerOffer>? offers,
    Insights? insights,
    DateTime? syncedAt,
    bool? syncing,
    String? error,
    bool clearError = false,
  }) => SellerData(
    listings: listings ?? this.listings,
    orders: orders ?? this.orders,
    live: live ?? this.live,
    payouts: payouts ?? this.payouts,
    notices: notices ?? this.notices,
    offers: offers ?? this.offers,
    insights: insights ?? this.insights,
    syncedAt: syncedAt ?? this.syncedAt,
    syncing: syncing ?? this.syncing,
    error: clearError ? null : error ?? this.error,
  );

  Map<String, Object?> toJson() => {
    'listings': listings.map((e) => e.toJson()).toList(),
    'orders': orders.map((e) => e.toJson()).toList(),
    'live': live.map((e) => e.toJson()).toList(),
    'payouts': payouts.map((e) => e.toJson()).toList(),
    'notifications': notices.map((e) => e.toJson()).toList(),
    'offers': offers.map((e) => e.toJson()).toList(),
    'insights': insights.toJson(),
    'syncedAt': syncedAt?.toIso8601String(),
  };

  static List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) => [
    for (final e in (v as List? ?? const [])) f(e as Map<String, dynamic>),
  ];

  factory SellerData.fromJson(Map<String, dynamic> j) => SellerData(
    listings: _list(j['listings'], Listing.fromJson)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    orders: _list(j['orders'], SellerOrder.fromJson)
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
    live: _list(j['live'], LiveCall.fromJson),
    payouts: _list(j['payouts'], Payout.fromJson)
      ..sort((a, b) => b.at.compareTo(a.at)),
    notices: _list(j['notifications'], Notice.fromJson)
      ..sort((a, b) => b.at.compareTo(a.at)),
    offers: _list(j['offers'], BuyerOffer.new)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    insights: Insights.fromJson(
      (j['insights'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    syncedAt: j['syncedAt'] == null
        ? DateTime.now()
        : DateTime.parse(j['syncedAt'] as String),
  );
}

/// Holds everything the seller sees and performs every action through the
/// GAMEX server, then re-syncs. Polls every 20 seconds while signed in.
class SyncNotifier extends Notifier<SellerData> {
  Timer? _timer;
  Api get _api => ref.read(apiProvider);
  LocalStore get _store => ref.read(localStoreProvider);
  String? get _sid => ref.read(sellerProvider)?.id;

  @override
  SellerData build() {
    final sid = ref.watch(sellerProvider.select((s) => s?.id));
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (sid == null) return const SellerData();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    Future.microtask(refresh);
    return _store.readJson(
          _kCache,
          (j) => SellerData.fromJson(j as Map<String, dynamic>),
        ) ??
        const SellerData();
  }

  Future<void>? _inflight;

  /// Syncs with the server; concurrent calls share one request.
  Future<void> refresh() =>
      _inflight ??= _refresh().whenComplete(() => _inflight = null);

  Future<void> _refresh() async {
    final sid = _sid;
    if (sid == null) return;
    state = state.copyWith(syncing: true);
    try {
      final j =
          await _api.get('/seller/$sid/bootstrap') as Map<String, dynamic>;
      final seller = Seller.fromJson(j['seller'] as Map<String, dynamic>);
      if (_sid != sid) return;
      await ref.read(sellerProvider.notifier).set(seller);
      final data = SellerData.fromJson({...j, 'syncedAt': null});
      state = data;
      await _store.writeJson(_kCache, data.toJson());
    } on ApiException catch (e) {
      state = state.copyWith(syncing: false, error: e.message);
    } catch (_) {
      state = state.copyWith(syncing: false, error: 'Sync failed');
    }
  }

  Future<T> _do<T>(Future<T> Function(String sid) f) async {
    final sid = _sid;
    if (sid == null) throw const ApiException('Please sign in again');
    final r = await f(sid);
    // Wait for any older sync, then pull the result of this action.
    await _inflight;
    unawaited(refresh());
    return r;
  }

  // ----- Listings -----

  /// Uploads any local photos, then saves. [submit] sends it for QC.
  Future<Listing> saveListing(Listing l, {required bool submit}) =>
      _do((sid) async {
        final photos = <String>[];
        for (final p in l.photos) {
          final isServer = p.startsWith('/img/') || p.startsWith('/uploads/');
          photos.add(isServer ? p : await _api.upload(p));
        }
        final j = await _api.post('/seller/$sid/listings', {
          ...l.copyWith(photos: photos).toJson(),
          'submit': submit,
        });
        return Listing.fromJson(j as Map<String, dynamic>);
      });

  Future<void> _patchListing(String id, Map<String, Object> body) =>
      _do((sid) => _api.patch('/seller/$sid/listings/$id', body));

  Future<void> setStock(String id, int stock) {
    _local(id, (l) => l.copyWith(stock: stock));
    return _patchListing(id, {'stock': stock});
  }

  Future<void> setPrice(String id, int price) =>
      _patchListing(id, {'price': price});

  Future<void> setPaused(String id, bool paused) {
    _local(
      id,
      (l) => l.copyWith(
        status: paused ? ListingStatus.paused : ListingStatus.active,
      ),
    );
    return _patchListing(id, {'status': paused ? 'paused' : 'active'});
  }

  Future<void> deleteListing(String id) {
    state = state.copyWith(
      listings: state.listings.where((l) => l.id != id).toList(),
    );
    return _do((sid) => _api.delete('/seller/$sid/listings/$id'));
  }

  void _local(String id, Listing Function(Listing) f) => state = state.copyWith(
    listings: [
      for (final l in state.listings)
        if (l.id == id) f(l) else l,
    ],
  );

  // ----- Orders -----

  Future<void> orderAction(
    String id,
    String action, [
    Map<String, Object> body = const {},
  ]) => _do((sid) => _api.post('/seller/$sid/orders/$id/$action', body));

  Future<void> accept(String id) => orderAction(id, 'accept');
  Future<void> reject(String id, String reason) =>
      orderAction(id, 'reject', {'reason': reason});
  Future<void> pack(String id) => orderAction(id, 'pack');
  Future<void> ship(String id, String courier, DateTime pickup) => orderAction(
    id,
    'ship',
    {'courier': courier, 'pickupAt': pickup.toIso8601String()},
  );

  /// Open-box delivery: needs the 4-digit OTP from the buyer's app.
  Future<void> deliver(
    String id,
    String otp, {
    bool tradeInCollected = false,
  }) => orderAction(id, 'deliver', {
    'otp': otp,
    if (tradeInCollected) 'tradeInCollected': true,
  });

  // ----- Offers -----

  /// accept | reject | counter (with [amount]).
  Future<void> offerAction(
    String id,
    String action, {
    int? amount,
    String? reason,
  }) => _do(
    (sid) => _api.post('/seller/$sid/offers/$id/$action', {
      'amount': ?amount,
      'reason': ?reason,
    }),
  );

  Future<void> sendLiveMessage(String id, String text) =>
      _do((sid) => _api.post('/seller/$sid/live/$id/messages', {'text': text}));

  // ----- Live reviews -----

  Future<void> updateLive(String id, {LiveStage? stage, bool? converted}) {
    state = state.copyWith(
      live: [
        for (final c in state.live)
          if (c.id == id) c.copyWith(stage: stage, converted: converted) else c,
      ],
    );
    return _do(
      (sid) => _api.patch('/seller/$sid/live/$id', {
        'stage': ?stage?.name,
        'converted': ?converted,
      }),
    );
  }

  // ----- Money & account -----

  Future<Payout> withdraw() => _do((sid) async {
    final j = await _api.post('/seller/$sid/withdraw');
    return Payout.fromJson(j as Map<String, dynamic>);
  });

  Future<void> markNoticesRead() {
    state = state.copyWith(
      notices: [
        for (final n in state.notices)
          Notice(
            id: n.id,
            title: n.title,
            body: n.body,
            kind: n.kind,
            at: n.at,
            read: true,
          ),
      ],
    );
    return _do((sid) => _api.post('/seller/$sid/notifications/read'));
  }

  Future<void> updateSeller(Seller s) async {
    await ref.read(sellerProvider.notifier).set(s);
    await _do(
      (sid) => _api.put('/seller/$sid', {
        'storeName': s.storeName,
        'ownerName': s.ownerName,
        'gstin': s.gstin,
        'online': s.online,
      }),
    );
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SellerData>(
  SyncNotifier.new,
);

final listingsProvider = Provider<List<Listing>>(
  (ref) => ref.watch(syncProvider.select((d) => d.listings)),
);
final ordersProvider = Provider<List<SellerOrder>>(
  (ref) => ref.watch(syncProvider.select((d) => d.orders)),
);
final liveProvider = Provider<List<LiveCall>>(
  (ref) => ref.watch(syncProvider.select((d) => d.live)),
);
final payoutsProvider = Provider<List<Payout>>(
  (ref) => ref.watch(syncProvider.select((d) => d.payouts)),
);
final noticesProvider = Provider<List<Notice>>(
  (ref) => ref.watch(syncProvider.select((d) => d.notices)),
);

final offersProvider = Provider<List<BuyerOffer>>(
  (ref) => ref.watch(syncProvider).offers,
);

final pendingOffersProvider = Provider<int>(
  (ref) => ref.watch(offersProvider).where((o) => o.pending).length,
);

final listingByIdProvider = Provider.family<Listing?, String>(
  (ref, id) => ref.watch(listingsProvider).where((e) => e.id == id).firstOrNull,
);

final orderByIdProvider = Provider.family<SellerOrder?, String>(
  (ref, id) => ref.watch(ordersProvider).where((e) => e.id == id).firstOrNull,
);

class Earnings {
  const Earnings({
    required this.available,
    required this.pending,
    required this.paidOut,
    required this.grossMonth,
    required this.feesMonth,
    required this.ordersMonth,
  });
  final double available;
  final double pending;
  final double paidOut;
  final double grossMonth;
  final double feesMonth;
  final int ordersMonth;
}

/// Delivered orders settle 7 days after delivery (return window).
final earningsProvider = Provider<Earnings>((ref) {
  final orders = ref.watch(ordersProvider);
  final payouts = ref.watch(payoutsProvider);
  return computeEarnings(orders, payouts, DateTime.now());
});

Earnings computeEarnings(
  List<SellerOrder> orders,
  List<Payout> payouts,
  DateTime now,
) {
  var available = 0.0, pending = 0.0, gross = 0.0, fees = 0.0;
  var count = 0;
  final lastPayout = payouts.isEmpty
      ? DateTime(2000)
      : payouts.map((p) => p.at).reduce((a, b) => a.isAfter(b) ? a : b);
  for (final o in orders) {
    if (o.stage == OrderStage.delivered) {
      final deliveredAt = o.events.last.at;
      final settled = now.difference(deliveredAt).inDays >= 7;
      if (settled && deliveredAt.isAfter(lastPayout)) {
        available += o.payout;
      } else if (!settled) {
        pending += o.payout;
      }
    } else if (o.stage.open) {
      pending += o.payout;
    }
    if (o.stage != OrderStage.cancelled &&
        o.stage != OrderStage.returned &&
        now.difference(o.placedAt).inDays < 30) {
      gross += o.price;
      fees += Fees.totalFees(o.price);
      count++;
    }
  }
  return Earnings(
    available: available,
    pending: pending,
    paidOut: payouts.fold(0.0, (s, p) => s + p.amount),
    grossMonth: gross,
    feesMonth: fees,
    ordersMonth: count,
  );
}
