import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../checkout/presentation/widgets/address_sheets.dart';
import '../../home/presentation/widgets/home_sheets.dart';
import '../../orders/providers/orders_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/avatar_provider.dart';
import 'account_sheets.dart';

const _img = 'assets/images/home';
const _ink = Color(0xFF0B1230);
const _muted = Color(0xFF4A5372);
const _purple = Color(0xFF6A3DF5);

/// Reward points: 1 point per ৳100 spent.
int rewardPoints(List<Order> orders) =>
    orders.fold(0.0, (s, o) => s + o.total) ~/ 100;

/// GAMEX wallet: 1% cashback on every order.
double walletBalance(List<Order> orders) =>
    (orders.fold(0.0, (s, o) => s + o.total) * 0.01).roundToDouble();

/// Account tab, laid out on the design's 887-px grid.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final d = mq.size.width / 887;
    final user = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider);
    final wish = ref.watch(wishlistProvider).length;

    Widget gap(double h) => SizedBox(height: h * d);

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F3FC),
          body: AuroraBackground(
            child: ListView(
              padding: EdgeInsets.only(
                top: mq.padding.top,
                bottom: mq.padding.bottom + 30 * d,
              ),
              children: [
                _Header(d: d),
                gap(8),
                user == null
                    ? _GuestCard(d: d)
                    : _ProfileCard(user: user, d: d),
                gap(18),
                _Stats(
                  d: d,
                  orders: orders.length,
                  wishlist: wish,
                  points: rewardPoints(orders),
                ),
                gap(22),
                _WalletCard(d: d, balance: walletBalance(orders)),
                gap(18),
                _OrdersCard(d: d, orders: orders),
                gap(18),
                _MenuGrid(d: d),
                gap(22),
                _RewardsBanner(d: d),
                gap(22),
                _SettingsCard(d: d, loggedIn: user != null),
                gap(18),
                Center(
                  child: Text(
                    'GAMEX v1.0.0 • Made with ♥ in Bangladesh',
                    style: TextStyle(
                      fontSize: 19 * d,
                      color: const Color(0xFF8C95B0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Header ─────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.d});
  final double d;

  @override
  Widget build(BuildContext context) {
    Widget circle(Widget icon, VoidCallback onTap, {bool dot = false}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80 * d,
            height: 80 * d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2A3D8F).withValues(alpha: 0.1),
                  blurRadius: 16 * d,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                icon,
                if (dot)
                  Positioned(
                    right: 16 * d,
                    top: 14 * d,
                    child: Container(
                      width: 20 * d,
                      height: 20 * d,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5283B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5 * d),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
    return SizedBox(
      height: 130 * d,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              '$_img/acct_header.jpg',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            right: 34 * d,
            top: 20 * d,
            child: Row(
              children: [
                circle(
                  Icon(Icons.search_rounded, size: 40 * d, color: _ink),
                  () => context.push('/search'),
                ),
                SizedBox(width: 22 * d),
                circle(
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 42 * d,
                    color: _ink,
                  ),
                  () => showNotificationsSheet(context),
                  dot: true,
                ),
                SizedBox(width: 22 * d),
                circle(
                  Icon(Icons.settings_outlined, size: 40 * d, color: _ink),
                  () => showSettingsSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Profile card ─────────────────────────────

BoxDecoration _cardDecoration(double d, {double radius = 40}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius * d),
  border: Border.all(color: Colors.white, width: 2),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF6F7FF), Color(0xFFEDE8FF)],
  ),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF3A2D9E).withValues(alpha: 0.08),
      blurRadius: 30 * d,
      offset: Offset(0, 12 * d),
    ),
  ],
);

class _Avatar extends ConsumerWidget {
  const _Avatar({
    required this.d,
    required this.initials,
    this.editable = true,
  });
  final double d;
  final String initials;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(avatarProvider);
    final size = 210 * d;
    return SizedBox(
      width: size + 20 * d,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(7 * d),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF12B3F6),
                  Color(0xFF6A3DF5),
                  Color(0xFFC04BFF),
                  Color(0xFF12B3F6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.35),
                  blurRadius: 26 * d,
                  offset: Offset(0, 8 * d),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.all(5 * d),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: path != null
                    ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 400)
                    : DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFDDE6FF), Color(0xFFEDE3FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 70 * d,
                              fontWeight: FontWeight.w800,
                              color: _purple,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (editable)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => showAvatarSheet(context),
                child: Container(
                  width: 62 * d,
                  height: 62 * d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10 * d,
                      ),
                    ],
                  ),
                  child: Icon(Icons.edit_outlined, size: 32 * d, color: _ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.d});
  final AppUser user;
  final double d;

  @override
  Widget build(BuildContext context) {
    final joined = DateFormat('d MMM yyyy')
        .format(user.joinedAt ?? DateTime.now());
    Widget info(IconData icon, String text) => Padding(
      padding: EdgeInsets.only(top: 14 * d),
      child: Row(
        children: [
          Icon(icon, size: 30 * d, color: _ink),
          SizedBox(width: 14 * d),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 23 * d,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * d),
      child: Container(
        height: 252 * d,
        decoration: _cardDecoration(d, radius: 44),
        child: Stack(
          children: [
            // Lavender glow behind the badge.
            Positioned(
              right: -40 * d,
              bottom: -60 * d,
              child: Container(
                width: 360 * d,
                height: 260 * d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB79CFF).withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14 * d,
              top: 20 * d,
              child: Image.asset(
                '$_img/acct_badge.png',
                width: 236 * d,
                height: 202 * d,
              ),
            ),
            Positioned(
              left: 20 * d,
              top: 20 * d,
              child: _Avatar(
                d: d,
                initials: user.initials.isEmpty ? 'G' : user.initials,
              ),
            ),
            Positioned(
              left: 262 * d,
              right: 236 * d,
              top: 30 * d,
              child: GestureDetector(
                onTap: () => showEditProfileSheet(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 42 * d,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.6 * d,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * d),
                        Icon(
                          Icons.verified_rounded,
                          size: 38 * d,
                          color: const Color(0xFF1F66FF),
                        ),
                      ],
                    ),
                    SizedBox(height: 12 * d),
                    Container(
                      height: 44 * d,
                      padding: EdgeInsets.symmetric(horizontal: 22 * d),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22 * d),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F2CF0), Color(0xFF8A4FFF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.35),
                            blurRadius: 14 * d,
                            offset: Offset(0, 5 * d),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 28 * d,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10 * d),
                          Text(
                            'Premium Member',
                            style: TextStyle(
                              fontSize: 22 * d,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    info(Icons.badge_outlined, 'User ID: ${user.customerId}'),
                    info(Icons.calendar_month_outlined, 'Joined: $joined'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.d});
  final double d;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * d),
      child: Container(
        height: 252 * d,
        decoration: _cardDecoration(d, radius: 44),
        padding: EdgeInsets.all(20 * d),
        child: Row(
          children: [
            _Avatar(d: d, initials: 'G', editable: false),
            SizedBox(width: 24 * d),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to GAMEX',
                    style: TextStyle(
                      fontSize: 38 * d,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  SizedBox(height: 6 * d),
                  Text(
                    'Sign in to track orders, earn rewards and get exclusive offers.',
                    style: TextStyle(
                      fontSize: 21 * d,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 18 * d),
                  GestureDetector(
                    onTap: () => context.push(
                      '/login?from=${Uri.encodeComponent('/profile')}',
                    ),
                    child: Container(
                      height: 58 * d,
                      padding: EdgeInsets.symmetric(horizontal: 30 * d),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(29 * d),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF12B3F6),
                            Color(0xFF2F5CFF),
                            Color(0xFF8B3DFF),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            color: Colors.white,
                            size: 30 * d,
                          ),
                          SizedBox(width: 12 * d),
                          Text(
                            'Sign in / Register',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23 * d,
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
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Stats ─────────────────────────────

class _Stats extends StatelessWidget {
  const _Stats({
    required this.d,
    required this.orders,
    required this.wishlist,
    required this.points,
  });
  final double d;
  final int orders;
  final int wishlist;
  final int points;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.shopping_bag_outlined,
        const Color(0xFF1F66FF),
        '$orders',
        'Orders',
        () => context.go('/orders'),
      ),
      (
        Icons.favorite_border_rounded,
        const Color(0xFF9B3DF5),
        '$wishlist',
        'Wishlist',
        () => context.push('/wishlist'),
      ),
      (
        Icons.local_offer_outlined,
        const Color(0xFFF59E0B),
        '${coupons.length}',
        'Coupons',
        () => showCouponsListSheet(context),
      ),
      (
        Icons.star_border_rounded,
        const Color(0xFF7A3CF0),
        NumberFormat.decimalPattern('en_IN').format(points),
        'Reward Points',
        () => showRewardsSheet(context, points),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * d),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 14 * d),
            Expanded(
              flex: i == 3 ? 23 : 20,
              child: GestureDetector(
                onTap: items[i].$5,
                child: Container(
                  height: 156 * d,
                  decoration: _cardDecoration(d, radius: 34),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, size: 50 * d, color: items[i].$2),
                      SizedBox(height: 4 * d),
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          fontSize: 38 * d,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      FittedBox(
                        child: Text(
                          items[i].$4,
                          style: TextStyle(fontSize: 22 * d, color: _ink),
                        ),
                      ),
                    ],
                  ),
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

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.d, required this.balance});
  final double d;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18 * d),
      child: GestureDetector(
        onTap: () => showWalletSheet(context),
        child: Container(
          height: 132 * d,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50 * d),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1F66FF),
                Color(0xFF3B44F2),
                Color(0xFF6E3CF0),
                Color(0xFFA24BFF),
              ],
              stops: [0, 0.4, 0.75, 1],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B44F2).withValues(alpha: 0.35),
                blurRadius: 26 * d,
                offset: Offset(0, 12 * d),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Glossy top highlight for a liquid-glass feel.
              Positioned(
                left: 30 * d,
                right: 30 * d,
                top: 4 * d,
                height: 46 * d,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30 * d),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  SizedBox(width: 32 * d),
                  Container(
                    width: 104 * d,
                    height: 104 * d,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32 * d),
                      color: Colors.white.withValues(alpha: 0.16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 54 * d,
                    ),
                  ),
                  SizedBox(width: 30 * d),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Wallet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34 * d,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'GAMEX Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 22 * d,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 2 * d,
                    height: 66 * d,
                    margin: EdgeInsets.symmetric(horizontal: 26 * d),
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${formatPrice(balance)}.00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 50 * d,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 22 * d),
                  Container(
                    width: 60 * d,
                    height: 60 * d,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: _purple,
                      size: 34 * d,
                    ),
                  ),
                  SizedBox(width: 28 * d),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Orders ─────────────────────────────

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.d, required this.orders});
  final double d;
  final List<Order> orders;

  int _count(bool Function(Order o) f) => orders.where(f).length;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        Icons.credit_card_rounded,
        const Color(0xFF1F66FF),
        'To Pay',
        _count(
          (o) =>
              o.status == OrderStatus.pending &&
              o.paymentMethod == PaymentMethod.cashOnDelivery,
        ),
      ),
      (
        Icons.inventory_2_outlined,
        const Color(0xFF1F66FF),
        'Processing',
        _count(
          (o) =>
              o.status == OrderStatus.confirmed ||
              (o.status == OrderStatus.pending &&
                  o.paymentMethod != PaymentMethod.cashOnDelivery),
        ),
      ),
      (
        Icons.local_shipping_outlined,
        const Color(0xFF1F66FF),
        'Shipped',
        _count((o) => o.status == OrderStatus.shipped),
      ),
      (
        Icons.check_circle_outline_rounded,
        const Color(0xFF16A34A),
        'Delivered',
        _count((o) => o.status == OrderStatus.delivered),
      ),
      (
        Icons.replay_rounded,
        const Color(0xFF7A3CF0),
        'Returns',
        _count((o) => o.status == OrderStatus.cancelled),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * d),
      child: Container(
        decoration: _cardDecoration(d),
        padding: EdgeInsets.fromLTRB(14 * d, 22 * d, 14 * d, 16 * d),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 26 * d),
                Icon(Icons.view_in_ar_rounded, size: 48 * d, color: _purple),
                SizedBox(width: 20 * d),
                Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 36 * d,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/orders'),
                  child: Container(
                    height: 48 * d,
                    padding: EdgeInsets.symmetric(horizontal: 22 * d),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24 * d),
                      border: Border.all(color: const Color(0xFFE3E8F5)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'View All Orders',
                          style: TextStyle(
                            fontSize: 21 * d,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        SizedBox(width: 10 * d),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 28 * d,
                          color: _ink,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16 * d),
              ],
            ),
            SizedBox(height: 22 * d),
            Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) SizedBox(width: 14 * d),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.go('/orders'),
                      child: Container(
                        height: 110 * d,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(28 * d),
                          border: Border.all(color: Colors.white),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2A3D8F)
                                  .withValues(alpha: 0.07),
                              blurRadius: 12 * d,
                              offset: Offset(0, 4 * d),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tiles[i].$1,
                                    size: 46 * d,
                                    color: tiles[i].$2,
                                  ),
                                  SizedBox(height: 6 * d),
                                  FittedBox(
                                    child: Text(
                                      tiles[i].$3,
                                      style: TextStyle(
                                        fontSize: 22 * d,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (tiles[i].$4 > 0)
                              Positioned(
                                right: 10 * d,
                                top: -6 * d,
                                child: Container(
                                  width: 34 * d,
                                  height: 34 * d,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5283B),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2 * d,
                                    ),
                                  ),
                                  child: Text(
                                    '${tiles[i].$4}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18 * d,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Menu grid ─────────────────────────────

class _MenuGrid extends ConsumerWidget {
  const _MenuGrid({required this.d});
  final double d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = rewardPoints(ref.watch(ordersProvider));
    final items = <(IconData, String, String, VoidCallback)>[
      (
        Icons.person_outline_rounded,
        'My Profile',
        'Manage your personal info',
        () => showEditProfileSheet(context),
      ),
      (
        Icons.location_on_outlined,
        'Saved Addresses',
        'Delivery & Billing addresses',
        () => showAddressPicker(context),
      ),
      (
        Icons.credit_card_rounded,
        'Payment Methods',
        'bKash, Nagad, Cards & COD',
        () => showPaymentMethodsSheet(context),
      ),
      (
        Icons.verified_user_outlined,
        'Account Security',
        'Password, 2FA & Privacy',
        () => showSecuritySheet(context),
      ),
      (
        Icons.local_offer_outlined,
        'My Coupons',
        'View & manage coupons',
        () => showCouponsListSheet(context),
      ),
      (
        Icons.card_giftcard_rounded,
        'Rewards & Discounts',
        'Points, Vouchers & Offers',
        () => showRewardsSheet(context, points),
      ),
      (
        Icons.favorite_border_rounded,
        'Wishlist',
        'Your saved products',
        () => context.push('/wishlist'),
      ),
      (
        Icons.headset_mic_outlined,
        'Help & Support',
        'Get help, track queries & more',
        () => showHelpSheet(context),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18 * d),
      child: Column(
        children: [
          for (var r = 0; r < items.length; r += 2) ...[
            if (r > 0) SizedBox(height: 8 * d),
            Row(
              children: [
                Expanded(
                  child: _MenuTile(d: d, item: items[r]),
                ),
                SizedBox(width: 13 * d),
                Expanded(
                  child: _MenuTile(d: d, item: items[r + 1]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.d, required this.item});
  final double d;
  final (IconData, String, String, VoidCallback) item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.$4,
      child: Container(
        height: 82 * d,
        decoration: _cardDecoration(d, radius: 26),
        padding: EdgeInsets.only(left: 26 * d, right: 18 * d),
        child: Row(
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => const LinearGradient(
                colors: [Color(0xFF2F5CFF), Color(0xFF9B3DF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(r),
              child: Icon(item.$1, size: 48 * d),
            ),
            SizedBox(width: 18 * d),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.$2,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 25 * d,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.$3,
                      maxLines: 1,
                      style: TextStyle(fontSize: 19 * d, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 38 * d, color: _ink),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Rewards banner ─────────────────────────────

class _RewardsBanner extends ConsumerWidget {
  const _RewardsBanner({required this.d});
  final double d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = rewardPoints(ref.watch(ordersProvider));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18 * d),
      child: Container(
        height: 224 * d,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44 * d),
          border: Border.all(color: Colors.white, width: 2),
          gradient: const LinearGradient(
            colors: [Color(0xFFF7F5FF), Color(0xFFEDE6FF), Color(0xFFF4EFFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A3DF5).withValues(alpha: 0.12),
              blurRadius: 30 * d,
              offset: Offset(0, 12 * d),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 6 * d,
              top: 6 * d,
              child: Image.asset(
                '$_img/acct_gift.png',
                width: 222 * d,
                height: 194 * d,
              ),
            ),
            Positioned(
              left: 220 * d,
              top: 30 * d,
              right: 300 * d,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (r) => const LinearGradient(
                                colors: [Color(0xFF5B2DF0), Color(0xFF9B3DF5)],
                              ).createShader(r),
                              child: Text(
                                'GAMEX',
                                style: TextStyle(
                                  fontSize: 40 * d,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5 * d,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' Rewards'),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 40 * d,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.5 * d,
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * d),
                  Text(
                    'Earn points on every order and redeem for exciting discounts.',
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 22 * d,
                      height: 1.3,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 22 * d,
              top: 72 * d,
              child: GestureDetector(
                onTap: () => showRewardsSheet(context, points),
                child: Container(
                  height: 66 * d,
                  padding: EdgeInsets.symmetric(horizontal: 26 * d),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(33 * d),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F2CF0), Color(0xFF8A4FFF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withValues(alpha: 0.35),
                        blurRadius: 16 * d,
                        offset: Offset(0, 6 * d),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Explore Rewards',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22 * d,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 10 * d),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 28 * d,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 * d,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 6 * d),
                      width: 14 * d,
                      height: 14 * d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0 ? _purple : const Color(0xFFD4CCF5),
                      ),
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

// ───────────────────────────── Settings ─────────────────────────────

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.d, required this.loggedIn});
  final double d;
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget row(
      IconData icon,
      String title,
      VoidCallback onTap, {
      Color? color,
      String? trailing,
    }) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30 * d, vertical: 22 * d),
        child: Row(
          children: [
            Icon(icon, size: 38 * d, color: color ?? _ink),
            SizedBox(width: 24 * d),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 24 * d,
                  fontWeight: FontWeight.w600,
                  color: color ?? _ink,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(fontSize: 21 * d, color: _muted),
              ),
            Icon(
              Icons.chevron_right_rounded,
              size: 36 * d,
              color: color ?? _ink,
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18 * d),
      child: Container(
        decoration: _cardDecoration(d, radius: 34),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              row(
                Icons.tune_rounded,
                'App Settings',
                () => showSettingsSheet(context),
                trailing: 'Theme, alerts',
              ),
              Divider(height: 1, indent: 92 * d),
              row(
                Icons.receipt_long_outlined,
                'Order History',
                () => context.go('/orders'),
              ),
              Divider(height: 1, indent: 92 * d),
              row(
                Icons.privacy_tip_outlined,
                'Privacy Policy & Terms',
                () => showAppSnack(context, 'Opening policy…'),
              ),
              if (loggedIn) ...[
                Divider(height: 1, indent: 92 * d),
                row(
                  Icons.logout_rounded,
                  'Log out',
                  () => confirmLogout(context, ref),
                  color: const Color(0xFFE5283B),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
