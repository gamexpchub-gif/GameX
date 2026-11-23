import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api.dart';
import '../../../data/models/order.dart';
import '../../../data/models/review.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';

/// Reviews shared by all buyers (GAMEX server). Empty when offline.
final serverReviewsProvider = FutureProvider.family<List<Review>, String>((
  ref,
  key,
) async {
  try {
    final api = ref.watch(apiProvider);
    final list =
        await api.get('/reviews?key=${Uri.encodeComponent(key)}') as List;
    return [
      for (final j in list.cast<Map<String, dynamic>>())
        Review(
          id: j['id'] as String,
          productKey: key,
          author: j['author'] as String? ?? 'Customer',
          rating: (j['rating'] as num).toInt(),
          title: j['title'] as String? ?? '',
          body: j['body'] as String? ?? '',
          createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
          media: [
            for (final p in (j['photos'] as List? ?? const []).cast<String>())
              ReviewMedia(api.media(p)),
          ],
          verified: j['verified'] == true,
          helpful: (j['helpful'] as num?)?.toInt() ?? 0,
          variant: j['variant'] as String?,
        ),
    ];
  } catch (_) {
    return const [];
  }
});

/// Questions shared by all buyers, with seller / GAMEX answers.
final serverQuestionsProvider = FutureProvider.family<List<Question>, String>((
  ref,
  key,
) async {
  try {
    final list =
        await ref
                .watch(apiProvider)
                .get('/questions?key=${Uri.encodeComponent(key)}')
            as List;
    return [for (final j in list) Question.fromJson(j as Map<String, dynamic>)];
  } catch (_) {
    return const [];
  }
});

/// True when this buyer ordered [key] on GAMEX (not cancelled).
final boughtProvider = Provider.family<bool, String>((ref, key) {
  return ref
      .watch(ordersProvider)
      .any(
        (o) =>
            o.status != OrderStatus.cancelled &&
            o.items.any((i) => productKeyOf(i.product.id) == key),
      );
});

class CommunityApi {
  CommunityApi(this._ref);
  final Ref _ref;
  Api get _api => _ref.read(apiProvider);

  /// Posts a review (uploading photos first). Throws when offline.
  Future<void> postReview(Review r) async {
    final user = _ref.read(authProvider);
    if (user == null) throw const ApiException('Log in to post a review');
    final photos = <String>[];
    for (final m in r.media.where((m) => !m.isVideo)) {
      if (m.path.startsWith('/') && !m.path.startsWith('/uploads/')) {
        photos.add(await _api.upload(m.path));
      }
    }
    await _api.post('/reviews', {
      'customerId': user.id,
      'author': r.author,
      'key': r.productKey,
      'rating': r.rating,
      'title': r.title,
      'body': r.body,
      'variant': r.variant,
      'photos': photos,
    });
    _ref.invalidate(serverReviewsProvider(r.productKey));
  }

  Future<void> ask(String key, String author, String text) async {
    await _api.post('/questions', {
      'customerId': _ref.read(authProvider)?.id,
      'author': author,
      'key': key,
      'text': text,
    });
    _ref.invalidate(serverQuestionsProvider(key));
  }
}

final communityApiProvider = Provider<CommunityApi>(CommunityApi.new);
