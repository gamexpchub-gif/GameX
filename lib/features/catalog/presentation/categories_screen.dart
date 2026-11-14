import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/brand_marks.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/listing_card.dart';
import '../../../core/widgets/phone_art.dart';
import '../../home/presentation/widgets/design_scale.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../../home/presentation/widgets/home_sheets.dart';
import '../providers/listings_provider.dart';

const _img = 'assets/images/home';

/// One tile in "Shop by Category".
class _Cat {
  const _Cat(this.id, this.label, {this.photo, this.art});
  final String id;
  final String label;

  /// Transparent product photo shown instead of the brand logo.
  final String? photo;

  /// Drawn phone colour shown instead of the brand logo.
  final int? art;
}

const _categories = [
  _Cat('apple', 'iPhone', photo: '$_img/cut_iphone_midnight.png'),
  _Cat('samsung', 'Samsung', art: 0xFF2453C8),
  _Cat('google', 'Google\nPixel'),
  _Cat('oneplus', 'OnePlus'),
  _Cat('vivo', 'Vivo'),
  _Cat('xiaomi', 'Xiaomi'),
  _Cat('realme', 'Realme'),
  _Cat('nothing', 'Nothing'),
  _Cat('motorola', 'Motorola'),
  _Cat('others', 'Others'),
];

class _Collection {
  const _Collection(this.id, this.title, this.discount, {this.photo, this.art});
  final String id;
  final String title;
  final int discount;
  final String? photo;
  final int? art;
}

const _collections = [
  _Collection(
    'apple',
    'iPhone Series',
    60,
    photo: '$_img/cut_iphone_purple.png',
  ),
  _Collection('samsung', 'Samsung Galaxy', 65, art: 0xFF2453C8),
  _Collection('google', 'Google Pixel', 65, art: 0xFF2B2F3A),
  _Collection('oneplus', 'OnePlus Series', 65, art: 0xFF4E8A72),
];

class _Banner {
  const _Banner(this.image, this.title, this.highlights, this.link);
  final String image;
  final String title;
  final String highlights;
  final String link;
}

const _banners = [
  _Banner(
    '$_img/hero_banner.png',
    'Premium\nSecond-Hand\nMobiles',
    'Trusted  •  Verified  •  Affordable',
    '/category/all',
  ),
  _Banner(
    '$_img/hero_banner_violet.png',
    'Flagship\nPhones for\nLess',
    'Pro Checked  •  Warranty',
    '/category/apple',
  ),
  _Banner(
    '$_img/hero_banner_teal.png',
    'Upgrade\nwith Smart\nEMI',
    '0% Interest  •  12 Months',
    '/category/samsung',
  ),
  _Banner(
    '$_img/hero_banner_magenta.png',
    'Trade-In &\nSave\nMore',
    'Instant Quote  •  Free Pickup',
    '/category/google',
  ),
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _open(BuildContext context, String id) {
    HapticFeedback.selectionClick();
    context.push('/category/${id == 'others' ? 'all' : id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final mq = MediaQuery.of(context);

    Widget box(Widget child) => SliverToBoxAdapter(child: child);
    Widget gap(double h) => SliverToBoxAdapter(child: SizedBox(height: h * k));

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AuroraBackground(
            child: NotificationListener<ScrollNotification>(
              // Endless feed: fetch the next page ~1.5 screens before the end.
              onNotification: (n) {
                if (n is ScrollUpdateNotification &&
                    n.metrics.extentAfter < mq.size.height * 1.5 &&
                    !ref.read(listingsProvider).loading) {
                  ref.read(listingsProvider.notifier).loadMore();
                }
                return false;
              },
              child: RefreshIndicator(
                edgeOffset: mq.padding.top,
                onRefresh: () => ref.read(listingsProvider.notifier).refresh(),
                child: CustomScrollView(
                  slivers: [
                    gap(mq.padding.top / k + 4),
                    box(
                      HomeHeader(
                        notifications: 3,
                        onBell: () => showNotificationsSheet(context),
                        onAvatar: () => context.go('/profile'),
                      ),
                    ),
                    gap(11),
                    box(
                      HomeSearchBar(
                        height: 67,
                        side: 30,
                        onScan: () => showAppSnack(
                          context,
                          'IMEI / QR scanner coming soon',
                        ),
                      ),
                    ),
                    gap(20),
                    box(const _BannerCarousel()),
                    gap(34),
                    box(
                      _SectionTitle(
                        title: 'Shop by Category',
                        onViewAll: () => _open(context, 'others'),
                      ),
                    ),
                    gap(19),
                    box(_CategoryGrid(onTap: (id) => _open(context, id))),
                    gap(33),
                    box(
                      _SmartChoiceCard(onTap: () => _open(context, 'others')),
                    ),
                    gap(33),
                    box(
                      _SectionTitle(
                        title: 'Popular Collections',
                        onViewAll: () => _open(context, 'others'),
                      ),
                    ),
                    gap(20),
                    box(_Collections(onTap: (id) => _open(context, id))),
                    gap(40),
                    box(
                      _SectionTitle(
                        title: 'New Listings',
                        badge: 'LIVE',
                        onViewAll: () => _open(context, 'others'),
                      ),
                    ),
                    gap(20),
                    // Only the feed rebuilds when a new page arrives.
                    Consumer(
                      builder: (context, ref, _) {
                        final items = ref.watch(
                          listingsProvider.select((s) => s.items),
                        );
                        return SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 30 * k),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 22 * k,
                                  crossAxisSpacing: 20 * k,
                                  // Two cards across: (852 - 2×30 - 20) / 2 design px wide.
                                  mainAxisExtent: listingCardHeight(386 * k),
                                ),
                            itemCount: items.length,
                            addRepaintBoundaries: false,
                            itemBuilder: (_, i) => RepaintBoundary(
                              child: ListingCard(
                                key: ValueKey(items[i].id),
                                product: items[i],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, _) => box(
                        _FeedFooter(
                          state: ref.watch(listingsProvider),
                          onRetry: () =>
                              ref.read(listingsProvider.notifier).loadMore(),
                        ),
                      ),
                    ),
                    gap(mq.padding.bottom / k + 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state, required this.onRetry});
  final ListingsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    Widget child;
    if (state.error) {
      child = TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Could not load. Tap to retry'),
      );
    } else if (state.loading || state.hasMore) {
      child = SizedBox(
        width: 28 * k,
        height: 28 * k,
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else {
      child = Text(
        "You're all caught up 🎉",
        style: TextStyle(fontSize: 18 * k, color: HomeColors.grey),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28 * k),
      child: Center(child: child),
    );
  }
}

// ───────────────────────────── Banner ─────────────────────────────

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _page = PageController();
  final _index = ValueNotifier(0);

  @override
  void dispose() {
    _page.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      children: [
        SizedBox(
          height: 350 * k,
          child: PageView.builder(
            controller: _page,
            clipBehavior: Clip.none,
            itemCount: _banners.length,
            onPageChanged: (i) => _index.value = i,
            itemBuilder: (_, i) =>
                RepaintBoundary(child: _BannerCard(banner: _banners[i])),
          ),
        ),
        SizedBox(height: 21 * k),
        ValueListenableBuilder<int>(
          valueListenable: _index,
          builder: (_, idx, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _banners.length; i++)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 5 * k),
                  width: (i == idx ? 30 : 26) * k,
                  height: 10 * k,
                  decoration: BoxDecoration(
                    color: i == idx ? HomeColors.blue : const Color(0xFFC9D6F7),
                    borderRadius: BorderRadius.circular(5 * k),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});
  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final radius = BorderRadius.circular(36 * k);
    return GestureDetector(
      onTap: () => context.push(banner.link),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 25 * k),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: const Color(0xFF041659),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2A8A).withValues(alpha: 0.18),
                      blurRadius: 26 * k,
                      offset: Offset(0, 10 * k),
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Image.asset(
                    banner.image,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.6, 0.75),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            // Copy.
            Positioned(
              left: 37 * k,
              top: 23 * k,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 49 * k,
                    padding: EdgeInsets.only(left: 3 * k, right: 18 * k),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(25 * k),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          '$_img/icon_certified.png',
                          width: 44 * k,
                          height: 47 * k,
                        ),
                        SizedBox(width: 9 * k),
                        Text(
                          'GAMEX Certified',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19.5 * k,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14 * k),
                  Text(
                    banner.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44 * k,
                      height: 1.04,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6 * k,
                    ),
                  ),
                  SizedBox(height: 14 * k),
                  Text(
                    banner.highlights,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21 * k,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 22 * k),
                  Container(
                    width: 234 * k,
                    height: 62 * k,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(31 * k),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F66FF), Color(0xFF0046E0)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Explore Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22 * k,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 12 * k),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 27 * k,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // "Up to 70% OFF" sticker breaking out of the right edge.
            Positioned(
              left: 687 * k,
              top: 7 * k,
              child: Container(
                width: 130 * k,
                height: 130 * k,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.93),
                  border: Border.all(
                    color: const Color(0xFFBFD3FF),
                    width: 3 * k,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7FA6FF).withValues(alpha: 0.5),
                      blurRadius: 18 * k,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Up to',
                      style: TextStyle(
                        fontSize: 22 * k,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.ink,
                      ),
                    ),
                    Text(
                      '70%',
                      style: TextStyle(
                        fontSize: 41 * k,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.blue,
                        letterSpacing: -1 * k,
                      ),
                    ),
                    Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: 26 * k,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Section title ─────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.onViewAll,
    this.badge,
  });
  final String title;
  final VoidCallback onViewAll;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: EdgeInsets.only(left: 28 * k, right: 30 * k),
      child: Row(
        children: [
          Container(
            width: 8 * k,
            height: 32 * k,
            decoration: BoxDecoration(
              color: HomeColors.blue,
              borderRadius: BorderRadius.circular(4 * k),
            ),
          ),
          SizedBox(width: 18 * k),
          Text(
            title,
            style: TextStyle(
              fontSize: 30 * k,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5 * k,
              color: HomeColors.ink,
            ),
          ),
          if (badge != null) ...[
            SizedBox(width: 12 * k),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 3 * k),
              decoration: BoxDecoration(
                color: HomeColors.red,
                borderRadius: BorderRadius.circular(8 * k),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14 * k,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onViewAll,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6 * k),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 22 * k,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.blue,
                    ),
                  ),
                  SizedBox(width: 12 * k),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 27 * k,
                    color: HomeColors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Category grid ─────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    Widget row(List<_Cat> items) => Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: 19.5 * k),
          Expanded(
            child: _CategoryTile(
              cat: items[i],
              onTap: () => onTap(items[i].id),
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * k),
      child: Column(
        children: [
          row(_categories.sublist(0, 5)),
          SizedBox(height: 21 * k),
          row(_categories.sublist(5)),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.cat, required this.onTap});
  final _Cat cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final twoLine = cat.label.contains('\n');
    Widget visual;
    if (cat.photo != null) {
      visual = Image.asset(
        cat.photo!,
        height: 74 * k,
        filterQuality: FilterQuality.medium,
      );
    } else if (cat.art != null) {
      visual = SizedBox(
        width: 90 * k,
        height: 74 * k,
        child: PhoneArt(
          spec: PhoneArtSpec(Color(cat.art!), 'duo'),
          background: false,
        ),
      );
    } else {
      visual = BrandLogo(
        cat.id,
        width: 110 * k,
        height: twoLine ? 66 * k : 74 * k,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 24 * k,
        color: Colors.white.withValues(alpha: 0.78),
        child: SizedBox(
          height: 128 * k,
          child: Column(
            children: [
              SizedBox(height: (twoLine ? 10 : 14) * k),
              SizedBox(
                height: (twoLine ? 66 : 74) * k,
                child: Center(child: visual),
              ),
              const Spacer(),
              Text(
                cat.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19.5 * k,
                  height: 1.08,
                  fontWeight: FontWeight.w500,
                  color: HomeColors.ink,
                ),
              ),
              SizedBox(height: (twoLine ? 8 : 14) * k),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Smart choice ─────────────────────────────

class _SmartChoiceCard extends StatelessWidget {
  const _SmartChoiceCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    Widget phone(String photo, double h, double angle) => Transform.rotate(
      angle: angle,
      child: Image.asset(photo, height: h, filterQuality: FilterQuality.medium),
    );

    Widget pill(IconData icon, String label) => Container(
      width: 163 * k,
      height: 52 * k,
      padding: EdgeInsets.only(left: 14 * k),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(26 * k),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
            blurRadius: 12 * k,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 28 * k, color: HomeColors.blue),
          SizedBox(width: 10 * k),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5 * k,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.ink,
                ),
              ),
            ),
          ),
          SizedBox(width: 10 * k),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25 * k),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 256 * k,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32 * k),
            gradient: const LinearGradient(
              colors: [Color(0xFFF1F4FF), Color(0xFFE2E9FF), Color(0xFFC9D8FF)],
              stops: [0, 0.45, 1],
            ),
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
                blurRadius: 24 * k,
                blurStyle: BlurStyle.outer,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32 * k),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Soft light pool behind the phones.
                Positioned(
                  left: 300 * k,
                  top: 20 * k,
                  child: Container(
                    width: 360 * k,
                    height: 360 * k,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 372 * k,
                  top: 56 * k,
                  child: phone(
                    '$_img/cutfront_iphone_titanium.png',
                    205 * k,
                    -0.07,
                  ),
                ),
                Positioned(
                  left: 548 * k,
                  top: 40 * k,
                  child: phone(
                    '$_img/cutfront_iphone_purple.png',
                    215 * k,
                    0.06,
                  ),
                ),
                Positioned(
                  left: 455 * k,
                  top: 16 * k,
                  child: phone(
                    '$_img/cutfront_iphone_midnight.png',
                    245 * k,
                    0,
                  ),
                ),
                Positioned(
                  left: 30 * k,
                  top: 26 * k,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Choice\nSmart Savings',
                        style: TextStyle(
                          fontSize: 36 * k,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6 * k,
                          color: HomeColors.ink,
                        ),
                      ),
                      SizedBox(height: 12 * k),
                      Text(
                        'Get the best value on\npremium used mobiles.',
                        style: TextStyle(
                          fontSize: 19.5 * k,
                          height: 1.25,
                          color: HomeColors.inkSoft,
                        ),
                      ),
                      SizedBox(height: 18 * k),
                      Container(
                        width: 193 * k,
                        height: 52 * k,
                        decoration: BoxDecoration(
                          color: HomeColors.blue,
                          borderRadius: BorderRadius.circular(26 * k),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Shop Smart',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19.5 * k,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 10 * k),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 24 * k,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 630 * k,
                  top: 52 * k,
                  child: Column(
                    children: [
                      pill(Icons.verified_user_rounded, '100% Verified'),
                      SizedBox(height: 10 * k),
                      pill(Icons.bolt_rounded, 'Best Price'),
                      SizedBox(height: 10 * k),
                      pill(Icons.headset_mic_outlined, '24/7 Support'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Collections ─────────────────────────────

class _Collections extends StatelessWidget {
  const _Collections({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * k),
      child: Row(
        children: [
          for (var i = 0; i < _collections.length; i++) ...[
            if (i > 0) SizedBox(width: 20 * k),
            Expanded(
              child: _CollectionCard(
                c: _collections[i],
                onTap: () => onTap(_collections[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.c, required this.onTap});
  final _Collection c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final visual = c.photo != null
        ? Image.asset(
            c.photo!,
            height: 92 * k,
            filterQuality: FilterQuality.medium,
          )
        : SizedBox(
            width: 120 * k,
            height: 92 * k,
            child: PhoneArt(
              spec: PhoneArtSpec(Color(c.art!), 'duo'),
              background: false,
            ),
          );
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 24 * k,
        color: Colors.white.withValues(alpha: 0.78),
        child: SizedBox(
          height: 232 * k,
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(8 * k, 8 * k, 8 * k, 0),
                height: 102 * k,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18 * k),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF1F5FF), Color(0xFFE3EBFF)],
                  ),
                ),
                alignment: Alignment.center,
                child: visual,
              ),
              SizedBox(height: 14 * k),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  c.title,
                  style: TextStyle(
                    fontSize: 20 * k,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3 * k,
                    color: HomeColors.ink,
                  ),
                ),
              ),
              SizedBox(height: 6 * k),
              Text(
                'Up to ${c.discount}% OFF',
                style: TextStyle(
                  fontSize: 16.5 * k,
                  color: const Color(0xFF4F5A7A),
                ),
              ),
              const Spacer(),
              Container(
                width: 107 * k,
                height: 36 * k,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18 * k),
                  border: Border.all(color: const Color(0xFFDCE4FA)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 16 * k,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.blue,
                      ),
                    ),
                    SizedBox(width: 6 * k),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18 * k,
                      color: HomeColors.blue,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 11 * k),
            ],
          ),
        ),
      ),
    );
  }
}
