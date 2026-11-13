import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/cart_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          items.isEmpty
              ? 'My Cart'
              : 'My Cart (${ref.watch(cartCountProvider)})',
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Clear cart?'),
                    content: const Text(
                      'All items will be removed from your cart.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) ref.read(cartProvider.notifier).clear();
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Looks like you haven\'t added anything yet.',
              actionLabel: 'Start Shopping',
              onAction: () => context.go('/home'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                const _FreeDeliveryBar(),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  _CartTile(item: item),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                const _PromoField(),
                const SizedBox(height: 16),
                const _SummaryCard(),
              ],
            ),
      bottomNavigationBar: items.isEmpty ? null : const _CheckoutBar(),
    );
  }
}

class _FreeDeliveryBar extends ConsumerWidget {
  const _FreeDeliveryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = ref.watch(cartSubtotalProvider);
    const goal = CartSummary.freeDeliveryThreshold;
    final done = subtotal >= goal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: done ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done
                        ? 'You\'ve unlocked FREE delivery! 🎉'
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
                color: done ? AppColors.success : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = item.product;
    final notifier = ref.read(cartProvider.notifier);
    final options = [if (item.size != null) 'Size ${item.size}'];

    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        notifier.remove(item.key);
        showAppSnack(
          context,
          '${p.name} removed',
          action: 'UNDO',
          onAction: () => notifier.add(
            p,
            quantity: item.quantity,
            size: item.size,
            color: item.color,
          ),
        );
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/product/${p.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                AppImage(
                  p.images.first,
                  width: 84,
                  height: 84,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (options.isNotEmpty || item.color != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (item.color != null) ...[
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(item.color!),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black12),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              options.join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatPrice(item.total),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          QuantityStepper(
                            compact: true,
                            value: item.quantity,
                            max: p.stock < CartNotifier.maxPerItem
                                ? p.stock
                                : CartNotifier.maxPerItem,
                            onChanged: (v) => notifier.setQuantity(item.key, v),
                          ),
                        ],
                      ),
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

class _PromoField extends ConsumerStatefulWidget {
  const _PromoField();

  @override
  ConsumerState<_PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends ConsumerState<_PromoField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(promoProvider);
    if (applied != null) {
      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.local_offer_rounded,
            color: AppColors.success,
          ),
          title: Text('$applied applied'),
          subtitle: Text(
            '${((promoCodes[applied] ?? 0) * 100).round()}% off your order',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => ref.read(promoProvider.notifier).clear(),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Promo code (try GAMEX10)',
              prefixIcon: Icon(Icons.local_offer_outlined),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: FilledButton.tonal(
            onPressed: () {
              final ok = ref.read(promoProvider.notifier).apply(_c.text);
              FocusScope.of(context).unfocus();
              showAppSnack(
                context,
                ok ? 'Promo code applied 🎉' : 'Invalid promo code',
              );
              if (ok) _c.clear();
            },
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(cartSummaryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SummaryLines(summary: s),
      ),
    );
  }
}

/// Price breakdown reused by cart and checkout.
class SummaryLines extends StatelessWidget {
  const SummaryLines({super.key, required this.summary});
  final CartSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget line(
      String label,
      String value, {
      Color? color,
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: bold
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style:
                (bold
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        line('Subtotal', formatPrice(summary.subtotal)),
        line(
          'Delivery',
          summary.deliveryFee == 0 ? 'FREE' : formatPrice(summary.deliveryFee),
          color: summary.deliveryFee == 0 ? AppColors.success : null,
        ),
        if (summary.discount > 0)
          line(
            'Discount',
            '-${formatPrice(summary.discount)}',
            color: AppColors.success,
          ),
        const Divider(height: 20),
        line('Total', formatPrice(summary.total), bold: true),
      ],
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(cartSummaryProvider).total;
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerTheme.color ?? AppColors.border,
            ),
          ),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
                Text(
                  formatPrice(total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (ref.read(authProvider) == null) {
                    context.push(
                      '/login?from=${Uri.encodeComponent('/checkout')}',
                    );
                  } else {
                    context.push('/checkout');
                  }
                },
                child: const Text('Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
