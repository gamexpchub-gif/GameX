import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../auth/providers/auth_provider.dart';
import '../../commerce/data/tradein.dart';

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// Repair services (mirrors server/src/service.js REPAIRS).
class RepairService {
  const RepairService(
    this.id,
    this.label,
    this.rate,
    this.min,
    this.max,
    this.hours,
    this.hint,
  );
  final String id;
  final String label;
  final double rate;
  final double min;
  final double max;
  final int hours;
  final String hint;
}

const kRepairs = [
  RepairService(
    'screen',
    'Screen replacement',
    0.32,
    1999,
    24999,
    3,
    'Cracked, lines, touch not working',
  ),
  RepairService(
    'battery',
    'Battery replacement',
    0.08,
    1299,
    6999,
    1,
    'Drains fast, health below 80%',
  ),
  RepairService(
    'backGlass',
    'Back glass',
    0.14,
    1499,
    12999,
    3,
    'Cracked back panel',
  ),
  RepairService(
    'charging',
    'Charging port',
    0.05,
    999,
    3499,
    2,
    'Loose cable, slow or no charging',
  ),
  RepairService(
    'camera',
    'Camera',
    0.16,
    1499,
    14999,
    2,
    'Blurry, black screen, cracked lens',
  ),
  RepairService(
    'speaker',
    'Speaker / mic',
    0.05,
    899,
    2999,
    1,
    'Low sound, people can\'t hear you',
  ),
  RepairService(
    'water',
    'Water damage check',
    0,
    499,
    499,
    24,
    'Dropped in water, not turning on',
  ),
  RepairService(
    'other',
    'Other / diagnosis',
    0,
    299,
    299,
    24,
    'Not sure what\'s wrong',
  ),
];

class RepairQuote {
  const RepairQuote(
    this.service,
    this.quality,
    this.price,
    this.warrantyMonths,
  );
  final RepairService service;

  /// original | compatible
  final String quality;
  final double price;
  final int warrantyMonths;
}

RepairQuote? repairQuote(
  String brand,
  String model,
  String issue,
  String quality,
) {
  final r = kRepairs.where((x) => x.id == issue).firstOrNull;
  if (r == null) return null;
  final base = kTradeInModels[brand]?[model] ?? 15000;
  var price = (base * 2.4 * r.rate).clamp(r.min, r.max).toDouble();
  if (quality == 'compatible' && r.rate > 0) {
    price = math.max(r.min * 0.7, price * 0.65);
  }
  return RepairQuote(
    r,
    quality,
    ((price / 100).ceil() * 100 - 1).toDouble(),
    quality == 'original' ? 6 : 3,
  );
}

/// Repair booking or sell request as returned by the server.
class ServiceJob {
  const ServiceJob(this.j);
  final Map<String, dynamic> j;
  String get id => j['id'] as String;
  String get status => j['status'] as String;
  String get model =>
      j['model'] as String? ?? (j['device'] as Map?)?['model'] as String? ?? '';
  String get title =>
      j['label'] as String? ?? 'Sell ${(j['device'] as Map?)?['model'] ?? ''}';
  double get amount =>
      ((j['finalAmount'] ?? j['price'] ?? j['quote']) as num?)?.toDouble() ?? 0;
  DateTime get slot => _d(j['slot']) ?? DateTime.now();
  DateTime get createdAt => _d(j['createdAt']) ?? DateTime.now();
  String get mode => j['mode'] as String? ?? 'pickup';
  List<(String, DateTime)> get events => [
    for (final e in (j['events'] as List? ?? const []).cast<Map>())
      (e['l'] as String, _d(e['a']) ?? DateTime.now()),
  ];
  bool get cancellable =>
      const {'booked', 'assigned', 'requested', 'scheduled'}.contains(status);
}

class ServiceApi {
  ServiceApi(this._api, this._ref);
  final Api _api;
  final Ref _ref;

  String get _cid {
    final id = _ref.read(authProvider)?.id;
    if (id == null) throw const ApiException('Please log in first');
    return id;
  }

  Future<ServiceJob> bookRepair(Map<String, dynamic> body) async => ServiceJob(
    await _api.post('/repairs', {...body, 'customerId': _cid})
        as Map<String, dynamic>,
  );

  Future<List<ServiceJob>> repairs() async => [
    for (final j in await _api.get('/repairs?customerId=$_cid') as List)
      ServiceJob(j as Map<String, dynamic>),
  ];

  Future<ServiceJob> sell(Map<String, dynamic> body) async => ServiceJob(
    await _api.post('/sell-requests', {...body, 'customerId': _cid})
        as Map<String, dynamic>,
  );

  Future<List<ServiceJob>> sells() async => [
    for (final j in await _api.get('/sell-requests?customerId=$_cid') as List)
      ServiceJob(j as Map<String, dynamic>),
  ];

  Future<void> cancel(ServiceJob job) => _api.post(
    job.id.startsWith('RP')
        ? '/repairs/${job.id}/cancel'
        : '/sell-requests/${job.id}/cancel',
    {'customerId': _cid},
  );
}

final serviceApiProvider = Provider<ServiceApi>(
  (ref) => ServiceApi(ref.watch(apiProvider), ref),
);

final myRepairsProvider = FutureProvider.autoDispose<List<ServiceJob>>((ref) {
  ref.watch(authProvider);
  return ref.watch(serviceApiProvider).repairs();
});

final mySellsProvider = FutureProvider.autoDispose<List<ServiceJob>>((ref) {
  ref.watch(authProvider);
  return ref.watch(serviceApiProvider).sells();
});

/// Next 5 days × 3 time windows.
List<DateTime> serviceSlots({DateTime? from}) {
  final now = from ?? DateTime.now();
  final out = <DateTime>[];
  for (var d = 0; d < 6 && out.length < 15; d++) {
    for (final h in const [10, 13, 17]) {
      final t = DateTime(now.year, now.month, now.day + d, h);
      if (t.isAfter(now.add(const Duration(hours: 3)))) out.add(t);
    }
  }
  return out;
}
