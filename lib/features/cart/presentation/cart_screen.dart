import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/listing_card.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/cart_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../checkout/presentation/widgets/address_sheets.dart';
import '../../checkout/providers/address_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/cart_provider.dart';
import 'widgets/price_details.dart';

export 'widgets/price_details.dart' show SummaryLines;

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _deleteSelected(
    BuildContext context,
    WidgetRef ref,
    List<CartItem> selected,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          'Remove ${selected.length} item${selected.length == 1 ? '' : 's'}?',
        ),
        content: const Text('Selected items will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 40),
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(cartProvider.notifier).removeKeys({
        for (final i in selected) i.key,
      });
    }
  }

  void _checkout(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    if (ref.read(authProvider) == null) {
      context.push('/login?from=${Uri.encodeComponent('/checkout')}');
    } else {
      context.push('/checkout');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final selected = ref.watch(selectedCartProvider);
    final allSelected = items.isNotEmpty && selected.length == items.length;

    return Scaffold(
      // Light fill behind the rounded sticky bar's corners.
      backgroundColor: const Color(0xFFF1F4FD),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Cart'),
            if (items.isNotEmpty)
              Text(
                '${ref.watch(cartCountProvider)} items',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => context.push('/wishlist'),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
        ],
      ),
      body: AuroraBackground(
        child: items.isEmpty
            ? EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                message: 'Find certified phones at the best prices and add them here.',
                actionLabel: 'Start Shopping',
                onAction: () => context.go('/home'),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                children: [
                  const _DeliverTo(),
                  const SizedBox(height: 12),
                  const _FreeDeliveryBar(),
                  const SizedBox(height: 12),
                  // Select all / delete selected.
                  SectionCard(
                    padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                    child: Row(
                      children: [
                        Checkbox(
                          value: allSelected
                              ? true
                              : (selected.isEmpty ? false : null),
                          tristate: true,
                          onChanged: (_) => ref
                              .read(deselectedProvider.notifier)
                              .setAll(
                                items.map((i) => i.key),
                                selected: !allSelected,
                              ),
                        ),
                        Expanded(
                          child: Text(
                            'Select all (${selected.length}/${items.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          onPressed: selected.isEmpty
                              ? null
                              : () => _deleteSelected(context, ref, selected),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                          ),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in items) ...[
                    _CartItemCard(item: item),
                    const SizedBox(height: 12),
                  ],
                  const _CouponCard(),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          icon: Icons.receipt_long_rounded,
                          title: 'Price Details',
                        ),
                        const SizedBox(height: 10),
                        SummaryLines(
                          summary: ref.watch(cartSummaryProvider),
                          couponCode: ref.watch(promoProvider),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _TrustRow(),
                  const _YouMayLike(),
                ],
              ),
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : _CheckoutBar(onCheckout: () => _checkout(context, ref)),
    );
  }
}

// ───────────────────────────── Deliver to ─────────────────────────────

class _DeliverTo extends ConsumerWidget {
  const _DeliverTo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(addressBookProvider).current;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: a == null
                ? const Text(
                    'Add a delivery address',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  )
                : Text.rich(
                    TextSpan(
                      text: 'Deliver to ',
                      children: [
                        TextSpan(
                          text: '${a.fullName}, ${a.city}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: '\n${a.label} • ${a.area}'),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
          ),
          TextButton(
            onPressed: () => showAddressPicker(context),
            child: Text(a == null ? 'Add' : 'Change'),
          ),
        ],
      ),
    );
  }
}

class _FreeDeliveryBar extends ConsumerWidget {
  const _FreeDeliveryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = ref.watch(cartSummaryProvider).subtotal;
    const goal = CartSummary.freeDeliveryThreshold;
    final done = subtotal >= goal;
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done
                    ? Icons.local_shipping_rounded
                    : Icons.local_shipping_outlined,
                color: done ? AppColors.success : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  done
                      ? 'Yay! You get FREE delivery on this order'
                      : 'Add ${formatPrice(goal - subtotal)} more for FREE delivery',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (subtotal / goal).clamp(0, 1),
              minHeight: 6,
              backgroundColor: const Color(0xFFE6EBF7),
              color: done ? AppColors.success : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Item card ─────────────────────────────

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = item.product;
    final cart = ref.read(cartProvider.notifier);
    final selected = !ref.watch(deselectedProvider).contains(item.key);
    final maxQty = p.stock < CartNotifier.maxPerItem
        ? p.stock
        : CartNotifier.maxPerItem;
    final condition = (p.condition ?? '').replaceAll(' Condition', '');

    Widget tag(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        cart.remove(item.key);
        showAppSnack(
          context,
          '${p.name} removed',
          action: 'UNDO',
          onAction: () => cart.add(
            p,
            quantity: item.quantity,
            size: item.size,
            color: item.color,
          ),
        );
      },
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(4, 12, 12, 10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) =>
                      ref.read(deselectedProvider.notifier).toggle(item.key),
                ),
                GestureDetector(
                  onTap: () => context.push('/product/${p.id}'),
                  child: AppImage(
                    p.images.first,
                    width: 92,
                    height: 104,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.size ?? p.memoryLabel ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (p.verified)
                            tag(
                              Icons.verified_user_rounded,
                              'Verified',
                              AppColors.primary,
                            ),
                          if (condition.isNotEmpty && item.size == null)
                            tag(
                              Icons.diamond_outlined,
                              condition,
                              const Color(0xFF6C4BD8),
                            ),
                          if (p.warrantyMonths > 0)
                            tag(
                              Icons.shield_outlined,
                              '${p.warrantyMonths}M warranty',
                              AppColors.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            formatPrice(p.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          if (p.discountPercent > 0) ...[
                            Text(
                              formatPrice(p.mrp),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Text(
                              '${p.discountPercent}% off',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (p.stock > 0 && p.stock <= 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Only ${p.stock} left – order soon',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                const SizedBox(width: 12),
                QuantityStepper(
                  compact: true,
                  value: item.quantity.clamp(1, maxQty < 1 ? 1 : maxQty),
                  max: maxQty < 1 ? 1 : maxQty,
                  onChanged: (v) => cart.setQuantity(item.key, v),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    if (!ref.read(wishlistProvider.notifier).contains(p.id)) {
                      ref.read(wishlistProvider.notifier).toggle(p);
                    }
                    cart.remove(item.key);
                    showAppSnack(context, 'Moved to wishlist');
                  },
                  icon: const Icon(Icons.favorite_border_rounded, size: 18),
                  label: const Text('Save'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: () {
                    cart.remove(item.key);
                    showAppSnack(
                      context,
                      '${p.name} removed',
                      action: 'UNDO',
                      onAction: () => cart.add(
                        p,
                        quantity: item.quantity,
                        size: item.size,
                        color: item.color,
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Coupon ─────────────────────────────

class _CouponCard extends ConsumerWidget {
  const _CouponCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(promoProvider);
    final summary = ref.watch(cartSummaryProvider);
    final coupon = couponByCode(code);
    final valid = coupon != null && summary.discount > 0;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => showCouponSheet(context),
        leading: Icon(
          valid ? Icons.local_offer_rounded : Icons.local_offer_outlined,
          color: valid ? AppColors.success : AppColors.primary,
        ),
        title: Text(
          valid ? '${coupon.code} applied' : 'Apply coupon',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          valid
              ? 'You save ${formatPrice(summary.discount)}'
              : coupon != null
              ? '${coupon.code} needs a minimum order of ${formatPrice(coupon.minOrder)}'
              : '${coupons.length} offers available for you',
          style: TextStyle(color: valid ? AppColors.success : null),
        ),
        trailing: code != null
            ? IconButton(
                tooltip: 'Remove coupon',
                onPressed: () => ref.read(promoProvider.notifier).clear(),
                icon: const Icon(Icons.close_rounded),
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String text) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        item(Icons.lock_rounded, 'Secure\npayments'),
        item(Icons.verified_user_rounded, '100% certified\nphones'),
        item(Icons.assignment_return_rounded, '7-day easy\nreturns'),
        item(Icons.support_agent_rounded, '24/7\nsupport'),
      ],
    );
  }
}

class _YouMayLike extends ConsumerWidget {
  const _YouMayLike();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = {
      for (final i in ref.watch(cartProvider)) i.product.id.split('-l').first,
    };
    final list = (ref.watch(featuredProductsProvider).asData?.value ?? const [])
        .where((p) => !inCart.contains(p.id))
        .take(8)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final k = MediaQuery.sizeOf(context).width / 852;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text(
            'You may also like',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: kListingCardHeight * k,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 253 * k,
              child: ListingCard(product: list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({required this.onCheckout});
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(cartSummaryProvider);
    final theme = Theme.of(context);
    return StickyBottomBar(
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPrice(s.total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (s.totalSavings > 0)
                  Text(
                    'You save ${formatPrice(s.totalSavings)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    '${s.itemCount} items selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 190,
            child: FilledButton.icon(
              onPressed: s.itemCount == 0 ? null : onCheckout,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text('Checkout (${s.itemCount})'),
            ),
          ),
        ],
      ),
    );
  }
}
