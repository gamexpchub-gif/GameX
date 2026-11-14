import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage.dart';
import 'models.dart';
import 'seed.dart';

const _kSeller = 'seller_v1';
const _kListings = 'listings_v1';
const _kOrders = 'orders_v1';
const _kLive = 'live_v1';
const _kPayouts = 'payouts_v1';

final _rand = Random();

List<T> _readList<T>(
  LocalStore s,
  String key,
  T Function(Map<String, dynamic>) parse,
) =>
    s.readJson(
      key,
      (j) => (j as List).map((e) => parse(e as Map<String, dynamic>)).toList(),
    ) ??
    const [];

// ---------------- Seller session ----------------

class SellerNotifier extends Notifier<Seller?> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  Seller? build() =>
      _s.readJson(_kSeller, (j) => Seller.fromJson(j as Map<String, dynamic>));

  Future<void> signIn(Seller seller) async {
    state = seller;
    await _s.writeJson(_kSeller, seller.toJson());
  }

  Future<void> save(Seller seller) => signIn(seller);

  Future<void> signOut() async {
    state = null;
    await _s.remove(_kSeller);
  }
}

final sellerProvider = NotifierProvider<SellerNotifier, Seller?>(
  SellerNotifier.new,
);

// ---------------- Listings ----------------

class ListingsNotifier extends Notifier<List<Listing>> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  List<Listing> build() {
    final saved = _readList(_s, _kListings, Listing.fromJson);
    if (saved.isNotEmpty) return saved;
    final seed = seedListings();
    _s.writeJson(_kListings, seed.map((e) => e.toJson()).toList());
    return seed;
  }

  void _set(List<Listing> v) {
    state = v;
    _s.writeJson(_kListings, v.map((e) => e.toJson()).toList());
  }

  String newId() => 'GXL${48000 + _rand.nextInt(90000)}';

  /// Adds or replaces [l]. Submitted listings go through a short QC review.
  Future<void> upsert(Listing l) async {
    final exists = state.any((e) => e.id == l.id);
    _set(
      exists
          ? [
              for (final e in state)
                if (e.id == l.id) l else e,
            ]
          : [l, ...state],
    );
    if (l.status == ListingStatus.inReview) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final cur = state.where((e) => e.id == l.id).firstOrNull;
      if (cur != null && cur.status == ListingStatus.inReview) {
        setStatus(l.id, ListingStatus.active);
      }
    }
  }

  void setStatus(String id, ListingStatus s) => _set([
    for (final e in state)
      if (e.id == id) e.copyWith(status: s) else e,
  ]);

  void setStock(String id, int stock) => _set([
    for (final e in state)
      if (e.id == id)
        e.copyWith(
          stock: stock,
          status: stock == 0
              ? ListingStatus.soldOut
              : e.status == ListingStatus.soldOut
              ? ListingStatus.active
              : e.status,
        )
      else
        e,
  ]);

  void setPrice(String id, int price) => _set([
    for (final e in state)
      if (e.id == id) e.copyWith(price: price) else e,
  ]);

  void remove(String id) => _set(state.where((e) => e.id != id).toList());
}

final listingsProvider = NotifierProvider<ListingsNotifier, List<Listing>>(
  ListingsNotifier.new,
);

final listingByIdProvider = Provider.family<Listing?, String>(
  (ref, id) => ref.watch(listingsProvider).where((e) => e.id == id).firstOrNull,
);

// ---------------- Orders ----------------

class OrdersNotifier extends Notifier<List<SellerOrder>> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  List<SellerOrder> build() {
    final saved = _readList(_s, _kOrders, SellerOrder.fromJson);
    if (saved.isNotEmpty) return saved;
    final seed = seedOrders(ref.read(listingsProvider));
    _s.writeJson(_kOrders, seed.map((e) => e.toJson()).toList());
    return seed;
  }

  void _patch(String id, SellerOrder Function(SellerOrder) f) {
    state = [
      for (final o in state)
        if (o.id == id) f(o) else o,
    ];
    _s.writeJson(_kOrders, state.map((e) => e.toJson()).toList());
  }

  List<OrderEvent> _ev(SellerOrder o, String label) => [
    ...o.events,
    OrderEvent(label, DateTime.now()),
  ];

  void accept(String id) => _patch(
    id,
    (o) => o.copyWith(
      stage: OrderStage.accepted,
      events: _ev(o, 'Accepted by you'),
    ),
  );

  void reject(String id, String reason) {
    _patch(
      id,
      (o) => o.copyWith(
        stage: OrderStage.cancelled,
        cancelReason: reason,
        events: _ev(o, 'Rejected by seller • $reason'),
      ),
    );
  }

  void pack(String id) => _patch(
    id,
    (o) => o.copyWith(
      stage: OrderStage.packed,
      imeiVerified: true,
      events: _ev(o, 'Packed • IMEI verified'),
    ),
  );

  void ship(String id, String courier, DateTime pickup) {
    final awb =
        '${courier.substring(0, 2).toUpperCase()}${9100000000 + _rand.nextInt(99999999)}';
    _patch(
      id,
      (o) => o.copyWith(
        stage: OrderStage.shipped,
        courier: courier,
        awb: awb,
        pickupAt: pickup,
        events: _ev(o, 'Handed to $courier • AWB $awb'),
      ),
    );
  }

  void deliver(String id) => _patch(
    id,
    (o) => o.copyWith(stage: OrderStage.delivered, events: _ev(o, 'Delivered')),
  );
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<SellerOrder>>(
  OrdersNotifier.new,
);

final orderByIdProvider = Provider.family<SellerOrder?, String>(
  (ref, id) => ref.watch(ordersProvider).where((e) => e.id == id).firstOrNull,
);

// ---------------- Live review calls ----------------

class LiveNotifier extends Notifier<List<LiveCall>> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  List<LiveCall> build() {
    final saved = _readList(_s, _kLive, LiveCall.fromJson);
    if (saved.isNotEmpty) return saved;
    final seed = seedLive(ref.read(listingsProvider));
    _s.writeJson(_kLive, seed.map((e) => e.toJson()).toList());
    return seed;
  }

  void patch(String id, LiveCall Function(LiveCall) f) {
    state = [
      for (final c in state)
        if (c.id == id) f(c) else c,
    ];
    _s.writeJson(_kLive, state.map((e) => e.toJson()).toList());
  }
}

final liveProvider = NotifierProvider<LiveNotifier, List<LiveCall>>(
  LiveNotifier.new,
);

// ---------------- Payouts & earnings ----------------

class PayoutsNotifier extends Notifier<List<Payout>> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  List<Payout> build() {
    final saved = _readList(_s, _kPayouts, Payout.fromJson);
    if (saved.isNotEmpty) return saved;
    final seed = seedPayouts();
    _s.writeJson(_kPayouts, seed.map((e) => e.toJson()).toList());
    return seed;
  }

  void add(Payout p) {
    state = [p, ...state];
    _s.writeJson(_kPayouts, state.map((e) => e.toJson()).toList());
  }
}

final payoutsProvider = NotifierProvider<PayoutsNotifier, List<Payout>>(
  PayoutsNotifier.new,
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
  final now = DateTime.now();
  var available = 0.0, pending = 0.0, gross = 0.0, fees = 0.0;
  var count = 0;
  final lastPayout = payouts.isEmpty ? DateTime(2000) : payouts.first.at;
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
});
