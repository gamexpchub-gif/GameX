import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sellerProvider);
    if (s == null) return const SizedBox.shrink();
    final orders = ref.watch(ordersProvider);
    final closed = orders.where((o) => !o.stage.open).length;
    final cancelled = orders
        .where(
          (o) => o.events.any((e) => e.label.startsWith('Rejected by seller')),
        )
        .length;
    final cancelRate = closed == 0 ? 0.0 : cancelled * 100 / closed;

    return Scaffold(
      appBar: AppBar(title: const Text('My Store')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: C.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    s.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.storeName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: C.primary,
                            size: 18,
                          ),
                        ],
                      ),
                      Text(
                        '${s.ownerName} • ${s.city}',
                        style: const TextStyle(color: C.muted),
                      ),
                      Text(
                        s.phone,
                        style: const TextStyle(color: C.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _edit(context, ref, s),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SectionTitle('Performance'),
          Row(
            children: [
              _Score(
                label: 'Rating',
                value: s.rating.toStringAsFixed(1),
                good: true,
                icon: Icons.star_rounded,
              ),
              const SizedBox(width: 10),
              const _Score(
                label: 'On-time dispatch',
                value: '98%',
                good: true,
                icon: Icons.bolt_rounded,
              ),
              const SizedBox(width: 10),
              _Score(
                label: 'Seller cancels',
                value: '${cancelRate.toStringAsFixed(1)}%',
                good: cancelRate < 5,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4DB), Color(0xFFFFE7B3)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFB7791F),
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gold Seller',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7A4B00),
                        ),
                      ),
                      Text(
                        'Keep rating ≥ 4.7 for lower 6% commission next month.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF7A4B00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Verification'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _Check('Mobile number', 'Verified with OTP', true),
                const _Check('PAN & Aadhaar (KYC)', 'Verified', true),
                _Check('Bank account', s.bank, true),
                _Check(
                  'GSTIN',
                  s.gstin.isEmpty ? 'Add to sell above ₹40L/year' : s.gstin,
                  s.gstin.isNotEmpty,
                ),
              ],
            ),
          ),
          const SectionTitle('Settings'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.storefront_rounded),
                  title: const Text(
                    'Store online',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    s.online
                        ? 'Buyers can see your listings'
                        : 'Holiday mode — listings hidden',
                  ),
                  value: s.online,
                  onChanged: (v) => ref
                      .read(sellerProvider.notifier)
                      .save(s.copyWith(online: v)),
                ),
                _Link(
                  Icons.videocam_outlined,
                  'Live review requests',
                  () => context.push('/live'),
                ),
                _Link(
                  Icons.notifications_none_rounded,
                  'Notifications',
                  () => snack(context, 'Order & payout alerts are on'),
                ),
                _Link(
                  Icons.description_outlined,
                  'Seller policies & fees',
                  () => _policies(context),
                ),
                _Link(
                  Icons.support_agent_rounded,
                  'Seller support (24×7)',
                  () => snack(
                    context,
                    'Call 1800-120-4263 • support@gamex.in',
                    icon: Icons.support_agent_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: C.red),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (ok == true) ref.read(sellerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'GAMEX Seller v1.0.0',
              style: TextStyle(color: C.faint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _policies(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fees & policies',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              KeyValue(
                'Commission',
                '${(Fees.commissionRate * 100).round()}% of price',
              ),
              const KeyValue('Fixed fee', '₹${Fees.fixedFee} per order'),
              const KeyValue('GST on fees', '18%'),
              const KeyValue('Shipping', 'Free (paid by GAMEX)'),
              const KeyValue('Accept order within', '4 hours'),
              const KeyValue('Dispatch within', '24 hours'),
              const KeyValue('Payout', '7 days after delivery'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Seller s) async {
    final store = TextEditingController(text: s.storeName);
    final owner = TextEditingController(text: s.ownerName);
    final gst = TextEditingController(text: s.gstin);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(c).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit store',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: store,
              decoration: const InputDecoration(labelText: 'Store name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: owner,
              decoration: const InputDecoration(labelText: 'Owner name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: gst,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'GSTIN'),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Save',
              onPressed: () {
                if (store.text.trim().length < 3) return;
                ref
                    .read(sellerProvider.notifier)
                    .save(
                      s.copyWith(
                        storeName: store.text.trim(),
                        ownerName: owner.text.trim(),
                        gstin: gst.text.trim().toUpperCase(),
                      ),
                    );
                Navigator.pop(c);
              },
            ),
          ],
        ),
      ),
    );
    store.dispose();
    owner.dispose();
    gst.dispose();
  }
}

class _Score extends StatelessWidget {
  const _Score({
    required this.label,
    required this.value,
    required this.good,
    required this.icon,
  });
  final String label;
  final String value;
  final bool good;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = good ? C.green : C.red;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: C.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.title, this.subtitle, this.ok);
  final String title;
  final String subtitle;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: ok ? C.green : C.amber,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.icon, this.title, this.onTap);
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: C.faint),
      onTap: onTap,
    );
  }
}
