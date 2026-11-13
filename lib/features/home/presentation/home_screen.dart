import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(bannersProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(allProductsProvider);
    await ref.read(allProductsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            slivers: [
              // Greeting + actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user == null
                                  ? 'Hello there 👋'
                                  : 'Hi, ${user.name.split(' ').first} 👋',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'What are you looking for today?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            showAppSnack(context, 'No new notifications'),
                        icon: const Badge(
                          smallSize: 8,
                          child: Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _SearchField(onTap: () => context.push('/search')),
                ),
              ),
              const SliverToBoxAdapter(child: _BannerCarousel()),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Categories',
                  onSeeAll: () => context.go('/categories'),
                ),
              ),
              const SliverToBoxAdapter(child: _CategoryStrip()),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Flash Sale',
                  trailing: const _Countdown(),
                  onSeeAll: () => context.push('/category/all?flash=1'),
                ),
              ),
              SliverToBoxAdapter(
                child: _ProductsRow(provider: flashSaleProductsProvider),
              ),
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Featured for you'),
              ),
              ...ref
                  .watch(featuredProductsProvider)
                  .when(
                    data: (list) => [ProductSliverGrid(products: list)],
                    loading: () => const [
                      SliverToBoxAdapter(child: ProductGridSkeleton()),
                    ],
                    error: (_, _) => [
                      SliverToBoxAdapter(
                        child: ErrorRetry(onRetry: () => _refresh(ref)),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerTheme.color ?? AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.colorScheme.outline),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search products, brands…',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              Icon(Icons.tune_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCarousel extends ConsumerStatefulWidget {
  const _BannerCarousel();

  @override
  ConsumerState<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<_BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final count = ref.read(bannersProvider).asData?.value.length ?? 0;
      if (count < 2 || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % count,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AspectRatio(
        aspectRatio: 2.15,
        child: banners.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Skeleton(radius: 18),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: list.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _BannerCard(banner: list[i]),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < list.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});
  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: banner.categoryId == null
              ? null
              : () => context.push('/category/${banner.categoryId}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(banner.image),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xDD1E1250), Color(0x001E1250)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      banner.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Shop now',
                        style: TextStyle(
                          color: AppColors.primary,
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
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 96,
      child: ref
          .watch(categoriesProvider)
          .when(
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) =>
                  const Skeleton(width: 64, height: 64, radius: 18),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (cats) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _CategoryChip(category: cats[i]),
            ),
          ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/category/${category.id}'),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                categoryIcon(category.icon),
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsRow extends ConsumerWidget {
  const _ProductsRow({required this.provider});
  final FutureProvider<List<Product>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(provider)
        .when(
          data: (list) => ProductCarousel(products: list),
          loading: () => SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const Skeleton(width: 170, radius: 14),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

/// Countdown to midnight – flash sale resets daily.
class _Countdown extends StatefulWidget {
  const _Countdown();

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Timer _timer;
  Duration _left = _remaining();

  static Duration _remaining() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _left = _remaining());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final text =
        '${two(_left.inHours)}:${two(_left.inMinutes % 60)}:${two(_left.inSeconds % 60)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
