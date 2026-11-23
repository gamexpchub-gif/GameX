import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/product.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../commerce/services/notification_service.dart';
import '../../discover/presentation/widgets/home_discover.dart';
import 'widgets/design_scale.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_compact.dart';
import 'widgets/home_header.dart';
import 'widgets/home_sections.dart';

/// Brand pre-selected in "Popular Brands", as in the design.
final selectedBrandProvider = NotifierProvider<_SelectedBrand, String>(
  _SelectedBrand.new,
);

class _SelectedBrand extends Notifier<String> {
  @override
  String build() => 'apple';
  void select(String id) => state = id;
}

/// Top deals for the selected brand (featured or flash-sale items first).
final topDealsProvider = FutureProvider<List<Product>>((ref) async {
  final brand = ref.watch(selectedBrandProvider);
  final all = await ref.watch(allProductsProvider.future);
  final list = all.where((p) => p.categoryId == brand).toList()
    ..sort((a, b) {
      int score(Product p) => (p.isFlashSale ? 2 : 0) + (p.isFeatured ? 1 : 0);
      final s = score(b).compareTo(score(a));
      return s != 0 ? s : a.id.compareTo(b.id);
    });
  return list;
});

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
    final k = context.k;
    final mq = MediaQuery.of(context);

    // The layout is pixel-matched to the design, so lock text scaling
    // to keep every element in its exact place.
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: AuroraBackground(
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              edgeOffset: mq.padding.top,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: mq.padding.top + 8 * k),
                  ),
                  SliverToBoxAdapter(
                    child: HomeHeader(
                      notifications: ref.watch(unreadNotificationsProvider),
                      onBell: () => context.push('/notifications'),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 16 * k)),
                  SliverToBoxAdapter(
                    child: HomeSearchBar(
                      onScan: () => context.push('/trust/scan'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ref
                        .watch(bannersProvider)
                        .when(
                          data: (b) => HeroBannerCarousel(banners: b),
                          loading: () => Padding(
                            padding: EdgeInsets.fromLTRB(
                              35 * k,
                              25 * k,
                              35 * k,
                              28 * k,
                            ),
                            child: Skeleton(height: 392 * k, radius: 40 * k),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 14 * k)),
                  const SliverToBoxAdapter(child: QuickActionGrid()),
                  SliverToBoxAdapter(child: SizedBox(height: 14 * k)),
                  const SliverToBoxAdapter(child: SaleStrip()),
                  SliverToBoxAdapter(child: SizedBox(height: 26 * k)),
                  const SliverToBoxAdapter(child: ForYouRail()),
                  SliverToBoxAdapter(child: SizedBox(height: 22 * k)),
                  SliverToBoxAdapter(
                    child: HomeSectionTitle(
                      title: 'Top Deals'.tr(context),
                      leading: Image.asset(
                        'assets/images/home/icon_sparkle.png',
                        width: 36 * k,
                        height: 42 * k,
                      ),
                      trailing: const DealCountdown(),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 12 * k)),
                  SliverToBoxAdapter(child: _Brands()),
                  SliverToBoxAdapter(child: SizedBox(height: 10 * k)),
                  SliverToBoxAdapter(
                    child: ref
                        .watch(topDealsProvider)
                        .when(
                          data: (list) => DealsRail(items: list),
                          loading: () => const SizedBox(height: 236),
                          error: (_, _) =>
                              ErrorRetry(onRetry: () => _refresh(ref)),
                        ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 22 * k)),
                  const SliverToBoxAdapter(child: RecentlyViewedRail()),
                  SliverToBoxAdapter(child: SizedBox(height: 22 * k)),
                  const SliverToBoxAdapter(child: TrustStrip()),
                  SliverToBoxAdapter(child: SizedBox(height: 16 * k)),
                  const SliverToBoxAdapter(child: ExploreAllButton()),
                  SliverToBoxAdapter(
                    child: SizedBox(height: mq.padding.bottom + 24 * k),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brands extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    return ref
        .watch(categoriesProvider)
        .when(
          loading: () => SizedBox(height: 108 * k),
          error: (_, _) => const SizedBox.shrink(),
          data: (brands) => BrandStrip(
            brands: brands,
            selected: ref.watch(selectedBrandProvider),
            onSelect: (id) {
              HapticFeedback.selectionClick();
              ref.read(selectedBrandProvider.notifier).select(id);
            },
          ),
        );
  }
}
