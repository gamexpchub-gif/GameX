import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../orders/orders_screen.dart' show OrderTile;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(sellerProvider);
    final orders = ref.watch(ordersProvider);
    final listings = ref.watch(listingsProvider);
    final live = ref.watch(liveProvider);
    final earn = ref.watch(earningsProvider);
    if (seller == null) return const SizedBox.shrink();

    final now = DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final counted = orders.where(
      (o) => o.stage != OrderStage.cancelled && o.stage != OrderStage.returned,
    );
    final todaySales = counted
        .where((o) => sameDay(o.placedAt))
        .fold<int>(0, (s, o) => s + o.price);
    final newOrders = orders
        .where((o) => o.stage == OrderStage.newOrder)
        .toList();
    final toShip = orders
        .where(
          (o) => o.stage == OrderStage.accepted || o.stage == OrderStage.packed,
        )
        .length;
    final active = listings
        .where((l) => l.status == ListingStatus.active)
        .length;
    final views = listings.fold<int>(0, (s, l) => s + l.views);
    final pendingLive = live.where((c) => c.stage == LiveStage.pending).length;
    final lowStock = listings.where((l) => l.lowStock).toList();

    final week = List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      return (
        d,
        counted
            .where(
              (o) =>
                  o.placedAt.year == d.year &&
                  o.placedAt.month == d.month &&
                  o.placedAt.day == d.day,
            )
            .fold<int>(0, (s, o) => s + o.price),
      );
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(seller: seller, available: earn.available),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _Kpi(
                      icon: Icons.currency_rupee_rounded,
                      color: C.primary,
                      label: "Today's sales",
                      value: inrShort(todaySales),
                      onTap: () => context.go('/earnings'),
                    ),
                    _Kpi(
                      icon: Icons.local_shipping_rounded,
                      color: C.violet,
                      label: 'Orders to ship',
                      value: '$toShip',
                      onTap: () => context.go('/orders?tab=ship'),
                    ),
                    _Kpi(
                      icon: Icons.inventory_2_rounded,
                      color: C.green,
                      label: 'Active listings',
                      value: '$active',
                      onTap: () => context.go('/listings'),
                    ),
                    _Kpi(
                      icon: Icons.visibility_rounded,
                      color: C.amber,
                      label: 'Store views (30d)',
                      value: views >= 1000
                          ? '${(views / 1000).toStringAsFixed(1)}K'
                          : '$views',
                    ),
                  ],
                ),
                if (newOrders.isNotEmpty ||
                    pendingLive > 0 ||
                    lowStock.isNotEmpty) ...[
                  const SectionTitle('Needs your attention'),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final o in newOrders)
                          _Alert(
                            icon: Icons.notifications_active_rounded,
                            color: C.amber,
                            title: 'New order ${o.id} • ${inr(o.price)}',
                            subtitle: timeLeft(o.slaDeadline) == null
                                ? 'Acceptance time passed — act now'
                                : 'Accept within ${timeLeft(o.slaDeadline)}',
                            onTap: () => context.push('/order/${o.id}'),
                          ),
                        if (pendingLive > 0)
                          _Alert(
                            icon: Icons.videocam_rounded,
                            color: C.red,
                            title:
                                '$pendingLive live review request${pendingLive > 1 ? 's' : ''}',
                            subtitle: 'Buyers want to see the phone live',
                            onTap: () => context.push('/live'),
                          ),
                        for (final l in lowStock.take(2))
                          _Alert(
                            icon: Icons.inventory_rounded,
                            color: C.violet,
                            title: '${l.title} — ${l.stock} left',
                            subtitle: 'Restock to keep the listing live',
                            onTap: () => context.push('/listing/${l.id}'),
                          ),
                      ],
                    ),
                  ),
                ],
                const SectionTitle('Sales this week'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            inr(week.fold<int>(0, (s, d) => s + d.$2)),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Pill(
                            '${earn.ordersMonth} orders / 30d',
                            color: C.green,
                            icon: Icons.trending_up_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(height: 150, child: _WeekBars(week: week)),
                    ],
                  ),
                ),
                const SectionTitle('Quick actions'),
                Row(
                  children: [
                    _Quick(
                      icon: Icons.add_box_rounded,
                      label: 'Add\nlisting',
                      color: C.primary,
                      onTap: () => context.push('/listing/new'),
                    ),
                    _Quick(
                      icon: Icons.videocam_rounded,
                      label: 'Live\nreviews',
                      color: C.red,
                      badge: pendingLive,
                      onTap: () => context.push('/live'),
                    ),
                    _Quick(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Pack\norders',
                      color: C.violet,
                      onTap: () => context.go('/orders?tab=ship'),
                    ),
                    _Quick(
                      icon: Icons.account_balance_rounded,
                      label: 'Get\npaid',
                      color: C.green,
                      onTap: () => context.go('/earnings'),
                    ),
                  ],
                ),
                SectionTitle(
                  'Recent orders',
                  action: 'All orders',
                  onAction: () => context.go('/orders'),
                ),
                for (final o in orders.take(3)) ...[
                  OrderTile(order: o),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.seller, required this.available});
  final Seller seller;
  final double available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Container(
      decoration: const BoxDecoration(
        gradient: C.nightGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 14,
        18,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: C.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  seller.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greet, ${seller.ownerName.split(' ').first}',
                      style: const TextStyle(
                        color: Color(0xFFB9C2FF),
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seller.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF5CB8FF),
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _OnlineSwitch(seller: seller),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ready to withdraw',
                        style: TextStyle(
                          color: Color(0xFFB9C2FF),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inr(available),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderStat(
                  icon: Icons.star_rounded,
                  value: seller.rating.toStringAsFixed(1),
                  label: 'Rating',
                ),
                const SizedBox(width: 14),
                const _HeaderStat(
                  icon: Icons.bolt_rounded,
                  value: '98%',
                  label: 'On-time',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFFC542), size: 16),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB9C2FF), fontSize: 11.5),
        ),
      ],
    );
  }
}

class _OnlineSwitch extends ConsumerWidget {
  const _OnlineSwitch({required this.seller});
  final Seller seller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref
            .read(sellerProvider.notifier)
            .save(seller.copyWith(online: !seller.online));
        snack(
          context,
          seller.online
              ? 'Store on holiday — listings hidden from buyers'
              : 'Store is live again',
          icon: seller.online ? Icons.beach_access_rounded : null,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (seller.online ? C.green : C.amber).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (seller.online ? C.green : C.amber).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: seller.online ? const Color(0xFF4ADE80) : C.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              seller.online ? 'Online' : 'Holiday',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: C.ink,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: C.faint),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: C.red,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.border),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: C.ink,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.week});
  final List<(DateTime, int)> week;

  @override
  Widget build(BuildContext context) {
    final max = week.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < week.length; i++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (week[i].$2 > 0)
                  Text(
                    inrShort(week[i].$2).replaceAll('₹', ''),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: C.muted,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  height: 6 + 96 * week[i].$2 / max,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    gradient: i == week.length - 1
                        ? C.brandGradient
                        : LinearGradient(
                            colors: [
                              C.primary.withValues(alpha: 0.35),
                              C.violet.withValues(alpha: 0.25),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  i == week.length - 1 ? 'Today' : days[week[i].$1.weekday - 1],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == week.length - 1
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i == week.length - 1 ? C.primary : C.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
