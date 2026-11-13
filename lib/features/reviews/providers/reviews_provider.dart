import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/review.dart';

const _reviewsKey = 'user_reviews_v1';
const _helpfulKey = 'helpful_votes_v1';
const _questionsKey = 'user_questions_v1';

/// Reviews written on this device (persisted). Demo reviews are generated
/// per product; both will come from the backend later.
class UserReviewsNotifier extends Notifier<List<Review>> {
  @override
  List<Review> build() =>
      ref
          .read(localStoreProvider)
          .readJson(
            _reviewsKey,
            (j) => (j as List)
                .map((e) => Review.fromJson(e as Map<String, dynamic>))
                .toList(),
          ) ??
      const [];

  Future<void> add(Review review) async {
    state = [review, ...state];
    await ref
        .read(localStoreProvider)
        .writeJson(_reviewsKey, state.map((r) => r.toJson()).toList());
  }
}

final userReviewsProvider = NotifierProvider<UserReviewsNotifier, List<Review>>(
  UserReviewsNotifier.new,
);

/// Review ids the user marked as helpful.
class HelpfulNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref
          .read(localStoreProvider)
          .readJson(_helpfulKey, (j) => Set<String>.from(j as List)) ??
      {};

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    ref.read(localStoreProvider).writeJson(_helpfulKey, state.toList());
  }
}

final helpfulProvider = NotifierProvider<HelpfulNotifier, Set<String>>(
  HelpfulNotifier.new,
);

/// All reviews for a product model, newest user reviews first.
final reviewsProvider = Provider.family<List<Review>, String>((ref, productId) {
  final key = productKeyOf(productId);
  final mine = ref.watch(userReviewsProvider).where((r) => r.productKey == key);
  return [...mine, ..._demoReviews(key)];
});

class RatingSummary {
  const RatingSummary(this.average, this.total, this.counts);
  final double average;
  final int total;

  /// counts[5] … counts[1]
  final Map<int, int> counts;

  double share(int star) => total == 0 ? 0 : (counts[star] ?? 0) / total;
}

/// Summary that blends the product's catalogue rating with local reviews.
final ratingSummaryProvider = Provider.family<RatingSummary, String>((
  ref,
  productId,
) {
  final product = MockData.byId(productId);
  final reviews = ref.watch(reviewsProvider(productId));
  final base = product?.reviewCount ?? reviews.length;
  final avg = product?.rating ?? 4.5;
  // Distribution shaped by the average rating.
  final five = ((avg - 3.6) / 1.4).clamp(0.3, 0.9);
  final shares = {
    5: five,
    4: (1 - five) * 0.62,
    3: (1 - five) * 0.22,
    2: (1 - five) * 0.09,
    1: (1 - five) * 0.07,
  };
  final counts = {
    for (final e in shares.entries) e.key: (base * e.value).round(),
  };
  final mine = ref
      .watch(userReviewsProvider)
      .where((r) => r.productKey == productKeyOf(productId));
  for (final r in mine) {
    counts[r.rating] = (counts[r.rating] ?? 0) + 1;
  }
  final total = counts.values.fold(0, (a, b) => a + b);
  final sum = counts.entries.fold(0, (a, e) => a + e.key * e.value);
  return RatingSummary(total == 0 ? avg : sum / total, total, counts);
});

class QuestionsNotifier extends Notifier<List<Question>> {
  @override
  List<Question> build() =>
      ref
          .read(localStoreProvider)
          .readJson(
            _questionsKey,
            (j) => (j as List)
                .map((e) => Question.fromJson(e as Map<String, dynamic>))
                .toList(),
          ) ??
      const [];

  Future<void> ask(String productId, String author, String text) async {
    final q = Question(
      id: 'q${DateTime.now().microsecondsSinceEpoch}',
      productKey: productKeyOf(productId),
      author: author,
      text: text,
      createdAt: DateTime.now(),
    );
    state = [q, ...state];
    await ref
        .read(localStoreProvider)
        .writeJson(_questionsKey, state.map((e) => e.toJson()).toList());
  }
}

final userQuestionsProvider =
    NotifierProvider<QuestionsNotifier, List<Question>>(QuestionsNotifier.new);

final questionsProvider = Provider.family<List<Question>, String>((
  ref,
  productId,
) {
  final key = productKeyOf(productId);
  final mine = ref
      .watch(userQuestionsProvider)
      .where((q) => q.productKey == key);
  return [...mine, ..._demoQuestions(key)];
});

// ───────────────────────────── Demo data ─────────────────────────────

const _names = [
  'Rakib Hasan',
  'Nusrat Jahan',
  'Tanvir Ahmed',
  'Sadia Rahman',
  'Imran Khan',
  'Farhana Akter',
  'Shuvo Das',
  'Mehedi Hasan',
];
const _texts = [
  (
    5,
    'Looks brand new!',
    'Phone looks and feels brand new. Battery health was exactly as listed and delivery took just one day. Highly recommended.',
  ),
  (
    5,
    'Worth every taka',
    'Saved a lot compared to a new one. The 70-point check report gave me full confidence. Packaging was premium.',
  ),
  (
    4,
    'Very good condition',
    'Tiny mark on the frame, otherwise perfect. Camera and Face ID work flawlessly. Support answered quickly on WhatsApp.',
  ),
  (
    5,
    'Smooth experience',
    'Ordered with Cash on Delivery, verified the IMEI at the door. Everything matched the listing.',
  ),
  (
    4,
    'Good value',
    'Performance is excellent, battery lasts a full day. Charger was included. Would buy again from GAMEX.',
  ),
  (
    3,
    'Okay, slow delivery',
    'Phone is fine but delivery took three days to Sylhet. Condition matches the description.',
  ),
];

List<Review> _demoReviews(String key) {
  final product = MockData.byId(key);
  final seed = key.hashCode.abs();
  return [
    for (var i = 0; i < _texts.length; i++)
      Review(
        id: '$key-r$i',
        productKey: key,
        author: _names[(seed + i) % _names.length],
        rating: _texts[i].$1,
        title: _texts[i].$2,
        body: _texts[i].$3,
        createdAt: DateTime(
          2026,
          11,
          12,
        ).subtract(Duration(days: 2 + i * 5 + seed % 4)),
        media: i == 0 && product != null
            ? [for (final img in product.images.take(2)) ReviewMedia(img)]
            : i == 2 && product != null
            ? [ReviewMedia(product.images.last)]
            : const [],
        helpful: 40 - i * 6 + seed % 7,
        variant: product?.memoryLabel,
      ),
  ];
}

List<Question> _demoQuestions(String key) => [
  Question(
    id: '$key-q1',
    productKey: key,
    author: 'Arif',
    text: 'Is the phone PTA/BTRC approved and network unlocked?',
    createdAt: DateTime(2026, 11, 2),
    answer: 'Yes. Every GAMEX phone is BTRC registered, IMEI verified and works on all Bangladeshi operators.',
  ),
  Question(
    id: '$key-q2',
    productKey: key,
    author: 'Mitu',
    text: 'Will I get the original box and charger?',
    createdAt: DateTime(2026, 10, 28),
    answer: 'You get a GAMEX premium box with a certified fast charger and cable. Original box when available.',
  ),
  Question(
    id: '$key-q3',
    productKey: key,
    author: 'Sabbir',
    text: 'Can I check the phone before paying with Cash on Delivery?',
    createdAt: DateTime(2026, 10, 20),
    answer: 'Absolutely. You can inspect the phone and verify the IMEI in front of the delivery agent.',
  ),
];
