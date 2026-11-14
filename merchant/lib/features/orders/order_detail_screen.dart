import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(orderByIdProvider(orderId));
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.search_off_rounded,
          title: 'Order not found',
          text: 'It may have been removed.',
        ),
      );
    }
    final listing = ref.watch(listingByIdProvider(o.listingId));
    final n = ref.read(syncProvider.notifier);
    final fees = Fees.totalFees(o.price);

    return Scaffold(
      appBar: AppBar(
        title: Text(o.id),
        actions: [
          if (o.awb != null)
            IconButton(
              tooltip: 'Shipping label',
              onPressed: () => _showLabel(context, o),
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _StageHeader(order: o),
          const SizedBox(height: 12),
          Panel(
            child: Row(
              children: [
                Photo(o.photo, size: 76),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.item,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(o.variant, style: const TextStyle(color: C.muted)),
                      const SizedBox(height: 6),
                      if (listing != null)
                        Text(
                          'IMEI ${listing.imei}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: C.muted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Your earnings'),
          Panel(
            child: Column(
              children: [
                KeyValue('Selling price', inr(o.price)),
                KeyValue(
                  'Commission (8%) + fixed fee + GST',
                  '− ${inr(fees)}',
                  color: C.red,
                ),
                const Divider(height: 18),
                KeyValue(
                  'You receive',
                  inr(o.payout),
                  bold: true,
                  color: C.green,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: C.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        o.payment == 'COD'
                            ? 'COD • collected by courier, paid 7 days after delivery'
                            : '${o.payment} • prepaid, paid 7 days after delivery',
                        style: const TextStyle(fontSize: 12.5, color: C.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Ship to'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.buyer,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${o.address}\n${o.city} – ${o.pincode}',
                  style: const TextStyle(color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: C.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      o.stage.open
                          ? 'Phone ${o.phone.substring(0, 6)}•••••• (masked)'
                          : 'Buyer contact hidden after fulfilment',
                      style: const TextStyle(fontSize: 12.5, color: C.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (o.awb != null) ...[
            const SectionTitle('Shipment'),
            Panel(
              child: Column(
                children: [
                  KeyValue('Courier', o.courier ?? '—'),
                  KeyValue('AWB number', o.awb!),
                  if (o.pickupAt != null)
                    KeyValue('Pickup slot', dateTime(o.pickupAt!)),
                ],
              ),
            ),
          ],
          if (o.cancelReason != null) ...[
            const SectionTitle('Cancellation'),
            Panel(
              color: C.red.withValues(alpha: 0.05),
              child: Text(
                o.cancelReason!,
                style: const TextStyle(
                  color: C.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SectionTitle('Timeline'),
          Panel(
            child: Column(
              children: [
                for (var i = o.events.length - 1; i >= 0; i--)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: i == o.events.length - 1
                                  ? C.primary
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: C.primary, width: 2.5),
                            ),
                          ),
                          if (i > 0)
                            Container(width: 2, height: 34, color: C.border),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.events[i].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              dateTime(o.events[i].at),
                              style: const TextStyle(
                                fontSize: 12,
                                color: C.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: switch (o.stage) {
        OrderStage.newOrder => ActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(context, ref, o),
                  style: OutlinedButton.styleFrom(foregroundColor: C.red),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Accept order',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    runAction(
                      context,
                      () => n.accept(o.id),
                      done: 'Order accepted — pack it within 24 hours',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        OrderStage.accepted => ActionBar(
          child: GradientButton(
            label: 'Verify IMEI & mark packed',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: () => _pack(context, ref, o, listing),
          ),
        ),
        OrderStage.packed => ActionBar(
          child: GradientButton(
            label: 'Schedule courier pickup',
            icon: Icons.local_shipping_rounded,
            onPressed: () => _ship(context, ref, o),
          ),
        ),
        OrderStage.shipped => ActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLabel(context, o),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Label'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.green),
                  onPressed: () {
                    runAction(
                      context,
                      () => n.deliver(o.id),
                      done: 'Marked delivered (courier confirmation)',
                    );
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Delivered'),
                ),
              ),
            ],
          ),
        ),
        _ => null,
      },
    );
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    SellerOrder o,
  ) async {
    const reasons = [
      'Phone no longer available',
      'Found a defect during final check',
      'Price listed incorrectly',
      'Cannot ship to this pincode',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Why are you rejecting?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Frequent rejections lower your seller rating.',
                style: TextStyle(color: C.muted),
              ),
            ),
            for (final r in reasons)
              ListTile(
                leading: const Icon(Icons.radio_button_off_rounded),
                title: Text(r),
                onTap: () => Navigator.pop(c, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(syncProvider.notifier).reject(o.id, reason),
      done: 'Order rejected',
      icon: Icons.cancel_rounded,
    );
  }

  Future<void> _pack(
    BuildContext context,
    WidgetRef ref,
    SellerOrder o,
    Listing? listing,
  ) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _PackSheet(expectedImei: listing?.imei),
    );
    if (ok != true || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(syncProvider.notifier).pack(o.id),
      done: 'Packed & IMEI verified — schedule the pickup next',
    );
  }

  Future<void> _ship(BuildContext context, WidgetRef ref, SellerOrder o) async {
    final res = await showModalBottomSheet<(String, DateTime)>(
      context: context,
      builder: (c) => const _ShipSheet(),
    );
    if (res == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(syncProvider.notifier).ship(o.id, res.$1, res.$2),
      done: 'Pickup booked with ${res.$1}',
    );
  }

  void _showLabel(BuildContext context, SellerOrder o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: C.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (o.courier ?? '').toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          o.payment == 'COD'
                              ? 'COD ${inr(o.price)}'
                              : 'PREPAID',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: CustomPaint(
                        painter: _BarcodePainter(o.awb ?? o.id),
                        size: Size.infinite,
                      ),
                    ),
                    Center(
                      child: Text(
                        o.awb ?? '',
                        style: const TextStyle(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Divider(height: 22, color: C.ink),
                    const Text(
                      'DELIVER TO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${o.buyer}\n${o.address}\n${o.city} – ${o.pincode}',
                      style: const TextStyle(height: 1.35),
                    ),
                    const Divider(height: 22, color: C.ink),
                    Text(
                      'Order ${o.id} • ${o.item} (${o.variant})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Send to printer',
                icon: Icons.print_rounded,
                onPressed: () {
                  Navigator.pop(c);
                  snack(context, 'Label sent to printer');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    const steps = [
      OrderStage.newOrder,
      OrderStage.accepted,
      OrderStage.packed,
      OrderStage.shipped,
      OrderStage.delivered,
    ];
    final idx = steps.indexOf(order.stage);
    final closed = idx < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: closed ? null : C.nightGradient,
        color: closed ? stageColor(order.stage).withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.stage.label,
                style: TextStyle(
                  color: closed ? stageColor(order.stage) : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Placed ${dateTime(order.placedAt)}',
                style: TextStyle(
                  color: closed ? C.muted : const Color(0xFFB9C2FF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (!closed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: i <= idx ? Colors.white : Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i < idx ? Icons.check_rounded : Icons.circle,
                      size: i < idx ? 16 : 8,
                      color: i <= idx ? C.primary : Colors.white38,
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i < idx ? Colors.white : Colors.white12,
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in const ['New', 'Accept', 'Pack', 'Ship', 'Done'])
                  Text(
                    l,
                    style: const TextStyle(
                      color: Color(0xFFB9C2FF),
                      fontSize: 11,
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

class _PackSheet extends StatefulWidget {
  const _PackSheet({required this.expectedImei});
  final String? expectedImei;

  @override
  State<_PackSheet> createState() => _PackSheetState();
}

class _PackSheetState extends State<_PackSheet> {
  final _imei = TextEditingController();
  final _checks = <String, bool>{
    'Phone matches listing photos': false,
    'Factory reset & accounts removed': false,
    'Bubble-wrapped in a sealed box': false,
    'Invoice & accessories included': false,
  };
  String? _err;

  @override
  void dispose() {
    _imei.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allChecked = _checks.values.every((v) => v);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pack & verify',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter the IMEI from *#06# on the phone you are packing.',
            style: TextStyle(color: C.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _imei,
            keyboardType: TextInputType.number,
            maxLength: 15,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'IMEI',
              counterText: '',
              errorText: _err,
              prefixIcon: const Icon(Icons.qr_code_2_rounded),
              suffixIcon: TextButton(
                onPressed: () => setState(() {
                  _imei.text = widget.expectedImei ?? '';
                  _err = null;
                }),
                child: const Text('Scan'),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final k in _checks.keys)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checks[k],
              onChanged: (v) => setState(() => _checks[k] = v ?? false),
              title: Text(k, style: const TextStyle(fontSize: 14)),
            ),
          const SizedBox(height: 10),
          GradientButton(
            label: 'Confirm packed',
            icon: Icons.inventory_rounded,
            onPressed: allChecked
                ? () {
                    if (widget.expectedImei != null &&
                        _imei.text != widget.expectedImei) {
                      setState(
                        () => _err =
                            'IMEI does not match this listing (${widget.expectedImei})',
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _ShipSheet extends StatefulWidget {
  const _ShipSheet();

  @override
  State<_ShipSheet> createState() => _ShipSheetState();
}

class _ShipSheetState extends State<_ShipSheet> {
  String _courier = 'Delhivery';
  int _slot = 0;

  List<DateTime> get _slots {
    final n = DateTime.now();
    final base = DateTime(n.year, n.month, n.day);
    return [
      for (final h in [11, 15, 18, 35, 39]) base.add(Duration(hours: h)),
    ].where((d) => d.isAfter(n.add(const Duration(hours: 1)))).take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    const couriers = [
      ('Delhivery', 'Pickup today • 2–3 day delivery'),
      ('Blue Dart', 'Premium • 1–2 day delivery'),
      ('Ekart', 'Economy • 3–4 day delivery'),
    ];
    final slots = _slots;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule pickup',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Shipping is free for you — GAMEX pays the courier.',
              style: TextStyle(color: C.muted),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _courier,
              onChanged: (v) => setState(() => _courier = v ?? _courier),
              child: Column(
                children: [
                  for (final c in couriers)
                    RadioListTile<String>(
                      value: c.$1,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        c.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(c.$2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pickup slot',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < slots.length; i++)
                  ChoiceChip(
                    label: Text(dateTime(slots[i])),
                    selected: _slot == i,
                    onSelected: (_) => setState(() => _slot = i),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Book pickup & generate AWB',
              icon: Icons.local_shipping_rounded,
              onPressed: () => Navigator.pop(context, (
                _courier,
                slots[_slot.clamp(0, slots.length - 1)],
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = C.ink;
    var x = 0.0;
    var i = 0;
    final codes = data.codeUnits;
    while (x < size.width) {
      final c = codes[i % codes.length] + i;
      final w = 1.0 + (c % 3);
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + (c % 2 == 0 ? 1 : 2);
      i++;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.data != data;
}
