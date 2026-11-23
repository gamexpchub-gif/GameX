import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/trust_api.dart';
import 'order_trust_section.dart';
import 'widgets/trust_ui.dart';

const _claimLabels = {
  'submitted': 'Submitted',
  'approved': 'In repair',
  'resolved': 'Resolved',
  'rejected': 'Rejected',
};

/// Full digital warranty card with claim history and "Raise a claim".
class WarrantyCardScreen extends ConsumerWidget {
  const WarrantyCardScreen({
    super.key,
    required this.orderId,
    required this.itemId,
  });
  final String orderId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderTrackProvider(orderId));
    return async.when(
      loading: () => const TrustScaffold(
        title: 'Warranty',
        children: [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (e, _) => TrustScaffold(
        title: 'Warranty',
        children: [
          const SizedBox(height: 120),
          Center(child: Text('$e')),
        ],
      ),
      data: (items) {
        final t = items.where((x) => x.id == itemId).firstOrNull;
        if (t == null) {
          return const TrustScaffold(
            title: 'Warranty',
            children: [
              SizedBox(height: 120),
              Center(child: Text('Warranty not found')),
            ],
          );
        }
        final open = t.openClaim;
        return TrustScaffold(
          title: 'Digital warranty',
          subtitle: t.item,
          bottom: t.warrantyActive && open == null
              ? TButton(
                  label: 'Raise a warranty claim',
                  icon: Icons.build_circle_outlined,
                  onTap: () async {
                    final ok = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _ClaimSheet(t: t),
                    );
                    if (ok == true) ref.invalidate(orderTrackProvider(orderId));
                  },
                )
              : null,
          children: [
            WarrantyCardFace(t: t),
            const TTitle('What\'s covered'),
            const TCard(
              child: Column(
                children: [
                  _Cover(
                    Icons.check_circle_rounded,
                    TX.green,
                    'Hardware faults that appear in normal use (battery, speaker, mic, cameras, charging, network)',
                  ),
                  _Cover(
                    Icons.check_circle_rounded,
                    TX.green,
                    'Free pickup & drop for approved claims',
                  ),
                  _Cover(
                    Icons.cancel_rounded,
                    TX.red,
                    'Physical or liquid damage, and repairs done outside GAMEX',
                    last: true,
                  ),
                ],
              ),
            ),
            if (t.claims.isNotEmpty) ...[
              const TTitle('Your claims'),
              for (final c in t.claims) ...[
                _ClaimCard(c: c),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover(this.icon, this.color, this.text, {this.last = false});
  final IconData icon;
  final Color color;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: TX.ink, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.c});
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final status = c['status'] as String;
    final color = switch (status) {
      'resolved' => TX.green,
      'rejected' => TX.red,
      'approved' => TX.blue,
      _ => TX.amber,
    };
    final events = (c['events'] as List? ?? const [])
        .cast<Map>()
        .reversed
        .toList();
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c['issue'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                    fontSize: 15,
                  ),
                ),
              ),
              TPill(_claimLabels[status] ?? status, color: color),
            ],
          ),
          if ((c['description'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c['description'] as String,
                style: const TextStyle(color: TX.muted),
              ),
            ),
          if ((c['note'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'GAMEX: ${c['note']}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 8),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 7, color: TX.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e['l'] as String,
                      style: const TextStyle(fontSize: 12.5, color: TX.ink),
                    ),
                  ),
                  Text(
                    DateFormat('d MMM, h:mm a')
                        .format(DateTime.parse(e['a'] as String)),
                    style: const TextStyle(fontSize: 11.5, color: TX.faint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClaimSheet extends ConsumerStatefulWidget {
  const _ClaimSheet({required this.t});
  final OrderTrack t;

  @override
  ConsumerState<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends ConsumerState<_ClaimSheet> {
  static const _issues = [
    (Icons.battery_alert_rounded, 'Battery'),
    (Icons.smartphone_rounded, 'Display / touch'),
    (Icons.volume_off_rounded, 'Speaker / mic'),
    (Icons.photo_camera_outlined, 'Camera'),
    (Icons.power_rounded, 'Charging'),
    (Icons.signal_cellular_off_rounded, 'Network / SIM'),
    (Icons.more_horiz_rounded, 'Other'),
  ];
  String? _issue;
  final _desc = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_issue == null) {
      return tSnack(context, 'Choose what is wrong', error: true);
    }
    if (_desc.text.trim().length < 10) {
      return tSnack(
        context,
        'Describe the problem in a few words',
        error: true,
      );
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(trustApiProvider)
          .claimWarranty(
            widget.t.id,
            issue: _issue!,
            description: _desc.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      tSnack(
        context,
        'Claim submitted. GAMEX will contact you within 24 hours.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        tSnack(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
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
            'Warranty claim',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: TX.ink,
            ),
          ),
          Text(
            '${widget.t.item} • IMEI ${widget.t.imei ?? ''}',
            style: const TextStyle(color: TX.muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'What\'s the problem?',
            style: TextStyle(fontWeight: FontWeight.w800, color: TX.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label) in _issues)
                ChoiceChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  selected: _issue == label,
                  onSelected: (_) => setState(() => _issue = label),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: tInput('When did it start? What happens?'),
          ),
          const SizedBox(height: 16),
          TButton(
            label: 'Submit claim',
            icon: Icons.send_rounded,
            busy: _busy,
            onTap: _submit,
          ),
        ],
      ),
    ),
  );
}
