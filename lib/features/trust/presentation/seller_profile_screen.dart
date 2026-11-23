import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/listing_card.dart';
import '../data/trust_api.dart';
import 'widgets/trust_ui.dart';

/// Public profile of a GAMEX marketplace seller.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key, required this.sellerId});
  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerProfileProvider(sellerId));
    return async.when(
      loading: () => const TrustScaffold(
        title: 'Seller',
        children: [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (e, _) => TrustScaffold(
        title: 'Seller',
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'Could not load this seller\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TX.muted),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 160,
              child: TButton(
                label: 'Retry',
                onTap: () => ref.invalidate(sellerProfileProvider(sellerId)),
              ),
            ),
          ),
        ],
      ),
      data: (s) => _Profile(s: s),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.s});
  final SellerProfile s;

  @override
  Widget build(BuildContext context) {
    final years = s.since == null
        ? 0
        : DateTime.now().difference(s.since!).inDays ~/ 365;
    final months = s.since == null
        ? 0
        : DateTime.now().difference(s.since!).inDays ~/ 30;
    final initials = s.storeName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    final w = MediaQuery.sizeOf(context).width - 32;
    final cardW = (w - 12) / 2;
    return TrustScaffold(
      title: s.storeName,
      subtitle: '${s.city} • GAMEX marketplace seller',
      children: [
        THero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF8E3DFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (s.verified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF7DD3FC),
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${s.city} • Selling on GAMEX ${years >= 1 ? 'for $years yr${years > 1 ? 's' : ''}' : 'for ${months.clamp(1, 11)} mo'}',
                          style: const TextStyle(
                            color: Color(0xFFC9D2FF),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (s.verified) const _Badge('KYC verified'),
                            if (s.gst) const _Badge('GST registered'),
                            const _Badge('QC on every phone'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(
                    s.rating == 0 ? 'New' : s.rating.toStringAsFixed(1),
                    'Rating',
                    Icons.star_rounded,
                  ),
                  _Stat('${s.sold}', 'Phones sold', Icons.shopping_bag_rounded),
                  _Stat(
                    s.responseMins == null
                        ? '—'
                        : s.responseMins! < 60
                        ? '${s.responseMins}m'
                        : '${(s.responseMins! / 60).round()}h',
                    'Accepts in',
                    Icons.bolt_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            children: [
              TRow(
                'Orders delivered',
                '${s.delivered}',
                icon: Icons.local_shipping_outlined,
              ),
              TRow(
                'Seller cancellations',
                '${s.cancelRate.toStringAsFixed(1)}%',
                icon: Icons.cancel_outlined,
                valueColor: s.cancelRate <= 5 ? TX.green : TX.amber,
              ),
              if (s.since != null)
                TRow(
                  'Member since',
                  DateFormat('MMM yyyy').format(s.since!),
                  icon: Icons.event_outlined,
                ),
              const TRow(
                'Payment protection',
                'Paid only after delivery',
                icon: Icons.lock_outline_rounded,
                last: true,
              ),
            ],
          ),
        ),
        TTitle(
          'Phones from this seller (${s.listings.length})',
        ),
        if (s.listings.isEmpty)
          const TCard(
            child: Center(
              child: Text(
                'No phones listed right now',
                style: TextStyle(color: TX.muted),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in s.listings)
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

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFC542), size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFC9D2FF), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
