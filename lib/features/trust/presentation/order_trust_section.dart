import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../data/trust_api.dart';
import 'widgets/trust_ui.dart';

/// Open-box delivery, returns and warranty for a marketplace order.
class OrderTrustSection extends ConsumerWidget {
  const OrderTrustSection({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderTrackProvider(orderId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => TCard(
        onTap: () => ref.invalidate(orderTrackProvider(orderId)),
        child: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: TX.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Live tracking unavailable. Tap to retry.',
                style: TextStyle(color: TX.muted),
              ),
            ),
          ],
        ),
      ),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final t in items) _ItemTrust(t: t, orderId: orderId)],
      ),
    );
  }
}

class _ItemTrust extends ConsumerWidget {
  const _ItemTrust({required this.t, required this.orderId});
  final OrderTrack t;
  final String orderId;

  void _refresh(WidgetRef ref) => ref.invalidate(orderTrackProvider(orderId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t.outForDelivery) ...[
          _OpenBox(t: t, onChanged: () => _refresh(ref)),
          const SizedBox(height: 12),
        ],
        if (t.delivered || t.returnRequest != null) ...[
          _WarrantyMini(t: t, orderId: orderId),
          const SizedBox(height: 12),
          _ReturnCard(t: t, onChanged: () => _refresh(ref)),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (t.sellerId != null)
              Expanded(
                child: TGhost(
                  label: t.sellerName ?? 'Seller',
                  icon: Icons.storefront_outlined,
                  height: 48,
                  onTap: () => context.push('/seller/${t.sellerId}'),
                ),
              ),
            if (t.sellerId != null && t.certificate != null)
              const SizedBox(width: 10),
            if (t.certificate != null)
              Expanded(
                child: TGhost(
                  label: 'Certificate',
                  icon: Icons.workspace_premium_outlined,
                  height: 48,
                  color: TX.green,
                  onTap: () => context.push('/certificate/${t.certificate}'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------- open box

class _OpenBox extends StatefulWidget {
  const _OpenBox({required this.t, required this.onChanged});
  final OrderTrack t;
  final VoidCallback onChanged;

  @override
  State<_OpenBox> createState() => _OpenBoxState();
}

class _OpenBoxState extends State<_OpenBox> {
  static const _steps = [
    ('Box & seal', 'Outer box is sealed and undamaged'),
    ('IMEI match', 'Dial *#06# - must match the GAMEX certificate'),
    ('Screen & touch', 'No new cracks, dead pixels or touch issues'),
    ('Cameras & sound', 'Take a photo, play a sound, make a test call'),
    ('Condition', 'Body matches the photos and grade'),
  ];
  final _done = <int>{};
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final ready = _done.length == _steps.length;
    return THero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Open-box delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TPill(
                'Out for delivery',
                color: Color(0xFF7DD3FC),
                icon: Icons.local_shipping_rounded,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Open the box in front of the delivery partner. Share the OTP only after every check passes.',
            style: TextStyle(
              color: Color(0xFFC9D2FF),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  InkWell(
                    onTap: () => setState(
                      () => _done.contains(i) ? _done.remove(i) : _done.add(i),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _done.contains(i) ? TX.success : null,
                              border: _done.contains(i)
                                  ? null
                                  : Border.all(color: TX.faint, width: 1.6),
                            ),
                            child: _done.contains(i)
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _steps[i].$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: TX.ink,
                                  ),
                                ),
                                Text(
                                  _steps[i].$2,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: TX.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i == 1)
                            TextButton(
                              onPressed: () => context.push('/trust/scan'),
                              child: const Text(
                                'Scan QR',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: ready ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery OTP',
                        style: TextStyle(
                          color: Color(0xFFC9D2FF),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        ready && _show
                            ? (t.otp ?? '----').split('').join('  ')
                            : '•  •  •  •',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        ready
                            ? 'Tell this OTP to the delivery partner'
                            : 'Complete all ${_steps.length} checks to reveal',
                        style: const TextStyle(
                          color: Color(0xFFC9D2FF),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TButton(
                    label: _show ? 'Hide' : 'Show',
                    icon: _show
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    height: 46,
                    gradient: TX.success,
                    onTap: ready
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _show = !_show);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => _refuse(context),
              icon: const Icon(
                Icons.do_not_disturb_on_outlined,
                color: Color(0xFFFFB4C0),
              ),
              label: const Text(
                'Something wrong? Refuse the phone',
                style: TextStyle(
                  color: Color(0xFFFFB4C0),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refuse(BuildContext context) async {
    const reasons = [
      'Phone doesn\'t match the photos',
      'IMEI doesn\'t match',
      'Screen / body damage',
      'Not working properly',
      'Box tampered',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Refuse at doorstep',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Don\'t share the OTP. Hand the phone back to the delivery partner. Any payment is refunded in full.',
                style: TextStyle(color: TX.muted, height: 1.4),
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
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(trustApiProvider).refuse(widget.t.id, reason);
      if (!context.mounted) return;
      tSnack(context, 'Refused. Your refund is on its way.');
      widget.onChanged();
    } catch (e) {
      if (context.mounted) tSnack(context, e.toString(), error: true);
    }
  }
}

// ---------------------------------------------------------------- warranty

class _WarrantyMini extends StatelessWidget {
  const _WarrantyMini({required this.t, required this.orderId});
  final OrderTrack t;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final until = t.warrantyUntil;
    final active = t.warrantyActive;
    final days = until == null ? 0 : until.difference(DateTime.now()).inDays;
    return WarrantyCardFace(
      t: t,
      compact: true,
      onTap: () => context.push(
        '/warranty/${Uri.encodeComponent(orderId)}/${Uri.encodeComponent(t.id)}',
      ),
      footer: until == null
          ? 'No seller warranty on this phone'
          : active
          ? '$days days left • tap to view or claim'
          : 'Expired on ${DateFormat('d MMM yyyy').format(until)}',
    );
  }
}

/// The digital warranty card (holographic look).
class WarrantyCardFace extends StatelessWidget {
  const WarrantyCardFace({
    super.key,
    required this.t,
    this.compact = false,
    this.onTap,
    this.footer,
  });
  final OrderTrack t;
  final bool compact;
  final VoidCallback? onTap;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final until = t.warrantyUntil;
    final start = t.deliveredAt;
    final active = t.warrantyActive;
    final total = until == null || start == null
        ? 1
        : until.difference(start).inDays.clamp(1, 9999);
    final left = until == null
        ? 0
        : until.difference(DateTime.now()).inDays.clamp(0, 9999);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: active
                ? const [
                    Color(0xFF0B1033),
                    Color(0xFF2A1466),
                    Color(0xFF7B3DF5),
                  ]
                : const [
                    Color(0xFF3F3F46),
                    Color(0xFF52525B),
                    Color(0xFF71717A),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A1466).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: const Alignment(-1, -1),
            end: const Alignment(1, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.35, 0.5, 0.65],
          ),
        ),
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFFFCD34D),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'GAMEX WARRANTY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 13,
                    ),
                  ),
                ),
                TPill(
                  active ? 'ACTIVE' : (until == null ? 'NONE' : 'EXPIRED'),
                  color: active ? const Color(0xFF4ADE80) : Colors.white70,
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              t.item,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              t.variant,
              style: const TextStyle(color: Color(0xFFC9D2FF), fontSize: 12.5),
            ),
            SizedBox(height: compact ? 10 : 16),
            Row(
              children: [
                Expanded(child: _Field('IMEI', t.imei ?? '—')),
                Expanded(
                  child: _Field(
                    'Valid till',
                    until == null
                        ? '—'
                        : DateFormat('d MMM yyyy').format(until),
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Field('Certificate', t.certificate ?? '—')),
                  Expanded(
                    child: _Field(
                      'Purchased',
                      start == null
                          ? '—'
                          : DateFormat('d MMM yyyy').format(start),
                    ),
                  ),
                ],
              ),
            ],
            if (until != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (left / total).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFFCD34D),
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(
                footer!,
                style: const TextStyle(
                  color: Color(0xFFC9D2FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF9DA8E8),
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- returns

const _returnSteps = ['requested', 'pickup_scheduled', 'picked_up', 'refunded'];
const _returnLabels = {
  'requested': 'Requested',
  'pickup_scheduled': 'Pickup scheduled',
  'picked_up': 'Picked up',
  'refunded': 'Refunded',
  'rejected': 'Rejected',
};

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.t, required this.onChanged});
  final OrderTrack t;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final r = t.returnRequest;
    if (r != null && r['status'] != 'rejected') return _ReturnStatus(r: r);
    final until = t.returnUntil;
    final daysLeft = until == null
        ? 0
        : (until.difference(DateTime.now()).inHours / 24).ceil();
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TIcon(
                Icons.assignment_return_rounded,
                gradient: LinearGradient(
                  colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                ),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Easy return',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: TX.ink,
                      ),
                    ),
                    Text(
                      t.returnDays == 0
                          ? 'This phone was sold without returns'
                          : t.canReturn
                          ? '$daysLeft day${daysLeft == 1 ? '' : 's'} left • free doorstep pickup'
                          : 'Return window closed${until == null ? '' : ' on ${DateFormat('d MMM').format(until)}'}',
                      style: const TextStyle(fontSize: 12.5, color: TX.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r != null && r['status'] == 'rejected') ...[
            const SizedBox(height: 8),
            Text(
              'Last request was rejected: ${r['note'] ?? ''}',
              style: const TextStyle(color: TX.red, fontSize: 12.5),
            ),
          ],
          if (t.canReturn) ...[
            const SizedBox(height: 12),
            TButton(
              label: 'Return this phone',
              icon: Icons.assignment_return_rounded,
              height: 48,
              gradient: const LinearGradient(
                colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
              ),
              onTap: () => _start(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReturnSheet(t: t),
    );
    if (ok == true) onChanged();
  }
}

class _ReturnStatus extends StatelessWidget {
  const _ReturnStatus({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final status = r['status'] as String;
    final idx = _returnSteps.indexOf(status);
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TIcon(
                Icons.assignment_return_rounded,
                gradient: LinearGradient(
                  colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                ),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Return in progress',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: TX.ink,
                      ),
                    ),
                    Text(
                      '${r['reason']} • refund ${formatPrice((r['refund'] as num?) ?? 0)}',
                      style: const TextStyle(fontSize: 12.5, color: TX.muted),
                    ),
                  ],
                ),
              ),
              TPill(
                _returnLabels[status] ?? status,
                color: status == 'refunded' ? TX.green : TX.amber,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _returnSteps.length; i++) ...[
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: i <= idx ? TX.chip : null,
                        color: i <= idx ? null : const Color(0xFFEDEBFA),
                      ),
                      child: Icon(
                        i < idx || status == 'refunded'
                            ? Icons.check_rounded
                            : Icons.circle,
                        size: i < idx || status == 'refunded' ? 15 : 7,
                        color: i <= idx ? Colors.white : TX.faint,
                      ),
                    ),
                  ],
                ),
                if (i < _returnSteps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i < idx ? TX.violet : const Color(0xFFEDEBFA),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requested',
                style: TextStyle(fontSize: 10.5, color: TX.muted),
              ),
              Text('Pickup', style: TextStyle(fontSize: 10.5, color: TX.muted)),
              Text(
                'QC check',
                style: TextStyle(fontSize: 10.5, color: TX.muted),
              ),
              Text('Refund', style: TextStyle(fontSize: 10.5, color: TX.muted)),
            ],
          ),
          if (r['pickupSlot'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: TX.muted),
                const SizedBox(width: 6),
                Text(
                  'Pickup: ${r['pickupSlot']}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: TX.ink,
                    fontWeight: FontWeight.w600,
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

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.t});
  final OrderTrack t;

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  static const _reasons = [
    'Not as described',
    'Found a defect',
    'Battery drains fast',
    'Changed my mind',
    'Other',
  ];
  String? _reason;
  late String _slot = _slots.first;
  final _details = TextEditingController();
  bool _busy = false;

  List<String> get _slots {
    final f = DateFormat('EEE d MMM');
    final d1 = DateTime.now().add(const Duration(days: 1));
    final d2 = DateTime.now().add(const Duration(days: 2));
    return [
      '${f.format(d1)}, 10 AM – 1 PM',
      '${f.format(d1)}, 2 – 6 PM',
      '${f.format(d2)}, 10 AM – 1 PM',
    ];
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return tSnack(context, 'Choose a reason', error: true);
    setState(() => _busy = true);
    try {
      await ref
          .read(trustApiProvider)
          .requestReturn(
            widget.t.id,
            reason: _reason!,
            details: _details.text.trim(),
            pickupSlot: _slot,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      tSnack(context, 'Return requested. Pickup on $_slot');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        tSnack(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Return this phone',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: TX.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.t.item} • full refund of ${formatPrice(widget.t.price)} after a quick QC check',
              style: const TextStyle(color: TX.muted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Why are you returning it?',
              style: TextStyle(fontWeight: FontWeight.w800, color: TX.ink),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _details,
              maxLines: 2,
              decoration: tInput('Tell us more (optional)'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pickup slot',
              style: TextStyle(fontWeight: FontWeight.w800, color: TX.ink),
            ),
            const SizedBox(height: 8),
            for (final s in _slots)
              RadioGroup<String>(
                groupValue: _slot,
                onChanged: (v) => setState(() => _slot = v ?? _slot),
                child: RadioListTile<String>(
                  value: s,
                  title: Text(s),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: TX.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep the box, charger and bill ready. Remove your accounts and factory reset the phone before pickup.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: TX.ink,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TButton(
              label: 'Request return',
              icon: Icons.assignment_return_rounded,
              busy: _busy,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
