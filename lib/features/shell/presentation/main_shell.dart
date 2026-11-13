import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../cart/providers/cart_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    final wishCount = ref.watch(wishlistProvider).length;

    Widget badge(Widget icon, int count) => count == 0
        ? icon
        : Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: badge(const Icon(Icons.shopping_cart_outlined), cartCount),
            selectedIcon: badge(
              const Icon(Icons.shopping_cart_rounded),
              cartCount,
            ),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: badge(const Icon(Icons.favorite_border_rounded), wishCount),
            selectedIcon: badge(const Icon(Icons.favorite_rounded), wishCount),
            label: 'Wishlist',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
