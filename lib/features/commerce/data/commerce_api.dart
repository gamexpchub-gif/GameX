import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../core/storage.dart';
import '../../../data/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import 'tradein.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

// ───────────────────────────── Promotions ─────────────────────────────

class BankOffer {
  const BankOffer(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get bank => j['bank'] as String;

  /// card | emi | any
  String get kind => j['kind'] as String? ?? 'card';
  String get text => j['text'] as String;
  double get percent => _num(j['percent']);
  double get flat => _num(j['flat']);
  double get maxOff => _num(j['maxOff']);
  double get minOrder => _num(j['minOrder']);

  bool appliesTo({required bool emi}) =>
      kind == 'any' || (emi ? kind == 'emi' : kind == 'card');

  double discountOn(double amount) {
    if (amount < minOrder) return 0;
    final raw = flat > 0 ? flat : amount * percent / 100;
    return (maxOff > 0 && raw > maxOff ? maxOff : raw).roundToDouble();
  }
}

class FestivalSale {
  const FestivalSale(this.j);
  final Map<String, dynamic> j;
  bool get active => j['active'] == true;
  String get title => j['title'] as String? ?? 'GAMEX Sale';
  String get subtitle => j['subtitle'] as String? ?? '';
  DateTime get startsAt => _date(j['startsAt']) ?? DateTime(2000);
  DateTime get endsAt => _date(j['endsAt']) ?? DateTime(2000);
  double get extraOffPercent => _num(j['extraOffPercent']);
  double get maxExtraOff => _num(j['maxExtraOff']);

  bool get live {
    final n = DateTime.now();
    return active && n.isAfter(startsAt) && n.isBefore(endsAt);
  }

  bool get upcoming => active && DateTime.now().isBefore(startsAt);

  /// Extra festival discount on flash-sale items worth [amount].
  double discountOn(double amount) {
    if (!live || amount <= 0) return 0;
    final raw = amount * extraOffPercent / 100;
    return (maxExtraOff > 0 && raw > maxExtraOff ? maxExtraOff : raw)
        .roundToDouble();
  }
}

class Promo {
  const Promo(this.j);
  final Map<String, dynamic> j;

  FestivalSale get sale =>
      FestivalSale(j['sale'] as Map<String, dynamic>? ?? const {});
  List<BankOffer> get bankOffers => [
    for (final b in (j['bankOffers'] as List? ?? const []))
      BankOffer(b as Map<String, dynamic>),
  ];
  double get referrerBonus => _num((j['referral'] as Map?)?['referrerBonus']);
  double get friendBonus => _num((j['referral'] as Map?)?['friendBonus']);
  double get cashbackRate => _num(j['cashbackRate']);
  double get cashbackCap => _num(j['cashbackCap']);
  double get walletMaxPercent => _num(j['walletMaxPercent']);
  double get exchangeBonus => _num(j['exchangeBonus']);

  /// Same defaults as the server, used when it can't be reached.
  static Promo fallback() {
    final now = DateTime.now();
    return Promo({
      'sale': {
        'active': true,
        'title': 'Diwali Dhamaka Sale',
        'subtitle': 'Extra 5% off on flash deals • Bank offers • No-cost EMI',
        'startsAt': now.subtract(const Duration(hours: 6)).toIso8601String(),
        'endsAt': DateTime(now.year, now.month, now.day + 3).toIso8601String(),
        'extraOffPercent': 5,
        'maxExtraOff': 3000,
      },
      'bankOffers': [
        {
          'id': 'BO1',
          'bank': 'HDFC Bank',
          'kind': 'card',
          'text': '10% instant discount on credit cards',
          'percent': 10,
          'flat': 0,
          'maxOff': 3000,
          'minOrder': 20000,
        },
        {
          'id': 'BO2',
          'bank': 'ICICI Bank',
          'kind': 'emi',
          'text': '7.5% off on credit card EMI',
          'percent': 7.5,
          'flat': 0,
          'maxOff': 2500,
          'minOrder': 25000,
        },
        {
          'id': 'BO3',
          'bank': 'SBI Card',
          'kind': 'card',
          'text': 'Flat ₹1,500 off on SBI credit cards',
          'percent': 0,
          'flat': 1500,
          'maxOff': 1500,
          'minOrder': 30000,
        },
        {
          'id': 'BO4',
          'bank': 'Axis Bank',
          'kind': 'any',
          'text': '5% off on cards & EMI',
          'percent': 5,
          'flat': 0,
          'maxOff': 2000,
          'minOrder': 15000,
        },
      ],
      'referral': {'referrerBonus': 500, 'friendBonus': 250},
      'cashbackRate': 0.02,
      'cashbackCap': 1500,
      'walletMaxPercent': 20,
      'exchangeBonus': 1000,
    });
  }
}

// ───────────────────────────── Wallet ─────────────────────────────

class WalletTx {
  const WalletTx(this.j);
  final Map<String, dynamic> j;
  double get amount => _num(j['amount']);
  String get kind => j['kind'] as String? ?? '';
  String get status => j['status'] as String? ?? 'available';
  String get label => j['label'] as String? ?? '';
  DateTime get at => _date(j['at']) ?? DateTime.now();
  DateTime? get releaseAt => _date(j['releaseAt']);
}

class Wallet {
  const Wallet(this.j);
  final Map<String, dynamic> j;
  double get balance => _num(j['balance']);
  double get pending => _num(j['pending']);
  String get referralCode => j['referralCode'] as String? ?? '';
  String? get referredBy => j['referredBy'] as String?;
  List<WalletTx> get tx => [
    for (final t in (j['tx'] as List? ?? const []))
      if ((t as Map)['status'] != 'void') WalletTx(t as Map<String, dynamic>),
  ];
  List<Map<String, dynamic>> get friends =>
      (j['friends'] as List? ?? const []).cast<Map<String, dynamic>>();
}

// ───────────────────────────── Offers ─────────────────────────────

/// A Make-an-Offer negotiation on one phone.
class PriceOffer {
  const PriceOffer(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get listingId => j['listingId'] as String;

  /// pending | countered | accepted | rejected | expired | withdrawn | used
  String get status => j['status'] as String;
  double get amount => _num(j['amount']);
  double get listPrice => _num(j['listPrice']);
  double? get counter => j['counter'] == null ? null : _num(j['counter']);
  double? get dealPrice => j['dealPrice'] == null ? null : _num(j['dealPrice']);
  String get note => j['note'] as String? ?? '';
  DateTime get createdAt => _date(j['createdAt']) ?? DateTime.now();
  DateTime? get expiresAt => _date(j['expiresAt']);
  DateTime? get dealExpiresAt => _date(j['dealExpiresAt']);
  String get title =>
      (j['listing'] as Map?)?['title'] as String? ??
      j['title'] as String? ??
      'Phone';
  String? get photo =>
      (j['listing'] as Map?)?['photo'] as String? ?? j['photo'] as String?;
  bool get local => j['local'] == true;
  List<(String, DateTime)> get events => [
    for (final e in (j['events'] as List? ?? const []).cast<Map>())
      (e['l'] as String, _date(e['a']) ?? DateTime.now()),
  ];

  bool get open => status == 'pending' || status == 'countered';
  bool get canBuy =>
      status == 'accepted' &&
      (dealExpiresAt == null || DateTime.now().isBefore(dealExpiresAt!));
}

// ───────────────────────────── Alerts & notifications ─────────────────

class StockAlert {
  const StockAlert(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get listingId => j['listingId'] as String;

  /// price | stock
  String get type => j['type'] as String;
  String get title => j['title'] as String? ?? '';
  double get priceAtSet => _num(j['priceAtSet']);
  double? get targetPrice =>
      j['targetPrice'] == null ? null : _num(j['targetPrice']);
  bool get local => j['local'] == true;
}

class CustomerNotif {
  const CustomerNotif(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get title => j['title'] as String;
  String get body => j['body'] as String? ?? '';
  String get kind => j['kind'] as String? ?? 'info';
  String get link => j['link'] as String? ?? '';
  DateTime get at => _date(j['at']) ?? DateTime.now();
  bool get read => j['read'] == true;
}

// ───────────────────────────── API ─────────────────────────────

/// Talks to the GAMEX server for growth features. Phones from the built-in
/// catalogue (ids without the GXL prefix) are handled locally by "GAMEX
/// Official", so every feature also works offline.
class CommerceApi {
  CommerceApi(this._api, this._ref);
  final Api _api;
  final Ref _ref;

  LocalStore get _store => _ref.read(localStoreProvider);
  String? get customerId => _ref.read(authProvider)?.id;
  String get customerName => _ref.read(authProvider)?.name ?? 'Customer';

  static bool isServerListing(String id) => id.startsWith('GXL');

  /// Server photo path → something AppImage can show.
  String image(String path) {
    if (path.startsWith('/img/')) {
      return 'asset:assets/images/home/${path.substring(5)}';
    }
    if (path.startsWith('/')) return _api.media(path);
    return path;
  }

  Future<Promo> promo() async {
    try {
      return Promo(await _api.get('/promo') as Map<String, dynamic>);
    } catch (_) {
      return Promo.fallback();
    }
  }

  // ── Trade-in ──
  Future<TradeInQuote> quote(
    TradeInDevice d, {
    double newPhonePrice = 0,
  }) async {
    try {
      final j = await _api.post('/trade-in/quote', {
        ...d.toJson(),
        'customerId': customerId ?? 'guest',
        'newPhonePrice': newPhonePrice,
      }) as Map<String, dynamic>;
      return TradeInQuote(
        device: d,
        amount: _num(j['amount']),
        lines: [
          for (final l in (j['lines'] as List).cast<Map>())
            QuoteLine(l['label'] as String, _num(l['amount'])),
        ],
        expiresAt:
            _date(j['expiresAt']) ??
            DateTime.now().add(const Duration(days: 7)),
        serverId: j['id'] as String?,
      );
    } catch (_) {
      // Server unreachable or not updated yet: quote with the same rules
      // locally. The pickup agent confirms the value at the door.
    }
    {
      final q = localQuote(d, newPhonePrice: newPhonePrice);
      if (q == null) throw const ApiException('We do not buy this model yet');
      return TradeInQuote(
        device: d,
        amount: q.$1,
        lines: q.$2,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
    }
  }

  // ── Wallet & referral ──
  Future<Wallet?> wallet() async {
    final id = customerId;
    if (id == null) return null;
    return Wallet(await _api.get('/wallet/$id') as Map<String, dynamic>);
  }

  Future<void> applyReferral(String code) async {
    final id = customerId;
    if (id == null) throw const ApiException('Log in to use a referral code');
    await _api.post('/referrals/apply', {
      'customerId': id,
      'code': code.trim().toUpperCase(),
    });
  }

  // ── Offers ──
  static const _localOffers = 'local_offers_v1';

  List<Map<String, dynamic>> _readLocal(String key) =>
      _store.readJson(key, (j) => (j as List).cast<Map<String, dynamic>>()) ??
      <Map<String, dynamic>>[];

  Future<List<PriceOffer>> offers() async {
    final local = [for (final j in _readLocal(_localOffers)) PriceOffer(j)];
    final id = customerId;
    if (id == null) return local;
    try {
      final list = await _api.get('/offers?customerId=$id') as List;
      return [
        for (final j in list) PriceOffer(j as Map<String, dynamic>),
        ...local,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return local;
    }
  }

  Future<PriceOffer> makeOffer(
    Product p,
    double amount, {
    String note = '',
  }) async {
    if (isServerListing(p.id)) {
      if (customerId == null) {
        throw const ApiException('Log in to make an offer');
      }
      return PriceOffer(
        await _api.post('/offers', {
          'listingId': p.id,
          'customer': {'id': customerId, 'name': customerName},
          'amount': amount.round(),
          'note': note,
        }) as Map<String, dynamic>,
      );
    }
    // GAMEX Official decides instantly.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final ratio = amount / p.price;
    if (ratio >= 1) {
      throw const ApiException('Offer must be below the current price');
    }
    if (ratio < 0.7) {
      throw ApiException(
        'Offers below ${(p.price * 0.7 / 100).round() * 100} are not accepted for this phone',
      );
    }
    final n = DateTime.now();
    String status;
    double? counter;
    double? deal;
    if (ratio >= 0.95) {
      status = 'accepted';
      deal = amount.roundToDouble();
    } else {
      status = 'countered';
      final mid = ratio >= 0.85 ? (amount + p.price) / 2 : p.price * 0.93;
      counter = ((mid / 100).round() * 100 - 1).toDouble();
      if (counter <= amount) counter = amount + 99;
    }
    final j = {
      'id': 'LOF${n.millisecondsSinceEpoch}',
      'local': true,
      'listingId': p.id,
      'title': p.name,
      'photo': p.images.first,
      'listPrice': p.price,
      'amount': amount.round(),
      'counter': counter,
      'dealPrice': deal,
      'note': note,
      'status': status,
      'createdAt': n.toIso8601String(),
      'expiresAt': n.add(const Duration(days: 1)).toIso8601String(),
      'dealExpiresAt': deal == null
          ? null
          : n.add(const Duration(days: 2)).toIso8601String(),
      'events': [
        {'l': 'Offered ₹${amount.round()}', 'a': n.toIso8601String()},
        {
          'l': status == 'accepted'
              ? 'GAMEX accepted'
              : 'GAMEX countered ₹${counter!.round()}',
          'a': n.toIso8601String(),
        },
      ],
    };
    await _store.writeJson(_localOffers, [j, ..._readLocal(_localOffers)]);
    return PriceOffer(j);
  }

  Future<PriceOffer> respond(PriceOffer o, String action) async {
    if (!o.local) {
      return PriceOffer(
        await _api.post('/offers/${o.id}/respond', {
          'customerId': customerId,
          'action': action,
        }) as Map<String, dynamic>,
      );
    }
    final all = _readLocal(_localOffers);
    final i = all.indexWhere((x) => x['id'] == o.id);
    if (i < 0) throw const ApiException('Offer not found');
    final j = Map<String, dynamic>.from(all[i]);
    final n = DateTime.now();
    final events = [...(j['events'] as List)];
    switch (action) {
      case 'accept':
        j['status'] = 'accepted';
        j['dealPrice'] = j['counter'];
        j['dealExpiresAt'] = n.add(const Duration(days: 2)).toIso8601String();
        events.add({
          'l': 'You accepted ₹${(j['counter'] as num).round()}',
          'a': n.toIso8601String(),
        });
      case 'reject':
        j['status'] = 'rejected';
        events.add({'l': 'You declined the counter', 'a': n.toIso8601String()});
      default:
        j['status'] = 'withdrawn';
        events.add({'l': 'Withdrawn', 'a': n.toIso8601String()});
    }
    j['events'] = events;
    all[i] = j;
    await _store.writeJson(_localOffers, all);
    return PriceOffer(j);
  }

  /// Marks a local deal as used after checkout.
  Future<void> markOfferUsed(String id) async {
    final all = _readLocal(_localOffers);
    for (final j in all) {
      if (j['id'] == id) j['status'] = 'used';
    }
    await _store.writeJson(_localOffers, all);
  }

  // ── Alerts ──
  static const _localAlerts = 'local_alerts_v1';

  Future<List<StockAlert>> alerts() async {
    final local = [for (final j in _readLocal(_localAlerts)) StockAlert(j)];
    final id = customerId;
    if (id == null) return local;
    try {
      final list = await _api.get('/alerts?customerId=$id') as List;
      return [
        for (final j in list) StockAlert(j as Map<String, dynamic>),
        ...local,
      ];
    } catch (_) {
      return local;
    }
  }

  Future<void> setAlert(Product p, String type, {double? target}) async {
    if (isServerListing(p.id) && customerId != null) {
      await _api.post('/alerts', {
        'customerId': customerId,
        'listingId': p.id,
        'type': type,
        'targetPrice': target?.round(),
      });
      return;
    }
    final all = _readLocal(_localAlerts)
      ..removeWhere((j) => j['listingId'] == p.id && j['type'] == type);
    all.insert(0, {
      'id': 'LAL${DateTime.now().millisecondsSinceEpoch}',
      'local': true,
      'listingId': p.id,
      'type': type,
      'title': p.name,
      'priceAtSet': p.price,
      'targetPrice': target,
    });
    await _store.writeJson(_localAlerts, all);
  }

  Future<void> removeAlert(StockAlert a) async {
    if (!a.local) {
      await _api.delete('/alerts/${a.id}?customerId=$customerId');
      return;
    }
    await _store.writeJson(
      _localAlerts,
      _readLocal(_localAlerts)..removeWhere((j) => j['id'] == a.id),
    );
  }

  // ── Notifications & push ──
  Future<List<CustomerNotif>> notifications({DateTime? since}) async {
    final id = customerId;
    if (id == null) return const [];
    final q = since == null
        ? ''
        : '?since=${Uri.encodeComponent(since.toUtc().toIso8601String())}';
    final list = await _api.get('/customers/$id/notifications$q') as List;
    return [for (final j in list) CustomerNotif(j as Map<String, dynamic>)];
  }

  Future<void> markNotificationsRead() async {
    final id = customerId;
    if (id != null) await _api.post('/customers/$id/notifications/read');
  }

  Future<void> registerPushToken(String token, String platform) async {
    final id = customerId;
    if (id != null) {
      await _api.post('/push/register', {
        'customerId': id,
        'token': token,
        'platform': platform,
      });
    }
  }

  String encode(Object o) => jsonEncode(o);
}

final commerceApiProvider = Provider<CommerceApi>(
  (ref) => CommerceApi(ref.watch(apiProvider), ref),
);

final promotionsProvider = FutureProvider<Promo>(
  (ref) => ref.watch(commerceApiProvider).promo(),
);

final walletProvider = FutureProvider.autoDispose<Wallet?>((ref) {
  ref.watch(authProvider);
  return ref.watch(commerceApiProvider).wallet();
});

final myOffersProvider = FutureProvider.autoDispose<List<PriceOffer>>((ref) {
  ref.watch(authProvider);
  return ref.watch(commerceApiProvider).offers();
});

final myAlertsProvider = FutureProvider.autoDispose<List<StockAlert>>((ref) {
  ref.watch(authProvider);
  return ref.watch(commerceApiProvider).alerts();
});
