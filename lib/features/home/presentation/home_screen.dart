import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/product.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../commerce/presentation/widgets/commerce_widgets.dart';
import '../../commerce/services/notification_service.dart';
import '../../discover/presentation/widgets/home_discover.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import 'widgets/design_scale.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/home_sections.dart';
import 'widgets/home_sheets.dart';

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
                  SliverToBoxAdapter(child: SizedBox(height: 21 * k)),
                  SliverToBoxAdapter(
                    child: FeatureRow(
                      onTap: (i) => showFeatureSheet(context, i),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 28 * k)),
                  SliverToBoxAdapter(
                    child: OfferCard(
                      tradeInUpTo: 15000,
                      emiFrom: 999,
                      onExchange: () => context.push('/trade-in'),
                      onEmi: () => context.push('/emi'),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 28 * k)),
                  SliverToBoxAdapter(
                    child: FestivalSaleBanner(
                      padding: EdgeInsets.fromLTRB(35 * k, 0, 35 * k, 22 * k),
                    ),
                  ),
                  const SliverToBoxAdapter(child: DiscoverToolsCard()),
                  SliverToBoxAdapter(child: SizedBox(height: 30 * k)),
                  const SliverToBoxAdapter(child: ForYouRail()),
                  SliverToBoxAdapter(child: SizedBox(height: 26 * k)),
                  const SliverToBoxAdapter(child: RecentlyViewedRail()),
                  SliverToBoxAdapter(child: SizedBox(height: 26 * k)),
                  SliverToBoxAdapter(
                    child: HomeSectionTitle(
                      title: 'Popular Brands',
                      trailing: SeeAllButton(
                        onTap: () => context.go('/categories'),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 20 * k)),
                  SliverToBoxAdapter(child: _Brands()),
                  SliverToBoxAdapter(child: SizedBox(height: 34 * k)),
                  SliverToBoxAdapter(
                    child: HomeSectionTitle(
                      title: 'Top Deals for You',
                      leading: Image.asset(
                        'assets/images/home/icon_sparkle.png',
                        width: 42 * k,
                        height: 48 * k,
                      ),
                      trailing: const DealCountdown(),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 16 * k)),
                  ..._deals(context, ref, k),
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

  List<Widget> _deals(BuildContext context, WidgetRef ref, double k) {
    return ref
        .watch(topDealsProvider)
        .when(
          loading: () => [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 35 * k),
                child: Skeleton(height: 284 * k, radius: 30 * k),
              ),
            ),
          ],
          error: (_, _) => [
            SliverToBoxAdapter(child: ErrorRetry(onRetry: () => _refresh(ref))),
          ],
          data: (list) => [
            SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => SizedBox(height: 22 * k),
              itemBuilder: (context, i) {
                final p = list[i];
                return DealCard(
                  product: p,
                  ribbon: i == 0 ? 'Best Deal' : null,
                  wished: ref.watch(isWishlistedProvider(p.id)),
                  onTap: () => context.push('/product/${p.id}'),
                  onWish: () {
                    HapticFeedback.lightImpact();
                    ref.read(wishlistProvider.notifier).toggle(p);
                  },
                  onAddToCart: p.inStock
                      ? () {
                          HapticFeedback.mediumImpact();
                          ref.read(cartProvider.notifier).add(p);
                          showAppSnack(
                            context,
                            '${p.name} added to cart',
                            action: 'VIEW',
                            onAction: () => context.push('/cart'),
                          );
                        }
                      : null,
                );
              },
            ),
          ],
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
