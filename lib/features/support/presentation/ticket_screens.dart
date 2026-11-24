import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../orders/providers/orders_provider.dart';
import '../data/support_api.dart';
import 'chat_screen.dart';
import 'support_ui.dart';

const _categoryIcons = <String, IconData>{
  'Order & delivery': Icons.local_shipping_outlined,
  'Return & refund': Icons.assignment_return_outlined,
  'Payment': Icons.payments_outlined,
  'Warranty & repair': Icons.build_outlined,
  'Product quality': Icons.workspace_premium_outlined,
  'Sell / exchange': Icons.swap_horiz_rounded,
  'Account': Icons.person_outline_rounded,
  'Other': Icons.help_outline_rounded,
};

// ═══════════════════════════════ New ticket ═══════════════════════════════

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key, this.orderId});
  final String? orderId;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketState();
}

class _NewTicketState extends ConsumerState<NewTicketScreen> {
  String? _category;
  String? _order;
  final _subject = TextEditingController();
  final _text = TextEditingController();
  final _photos = <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.orderId;
    if (_order != null) _category = 'Order & delivery';
  }

  @override
  void dispose() {
    _subject.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 80,
        limit: 6 - _photos.length,
      );
      setState(() => _photos.addAll(files.take(6 - _photos.length).map((f) => f.path)));
    } catch (_) {}
  }

  Future<void> _submit() async {
    final cat = _category;
    if (cat == null) return showAppSnack(context, 'Choose what your issue is about');
    if (_text.text.trim().length < 10) {
      return showAppSnack(context, 'Please describe the problem in a few words');
    }
    setState(() => _busy = true);
    try {
      final t = await ref.read(supportApiProvider).createTicket(
        category: cat,
        subject: _subject.text.trim().isEmpty ? cat : _subject.text.trim(),
        text: _text.text.trim(),
        orderId: _order,
        photos: _photos,
      );
      ref.invalidate(myTicketsProvider);
      ref.invalidate(supportHomeProvider);
      if (!mounted) return;
      context.pushReplacement('/support/ticket/${t.id}');
      showAppSnack(context, 'Ticket ${t.id} created — we will reply soon');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not reach GAMEX. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(supportHomeProvider).asData?.value;
    final cats = home?.categories.isNotEmpty == true
        ? home!.categories
        : _categoryIcons.keys.toList();
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      backgroundColor: SX.bg,
      appBar: const SupportAppBar(
        title: 'Raise a ticket',
        subtitle: 'A support expert will reply in the app',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text('What is it about?', style: SX.h2),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.9,
            children: [
              for (final c in cats)
                Material(
                  color: _category == c ? SX.blue : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _category = c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcons[c] ?? Icons.help_outline_rounded,
                            size: 22,
                            color: _category == c ? Colors.white : SX.blue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: _category == c ? Colors.white : SX.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (orders.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text('Related order (optional)', style: SX.h2),
            const SizedBox(height: 10),
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final o in orders.take(10))
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        selected: _order == o.id,
                        onSelected: (v) =>
                            setState(() => _order = v ? o.id : null),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        label: SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                o.items.isEmpty
                                    ? o.id
                                    : o.items.first.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${o.id} • ${o.status.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text('Subject', style: SX.h2),
          const SizedBox(height: 10),
          TextField(
            controller: _subject,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16),
            decoration: _input('e.g. Refund not received for my return'),
          ),
          const SizedBox(height: 8),
          const Text('Describe the problem', style: SX.h2),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 10,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16),
            decoration: _input(
              'What happened? Include dates, amounts and what you have tried.',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Photos / screenshots', style: SX.h2)),
              Text('${_photos.length}/6', style: SX.small),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, p) in _photos.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: AppImage(p),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.close_rounded, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_photos.length < 6)
                  InkWell(
                    onTap: _addPhoto,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SX.line, width: 1.5),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: SX.blue),
                          SizedBox(height: 4),
                          Text('Add', style: SX.small),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: SX.blue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Never share your card number, CVV, OTP or password. GAMEX will never ask for them.',
                    style: SX.small,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Submit ticket'),
          ),
        ),
      ),
    );
  }
}

InputDecoration _input(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.all(16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: SX.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: SX.line),
  ),
);

// ═══════════════════════════════ Ticket list ═══════════════════════════════

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsState();
}

class _MyTicketsState extends ConsumerState<MyTicketsScreen> {
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myTicketsProvider);
    return Scaffold(
      backgroundColor: SX.bg,
      appBar: const SupportAppBar(title: 'My tickets'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New ticket'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(myTicketsProvider),
            child: const Text('Could not load tickets — retry'),
          ),
        ),
        data: (all) {
          final list = all.where((t) => t.isOpen != _closed).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myTicketsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('Active (${all.where((t) => t.isOpen).length})'),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Closed (${all.where((t) => !t.isOpen).length})'),
                    ),
                  ],
                  selected: {_closed},
                  onSelectionChanged: (s) => setState(() => _closed = s.first),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 56, color: SX.muted),
                        const SizedBox(height: 10),
                        Text(
                          _closed ? 'No closed tickets' : 'No active tickets',
                          style: SX.title,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Need help? Chat with us or raise a ticket.',
                          style: SX.small,
                        ),
                      ],
                    ),
                  ),
                for (final t in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TicketTile(ticket: t),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final last = t.lastMessage;
    return SCard(
      onTap: () => context.push('/support/ticket/${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _categoryIcons[t.category] ?? Icons.help_outline_rounded,
                color: SX.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${t.id} • ${t.category}',
                  style: SX.small.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              StatusPill(t.statusLabel, ticketColor(t.status)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SX.title,
                ),
              ),
              if (t.unread)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    color: SX.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 4),
            Text(
              '${last.from == 'agent' ? '${last.author ?? 'GAMEX'}: ' : last.mine ? 'You: ' : ''}${last.text}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SX.small,
            ),
          ],
          const SizedBox(height: 8),
          Text('Updated ${supportTime(t.updatedAt)}', style: SX.small.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════ Ticket detail ═══════════════════════════════

final _ticketProvider = FutureProvider.autoDispose.family<Ticket, String>(
  (ref, id) => ref.watch(supportApiProvider).ticket(id),
);

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TicketScreen> createState() => _TicketState();
}

class _TicketState extends ConsumerState<TicketScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _photos = <String>[];
  bool _busy = false;
  Timer? _poll;
  Ticket? _local;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => ref.invalidate(_ticketProvider(widget.id)),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty && _photos.isEmpty) return;
    setState(() => _busy = true);
    try {
      final t = await ref
          .read(supportApiProvider)
          .reply(widget.id, body, photos: [..._photos]);
      _text.clear();
      _photos.clear();
      setState(() => _local = t);
      ref.invalidate(myTicketsProvider);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not send. Check your internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(Ticket t) async {
    var stars = 5;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Was your issue solved?', style: SX.h2),
                const SizedBox(height: 6),
                const Text(
                  'Rate our support and close the ticket.',
                  style: SX.small,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        iconSize: 40,
                        onPressed: () => set(() => stars = i),
                        icon: Icon(
                          i <= stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFF5A623),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Close ticket'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final r = await ref.read(supportApiProvider).close(t.id, rating: stars);
      setState(() => _local = r);
      ref.invalidate(myTicketsProvider);
      if (mounted) showAppSnack(context, 'Thanks for your feedback!');
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not close the ticket');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_ticketProvider(widget.id));
    final t = async.asData?.value ?? _local;
    if (async.asData != null) _local = async.asData!.value;
    return Scaffold(
      backgroundColor: SX.bg,
      appBar: SupportAppBar(
        title: t?.subject ?? 'Ticket',
        subtitle: t == null ? widget.id : '${t.id} • ${t.category}',
        actions: [
          if (t != null && t.status != 'closed')
            TextButton(
              onPressed: () => _close(t),
              child: const Text('Close'),
            ),
        ],
      ),
      body: t == null
          ? Center(
              child: async.hasError
                  ? const Text('Ticket not found')
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                _statusBar(t),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    children: [
                      for (final m in t.messages.reversed) ChatBubble(message: m),
                    ],
                  ),
                ),
                if (t.status == 'closed')
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t.rating == null
                            ? 'This ticket is closed. Raise a new ticket if you need more help.'
                            : 'Closed • you rated us ${t.rating}★. Thank you!',
                        textAlign: TextAlign.center,
                        style: SX.small,
                      ),
                    ),
                  )
                else
                  Composer(
                    controller: _text,
                    busy: _busy,
                    hint: 'Write a reply…',
                    photos: _photos,
                    onPhotos: (ps) => setState(() => _photos.addAll(ps)),
                    onRemovePhoto: (i) => setState(() => _photos.removeAt(i)),
                    onSend: _send,
                  ),
              ],
            ),
    );
  }

  Widget _statusBar(Ticket t) {
    final color = ticketColor(t.status);
    final text = switch (t.status) {
      'open' =>
        t.slaDueAt.isAfter(DateTime.now())
            ? 'With our team • reply expected by ${supportTime(t.slaDueAt)}'
            : 'With our team • a reply is on the way',
      'awaiting_customer' => 'GAMEX replied • waiting for your answer',
      'resolved' => 'Marked resolved • reply if you still need help',
      _ => 'Closed',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          StatusPill(t.statusLabel, color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: SX.small.copyWith(color: SX.ink))),
          if (t.orderId != null)
            Text(t.orderId!, style: SX.small.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
