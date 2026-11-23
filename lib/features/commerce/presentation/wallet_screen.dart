import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/commerce_api.dart';

/// GAMEX wallet: cashback, referral rewards and Refer & Earn.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_code.text.trim().length < 4) return;
    setState(() => _busy = true);
    try {
      await ref.read(commerceApiProvider).applyReferral(_code.text);
      ref.invalidate(walletProvider);
      HapticFeedback.heavyImpact();
      if (mounted) {
        tSnack(
          context,
          'Referral applied! Welcome bonus added to your wallet.',
        );
      }
    } catch (e) {
      if (mounted) tSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return TrustScaffold(
        title: 'Wallet & Refer',
        children: [
          const SizedBox(height: 80),
          const Center(
            child: TIcon(Icons.account_balance_wallet_rounded, size: 64),
          ),
          const SizedBox(height: 14),
          const Text(
            'Log in to see your cashback and invite friends',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, color: TX.ink),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 200,
              child: TButton(
                label: 'Log in',
                onTap: () => context.push('/login?from=/wallet'),
              ),
            ),
          ),
        ],
      );
    }
    final async = ref.watch(walletProvider);
    final promo =
        ref.watch(promotionsProvider).asData?.value ?? Promo.fallback();
    return TrustScaffold(
      title: 'Wallet & Refer',
      subtitle: 'Cashback on every order',
      children: async.when(
        loading: () => const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
        error: (e, _) => [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Could not load your wallet\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TX.muted),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 160,
              child: TButton(
                label: 'Retry',
                onTap: () => ref.invalidate(walletProvider),
              ),
            ),
          ),
        ],
        data: (w) => w == null ? const [] : _content(w, promo, user.name),
      ),
    );
  }

  List<Widget> _content(Wallet w, Promo promo, String name) {
    final msg =
        'Hey! I buy certified second-hand phones on GAMEX. Use my code ${w.referralCode} and get ${formatPrice(promo.friendBonus)} in your GAMEX wallet.';
    final f = DateFormat('d MMM yyyy');
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: TX.night,
          borderRadius: BorderRadius.circular(28),
          boxShadow: TX.soft(0.25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFFFC542),
                ),
                SizedBox(width: 8),
                Text(
                  'GAMEX WALLET',
                  style: TextStyle(
                    color: Color(0xFFC9D2FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              formatPrice(w.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Text(
              'Usable on up to ${promo.walletMaxPercent.round()}% of any order',
              style: const TextStyle(color: Color(0xFFC9D2FF), fontSize: 12.5),
            ),
            if (w.pending > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${formatPrice(w.pending)} pending • unlocks after delivery',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _Perk(
              Icons.savings_rounded,
              '${(promo.cashbackRate * 100).round()}% cashback',
              'On every order, up to ${formatPrice(promo.cashbackCap)}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Perk(
              Icons.card_giftcard_rounded,
              '${formatPrice(promo.referrerBonus)} per friend',
              'When their first order is delivered',
            ),
          ),
        ],
      ),
      const TTitle('Refer & Earn'),
      TCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your friend gets ${formatPrice(promo.friendBonus)}, you get ${formatPrice(promo.referrerBonus)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: TX.ink,
                fontSize: 15.5,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: w.referralCode));
                HapticFeedback.selectionClick();
                tSnack(context, 'Code copied');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: TX.violet.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: TX.violet.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      w.referralCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: TX.violet,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy_rounded, color: TX.violet, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TButton(
              label: 'Invite on WhatsApp',
              icon: Icons.share_rounded,
              gradient: TX.success,
              onTap: () => launchUrl(
                Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            if (w.friends.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '${w.friends.length} friend${w.friends.length > 1 ? 's' : ''} joined',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TX.ink,
                ),
              ),
              for (final fr in w.friends)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: TX.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${fr['name']}')),
                      TPill(
                        fr['ordered'] == true ? 'Earned' : 'Awaiting 1st order',
                        color: fr['ordered'] == true ? TX.green : TX.amber,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      if (w.referredBy == null) ...[
        const TTitle('Have a friend\'s code?'),
        TCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: tInput('Enter code, e.g. GX5CC1B4'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: TButton(
                  label: 'Apply',
                  height: 50,
                  busy: _busy,
                  onTap: _apply,
                ),
              ),
            ],
          ),
        ),
      ],
      const TTitle('History'),
      if (w.tx.isEmpty)
        const TCard(
          child: Text(
            'Your cashback and rewards will appear here after your first order.',
            style: TextStyle(color: TX.muted),
          ),
        )
      else
        TCard(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(
            children: [
              for (final (i, t) in w.tx.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: i == w.tx.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFFF0EEFA)),
                          ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        switch (t.kind) {
                          'cashback' => Icons.savings_rounded,
                          'referral' ||
                          'referralBonus' => Icons.card_giftcard_rounded,
                          'refund' => Icons.replay_rounded,
                          _ => Icons.shopping_bag_rounded,
                        },
                        color: t.amount < 0 ? TX.muted : TX.green,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: TX.ink,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              t.status == 'pending'
                                  ? 'Pending${t.releaseAt != null ? ' • unlocks ${f.format(t.releaseAt!.toLocal())}' : ' • unlocks after delivery'}'
                                  : f.format(t.at.toLocal()),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: t.status == 'pending'
                                    ? TX.amber
                                    : TX.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${t.amount < 0 ? '−' : '+'}${formatPrice(t.amount.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: t.amount < 0 ? TX.ink : TX.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => TCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TIcon(icon, size: 34),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, color: TX.ink),
        ),
        Text(text, style: const TextStyle(fontSize: 11.5, color: TX.muted)),
      ],
    ),
  );
}
