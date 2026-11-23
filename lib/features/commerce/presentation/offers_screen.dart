import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../discover/data/phone_intel.dart';
import '../../discover/providers/discover_providers.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/commerce_api.dart';
import '../services/notification_service.dart';

/// Opens the Make-an-Offer sheet for [p].
Future<void> showMakeOfferSheet(BuildContext context, Product p) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F4FF),
      builder: (_) => _OfferSheet(product: p),
    );

class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet({required this.product});
  final Product product;

  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  late double _amount = _round(widget.product.price * 0.93);
  final _note = TextEditingController();
  bool _busy = false;
  PriceOffer? _result;
  String? _error;

  Product get p => widget.product;
  static double _round(double v) => ((v / 100).round() * 100 - 1).toDouble();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  (String, Color, double) get _chance {
    final r = _amount / p.price;
    if (r >= 0.95) return ('Very likely to be accepted', TX.green, 0.95);
    if (r >= 0.88) return ('Good chance', TX.blue, 0.7);
    if (r >= 0.8) return ('Seller may counter', TX.amber, 0.45);
    return ('Unlikely: well below market', TX.red, 0.2);
  }

  Future<void> _send() async {
    final server = CommerceApi.isServerListing(p.id);
    if (server && ref.read(authProvider) == null) {
      Navigator.pop(context);
      context.push('/login?from=${Uri.encodeComponent('/product/${p.id}')}');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await ref
          .read(commerceApiProvider)
          .makeOffer(p, _amount, note: _note.text.trim());
      ref.invalidate(myOffersProvider);
      ref.read(notificationFeedProvider.notifier).requestPermission();
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _result = o);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    final fair = fairPriceOf(p, market: pool);
    final min = _round(p.price * 0.7) + 100;
    final max = _round(p.price * 0.99);
    final (label, color, chance) = _chance;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottom),
      child: SingleChildScrollView(
        child: _result != null
            ? _done(_result!)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: AppImage(
                          p.images.first,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Make an offer',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: TX.ink,
                              ),
                            ),
                            Text(
                              '${p.name} • listed at ${formatPrice(p.price)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: TX.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _amount),
                      duration: const Duration(milliseconds: 200),
                      builder: (_, v, _) => Text(
                        formatPrice(v.roundToDouble()),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: TX.violet,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${formatPrice(p.price - _amount)} (${((1 - _amount / p.price) * 100).round()}%) below the asking price',
                      style: const TextStyle(color: TX.muted, fontSize: 12.5),
                    ),
                  ),
                  Slider(
                    value: _amount.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: ((max - min) / 100).round().clamp(1, 1000),
                    onChanged: (v) => setState(() => _amount = _round(v)),
                  ),
                  Row(
                    children: [
                      for (final pct in [3, 5, 8, 12])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => setState(
                                () =>
                                    _amount = _round(p.price * (1 - pct / 100)),
                              ),
                              child: Text(
                                '−$pct%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insights_rounded,
                              size: 18,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: chance,
                            minHeight: 6,
                            backgroundColor: TX.line,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'GAMEX market estimate: ${formatPrice(fair.low)} – ${formatPrice(fair.high)}',
                          style: const TextStyle(fontSize: 12, color: TX.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    maxLength: 120,
                    decoration: tInput(
                      'Message to seller (optional)',
                      prefix: const Icon(Icons.chat_bubble_outline_rounded),
                    ).copyWith(counterText: ''),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: TX.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TButton(
                    label: 'Send offer ${formatPrice(_amount)}',
                    icon: Icons.send_rounded,
                    busy: _busy,
                    onTap: _send,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CommerceApi.isServerListing(p.id)
                        ? 'The seller replies within 24 hours. If accepted, the price is held for you for 48 hours.'
                        : 'GAMEX replies instantly. An accepted price is held for you for 48 hours.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: TX.muted),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _done(PriceOffer o) {
    final (icon, color, title, text) = switch (o.status) {
      'accepted' => (
        Icons.celebration_rounded,
        TX.green,
        'Offer accepted!',
        'Buy it for ${formatPrice(o.dealPrice ?? o.amount)} within 48 hours.',
      ),
      'countered' => (
        Icons.swap_horiz_rounded,
        TX.amber,
        'Counter-offer: ${formatPrice(o.counter ?? 0)}',
        'Accept it or decline from My Offers.',
      ),
      _ => (
        Icons.mark_email_read_rounded,
        TX.blue,
        'Offer sent',
        'We\'ll notify you as soon as the seller replies.',
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: TX.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: TX.muted),
        ),
        const SizedBox(height: 18),
        if (o.status == 'accepted')
          TButton(
            label: 'Buy at ${formatPrice(o.dealPrice ?? o.amount)}',
            icon: Icons.shopping_bag_rounded,
            onTap: () {
              ref
                  .read(cartProvider.notifier)
                  .addDeal(p, o.dealPrice ?? o.amount, o.id);
              Navigator.pop(context);
              context.push('/cart');
            },
          )
        else
          TButton(
            label: 'View my offers',
            icon: Icons.local_offer_rounded,
            onTap: () {
              Navigator.pop(context);
              context.push('/offers');
            },
          ),
      ],
    );
  }
}

/// All offers the buyer has made.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOffersProvider);
    return TrustScaffold(
      title: 'My offers',
      subtitle: 'Negotiate the price, buy at your deal',
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
                    child: TIcon(Icons.local_offer_rounded, size: 64),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'No offers yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open any phone and tap "Make an offer" to propose your price.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TX.muted),
                  ),
                ]
              : [
                  for (final o in list) ...[
                    _OfferCard(o: o),
                    const SizedBox(height: 12),
                  ],
                ],
        ),
      ],
    );
  }
}

const _statusLabel = {
  'pending': 'Waiting for seller',
  'countered': 'Counter-offer',
  'accepted': 'Accepted',
  'rejected': 'Declined',
  'expired': 'Expired',
  'withdrawn': 'Withdrawn',
  'used': 'Purchased',
};

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.o});
  final PriceOffer o;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _respond(String action) async {
    setState(() => _busy = true);
    try {
      await ref.read(commerceApiProvider).respond(widget.o, action);
      ref.invalidate(myOffersProvider);
    } catch (e) {
      if (mounted) tSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy() async {
    final o = widget.o;
    setState(() => _busy = true);
    try {
      final p = await ref.read(productByIdProvider(o.listingId).future);
      if (p == null) throw 'This phone is no longer available';
      ref.read(cartProvider.notifier).addDeal(p, o.dealPrice!, o.id);
      if (mounted) context.push('/cart');
    } catch (e) {
      if (mounted) tSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final color = switch (o.status) {
      'accepted' || 'used' => TX.green,
      'countered' => TX.amber,
      'pending' => TX.blue,
      _ => TX.faint,
    };
    final api = ref.read(commerceApiProvider);
    final photo = o.photo == null ? null : api.image(o.photo!);
    final f = DateFormat('d MMM, h:mm a');
    return TCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/product/${o.listingId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: AppImage(
                      photo,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                    Text(
                      'Listed ${formatPrice(o.listPrice)} • you offered ${formatPrice(o.amount)}',
                      style: const TextStyle(fontSize: 12, color: TX.muted),
                    ),
                  ],
                ),
              ),
              TPill(_statusLabel[o.status] ?? o.status, color: color),
            ],
          ),
          const SizedBox(height: 10),
          for (final (l, a) in o.events.reversed.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 7, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l,
                      style: const TextStyle(fontSize: 12.5, color: TX.ink),
                    ),
                  ),
                  Text(
                    f.format(a.toLocal()),
                    style: const TextStyle(fontSize: 11, color: TX.faint),
                  ),
                ],
              ),
            ),
          if (o.status == 'countered') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TGhost(
                    label: 'Decline',
                    height: 46,
                    onTap: _busy ? null : () => _respond('reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TButton(
                    label: 'Accept ${formatPrice(o.counter!)}',
                    height: 46,
                    busy: _busy,
                    onTap: () => _respond('accept'),
                  ),
                ),
              ],
            ),
          ],
          if (o.canBuy) ...[
            const SizedBox(height: 12),
            TButton(
              label: 'Buy now at ${formatPrice(o.dealPrice!)}',
              icon: Icons.shopping_bag_rounded,
              height: 48,
              busy: _busy,
              gradient: TX.success,
              onTap: _buy,
            ),
            if (o.dealExpiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Deal held until ${f.format(o.dealExpiresAt!.toLocal())}',
                  style: const TextStyle(fontSize: 11.5, color: TX.muted),
                ),
              ),
          ],
          if (o.status == 'pending')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => _respond('withdraw'),
                child: const Text('Withdraw offer'),
              ),
            ),
        ],
      ),
    );
  }
}
