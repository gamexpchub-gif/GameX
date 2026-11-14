import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../providers/orders_provider.dart';

const _blue = Color(0xFF1F5BFF);

/// Opens the AI order assistant chat, optionally with a first question.
void showOrderAssistant(BuildContext context, {String? question}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (_, scroll) => _AssistantChat(scroll: scroll, initial: question),
    ),
  );
}

class _Msg {
  const _Msg(this.text, {required this.mine});
  final String text;
  final bool mine;
}

class _AssistantChat extends ConsumerStatefulWidget {
  const _AssistantChat({required this.scroll, this.initial});
  final ScrollController scroll;
  final String? initial;

  @override
  ConsumerState<_AssistantChat> createState() => _AssistantChatState();
}

class _AssistantChatState extends ConsumerState<_AssistantChat> {
  final _c = TextEditingController();
  final _msgs = <_Msg>[
    const _Msg(
      'Hi! I\'m your GAMEX order assistant 🤖\nAsk me where your order is, when it will arrive, or how to return it.',
      mine: false,
    ),
  ];
  bool _typing = false;

  static const _suggestions = [
    'Where is my order?',
    'When will it arrive?',
    'How do I return?',
    'Cancel my order',
  ];

  @override
  void initState() {
    super.initState();
    final q = widget.initial?.trim();
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _answer(String q) {
    final orders = ref.read(ordersProvider);
    final t = q.toLowerCase();
    final fmt = DateFormat('EEE, d MMM');
    final active = orders.where((o) => o.isProcessing || o.isShipped).toList();
    String line(Order o) {
      final name = o.items.first.product.name;
      if (o.isShipped) {
        return '• $name (#${o.id}) is in transit, arriving ${fmt.format(o.expectedDelivery)}.';
      }
      if (o.isProcessing) {
        return '• $name (#${o.id}) is being processed and will ship within 24 hours.';
      }
      if (o.isDelivered) {
        return '• $name (#${o.id}) was delivered on ${fmt.format(o.deliveredAt)}.';
      }
      return '• $name (#${o.id}) was returned and refunded.';
    }

    if (orders.isEmpty) {
      return 'You have no orders yet. Browse certified phones and I\'ll track them for you!';
    }
    if (t.contains('cancel')) {
      return active.isEmpty
          ? 'You have no orders that can be cancelled right now.'
          : 'Orders can be cancelled free of charge before they ship. Open the order and tap "Need help with this order?" — our team will cancel it within an hour.';
    }
    if (t.contains('return') ||
        t.contains('refund') ||
        t.contains('exchange')) {
      return 'Every GAMEX phone has a 7-day easy return. Open a delivered order, tap "Need help", and we\'ll schedule a free pickup. Refunds reach your original payment method in 3–5 working days.';
    }
    if (t.contains('pay') || t.contains('emi') || t.contains('upi')) {
      return 'We accept UPI, cards, wallets, Cash on Delivery and no-cost EMI on cards. Payments are 256-bit encrypted.';
    }
    if (t.contains('warranty')) {
      return 'GAMEX Certified phones include a 6-month warranty covering hardware and battery defects. Raise a claim from Account → Warranty Claim.';
    }
    if (t.contains('when') || t.contains('arrive') || t.contains('deliver')) {
      if (active.isEmpty) {
        return 'All your orders have been delivered 🎉\n${orders.take(3).map(line).join('\n')}';
      }
      return active.map(line).join('\n');
    }
    // Default: status of recent orders.
    final recent = (active.isNotEmpty ? active : orders)
        .take(3)
        .map(line)
        .join('\n');
    return 'Here\'s the latest on your orders:\n$recent\n\nTotal spent: ${formatPrice(orders.fold(0.0, (s, o) => s + o.total))}';
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    _c.clear();
    setState(() {
      _msgs.add(_Msg(q, mine: true));
      _typing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _msgs.add(_Msg(_answer(q), mine: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: _blue),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Order Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: Color(0xFF22C55E),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final m in _msgs) _Bubble(msg: m),
                if (_typing) const _Bubble(msg: _Msg('Typing…', mine: false)),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(s),
                      onPressed: () => _send(s),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _c,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ask about your order…',
                  suffixIcon: IconButton(
                    onPressed: () => _send(_c.text),
                    icon: const Icon(Icons.send_rounded, color: _blue),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: msg.mine
              ? const LinearGradient(
                  colors: [Color(0xFF1F66FF), Color(0xFF6A3DF5)],
                )
              : null,
          color: msg.mine ? null : const Color(0xFFF0F3FB),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.mine ? 18 : 4),
            bottomRight: Radius.circular(msg.mine ? 4 : 18),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.mine ? Colors.white : const Color(0xFF0B1230),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
