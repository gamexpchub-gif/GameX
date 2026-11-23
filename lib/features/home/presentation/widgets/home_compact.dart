import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/models/product.dart';
import '../../../commerce/data/commerce_api.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart';
import '../../../discover/data/phone_filter.dart';
import '../../../discover/data/phone_intel.dart';
import '../../../discover/presentation/widgets/home_discover.dart';
import '../../../discover/providers/discover_providers.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import 'design_scale.dart';

/// One shortcut in the home quick-action grid.
class _Action {
  const _Action(this.icon, this.label, this.route, this.colors, {this.badge});
  final IconData icon;
  final String label;
  final String route;
  final List<Color> colors;
  final String? badge;
}

const _actions = [
  _Action(Icons.travel_explore_rounded, 'Phone\nFinder', '/finder', [
    Color(0xFF8E3DFF),
    Color(0xFF5B21B6),
  ], badge: 'NEW'),
  _Action(Icons.tune_rounded, 'Smart\nFilter', '/explore', [
    Color(0xFF3B82F6),
    Color(0xFF1D4ED8),
  ]),
  _Action(Icons.currency_exchange_rounded, 'Exchange', '/trade-in', [
    Color(0xFF34D399),
    Color(0xFF059669),
  ]),
  _Action(Icons.sell_rounded, 'Sell\nPhone', '/sell', [
    Color(0xFFFBBF24),
    Color(0xFFD97706),
  ]),
  _Action(Icons.calendar_month_rounded, 'EMI', '/emi', [
    Color(0xFF60A5FA),
    Color(0xFF7C3AED),
  ]),
  _Action(Icons.compare_arrows_rounded, 'Compare', '/compare', [
    Color(0xFF22D3EE),
    Color(0xFF0E7490),
  ]),
  _Action(Icons.build_rounded, 'Repair', '/repair', [
    Color(0xFFFB7185),
    Color(0xFFE11D48),
  ]),
  _Action(Icons.local_shipping_rounded, 'Track\nOrder', '/orders', [
    Color(0xFF818CF8),
    Color(0xFF4338CA),
  ]),
  _Action(Icons.health_and_safety_rounded, 'Phone\nCheck', '/setup', [
    Color(0xFF2DD4BF),
    Color(0xFF0F766E),
  ]),
  _Action(Icons.verified_user_rounded, 'Trust\nCenter', '/trust', [
    Color(0xFF94A3B8),
    Color(0xFF334155),
  ]),
];

/// Two rows of five shortcuts to every buyer tool.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * k),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: TX.soft(0.07),
        ),
        child: GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          childAspectRatio: 0.84,
          children: [for (final a in _actions) _Tile(a)],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.a);
  final _Action a;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      HapticFeedback.selectionClick();
      a.route == '/orders' ? context.go(a.route) : context.push(a.route);
    },
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: a.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: a.colors.last.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Glossy highlight for the 3D look.
                  Positioned(
                    left: 4,
                    right: 4,
                    top: 3,
                    height: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Center(child: Icon(a.icon, color: Colors.white, size: 23)),
                ],
              ),
            ),
            if (a.badge != null)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    a.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          a.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E2440),
          ),
        ),
      ],
    ),
  );
}

/// Slim festival-sale strip with a live countdown.
class SaleStrip extends ConsumerWidget {
  const SaleStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(promotionsProvider).asData?.value.sale;
    if (sale == null || !(sale.live || sale.upcoming)) {
      return const SizedBox.shrink();
    }
    final k = context.k;
    return Padding(
      padding: EdgeInsets.fromLTRB(30 * k, 0, 30 * k, 0),
      child: GestureDetector(
        onTap: () => context.push('/sale'),
        child: Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A18), Color(0xFFE11D48), Color(0xFF8E3DFF)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFFE08A),
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          sale.live
                              ? 'Extra ${sale.extraOffPercent.round()}% off • ends in '
                              : 'Starts in ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(
                          height: 20,
                          child: FittedBox(
                            child: Countdown(
                              to: sale.live ? sale.endsAt : sale.startsAt,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal rail of the selected brand's best deals.
class DealsRail extends ConsumerWidget {
  const DealsRail({super.key, required this.items});
  final List<Product> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    return HomeRail(
      items: [
        for (final p in items.take(10))
          ProductRailCard(
            product: p,
            fair: fairPriceOf(p, market: pool),
            tag: p.oldPrice != null && p.oldPrice! > p.price
                ? '${((1 - p.price / p.oldPrice!) * 100).round()}% off • save ${formatPrice(p.oldPrice! - p.price)}'
                : null,
          ),
      ],
    );
  }
}

/// Four GAMEX promises in one compact row.
class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const items = [
      (Icons.verified_rounded, '32-point\nQC check'),
      (Icons.inventory_2_rounded, 'Open-box\ndelivery'),
      (Icons.assignment_return_rounded, '7-day\nreturns'),
      (Icons.shield_rounded, 'Up to 12 mo\nwarranty'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * k),
      child: GestureDetector(
        onTap: () => context.push('/trust'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            gradient: TX.night,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              for (final (icon, label) in items)
                Expanded(
                  child: Column(
                    children: [
                      Icon(icon, color: const Color(0xFFFFC542), size: 22),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
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

/// "Explore all phones" button at the end of home.
class ExploreAllButton extends StatelessWidget {
  const ExploreAllButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 30 * context.k),
    child: TButton(
      label: 'Explore all phones',
      icon: Icons.grid_view_rounded,
      onTap: () => context.push('/explore', extra: const PhoneFilter()),
    ),
  );
}
