import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/server_sheet.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../commerce/data/commerce_api.dart';
import '../../commerce/services/notification_service.dart';
import '../../orders/providers/orders_provider.dart';
import '../../support/data/support_api.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/avatar_provider.dart';
import 'account_sheets.dart';

const _bg = Color(0xFFF1F4FB);
const _ink = Color(0xFF0B1230);
const _muted = Color(0xFF5B6585);
const _blue = Color(0xFF1F5BFF);
const _violet = Color(0xFF6D3BFF);
const _hero = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0A2A8F), Color(0xFF1F5BFF), Color(0xFF6D3BFF)],
);

/// Account tab: profile, order summary, wallet, shopping, services,
/// help & support and settings. Sized in logical pixels for easy reading.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _need(BuildContext context, WidgetRef ref, String path) {
    if (ref.read(authProvider) == null) {
      context.push('/login?from=${Uri.encodeComponent(path)}');
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider);
    final pad = MediaQuery.paddingOf(context);
    final support = user == null
        ? null
        : ref.watch(supportHomeProvider).asData?.value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletProvider);
            ref.invalidate(supportHomeProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, pad.bottom + 32),
            children: [
              const _TopBar(),
              const SizedBox(height: 14),
              _ProfileHero(user: user),
              const SizedBox(height: 16),
              _OrderStats(orders: orders),
              const SizedBox(height: 16),
              if (user != null) ...[
                const _WalletCard(),
                const SizedBox(height: 16),
              ],
              _HelpBanner(
                unread: support?.unread ?? 0,
                agentsOnline: support?.agentsOnline ?? false,
                onChat: () => _need(context, ref, '/support/chat'),
                onHelp: () => context.push('/support'),
              ),
              const SizedBox(height: 24),
              _Section(
                title: 'My shopping',
                rows: [
                  _Row(Icons.inventory_2_outlined, 'My Orders', 'Track, return or get an invoice', () => context.go('/orders'), badge: orders.where((o) => o.isShipped).length),
                  _Row(Icons.favorite_border_rounded, 'Wishlist', '${ref.watch(wishlistProvider).length} saved phones', () => context.push('/wishlist')),
                  _Row(Icons.local_offer_outlined, 'My Offers', 'Prices you proposed and seller replies', () => _need(context, ref, '/offers')),
                  _Row(Icons.notifications_active_outlined, 'Price & Stock Alerts', 'Get told when prices drop', () => _need(context, ref, '/alerts')),
                  _Row(Icons.devices_other_outlined, 'My Devices', 'Bought, traded-in and under warranty', () => showDevicesSheet(context)),
                ],
              ),
              _Section(
                title: 'Sell & services',
                rows: [
                  _Row(Icons.swap_horiz_rounded, 'Exchange your phone', 'Instant quote, extra bonus on a new order', () => context.push('/trade-in')),
                  _Row(Icons.sell_outlined, 'Sell to GAMEX', 'Best price, paid the same day', () => context.push('/sell')),
                  _Row(Icons.build_outlined, 'Repairs', 'Doorstep pickup, 6-month repair warranty', () => context.push('/repair')),
                  _Row(Icons.health_and_safety_outlined, 'Phone setup & health check', 'Test your phone, move your data', () => context.push('/setup')),
                  _Row(Icons.credit_card_outlined, 'EMI & Pay Later', 'No-cost EMI calculator', () => context.push('/emi')),
                ],
              ),
              _Section(
                title: 'Help & support',
                rows: [
                  _Row(Icons.support_agent_rounded, 'Help Center', 'FAQs, guides and contact options', () => context.push('/support')),
                  _Row(Icons.chat_bubble_outline_rounded, 'Live chat', 'AI assistant 24×7, agents 9 AM – 9 PM', () => _need(context, ref, '/support/chat')),
                  _Row(
                    Icons.confirmation_number_outlined,
                    'My tickets',
                    support == null || support.openTickets == 0
                        ? 'Raise and track support requests'
                        : '${support.openTickets} open ticket${support.openTickets > 1 ? 's' : ''}',
                    () => _need(context, ref, '/support/tickets'),
                    badge: support?.unread ?? 0,
                  ),
                  _Row(Icons.verified_user_outlined, 'Trust Center', 'Certificates, IMEI check, warranty', () => context.push('/trust')),
                ],
              ),
              _Section(
                title: 'Settings',
                rows: [
                  _Row(Icons.person_outline_rounded, 'Account settings', 'Name, email and password', () => user == null ? context.push('/login?from=${Uri.encodeComponent('/profile')}') : showEditProfileSheet(context)),
                  _Row(Icons.translate_rounded, 'Language', 'English • हिन्दी • বাংলা', () => showLanguageSheet(context, ref)),
                  _Row(Icons.notifications_none_rounded, 'Notifications', 'Orders, offers and alerts', () => context.push('/notifications'), badge: ref.watch(unreadNotificationsProvider)),
                  _Row(Icons.lock_outline_rounded, 'Privacy & security', 'Password, data and account deletion', () => showSecuritySheet(context)),
                  _Row(Icons.dns_outlined, 'GAMEX server', 'Connection settings', () => showServerSheet(context)),
                ],
              ),
              if (user != null) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ],
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'GAMEX v1.0.0 • Made with ♥ in India',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8C95B0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Top bar ─────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget btn(IconData icon, VoidCallback onTap, int count) => Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: _ink, size: 24),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5283B),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        const Expanded(
          child: Text(
            'My Account',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.4,
            ),
          ),
        ),
        btn(
          Icons.notifications_none_rounded,
          () => context.push('/notifications'),
          ref.watch(unreadNotificationsProvider),
        ),
        const SizedBox(width: 10),
        btn(
          Icons.shopping_bag_outlined,
          () => context.push('/cart'),
          ref.watch(cartCountProvider),
        ),
      ],
    );
  }
}

// ───────────────────────────── Profile ─────────────────────────────

class _ProfileHero extends ConsumerWidget {
  const _ProfileHero({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    final avatar = ref.watch(avatarProvider);
    final hasPhoto = avatar != null && File(avatar).existsSync();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _hero,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: u == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Welcome to GAMEX',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in to track orders, save phones and get help faster.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _blue,
                          minimumSize: const Size.fromHeight(50),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () => context.push(
                          '/login?from=${Uri.encodeComponent('/profile')}',
                        ),
                        child: const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          minimumSize: const Size.fromHeight(50),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => context.push(
                          '/register?from=${Uri.encodeComponent('/profile')}',
                        ),
                        child: const Text('Create account'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => showAvatarSheet(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white,
                            backgroundImage: hasPhoto
                                ? FileImage(File(avatar))
                                : null,
                            child: hasPhoto
                                ? null
                                : Text(
                                    u.initials,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _blue,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _violet,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF7CF3C5),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            u.phone?.isNotEmpty == true ? u.phone! : u.email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          if (u.email.isNotEmpty &&
                              u.phone?.isNotEmpty == true)
                            Text(
                              u.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD66B),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Member since ${DateFormat('MMM yyyy').format(u.joinedAt ?? DateTime.now())}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showEditProfileSheet(context),
                        child: const Row(
                          children: [
                            Text(
                              'Edit profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                            ),
                          ],
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

// ───────────────────────────── Order stats ─────────────────────────────

class _OrderStats extends StatelessWidget {
  const _OrderStats({required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.inventory_2_outlined, orders.length, 'Orders', _blue),
      (
        Icons.local_shipping_outlined,
        orders.where((o) => o.isShipped).length,
        'On the way',
        const Color(0xFFEA580C),
      ),
      (
        Icons.check_circle_outline_rounded,
        orders.where((o) => o.isDelivered).length,
        'Delivered',
        const Color(0xFF16A34A),
      ),
      (
        Icons.assignment_return_outlined,
        orders.where((o) => o.isReturned).length,
        'Returns',
        _violet,
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: _cardDecoration,
      child: Row(
        children: [
          for (final (i, it) in items.indexed) ...[
            if (i > 0)
              Container(width: 1, height: 52, color: const Color(0xFFE6EAF4)),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.go('/orders'),
                child: Column(
                  children: [
                    Icon(it.$1, color: it.$4, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      '${it.$2}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      it.$3,
                      style: const TextStyle(fontSize: 12.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Wallet ─────────────────────────────

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider).asData?.value;
    Widget tile(
      IconData icon,
      Color color,
      String label,
      String value,
      VoidCallback onTap,
    ) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 13, color: _muted),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration,
      child: Row(
        children: [
          tile(
            Icons.account_balance_wallet_outlined,
            _blue,
            'GAMEX Wallet',
            w == null ? '—' : formatPrice(w.balance),
            () => context.push('/wallet'),
          ),
          Container(width: 1, height: 44, color: const Color(0xFFE6EAF4)),
          const SizedBox(width: 6),
          tile(
            Icons.card_giftcard_rounded,
            _violet,
            'Refer & earn',
            w == null || w.referralCode.isEmpty ? 'Invite' : w.referralCode,
            () => context.push('/wallet'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Help banner ─────────────────────────────

class _HelpBanner extends StatelessWidget {
  const _HelpBanner({
    required this.unread,
    required this.agentsOnline,
    required this.onChat,
    required this.onHelp,
  });
  final int unread;
  final bool agentsOnline;
  final VoidCallback onChat;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0FF),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFD4E0FF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _hero,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Need help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  Text(
                    agentsOnline
                        ? 'AI assistant 24×7 • agents online now'
                        : 'AI assistant 24×7 • agents 9 AM – 9 PM',
                    style: const TextStyle(fontSize: 13.5, color: _muted),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5283B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unread new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _blue,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: const Text('Chat with us'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFC9D6FF)),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline_rounded, size: 20),
                label: const Text('Help Center'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ───────────────────────────── Sections ─────────────────────────────

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF1E2A5A).withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

class _Row {
  const _Row(this.icon, this.title, this.subtitle, this.onTap, {this.badge = 0});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        Container(
          decoration: _cardDecoration,
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (final (i, r) in rows.indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 72,
                      color: Color(0xFFEDF0F7),
                    ),
                  InkWell(
                    onTap: r.onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF3FF),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(r.icon, color: _blue, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r.badge > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5283B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${r.badge}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFA3ABC4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
