import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../data/models/product.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import '../../data/phone_filter.dart';
import '../../providers/discover_providers.dart';
import 'compare_widgets.dart';

/// Product page: "Add to compare" + "Similar phones in this budget".
class PdpDiscoverActions extends ConsumerWidget {
  const PdpDiscoverActions({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(isComparedProvider(product.id));
    final n = ref.watch(compareProvider).length;
    Widget button({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool active = false,
    }) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 46,
          decoration: BoxDecoration(
            gradient: active ? TX.chip : null,
            color: active ? null : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            boxShadow: TX.soft(active ? 0.2 : 0.06),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: active ? Colors.white : TX.violet),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? Colors.white : TX.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final lo = (product.price * 0.8 / 1000).floor() * 1000.0;
    final hi = (product.price * 1.2 / 1000).ceil() * 1000.0;
    return Row(
      children: [
        button(
          icon: on ? Icons.check_rounded : Icons.compare_arrows_rounded,
          label: on
              ? (n >= 2 ? 'Compare now ($n)' : 'Added to compare')
              : 'Add to compare'.tr(context),
          active: on,
          onTap: () => on && n >= 2
              ? context.push('/compare')
              : toggleCompare(context, ref, product),
        ),
        const SizedBox(width: 10),
        button(
          icon: Icons.travel_explore_rounded,
          label: 'Similar in budget'.tr(context),
          onTap: () => context.push(
            '/explore',
            extra: PhoneFilter(
              minPrice: lo.clamp(kMinPrice, kMaxPrice),
              maxPrice: hi.clamp(kMinPrice, kMaxPrice),
              sort: DiscoverSort.bestDeal,
            ),
          ),
        ),
      ],
    );
  }
}
