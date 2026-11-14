import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../data/models/order.dart';
import '../../home/presentation/widgets/home_sheets.dart';
import '../../product/presentation/widgets/review_widgets.dart';
import '../providers/orders_provider.dart';
import 'order_assistant.dart';

const _img = 'assets/images/home';
const _ink = Color(0xFF0B1230);
const _muted = Color(0xFF4A5372);
const _blue = Color(0xFF1F5BFF);

Color orderStatusColor(OrderStatus s) => switch (s) {
  OrderStatus.pending || OrderStatus.confirmed => const Color(0xFFF08A00),
  OrderStatus.shipped => _blue,
  OrderStatus.delivered => const Color(0xFF16A34A),
  OrderStatus.cancelled => const Color(0xFFE5283B),
};

String orderStatusLabel(OrderStatus s) => switch (s) {
  OrderStatus.pending || OrderStatus.confirmed => 'Processing',
  OrderStatus.shipped => 'In Transit',
  OrderStatus.delivered => 'Delivered',
  OrderStatus.cancelled => 'Returned',
};

IconData orderStatusIcon(OrderStatus s) => switch (s) {
  OrderStatus.pending || OrderStatus.confirmed => Icons.schedule_rounded,
  OrderStatus.shipped => Icons.local_shipping_rounded,
  OrderStatus.delivered => Icons.verified_rounded,
  OrderStatus.cancelled => Icons.assignment_return_rounded,
};

/// Coloured status chip used on order cards and the order details page.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.scale = 1});
  final OrderStatus status;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final c = orderStatusColor(status);
    return Container(
      height: 36 * scale,
      padding: EdgeInsets.only(left: 6 * scale, right: 14 * scale),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(orderStatusIcon(status), size: 24 * scale, color: c),
          SizedBox(width: 6 * scale),
          Text(
            orderStatusLabel(status),
            style: TextStyle(
              color: c,
              fontSize: 18 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tab { all, processing, shipped, delivered, returns }

/// Orders tab, laid out on the design's 852-px grid.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  _Tab _tab = _Tab.all;

  bool _match(Order o) => switch (_tab) {
    _Tab.all => true,
    _Tab.processing => o.isProcessing,
    _Tab.shipped => o.isShipped,
    _Tab.delivered => o.isDelivered,
    _Tab.returns => o.isReturned,
  };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final d = mq.size.width / 852;
    final orders = ref.watch(ordersProvider);
    final list = orders.where(_match).toList();
    Widget box(Widget w) => SliverToBoxAdapter(child: w);
    Widget gap(double h) => SliverToBoxAdapter(child: SizedBox(height: h * d));

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFEEF2FC),
          body: AuroraBackground(
            child: CustomScrollView(
              slivers: [
                gap(mq.padding.top / d + 30),
                box(_Header(d: d)),
                gap(26),
                box(_TitleRow(d: d, orders: orders)),
                gap(26),
                box(_Stats(d: d, orders: orders)),
                gap(28),
                box(_AssistantBanner(d: d)),
                gap(30),
                box(
                  _Tabs(
                    d: d,
                    orders: orders,
                    tab: _tab,
                    onTab: (t) => setState(() => _tab = t),
                  ),
                ),
                gap(22),
                if (list.isEmpty)
                  box(
                    Padding(
                      padding: EdgeInsets.only(top: 40 * d),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: orders.isEmpty
                            ? 'No orders yet'
                            : 'Nothing here',
                        message: orders.isEmpty
                            ? 'Your orders will appear here once you place one.'
                            : 'No orders in this status right now.',
                        actionLabel: orders.isEmpty ? 'Start Shopping' : null,
                        onAction: orders.isEmpty
                            ? () => context.go('/home')
                            : null,
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => SizedBox(height: 22 * d),
                    itemBuilder: (_, i) => RepaintBoundary(
                      child: _OrderCard(order: list[i], d: d),
                    ),
                  ),
                gap(mq.padding.bottom / d + 30),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(40 * d, 0, 30 * d, 0),
      child: Row(
        children: [
          Image.asset(
            '$_img/logo_gamex2.png',
            width: 278 * d,
            height: 80 * d,
            filterQuality: FilterQuality.medium,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => showNotificationsSheet(context),
            child: Container(
              width: 74 * d,
              height: 74 * d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
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
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 44 * d,
                    color: _ink,
                  ),
                  Positioned(
                    right: -2 * d,
                    top: -4 * d,
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
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17 * d,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 38 * d),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 76 * d,
              height: 76 * d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF1B2F6E), Color(0xFF060B1E)],
                  center: Alignment(-0.3, -0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B1A4A).withValues(alpha: 0.3),
                    blurRadius: 12 * d,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF7FB2FF), Color(0xFF1F5BFF)],
                ).createShader(r),
                child: Text(
                  'G',
                  style: TextStyle(
                    fontSize: 46 * d,
                    height: 1,
                    fontWeight: FontWeight.w800,
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

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.d, required this.orders});
  final double d;
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(42 * d, 0, 32 * d, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 48 * d,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -1 * d,
                  ),
                ),
                SizedBox(height: 8 * d),
                Text(
                  'Track, manage and explore your orders',
                  style: TextStyle(fontSize: 22 * d, color: _muted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showHistory(context, orders),
            child: Container(
              height: 60 * d,
              padding: EdgeInsets.symmetric(horizontal: 24 * d),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30 * d),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
                    blurRadius: 14 * d,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 34 * d, color: _blue),
                  SizedBox(width: 12 * d),
                  Text(
                    'Order History',
                    style: TextStyle(
                      fontSize: 21 * d,
                      fontWeight: FontWeight.w700,
                      color: _blue,
                    ),
                  ),
                  SizedBox(width: 10 * d),
                  Icon(Icons.arrow_forward_rounded, size: 28 * d, color: _blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showHistory(BuildContext context, List<Order> orders) {
  final byMonth = <String, List<Order>>{};
  for (final o in orders) {
    byMonth
        .putIfAbsent(DateFormat('MMMM yyyy').format(o.createdAt), () => [])
        .add(o);
  }
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text(
            'Order History',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${orders.length} orders • ${formatPrice(orders.fold(0.0, (s, o) => s + o.total))} spent',
            style: const TextStyle(color: _muted),
          ),
          for (final e in byMonth.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Text(
                e.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ),
            for (final o in e.value)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: AppImage(
                    o.items.first.product.images.first,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                title: Text(
                  o.items.first.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('#${o.id} • ${orderStatusLabel(o.status)}'),
                trailing: Text(
                  formatPrice(o.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(c);
                  context.push('/order/${o.id}');
                },
              ),
          ],
        ],
      ),
    ),
  );
}

// ───────────────────────────── Stats ─────────────────────────────

class _Stats extends StatelessWidget {
  const _Stats({required this.d, required this.orders});
  final double d;
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ic3d_cart', orders.length, 'Total Orders', const Color(0xFF1F5BFF)),
      (
        'ic3d_parcel',
        orders.where((o) => o.isDelivered).length,
        'Delivered',
        const Color(0xFF9B3DF5),
      ),
      (
        'ic3d_truck2',
        orders.where((o) => o.isShipped).length,
        'In Transit',
        const Color(0xFFFF7A00),
      ),
      (
        'ic3d_return2',
        orders.where((o) => o.isReturned).length,
        'Returns',
        const Color(0xFF22B455),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 36 * d),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 18 * d),
            Expanded(
              child: Container(
                height: 136 * d,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28 * d),
                  border: Border.all(color: Colors.white, width: 1.6),
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 1.1,
                    colors: [
                      items[i].$4.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2A3D8F).withValues(alpha: 0.07),
                      blurRadius: 16 * d,
                      offset: Offset(0, 6 * d),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      '$_img/${items[i].$1}.png',
                      width: 58 * d,
                      height: 58 * d,
                    ),
                    Text(
                      '${items[i].$2}',
                      style: TextStyle(
                        fontSize: 34 * d,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      items[i].$3,
                      style: TextStyle(fontSize: 20 * d, color: _ink),
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

// ───────────────────────────── AI assistant banner ─────────────────────────────

class _AssistantBanner extends StatefulWidget {
  const _AssistantBanner({required this.d});
  final double d;

  @override
  State<_AssistantBanner> createState() => _AssistantBannerState();
}

class _AssistantBannerState extends State<_AssistantBanner> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ask() {
    FocusScope.of(context).unfocus();
    showOrderAssistant(
      context,
      question: _c.text.trim().isEmpty ? 'Where is my order?' : _c.text.trim(),
    );
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 33 * d),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36 * d),
        child: Container(
          height: 227 * d,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F63FE),
                Color(0xFF0050C4),
                Color(0xFF062A7E),
                Color(0xFF4E7BD5),
              ],
              stops: [0, 0.35, 0.8, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 359 * d,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0, 0.88, 1],
                  ).createShader(r),
                  child: Image.asset(
                    '$_img/orders_robot.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              Positioned(
                left: 372 * d,
                right: 22 * d,
                top: 25 * d,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 40 * d,
                          padding: EdgeInsets.symmetric(horizontal: 16 * d),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F5BFF),
                            borderRadius: BorderRadius.circular(20 * d),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 24 * d,
                              ),
                              SizedBox(width: 8 * d),
                              Text(
                                'AI Order Assistant',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18 * d,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16 * d),
                        Container(
                          width: 14 * d,
                          height: 14 * d,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8 * d),
                        Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17 * d,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16 * d),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Need help with your order?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27 * d,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * d),
                    Text(
                      'Ask anything about your order status...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 19 * d,
                      ),
                    ),
                    SizedBox(height: 16 * d),
                    Container(
                      height: 58 * d,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(29 * d),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12 * d,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 22 * d),
                          Expanded(
                            child: TextField(
                              controller: _c,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _ask(),
                              style: TextStyle(fontSize: 19 * d, color: _ink),
                              decoration: InputDecoration(
                                hintText: 'e.g. Where is my order?',
                                hintStyle: TextStyle(
                                  fontSize: 19 * d,
                                  color: const Color(0xFF7A84A3),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _ask,
                            child: Container(
                              width: 46 * d,
                              height: 46 * d,
                              margin: EdgeInsets.only(right: 6 * d),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1F5BFF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 28 * d,
                              ),
                            ),
                          ),
                        ],
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
  }
}

// ───────────────────────────── Tabs ─────────────────────────────

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.d,
    required this.orders,
    required this.tab,
    required this.onTab,
  });
  final double d;
  final List<Order> orders;
  final _Tab tab;
  final ValueChanged<_Tab> onTab;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_Tab.all, Icons.shopping_bag_outlined, 'All Orders', orders.length),
      (
        _Tab.processing,
        Icons.schedule_rounded,
        'Processing',
        orders.where((o) => o.isProcessing).length,
      ),
      (
        _Tab.shipped,
        Icons.local_shipping_outlined,
        'Shipped',
        orders.where((o) => o.isShipped).length,
      ),
      (
        _Tab.delivered,
        Icons.check_circle_outline_rounded,
        'Delivered',
        orders.where((o) => o.isDelivered).length,
      ),
      (
        _Tab.returns,
        Icons.assignment_return_outlined,
        'Returns',
        orders.where((o) => o.isReturned).length,
      ),
    ];
    return SizedBox(
      height: 64 * d,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 28 * d),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => SizedBox(width: 10 * d),
        itemBuilder: (_, i) {
          final t = tabs[i];
          final sel = t.$1 == tab;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTab(t.$1);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 22 * d),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32 * d),
                gradient: sel
                    ? const LinearGradient(
                        colors: [Color(0xFF2F6BFF), Color(0xFF1A4BEA)],
                      )
                    : null,
                color: sel ? null : Colors.white.withValues(alpha: 0.85),
                border: Border.all(
                  color: sel ? Colors.transparent : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (sel ? _blue : const Color(0xFF2A3D8F)).withValues(
                      alpha: sel ? 0.3 : 0.06,
                    ),
                    blurRadius: 14 * d,
                    offset: Offset(0, 5 * d),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(t.$2, size: 30 * d, color: sel ? Colors.white : _ink),
                  SizedBox(width: 12 * d),
                  Text(
                    t.$3,
                    style: TextStyle(
                      fontSize: 19 * d,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : _ink,
                    ),
                  ),
                  if (t.$4 > 0) ...[
                    SizedBox(width: 12 * d),
                    Container(
                      constraints: BoxConstraints(minWidth: 32 * d),
                      height: 32 * d,
                      padding: EdgeInsets.symmetric(horizontal: 8 * d),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : const Color(0xFFEFF2FA),
                        borderRadius: BorderRadius.circular(16 * d),
                      ),
                      child: Text(
                        '${t.$4}',
                        style: TextStyle(
                          fontSize: 17 * d,
                          fontWeight: FontWeight.w700,
                          color: sel ? _blue : _ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Order card ─────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.d});
  final Order order;
  final double d;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final item = o.items.first;
    final p = item.product;
    final fmt = DateFormat('d MMM yyyy');
    final dates = o.isDelivered
        ? 'Ordered: ${fmt.format(o.createdAt)}  •  Delivered: ${fmt.format(o.deliveredAt)}'
        : o.isShipped
        ? 'Ordered: ${fmt.format(o.createdAt)}  •  Delivery: ${fmt.format(o.expectedDelivery)}'
        : o.isReturned
        ? 'Ordered: ${fmt.format(o.createdAt)}  •  Refunded'
        : 'Ordered: ${fmt.format(o.createdAt)}  •  Processing...';
    final variant =
        item.size ?? [p.storage, p.colorName].whereType<String>().join('  •  ');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 33 * d),
      child: GestureDetector(
        onTap: () => context.push('/order/${o.id}'),
        child: Container(
          padding: EdgeInsets.fromLTRB(20 * d, 16 * d, 18 * d, 20 * d),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32 * d),
            border: Border.all(color: Colors.white, width: 1.8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FE)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
                blurRadius: 20 * d,
                offset: Offset(0, 8 * d),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusPill(o.status, scale: d),
                  const Spacer(),
                  Text(
                    'Order #${o.id}',
                    style: TextStyle(
                      fontSize: 17 * d,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  SizedBox(width: 10 * d),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: o.id));
                      showAppSnack(context, 'Order ID copied');
                    },
                    child: Icon(Icons.copy_rounded, size: 26 * d, color: _ink),
                  ),
                ],
              ),
              SizedBox(height: 14 * d),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 168 * d,
                    height: 140 * d,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20 * d),
                      color: const Color(0xFFEFF3FC),
                    ),
                    child: AppImage(
                      p.images.first,
                      borderRadius: BorderRadius.circular(20 * d),
                    ),
                  ),
                  SizedBox(width: 14 * d),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 26 * d,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  SizedBox(height: 4 * d),
                                  Text(
                                    variant,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20 * d,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10 * d),
                            _ActionButton(
                              d: d,
                              label: o.isShipped
                                  ? 'Track Order'
                                  : 'View Details',
                              onTap: () => context.push('/order/${o.id}'),
                            ),
                          ],
                        ),
                        SizedBox(height: 8 * d),
                        Row(
                          children: [
                            Text(
                              formatPrice(o.total),
                              style: TextStyle(
                                fontSize: 28 * d,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            if (p.discountPercent > 0) ...[
                              SizedBox(width: 10 * d),
                              Text(
                                formatPrice(p.mrp * item.quantity),
                                style: TextStyle(
                                  fontSize: 20 * d,
                                  color: const Color(0xFF8C95B0),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: const Color(0xFF8C95B0),
                                ),
                              ),
                              SizedBox(width: 12 * d),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14 * d,
                                  vertical: 4 * d,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD9F5E3),
                                  borderRadius: BorderRadius.circular(16 * d),
                                ),
                                child: Text(
                                  '${p.discountPercent}% OFF',
                                  style: TextStyle(
                                    fontSize: 18 * d,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF138A4A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 10 * d),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 20 * d,
                              color: _ink,
                            ),
                            SizedBox(width: 8 * d),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  dates,
                                  style: TextStyle(
                                    fontSize: 16.5 * d,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (o.items.length > 1)
                          Padding(
                            padding: EdgeInsets.only(top: 6 * d),
                            child: Text(
                              '+${o.items.length - 1} more item${o.items.length > 2 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 17 * d,
                                fontWeight: FontWeight.w600,
                                color: _blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16 * d),
              if (o.isDelivered)
                _DeliveredFooter(d: d, productId: p.id, variant: item.size)
              else if (o.isShipped)
                _Progress(d: d, step: 2)
              else
                _InfoBar(
                  d: d,
                  text: o.isReturned
                      ? 'Return completed. Refund sent to your original payment method.'
                      : 'Your order is being processed. We will notify you soon.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.d,
    required this.label,
    required this.onTap,
  });
  final double d;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58 * d,
        padding: EdgeInsets.symmetric(horizontal: 20 * d),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(29 * d),
          border: Border.all(color: const Color(0xFFD9E2F7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F).withValues(alpha: 0.08),
              blurRadius: 12 * d,
              offset: Offset(0, 4 * d),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 19 * d,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF13286B),
              ),
            ),
            SizedBox(width: 8 * d),
            Icon(
              Icons.arrow_forward_rounded,
              size: 26 * d,
              color: const Color(0xFF13286B),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveredFooter extends StatelessWidget {
  const _DeliveredFooter({
    required this.d,
    required this.productId,
    this.variant,
  });
  final double d;
  final String productId;
  final String? variant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76 * d,
      child: Row(
        children: [
          Expanded(
            flex: 505,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20 * d),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(20 * d),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 40 * d, color: _blue),
                  SizedBox(width: 14 * d),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivered Successfully',
                        style: TextStyle(
                          fontSize: 19 * d,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'Enjoy your new device!',
                        style: TextStyle(fontSize: 16 * d, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 6 * d),
          Expanded(
            flex: 238,
            child: GestureDetector(
              onTap: () => showWriteReviewSheet(
                context,
                productId: productId,
                variant: variant,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20 * d),
                  border: Border.all(color: const Color(0xFFE3E8F5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 5; i++)
                          Icon(
                            Icons.star_rounded,
                            size: 28 * d,
                            color: const Color(0xFFF7B500),
                          ),
                      ],
                    ),
                    Text(
                      'Rate Product →',
                      style: TextStyle(
                        fontSize: 15 * d,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.d, required this.step});
  final double d;
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Order Placed', 'Packed', 'Shipped', 'Out for Delivery'];
    const icons = [
      Icons.check_rounded,
      Icons.check_rounded,
      Icons.local_shipping_rounded,
      Icons.place_outlined,
    ];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12 * d),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FD),
        borderRadius: BorderRadius.circular(20 * d),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4 * d,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= step ? _blue : const Color(0xFFCBD3E6)),
                        ),
                      ),
                      Container(
                        width: 34 * d,
                        height: 34 * d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= step ? _blue : Colors.white,
                          border: Border.all(
                            color: i <= step
                                ? Colors.white
                                : const Color(0xFFB8C2DA),
                            width: 3 * d,
                          ),
                          boxShadow: i <= step
                              ? [
                                  BoxShadow(
                                    color: _blue.withValues(alpha: 0.3),
                                    blurRadius: 8 * d,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          icons[i],
                          size: 20 * d,
                          color: i <= step
                              ? Colors.white
                              : const Color(0xFF8C95B0),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 4 * d,
                          color: i == labels.length - 1
                              ? Colors.transparent
                              : (i < step ? _blue : const Color(0xFFCBD3E6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8 * d),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17 * d,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i == step ? _ink : _muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.d, required this.text});
  final double d;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18 * d, vertical: 12 * d),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(16 * d),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, size: 30 * d, color: AppColors.primary),
          SizedBox(width: 14 * d),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 18 * d, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}
