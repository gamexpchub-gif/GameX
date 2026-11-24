import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../data/support_api.dart';
import 'support_ui.dart';

/// Live chat: the GAMEX Assistant (AI) answers instantly and hands over to
/// a human agent when needed; agent replies arrive here and as notifications.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _ChatState();
}

class _ChatState extends ConsumerState<SupportChatScreen> {
  final _text = TextEditingController();
  SupportChat? _chat;
  String? _pending; // customer message waiting for the assistant
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  SupportApi get _api => ref.read(supportApiProvider);

  @override
  void initState() {
    super.initState();
    _start();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final c = await _api.startChat();
      if (mounted) setState(() => _chat = c);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not connect to GAMEX support.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// While a human is involved, check for agent replies.
  Future<void> _refresh() async {
    final c = _chat;
    if (c == null || _sending || c.mode == 'ai' || c.mode == 'closed') return;
    try {
      final n = await _api.chat();
      if (n != null && mounted && n.messages.length != c.messages.length) {
        HapticFeedback.lightImpact();
        setState(() => _chat = n);
      }
    } catch (_) {}
  }

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    if (preset == null) _text.clear();
    if (body.toLowerCase() == 'talk to an agent') return _agent();
    setState(() {
      _sending = true;
      _pending = body;
    });
    try {
      final c = await _api.send(body);
      if (mounted) setState(() => _chat = c);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Message not sent. Check your internet.');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pending = null;
        });
      }
    }
  }

  Future<void> _agent() async {
    setState(() => _sending = true);
    try {
      final c = await _api.askAgent();
      if (mounted) setState(() => _chat = c);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not reach an agent. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _end() async {
    var stars = 0;
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
                const Text('End this chat?', style: SX.h2),
                const SizedBox(height: 6),
                const Text('How was your support experience?', style: SX.small),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('End chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.endChat(rating: stars == 0 ? null : stars);
    } catch (_) {}
    ref.invalidate(supportHomeProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _chat;
    final mode = c?.mode ?? 'ai';
    final (title, sub, dot) = switch (mode) {
      'agent' => (c?.agent ?? 'GAMEX Support', 'Support agent • online', SX.green),
      'waiting' => (
        'Connecting to an agent',
        c?.agentsOnline == true
            ? 'Usually under 3 minutes'
            : 'Agents back at 9 AM • ticket ${c?.ticketId ?? ''}',
        SX.amber,
      ),
      'closed' => ('Chat ended', 'Start a new chat any time', SX.muted),
      _ => ('GAMEX Assistant', 'AI assistant • replies instantly', SX.green),
    };
    final last = c?.messages.isEmpty ?? true ? null : c!.messages.last;
    final suggestions = !_sending && last != null && last.from == 'ai'
        ? last.suggestions
        : const <String>[];
    return Scaffold(
      backgroundColor: SX.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 66,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: mode == 'agent' ? SX.violet : SX.blue,
                  child: Icon(
                    mode == 'agent'
                        ? Icons.support_agent_rounded
                        : Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SX.title.copyWith(fontSize: 17)),
                  Text(sub, style: SX.small.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'agent' => _agent(),
              'ticket' => context.push('/support/ticket/${c!.ticketId}'),
              'end' => _end(),
              _ => null,
            },
            itemBuilder: (_) => [
              if (mode == 'ai')
                const PopupMenuItem(value: 'agent', child: Text('Talk to an agent')),
              if (c?.ticketId != null)
                const PopupMenuItem(value: 'ticket', child: Text('View ticket')),
              if (c != null && mode != 'closed')
                const PopupMenuItem(value: 'end', child: Text('End chat')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: SX.muted),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center, style: SX.body),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _start();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    children: [
                      if (_sending && _pending != null) ...[
                        if (mode == 'ai') const _Typing(),
                        ChatBubble(
                          message: SupportMessage({
                            'from': 'customer',
                            'text': _pending,
                            'at': DateTime.now().toIso8601String(),
                          }),
                          sending: true,
                        ),
                      ],
                      for (final m in (c?.messages ?? const <SupportMessage>[]).reversed)
                        ChatBubble(message: m),
                      const _Intro(),
                    ],
                  ),
                ),
                if (suggestions.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final s in suggestions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 6),
                            child: ActionChip(
                              label: Text(
                                s,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: SX.blue,
                                ),
                              ),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFC9D6FF)),
                              shape: const StadiumBorder(),
                              onPressed: () => _send(s),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (mode == 'closed')
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () {
                          setState(() => _loading = true);
                          _start();
                        },
                        child: const Text('Start a new chat'),
                      ),
                    ),
                  )
                else
                  Composer(
                    controller: _text,
                    busy: _sending,
                    hint: mode == 'ai'
                        ? 'Ask about orders, refunds, warranty…'
                        : 'Message GAMEX Support…',
                    onSend: _send,
                  ),
              ],
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: SX.hero,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 10),
        const Text('GAMEX Support', style: SX.h2),
        const SizedBox(height: 4),
        const Text(
          'Our AI assistant sees your orders and answers instantly. Ask for an agent any time.',
          textAlign: TextAlign.center,
          style: SX.small,
        ),
      ],
    ),
  );
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: SX.blue.withValues(
                    alpha: 0.3 + 0.7 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// One message in a ticket or chat thread.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.sending = false});
  final SupportMessage message;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.from == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: Text(
          m.text,
          textAlign: TextAlign.center,
          style: SX.small.copyWith(fontSize: 12.5),
        ),
      );
    }
    final mine = m.mine;
    final who = switch (m.from) {
      'ai' => 'GAMEX Assistant',
      'agent' => m.author ?? 'GAMEX Support',
      _ => null,
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(colors: [SX.blue, SX.violet])
                : null,
            color: mine ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            boxShadow: mine
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF1E2A5A).withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (who != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m.from == 'ai'
                            ? Icons.auto_awesome_rounded
                            : Icons.support_agent_rounded,
                        size: 14,
                        color: m.from == 'ai' ? SX.blue : SX.violet,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        who,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: m.from == 'ai' ? SX.blue : SX.violet,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final p in m.photos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 200,
                      height: 150,
                      child: AppImage(
                        p.startsWith('/')
                            ? ProviderScope.containerOf(context)
                                  .read(apiProvider)
                                  .media(p)
                            : p,
                      ),
                    ),
                  ),
                ),
              if (m.text.isNotEmpty)
                Text(
                  m.text,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.4,
                    color: mine ? Colors.white : SX.ink,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                sending ? 'Sending…' : supportTime(m.at),
                style: TextStyle(
                  fontSize: 11,
                  color: mine ? Colors.white70 : SX.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message box with optional photo attachments.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.busy,
    required this.hint,
    this.photos,
    this.onPhotos,
    this.onRemovePhoto,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool busy;
  final String hint;
  final List<String>? photos;
  final ValueChanged<List<String>>? onPhotos;
  final ValueChanged<int>? onRemovePhoto;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: SX.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photos?.isNotEmpty == true)
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (i, p) in photos!.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 6),
                        child: GestureDetector(
                          onTap: () => onRemovePhoto?.call(i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: AppImage(p),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onPhotos != null)
                  IconButton(
                    onPressed: () async {
                      try {
                        final f = await ImagePicker().pickMultiImage(
                          maxWidth: 1600,
                          imageQuality: 80,
                          limit: 4,
                        );
                        onPhotos!([for (final x in f.take(4)) x.path]);
                      } catch (_) {}
                    },
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: SX.muted,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: hint,
                      filled: true,
                      fillColor: SX.bg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    onPressed: busy ? null : onSend,
                    icon: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
