import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../data/support_api.dart';
import 'support_ui.dart';

const _topicIcons = <String, IconData>{
  'orders': Icons.local_shipping_outlined,
  'returns': Icons.assignment_return_outlined,
  'refunds': Icons.currency_rupee_rounded,
  'payments': Icons.payments_outlined,
  'warranty': Icons.verified_user_outlined,
  'quality': Icons.workspace_premium_outlined,
  'sell': Icons.swap_horiz_rounded,
  'repairs': Icons.build_outlined,
  'account': Icons.person_outline_rounded,
};

/// Help Center: search, topics, articles, live chat, tickets and contact.
class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterState();
}

class _HelpCenterState extends ConsumerState<HelpCenterScreen> {
  final _q = TextEditingController();
  String? _topic;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _need(String path) {
    if (ref.read(authProvider) == null) {
      context.push('/login?from=${Uri.encodeComponent(path)}');
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(supportHomeProvider);
    final user = ref.watch(authProvider);
    final q = _q.text.trim().toLowerCase();
    final h = home.asData?.value;
    return Scaffold(
      backgroundColor: SX.bg,
      appBar: const SupportAppBar(title: 'Help Center', subtitle: 'GAMEX Support • 24×7'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(supportHomeProvider);
          ref.invalidate(myTicketsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _hero(user?.name),
            const SizedBox(height: 18),
            if (q.isNotEmpty)
              ..._results(h, q)
            else ...[
              _contactRow(h),
              const SizedBox(height: 14),
              if (user != null) _ticketsCard(h),
              if (user != null) _recentOrders(),
              const SizedBox(height: 8),
              const Text('Browse by topic', style: SX.h2),
              const SizedBox(height: 12),
              if (h == null && home.isLoading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (h == null)
                SCard(
                  onTap: () => ref.invalidate(supportHomeProvider),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: SX.muted),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Could not load help articles. Tap to retry.',
                          style: SX.body,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _topics(h),
                const SizedBox(height: 22),
                Text(
                  _topic == null
                      ? 'Popular questions'
                      : h.topics
                            .firstWhere(
                              (t) => t.id == _topic,
                              orElse: () => h.topics.first,
                            )
                            .title,
                  style: SX.h2,
                ),
                const SizedBox(height: 12),
                for (final a in h.articles.where(
                  (a) => _topic == null || a.topic == _topic,
                ))
                  _Article(article: a),
              ],
              const SizedBox(height: 18),
              _stillNeedHelp(h),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero(String? name) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    decoration: BoxDecoration(
      gradient: SX.hero,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: SX.blue.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null ? 'Hi there 👋' : 'Hi ${name.split(' ').first} 👋',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'How can we help you today?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _q,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search: refund, return, warranty…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _q.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_q.clear),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _results(SupportHome? h, String q) {
    final words = q.split(RegExp(r'\s+'));
    final hits = [
      for (final a in h?.articles ?? const <HelpArticle>[])
        if (words.every(
          (w) => '${a.title} ${a.body} ${a.topic}'.toLowerCase().contains(w),
        ))
          a,
    ];
    return [
      Text(
        '${hits.length} result${hits.length == 1 ? '' : 's'} for "${_q.text.trim()}"',
        style: SX.small,
      ),
      const SizedBox(height: 10),
      for (final a in hits) _Article(article: a, open: true),
      if (hits.isEmpty) ...[
        const SizedBox(height: 10),
        SCard(
          child: Column(
            children: [
              const Icon(Icons.support_agent_rounded, size: 44, color: SX.blue),
              const SizedBox(height: 8),
              const Text('No article matches that', style: SX.title),
              const SizedBox(height: 4),
              const Text(
                'Ask the GAMEX Assistant — it can see your orders and answers instantly.',
                textAlign: TextAlign.center,
                style: SX.small,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _need('/support/chat'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat with us'),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _contactRow(SupportHome? h) {
    final online = h?.agentsOnline ?? false;
    return Column(
      children: [
        SCard(
          onTap: () => _need('/support/chat'),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: SX.hero,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chat with GAMEX Assistant', style: SX.title),
                    const SizedBox(height: 3),
                    const Text(
                      'Instant answers about your orders • 24×7',
                      style: SX.small,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: online ? SX.green : SX.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          online
                              ? 'Human agents online'
                              : 'Agents back at 9 AM',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: online ? SX.green : SX.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: SX.muted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Action(
                icon: Icons.confirmation_number_outlined,
                color: SX.violet,
                title: 'Raise a ticket',
                text: 'We reply within 24h',
                onTap: () => _need('/support/new'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Action(
                icon: Icons.call_outlined,
                color: SX.green,
                title: 'Call us',
                text: h?.hours ?? '9 AM – 9 PM',
                onTap: h == null || h.phone.isEmpty
                    ? null
                    : () => launchUrl(
                        Uri.parse('tel:${h.phone.replaceAll(' ', '')}'),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ticketsCard(SupportHome? h) {
    final tickets = ref.watch(myTicketsProvider).asData?.value ?? const [];
    if (tickets.isEmpty) return const SizedBox.shrink();
    final open = tickets.where((t) => t.isOpen).length;
    final unread = tickets.where((t) => t.unread).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SCard(
        onTap: () => context.push('/support/tickets'),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: SX.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                color: SX.violet,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My tickets', style: SX.title),
                  Text(
                    '$open open • ${tickets.length} total',
                    style: SX.small,
                  ),
                ],
              ),
            ),
            if (unread > 0) StatusPill('$unread new reply', SX.red),
            const Icon(Icons.chevron_right_rounded, color: SX.muted),
          ],
        ),
      ),
    );
  }

  Widget _recentOrders() {
    final orders = ref.watch(ordersProvider).take(2).toList();
    if (orders.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help with a recent order', style: SX.title),
            const SizedBox(height: 10),
            for (final o in orders)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(
                  '/support/new?order=${Uri.encodeComponent(o.id)}',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: SX.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.items.isEmpty
                                  ? o.id
                                  : o.items.first.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: SX.ink,
                              ),
                            ),
                            Text(
                              '${o.id} • ${o.status.label} • ${formatPrice(o.total)}',
                              style: SX.small,
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Get help',
                        style: TextStyle(
                          color: SX.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topics(SupportHome h) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.05,
    children: [
      for (final t in h.topics)
        Material(
          color: _topic == t.id ? SX.blue : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () =>
                setState(() => _topic = _topic == t.id ? null : t.id),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _topicIcons[t.id] ?? Icons.help_outline_rounded,
                    size: 28,
                    color: _topic == t.id ? Colors.white : SX.blue,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: _topic == t.id ? Colors.white : SX.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _stillNeedHelp(SupportHome? h) => SCard(
    color: const Color(0xFFEAF0FF),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Still need help?', style: SX.h2),
        const SizedBox(height: 4),
        Text(
          'Write to ${h?.email ?? 'support@gamex.in'} or call ${h?.phone ?? ''} (${h?.hours ?? '9 AM – 9 PM'}).',
          style: SX.small,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _need('/support/chat'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: h == null || h.email.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse('mailto:${h.email}')),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Email'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 12),
        Text(title, style: SX.title),
        const SizedBox(height: 2),
        Text(text, style: SX.small, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _Article extends StatefulWidget {
  const _Article({required this.article, this.open = false});
  final HelpArticle article;
  final bool open;

  @override
  State<_Article> createState() => _ArticleState();
}

class _ArticleState extends State<_Article> {
  late bool _open = widget.open;
  bool? _helpful;

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SCard(
        padding: EdgeInsets.zero,
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(a.title, style: SX.title)),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: SX.muted,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10, right: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.body, style: SX.body.copyWith(color: SX.muted)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  _helpful == null
                                      ? 'Was this helpful?'
                                      : 'Thanks for the feedback!',
                                  style: SX.small,
                                ),
                                const Spacer(),
                                if (_helpful == null) ...[
                                  IconButton(
                                    onPressed: () =>
                                        setState(() => _helpful = true),
                                    icon: const Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _helpful = false);
                                      context.push('/support/chat');
                                    },
                                    icon: const Icon(
                                      Icons.thumb_down_alt_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
