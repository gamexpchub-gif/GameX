import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../providers/live_review_provider.dart';

const _ink = Color(0xFF0B1230);
const _muted = Color(0xFF5B6380);
const _red = Color(0xFFE5283B);
const _blue = Color(0xFF1F5BFF);

/// "See this exact phone live": book a video inspection of a listing.
class LiveReviewScreen extends ConsumerWidget {
  const LiveReviewScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(productByIdProvider(productId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorRetry(
              onRetry: () => ref.invalidate(productByIdProvider(productId)),
            ),
          ),
          data: (p) => p == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Listing not found',
                    message: 'This phone may have been sold.',
                  ),
                )
              : _LiveReviewPage(product: p),
        );
  }
}

class _LiveReviewPage extends ConsumerStatefulWidget {
  const _LiveReviewPage({required this.product});
  final Product product;

  @override
  ConsumerState<_LiveReviewPage> createState() => _LiveReviewPageState();
}

class _LiveReviewPageState extends ConsumerState<_LiveReviewPage> {
  LiveMode _mode = LiveMode.video;
  int _day = 0;
  int? _slot;
  String _language = 'English';
  bool _sending = false;
  late final _phone = TextEditingController(
    text: ref.read(authProvider)?.phone ?? '',
  );
  final _notes = TextEditingController();

  static const _hours = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];

  Product get p => widget.product;

  DateTime _date(int day) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(Duration(days: day));
  }

  bool _slotAvailable(int hour) {
    final slot = _date(_day).add(Duration(hours: hour));
    if (slot.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      return false;
    }
    // Demo: a couple of slots are already booked.
    return (hour + _day) % 5 != 0;
  }

  @override
  void dispose() {
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_slot == null) return showAppSnack(context, 'Please pick a time slot');
    final phoneErr = Validators.phone(_phone.text);
    if (phoneErr != null) return showAppSnack(context, phoneErr);
    setState(() => _sending = true);
    final req = await ref
        .read(liveRequestsProvider.notifier)
        .request(
          LiveRequest(
            id: 'LV${DateTime.now().millisecondsSinceEpoch % 1000000}',
            productId: p.id,
            productName: p.name,
            image: p.images.first,
            mode: _mode,
            slot: _date(_day).add(Duration(hours: _slot!)),
            phone: _phone.text.trim(),
            language: _language,
            notes: _notes.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _slot = null;
    });
    HapticFeedback.heavyImpact();
    _showConfirmed(req);
  }

  void _showConfirmed(LiveRequest r) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  size: 48,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Live View scheduled!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${r.mode.label} • ${DateFormat('EEEE, d MMM • h:mm a').format(r.slot)}\nWe\'ll call ${r.phone} at the scheduled time. Request ID ${r.id}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref
        .watch(liveRequestsProvider)
        .where((r) => r.productId == p.id)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F4FD),
        title: const Text('Live Review'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.white),
                SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AuroraBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _howItWorks(),
            const SizedBox(height: 14),
            _modeCard(),
            const SizedBox(height: 14),
            _scheduleCard(),
            const SizedBox(height: 14),
            _contactCard(),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: 14),
              _myRequests(requests),
            ],
          ],
        ),
      ),
      bottomNavigationBar: StickyBottomBar(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _slot == null
                        ? 'Pick a time slot'
                        : DateFormat('EEE d MMM • h:mm a')
                              .format(_date(_day).add(Duration(hours: _slot!))),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${_mode.label} • Free',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.videocam_rounded),
              label: const Text('Request Live View'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final grade = (p.condition ?? 'Excellent').replaceAll(' Condition', '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1033), Color(0xFF2A1466), Color(0xFF5B1E8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: AppImage(
              p.images.first,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.memoryLabel ?? ''} • $grade',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  formatPrice(p.price),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'See the exact unit you\'ll receive — not a stock photo.',
                  style: TextStyle(color: Color(0xFFB9C7FF), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _howItWorks() {
    const steps = [
      (Icons.event_rounded, 'Book a slot', 'Pick a time that suits you'),
      (
        Icons.videocam_rounded,
        'Expert calls you',
        'HD video with a GAMEX specialist',
      ),
      (
        Icons.fact_check_rounded,
        'Inspect live',
        'IMEI, battery, screen, body & camera',
      ),
      (
        Icons.shopping_bag_rounded,
        'Decide',
        'Buy with full confidence — or don\'t',
      ),
    ];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.auto_awesome_rounded,
            title: 'How Live Review works',
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _blue.withValues(alpha: 0.1),
                      child: Icon(steps[i].$1, size: 18, color: _blue),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 22,
                        color: const Color(0xFFDCE3F4),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          steps[i].$3,
                          style: const TextStyle(fontSize: 12.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _modeCard() {
    const icons = {
      LiveMode.video: Icons.videocam_rounded,
      LiveMode.whatsapp: Icons.chat_rounded,
      LiveMode.store: Icons.storefront_rounded,
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.connected_tv_rounded,
            title: 'How would you like to see it?',
          ),
          const SizedBox(height: 12),
          for (final m in LiveMode.values) ...[
            GestureDetector(
              onTap: () => setState(() => _mode = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _mode == m
                      ? _blue.withValues(alpha: 0.06)
                      : Colors.white,
                  border: Border.all(
                    color: _mode == m ? _blue : const Color(0xFFE3E8F5),
                    width: _mode == m ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icons[m], color: _mode == m ? _blue : _muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            m.description,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _mode == m
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: _mode == m ? _blue : _muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _scheduleCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.event_rounded,
            title: 'Choose date & time',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final dt = _date(i);
                final sel = i == _day;
                return GestureDetector(
                  onTap: () => setState(() {
                    _day = i;
                    _slot = null;
                  }),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: sel
                          ? const LinearGradient(
                              colors: [Color(0xFF1F66FF), Color(0xFF6A3DF5)],
                            )
                          : null,
                      color: sel ? null : Colors.white,
                      border: Border.all(
                        color: sel
                            ? Colors.transparent
                            : const Color(0xFFE3E8F5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          i == 0
                              ? 'Today'
                              : i == 1
                              ? 'Tmrw'
                              : DateFormat('EEE').format(dt),
                          style: TextStyle(
                            fontSize: 12,
                            color: sel ? Colors.white70 : _muted,
                          ),
                        ),
                        Text(
                          '${dt.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : _ink,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(dt),
                          style: TextStyle(
                            fontSize: 11,
                            color: sel ? Colors.white70 : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _hours)
                Builder(
                  builder: (_) {
                    final ok = _slotAvailable(h);
                    final sel = _slot == h;
                    return GestureDetector(
                      onTap: ok ? () => setState(() => _slot = h) : null,
                      child: Container(
                        width: 84,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: sel
                              ? _blue
                              : ok
                              ? Colors.white
                              : const Color(0xFFF1F3F8),
                          border: Border.all(
                            color: sel ? _blue : const Color(0xFFE3E8F5),
                          ),
                        ),
                        child: Text(
                          DateFormat('h:mm a').format(DateTime(2000, 1, 1, h)),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: sel
                                ? Colors.white
                                : ok
                                ? _ink
                                : const Color(0xFFB0B7C9),
                            decoration: ok ? null : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Each Live Review takes about 10 minutes.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _contactCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.person_pin_rounded,
            title: 'Your details',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '98765 43210',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Language',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              for (final l in const ['English', 'Hindi'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l),
                    selected: _language == l,
                    onSelected: (_) => setState(() => _language = l),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Anything specific to check? (optional)',
              hintText: 'e.g. camera focus, speaker, back glass',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _myRequests(List<LiveRequest> list) {
    Color c(LiveStatus s) => switch (s) {
      LiveStatus.requested => const Color(0xFFF08A00),
      LiveStatus.scheduled => const Color(0xFF16A34A),
      LiveStatus.completed => _blue,
      LiveStatus.cancelled => _red,
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.history_rounded,
            title: 'My Live Review requests',
          ),
          for (final r in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: c(r.status).withValues(alpha: 0.12),
                child: Icon(Icons.videocam_rounded, color: c(r.status)),
              ),
              title: Text(
                '${r.mode.label} • ${DateFormat('d MMM, h:mm a').format(r.slot)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${r.status.label} • ID ${r.id}'),
              trailing: r.productId.startsWith('GXL')
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Chat with seller',
                          onPressed: () => context.push('/live-chat/${r.id}'),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: _blue,
                          ),
                        ),
                        if (r.active)
                          IconButton(
                            tooltip: 'Cancel',
                            onPressed: () => ref
                                .read(liveRequestsProvider.notifier)
                                .cancel(r.id),
                            icon: const Icon(Icons.close_rounded, color: _red),
                          ),
                      ],
                    )
                  : r.active
                  ? TextButton(
                      onPressed: () =>
                          ref.read(liveRequestsProvider.notifier).cancel(r.id),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _red),
                      ),
                    )
                  : null,
            ),
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to product'),
          ),
        ],
      ),
    );
  }
}
