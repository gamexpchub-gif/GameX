import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand_marks.dart';
import '../../auth/providers/auth_provider.dart';
import '../../checkout/presentation/widgets/address_sheets.dart';
import '../../checkout/providers/address_provider.dart';
import '../../commerce/data/tradein.dart';
import '../../discover/presentation/filter_sheet.dart' show FChip;
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/service_api.dart';

// ───────────────────────────── Shared pieces ─────────────────────────────

/// Day + time-window picker.
class SlotPicker extends StatelessWidget {
  const SlotPicker({super.key, required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final slots = serviceSlots();
    final days = <DateTime, List<DateTime>>{};
    for (final s in slots) {
      days.putIfAbsent(DateTime(s.year, s.month, s.day), () => []).add(s);
    }
    final day = value == null
        ? days.keys.first
        : DateTime(value!.year, value!.month, value!.day);
    final now = DateTime.now();
    String dayLabel(DateTime d) => DateUtils.isSameDay(d, now)
        ? 'Today'
        : DateUtils.isSameDay(d, now.add(const Duration(days: 1)))
        ? 'Tomorrow'
        : DateFormat('EEE d').format(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final d in days.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FChip(
                    dayLabel(d),
                    DateUtils.isSameDay(d, day),
                    () => onChanged(days[d]!.first),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in days[day] ?? const <DateTime>[])
              FChip(
                '${DateFormat('h a').format(s)} – ${DateFormat('h a').format(s.add(const Duration(hours: 3)))}',
                value == s,
                () => onChanged(s),
                icon: Icons.schedule_rounded,
              ),
          ],
        ),
      ],
    );
  }
}

/// Selected address + change button.
class AddressTile extends ConsumerWidget {
  const AddressTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(addressBookProvider).current;
    return TCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: TX.violet),
          const SizedBox(width: 10),
          Expanded(
            child: a == null
                ? const Text(
                    'Add your address',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TX.ink,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a.fullName} • ${a.phone}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TX.ink,
                        ),
                      ),
                      Text(
                        a.oneLine,
                        style: const TextStyle(fontSize: 12, color: TX.muted),
                      ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: () => a == null
                ? showAddressForm(context)
                : showAddressPicker(context),
            child: Text(a == null ? 'Add' : 'Change'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Repair booking ─────────────────────────────

class RepairScreen extends ConsumerStatefulWidget {
  const RepairScreen({super.key});

  @override
  ConsumerState<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends ConsumerState<RepairScreen> {
  String _brand = 'Apple';
  String? _model;
  String? _issue;
  String _quality = 'original';
  String _mode = 'pickup';
  DateTime? _slot;
  final _notes = TextEditingController();
  bool _busy = false;

  static const _icons = {
    'screen': Icons.smartphone_rounded,
    'battery': Icons.battery_charging_full_rounded,
    'backGlass': Icons.flip_to_back_rounded,
    'charging': Icons.power_rounded,
    'camera': Icons.photo_camera_rounded,
    'speaker': Icons.volume_up_rounded,
    'water': Icons.water_drop_rounded,
    'other': Icons.help_rounded,
  };
  static const _modes = [
    (
      'pickup',
      Icons.local_shipping_rounded,
      'Free pickup & drop',
      'We collect, repair at the lab and return it',
    ),
    (
      'doorstep',
      Icons.home_repair_service_rounded,
      'Doorstep repair',
      'Technician repairs at your home (+₹199)',
    ),
    (
      'store',
      Icons.storefront_rounded,
      'Walk-in service centre',
      'Visit a GAMEX partner centre',
    ),
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  RepairQuote? get _quote => _model == null || _issue == null
      ? null
      : repairQuote(_brand, _model!, _issue!, _quality);

  Future<void> _book() async {
    final user = ref.read(authProvider);
    final a = ref.read(addressBookProvider).current;
    if (user == null) {
      context.push('/login?from=/repair');
      return;
    }
    if (_quote == null || _slot == null) {
      tSnack(
        context,
        'Choose your phone, the problem and a time slot',
        error: true,
      );
      return;
    }
    if (_mode != 'store' && a == null) {
      showAddressForm(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final job = await ref.read(serviceApiProvider).bookRepair({
        'name': a?.fullName ?? user.name,
        'phone': a?.phone ?? user.phone ?? '',
        'brand': _brand,
        'model': _model,
        'issue': _issue,
        'quality': _quality,
        'mode': _mode,
        'slot': _slot!.toUtc().toIso8601String(),
        'address': a?.oneLine ?? '',
        'city': a?.city ?? '',
        'notes': _notes.text.trim(),
      });
      ref.invalidate(myRepairsProvider);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      tSnack(context, 'Repair booked • ${job.id}');
      context.pushReplacement('/repairs');
    } catch (e) {
      if (mounted) tSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final extra = _mode == 'doorstep' ? 199.0 : 0.0;
    return TrustScaffold(
      title: 'Book a repair',
      subtitle: 'Genuine parts • repair warranty',
      trailing: TextButton(
        onPressed: () => context.push('/repairs'),
        child: const Text('My repairs'),
      ),
      bottom: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q == null
                      ? 'Price'
                      : '${q.service.label} • ${q.warrantyMonths} mo warranty',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: TX.muted),
                ),
                Text(
                  q == null ? '—' : formatPrice(q.price + extra),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: TButton(
              label: 'Book repair',
              icon: Icons.event_available_rounded,
              busy: _busy,
              onTap: _book,
            ),
          ),
        ],
      ),
      children: [
        const TTitle('Your phone'),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final b in kTradeInModels.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _brand = b;
                      _model = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _brand == b ? TX.violet : TX.line,
                          width: _brand == b ? 1.8 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            height: 22,
                            child: Center(
                              child: BrandMark(b.toLowerCase(), size: 16),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            b,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in kTradeInModels[_brand]!.keys)
              FChip(m, _model == m, () => setState(() => _model = m)),
          ],
        ),
        const TTitle('What needs fixing?'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            for (final r in kRepairs)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _issue = r.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _issue == r.id
                        ? TX.violet.withValues(alpha: 0.07)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _issue == r.id ? TX.violet : TX.line,
                      width: _issue == r.id ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_icons[r.id], color: TX.violet, size: 20),
                          const Spacer(),
                          if (_model != null)
                            Text(
                              formatPrice(
                                repairQuote(
                                  _brand,
                                  _model!,
                                  r.id,
                                  _quality,
                                )!.price,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                color: TX.ink,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        r.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TX.ink,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        r.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: TX.muted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const TTitle('Part quality'),
        Row(
          children: [
            Expanded(
              child: _QualityCard(
                'Original (OEM)',
                'Best quality • 6-month warranty',
                _quality == 'original',
                () => setState(() => _quality = 'original'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QualityCard(
                'Premium compatible',
                'Save ~35% • 3-month warranty',
                _quality == 'compatible',
                () => setState(() => _quality = 'compatible'),
              ),
            ),
          ],
        ),
        const TTitle('How do you want it fixed?'),
        for (final (id, icon, title, sub) in _modes) ...[
          TCard(
            onTap: () => setState(() => _mode = id),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TIcon(icon, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TX.ink,
                        ),
                      ),
                      Text(
                        sub,
                        style: const TextStyle(fontSize: 12, color: TX.muted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _mode == id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: _mode == id ? TX.violet : TX.faint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const TTitle('Pick a time'),
        SlotPicker(value: _slot, onChanged: (s) => setState(() => _slot = s)),
        if (_mode != 'store') ...[const TTitle('Address'), const AddressTile()],
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: tInput(
            'Anything else we should know? (optional)',
            prefix: const Icon(Icons.notes_rounded),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Pay after the repair. Data stays on your phone; we recommend a backup before pickup.',
          style: TextStyle(fontSize: 11.5, color: TX.faint),
        ),
      ],
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard(this.title, this.sub, this.on, this.onTap);
  final String title;
  final String sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: on ? TX.violet.withValues(alpha: 0.07) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: on ? TX.violet : TX.line,
          width: on ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: TX.ink,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: TX.muted)),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Jobs list ─────────────────────────────

const _statusLabels = {
  'booked': ('Booked', TX.blue),
  'assigned': ('Technician assigned', TX.violet),
  'inRepair': ('In repair', TX.amber),
  'completed': ('Completed', TX.green),
  'requested': ('Pickup requested', TX.blue),
  'scheduled': ('Pickup scheduled', TX.violet),
  'pickedUp': ('Collected • inspecting', TX.amber),
  'paid': ('Paid', TX.green),
  'rejected': ('Not accepted', TX.red),
  'cancelled': ('Cancelled', TX.faint),
};

/// "My repairs" ([sell] false) or "My sell requests" ([sell] true).
class ServiceJobsScreen extends ConsumerWidget {
  const ServiceJobsScreen({super.key, required this.sell});
  final bool sell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = sell ? mySellsProvider : myRepairsProvider;
    final async = ref.watch(p);
    final f = DateFormat('EEE d MMM, h a');
    return TrustScaffold(
      title: sell ? 'My sell requests' : 'My repairs',
      subtitle: sell
          ? 'Phones you are selling to GAMEX'
          : 'Bookings and repair status',
      bottom: TButton(
        label: sell ? 'Sell another phone' : 'Book a new repair',
        icon: Icons.add_rounded,
        onTap: () => context.push(sell ? '/sell' : '/repair'),
      ),
      children: async.when(
        loading: () => const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
        error: (e, _) => [
          const SizedBox(height: 100),
          Center(
            child: Text(
              '$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TX.muted),
            ),
          ),
        ],
        data: (list) => list.isEmpty
            ? [
                const SizedBox(height: 80),
                Center(
                  child: TIcon(
                    sell ? Icons.sell_rounded : Icons.build_rounded,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    sell ? 'No sell requests yet' : 'No repairs booked yet',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: TX.ink,
                    ),
                  ),
                ),
              ]
            : [
                for (final j in list) ...[
                  TCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${j.model} • ${j.title}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: TX.ink,
                                    ),
                                  ),
                                  Text(
                                    '${j.id} • ${f.format(j.slot.toLocal())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: TX.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TPill(
                              _statusLabels[j.status]?.$1 ?? j.status,
                              color: _statusLabels[j.status]?.$2 ?? TX.faint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${sell ? 'You get' : 'Price'} ${formatPrice(j.amount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: TX.green,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final (l, a) in j.events.reversed.take(3))
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: TX.violet,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                                Text(
                                  DateFormat('d MMM').format(a.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TX.faint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (j.cancellable)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                try {
                                  await ref.read(serviceApiProvider).cancel(j);
                                  ref.invalidate(p);
                                } catch (e) {
                                  if (context.mounted) {
                                    tSnack(context, '$e', error: true);
                                  }
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
      ),
    );
  }
}

// ───────────────────────────── Sell to GAMEX ─────────────────────────────

/// Pickup + payout details after a sell quote.
Future<void> showSellPickupSheet(BuildContext context, TradeInQuote q) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F4FF),
      builder: (_) => _SellSheet(q: q),
    );

class _SellSheet extends ConsumerStatefulWidget {
  const _SellSheet({required this.q});
  final TradeInQuote q;

  @override
  ConsumerState<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends ConsumerState<_SellSheet> {
  DateTime? _slot;
  String _method = 'upi';
  final _upi = TextEditingController();
  final _acc = TextEditingController();
  final _ifsc = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _upi.dispose();
    _acc.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider);
    final a = ref.read(addressBookProvider).current;
    if (user == null) {
      Navigator.pop(context);
      context.push('/login?from=/sell');
      return;
    }
    if (a == null) return showAddressForm(context);
    if (_slot == null) {
      return tSnack(context, 'Choose a pickup time', error: true);
    }
    setState(() => _busy = true);
    try {
      await ref.read(serviceApiProvider).sell({
        'name': a.fullName,
        'phone': a.phone,
        'device': widget.q.device.toJson(),
        'address': a.oneLine,
        'city': a.city,
        'slot': _slot!.toUtc().toIso8601String(),
        'payout': {
          'method': _method,
          'upi': _upi.text.trim(),
          'account': _acc.text.trim(),
          'ifsc': _ifsc.text.trim().toUpperCase(),
        },
      });
      ref.invalidate(mySellsProvider);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      Navigator.pop(context);
      context.pushReplacement('/sell/requests');
    } catch (e) {
      if (mounted) tSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      0,
      18,
      18 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sell ${widget.q.device.model} for ${formatPrice(widget.q.amount)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: TX.ink,
            ),
          ),
          const Text(
            'Free pickup • paid within 24 hours of inspection',
            style: TextStyle(color: TX.muted),
          ),
          const TTitle('Pickup address'),
          const AddressTile(),
          const TTitle('Pickup time'),
          SlotPicker(value: _slot, onChanged: (s) => setState(() => _slot = s)),
          const TTitle('Get paid by'),
          Row(
            children: [
              FChip(
                'UPI',
                _method == 'upi',
                () => setState(() => _method = 'upi'),
                icon: Icons.qr_code_2_rounded,
              ),
              const SizedBox(width: 8),
              FChip(
                'Bank transfer',
                _method == 'bank',
                () => setState(() => _method = 'bank'),
                icon: Icons.account_balance_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_method == 'upi')
            TextField(
              controller: _upi,
              decoration: tInput('UPI ID, e.g. name@okaxis'),
            )
          else ...[
            TextField(
              controller: _acc,
              keyboardType: TextInputType.number,
              decoration: tInput('Account number'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ifsc,
              textCapitalization: TextCapitalization.characters,
              decoration: tInput('IFSC code'),
            ),
          ],
          const SizedBox(height: 16),
          TButton(
            label: 'Confirm pickup',
            icon: Icons.check_circle_rounded,
            busy: _busy,
            onTap: _submit,
          ),
          const SizedBox(height: 8),
          const Text(
            'The agent checks the phone at pickup. If it differs from your answers, you get a revised offer and can cancel for free.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: TX.muted),
          ),
        ],
      ),
    ),
  );
}
