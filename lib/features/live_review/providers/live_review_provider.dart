import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';

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

  LiveRequest copyWith({LiveStatus? status}) => LiveRequest(
    id: id,
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
  List<LiveRequest> build() =>
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

  /// Submits a request; the demo auto-confirms it as "Scheduled".
  Future<LiveRequest> request(LiveRequest r) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final scheduled = r.copyWith(status: LiveStatus.scheduled);
    await _save([scheduled, ...state]);
    return scheduled;
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
