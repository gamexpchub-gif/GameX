import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/commerce_api.dart';
import '../services/notification_service.dart';

/// Price-drop / back-in-stock alert sheet for a phone.
Future<void> showAlertSheet(BuildContext context, Product p) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F4FF),
      builder: (_) => _AlertSheet(product: p),
    );

class _AlertSheet extends ConsumerStatefulWidget {
  const _AlertSheet({required this.product});
  final Product product;

  @override
  ConsumerState<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends ConsumerState<_AlertSheet> {
  late double _target = ((widget.product.price * 0.95) / 100).round() * 100 - 1;
  bool _busy = false;

  Product get p => widget.product;

  Future<void> _save() async {
    if (CommerceApi.isServerListing(p.id) && ref.read(authProvider) == null) {
      Navigator.pop(context);
      context.push('/login?from=${Uri.encodeComponent('/product/${p.id}')}');
      return;
    }
    setState(() => _busy = true);
    try {
      final allowed = await ref
          .read(notificationFeedProvider.notifier)
          .requestPermission();
      await ref
          .read(commerceApiProvider)
          .setAlert(
            p,
            p.inStock ? 'price' : 'stock',
            target: p.inStock ? _target : null,
          );
      ref.invalidate(myAlertsProvider);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
      tSnack(
        context,
        p.inStock
            ? 'We\'ll notify you when it drops to ${formatPrice(_target)}'
            : 'We\'ll notify you when it\'s back in stock',
      );
      if (!allowed) {
        tSnack(
          context,
          'Turn on notifications for GAMEX in Settings to get alerts',
        );
      }
    } catch (e) {
      if (mounted) tSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = !p.inStock;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TIcon(
                stock
                    ? Icons.notifications_active_rounded
                    : Icons.trending_down_rounded,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock ? 'Notify me when available' : 'Price drop alert',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                    Text(p.name, style: const TextStyle(color: TX.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!stock) ...[
            Text(
              'Alert me at ${formatPrice(_target)} or less',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: TX.violet,
              ),
            ),
            Text(
              'Now ${formatPrice(p.price)} • ${((1 - _target / p.price) * 100).round()}% lower',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TX.muted, fontSize: 12.5),
            ),
            Slider(
              value: _target,
              min: (p.price * 0.7 / 100).round() * 100 - 1,
              max: (p.price / 100).floor() * 100 - 1,
              divisions: 30,
              onChanged: (v) => setState(
                () => _target = ((v / 100).round() * 100 - 1).toDouble(),
              ),
            ),
          ] else
            const Text(
              'This phone is sold out. We\'ll send you a notification the moment the seller restocks it.',
              style: TextStyle(color: TX.muted, height: 1.35),
            ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.notifications_rounded, size: 16, color: TX.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'You get a phone notification, even when the app is in the background.',
                  style: TextStyle(fontSize: 12, color: TX.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TButton(
            label: stock ? 'Notify me' : 'Set price alert',
            icon: Icons.notifications_active_rounded,
            busy: _busy,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}

/// All active price / stock alerts.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAlertsProvider);
    return TrustScaffold(
      title: 'Price & stock alerts',
      subtitle: 'We watch prices so you don\'t have to',
      children: [
        ...async.when(
          loading: () => [
            const SizedBox(height: 160),
            const Center(child: CircularProgressIndicator()),
          ],
          error: (e, _) => [Text('$e')],
          data: (list) => list.isEmpty
              ? [
                  const SizedBox(height: 60),
                  const Center(
                    child: TIcon(Icons.notifications_none_rounded, size: 64),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'No alerts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the bell on any phone to get notified when its price drops or it is back in stock.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TX.muted),
                  ),
                ]
              : [
                  for (final a in list) ...[
                    TCard(
                      padding: const EdgeInsets.all(12),
                      onTap: () => context.push('/product/${a.listingId}'),
                      child: Row(
                        children: [
                          TIcon(
                            a.type == 'price'
                                ? Icons.trending_down_rounded
                                : Icons.inventory_rounded,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: TX.ink,
                                  ),
                                ),
                                Text(
                                  a.type == 'price'
                                      ? 'Alert at ${formatPrice(a.targetPrice ?? a.priceAtSet)} • was ${formatPrice(a.priceAtSet)}'
                                      : 'Back-in-stock alert',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: TX.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: TX.faint,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(commerceApiProvider)
                                  .removeAlert(a);
                              ref.invalidate(myAlertsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
        ),
      ],
    );
  }
}

/// Notification centre (server notifications).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final feed = ref.read(notificationFeedProvider.notifier);
      await feed.refresh(silent: true);
      await feed.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationFeedProvider);
    final user = ref.watch(authProvider);
    final f = DateFormat('d MMM, h:mm a');
    IconData icon(String k) => switch (k) {
      'offer' => Icons.local_offer_rounded,
      'price' => Icons.trending_down_rounded,
      'stock' => Icons.inventory_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      'order' => Icons.local_shipping_rounded,
      'tradein' => Icons.currency_exchange_rounded,
      _ => Icons.notifications_rounded,
    };
    return TrustScaffold(
      title: 'Notifications',
      subtitle: 'Offers, price drops, orders & wallet',
      trailing: IconButton(
        icon: const Icon(Icons.tune_rounded, color: TX.ink),
        onPressed: () => context.push('/alerts'),
      ),
      children: [
        if (user == null)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Text(
              'Log in to get notifications for your offers, alerts and orders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TX.muted),
            ),
          )
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Column(
              children: [
                TIcon(Icons.notifications_none_rounded, size: 60),
                SizedBox(height: 12),
                Text(
                  'You\'re all caught up',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
              ],
            ),
          )
        else
          for (final n in list) ...[
            TCard(
              padding: const EdgeInsets.all(12),
              onTap: n.link.startsWith('/') ? () => context.push(n.link) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TIcon(icon(n.kind), size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TX.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n.body,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: TX.muted,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.format(n.at.toLocal()),
                          style: const TextStyle(fontSize: 11, color: TX.faint),
                        ),
                      ],
                    ),
                  ),
                  if (!n.read)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: TX.violet,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}
