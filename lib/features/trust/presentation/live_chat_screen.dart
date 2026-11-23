import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_image.dart';
import '../data/trust_api.dart';
import 'widgets/trust_ui.dart';

/// Chat with the seller about a live review request.
class LiveChatScreen extends ConsumerStatefulWidget {
  const LiveChatScreen({super.key, required this.liveId});
  final String liveId;

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen> {
  final _text = TextEditingController();
  ChatThread? _thread;
  String? _error;
  bool _sending = false;
  Timer? _poll;

  static const _quick = [
    'Can you show the IMEI (*#06#)?',
    'Please show battery health',
    'Any scratches on the back?',
    'Is the bill available?',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(trustApiProvider).chat(widget.liveId);
      if (mounted) {
        setState(() {
          _thread = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _thread == null) setState(() => _error = e.toString());
    }
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? _text.text).trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final th = await ref.read(trustApiProvider).sendChat(widget.liveId, t);
      if (!mounted) return;
      _text.clear();
      setState(() => _thread = th);
    } catch (e) {
      if (mounted) tSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = _thread;
    final api = ref.read(trustApiProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 10,
              16,
              14,
            ),
            decoration: const BoxDecoration(
              gradient: TX.night,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (th != null)
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppImage(api.image(th.photo), fit: BoxFit.contain),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        th?.sellerName ?? 'Seller',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        th?.item ?? 'Live review',
                        style: const TextStyle(
                          color: Color(0xFFC9D2FF),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const TPill(
                  'LIVE REVIEW',
                  color: Color(0xFFFB7185),
                  icon: Icons.videocam_rounded,
                ),
              ],
            ),
          ),
          Expanded(
            child: th == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text(
                            _error!,
                            style: const TextStyle(color: TX.muted),
                          ),
                  )
                : th.messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 30),
                      const Icon(
                        Icons.forum_outlined,
                        size: 54,
                        color: TX.faint,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ask the seller anything before the live call',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TX.ink,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your phone number stays private.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: TX.muted),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in _quick)
                            ActionChip(
                              label: Text(q),
                              onPressed: () => _send(q),
                            ),
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    itemCount: th.messages.length,
                    itemBuilder: (_, i) {
                      final m = th.messages[th.messages.length - 1 - i];
                      return Align(
                        alignment: m.mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.74,
                          ),
                          decoration: BoxDecoration(
                            gradient: m.mine ? TX.chip : null,
                            color: m.mine ? null : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(m.mine ? 18 : 4),
                              bottomRight: Radius.circular(m.mine ? 4 : 18),
                            ),
                            boxShadow: TX.soft(0.06),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                m.text,
                                style: TextStyle(
                                  color: m.mine ? Colors.white : TX.ink,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('h:mm a').format(m.at),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: m.mine ? Colors.white70 : TX.faint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              10 + MediaQuery.paddingOf(context).bottom,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: tInput('Message the seller…'),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      gradient: TX.chip,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
