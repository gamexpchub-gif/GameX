import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

class _Review {
  const _Review(this.name, this.phone, this.rating, this.text, this.daysAgo);
  final String name;
  final String phone;
  final int rating;
  final String text;
  final int daysAgo;
}

/// Customer reviews. Static for now; will be served by the backend.
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  static const _reviews = [
    _Review(
      'Rakib H.',
      'iPhone 14 Pro',
      5,
      'Phone looks brand new, battery health 92%. Delivery in one day. Highly recommended!',
      2,
    ),
    _Review(
      'Nusrat J.',
      'Galaxy S23 Ultra',
      5,
      'Exactly as described. The 52-point check report gave me full confidence.',
      4,
    ),
    _Review(
      'Tanvir A.',
      'Pixel 8 Pro',
      4,
      'Great camera and condition. Box was slightly dented but phone perfect.',
      6,
    ),
    _Review(
      'Sadia R.',
      'iPhone 13',
      5,
      'Exchanged my old iPhone 11 and got a great price. Smooth process.',
      9,
    ),
    _Review(
      'Imran K.',
      'OnePlus 12',
      4,
      'Very good value. Support team answered all questions on WhatsApp.',
      12,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = _reviews.fold<int>(0, (s, r) => s + r.rating) / _reviews.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        avg.toStringAsFixed(1),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const _Stars(5),
                      const SizedBox(height: 4),
                      Text(
                        '12.5k+ reviews',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        for (final (star, v) in const [
                          (5, 0.82),
                          (4, 0.12),
                          (3, 0.04),
                          (2, 0.01),
                          (1, 0.01),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(width: 14, child: Text('$star')),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: v,
                                      minHeight: 6,
                                      color: AppColors.star,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final r in _reviews) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            r.name[0],
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Bought ${r.phone}',
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${r.daysAgo}d ago',
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Stars(r.rating),
                    const SizedBox(height: 6),
                    Text(r.text, style: const TextStyle(height: 1.45)),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Verified purchase',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars(this.rating);
  final int rating;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 5; i++)
        Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: AppColors.star,
        ),
    ],
  );
}
