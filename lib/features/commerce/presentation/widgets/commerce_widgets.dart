import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../data/models/product.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import '../../data/accessories.dart';
import '../../data/commerce_api.dart';
import '../../data/emi.dart';
import '../../data/protection.dart';
import '../../data/tradein.dart';
import '../../providers/checkout_extras.dart';
import '../alerts_screen.dart';
import '../offers_screen.dart';

// ───────────────────────────── Countdown ─────────────────────────────

/// Ticking "02d 09h 14m 05s" boxes until [to].
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.to, this.light = true});
  final DateTime to;
  final bool light;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var d = widget.to.difference(DateTime.now());
    if (d.isNegative) d = Duration.zero;
    final parts = [
      if (d.inDays > 0) (d.inDays, 'd'),
      (d.inHours % 24, 'h'),
      (d.inMinutes % 60, 'm'),
      (d.inSeconds % 60, 's'),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (v, u)) in parts.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: widget.light ? Colors.white : TX.ink,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${v.toString().padLeft(2, '0')}$u',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: widget.light ? const Color(0xFFB91C1C) : Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────────── Festival sale ─────────────────────────

const _saleGradient = LinearGradient(
  colors: [Color(0xFFFF7A18), Color(0xFFE11D48), Color(0xFF8E3DFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Festival sale banner with countdown (home).
class FestivalSaleBanner extends ConsumerWidget {
  const FestivalSaleBanner({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promo = ref.watch(promotionsProvider).asData?.value;
    final sale = promo?.sale;
    if (sale == null || !(sale.live || sale.upcoming)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: GestureDetector(
        onTap: () => context.push('/sale'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: _saleGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFFE08A),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sale.live ? 'LIVE NOW' : 'STARTS SOON',
                          style: const TextStyle(
                            color: Color(0xFFFFE08A),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sale.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sale.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          sale.live ? 'Ends in ' : 'Starts in ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
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
              const SizedBox(width: 6),
              Column(
                children: [
                  Text(
                    '${sale.extraOffPercent.round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'EXTRA OFF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Bank offers ─────────────────────────

/// "Bank offers" list (PDP / checkout).
class BankOffersCard extends ConsumerWidget {
  const BankOffersCard({super.key, required this.amount, this.max = 4});
  final double amount;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promo =
        ref.watch(promotionsProvider).asData?.value ?? Promo.fallback();
    final offers = promo.bankOffers.take(max).toList();
    if (offers.isEmpty) return const SizedBox.shrink();
    return TCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              TIcon(Icons.account_balance_rounded, size: 32),
              SizedBox(width: 10),
              Text(
                'Bank offers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: TX.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final o in offers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.local_offer_rounded,
                      size: 15,
                      color: TX.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${o.bank}: ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: o.text),
                          if (o.minOrder > 0)
                            TextSpan(
                              text: ' • min ${formatPrice(o.minOrder)}',
                              style: const TextStyle(color: TX.muted),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TX.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (o.discountOn(amount) > 0)
                    Text(
                      '−${formatPrice(o.discountOn(amount))}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: TX.green,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Protection ─────────────────────────

/// Picker for one phone's protection plan. [onChanged] gets null for none.
class ProtectionPicker extends StatelessWidget {
  const ProtectionPicker({
    super.key,
    required this.phonePrice,
    required this.selected,
    required this.onChanged,
  });
  final double phonePrice;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final p in kProtectionPlans)
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(selected == p.id ? null : p.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected == p.id
                  ? TX.violet.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected == p.id ? TX.violet : TX.line,
                width: selected == p.id ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TIcon(p.icon, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: TX.ink,
                              ),
                            ),
                          ),
                          if (p.popular) ...[
                            const SizedBox(width: 6),
                            const TPill('Best value', color: TX.green),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.covers.join(' • '),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: TX.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(p.priceFor(phonePrice)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                    Icon(
                      selected == p.id
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected == p.id ? TX.violet : TX.faint,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

// ───────────────────────────── Accessories ─────────────────────────

/// Horizontal "Eta-o lagbe?" rail. Adds to cart with one tap.
class AccessoryRail extends ConsumerWidget {
  const AccessoryRail({super.key, required this.items, this.height = 210});
  final List<Product> items;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = items[i];
          final added = cart.any((c) => c.product.id == a.id);
          final tag = accessoryTag(a);
          return Container(
            width: 138,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: added ? TX.green : TX.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AppImage(
                          a.images.first,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      if (tag != null)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: TX.violet,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: TX.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formatPrice(a.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        formatPrice(a.mrp),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          color: TX.faint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final n = ref.read(cartProvider.notifier);
                        if (added) {
                          n.remove(
                            cart.firstWhere((c) => c.product.id == a.id).key,
                          );
                        } else {
                          n.add(a);
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: added ? TX.success : TX.chip,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          added ? Icons.check_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Complete your setup" card: accessories for the phones in the cart.
class CrossSellCard extends ConsumerWidget {
  const CrossSellCard({
    super.key,
    this.title = 'Eta-o lagbe? Complete your setup',
  });
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final phones = [
      for (final c in cart)
        if (!isAccessory(c.product)) c.product,
    ];
    if (phones.isEmpty) return const SizedBox.shrink();
    final items = crossSellFor(phones, {
      for (final c in cart) c.product.id,
    }).take(8).toList();
    final added = cart.where((c) => isAccessory(c.product)).toList();
    final list = [...added.map((c) => c.product), ...items];
    if (list.isEmpty) return const SizedBox.shrink();
    return TCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TIcon(Icons.cable_rounded, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 10),
            child: Text(
              'Phones ship without a charger. Ships in the same box, no extra delivery fee.',
              style: TextStyle(fontSize: 12, color: TX.muted),
            ),
          ),
          AccessoryRail(items: list),
        ],
      ),
    );
  }
}

// ───────────────────────────── Product page ─────────────────────────

/// Product page commerce block: Make an Offer, alerts, EMI, exchange,
/// bank offers and protection.
class PdpCommerceSection extends ConsumerWidget {
  const PdpCommerceSection({
    super.key,
    required this.product,
    required this.price,
  });
  final Product product;
  final double price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final emi = lowestEmi(price);
    final noCost = bestNoCost(price);
    final trade = ref.watch(tradeInProvider);
    final best = kTradeInModels.values
        .expand((m) => m.values)
        .reduce((a, b) => a > b ? a : b);
    Widget row(
      IconData icon,
      Widget title,
      String sub,
      VoidCallback onTap, {
      Gradient? g,
    }) => TCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      onTap: onTap,
      child: Row(
        children: [
          TIcon(icon, size: 38, gradient: g ?? TX.chip),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                Text(
                  sub,
                  style: const TextStyle(fontSize: 12, color: TX.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TX.faint),
        ],
      ),
    );
    const bold = TextStyle(
      fontWeight: FontWeight.w900,
      color: TX.ink,
      fontSize: 14.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TButton(
                label: 'Make an offer'.tr(context),
                icon: Icons.handshake_rounded,
                height: 48,
                onTap: p.inStock ? () => showMakeOfferSheet(context, p) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TGhost(
                label: (p.inStock ? 'Price alert' : 'Notify me').tr(context),
                icon: Icons.notifications_active_rounded,
                height: 48,
                color: TX.violet,
                onTap: () => showAlertSheet(context, p),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        row(
          Icons.calendar_month_rounded,
          Text.rich(
            TextSpan(
              text: 'EMI from ',
              children: [
                TextSpan(
                  text: '${formatPrice(emi.ceilToDouble())}/mo',
                  style: const TextStyle(color: TX.blue),
                ),
              ],
            ),
            style: bold,
          ),
          noCost == null
              ? 'Card EMI • Pay Later • Cardless EMI'
              : 'No-cost EMI up to $noCost months • Pay Later',
          () => context.push(
            '/emi?price=${price.round()}&name=${Uri.encodeComponent(p.name)}',
          ),
        ),
        const SizedBox(height: 10),
        row(
          Icons.currency_exchange_rounded,
          Text(
            trade == null
                ? 'Exchange & save up to ${formatPrice(best * 1.22)}'
                : 'Exchange: −${formatPrice(trade.amount)} applied',
            style: bold.copyWith(color: trade == null ? TX.ink : TX.green),
          ),
          trade == null
              ? 'Instant quote for your old phone • picked up at delivery'
              : '${trade.device.model} • ${trade.device.conditionSummary}',
          () => context.push('/trade-in?price=${price.round()}'),
          g: TX.success,
        ),
        const SizedBox(height: 10),
        BankOffersCard(amount: price, max: 3),
        const SizedBox(height: 10),
        TCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  TIcon(Icons.shield_rounded, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Protect your phone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Add screen damage cover or extended warranty in the cart or at checkout.',
                style: TextStyle(fontSize: 12, color: TX.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final plan in kProtectionPlans)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${plan.short} • ${formatPrice(plan.priceFor(price))}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TX.violet,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequently bought together',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: TX.ink,
                ),
              ),
              const SizedBox(height: 10),
              AccessoryRail(items: accessoriesFor(p).take(6).toList()),
            ],
          ),
        ),
      ],
    );
  }
}
