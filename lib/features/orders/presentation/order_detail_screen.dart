import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/order.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../commerce/data/protection.dart';
import '../providers/orders_provider.dart';
import '../../trust/presentation/order_trust_section.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ordersProvider);
    final order = ref.read(ordersProvider.notifier).byId(orderId);
    final theme = Theme.of(context);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Order not found',
          message: 'We couldn\'t find this order.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      StatusPill(order.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Placed on ${formatDate(order.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Timeline(status: order.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (order.hasSellerItems) OrderTrustSection(orderId: order.id),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                order.address.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${order.address.phone}\n${order.address.oneLine}',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.payments_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Payment'),
              subtitle: Text(
                order.paymentNote == null
                    ? order.paymentMethod.label
                    : '${order.paymentMethod.label}\n${order.paymentNote}',
              ),
              isThreeLine: order.paymentNote != null,
            ),
          ),
          if (order.tradeIn != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.currency_exchange_rounded,
                  color: AppColors.success,
                ),
                title: Text(
                  'Exchange: ${order.tradeIn!['model']} • −${formatPrice((order.tradeIn!['amount'] as num).toDouble())}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  order.isDelivered
                      ? 'Old phone collected at delivery'
                      : 'Keep your old phone ready. Sign out of iCloud / Google and hand it over at delivery (${order.tradeIn!['condition']}).',
                ),
                isThreeLine: !order.isDelivered,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          AppImage(
                            item.product.images.first,
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  [
                                    'Qty ${item.quantity}',
                                    if (item.size != null) item.size!,
                                    if (protectionById(item.protection) != null)
                                      protectionById(item.protection)!.short,
                                    if (item.offerId != null) 'Offer price',
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatPrice(item.total),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  SummaryLines(
                    summary: CartSummary(
                      subtotal: order.subtotal,
                      deliveryFee: order.deliveryFee,
                      discount: order.discount,
                    ),
                    extraLines: order.lines,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () =>
                showAppSnack(context, 'Our support team will call you shortly'),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Need help with this order?'),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.shipped,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return const Text(
        'This order was cancelled.',
        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
      );
    }
    final current = _steps.indexOf(status);
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: i <= current
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  i <= current ? Icons.check_rounded : Icons.circle,
                  size: i <= current ? 16 : 8,
                  color: i <= current
                      ? Colors.white
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _steps[i].label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                color: i < current
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
        ],
      ],
    );
  }
}
