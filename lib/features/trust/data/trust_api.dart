import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/api_product_repository.dart';
import '../../auth/providers/auth_provider.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// A GAMEX QC certificate looked up by its number (or from a QR code).
class CertificateInfo {
  const CertificateInfo(this.j);
  final Map<String, dynamic> j;

  String get certificate => j['certificate'] as String;
  String get listingId => j['listingId'] as String;
  bool get live => j['live'] == true;
  String get title => '${j['brand']} ${j['model']}';
  String get memory => '${j['ram']} / ${j['storage']}';
  String get color => j['color'] as String? ?? '';
  String get grade => j['grade'] as String? ?? 'excellent';
  int get battery => (j['battery'] as num?)?.toInt() ?? 0;
  String get imei => j['imei'] as String? ?? '';
  int get warranty => (j['warranty'] as num?)?.toInt() ?? 0;
  String get photo => j['photo'] as String? ?? '';
  bool get blacklisted => j['blacklisted'] == true;
  Map<String, bool> get checks =>
      Map<String, bool>.from(j['checks'] as Map? ?? const {});
  String? get qcBy => (j['qc'] as Map?)?['by'] as String?;
  DateTime? get qcAt => _date((j['qc'] as Map?)?['at']);
  String? get sellerName => (j['seller'] as Map?)?['storeName'] as String?;
  String? get sellerCity => (j['seller'] as Map?)?['city'] as String?;
  String? get sellerId => (j['seller'] as Map?)?['id'] as String?;
}

/// Result of an IMEI lookup.
class ImeiResult {
  const ImeiResult(this.j);
  final Map<String, dynamic> j;

  String get imei => j['imei'] as String;
  bool get validChecksum => j['validChecksum'] == true;
  bool get blacklisted => j['blacklisted'] == true;
  String? get blacklistReason => j['blacklistReason'] as String?;
  DateTime? get reportedAt => _date(j['reportedAt']);
  Map<String, dynamic>? get gamex =>
      (j['gamex'] as Map?)?.cast<String, dynamic>();
  bool get safe => validChecksum && !blacklisted;
}

/// Public seller profile.
class SellerProfile {
  const SellerProfile(this.j, this.listings);
  final Map<String, dynamic> j;
  final List<Product> listings;

  String get id => j['id'] as String;
  String get storeName => j['storeName'] as String;
  String get ownerName => j['ownerName'] as String? ?? '';
  String get city => j['city'] as String? ?? '';
  double get rating => (j['rating'] as num?)?.toDouble() ?? 0;
  DateTime? get since => _date(j['since']);
  bool get verified => j['verified'] == true;
  bool get gst => j['gst'] == true;
  int get sold => (j['sold'] as num?)?.toInt() ?? 0;
  int get delivered => (j['delivered'] as num?)?.toInt() ?? 0;
  int? get responseMins => (j['responseMins'] as num?)?.toInt();
  double get cancelRate => (j['cancelRate'] as num?)?.toDouble() ?? 0;
}

/// Live server view of one marketplace order item.
class OrderTrack {
  const OrderTrack(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get orderId => j['orderId'] as String;
  String get listingId => j['listingId'] as String? ?? '';
  String get item => j['item'] as String? ?? '';
  String get variant => j['variant'] as String? ?? '';
  String get photo => j['photo'] as String? ?? '';
  int get price => (j['price'] as num?)?.toInt() ?? 0;
  String get stage => j['stage'] as String? ?? 'newOrder';
  String? get awb => j['awb'] as String?;
  String? get courier => j['courier'] as String?;
  String? get otp => j['otp'] as String?;
  DateTime? get deliveredAt => _date(j['deliveredAt']);
  int get returnDays => (j['returnDays'] as num?)?.toInt() ?? 7;
  int get warrantyMonths => (j['warrantyMonths'] as num?)?.toInt() ?? 0;
  String? get imei => j['imei'] as String?;
  String? get certificate => j['certificate'] as String?;
  Map<String, dynamic>? get returnRequest =>
      (j['returnRequest'] as Map?)?.cast<String, dynamic>();
  List<Map<String, dynamic>> get claims => [
    for (final c in (j['claims'] as List? ?? const []))
      (c as Map).cast<String, dynamic>(),
  ];
  String? get sellerName => (j['seller'] as Map?)?['storeName'] as String?;
  String? get sellerId => (j['seller'] as Map?)?['id'] as String?;
  List<({String label, DateTime at})> get events => [
    for (final e in (j['events'] as List? ?? const []))
      (label: (e as Map)['l'] as String, at: DateTime.parse(e['a'] as String)),
  ];

  bool get delivered => stage == 'delivered';
  bool get outForDelivery => stage == 'shipped';

  DateTime? get returnUntil => deliveredAt?.add(Duration(days: returnDays));
  bool get canReturn {
    final until = returnUntil;
    final r = returnRequest;
    return delivered &&
        returnDays > 0 &&
        until != null &&
        DateTime.now().isBefore(until) &&
        (r == null || r['status'] == 'rejected');
  }

  DateTime? get warrantyUntil {
    final d = deliveredAt;
    if (d == null || warrantyMonths == 0) return null;
    return DateTime(d.year, d.month + warrantyMonths, d.day, d.hour, d.minute);
  }

  bool get warrantyActive {
    final u = warrantyUntil;
    return u != null && DateTime.now().isBefore(u);
  }

  Map<String, dynamic>? get openClaim {
    for (final c in claims) {
      if (c['status'] == 'submitted' || c['status'] == 'approved') return c;
    }
    return null;
  }
}

/// Chat thread for a live review request.
class ChatThread {
  const ChatThread(this.j);
  final Map<String, dynamic> j;

  String get item => j['item'] as String? ?? '';
  String get photo => j['photo'] as String? ?? '';
  String get stage => j['stage'] as String? ?? 'pending';
  String? get sellerName => (j['seller'] as Map?)?['storeName'] as String?;
  List<({bool mine, String text, DateTime at})> get messages => [
    for (final m in (j['messages'] as List? ?? const []))
      (
        mine: (m as Map)['from'] == 'buyer',
        text: m['text'] as String,
        at: DateTime.parse(m['at'] as String),
      ),
  ];
}

class TrustApi {
  TrustApi(this._api, this._ref);
  final Api _api;
  final Ref _ref;

  String media(String path) => _api.media(path);

  /// Server photo path → something [AppImage] can show.
  String image(String path) {
    if (path.startsWith('/img/')) {
      return 'asset:assets/images/home/${path.substring(5)}';
    }
    if (path.startsWith('/')) return _api.media(path);
    return path;
  }

  Future<CertificateInfo> certificate(String code) async => CertificateInfo(
    await _api.get('/certificates/${Uri.encodeComponent(code.trim())}')
        as Map<String, dynamic>,
  );

  Future<ImeiResult> checkImei(String imei) async =>
      ImeiResult(await _api.get('/imei/$imei') as Map<String, dynamic>);

  Future<SellerProfile> seller(String id) async {
    final j = await _api.get('/sellers/$id/public') as Map<String, dynamic>;
    final repo = ApiProductRepository(_api);
    return SellerProfile(j, [
      for (final l in (j['listings'] as List? ?? const []))
        repo.productFromJson(l as Map<String, dynamic>),
    ]);
  }

  Future<List<OrderTrack>> track(String orderId) async {
    final list = await _api.get(
      '/orders/status?ids=${Uri.encodeComponent(orderId)}',
    ) as List;
    return [for (final e in list) OrderTrack(e as Map<String, dynamic>)];
  }

  Future<void> refuse(String itemId, String reason) =>
      _api.post('/orders/$itemId/refuse', {'reason': reason});

  Future<void> requestReturn(
    String itemId, {
    required String reason,
    required String details,
    required String pickupSlot,
  }) => _api.post('/returns', {
    'orderId': itemId,
    'reason': reason,
    'details': details,
    'pickupSlot': pickupSlot,
  });

  Future<void> claimWarranty(
    String itemId, {
    required String issue,
    required String description,
  }) => _api.post('/warranty-claims', {
    'orderId': itemId,
    'issue': issue,
    'description': description,
    'customerId': _ref.read(authProvider)?.id,
  });

  Future<ChatThread> chat(String liveId) async => ChatThread(
    await _api.get('/live/$liveId/messages') as Map<String, dynamic>,
  );

  Future<ChatThread> sendChat(String liveId, String text) async => ChatThread(
    await _api.post('/live/$liveId/messages', {'text': text})
        as Map<String, dynamic>,
  );
}

final trustApiProvider = Provider(
  (ref) => TrustApi(ref.watch(apiProvider), ref),
);

final certificateProvider = FutureProvider.autoDispose
    .family<CertificateInfo, String>(
      (ref, code) => ref.watch(trustApiProvider).certificate(code),
    );

final sellerProfileProvider = FutureProvider.autoDispose
    .family<SellerProfile, String>(
      (ref, id) => ref.watch(trustApiProvider).seller(id),
    );

final orderTrackProvider = FutureProvider.autoDispose
    .family<List<OrderTrack>, String>(
      (ref, orderId) => ref.watch(trustApiProvider).track(orderId),
    );
