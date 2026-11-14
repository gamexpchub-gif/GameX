import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/server_sheet.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../home/presentation/widgets/home_sheets.dart';
import '../../orders/presentation/order_assistant.dart';
import '../../orders/providers/orders_provider.dart';
import '../providers/avatar_provider.dart';
import 'account_sheets.dart';

const _img = 'assets/images/home';
const _ink = Color(0xFF0B1230);
const _muted = Color(0xFF4A5372);
const _blue = Color(0xFF1F5BFF);

/// Reward points: 1 point per ₹10 spent.
int rewardPoints(List<Order> orders) =>
    orders.fold(0.0, (s, o) => s + o.total) ~/ 10;

/// GAMEX wallet: 2% cashback on delivered orders.
double walletBalance(List<Order> orders) =>
    (orders.where((o) => o.isDelivered).fold(0.0, (s, o) => s + o.total) * 0.02)
        .roundToDouble();

/// Account tab, laid out on the design's 852-px grid.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final d = mq.size.width / 852;
    final user = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider);
    Widget gap(double h) => SizedBox(height: h * d);

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFEEF2FC),
          body: AuroraBackground(
            child: ListView(
              padding: EdgeInsets.only(
                top: mq.padding.top + 12 * d,
                bottom: mq.padding.bottom + 36 * d,
              ),
              children: [
                _Header(d: d),
                gap(22),
                RepaintBoundary(
                  child: _ProfileCard(d: d, user: user, orders: orders),
                ),
                gap(22),
                _Stats(d: d, orders: orders),
                gap(22),
                _WalletOffers(d: d, balance: walletBalance(orders)),
                gap(20),
                _MenuCard(d: d),
                gap(36),
                _SectionTitle(
                  d: d,
                  title: 'Support & Services',
                  onViewAll: () => showHelpSheet(context),
                ),
                gap(18),
                _Services(d: d),
                gap(34),
                _SectionTitle(d: d, title: 'Settings & Account'),
                gap(16),
                _SettingsCard(d: d, loggedIn: user != null),
                gap(22),
                Center(
                  child: Text(
                    'GAMEX v1.0.0 • Made with ♥ in India',
                    style: TextStyle(
                      fontSize: 17 * d,
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

class _Header extends ConsumerWidget {
  const _Header({required this.d});
  final double d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartCountProvider);
    Widget badge(int n) => Positioned(
      right: -4 * d,
      top: -6 * d,
      child: Container(
        width: 32 * d,
        height: 32 * d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE5283B),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5 * d),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17 * d,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    Widget btn(
      Widget icon,
      VoidCallback onTap, {
      int count = 0,
      bool square = false,
    }) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70 * d,
        height: 70 * d,
        decoration: BoxDecoration(
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(22 * d) : null,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F).withValues(alpha: 0.1),
              blurRadius: 14 * d,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [icon, if (count > 0) badge(count)],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(50 * d, 0, 30 * d, 0),
      child: Row(
        children: [
          Image.asset(
            '$_img/logo_gamex.png',
            width: 222 * d,
            height: 70 * d,
            filterQuality: FilterQuality.medium,
          ),
          const Spacer(),
          btn(
            Icon(Icons.notifications_none_rounded, size: 40 * d, color: _ink),
            () => showNotificationsSheet(context),
            count: 3,
          ),
          SizedBox(width: 18 * d),
          btn(
            Icon(Icons.shopping_cart_outlined, size: 38 * d, color: _ink),
            () => context.push('/cart'),
            count: cart,
          ),
          SizedBox(width: 18 * d),
          btn(
            Icon(Icons.center_focus_weak_rounded, size: 40 * d, color: _blue),
            () => showAppSnack(
              context,
              'Scan an IMEI or GAMEX QR code — coming soon',
            ),
            square: true,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Profile card ─────────────────────────────

/// Soft light ribbons on the right of the blue profile card.
class _LiquidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Paint ribbon(double a) => Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: a),
          const Color(0xFF8FB8FF).withValues(alpha: a * 0.6),
        ],
        stops: const [0, 0.6, 1],
      ).createShader(Offset.zero & size);
    final p1 = Path()
      ..moveTo(w * 0.62, h)
      ..cubicTo(w * 0.72, h * 0.62, w * 0.86, h * 0.72, w, h * 0.35)
      ..lineTo(w, h * 0.55)
      ..cubicTo(w * 0.9, h * 0.85, w * 0.78, h * 0.8, w * 0.7, h)
      ..close();
    canvas.drawPath(p1, ribbon(0.32));
    final p2 = Path()
      ..moveTo(w * 0.7, h * 0.55)
      ..cubicTo(w * 0.8, h * 0.4, w * 0.9, h * 0.52, w, h * 0.12)
      ..lineTo(w, h * 0.22)
      ..cubicTo(w * 0.9, h * 0.6, w * 0.82, h * 0.5, w * 0.74, h * 0.62)
      ..close();
    canvas.drawPath(p2, ribbon(0.22));
    // Warm glow bottom-right.
    canvas.drawCircle(
      Offset(w * 1.02, h * 0.95),
      h * 0.5,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFE7A8).withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 1.02, h * 0.95),
                radius: h * 0.5,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(_LiquidPainter oldDelegate) => false;
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({
    required this.d,
    required this.user,
    required this.orders,
  });
  final double d;
  final AppUser? user;
  final List<Order> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    final avatar = ref.watch(avatarProvider);
    final points = rewardPoints(orders);
    final since = DateFormat('MMM yyyy').format(u?.joinedAt ?? DateTime.now());
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * d),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40 * d),
        child: Container(
          height: 275 * d,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2A8F), Color(0xFF0D3BC0), Color(0xFF1E5BEA)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _LiquidPainter())),
              // Avatar.
              Positioned(
                left: 40 * d,
                top: 17 * d,
                child: GestureDetector(
                  onTap: u == null ? null : () => showAvatarSheet(context),
                  child: SizedBox(
                    width: 140 * d,
                    height: 140 * d,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 134 * d,
                          height: 134 * d,
                          padding: EdgeInsets.all(5 * d),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 16 * d,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatar != null
                                ? Image.file(
                                    File(avatar),
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                  )
                                : Container(
                                    color: const Color(0xFFE6ECFF),
                                    alignment: Alignment.center,
                                    child: Text(
                                      u == null
                                          ? 'G'
                                          : (u.initials.isEmpty
                                                ? 'G'
                                                : u.initials),
                                      style: TextStyle(
                                        fontSize: 48 * d,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0D3BC0),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (u != null)
                          Positioned(
                            right: 2 * d,
                            bottom: 2 * d,
                            child: Container(
                              width: 38 * d,
                              height: 38 * d,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1F5BFF),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3 * d,
                                ),
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 22 * d,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Name, email, phone.
              Positioned(
                left: 198 * d,
                right: 120 * d,
                top: 28 * d,
                child: u == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to GAMEX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30 * d,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6 * d),
                          Text(
                            'Sign in to track orders and earn rewards',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 18 * d,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    u.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30 * d,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8 * d),
                              Icon(
                                Icons.verified_rounded,
                                size: 30 * d,
                                color: const Color(0xFF4F8BFF),
                              ),
                            ],
                          ),
                          SizedBox(height: 10 * d),
                          Text(
                            u.email.isEmpty ? u.customerId : u.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 19 * d,
                            ),
                          ),
                          SizedBox(height: 12 * d),
                          Row(
                            children: [
                              Icon(
                                Icons.call_rounded,
                                size: 22 * d,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                              SizedBox(width: 10 * d),
                              Text(
                                _formatPhone(u.phone),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19 * d,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 12 * d),
                              if ((u.phone ?? '').isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12 * d,
                                    vertical: 3 * d,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(14 * d),
                                  ),
                                  child: Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16 * d,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
              // Edit profile + QR.
              Positioned(
                right: 25 * d,
                top: 56 * d,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => u == null
                          ? context.push(
                              '/login?from=${Uri.encodeComponent('/profile')}',
                            )
                          : showEditProfileSheet(context),
                      child: Container(
                        height: 50 * d,
                        padding: EdgeInsets.symmetric(horizontal: 18 * d),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(25 * d),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              u == null
                                  ? Icons.login_rounded
                                  : Icons.edit_outlined,
                              size: 24 * d,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8 * d),
                            Text(
                              u == null ? 'Sign In' : 'Edit Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18 * d,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 14 * d),
                    GestureDetector(
                      onTap: () => showIdCardSheet(context),
                      child: Container(
                        width: 50 * d,
                        height: 50 * d,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12 * d),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 36 * d,
                          color: _blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // GAMEX Prime + points.
              Positioned(
                left: 27 * d,
                right: 23 * d,
                bottom: 17 * d,
                child: Container(
                  height: 76 * d,
                  decoration: BoxDecoration(
                    color: const Color(0xFF081A4F).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24 * d),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 24 * d),
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 46 * d,
                        color: const Color(0xFFF7C33C),
                      ),
                      SizedBox(width: 18 * d),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'GAMEX Prime',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21 * d,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 10 * d),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 9 * d,
                                    vertical: 1 * d,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5C542),
                                    borderRadius: BorderRadius.circular(10 * d),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: const Color(0xFF3B2A00),
                                      fontSize: 14 * d,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Member since $since',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16 * d,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 46 * d,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showRewardsSheet(context, points),
                          child: Row(
                            children: [
                              SizedBox(width: 28 * d),
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 38 * d,
                                color: const Color(0xFFF7C33C),
                              ),
                              SizedBox(width: 16 * d),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${NumberFormat.decimalPattern('en_IN').format(points)} Points',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 21 * d,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Worth ${formatPrice((points / 10).roundToDouble())}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 16 * d,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 34 * d,
                                color: Colors.white,
                              ),
                              SizedBox(width: 14 * d),
                            ],
                          ),
                        ),
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

  static String _formatPhone(String? p) {
    final digits = (p ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return p ?? '';
    final last = digits.substring(digits.length - 10);
    return '+91 ${last.substring(0, 5)} ${last.substring(5)}';
  }
}

// ───────────────────────────── Stats ─────────────────────────────

class _Stats extends StatelessWidget {
  const _Stats({required this.d, required this.orders});
  final double d;
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ic3d_box', orders.length, 'Total Orders'),
      ('ic3d_check', orders.where((o) => o.isDelivered).length, 'Delivered'),
      ('ic3d_truck', orders.where((o) => o.isShipped).length, 'In Transit'),
      ('ic3d_return', orders.where((o) => o.isReturned).length, 'Returns'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 36 * d),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 17 * d),
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/orders'),
                child: Container(
                  height: 125 * d,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(26 * d),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2A3D8F).withValues(alpha: 0.07),
                        blurRadius: 14 * d,
                        offset: Offset(0, 5 * d),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        '$_img/${items[i].$1}.png',
                        width: 50 * d,
                        height: 48 * d,
                      ),
                      SizedBox(height: 4 * d),
                      Text(
                        '${items[i].$2}',
                        style: TextStyle(
                          fontSize: 30 * d,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      Text(
                        items[i].$3,
                        style: TextStyle(fontSize: 17 * d, color: _ink),
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

// ───────────────────────────── Wallet + offers ─────────────────────────────

class _WalletOffers extends StatelessWidget {
  const _WalletOffers({required this.d, required this.balance});
  final double d;
  final double balance;

  @override
  Widget build(BuildContext context) {
    Widget card({
      required List<Color> colors,
      required String icon,
      required Widget text,
      required VoidCallback onTap,
      required Color arrow,
    }) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 84 * d,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30 * d),
            gradient: LinearGradient(colors: colors),
            border: Border.all(color: Colors.white, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 16 * d,
                offset: Offset(0, 6 * d),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(width: 26 * d),
              Image.asset('$_img/$icon.png', width: 62 * d, height: 62 * d),
              SizedBox(width: 18 * d),
              Expanded(child: text),
              Container(
                width: 46 * d,
                height: 46 * d,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 28 * d,
                  color: arrow,
                ),
              ),
              SizedBox(width: 16 * d),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * d),
      child: Row(
        children: [
          card(
            colors: const [Color(0xFFE4EEFF), Color(0xFFC4DAFF)],
            icon: 'ic3d_wallet',
            arrow: _blue,
            onTap: () => showWalletSheet(context),
            text: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GAMEX Wallet',
                  style: TextStyle(
                    fontSize: 17 * d,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPrice(balance),
                    style: TextStyle(
                      fontSize: 30 * d,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 18 * d),
          card(
            colors: const [Color(0xFFF2EAFF), Color(0xFFDCC9FF)],
            icon: 'ic3d_offer',
            arrow: const Color(0xFF6A3DF5),
            onTap: () => showCouponsListSheet(context),
            text: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Offers',
                  style: TextStyle(
                    fontSize: 19 * d,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                Text(
                  '${coupons.length + 1} Active Offers',
                  style: TextStyle(
                    fontSize: 17 * d,
                    color: const Color(0xFF4B3A8C),
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

// ───────────────────────────── Lists ─────────────────────────────

typedef _Row = (IconData, String, String, VoidCallback);

class _ListCard extends StatelessWidget {
  const _ListCard({required this.d, required this.rows});
  final double d;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * d),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30 * d),
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F).withValues(alpha: 0.07),
              blurRadius: 18 * d,
              offset: Offset(0, 6 * d),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 105 * d,
                    endIndent: 60 * d,
                    color: const Color(0xFFE6EAF4),
                  ),
                InkWell(
                  onTap: rows[i].$4,
                  borderRadius: BorderRadius.circular(30 * d),
                  child: SizedBox(
                    height: 68 * d,
                    child: Row(
                      children: [
                        SizedBox(width: 36 * d),
                        Icon(
                          rows[i].$1,
                          size: 38 * d,
                          color: const Color(0xFF1B2340),
                        ),
                        SizedBox(width: 32 * d),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rows[i].$2,
                                style: TextStyle(
                                  fontSize: 20 * d,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                rows[i].$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16 * d,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 38 * d,
                          color: const Color(0xFF1B2340),
                        ),
                        SizedBox(width: 28 * d),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.d});
  final double d;

  @override
  Widget build(BuildContext context) {
    return _ListCard(
      d: d,
      rows: [
        (
          Icons.view_in_ar_outlined,
          'My Orders',
          'Track, manage and view all your orders',
          () => context.go('/orders'),
        ),
        (
          Icons.smartphone_rounded,
          'My Devices',
          'Purchased, traded-in and warranty devices',
          () => showDevicesSheet(context),
        ),
        (
          Icons.favorite_border_rounded,
          'Wishlist',
          'Your saved phones and alerts',
          () => context.push('/wishlist'),
        ),
        (
          Icons.notifications_none_rounded,
          'Price Alerts',
          'Get notified when prices drop',
          () => showPriceAlertsSheet(context),
        ),
        (
          Icons.swap_horiz_rounded,
          'Trade-In / Sell Phone',
          'Exchange your old phone for the best value',
          () => showTradeInSheet(context),
        ),
        (
          Icons.credit_card_rounded,
          'EMI & Payments',
          'EMI plans, transactions and invoices',
          () => showEmiSheet(context),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.d, required this.title, this.onViewAll});
  final double d;
  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32 * d),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26 * d,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.3 * d,
            ),
          ),
          const Spacer(),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 20 * d,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                    ),
                  ),
                  SizedBox(width: 10 * d),
                  Icon(Icons.arrow_forward_rounded, size: 26 * d, color: _blue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Services extends StatelessWidget {
  const _Services({required this.d});
  final double d;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback, bool)>[
      (
        Icons.headset_mic_outlined,
        'Help Center',
        () => showHelpSheet(context),
        false,
      ),
      (
        Icons.chat_outlined,
        'Live Chat',
        () => showOrderAssistant(context),
        true,
      ),
      (
        Icons.verified_user_outlined,
        'Warranty\nClaim',
        () => showRequestSheet(
          context,
          title: 'Warranty Claim',
          subtitle: 'Covered under your GAMEX warranty',
          cta: 'Submit Claim',
        ),
        false,
      ),
      (
        Icons.build_outlined,
        'Service &\nRepair',
        () => showRequestSheet(
          context,
          title: 'Service & Repair',
          subtitle: 'Doorstep pickup by certified technicians',
          cta: 'Book Service',
        ),
        false,
      ),
      (
        Icons.location_on_outlined,
        'Pickup &\nReturn',
        () => showRequestSheet(
          context,
          title: 'Pickup & Return',
          subtitle: 'Free pickup within 7 days of delivery',
          cta: 'Schedule Pickup',
        ),
        false,
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * d),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 16 * d),
            Expanded(
              child: GestureDetector(
                onTap: items[i].$3,
                child: Container(
                  height: 120 * d,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24 * d),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2A3D8F).withValues(alpha: 0.07),
                        blurRadius: 14 * d,
                        offset: Offset(0, 5 * d),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(items[i].$1, size: 46 * d, color: _blue),
                          if (items[i].$4)
                            Positioned(
                              right: -10 * d,
                              top: -6 * d,
                              child: Container(
                                width: 16 * d,
                                height: 16 * d,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2 * d,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8 * d),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.5 * d,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: _ink,
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

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.d, required this.loggedIn});
  final double d;
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ListCard(
      d: d,
      rows: [
        (
          Icons.person_outline_rounded,
          'Account Settings',
          'Profile, email, phone and security',
          () {
            if (loggedIn) {
              showEditProfileSheet(context);
            } else {
              context.push('/login?from=${Uri.encodeComponent('/profile')}');
            }
          },
        ),
        (
          Icons.notifications_none_rounded,
          'Notification Preferences',
          'Offers, orders and price alerts',
          () => showSettingsSheet(context),
        ),
        (
          Icons.verified_user_outlined,
          'Privacy & Security',
          'Password, 2FA and account protection',
          () => showSecuritySheet(context),
        ),
        (
          Icons.dns_outlined,
          'GAMEX Server',
          'Connection for seller listings & orders',
          () => showServerSheet(context),
        ),
        if (loggedIn)
          (
            Icons.logout_rounded,
            'Log Out',
            'Sign out of this device',
            () => confirmLogout(context, ref),
          ),
      ],
    );
  }
}
