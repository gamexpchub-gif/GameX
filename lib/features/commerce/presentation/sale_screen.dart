import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/listing_card.dart';
import '../../discover/data/phone_intel.dart';
import '../../discover/providers/discover_providers.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/commerce_api.dart';
import 'widgets/commerce_widgets.dart';

/// Festival sale page: countdown, extra discount, bank offers and deals.
class SaleScreen extends ConsumerWidget {
  const SaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promo =
        ref.watch(promotionsProvider).asData?.value ?? Promo.fallback();
    final sale = promo.sale;
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    final flash = pool.where((p) => p.isFlashSale && p.inStock).toList();
    final deals = [
      ...flash,
      ...(pool.where((p) => !p.isFlashSale && p.inStock).toList()..sort(
            (a, b) => fairPriceOf(
              a,
              market: pool,
            ).delta.compareTo(fairPriceOf(b, market: pool).delta),
          ))
          .take(12),
    ];
    final w = MediaQuery.sizeOf(context).width;
    final cardW = (w - 32 - 12) / 2;
    return TrustScaffold(
      title: sale.title,
      subtitle: sale.live
          ? 'Live now'
          : sale.upcoming
          ? 'Coming soon'
          : 'Sale ended',
      children: [
        const FestivalSaleBanner(),
        if (!sale.live && !sale.upcoming)
          const TCard(
            child: Text(
              'This sale has ended. Bank offers and no-cost EMI are still available.',
              style: TextStyle(color: TX.muted),
            ),
          ),
        const SizedBox(height: 12),
        TCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _Rule(
                Icons.bolt_rounded,
                '${sale.extraOffPercent.round()}% extra off on flash deals',
                'Applied automatically at checkout, up to ${formatPrice(sale.maxExtraOff)}',
              ),
              const _Rule(
                Icons.account_balance_rounded,
                'Bank offers stack on top',
                'Pay with an eligible card or EMI',
              ),
              const _Rule(
                Icons.currency_exchange_rounded,
                'Exchange bonus',
                '+₹1,000 on phones above ₹30,000',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BankOffersCard(amount: 50000),
        TTitle('Flash deals (${flash.length})'),
        if (flash.isEmpty)
          const TCard(
            child: Text(
              'Flash deals are being restocked. Check the best deals below.',
              style: TextStyle(color: TX.muted),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in deals)
              SizedBox(
                width: cardW,
                height: listingCardHeight(cardW),
                child: ListingCard(product: p),
              ),
          ],
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.title, this.text, {this.last = false});
  final IconData icon;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Row(
      children: [
        TIcon(
          icon,
          size: 36,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A18), Color(0xFFE11D48)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: TX.ink,
                ),
              ),
              Text(text, style: const TextStyle(fontSize: 12, color: TX.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}
