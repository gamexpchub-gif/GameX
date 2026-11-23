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
import '../../../data/mock/mock_data.dart';
import '../../../data/models/product.dart';
import '../../../data/models/review.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../discover/presentation/widgets/fair_price_meter.dart';
import '../../discover/presentation/widgets/pdp_discover_actions.dart';
import '../../discover/providers/discover_providers.dart';
import '../../home/presentation/widgets/design_scale.dart' show HomeColors;
import '../../home/presentation/widgets/home_sheets.dart';
import '../../reviews/providers/reviews_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import 'widgets/pdp_sections.dart';
import 'widgets/pdp_sheets.dart';
import 'widgets/review_widgets.dart';

/// Product page laid out on the design mockup's grid (887 px wide);
/// `d` converts design px to logical px.
extension PdpScale on BuildContext {
  double get d => MediaQuery.sizeOf(this).width / 887;
}

const _img = 'assets/images/home';

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

// ───────────────────────────── Options ─────────────────────────────

const _storageLadder = ['64GB', '128GB', '256GB', '512GB', '1TB'];

class ColorOption {
  const ColorOption(this.name, this.color, [this.hero]);
  final String name;
  final int color;

  /// Studio hero variant (iPhones) shown when this colour is picked.
  final String? hero;
}

double _round99(double v) => (v / 100).round() * 100 - 1;

class _ProductPage extends ConsumerStatefulWidget {
  const _ProductPage({required this.product});
  final Product product;

  @override
  ConsumerState<_ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<_ProductPage> {
  final _gallery = PageController();
  final _highlightsKey = GlobalKey();
  final _specsKey = GlobalKey();
  final _reviewsKey = GlobalKey();
  int _page = 0;
  int _color = 0;
  late int _storage;

  Product get p => widget.product;
  String get _key => productKeyOf(p.id);

  late final List<String> _storages = () {
    final base = p.storage ?? '';
    final i = _storageLadder.indexOf(base);
    if (i < 0) return [base.isEmpty ? 'Standard' : base];
    final start = i.clamp(0, _storageLadder.length - 3);
    return _storageLadder.sublist(
      start,
      (start + 3).clamp(0, _storageLadder.length),
    );
  }();

  late final List<ColorOption> _colors = () {
    final hero = MockData.pdpHero[_key];
    final isIphone = hero != null;
    final list = <ColorOption>[
      ColorOption(
        p.colorName ?? 'Original',
        p.colors.isEmpty ? 0xFF5B3E96 : p.colors.first,
        hero,
      ),
      ColorOption('Silver', 0xFFE3E6EE, isIphone ? 'iphone_starlight' : null),
      ColorOption(
        'Space Black',
        0xFF111111,
        isIphone ? 'iphone_midnight' : null,
      ),
      ColorOption('Gold', 0xFFE8B86A, isIphone ? 'iphone_titanium' : null),
    ];
    final seen = <String>{};
    return [
      for (final c in list)
        if (seen.add(c.name)) c,
    ];
  }();

  int get _baseStorage =>
      _storages.indexOf(p.storage ?? '').clamp(0, _storages.length - 1);
  double _priceFor(int s) =>
      _round99(p.price * (1 + (s - _baseStorage) * 0.14));
  double get _price => _priceFor(_storage);
  double get _mrp => _round99(p.mrp * (1 + (_storage - _baseStorage) * 0.14));
  int get _off => _mrp <= _price ? 0 : ((_mrp - _price) / _mrp * 100).round();

  /// Gallery pages (asset/art/network specs).
  List<String> get _pages {
    final hero = _colors[_color].hero;
    if (hero == null) return p.images;
    return [
      'asset:$_img/pdp_hero_$hero.jpg',
      'asset:$_img/pdp_cam_$hero.jpg',
      ...p.images,
    ];
  }

  String get _variantLabel =>
      '${p.ram != null ? '${p.ram} / ' : ''}${_storages[_storage]} • ${_colors[_color].name}';

  Product get _configured => p.copyWith(
    price: _price,
    oldPrice: _mrp,
    variant: '${_storages[_storage]} • ${_colors[_color].name}',
    colors: [_colors[_color].color],
  );

  @override
  void initState() {
    super.initState();
    _storage = _baseStorage;
    Future.microtask(() => ref.read(recentlyViewedProvider.notifier).record(p));
  }

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  void _add({required bool buy}) {
    HapticFeedback.mediumImpact();
    ref
        .read(cartProvider.notifier)
        .add(_configured, size: _variantLabel, color: _colors[_color].color);
    if (!buy) {
      showAppSnack(
        context,
        'Added to cart',
        action: 'VIEW',
        onAction: () => context.push('/cart'),
      );
    } else if (ref.read(authProvider) == null) {
      context.push('/login?from=${Uri.encodeComponent('/checkout')}');
    } else {
      context.push('/checkout');
    }
  }

  void _openGallery([int? i]) => openMediaViewer(context, [
    for (final x in _pages) ReviewMedia(x),
  ], i ?? _page);

  @override
  Widget build(BuildContext context) {
    final d = context.d;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F4FD),
          body: AuroraBackground(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: mq.padding.top)),
                SliverToBoxAdapter(child: _Header(product: p)),
                SliverToBoxAdapter(child: SizedBox(height: 18 * d)),
                SliverToBoxAdapter(child: _hero(d)),
                SliverToBoxAdapter(child: SizedBox(height: 16 * d)),
                SliverToBoxAdapter(child: _thumbs(d)),
                SliverToBoxAdapter(child: SizedBox(height: 22 * d)),
                SliverToBoxAdapter(child: _titleBlock(d)),
                SliverToBoxAdapter(child: SizedBox(height: 22 * d)),
                SliverToBoxAdapter(child: _priceCard(d)),
                SliverToBoxAdapter(child: SizedBox(height: 18 * d)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 19 * d),
                    child: Column(
                      children: [
                        FairPriceMeter(product: p, price: _price),
                        const SizedBox(height: 10),
                        PdpDiscoverActions(product: p),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 18 * d)),
                SliverToBoxAdapter(child: _emiCard(d)),
                SliverToBoxAdapter(child: SizedBox(height: 26 * d)),
                SliverToBoxAdapter(child: _options(d)),
                SliverToBoxAdapter(child: SizedBox(height: 22 * d)),
                SliverToBoxAdapter(child: _features(d)),
                SliverToBoxAdapter(child: SizedBox(height: 18 * d)),
                SliverToBoxAdapter(child: _quickLinks(d)),
                SliverToBoxAdapter(child: SizedBox(height: 26 * d)),
                SliverToBoxAdapter(
                  child: PdpSections(
                    product: p,
                    price: _price,
                    variantLabel: _variantLabel,
                    heroVariant: _colors[_color].hero,
                    highlightsKey: _highlightsKey,
                    specsKey: _specsKey,
                    reviewsKey: _reviewsKey,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 40 * d)),
              ],
            ),
          ),
          bottomNavigationBar: _bottomBar(d, mq),
        ),
      ),
    );
  }

  // ── Hero gallery ──
  Widget _hero(double d) {
    final wished = ref.watch(isWishlistedProvider(p.id));
    final pages = _pages;
    Widget circle(Widget icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76 * d,
        height: 76 * d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14 * d,
            ),
          ],
        ),
        child: Center(child: icon),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40 * d),
        child: SizedBox(
          // Square gallery (equal sides).
          height: 849 * d,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2B1468),
                        Color(0xFF7B3FD0),
                        Color(0xFF3A1C8C),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: PageView.builder(
                    controller: _gallery,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _openGallery(i),
                      child: pages[i].contains('pdp_')
                          ? Image.asset(
                              pages[i].substring(6),
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              gaplessPlayback: true,
                            )
                          : Padding(
                              padding: EdgeInsets.all(26 * d),
                              child: AppImage(
                                pages[i],
                                borderRadius: BorderRadius.circular(28 * d),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              if (p.verified)
                Positioned(
                  left: 19 * d,
                  top: 24 * d,
                  child: Container(
                    height: 46 * d,
                    padding: EdgeInsets.only(left: 4 * d, right: 18 * d),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(23 * d),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          '$_img/icon_certified.png',
                          width: 40 * d,
                          height: 42 * d,
                        ),
                        SizedBox(width: 8 * d),
                        Text(
                          'GAMEX Certified',
                          style: TextStyle(
                            fontSize: 19 * d,
                            fontWeight: FontWeight.w600,
                            color: HomeColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 19 * d,
                top: 84 * d,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroTag(
                      d: d,
                      icon: Icons.diamond_outlined,
                      text:
                          '${(p.condition ?? 'Excellent').replaceAll(' Condition', '')} Condition${p.batteryHealth > 0 ? '  •  🔋 ${p.batteryHealth}%' : ''}',
                      onTap: () => showConditionReport(context, p),
                    ),
                    SizedBox(height: 12 * d),
                    _HeroTag(
                      d: d,
                      live: true,
                      icon: Icons.videocam_rounded,
                      text: 'LIVE View',
                      onTap: () => context.push('/live-review/${p.id}'),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 17 * d,
                top: 15 * d,
                child: Column(
                  children: [
                    circle(
                      Icon(
                        wished
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 38 * d,
                        color: wished ? AppColors.danger : HomeColors.ink,
                      ),
                      () {
                        HapticFeedback.lightImpact();
                        ref.read(wishlistProvider.notifier).toggle(p);
                      },
                    ),
                    SizedBox(height: 11 * d),
                    circle(
                      Icon(
                        Icons.share_outlined,
                        size: 34 * d,
                        color: HomeColors.ink,
                      ),
                      () {
                        Clipboard.setData(
                          ClipboardData(text: 'https://gamex.shop/p/${p.id}'),
                        );
                        showAppSnack(context, 'Product link copied');
                      },
                    ),
                    SizedBox(height: 11 * d),
                    circle(
                      Icon(
                        Icons.threed_rotation_rounded,
                        size: 40 * d,
                        color: HomeColors.ink,
                      ),
                      () => open360View(context, pages.first),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 19 * d,
                bottom: 24 * d,
                child: GestureDetector(
                  onTap: () => open360View(context, pages.first),
                  child: Container(
                    height: 64 * d,
                    padding: EdgeInsets.symmetric(horizontal: 24 * d),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14183A).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(32 * d),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.view_in_ar_rounded,
                          color: Colors.white,
                          size: 32 * d,
                        ),
                        SizedBox(width: 12 * d),
                        Text(
                          '3D / 360° View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19 * d,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20 * d,
                bottom: 24 * d,
                child: GestureDetector(
                  onTap: _openGallery,
                  child: Container(
                    width: 66 * d,
                    height: 64 * d,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14183A).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18 * d),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 38 * d,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 34 * d,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 4 * d),
                          width: (i == _page ? 24 : 11) * d,
                          height: 11 * d,
                          decoration: BoxDecoration(
                            color: i == _page ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(6 * d),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbs(double d) {
    final pages = _pages;
    final videos = [
      for (final r in ref.watch(reviewsProvider(p.id)))
        ...r.media.where((m) => m.isVideo),
    ];
    Widget frame(bool sel, Widget child) => Container(
      width: 150 * d,
      height: 150 * d,
      padding: EdgeInsets.all(4 * d),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20 * d),
        color: Colors.white,
        border: Border.all(
          color: sel ? AppColors.primary : const Color(0xFFE3E8F5),
          width: sel ? 3 * d : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16 * d),
        child: child,
      ),
    );
    return SizedBox(
      height: 150 * d,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 19 * d),
        children: [
          for (var i = 0; i < pages.length; i++)
            Padding(
              padding: EdgeInsets.only(right: 14 * d),
              child: GestureDetector(
                onTap: () => _gallery.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                child: frame(
                  i == _page,
                  pages[i].contains('pdp_')
                      ? Image.asset(
                          pages[i].substring(6),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                        )
                      : AppImage(pages[i]),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => videos.isEmpty
                ? showAppSnack(context, 'Product video will be available soon')
                : openMediaViewer(context, videos, 0),
            child: frame(
              false,
              Container(
                color: const Color(0xFF14183A),
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white,
                  size: 56 * d,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Title, rating ──
  Widget _titleBlock(double d) {
    final summary = ref.watch(ratingSummaryProvider(p.id));
    final sold = p.soldCount >= 1000
        ? '${(p.soldCount / 1000).floor()}K+'
        : '${p.soldCount}+';
    final reviewsText = summary.total.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 70 * d,
                child: BrandBadge(brand: p.categoryId, size: 70 * d),
              ),
              SizedBox(width: 30 * d),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.brand == 'Apple' ? 'Apple ' : ''}${p.name}',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 44 * d,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8 * d,
                        color: HomeColors.ink,
                      ),
                    ),
                    SizedBox(height: 8 * d),
                    Text(
                      '${_storages[_storage]} Storage   |   ${_colors[_color].name}',
                      style: TextStyle(
                        fontSize: 24 * d,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (p.isFeatured || p.reviewCount > 5000) ...[
                SizedBox(width: 10 * d),
                Container(
                  height: 46 * d,
                  padding: EdgeInsets.symmetric(horizontal: 14 * d),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF0C2), Color(0xFFFCDD8A)],
                    ),
                    borderRadius: BorderRadius.circular(23 * d),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 28 * d,
                        color: const Color(0xFFE08A00),
                      ),
                      SizedBox(width: 6 * d),
                      Text(
                        'Bestseller',
                        style: TextStyle(
                          fontSize: 22 * d,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3B2A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 22 * d),
          Row(
            children: [
              Container(
                height: 40 * d,
                padding: EdgeInsets.symmetric(horizontal: 12 * d),
                decoration: BoxDecoration(
                  color: const Color(0xFF138A3E),
                  borderRadius: BorderRadius.circular(8 * d),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 26 * d, color: Colors.white),
                    SizedBox(width: 6 * d),
                    Text(
                      summary.average.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 22 * d,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16 * d),
              GestureDetector(
                onTap: () => showAllReviewsSheet(
                  context,
                  product: p,
                  variant: _variantLabel,
                ),
                child: Text(
                  '($reviewsText Reviews)',
                  style: TextStyle(
                    fontSize: 23 * d,
                    color: HomeColors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 2 * d,
                height: 30 * d,
                margin: EdgeInsets.symmetric(horizontal: 18 * d),
                color: const Color(0xFFD5DBEA),
              ),
              Icon(
                Icons.local_fire_department_rounded,
                size: 34 * d,
                color: const Color(0xFFFF4D1A),
              ),
              SizedBox(width: 6 * d),
              Text(
                '$sold Sold',
                style: TextStyle(
                  fontSize: 23 * d,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Price ──
  Widget _priceCard(double d) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: Glass(
        radius: 30 * d,
        color: Colors.white.withValues(alpha: 0.9),
        padding: EdgeInsets.fromLTRB(40 * d, 14 * d, 26 * d, 18 * d),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatPrice(_price),
                            style: TextStyle(
                              fontSize: 54 * d,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: HomeColors.blue,
                              letterSpacing: -1 * d,
                            ),
                          ),
                        ),
                      ),
                      if (_off > 0) ...[
                        SizedBox(width: 18 * d),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18 * d,
                            vertical: 6 * d,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE1E4),
                            borderRadius: BorderRadius.circular(26 * d),
                          ),
                          child: Text(
                            '$_off% OFF',
                            style: TextStyle(
                              fontSize: 26 * d,
                              fontWeight: FontWeight.w700,
                              color: HomeColors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_off > 0)
                    Text(
                      formatPrice(_mrp),
                      style: TextStyle(
                        fontSize: 28 * d,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8C95B0),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: const Color(0xFF8C95B0),
                      ),
                    ),
                  SizedBox(height: 6 * d),
                  Text(
                    'Inclusive of all taxes',
                    style: TextStyle(fontSize: 21 * d, color: HomeColors.muted),
                  ),
                ],
              ),
            ),
            if (_off > 0) ...[
              Container(
                width: 2 * d,
                height: 96 * d,
                color: const Color(0xFFE3E8F5),
              ),
              SizedBox(width: 28 * d),
              Container(
                width: 210 * d,
                padding: EdgeInsets.symmetric(vertical: 12 * d),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9F5E3),
                  borderRadius: BorderRadius.circular(22 * d),
                ),
                child: Column(
                  children: [
                    Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 27 * d,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.green,
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        formatPrice(_mrp - _price),
                        style: TextStyle(
                          fontSize: 30 * d,
                          fontWeight: FontWeight.w800,
                          color: HomeColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emiCard(double d) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: GestureDetector(
        onTap: () => showEmiSheet(context),
        child: Glass(
          radius: 30 * d,
          color: Colors.white.withValues(alpha: 0.9),
          child: SizedBox(
            height: 84 * d,
            child: Row(
              children: [
                SizedBox(width: 40 * d),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 54 * d,
                  color: HomeColors.blue,
                ),
                SizedBox(width: 26 * d),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMI from ${formatPrice((_price / 20).roundToDouble())}/month',
                        style: TextStyle(
                          fontSize: 25 * d,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.ink,
                        ),
                      ),
                      Text(
                        'No Cost EMI Available',
                        style: TextStyle(
                          fontSize: 21 * d,
                          color: HomeColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'View Plans',
                  style: TextStyle(
                    fontSize: 24 * d,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.blue,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 36 * d,
                  color: HomeColors.blue,
                ),
                SizedBox(width: 26 * d),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Colour + storage (side by side, as in the design) ──
  Widget _options(double d) {
    TextStyle label() => TextStyle(
      fontSize: 25 * d,
      fontWeight: FontWeight.w700,
      color: HomeColors.ink,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(19 * d, 0, 19 * d, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 385,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 21 * d),
                    child: Text('Choose Color', style: label()),
                  ),
                  SizedBox(height: 18 * d),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < _colors.length; i++)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _color = i;
                              _page = 0;
                            });
                            if (_gallery.hasClients) _gallery.jumpToPage(0);
                          },
                          child: _Swatch(
                            color: Color(_colors[i].color),
                            selected: i == _color,
                            d: d,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 2 * d,
              margin: EdgeInsets.symmetric(horizontal: 22 * d, vertical: 6 * d),
              color: const Color(0xFFE3E8F5),
            ),
            Expanded(
              flex: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 4 * d),
                    child: Text('Choose Storage', style: label()),
                  ),
                  SizedBox(height: 18 * d),
                  Row(
                    children: [
                      for (var i = 0; i < _storages.length; i++) ...[
                        if (i > 0) SizedBox(width: 8 * d),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _storage = i);
                            },
                            child: Container(
                              height: 64 * d,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == _storage
                                    ? HomeColors.blue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(32 * d),
                                border: Border.all(
                                  color: i == _storage
                                      ? HomeColors.blue
                                      : const Color(0xFFE3E8F5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (i == _storage
                                                ? HomeColors.blue
                                                : const Color(0xFF2A3D8F))
                                            .withValues(
                                              alpha: i == _storage ? 0.3 : 0.06,
                                            ),
                                    blurRadius: 14 * d,
                                    offset: Offset(0, 5 * d),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8 * d,
                                  ),
                                  child: Text(
                                    _storages[i],
                                    style: TextStyle(
                                      fontSize: 24 * d,
                                      fontWeight: FontWeight.w600,
                                      color: i == _storage
                                          ? Colors.white
                                          : HomeColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _features(double d) {
    final items = [
      (
        Icons.verified_user_outlined,
        '${p.warrantyMonths > 0 ? p.warrantyMonths : 6} Months\nWarranty',
      ),
      (Icons.workspace_premium_outlined, '52-Point\nQuality Check'),
      (Icons.swap_horiz_rounded, 'Easy\nExchange'),
      (Icons.local_shipping_outlined, 'Free\nDelivery'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: Glass(
        radius: 30 * d,
        color: Colors.white.withValues(alpha: 0.9),
        padding: EdgeInsets.symmetric(vertical: 22 * d),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1.5,
                  height: 92 * d,
                  color: const Color(0xFFE3E8F5),
                ),
              Expanded(
                child: GestureDetector(
                  onTap: () => switch (i) {
                    0 => showFeatureSheet(context, 0),
                    1 => showConditionReport(context, p),
                    2 => showTradeInSheet(context),
                    _ => showAppSnack(
                      context,
                      'Free delivery on orders above ₹5,000',
                    ),
                  },
                  child: Column(
                    children: [
                      Icon(items[i].$1, size: 50 * d, color: HomeColors.blue),
                      SizedBox(height: 8 * d),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22 * d,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickLinks(double d) {
    final total = NumberFormat.decimalPattern('en_IN')
        .format(ref.watch(ratingSummaryProvider(p.id)).total);
    final rows = [
      (
        Icons.description_outlined,
        'Product Highlights',
        'Key features, what\'s in the box',
        _highlightsKey,
      ),
      (
        Icons.settings_outlined,
        'Specifications',
        'Detailed technical information',
        _specsKey,
      ),
      (
        Icons.star_border_rounded,
        'Ratings & Reviews ($total)',
        'Real customer feedback with photos',
        _reviewsKey,
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: Glass(
        radius: 30 * d,
        color: Colors.white.withValues(alpha: 0.9),
        padding: EdgeInsets.symmetric(vertical: 6 * d),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 120 * d, endIndent: 30 * d),
              InkWell(
                onTap: () {
                  final c = rows[i].$4.currentContext;
                  if (c != null) {
                    Scrollable.ensureVisible(
                      c,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      alignment: 0.04,
                    );
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * d,
                    vertical: 14 * d,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72 * d,
                        height: 72 * d,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EFFF),
                          borderRadius: BorderRadius.circular(20 * d),
                        ),
                        child: Icon(
                          rows[i].$1,
                          size: 40 * d,
                          color: HomeColors.blue,
                        ),
                      ),
                      SizedBox(width: 28 * d),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].$2,
                              style: TextStyle(
                                fontSize: 27 * d,
                                fontWeight: FontWeight.w700,
                                color: HomeColors.ink,
                              ),
                            ),
                            Text(
                              rows[i].$3,
                              style: TextStyle(
                                fontSize: 22 * d,
                                color: HomeColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 40 * d,
                        color: HomeColors.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(double d, MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        21 * d,
        16 * d,
        19 * d,
        16 * d + mq.padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A3D8F).withValues(alpha: 0.1),
            blurRadius: 24,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillButton(
              d: d,
              filled: false,
              icon: Icons.shopping_cart_outlined,
              label: 'Add to Cart',
              onTap: p.inStock ? () => _add(buy: false) : null,
            ),
          ),
          SizedBox(width: 19 * d),
          Expanded(
            child: _PillButton(
              d: d,
              filled: true,
              icon: Icons.bolt_rounded,
              label: p.inStock ? 'Buy Now' : 'Sold Out',
              onTap: p.inStock ? () => _add(buy: true) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.d});
  final Color color;
  final bool selected;
  final double d;

  @override
  Widget build(BuildContext context) {
    final dark = color.computeLuminance() < 0.4;
    return Container(
      width: 74 * d,
      height: 74 * d,
      padding: EdgeInsets.all(5 * d),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: selected ? HomeColors.blue : Colors.white,
          width: 3 * d,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10 * d,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [Color.lerp(color, Colors.white, 0.35)!, color],
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                color: dark ? Colors.white : HomeColors.ink,
                size: 34 * d,
              )
            : null,
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.d,
    required this.filled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double d;
  final bool filled;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = filled ? Colors.white : HomeColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 86 * d,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(43 * d),
          gradient: filled
              ? LinearGradient(
                  colors: enabled
                      ? const [Color(0xFF1F66FF), Color(0xFF0046E0)]
                      : const [Color(0xFFA3AEC9), Color(0xFF8D97B3)],
                )
              : null,
          color: filled ? null : Colors.white,
          border: filled
              ? null
              : Border.all(color: const Color(0xFFE3E8F5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: (filled ? HomeColors.blue : const Color(0xFF2A3D8F))
                  .withValues(alpha: filled ? 0.3 : 0.08),
              blurRadius: 18 * d,
              offset: Offset(0, 6 * d),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 42 * d),
            SizedBox(width: 18 * d),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 29 * d,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back · GAMEX logo · search · cart · more.
class _Header extends ConsumerWidget {
  const _Header({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.d;
    final cart = ref.watch(cartCountProvider);
    Widget circle(Widget child, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72 * d,
        height: 72 * d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F).withValues(alpha: 0.1),
              blurRadius: 14 * d,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(22 * d, 10 * d, 20 * d, 0),
      child: Row(
        children: [
          circle(
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 32 * d,
              color: HomeColors.ink,
            ),
            () => context.pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text.rich(
                  const TextSpan(
                    text: 'GAME',
                    children: [
                      TextSpan(
                        text: 'X',
                        style: TextStyle(color: HomeColors.blue),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 46 * d,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1 * d,
                    color: const Color(0xFF0B1020),
                  ),
                ),
                SizedBox(height: 4 * d),
                Text(
                  'Buy Smart. Sell Smart.',
                  style: TextStyle(
                    fontSize: 17 * d,
                    fontWeight: FontWeight.w500,
                    color: HomeColors.ink,
                  ),
                ),
              ],
            ),
          ),
          circle(
            Icon(Icons.search_rounded, size: 38 * d, color: HomeColors.ink),
            () => context.push('/search'),
          ),
          SizedBox(width: 12 * d),
          circle(
            Badge(
              isLabelVisible: cart > 0,
              backgroundColor: HomeColors.red,
              label: Text('$cart'),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 38 * d,
                color: HomeColors.ink,
              ),
            ),
            () => context.push('/cart'),
          ),
          SizedBox(width: 12 * d),
          circle(
            Icon(Icons.more_horiz_rounded, size: 38 * d, color: HomeColors.ink),
            () => showProductMenu(context, product),
          ),
        ],
      ),
    );
  }
}

/// Small pill on the gallery (condition / LIVE View).
class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.d,
    required this.icon,
    required this.text,
    required this.onTap,
    this.live = false,
  });
  final double d;
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46 * d,
        padding: EdgeInsets.symmetric(horizontal: 16 * d),
        decoration: BoxDecoration(
          color: live
              ? const Color(0xFFE5283B)
              : const Color(0xFF14183A).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(23 * d),
          border: Border.all(
            color: Colors.white.withValues(alpha: live ? 0.6 : 0.25),
          ),
          boxShadow: live
              ? [
                  BoxShadow(
                    color: const Color(0xFFE5283B).withValues(alpha: 0.45),
                    blurRadius: 14 * d,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live)
              Container(
                width: 12 * d,
                height: 12 * d,
                margin: EdgeInsets.only(right: 8 * d),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            Icon(icon, size: 26 * d, color: Colors.white),
            SizedBox(width: 8 * d),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * d,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
