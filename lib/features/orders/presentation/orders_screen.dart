import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/order.dart';
import '../../cart/providers/cart_provider.dart';
import '../providers/orders_provider.dart';

Color orderStatusColor(OrderStatus s) => switch (s) {
  OrderStatus.pending => AppColors.warning,
  OrderStatus.confirmed => AppColors.primary,
  OrderStatus.shipped => const Color(0xFF0EA5E9),
  OrderStatus.delivered => AppColors.success,
  OrderStatus.cancelled => AppColors.danger,
};

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push('/cart'),
            icon: Badge(
              isLabelVisible: ref.watch(cartCountProvider) > 0,
              label: Text('${ref.watch(cartCountProvider)}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: orders.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'Your orders will appear here once you place one.',
              actionLabel: 'Start Shopping',
              onAction: () => context.go('/home'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final o = orders[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/order/${o.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${o.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              StatusPill(o.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDate(o.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: o.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, j) => AppImage(
                                o.items[j].product.images.first,
                                width: 52,
                                height: 52,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Text('${o.itemCount} items'),
                              const Spacer(),
                              Text(
                                formatPrice(o.total),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
