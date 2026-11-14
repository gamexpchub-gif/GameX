import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';

class SellerShell extends ConsumerWidget {
  const SellerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newOrders = ref.watch(
      ordersProvider.select(
        (o) => o.where((e) => e.stage == OrderStage.newOrder).length,
      ),
    );
    Widget badge(IconData icon, int n) => Badge(
      isLabelVisible: n > 0,
      label: Text('$n'),
      backgroundColor: C.red,
      child: Icon(icon),
    );
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: badge(Icons.receipt_long_outlined, newOrders),
              selectedIcon: badge(Icons.receipt_long_rounded, newOrders),
              label: 'Orders',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Listings',
            ),
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Earnings',
            ),
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Store',
            ),
          ],
        ),
      ),
    );
  }
}
