import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../data/models/order.dart';
import '../../discover/data/phone_intel.dart';
import '../../orders/providers/orders_provider.dart';

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// Rough map position of Indian cities (0..1). Same table as the server.
const kCityXY = <String, (double, double)>{
  'Delhi': (0.36, 0.25),
  'New Delhi': (0.36, 0.25),
  'Gurugram': (0.35, 0.26),
  'Noida': (0.37, 0.25),
  'Jaipur': (0.3, 0.32),
  'Lucknow': (0.47, 0.3),
  'Chandigarh': (0.35, 0.18),
  'Ahmedabad': (0.2, 0.44),
  'Surat': (0.21, 0.5),
  'Mumbai': (0.22, 0.56),
  'Thane': (0.23, 0.55),
  'Pune': (0.26, 0.59),
  'Nagpur': (0.4, 0.5),
  'Indore': (0.31, 0.45),
  'Hyderabad': (0.39, 0.62),
  'Bengaluru': (0.36, 0.78),
  'Chennai': (0.45, 0.77),
  'Kochi': (0.31, 0.88),
  'Coimbatore': (0.34, 0.85),
  'Kolkata': (0.7, 0.44),
  'Patna': (0.6, 0.34),
  'Bhubaneswar': (0.6, 0.5),
  'Guwahati': (0.84, 0.31),
  'Goa': (0.24, 0.67),
};

(double, double) cityXY(String c) =>
    kCityXY[c] ?? kCityXY[c.split(RegExp(r'[ ,/]')).first] ?? (0.4, 0.5);

const _states = {
  'Mumbai': 'Maharashtra',
  'Thane': 'Maharashtra',
  'Pune': 'Maharashtra',
  'Nagpur': 'Maharashtra',
  'Delhi': 'Delhi',
  'New Delhi': 'Delhi',
  'Bengaluru': 'Karnataka',
  'Hyderabad': 'Telangana',
  'Chennai': 'Tamil Nadu',
  'Kolkata': 'West Bengal',
  'Ahmedabad': 'Gujarat',
  'Surat': 'Gujarat',
  'Jaipur': 'Rajasthan',
  'Lucknow': 'Uttar Pradesh',
  'Kochi': 'Kerala',
};
String? stateOfCity(String c) => _states[c] ?? _states[c.split(' ').first];

class Scan {
  const Scan(this.label, this.place, this.at);
  final String label;
  final String place;
  final DateTime at;
}

/// One shipment of an order (marketplace orders can have several).
class Shipment {
  const Shipment({
    required this.id,
    required this.item,
    required this.variant,
    required this.photo,
    required this.price,
    required this.stage,
    required this.from,
    required this.to,
    required this.progress,
    required this.scans,
    required this.invoice,
    this.courier,
    this.awb,
    this.otp,
    this.eta,
    this.live = false,
  });

  final String id;
  final String item;
  final String variant;
  final String photo;
  final double price;

  /// newOrder | accepted | packed | shipped | delivered | cancelled | returned
  final String stage;
  final String from;
  final String to;

  /// 0..1 along the route.
  final double progress;
  final List<Scan> scans;
  final Map<String, dynamic> invoice;
  final String? courier;
  final String? awb;
  final String? otp;
  final DateTime? eta;

  /// Scans come from a real courier account.
  final bool live;

  int get step => switch (stage) {
    'newOrder' => 0,
    'accepted' || 'packed' => 1,
    'shipped' => 2,
    'delivered' || 'returned' => 3,
    _ => -1,
  };

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
    id: j['id'] as String,
    item: j['item'] as String? ?? '',
    variant: j['variant'] as String? ?? '',
    photo: j['photo'] as String? ?? '',
    price: (j['price'] as num?)?.toDouble() ?? 0,
    stage: j['stage'] as String? ?? 'newOrder',
    from: (j['from'] as Map?)?['city'] as String? ?? 'Mumbai',
    to: (j['to'] as Map?)?['city'] as String? ?? 'Mumbai',
    progress: (j['progress'] as num?)?.toDouble() ?? 0,
    scans: [
      for (final s in (j['scans'] as List? ?? const []).cast<Map>())
        Scan(
          s['l'] as String,
          s['place'] as String? ?? '',
          _d(s['at']) ?? DateTime.now(),
        ),
    ],
    invoice: (j['invoice'] as Map?)?.cast<String, dynamic>() ?? const {},
    courier: j['courier'] as String?,
    awb: j['awb'] as String?,
    otp: j['otp'] as String?,
    eta: _d(j['eta']),
    live: j['live'] == true,
  );
}

/// Builds tracking for catalogue orders (handled by GAMEX logistics).
List<Shipment> localShipments(Order o) {
  final from = shipsFrom(o.items.first.product);
  final to = o.address.city;
  final same = from == to;
  final pick = o.createdAt.add(const Duration(hours: 6));
  final total = Duration(hours: same ? 20 : 54);
  final stage = switch (o.status) {
    OrderStatus.pending => 'newOrder',
    OrderStatus.confirmed => 'packed',
    OrderStatus.shipped => 'shipped',
    OrderStatus.delivered => 'delivered',
    OrderStatus.cancelled => 'cancelled',
  };
  final plan = [
    (0, 'Picked up from GAMEX $from hub', from),
    if (!same) (6, 'Departed $from hub', from),
    if (!same) (total.inHours - 14, 'Arrived at $to hub', to),
    (total.inHours - 5, 'Out for delivery', to),
  ];
  final now = DateTime.now();
  final delivered = stage == 'delivered';
  final scans = [
    if (stage == 'shipped' || delivered)
      for (final (h, l, p) in plan)
        if (delivered || pick.add(Duration(hours: h)).isBefore(now))
          Scan(l, p, pick.add(Duration(hours: h))),
    if (delivered) Scan('Delivered • OTP verified', to, o.deliveredAt),
  ];
  final progress = switch (stage) {
    'newOrder' => 0.04,
    'packed' => 0.2,
    'delivered' => 1.0,
    'shipped' =>
      (0.25 + now.difference(pick).inMinutes / total.inMinutes * 0.7).clamp(
        0.25,
        0.95,
      ),
    _ => 0.0,
  };
  final fs = stateOfCity(from);
  final ts = stateOfCity(to);
  final seed = o.id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  return [
    for (final (i, it) in o.items.indexed)
      Shipment(
        id: o.items.length > 1 ? '${o.id}-${i + 1}' : o.id,
        item: it.product.name,
        variant: it.size ?? it.product.memoryLabel ?? '',
        photo: it.product.images.first,
        price: it.total,
        stage: stage,
        from: from,
        to: to,
        progress: progress.toDouble(),
        scans: scans,
        courier: stage == 'shipped' || delivered ? 'GAMEX Express' : null,
        awb: stage == 'shipped' || delivered
            ? 'GX${9100000000 + seed % 99999999}'
            : null,
        otp: stage == 'shipped' ? '${1000 + seed % 9000}' : null,
        eta: stage == 'newOrder' || stage == 'packed' || stage == 'shipped'
            ? pick.add(total)
            : null,
        invoice: {
          'number': 'GMX/${o.createdAt.year}/${_last8(o.id)}',
          'date': o.createdAt.toIso8601String(),
          'seller': {
            'name': 'GAMEX Retail Pvt Ltd',
            'gstin': '27AACCG1234F1Z5',
            'city': from,
            'state': fs,
          },
          'buyer': {
            'name': o.address.fullName,
            'phone': o.address.phone,
            'address': '${o.address.details}, ${o.address.area}',
            'city': to,
            'state': ts,
          },
          'hsn': '8517',
          'interState': fs != null && ts != null && fs != ts,
        },
      ),
  ];
}

String _last8(String id) {
  final d = id.replaceAll(RegExp(r'\D'), '');
  return d.length > 8 ? d.substring(d.length - 8) : d;
}

final trackingProvider = FutureProvider.autoDispose
    .family<List<Shipment>, String>((ref, orderId) async {
      final o = ref.watch(ordersProvider.notifier).byId(orderId);
      if (o != null && !o.hasSellerItems) return localShipments(o);
      final list =
          await ref.watch(apiProvider).get('/orders/$orderId/tracking') as List;
      return [
        for (final j in list) Shipment.fromJson(j as Map<String, dynamic>),
      ];
    });
