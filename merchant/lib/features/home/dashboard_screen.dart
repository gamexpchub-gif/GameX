import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/server_sheet.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../listings/widgets/listing_ui.dart';
import '../orders/orders_screen.dart' show OrderTile;

const _kGoal = 'monthly_goal_v1';

/// Monthly sales target the seller sets for themselves.
class GoalNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.read(localStoreProvider).readJson(_kGoal, (j) => j as int) ?? 500000;

  void set(int v) {
    state = v;
    ref.read(localStoreProvider).writeJson(_kGoal, v);
  }
}

final goalProvider = NotifierProvider<GoalNotifier, int>(GoalNotifier.new);

/// Seller level by 30-day sales.
const _levels = [
  ('Bronze', 0, Color(0xFFB7791F)),
  ('Silver', 200000, Color(0xFF64748B)),
  ('Gold', 500000, Color(0xFFD69E2E)),
  ('Platinum', 1500000, Color(0xFF6A3DF5)),
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(sellerProvider);
    final data = ref.watch(syncProvider);
    final earn = ref.watch(earningsProvider);
    if (seller == null) return const SizedBox.shrink();

    final orders = data.orders;
    final listings = data.listings;
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final counted = orders.where(
      (o) => o.stage != OrderStage.cancelled && o.stage != OrderStage.returned,
    );
    final todaySales = counted
        .where((o) => sameDay(o.placedAt, now))
        .fold<int>(0, (s, o) => s + o.price);
    final yesterdaySales = counted
        .where(
          (o) => sameDay(o.placedAt, now.subtract(const Duration(days: 1))),
        )
        .fold<int>(0, (s, o) => s + o.price);
    final newOrders = orders
        .where((o) => o.stage == OrderStage.newOrder)
        .length;
    final toPack = orders.where((o) => o.stage == OrderStage.accepted).length;
    final toShip = orders.where((o) => o.stage == OrderStage.packed).length;
    final active = listings.where((l) => l.status == ListingStatus.active);
    final views = listings.fold<int>(0, (s, l) => s + l.views);
    final pendingLive = data.live
        .where((c) => c.stage == LiveStage.pending)
        .length;
    final liveToday = data.live
        .where((c) => c.stage == LiveStage.confirmed && sameDay(c.slot, now))
        .length;
    final inReview = listings
        .where((l) => l.status == ListingStatus.inReview)
        .toList();
    final rejected = listings
        .where((l) => l.status == ListingStatus.rejected)
        .toList();
    final unread = data.notices.where((n) => !n.read).length;
    final announcements = data.notices.where((n) => n.isAnnouncement).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: LxBackground(
        child: RefreshIndicator(
          onRefresh: () => ref.read(syncProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  seller: seller,
                  data: data,
                  available: earn.available,
                  unread: unread,
                  todaySales: todaySales,
                  yesterdaySales: yesterdaySales,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                sliver: SliverList.list(
                  children: [
                    if (data.error != null) _OfflineBanner(error: data.error!),
                    if (seller.status != SellerStatus.approved)
                      _AccountBanner(seller: seller),
                    _TodayTasks(
                      tasks: [
                        _Task(
                          Icons.notifications_active_rounded,
                          C.amber,
                          'Accept new orders',
                          newOrders,
                          () => context.go('/orders?tab=new'),
                        ),
                        _Task(
                          Icons.inventory_rounded,
                          C.primary,
                          'Verify IMEI & pack',
                          toPack,
                          () => context.go('/orders?tab=ship'),
                        ),
                        _Task(
                          Icons.local_shipping_rounded,
                          C.violet,
                          'Book courier pickup',
                          toShip,
                          () => context.go('/orders?tab=ship'),
                        ),
                        _Task(
                          Icons.videocam_rounded,
                          C.red,
                          'Live review requests',
                          pendingLive + liveToday,
                          () => context.push('/live'),
                        ),
                        _Task(
                          Icons.edit_note_rounded,
                          C.cyan,
                          'Fix rejected listings',
                          rejected.length,
                          () => context.go('/listings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.36,
                      children: [
                        _Kpi(
                          icon: Icons.receipt_long_rounded,
                          color: C.primary,
                          label: 'Orders (30d)',
                          value: '${earn.ordersMonth}',
                          onTap: () => context.go('/orders'),
                        ),
                        _Kpi(
                          icon: Icons.inventory_2_rounded,
                          color: C.green,
                          label: 'Live listings',
                          value: '${active.length}',
                          onTap: () => context.go('/listings'),
                        ),
                        _Kpi(
                          icon: Icons.visibility_rounded,
                          color: C.amber,
                          label: 'Store views',
                          value: views >= 1000
                              ? '${(views / 1000).toStringAsFixed(1)}K'
                              : '$views',
                        ),
                        _Kpi(
                          icon: Icons.percent_rounded,
                          color: C.violet,
                          label: 'View → order',
                          value: views == 0
                              ? '0%'
                              : '${(earn.ordersMonth * 100 / views).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _SellCard(),
                    if (announcements.isNotEmpty) ...[
                      const _Title('From GAMEX'),
                      _Announcements(items: announcements),
                    ],
                    const _Title('Sales'),
                    _SalesCard(orders: counted.toList()),
                    const _Title('Growth'),
                    _ScoreCard(
                      rating: seller.rating,
                      cancelRate: orders.isEmpty
                          ? 0
                          : orders
                                    .where(
                                      (o) => o.events.any(
                                        (e) => e.label.startsWith(
                                          'Rejected by seller',
                                        ),
                                      ),
                                    )
                                    .length *
                                100 /
                                orders.length,
                      qcPass: () {
                        final checked = listings.where(
                          (l) =>
                              l.status != ListingStatus.inReview &&
                              l.status != ListingStatus.draft,
                        );
                        return checked.isEmpty
                            ? 1.0
                            : checked
                                      .where(
                                        (l) =>
                                            l.status != ListingStatus.rejected,
                                      )
                                      .length /
                                  checked.length;
                      }(),
                      liveConv: () {
                        final done = data.live.where(
                          (c) => c.stage == LiveStage.done,
                        );
                        return done.isEmpty
                            ? 0.0
                            : done.where((c) => c.converted == true).length /
                                  done.length;
                      }(),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _GoalCard(month: _monthSales(counted, now)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _LevelCard(gmv30: earn.grossMonth)),
                        ],
                      ),
                    ),
                    if (inReview.isNotEmpty || rejected.isNotEmpty) ...[
                      _Title(
                        'Quality check',
                        action: 'Listings',
                        onAction: () => context.go('/listings'),
                      ),
                      _QcCard(inReview: inReview, rejected: rejected),
                    ],
                    const _Title('Quick actions'),
                    const _QuickGrid(),
                    if (active.isNotEmpty) ...[
                      const _Title('Top listings'),
                      _TopListings(listings: active.toList()),
                    ],
                    const _Title('Inventory health'),
                    _InventoryHealth(listings: listings),
                    if (data.insights.demand.isNotEmpty ||
                        data.insights.pricing.isNotEmpty) ...[
                      const _Title('Market insights'),
                      _Insights(insights: data.insights),
                    ],
                    _Title(
                      'Recent orders',
                      action: 'All orders',
                      onAction: () => context.go('/orders'),
                    ),
                    if (orders.isEmpty)
                      const LxCard(
                        child: EmptyView(
                          icon: Icons.receipt_long_rounded,
                          title: 'No orders yet',
                          text: 'Approved listings appear in the GAMEX app. Orders will show up here.',
                        ),
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
        ),
      ),
    );
  }

  static int _monthSales(Iterable<SellerOrder> orders, DateTime now) => orders
      .where(
        (o) => o.placedAt.year == now.year && o.placedAt.month == now.month,
      )
      .fold<int>(0, (s, o) => s + o.price);
}

// ------------------------------------------------------------------ header

class _Header extends ConsumerWidget {
  const _Header({
    required this.seller,
    required this.data,
    required this.available,
    required this.unread,
    required this.todaySales,
    required this.yesterdaySales,
  });
  final Seller seller;
  final SellerData data;
  final double available;
  final int unread;
  final int todaySales;
  final int yesterdaySales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final change = yesterdaySales == 0
        ? null
        : (todaySales - yesterdaySales) * 100 / yesterdaySales;
    return _LiquidHeader(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 12,
          12,
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
                          if (seller.status == SellerStatus.approved) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF5CB8FF),
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _OnlineSwitch(seller: seller),
                IconButton(
                  onPressed: () => _showNotices(context, ref),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    backgroundColor: C.red,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's sales",
                          style: TextStyle(
                            color: Color(0xFFB9C2FF),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inr(todaySales),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          change == null
                              ? 'vs ${inr(yesterdaySales)} yesterday'
                              : '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% vs yesterday',
                          style: TextStyle(
                            color: change == null
                                ? Colors.white60
                                : change >= 0
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFF8A8A),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SyncChip(data: data),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                children: [
                  _HeaderTile(
                    label: 'Withdrawable',
                    value: inrShort(available),
                    icon: Icons.account_balance_wallet_rounded,
                    onTap: () => context.go('/earnings'),
                  ),
                  const SizedBox(width: 8),
                  _HeaderTile(
                    label: 'Rating',
                    value: seller.rating == 0
                        ? 'New'
                        : seller.rating.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                  ),
                  const SizedBox(width: 8),
                  _HeaderTile(
                    label: 'Payout',
                    value: _nextMonday(),
                    icon: Icons.event_available_rounded,
                    onTap: () => context.go('/earnings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _nextMonday() {
    final n = DateTime.now();
    final d = (8 - n.weekday) % 7;
    return dateShort(n.add(Duration(days: d == 0 ? 7 : d)));
  }

  void _showNotices(BuildContext context, WidgetRef ref) {
    final notices = ref.read(noticesProvider);
    if (notices.any((n) => !n.read)) {
      ref.read(syncProvider.notifier).markNoticesRead().ignore();
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scroll) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notices.isEmpty
                  ? const EmptyView(
                      icon: Icons.notifications_off_outlined,
                      title: 'All caught up',
                      text: 'Order, QC and payout alerts appear here.',
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: notices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = notices[i];
                        final (icon, color) = _noticeStyle(n.kind);
                        return LxCard(
                          padding: const EdgeInsets.all(12),
                          color: n.read
                              ? Colors.white
                              : C.primary.withValues(alpha: 0.04),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (n.body.isNotEmpty)
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                          color: C.muted,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ago(n.at),
                                      style: const TextStyle(
                                        color: C.faint,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color) _noticeStyle(String kind) => switch (kind) {
  'order' => (Icons.receipt_long_rounded, C.primary),
  'live' => (Icons.videocam_rounded, C.red),
  'qc' => (Icons.verified_rounded, C.green),
  'payout' => (Icons.payments_rounded, C.green),
  'account' => (Icons.badge_rounded, C.violet),
  'promo' => (Icons.local_offer_rounded, C.amber),
  'feature' => (Icons.auto_awesome_rounded, C.violet),
  'announcement' => (Icons.campaign_rounded, C.cyan),
  _ => (Icons.info_outline_rounded, C.muted),
};

class _SyncChip extends ConsumerWidget {
  const _SyncChip({required this.data});
  final SellerData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = data.error == null && data.loaded;
    return GestureDetector(
      onTap: () => ok
          ? ref.read(syncProvider.notifier).refresh()
          : showServerSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.syncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                size: 14,
                color: ok ? const Color(0xFF4ADE80) : const Color(0xFFFFB4B4),
              ),
            const SizedBox(width: 5),
            Text(
              data.syncing
                  ? 'Syncing'
                  : ok
                  ? 'Synced ${ago(data.syncedAt!)}'
                  : 'Offline',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderTile extends StatelessWidget {
  const _HeaderTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: const Color(0xFFFFC542)),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFB9C2FF), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineSwitch extends ConsumerWidget {
  const _OnlineSwitch({required this.seller});
  final Seller seller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = seller.online ? C.green : C.amber;
    return GestureDetector(
      onTap: () => runAction(
        context,
        () => ref
            .read(syncProvider.notifier)
            .updateSeller(seller.copyWith(online: !seller.online)),
        done: seller.online
            ? 'Holiday mode — listings hidden from buyers'
            : 'Store is live again',
        icon: seller.online ? Icons.beach_access_rounded : null,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: seller.online ? const Color(0xFF4ADE80) : C.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              seller.online ? 'Online' : 'Holiday',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ banners

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LxCard(
        color: C.red.withValues(alpha: 0.06),
        padding: const EdgeInsets.all(12),
        onTap: () => showServerSheet(context),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: C.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$error — showing saved data. Tap to check the server address.',
                style: const TextStyle(
                  color: C.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountBanner extends StatelessWidget {
  const _AccountBanner({required this.seller});
  final Seller seller;

  @override
  Widget build(BuildContext context) {
    final suspended = seller.status == SellerStatus.suspended;
    final c = suspended ? C.red : C.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LxCard(
        color: c.withValues(alpha: 0.07),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              suspended ? Icons.block_rounded : Icons.hourglass_top_rounded,
              color: c,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suspended ? 'Account suspended' : 'KYC under review',
                    style: TextStyle(fontWeight: FontWeight.w800, color: c),
                  ),
                  Text(
                    suspended
                        ? (seller.suspendReason ?? 'Contact seller support.')
                        : 'Add listings now — they go live once GAMEX approves your account and each phone passes QC.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: C.ink,
                      height: 1.35,
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

// ------------------------------------------------------------------ tasks

class _Task {
  const _Task(this.icon, this.color, this.label, this.count, this.onTap);
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final VoidCallback onTap;
}

class _TodayTasks extends StatelessWidget {
  const _TodayTasks({required this.tasks});
  final List<_Task> tasks;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((t) => t.count > 0).toList();
    return LxCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Today's to-do",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Pill(
                open.isEmpty
                    ? 'All done'
                    : '${open.fold<int>(0, (s, t) => s + t.count)} pending',
                color: open.isEmpty ? C.green : C.amber,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (open.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.celebration_rounded, color: C.green),
                  SizedBox(width: 10),
                  Text(
                    'Nothing pending. Great job!',
                    style: TextStyle(color: C.muted),
                  ),
                ],
              ),
            ),
          for (final t in open)
            InkWell(
              onTap: t.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _GIcon(t.icon, colors: _grad(t.color), size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: t.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${t.count}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: C.faint),
                  ],
                ),
              ),
            ),
        ],
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
    return LxCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GIcon(icon, colors: _grad(color), size: 38),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: LX.ink,
              letterSpacing: -0.4,
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

// ------------------------------------------------------------------ announcements

class _Announcements extends StatelessWidget {
  const _Announcements({required this.items});
  final List<Notice> items;

  @override
  Widget build(BuildContext context) {
    const gradients = [
      [Color(0xFF1F5BFF), Color(0xFF6A3DF5)],
      [Color(0xFFF59E0B), Color(0xFFEC4899)],
      [Color(0xFF0891B2), Color(0xFF16A34A)],
    ];
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final n = items[i];
          final (icon, _) = _noticeStyle(n.kind);
          return Container(
            width: MediaQuery.sizeOf(context).width * 0.78,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradients[i % gradients.length]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ sales chart

class _SalesCard extends StatefulWidget {
  const _SalesCard({required this.orders});
  final List<SellerOrder> orders;

  @override
  State<_SalesCard> createState() => _SalesCardState();
}

class _SalesCardState extends State<_SalesCard> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(_days, (i) {
      final d = DateTime(now.year, now.month, now.day - (_days - 1 - i));
      final list = widget.orders.where(
        (o) =>
            o.placedAt.year == d.year &&
            o.placedAt.month == d.month &&
            o.placedAt.day == d.day,
      );
      return (d, list.fold<int>(0, (s, o) => s + o.price), list.length);
    });
    final total = days.fold<int>(0, (s, d) => s + d.$2);
    final count = days.fold<int>(0, (s, d) => s + d.$3);
    return LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inr(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$count orders • avg ${inr(count == 0 ? 0 : total ~/ count)}',
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 7, label: Text('7D')),
                  ButtonSegment(value: 30, label: Text('30D')),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: _Bars(days: days, labelEvery: _days == 7 ? 1 : 5),
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.days, required this.labelEvery});
  final List<(DateTime, int, int)> days;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(1, (m, d) => math.max(m, d.$2));
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (labelEvery == 1 && days[i].$2 > 0)
                  Text(
                    inrShort(days[i].$2).replaceAll('₹', ''),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: C.muted,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  height: 5 + 100 * days[i].$2 / max,
                  margin: EdgeInsets.symmetric(
                    horizontal: labelEvery == 1 ? 7 : 1.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: i == days.length - 1
                        ? C.brandGradient
                        : LinearGradient(
                            colors: [
                              C.primary.withValues(alpha: 0.35),
                              C.violet.withValues(alpha: 0.25),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                    borderRadius: BorderRadius.circular(
                      labelEvery == 1 ? 8 : 3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 14,
                  child: (days.length - 1 - i) % labelEvery == 0
                      ? Text(
                          i == days.length - 1
                              ? 'Today'
                              : labelEvery == 1
                              ? wd[days[i].$1.weekday - 1]
                              : '${days[i].$1.day}',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == days.length - 1
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: i == days.length - 1 ? C.primary : C.muted,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ growth

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.month});
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(goalProvider);
    final p = (month / goal).clamp(0.0, 1.0);
    return LxCard(
      onTap: () => _edit(context, ref, goal),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly goal',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(Icons.edit_rounded, size: 15, color: C.faint),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: p,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: C.border,
                    color: p >= 1 ? C.green : C.primary,
                  ),
                  Center(
                    child: Text(
                      '${(p * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            inrShort(month),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            'of ${inrShort(goal)} this month',
            style: const TextStyle(color: C.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, int goal) async {
    final c = TextEditingController(text: '$goal');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Monthly sales goal'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, int.tryParse(c.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) ref.read(goalProvider.notifier).set(v);
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.gmv30});
  final double gmv30;

  @override
  Widget build(BuildContext context) {
    var idx = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (gmv30 >= _levels[i].$2) idx = i;
    }
    final cur = _levels[idx];
    final next = idx + 1 < _levels.length ? _levels[idx + 1] : null;
    final p = next == null
        ? 1.0
        : ((gmv30 - cur.$2) / (next.$2 - cur.$2)).clamp(0.0, 1.0);
    return LxCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seller level',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [cur.$3, cur.$3.withValues(alpha: 0.6)],
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cur.$1,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: cur.$3,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 7,
              backgroundColor: C.border,
              color: cur.$3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'Top level reached'
                : '${inrShort(next.$2 - gmv30)} more to ${next.$1}',
            style: const TextStyle(color: C.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ QC

class _QcCard extends StatelessWidget {
  const _QcCard({required this.inReview, required this.rejected});
  final List<Listing> inReview;
  final List<Listing> rejected;

  @override
  Widget build(BuildContext context) {
    return LxCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final l in [...rejected, ...inReview].take(4))
            ListTile(
              onTap: () => context.push('/listing/${l.id}'),
              leading: Photo(
                l.photos.isEmpty ? '' : l.photos.first,
                size: 46,
                radius: 12,
              ),
              title: Text(
                l.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                l.status == ListingStatus.rejected
                    ? (l.rejectReason ?? 'Needs changes')
                    : 'GAMEX team is checking photos, IMEI & price',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: l.status == ListingStatus.rejected ? C.red : C.muted,
                ),
              ),
              trailing: l.status == ListingStatus.rejected
                  ? const Pill('Fix', color: C.red, icon: Icons.edit_rounded)
                  : const Pill('In review', color: C.amber),
            ),
        ],
      ),
    );
  }
}

class _QuickGrid extends ConsumerWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingLive = ref
        .watch(liveProvider)
        .where((c) => c.stage == LiveStage.pending)
        .length;
    final items = [
      (
        Icons.add_box_rounded,
        'Add\nlisting',
        C.primary,
        () => context.push('/listing/new'),
        0,
      ),
      (
        Icons.videocam_rounded,
        'Live\nreviews',
        C.red,
        () => context.push('/live'),
        pendingLive,
      ),
      (
        Icons.qr_code_scanner_rounded,
        'Pack\norders',
        C.violet,
        () => context.go('/orders?tab=ship'),
        0,
      ),
      (
        Icons.account_balance_rounded,
        'Get\npaid',
        C.green,
        () => context.go('/earnings'),
        0,
      ),
      (
        Icons.forum_rounded,
        'Buyer\nQ&A',
        C.cyan,
        () => context.push('/questions'),
        ref.watch(openQuestionsProvider),
      ),
      (
        Icons.assignment_return_rounded,
        'Returns',
        C.amber,
        () => context.go('/orders?tab=issues'),
        0,
      ),
      (
        Icons.storefront_rounded,
        'My\nstore',
        C.ink,
        () => context.go('/account'),
        0,
      ),
      (
        Icons.handshake_rounded,
        'Buyer\noffers',
        C.amber,
        () => context.push('/offers'),
        ref.watch(pendingOffersProvider),
      ),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      childAspectRatio: 0.82,
      children: [
        for (final it in items)
          GestureDetector(
            onTap: it.$4,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Badge(
                  isLabelVisible: it.$5 > 0,
                  label: Text('${it.$5}'),
                  backgroundColor: C.red,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: LX.soft(0.10),
                    ),
                    alignment: Alignment.center,
                    child: _GIcon(it.$1, colors: _grad(it.$3), size: 40),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  it.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: C.ink,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopListings extends StatelessWidget {
  const _TopListings({required this.listings});
  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    final top = [...listings]
      ..sort(
        (a, b) => (b.sold * 100 + b.views).compareTo(a.sold * 100 + a.views),
      );
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: math.min(top.length, 6),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final l = top[i];
          return SizedBox(
            width: 150,
            child: LxCard(
              onTap: () => context.push('/listing/${l.id}'),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Photo(
                        l.photos.isEmpty ? '' : l.photos.first,
                        size: 130,
                        radius: 12,
                        pad: 10,
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: C.ink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    l.model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${l.views} views • ${l.sold} sold',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InventoryHealth extends StatelessWidget {
  const _InventoryHealth({required this.listings});
  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    final active = listings
        .where((l) => l.status == ListingStatus.active)
        .toList();
    final aging = active.where((l) => l.ageDays >= 30).length;
    final low = active.where((l) => l.stock <= 1).length;
    final out = listings.where((l) => l.status == ListingStatus.soldOut).length;
    final paused = listings
        .where((l) => l.status == ListingStatus.paused)
        .length;
    final healthy = active.length - aging - low;
    final score = listings.isEmpty
        ? 100
        : (math.max(0, healthy) * 100 / math.max(1, active.length)).round();
    Widget row(IconData i, Color c, String t, int n, String hint) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(i, color: c, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  hint,
                  style: const TextStyle(color: C.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '$n',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: n == 0 ? C.faint : c,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
    return LxCard(
      onTap: () => context.go('/listings'),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Health score',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$score/100',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: score >= 70
                      ? C.green
                      : score >= 40
                      ? C.amber
                      : C.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 7,
              backgroundColor: C.border,
              color: score >= 70
                  ? C.green
                  : score >= 40
                  ? C.amber
                  : C.red,
            ),
          ),
          const SizedBox(height: 6),
          row(
            Icons.hourglass_bottom_rounded,
            C.amber,
            'Aging stock',
            aging,
            'Listed 30+ days — consider a price drop',
          ),
          row(
            Icons.inventory_rounded,
            C.violet,
            'Low stock',
            low,
            '1 unit or less left',
          ),
          row(
            Icons.remove_shopping_cart_rounded,
            C.red,
            'Sold out',
            out,
            'Restock to get back in search',
          ),
          row(
            Icons.pause_circle_outline_rounded,
            C.muted,
            'Paused',
            paused,
            'Hidden from buyers',
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.insights});
  final Insights insights;

  @override
  Widget build(BuildContext context) {
    final maxOrders = insights.demand.fold<int>(
      1,
      (m, d) => math.max(m, d.orders),
    );
    return LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (insights.demand.isNotEmpty) ...[
            const Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: C.red,
                  size: 19,
                ),
                SizedBox(width: 6),
                Text(
                  'In demand on GAMEX',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final d in insights.demand)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: d.orders / maxOrders,
                          minHeight: 8,
                          backgroundColor: C.border,
                          color: C.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${d.orders}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (insights.pricing.isNotEmpty) ...[
            const Divider(height: 20),
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: C.violet, size: 19),
                SizedBox(width: 6),
                Text(
                  'Price check',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in insights.pricing)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => context.push('/listing/${p.id}'),
                title: Text(
                  p.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Yours ${inr(p.price)} • market avg ${inr(p.market)}',
                ),
                trailing: Pill(
                  p.price > p.market
                      ? '${((p.price - p.market) * 100 / p.market).round()}% higher'
                      : '${((p.market - p.price) * 100 / p.market).round()}% lower',
                  color: p.price > p.market ? C.amber : C.green,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 3D liquid pieces

/// Gradient header shell with glossy highlight, glow blobs and a 3D phone.
class _LiquidHeader extends StatelessWidget {
  const _LiquidHeader({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const r = BorderRadius.vertical(bottom: Radius.circular(34));
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C2BD9).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF14104A),
                      Color(0xFF3B23B8),
                      Color(0xFF2F6BFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -60,
              top: -40,
              child: _Glow(
                color: const Color(0xFFB57BFF).withValues(alpha: 0.45),
                size: 240,
              ),
            ),
            Positioned(
              left: -70,
              bottom: -90,
              child: _Glow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.30),
                size: 260,
              ),
            ),
            Positioned(
              right: -24,
              top: MediaQuery.paddingOf(context).top + 52,
              child: Opacity(
                opacity: 0.55,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const RadialGradient(
                    radius: 0.7,
                    colors: [Colors.black, Colors.transparent],
                    stops: [0.55, 1],
                  ).createShader(r),
                  child: Image.asset(
                    'assets/img/listing/hero_details.png',
                    width: 190,
                  ),
                ),
              ),
            ),
            // Glossy top highlight ("liquid glass").
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

/// Section title with a gradient accent bar and optional "View all" pill.
class _Title extends StatelessWidget {
  const _Title(this.title, {this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              gradient: LX.chip,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LX.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6DDFE)),
                ),
                child: Row(
                  children: [
                    Text(
                      action!,
                      style: const TextStyle(
                        color: LX.violet,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: LX.violet,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Gradient icon in a soft rounded square.
class _GIcon extends StatelessWidget {
  const _GIcon(
    this.icon, {
    this.colors = const [Color(0xFF2F6BFF), Color(0xFF8E3DFF)],
    this.size = 40,
  });
  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.32),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.52),
  );
}

/// Colour pairs for gradient icons.
const _gBlue = [Color(0xFF38BDF8), Color(0xFF2F6BFF)];
const _gViolet = [Color(0xFFA78BFA), Color(0xFF7B3DF5)];
const _gGreen = [Color(0xFF34D399), Color(0xFF16A34A)];
const _gAmber = [Color(0xFFFCD34D), Color(0xFFF59E0B)];
const _gRed = [Color(0xFFFB7185), Color(0xFFE11D48)];
const _gCyan = [Color(0xFF67E8F9), Color(0xFF0891B2)];

/// "List a phone" promo with a 3D illustration.
class _SellCard extends StatelessWidget {
  const _SellCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFF3EEFF), Color(0xFFE9F2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: LX.soft(0.10),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sell your next phone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LX.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Photos → details → price. GAMEX QC checks it and it goes live in the app.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: LX.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 170,
                  child: LxButton(
                    label: 'Add Listing',
                    icon: Icons.add_rounded,
                    height: 44,
                    onTap: () => context.push('/listing/new'),
                  ),
                ),
              ],
            ),
          ),
          Image.asset('assets/img/listing/hero_photos.png', width: 128),
        ],
      ),
    );
  }
}

/// Overall seller score from rating, dispatch, cancellations and QC.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.rating,
    required this.cancelRate,
    required this.qcPass,
    required this.liveConv,
  });
  final double rating;
  final double cancelRate;
  final double qcPass;
  final double liveConv;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (
        'Rating',
        rating == 0 ? 0.8 : rating / 5,
        rating == 0 ? 'New' : rating.toStringAsFixed(1),
      ),
      (
        'Low cancels',
        (1 - cancelRate / 20).clamp(0.0, 1.0),
        '${cancelRate.toStringAsFixed(1)}%',
      ),
      ('QC pass', qcPass, '${(qcPass * 100).round()}%'),
      ('Live → sale', liveConv, '${(liveConv * 100).round()}%'),
    ];
    final score =
        (parts.fold<double>(0, (s, p) => s + p.$2) / parts.length * 100)
            .round();
    final color = score >= 80
        ? LX.green
        : score >= 60
        ? const Color(0xFFF59E0B)
        : LX.red;
    return LxCard(
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFEDEBFA),
                  color: color,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const Text(
                      '/ 100',
                      style: TextStyle(fontSize: 11, color: LX.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seller Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: LX.ink,
                  ),
                ),
                const SizedBox(height: 6),
                for (final p in parts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 78,
                          child: Text(
                            p.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LX.muted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: p.$2,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFEDEBFA),
                              color: LX.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text(
                            p.$3,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: LX.ink,
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
    );
  }
}

List<Color> _grad(Color c) {
  if (c == C.primary) return _gBlue;
  if (c == C.green) return _gGreen;
  if (c == C.amber) return _gAmber;
  if (c == C.violet) return _gViolet;
  if (c == C.red) return _gRed;
  if (c == C.cyan) return _gCyan;
  return [Color.lerp(c, Colors.white, 0.3)!, c];
}
