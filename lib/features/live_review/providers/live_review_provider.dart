import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../core/storage.dart';
import '../../auth/providers/auth_provider.dart';

const _key = 'live_review_requests_v1';

enum LiveMode {
  video('Video Call', 'In-app HD video with a GAMEX expert'),
  whatsapp('WhatsApp Video', 'We call you on WhatsApp'),
  store('Visit Store', 'See it in person at a GAMEX store');

  const LiveMode(this.label, this.description);
  final String label;
  final String description;
}

enum LiveStatus {
  requested('Requested'),
  scheduled('Scheduled'),
  completed('Completed'),
  cancelled('Cancelled');

  const LiveStatus(this.label);
  final String label;
}

/// A customer's request to inspect a specific phone live before buying.
class LiveRequest {
  const LiveRequest({
    required this.id,
    required this.productId,
    required this.productName,
    required this.image,
    required this.mode,
    required this.slot,
    required this.phone,
    required this.language,
    required this.createdAt,
    this.notes = '',
    this.status = LiveStatus.requested,
  });

  final String id;
  final String productId;
  final String productName;
  final String image;
  final LiveMode mode;
  final DateTime slot;
  final String phone;
  final String language;
  final String notes;
  final DateTime createdAt;
  final LiveStatus status;

  bool get active =>
      status == LiveStatus.requested || status == LiveStatus.scheduled;

  LiveRequest copyWith({LiveStatus? status, String? id}) => LiveRequest(
    id: id ?? this.id,
    productId: productId,
    productName: productName,
    image: image,
    mode: mode,
    slot: slot,
    phone: phone,
    language: language,
    notes: notes,
    createdAt: createdAt,
    status: status ?? this.status,
  );

  factory LiveRequest.fromJson(Map<String, dynamic> j) => LiveRequest(
    id: j['id'] as String,
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    image: j['image'] as String,
    mode: LiveMode.values.byName(j['mode'] as String),
    slot: DateTime.parse(j['slot'] as String),
    phone: j['phone'] as String,
    language: j['language'] as String? ?? 'English',
    notes: j['notes'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    status: LiveStatus.values.byName(j['status'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'image': image,
    'mode': mode.name,
    'slot': slot.toIso8601String(),
    'phone': phone,
    'language': language,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };
}

class LiveRequestsNotifier extends Notifier<List<LiveRequest>> {
  @override
  List<LiveRequest> build() {
    Future.microtask(sync);
    return _load();
  }

  List<LiveRequest> _load() =>
      ref
          .read(localStoreProvider)
          .readJson(
            _key,
            (j) => (j as List)
                .map((e) => LiveRequest.fromJson(e as Map<String, dynamic>))
                .toList(),
          ) ??
      const [];

  Future<void> _save(List<LiveRequest> list) async {
    state = list;
    await ref
        .read(localStoreProvider)
        .writeJson(_key, list.map((e) => e.toJson()).toList());
  }

  /// Sends the request to the seller via the GAMEX server. Built-in
  /// catalogue phones (no seller) are confirmed by GAMEX automatically.
  Future<LiveRequest> request(LiveRequest r) async {
    if (!r.productId.startsWith('GXL')) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final scheduled = r.copyWith(status: LiveStatus.scheduled);
      await _save([scheduled, ...state]);
      return scheduled;
    }
    final user = ref.read(authProvider);
    final j = await ref.read(apiProvider).post('/live', {
      'listingId': r.productId,
      'customer': {'id': user?.id, 'name': user?.name ?? 'GAMEX Customer'},
      'phone': r.phone,
      'mode': r.mode.label,
      'language': r.language,
      'slot': r.slot.toIso8601String(),
      'notes': r.notes,
    }) as Map;
    final saved = r.copyWith(id: j['id'] as String);
    await _save([saved, ...state]);
    return saved;
  }

  static const _map = {
    'pending': LiveStatus.requested,
    'confirmed': LiveStatus.scheduled,
    'done': LiveStatus.completed,
    'declined': LiveStatus.cancelled,
  };

  /// Pulls seller decisions for marketplace requests.
  Future<void> sync() async {
    final ids = [
      for (final r in state)
        if (r.productId.startsWith('GXL') && r.active) r.id,
    ];
    if (ids.isEmpty) return;
    try {
      final list =
          await ref.read(apiProvider).get('/live/status?ids=${ids.join(',')}')
              as List;
      final byId = {
        for (final e in list.cast<Map>()) e['id'] as String: _map[e['stage']],
      };
      await _save([
        for (final r in state)
          if (byId[r.id] != null) r.copyWith(status: byId[r.id]) else r,
      ]);
    } catch (_) {}
  }

  Future<void> cancel(String id) => _save([
    for (final r in state)
      r.id == id ? r.copyWith(status: LiveStatus.cancelled) : r,
  ]);
}

final liveRequestsProvider =
    NotifierProvider<LiveRequestsNotifier, List<LiveRequest>>(
      LiveRequestsNotifier.new,
    );
