import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/listing_card.dart';
import '../../../data/models/product.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/product_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../home/presentation/widgets/home_sheets.dart';
import '../../reviews/providers/reviews_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import 'widgets/review_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(productByIdProvider(productId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorRetry(
              onRetry: () => ref.invalidate(productByIdProvider(productId)),
            ),
          ),
          data: (p) => p == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Product not found',
                    message: 'This listing may have been sold.',
                  ),
                )
              : _ProductPage(product: p),
        );
  }
}

// ───────────────────────────── Variant options ─────────────────────────────

const _storageLadder = ['64GB', '128GB', '256GB', '512GB', '1TB'];

class _Grade {
  const _Grade(this.name, this.factor, this.note, this.icon);
  final String name;
  final double factor;
  final String note;
  final IconData icon;
}

const _grades = [
  _Grade('Like New', 1.06, 'No visible signs of use', Icons.diamond_rounded),
  _Grade(
    'Excellent',
    1.0,
    'Micro-scratches, invisible at arm\'s length',
    Icons.workspace_premium_rounded,
  ),
  _Grade(
    'Good',
    0.9,
    'Light visible wear on body, screen flawless',
    Icons.thumb_up_alt_rounded,
  ),
];

double _round99(double v) => (v / 100).round() * 100 - 1;

class _ProductPage extends ConsumerStatefulWidget {
  const _ProductPage({required this.product});
  final Product product;

  @override
  ConsumerState<_ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<_ProductPage> {
  final _gallery = PageController();
  int _image = 0;
  late int _storage; // index into _storageOptions
  int _color = 0;
  late int _grade;
  int _qty = 1;
  bool _specsExpanded = false;

  Product get p => widget.product;

  /// Gallery images with the wide front+back shot first.
  late final List<String> _images = [
    ...p.images.where((i) => i.contains('/deal_')),
    ...p.images.where((i) => !i.contains('/deal_')),
  ];

  final _scroll = ScrollController();
  final _scrolled = ValueNotifier(false);

  late final List<String> _storageOptions = () {
    final i = _storageLadder.indexOf(p.storage ?? '');
    if (i < 0) return [p.storage ?? 'Standard'];
    return _storageLadder.sublist(i, (i + 3).clamp(0, _storageLadder.length));
  }();

  late final List<(String, int)> _colors = () {
    final list = <(String, int)>[
      if (p.colors.isNotEmpty) (p.colorName ?? 'Original', p.colors.first),
      ('Graphite', 0xFF2B2E36),
      ('Silver', 0xFFD9DCE3),
    ];
    final seen = <String>{};
    return [
      for (final c in list)
        if (seen.add(c.$1)) c,
    ];
  }();

  double get _baseFactor {
    final name = (p.condition ?? '').replaceAll(' Condition', '');
    return _grades
        .firstWhere((g) => g.name == name, orElse: () => _grades[1])
        .factor;
  }

  double _priceFor({int? storage, int? grade}) {
    final s = storage ?? _storage;
    final g = grade ?? _grade;
    final storageMult = 1 + s * 0.14;
    return _round99(p.price / _baseFactor * _grades[g].factor * storageMult);
  }

  double get _price => _priceFor();
  double get _mrp => _round99(p.mrp * (1 + _storage * 0.14));
  int get _off => _mrp <= _price ? 0 : ((_mrp - _price) / _mrp * 100).round();
  int get _maxQty => p.stock.clamp(1, 5);

  String get _variantLabel =>
      '${p.ram != null ? '${p.ram} / ' : ''}${_storageOptions[_storage]} • ${_colors[_color].$1} • ${_grades[_grade].name}';

  /// The product as configured, ready for the cart.
  Product get _configured => p.copyWith(
    price: _price,
    oldPrice: _mrp,
    variant: '${_storageOptions[_storage]} • ${_colors[_color].$1}',
    condition: '${_grades[_grade].name} Condition',
    colors: [_colors[_color].$2],
  );

  @override
  void initState() {
    super.initState();
    _storage = 0;
    _scroll.addListener(() {
      final v = _scroll.offset > MediaQuery.sizeOf(context).width * 0.75;
      if (v != _scrolled.value) _scrolled.value = v;
    });
    final name = (p.condition ?? '').replaceAll(' Condition', '');
    _grade = _grades
        .indexWhere((g) => g.name == name)
        .clamp(0, _grades.length - 1);
    if (_grade < 0) _grade = 1;
  }

  @override
  void dispose() {
    _gallery.dispose();
    _scroll.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  void _addToCart() {
    HapticFeedback.mediumImpact();
    ref
        .read(cartProvider.notifier)
        .add(
          _configured,
          quantity: _qty,
          size: _variantLabel,
          color: _colors[_color].$2,
        );
    showAppSnack(
      context,
      'Added to cart',
      action: 'VIEW',
      onAction: () => context.push('/cart'),
    );
  }

  void _buyNow() {
    _addToCartSilently();
    if (ref.read(authProvider) == null) {
      context.push('/login?from=${Uri.encodeComponent('/checkout')}');
    } else {
      context.push('/checkout');
    }
  }

  void _addToCartSilently() {
    HapticFeedback.mediumImpact();
    ref
        .read(cartProvider.notifier)
        .add(
          _configured,
          quantity: _qty,
          size: _variantLabel,
          color: _colors[_color].$2,
        );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reviews = ref.watch(reviewsProvider(p.id));
    final videoMedia = [
      for (final r in reviews) ...r.media.where((m) => m.isVideo),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuroraBackground(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _gallerySection(mq, videoMedia)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    sliver: SliverList.list(
                      children: [
                        _titleCard(),
                        _gap,
                        _priceCard(),
                        _gap,
                        _optionsCard(),
                        _gap,
                        _ConditionReport(product: p, grade: _grades[_grade]),
                        _gap,
                        _DeliveryCard(product: p),
                        _gap,
                        _specsCard(),
                        _gap,
                        const _SellerCard(),
                        _gap,
                        _ReviewsSection(product: p, variant: _variantLabel),
                        _gap,
                        _QuestionsSection(product: p),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: _Recommendations(product: p)),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 110 + mq.padding.bottom),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopBar(product: p, scrolled: _scrolled, price: _price),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar(mq)),
            ],
          ),
        ),
      ),
    );
  }

  static const _gap = SizedBox(height: 12);

  // ── Gallery ──
  Widget _gallerySection(MediaQueryData mq, List<ReviewMedia> videos) {
    final h = mq.size.width * 0.92;
    return Column(
      children: [
        SizedBox(
          height: h + mq.padding.top,
          child: Stack(
            children: [
              PageView.builder(
                controller: _gallery,
                itemCount: _images.length,
                onPageChanged: (i) => setState(() => _image = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => openMediaViewer(context, [
                    for (final img in _images) ReviewMedia(img),
                  ], i),
                  child: Padding(
                    padding: EdgeInsets.only(top: mq.padding.top),
                    child: AppImage(_images[i]),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Row(
                  children: [
                    _GlassChip(
                      icon: Icons.photo_library_outlined,
                      label: '${_image + 1}/${_images.length}',
                    ),
                    if (videos.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _GlassChip(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Videos (${videos.length})',
                        onTap: () => openMediaViewer(context, videos, 0),
                      ),
                    ],
                  ],
                ),
              ),
              if (p.verified)
                const Positioned(
                  right: 14,
                  bottom: 14,
                  child: _GlassChip(
                    icon: Icons.verified_user_rounded,
                    label: 'GAMEX Certified',
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _gallery.animateToPage(
                i,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
              child: Container(
                width: 62,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == _image ? AppColors.primary : Colors.white,
                    width: 2,
                  ),
                ),
                child: AppImage(
                  _images[i],
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Title ──
  Widget _titleCard() {
    final summary = ref.watch(ratingSummaryProvider(p.id));
    final theme = Theme.of(context);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(text: p.brand.toUpperCase(), color: AppColors.primary),
              const SizedBox(width: 8),
              if (p.isFlashSale)
                const _Pill(text: 'FLASH DEAL', color: AppColors.danger),
              const Spacer(),
              _StockPill(stock: p.stock),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _variantLabel,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              StarRow(rating: summary.average, size: 17),
              Text(
                summary.average.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${NumberFormat.compact().format(summary.total)} ratings',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              Text('•', style: TextStyle(color: theme.colorScheme.outline)),
              Text(
                '${NumberFormat.compact().format(p.soldCount)} sold',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Price ──
  Widget _priceCard() {
    final theme = Theme.of(context);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPrice(_price),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              if (_off > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'MRP ${formatPrice(_mrp)}',
                    style: TextStyle(
                      color: theme.colorScheme.outline,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              const Spacer(),
              if (_off > 0)
                _Pill(
                  text: '$_off% OFF',
                  color: AppColors.success,
                  filled: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_off > 0)
            Text(
              'You save ${formatPrice(_mrp - _price)} on this ${_grades[_grade].name.toLowerCase()} unit',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            'Inclusive of VAT • Free delivery over ৳5,000',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.calendar_month_rounded,
            title: 'EMI from ${formatPrice(_price / 12)}/mo',
            subtitle: '0% interest for 12 months on selected cards',
            onTap: () => showEmiSheet(context),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.sync_rounded,
            title: 'Exchange your old phone',
            subtitle: 'Get up to ৳15,000 off instantly',
            onTap: () => showTradeInSheet(context),
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            icon: Icons.local_offer_rounded,
            title: 'Bank offer: 10% instant discount',
            subtitle: 'bKash / Nagad / Visa cards • code GAMEX10',
          ),
        ],
      ),
    );
  }

  // ── Options ──
  Widget _optionsCard() {
    final theme = Theme.of(context);
    TextStyle label() =>
        theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RAM / Storage', style: label()),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _storageOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _OptionTile(
                    selected: i == _storage,
                    onTap: () => setState(() => _storage = i),
                    child: Column(
                      children: [
                        Text(
                          '${p.ram != null ? '${p.ram}/' : ''}${_storageOptions[i]}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatPrice(_priceFor(storage: i)),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Colour', style: label()),
              const SizedBox(width: 8),
              Text(
                _colors[_color].$1,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _colors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _color
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(_colors[i].$2).withValues(alpha: 0.85),
                            Color(_colors[i].$2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Condition', style: label()),
          const SizedBox(height: 10),
          for (var i = 0; i < _grades.length; i++) ...[
            _OptionTile(
              selected: i == _grade,
              onTap: () => setState(() => _grade = i),
              child: Row(
                children: [
                  Icon(
                    _grades[i].icon,
                    color: i == _grade
                        ? AppColors.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _grades[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _grades[i].note,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPrice(_priceFor(grade: i)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Quantity', style: label()),
              const SizedBox(width: 8),
              Text(
                '(${p.stock} in stock)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              QuantityStepper(
                value: _qty.clamp(1, _maxQty),
                max: _maxQty,
                onChanged: (v) => setState(() => _qty = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Specs ──
  Widget _specsCard() {
    final theme = Theme.of(context);
    final entries = p.specs.entries.toList();
    final shown = _specsExpanded ? entries : entries.take(4).toList();
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.memory_rounded,
            title: 'Specifications',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < shown.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: i.isEven
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      shown[i].key,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      shown[i].value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (entries.length > 4)
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _specsExpanded = !_specsExpanded),
                icon: Icon(
                  _specsExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _specsExpanded ? 'Show less' : 'View all specifications',
                ),
              ),
            ),
          const Divider(height: 20),
          Text(
            'About this phone',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.description,
            style: TextStyle(
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ──
  Widget _bottomBar(MediaQueryData mq) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A3D8F).withValues(alpha: 0.12),
            blurRadius: 24,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              Text(
                formatPrice(_price * _qty),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                foregroundColor: AppColors.primary,
              ),
              onPressed: p.inStock ? _addToCart : null,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const FittedBox(child: Text('Add to Cart')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: p.inStock ? _buyNow : null,
              child: FittedBox(child: Text(p.inStock ? 'Buy Now' : 'Sold Out')),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Building blocks ─────────────────────────────

/// Frosted section card.
class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Glass(
    radius: 22,
    color: Colors.white.withValues(alpha: 0.85),
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      ?trailing,
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.filled = false});
  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: filled
          ? color.withValues(alpha: 0.14)
          : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.stock});
  final int stock;

  @override
  Widget build(BuildContext context) {
    final (text, color) = stock == 0
        ? ('Sold out', AppColors.danger)
        : stock < 5
        ? ('Only $stock left', AppColors.warning)
        : ('In stock', AppColors.success);
    return _Pill(text: text.toUpperCase(), color: color, filled: true);
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Glass(
      radius: 20,
      color: Colors.white.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.textPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.white,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.8 : 1,
        ),
      ),
      child: child,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

/// Floating back / share / wishlist / cart buttons.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.product,
    required this.scrolled,
    required this.price,
  });
  final Product product;

  /// True once the gallery has scrolled away: show a solid header.
  final ValueListenable<bool> scrolled;
  final double price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(isWishlistedProvider(product.id));
    final cart = ref.watch(cartCountProvider);
    Widget btn(Widget icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 22,
        color: Colors.white.withValues(alpha: 0.9),
        child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
      ),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: scrolled,
      builder: (context, solid, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: solid
              ? Colors.white.withValues(alpha: 0.97)
              : Colors.transparent,
          boxShadow: solid
              ? [
                  BoxShadow(
                    color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              children: [
                btn(const Icon(Icons.arrow_back_rounded), () => context.pop()),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: solid ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          formatPrice(price),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child!,
              ],
            ),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(const Icon(Icons.share_outlined, size: 21), () {
            Clipboard.setData(
              ClipboardData(text: 'https://gamex.shop/p/${product.id}'),
            );
            showAppSnack(context, 'Link copied to clipboard');
          }),
          const SizedBox(width: 10),
          btn(
            Icon(
              wished ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: wished ? AppColors.danger : null,
              size: 22,
            ),
            () {
              HapticFeedback.lightImpact();
              ref.read(wishlistProvider.notifier).toggle(product);
            },
          ),
          const SizedBox(width: 10),
          btn(
            Badge(
              isLabelVisible: cart > 0,
              label: Text('$cart'),
              child: const Icon(Icons.shopping_cart_outlined, size: 22),
            ),
            () => context.push('/cart'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Condition report ─────────────────────────────

class _ConditionReport extends StatelessWidget {
  const _ConditionReport({required this.product, required this.grade});
  final Product product;
  final _Grade grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final battery = product.batteryHealth == 0 ? 90 : product.batteryHealth;
    final scores = {
      'Screen': grade.factor >= 1 ? 1.0 : 0.95,
      'Body': grade.factor > 1
          ? 0.98
          : grade.factor == 1
          ? 0.9
          : 0.78,
      'Camera': 1.0,
      'Battery': battery / 100,
    };
    const checks = [
      'IMEI verified & BTRC registered',
      'Original display & parts',
      'Face ID / fingerprint working',
      'Network unlocked',
      'Factory reset & sanitised',
      '70-point inspection passed',
    ];
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.fact_check_rounded,
            title: 'Condition Report',
            trailing: _Pill(
              text: grade.name.toUpperCase(),
              color: AppColors.primary,
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
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
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          Text(
                            'Battery',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
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
                              width: 58,
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
          const Divider(height: 26),
          Wrap(
            runSpacing: 10,
            children: [
              for (final c in checks)
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c,
                          style: const TextStyle(fontSize: 12.5, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Delivery & services ─────────────────────────────

class _DeliveryCard extends StatefulWidget {
  const _DeliveryCard({required this.product});
  final Product product;

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  String _city = 'Dhaka';
  static const _cities = {
    'Dhaka': 1,
    'Chattogram': 2,
    'Sylhet': 3,
    'Rajshahi': 3,
    'Khulna': 3,
    'Barishal': 3,
    'Rangpur': 4,
    'Mymensingh': 3,
  };

  @override
  Widget build(BuildContext context) {
    final eta = DateTime.now().add(Duration(days: _cities[_city] ?? 3));
    final warranty = widget.product.warrantyMonths;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.local_shipping_rounded,
            title: 'Delivery & Services',
            trailing: PopupMenuButton<String>(
              initialValue: _city,
              onSelected: (v) => setState(() => _city = v),
              itemBuilder: (_) => [
                for (final c in _cities.keys)
                  PopupMenuItem(value: c, child: Text(c)),
              ],
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  Text(
                    _city,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.bolt_rounded,
            title: 'Get it by ${DateFormat('EEE, d MMM').format(eta)}',
            subtitle: _city == 'Dhaka'
                ? 'Express delivery • Order within 4h'
                : 'Standard delivery',
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            icon: Icons.payments_outlined,
            title: 'Cash on Delivery available',
            subtitle: 'Check the phone before you pay',
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            icon: Icons.assignment_return_outlined,
            title: '7-day easy return',
            subtitle: 'Full refund if not as described',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.shield_outlined,
            title: warranty > 0
                ? '$warranty months GAMEX warranty'
                : 'Seller warranty',
            subtitle: 'Covers hardware & battery defects',
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Seller ─────────────────────────────

class _SellerCard extends StatelessWidget {
  const _SellerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String v, String l) => Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text(
            l,
            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
    return _Section(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,

                            'GAMEX Certified Store',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    Text(
                      'Official refurbished partner • Dhaka',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 38),
                ),
                onPressed: () =>
                    showAppSnack(context, 'Chat with seller coming soon'),
                child: const Text('Chat'),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              stat('4.9★', 'Seller rating'),
              stat('98%', 'Positive'),
              stat('< 1h', 'Response'),
              stat('25k+', 'Sold'),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Reviews ─────────────────────────────

enum _ReviewFilter { all, media, five, four, three, low }

class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection({required this.product, required this.variant});
  final Product product;
  final String variant;

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  _ReviewFilter _filter = _ReviewFilter.all;
  bool _showAll = false;

  bool _match(Review r) => switch (_filter) {
    _ReviewFilter.all => true,
    _ReviewFilter.media => r.hasMedia,
    _ReviewFilter.five => r.rating == 5,
    _ReviewFilter.four => r.rating == 4,
    _ReviewFilter.three => r.rating == 3,
    _ReviewFilter.low => r.rating <= 2,
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final summary = ref.watch(ratingSummaryProvider(p.id));
    final all = ref.watch(reviewsProvider(p.id));
    final media = [for (final r in all) ...r.media];
    final list = all.where(_match).toList();
    final shown = _showAll ? list : list.take(3).toList();
    const labels = {
      _ReviewFilter.all: 'All',
      _ReviewFilter.media: 'With media',
      _ReviewFilter.five: '5★',
      _ReviewFilter.four: '4★',
      _ReviewFilter.three: '3★',
      _ReviewFilter.low: '1-2★',
    };

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.reviews_rounded,
            title: 'Ratings & Reviews',
          ),
          const SizedBox(height: 16),
          RatingSummaryView(summary: summary),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: () => showWriteReviewSheet(
              context,
              productId: p.id,
              variant: widget.variant,
            ),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Write a review • Add photos & video'),
          ),
          if (media.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Customer photos & videos (${media.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => MediaThumb(
                  media: media[i],
                  size: 72,
                  onTap: () => openMediaViewer(context, media, i),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _ReviewFilter.values)
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
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No reviews in this filter yet')),
            ),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ReviewTile(review: shown[i]),
          ],
          if (list.length > 3)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll
                      ? 'Show fewer reviews'
                      : 'See all ${list.length} reviews',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Q&A ─────────────────────────────

class _QuestionsSection extends ConsumerStatefulWidget {
  const _QuestionsSection({required this.product});
  final Product product;

  @override
  ConsumerState<_QuestionsSection> createState() => _QuestionsSectionState();
}

class _QuestionsSectionState extends ConsumerState<_QuestionsSection> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final text = _c.text.trim();
    if (text.length < 5) {
      return showAppSnack(context, 'Please type your question');
    }
    final user = ref.read(authProvider);
    await ref
        .read(userQuestionsProvider.notifier)
        .ask(widget.product.id, user?.name ?? 'You', text);
    _c.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      showAppSnack(context, 'Question posted. We usually answer within 1 hour');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = ref.watch(questionsProvider(widget.product.id));
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.forum_rounded,
            title: 'Questions & Answers',
            trailing: Text(
              '${questions.length}',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
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
          const SizedBox(height: 6),
          for (final q in questions.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Q',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                      const Text(
                        'A',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          q.answer ?? 'Awaiting answer from GAMEX…',
                          style: TextStyle(
                            height: 1.4,
                            color: q.answer == null
                                ? theme.colorScheme.outline
                                : null,
                            fontStyle: q.answer == null
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      '${q.author} • ${DateFormat('d MMM yyyy').format(q.createdAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Recommendations ─────────────────────────────

class _Recommendations extends ConsumerWidget {
  const _Recommendations({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(
      productsProvider((
        categoryId: product.categoryId,
        query: null,
        sort: ProductSort.popular,
      )),
    );
    final popular = ref.watch(allProductsProvider);
    final key = productKeyOf(product.id);
    final a = (similar.asData?.value ?? const <Product>[])
        .where((p) => p.id != key)
        .toList();
    final b = (popular.asData?.value ?? const <Product>[])
        .where((p) => p.id != key && p.categoryId != product.categoryId)
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.isNotEmpty) _Rail(title: 'Similar phones', products: a),
        if (b.isNotEmpty) _Rail(title: 'Customers also viewed', products: b),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.title, required this.products});
  final String title;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final k = MediaQuery.sizeOf(context).width / 852;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: kListingCardHeight * k,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 253 * k,
              child: ListingCard(product: products[i]),
            ),
          ),
        ),
      ],
    );
  }
}
