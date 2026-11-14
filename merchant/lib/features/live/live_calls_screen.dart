import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

/// Buyers who asked to see a phone live on video before buying.
class LiveCallsScreen extends ConsumerWidget {
  const LiveCallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(liveProvider);
    List<LiveCall> of(Set<LiveStage> s) =>
        calls.where((c) => s.contains(c.stage)).toList()
          ..sort((a, b) => a.slot.compareTo(b.slot));
    final done = calls.where((c) => c.stage == LiveStage.done).toList();
    final conv = done.isEmpty
        ? 0
        : (done.where((c) => c.converted == true).length * 100 / done.length)
              .round();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live Reviews'),
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
              Tab(text: 'Requests (${of({LiveStage.pending}).length})'),
              Tab(text: 'Upcoming (${of({LiveStage.confirmed}).length})'),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: C.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Buyers who see a phone live are 3× more likely to buy.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$conv%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'converted',
                        style: TextStyle(
                          color: Color(0xFFB9C2FF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _List(calls: of({LiveStage.pending})),
                  _List(calls: of({LiveStage.confirmed})),
                  _List(
                    calls: of({LiveStage.done, LiveStage.declined}).reversed
                        .toList(),
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
  const _List({required this.calls});
  final List<LiveCall> calls;

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) {
      return ListView(
        children: const [
          EmptyView(
            icon: Icons.videocam_off_rounded,
            title: 'Nothing here',
            text: 'Live review requests from buyers will appear here.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: calls.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CallCard(call: calls[i]),
    );
  }
}

class _CallCard extends ConsumerWidget {
  const _CallCard({required this.call});
  final LiveCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = call;
    final n = ref.read(liveProvider.notifier);
    final color = switch (c.stage) {
      LiveStage.pending => C.amber,
      LiveStage.confirmed => C.primary,
      LiveStage.done => c.converted == true ? C.green : C.muted,
      LiveStage.declined => C.red,
    };
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Photo(c.photo, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.item,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${c.buyer} • ${c.language}',
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Pill(
                c.stage == LiveStage.done
                    ? (c.converted == true ? 'Bought' : 'No sale')
                    : c.stage.label,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                c.mode == 'Visit Store'
                    ? Icons.storefront_rounded
                    : c.mode == 'WhatsApp Video'
                    ? Icons.chat_rounded
                    : Icons.videocam_rounded,
                c.mode,
              ),
              const SizedBox(width: 8),
              _Chip(Icons.event_rounded, dateTime(c.slot)),
            ],
          ),
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '“${c.notes}”',
              style: const TextStyle(
                color: C.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (c.stage == LiveStage.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => n.patch(
                      c.id,
                      (x) => x.copyWith(stage: LiveStage.declined),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.red,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () {
                      n.patch(
                        c.id,
                        (x) => x.copyWith(stage: LiveStage.confirmed),
                      );
                      snack(context, 'Slot confirmed — buyer notified');
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirm slot'),
                  ),
                ),
              ],
            ),
          ],
          if (c.stage == LiveStage.confirmed) ...[
            const SizedBox(height: 12),
            GradientButton(
              label: 'Start live video',
              icon: Icons.videocam_rounded,
              gradient: const LinearGradient(
                colors: [C.red, Color(0xFFEC4899)],
              ),
              onPressed: () async {
                final bought = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => _CallRoom(call: c),
                  ),
                );
                if (bought == null) return;
                n.patch(
                  c.id,
                  (x) => x.copyWith(stage: LiveStage.done, converted: bought),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: C.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simulated live video room with the inspection checklist.
class _CallRoom extends StatefulWidget {
  const _CallRoom({required this.call});
  final LiveCall call;

  @override
  State<_CallRoom> createState() => _CallRoomState();
}

class _CallRoomState extends State<_CallRoom> {
  late final Timer _t;
  int _secs = 0;
  bool _mic = true;
  final _done = <String>{};
  static const _show = [
    'IMEI on *#06#',
    'Battery health',
    'Screen – white & black',
    'All four sides',
    'Cameras',
    'Speakers & mic',
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _secs++),
    );
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  Future<void> _end() async {
    final bought = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How did it go?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Buyer is purchasing',
                icon: Icons.shopping_bag_rounded,
                onPressed: () => Navigator.pop(c, true),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('No purchase'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (bought != null && mounted) Navigator.pop(context, bought);
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_secs ~/ 60).toString().padLeft(2, '0');
    final ss = (_secs % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: const Color(0xFF05060F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: C.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '● LIVE  $mm:$ss',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'with ${widget.call.buyer}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: C.nightGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Photo(
                        widget.call.photo,
                        size: 220,
                        radius: 24,
                        pad: 16,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 84,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.call.buyer.split(' ').map((w) => w[0]).join(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _show)
                    FilterChip(
                      label: Text(s),
                      selected: _done.contains(s),
                      onSelected: (v) =>
                          setState(() => v ? _done.add(s) : _done.remove(s)),
                      backgroundColor: Colors.white10,
                      selectedColor: C.green.withValues(alpha: 0.3),
                      checkmarkColor: Colors.white,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                      ),
                      side: const BorderSide(color: Colors.white24),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundBtn(
                    icon: _mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                    onTap: () => setState(() => _mic = !_mic),
                  ),
                  _RoundBtn(icon: Icons.cameraswitch_rounded, onTap: () {}),
                  _RoundBtn(
                    icon: Icons.call_end_rounded,
                    color: C.red,
                    onTap: _end,
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

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white12,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 62,
          height: 62,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
