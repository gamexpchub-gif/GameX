import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(earningsProvider);
    final payouts = ref.watch(payoutsProvider);
    final seller = ref.watch(sellerProvider);
    final now = DateTime.now();
    final nextSettlement = now.add(
      Duration(days: (8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: C.nightGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available to withdraw',
                  style: TextStyle(color: Color(0xFFB9C2FF)),
                ),
                const SizedBox(height: 4),
                Text(
                  inr(e.available),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'to ${seller?.bank ?? 'your bank'}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _HeroStat('In settlement', inr(e.pending))),
                    Expanded(
                      child: _HeroStat(
                        'Next payout',
                        dateShort(nextSettlement),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: C.ink,
                    ),
                    onPressed: e.available < 1
                        ? null
                        : () {
                            ref
                                .read(payoutsProvider.notifier)
                                .add(
                                  Payout(
                                    id: 'PO${9121 + payouts.length}',
                                    amount: e.available,
                                    orders: 1,
                                    at: DateTime.now(),
                                    utr:
                                        'HDFCN${DateTime.now().millisecondsSinceEpoch % 100000000}',
                                  ),
                                );
                            snack(
                              context,
                              '${inr(e.available)} sent — arrives within 2 hours (IMPS)',
                            );
                          },
                    icon: const Icon(Icons.account_balance_rounded),
                    label: Text(
                      e.available < 1
                          ? 'Nothing to withdraw yet'
                          : 'Withdraw now',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Last 30 days'),
          Panel(
            child: Column(
              children: [
                KeyValue(
                  'Gross sales (${e.ordersMonth} orders)',
                  inr(e.grossMonth),
                ),
                KeyValue(
                  'GAMEX fees incl. GST',
                  '− ${inr(e.feesMonth)}',
                  color: C.red,
                ),
                KeyValue('Shipping', 'FREE', color: C.green),
                const Divider(height: 18),
                KeyValue(
                  'Net earnings',
                  inr(e.grossMonth - e.feesMonth),
                  bold: true,
                  color: C.green,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: (e.grossMonth - e.feesMonth).round().clamp(
                          1,
                          1 << 31,
                        ),
                        child: Container(height: 10, color: C.green),
                      ),
                      Expanded(
                        flex: e.feesMonth.round().clamp(1, 1 << 31),
                        child: Container(
                          height: 10,
                          color: C.red.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const _Dot(C.green, 'You keep'),
                    const SizedBox(width: 14),
                    const _Dot(C.red, 'Fees'),
                    const Spacer(),
                    Text(
                      'Fee rate ${(Fees.commissionRate * 100).round()}% + ₹${Fees.fixedFee}',
                      style: const TextStyle(fontSize: 12, color: C.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('How payouts work'),
          const Panel(
            child: Column(
              children: [
                _Step(
                  Icons.local_shipping_rounded,
                  'Order delivered',
                  'Buyer receives the phone',
                ),
                _Step(
                  Icons.shield_moon_rounded,
                  '7-day return window',
                  'Protects you and the buyer',
                ),
                _Step(
                  Icons.account_balance_rounded,
                  'Paid to your bank',
                  'Every Monday, or withdraw any time',
                  last: true,
                ),
              ],
            ),
          ),
          const SectionTitle('Payout history'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final p in payouts)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.south_west_rounded,
                        color: C.green,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      inr(p.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${dateLong(p.at)} • UTR ${p.utr}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Pill('Paid', color: C.green),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB9C2FF), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.title, this.text, {this.last = false});
  final IconData icon;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: C.primary.withValues(alpha: 0.1),
              child: Icon(icon, size: 17, color: C.primary),
            ),
            if (!last) Container(width: 2, height: 20, color: C.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  text,
                  style: const TextStyle(fontSize: 12.5, color: C.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
