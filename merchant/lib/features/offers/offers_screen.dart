import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

/// Buyers' price offers (Make an Offer): accept, counter or decline.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    final open = offers.where((o) => o.pending).toList();
    final waiting = offers.where((o) => o.status == 'countered').toList();
    final history = offers
        .where((o) => !o.pending && o.status != 'countered')
        .toList();
    final won = offers.where(
      (o) => o.status == 'accepted' || o.status == 'used',
    );
    final rate = offers.isEmpty
        ? 0
        : (won.length * 100 / offers.length).round();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buyer Offers'),
          bottom: TabBar(
            labelColor: C.primary,
            unselectedLabelColor: C.muted,
            indicatorColor: C.primary,
            dividerColor: C.border,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
            tabs: [
              Tab(text: 'New (${open.length})'),
              Tab(text: 'Countered (${waiting.length})'),
              const Tab(text: 'History'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: C.nightGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.handshake_rounded,
                    color: Color(0xFFFFC542),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reply within 24 hours. Accepted prices are held for the buyer for 48 hours.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Text(
                        '$rate%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'closed',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _List(
                    open,
                    empty: 'No new offers. Buyers can make offers on any active listing.',
                  ),
                  _List(
                    waiting,
                    empty: 'No counter-offers waiting for the buyer.',
                  ),
                  _List(
                    history,
                    empty: 'Accepted, declined and expired offers appear here.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List(this.items, {required this.empty});
  final List<BuyerOffer> items;
  final String empty;

  @override
  Widget build(BuildContext context) => items.isEmpty
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              empty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.muted),
            ),
          ),
        )
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _OfferCard(o: items[i]),
        );
}

const _labels = {
  'pending': 'New',
  'countered': 'Countered',
  'accepted': 'Accepted',
  'rejected': 'Declined',
  'expired': 'Expired',
  'withdrawn': 'Withdrawn',
  'used': 'Sold',
};

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.o});
  final BuyerOffer o;

  Color get _color => switch (o.status) {
    'pending' => C.primary,
    'countered' => C.amber,
    'accepted' || 'used' => C.green,
    _ => C.faint,
  };

  Future<void> _counter(BuildContext context, WidgetRef ref) async {
    final mid = ((o.amount + o.listPrice) / 2 / 100).round() * 100 - 1;
    var value = mid.toDouble();
    final amount = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Counter-offer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                '${o.customerName} offered ${inr(o.amount)} • listed ${inr(o.listPrice)}',
                style: const TextStyle(color: C.muted),
              ),
              const SizedBox(height: 18),
              Text(
                inr(value.round()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: C.primary,
                ),
              ),
              Slider(
                value: value,
                min: o.amount + 100.0,
                max: o.listPrice - 1.0,
                divisions: ((o.listPrice - o.amount) / 100).round().clamp(
                  1,
                  500,
                ),
                onChanged: (v) =>
                    set(() => value = ((v / 100).round() * 100 - 1).toDouble()),
              ),
              Text(
                'You receive ~${inr((value * 0.9).round())} after fees',
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Send counter ${inr(value.round())}',
                icon: Icons.send_rounded,
                onPressed: () => Navigator.pop(ctx, value.round()),
              ),
            ],
          ),
        ),
      ),
    );
    if (amount == null || !context.mounted) return;
    await runAction(
      context,
      () => ref
          .read(syncProvider.notifier)
          .offerAction(o.id, 'counter', amount: amount),
      done: 'Counter-offer sent to ${o.customerName}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = o.expiresAt?.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (o.photo != null) ...[
                Photo(o.photo!, size: 54),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${o.customerName} • ${ago(o.createdAt)}',
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _labels[o.status] ?? o.status,
                  style: TextStyle(
                    color: _color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Num('Offer', inr(o.amount), C.primary),
              _Num('Listed', inr(o.listPrice), C.ink),
              _Num(
                'Below list',
                '${o.percentOff}%',
                o.percentOff > 12 ? C.red : C.amber,
              ),
              if (o.counter != null)
                _Num('Your counter', inr(o.counter!), C.amber),
            ],
          ),
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"${o.note}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: C.ink,
                ),
              ),
            ),
          ],
          if (o.pending) ...[
            if (left != null && !left.isNegative)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Expires in ${left.inHours}h ${left.inMinutes % 60}m',
                  style: const TextStyle(
                    color: C.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => runAction(
                      context,
                      () => ref
                          .read(syncProvider.notifier)
                          .offerAction(o.id, 'reject'),
                      done: 'Offer declined',
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _counter(context, ref),
                    child: const Text('Counter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.green),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      runAction(
                        context,
                        () => ref
                            .read(syncProvider.notifier)
                            .offerAction(o.id, 'accept'),
                        done: 'Accepted • held for the buyer for 48 hours',
                      );
                    },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w900, color: color),
        ),
      ],
    ),
  );
}
