import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/brand_marks.dart';
import '../../../../core/widgets/common.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/review.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../reviews/providers/community_provider.dart';
import '../../../reviews/providers/reviews_provider.dart';
import 'review_widgets.dart';

/// Brand logo next to the product title.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.brand, required this.size});

  /// Category id, e.g. `apple`.
  final String brand;
  final double size;

  @override
  Widget build(BuildContext context) => brand == 'apple'
      ? Icon(Icons.apple, size: size, color: Colors.black)
      : BrandLogo(brand, width: size, height: size);
}

// ───────────────────────────── 3D / 360° view ─────────────────────────────

/// Full-screen interactive viewer: drag to rotate the product in 3D,
/// pinch to zoom.
void open360View(BuildContext context, String image) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _Viewer360(image: image),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

class _Viewer360 extends StatefulWidget {
  const _Viewer360({required this.image});
  final String image;

  @override
  State<_Viewer360> createState() => _Viewer360State();
}

class _Viewer360State extends State<_Viewer360> {
  double _yaw = 0;
  double _pitch = 0;

  @override
  Widget build(BuildContext context) {
    final img =
        widget.image.startsWith('asset:') && widget.image.contains('pdp_')
        ? Image.asset(widget.image.substring(6), fit: BoxFit.contain)
        : AppImage(widget.image, fit: BoxFit.contain);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0820),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF4A2A9E), Color(0xFF0B0820)],
                    radius: 0.9,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onPanUpdate: (e) => setState(() {
                _yaw = (_yaw + e.delta.dx * 0.01).clamp(-0.9, 0.9);
                _pitch = (_pitch - e.delta.dy * 0.006).clamp(-0.35, 0.35);
              }),
              onDoubleTap: () => setState(() => _yaw = _pitch = 0),
              child: InteractiveViewer(
                maxScale: 3,
                child: Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0014)
                      ..rotateY(_yaw)
                      ..rotateX(_pitch),
                    child: AspectRatio(aspectRatio: 849 / 452, child: img),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '3D / 360° View',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  Transform.rotate(
                    angle: _yaw,
                    child: const Icon(
                      Icons.threesixty_rounded,
                      color: Colors.white70,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Drag to rotate • Pinch to zoom • Double-tap to reset  (${(_yaw * 180 / math.pi).round()}°)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── More menu ─────────────────────────────

void showProductMenu(BuildContext context, Product p) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share product'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: 'https://gamex.shop/p/${p.id}'),
              );
              Navigator.pop(c);
              showAppSnack(context, 'Product link copied');
            },
          ),
          ListTile(
            leading: const Icon(Icons.compare_arrows_rounded),
            title: const Text('Compare with similar phones'),
            onTap: () {
              Navigator.pop(c);
              context.push('/category/${p.categoryId}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Ask GAMEX support'),
            onTap: () {
              Navigator.pop(c);
              showAppSnack(context, 'Support: 1800-123-4567 (9am – 10pm)');
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
            title: const Text(
              'Report this listing',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () {
              Navigator.pop(c);
              showAppSnack(
                context,
                'Thanks, our team will review this listing',
              );
            },
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────────── All reviews ─────────────────────────────

enum _Filter { all, media, five, four, three, low }

void showAllReviewsSheet(
  BuildContext context, {
  required Product product,
  String? variant,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (_, scroll) =>
          _AllReviews(product: product, variant: variant, scroll: scroll),
    ),
  );
}

class _AllReviews extends ConsumerStatefulWidget {
  const _AllReviews({
    required this.product,
    required this.scroll,
    this.variant,
  });
  final Product product;
  final ScrollController scroll;
  final String? variant;

  @override
  ConsumerState<_AllReviews> createState() => _AllReviewsState();
}

class _AllReviewsState extends ConsumerState<_AllReviews> {
  _Filter _filter = _Filter.all;

  bool _match(Review r) => switch (_filter) {
    _Filter.all => true,
    _Filter.media => r.hasMedia,
    _Filter.five => r.rating == 5,
    _Filter.four => r.rating == 4,
    _Filter.three => r.rating == 3,
    _Filter.low => r.rating <= 2,
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final all = ref.watch(reviewsProvider(p.id));
    final list = all.where(_match).toList();
    const labels = {
      _Filter.all: 'All',
      _Filter.media: 'Photos & videos',
      _Filter.five: '5★',
      _Filter.four: '4★',
      _Filter.three: '3★',
      _Filter.low: '1-2★',
    };
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          'Ratings & Reviews',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        RatingSummaryView(summary: ref.watch(ratingSummaryProvider(p.id))),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => showWriteReviewSheet(
            context,
            productId: p.id,
            variant: widget.variant,
          ),
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Write a review • Photos & 30s video'),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labels[f]!),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No reviews in this filter yet')),
          ),
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          ReviewTile(review: list[i]),
        ],
      ],
    );
  }
}

// ───────────────────────────── All Q&A ─────────────────────────────

void showAllQuestionsSheet(BuildContext context, Product product) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scroll) => _AllQuestions(product: product, scroll: scroll),
    ),
  );
}

class _AllQuestions extends ConsumerStatefulWidget {
  const _AllQuestions({required this.product, required this.scroll});
  final Product product;
  final ScrollController scroll;

  @override
  ConsumerState<_AllQuestions> createState() => _AllQuestionsState();
}

class _AllQuestionsState extends ConsumerState<_AllQuestions> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final text = _c.text.trim();
    if (text.length < 5) {
      showAppSnack(context, 'Please type your question');
      return;
    }
    final author = ref.read(authProvider)?.name ?? 'You';
    try {
      await ref
          .read(communityApiProvider)
          .ask(productKeyOf(widget.product.id), author, text);
    } catch (_) {
      await ref
          .read(userQuestionsProvider.notifier)
          .ask(widget.product.id, author, text);
    }
    _c.clear();
    if (mounted) {
      showAppSnack(context, 'Question posted. We usually answer within 1 hour');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qs = ref.watch(questionsProvider(widget.product.id));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Questions & Answers (${qs.length})',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            decoration: InputDecoration(
              hintText: 'Ask about condition, warranty, delivery…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _ask,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final q in qs) QaCard(question: q),
        ],
      ),
    );
  }
}

/// One question with its answer (or a pending note).
class QaCard extends StatelessWidget {
  const QaCard({super.key, required this.question, this.compact = false});
  final Question question;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.contact_support_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 26,
                child: Text(
                  'A:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Text(
                  q.answer == null
                      ? 'Awaiting answer from the seller…'
                      : q.answeredBy == null
                      ? q.answer!
                      : '${q.answer!}\n— ${q.answeredBy}',
                  style: TextStyle(
                    height: 1.4,
                    color: q.answer == null
                        ? theme.colorScheme.outline
                        : theme.colorScheme.onSurfaceVariant,
                    fontStyle: q.answer == null ? FontStyle.italic : null,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '${q.author} • ${DateFormat('d MMM yyyy').format(q.createdAt)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Condition report ─────────────────────────────

/// Opens the full 32-point inspection report.
void showConditionReport(BuildContext context, Product p) =>
    context.push('/product/${p.id}/report');

/// Quick condition summary sheet (kept for small entry points).
void showConditionSummary(BuildContext context, Product p) {
  final battery = p.batteryHealth == 0 ? 90 : p.batteryHealth;
  final grade = (p.condition ?? 'Excellent').replaceAll(' Condition', '');
  final scores = {
    'Screen': grade == 'Good' ? 0.95 : 1.0,
    'Body': grade == 'Like New'
        ? 0.98
        : grade == 'Good'
        ? 0.78
        : 0.9,
    'Camera': 1.0,
    'Battery': battery / 100,
  };
  const checks = [
    'IMEI verified & blacklist-free',
    'Original display & parts',
    'Face ID / fingerprint working',
    'Network unlocked',
    'Factory reset & sanitised',
    '52-point inspection passed',
  ];
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Condition Report',
                  style: Theme.of(c).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    grade.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: battery / 100,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFFE6EBF7),
                        color: battery >= 85
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$battery%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const Text(
                              'Battery',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in scores.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text(
                                  e.key,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: e.value,
                                    minHeight: 7,
                                    backgroundColor: const Color(0xFFE6EBF7),
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  (e.value * 10).toStringAsFixed(1),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
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
            const Divider(height: 28),
            for (final ch in checks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(ch),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
