import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

enum _Tab {
  newOrders('New', 'new'),
  ship('To ship', 'ship'),
  transit('Shipped', 'transit'),
  done('Delivered', 'done'),
  issues('Cancelled / Returns', 'issues');

  const _Tab(this.label, this.key);
  final String label;
  final String key;

  bool matches(SellerOrder o) => switch (this) {
    _Tab.newOrders => o.stage == OrderStage.newOrder,
    _Tab.ship => o.stage == OrderStage.accepted || o.stage == OrderStage.packed,
    _Tab.transit => o.stage == OrderStage.shipped,
    _Tab.done => o.stage == OrderStage.delivered,
    _Tab.issues =>
      o.stage == OrderStage.cancelled || o.stage == OrderStage.returned,
  };
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: _Tab.values.length,
    vsync: this,
    initialIndex: _indexFor(widget.initialTab),
  );
  String _q = '';
  bool _searching = false;

  int _indexFor(String? key) {
    final i = _Tab.values.indexWhere((t) => t.key == key);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(OrdersScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab && widget.initialTab != null) {
      _tabs.animateTo(_indexFor(widget.initialTab));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final q = _q.toLowerCase();
    final filtered = orders
        .where(
          (o) =>
              q.isEmpty ||
              '${o.id} ${o.buyer} ${o.item} ${o.city} ${o.awb ?? ''}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Order ID, buyer, AWB…',
                  isDense: true,
                ),
              )
            : const Text('Orders'),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _q = '';
            }),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: C.border,
          labelColor: C.primary,
          unselectedLabelColor: C.muted,
          indicatorColor: C.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
          tabs: [
            for (final t in _Tab.values)
              Tab(
                child: Row(
                  children: [
                    Text(t.label),
                    const SizedBox(width: 6),
                    _Count(orders.where(t.matches).length, t == _Tab.newOrders),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final t in _Tab.values)
            Builder(
              builder: (_) {
                final list = filtered.where(t.matches).toList();
                if (list.isEmpty) {
                  return ListView(
                    children: [
                      EmptyView(
                        icon: Icons.receipt_long_rounded,
                        title: q.isEmpty ? 'All clear here' : 'No matches',
                        text: q.isEmpty
                            ? 'Orders in "${t.label}" will appear here.'
                            : 'Try another order ID or buyer name.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => OrderTile(order: list[i]),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n, this.hot);
  final int n;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    if (n == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: hot ? C.red : C.border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontSize: 11,
          color: hot ? Colors.white : C.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Compact order card used on the orders list and dashboard.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final left = o.stage == OrderStage.newOrder
        ? timeLeft(o.slaDeadline)
        : null;
    return Panel(
      onTap: () => context.push('/order/${o.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                o.id,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: C.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ago(o.placedAt),
                style: const TextStyle(color: C.faint, fontSize: 12),
              ),
              const Spacer(),
              Pill(o.stage.label, color: stageColor(o.stage)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Photo(o.photo, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      o.variant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${o.buyer} • ${o.city}',
                      style: const TextStyle(fontSize: 12.5, color: C.ink),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    inr(o.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    o.payment,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: o.payment == 'COD' ? C.amber : C.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (left != null || o.stage == OrderStage.newOrder) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (left == null ? C.red : C.amber).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: left == null ? C.red : C.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    left == null
                        ? 'Acceptance time passed'
                        : 'Accept within $left',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: left == null ? C.red : C.amber,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Review',
                    style: TextStyle(
                      color: C.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
