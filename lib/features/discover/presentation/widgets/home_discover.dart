import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../data/models/product.dart';
import '../../../home/presentation/widgets/design_scale.dart';
import '../../../home/presentation/widgets/home_sections.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import '../../data/phone_filter.dart';
import '../../data/phone_intel.dart';
import '../../providers/discover_providers.dart';
import 'fair_price_meter.dart';

/// Home: Phone Finder banner + Smart Filter / Compare / Best Deals tiles.
class DiscoverToolsCard extends ConsumerWidget {
  const DiscoverToolsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final compared = ref.watch(compareProvider).length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => context.push('/finder'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: TX.night,
                borderRadius: BorderRadius.circular(26),
                boxShadow: TX.soft(0.22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PHONE FINDER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Not sure which phone to buy?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.5,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Answer 4 quick questions, get your best 3 matches.',
                          style: TextStyle(
                            color: Color(0xFFC9D2FF),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start quiz',
                                style: TextStyle(
                                  color: TX.violet,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: TX.violet,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 96,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF8E3DFF).withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.travel_explore_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                        const Positioned(
                          right: 6,
                          top: 10,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 22,
                            color: Color(0xFFFFC542),
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
          Row(
            children: [
              _Tile(
                icon: Icons.tune_rounded,
                gradient: TX.chip,
                title: 'Smart Filter',
                sub: 'Budget, battery, 5G…',
                onTap: () => context.push('/explore'),
              ),
              const SizedBox(width: 10),
              _Tile(
                icon: Icons.compare_arrows_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
                ),
                title: 'Compare',
                sub: compared == 0 ? 'Side by side' : '$compared selected',
                onTap: () => context.push('/compare'),
              ),
              const SizedBox(width: 10),
              _Tile(
                icon: Icons.speed_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                ),
                title: 'Best Deals',
                sub: 'Below market price',
                onTap: () => context.push(
                  '/explore',
                  extra: const PhoneFilter(sort: DiscoverSort.bestDeal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: TX.soft(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TIcon(icon, gradient: gradient, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                color: TX.ink,
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: TX.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Home: "Picked for you" recommendations rail.
class ForYouRail extends ConsumerWidget {
  const ForYouRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider).asData?.value;
    if (recs == null || recs.isEmpty) return const SizedBox.shrink();
    final personal =
        ref.watch(recentlyViewedProvider).isNotEmpty ||
        ref.watch(compareProvider).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: (personal ? 'Picked for You' : 'Best Value Right Now').tr(
            context,
          ),
          leading: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF8E3DFF),
          ),
          trailing: SeeAllButton(
            onTap: () => context.push(
              '/explore',
              extra: const PhoneFilter(sort: DiscoverSort.bestDeal),
            ),
          ),
        ),
        const SizedBox(height: 12),
        HomeRail(
          items: [
            for (final r in recs)
              ProductRailCard(product: r.product, tag: r.reason, fair: r.fair),
          ],
        ),
      ],
    );
  }
}

/// Home: "Recently viewed" rail.
class RecentlyViewedRail extends ConsumerWidget {
  const RecentlyViewedRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recentlyViewedProvider);
    if (list.isEmpty) return const SizedBox.shrink();
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: 'Recently Viewed'.tr(context),
          leading: const Icon(Icons.history_rounded, color: Color(0xFF2F6BFF)),
          trailing: TextButton(
            onPressed: () => ref.read(recentlyViewedProvider.notifier).clear(),
            child: const Text('Clear'),
          ),
        ),
        const SizedBox(height: 8),
        HomeRail(
          items: [
            for (final p in list.take(12))
              ProductRailCard(
                product: p,
                fair: fairPriceOf(p, market: pool),
              ),
          ],
        ),
      ],
    );
  }
}

class HomeRail extends StatelessWidget {
  const HomeRail({super.key, required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 236,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 35 * context.k),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) => items[i],
    ),
  );
}

class ProductRailCard extends StatelessWidget {
  const ProductRailCard({
    super.key,
    required this.product,
    required this.fair,
    this.tag,
  });
  final Product product;
  final FairPrice fair;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () => context.push('/product/${p.id}'),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          boxShadow: TX.soft(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F0FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: AppImage(
                        p.images.first,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.battery_full_rounded,
                            size: 11,
                            color: TX.green,
                          ),
                          Text(
                            '${batteryOf(p)}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: TX.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                color: TX.ink,
              ),
            ),
            Text(
              '${p.memoryLabel ?? ''} • ${gradeOf(p)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: TX.muted),
            ),
            const SizedBox(height: 3),
            Text(
              formatPrice(p.price),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: TX.blue,
              ),
            ),
            const SizedBox(height: 4),
            if (tag != null)
              Text(
                tag!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: TX.violet,
                ),
              )
            else
              FairPriceChip(fair: fair, dense: true),
          ],
        ),
      ),
    );
  }
}
