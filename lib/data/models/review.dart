/// Photo or video attached to a review. [path] is an `asset:`/`art:` spec
/// for demo data or an absolute file path for user uploads.
class ReviewMedia {
  const ReviewMedia(this.path, {this.isVideo = false});
  final String path;
  final bool isVideo;

  factory ReviewMedia.fromJson(Map<String, dynamic> j) =>
      ReviewMedia(j['path'] as String, isVideo: j['isVideo'] as bool? ?? false);
  Map<String, dynamic> toJson() => {'path': path, 'isVideo': isVideo};
}

class Review {
  const Review({
    required this.id,
    required this.productKey,
    required this.author,
    required this.rating,
    required this.title,
    required this.body,
    required this.createdAt,
    this.media = const [],
    this.verified = true,
    this.helpful = 0,
    this.variant,
  });

  final String id;

  /// Base product id (listings share their model's reviews).
  final String productKey;
  final String author;
  final int rating;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<ReviewMedia> media;
  final bool verified;
  final int helpful;
  final String? variant;

  bool get hasMedia => media.isNotEmpty;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as String,
    productKey: j['productKey'] as String,
    author: j['author'] as String,
    rating: j['rating'] as int,
    title: j['title'] as String,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    media: (j['media'] as List? ?? const [])
        .map((e) => ReviewMedia.fromJson(e as Map<String, dynamic>))
        .toList(),
    verified: j['verified'] as bool? ?? false,
    helpful: j['helpful'] as int? ?? 0,
    variant: j['variant'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productKey': productKey,
    'author': author,
    'rating': rating,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'media': media.map((m) => m.toJson()).toList(),
    'verified': verified,
    'helpful': helpful,
    'variant': variant,
  };
}

class Question {
  const Question({
    required this.id,
    required this.productKey,
    required this.author,
    required this.text,
    required this.createdAt,
    this.answer,
    this.answeredBy,
  });

  final String id;
  final String productKey;
  final String author;
  final String text;
  final DateTime createdAt;

  /// Answer from GAMEX or the seller; null while pending.
  final String? answer;

  /// "GAMEX" or the seller's store name.
  final String? answeredBy;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'] as String,
    productKey: (j['productKey'] ?? j['key']) as String,
    author: j['author'] as String,
    text: j['text'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    answer: j['answer'] as String?,
    answeredBy: j['answeredBy'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productKey': productKey,
    'author': author,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'answer': answer,
    'answeredBy': answeredBy,
  };
}

/// "p1-l42" → "p1".
String productKeyOf(String productId) => productId.split('-l').first;
