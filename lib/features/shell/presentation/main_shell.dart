import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'liquid_nav_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navSpace = LiquidNavBar.occupiedHeight(
      mq.size.width,
      mq.padding.bottom,
    );
    final isHome = shell.currentIndex == 0;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Home scrolls underneath the glass bar; other tabs stop above it.
          Positioned.fill(
            bottom: isHome ? 0 : navSpace,
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(bottom: isHome ? navSpace : 0),
              ),
              child: shell,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidNavBar(
              currentIndex: shell.currentIndex,
              onTap: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              items: [
                const LiquidNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                const LiquidNavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Category',
                ),
                const LiquidNavItem(
                  icon: Icons.shopping_bag_outlined,
                  activeIcon: Icons.shopping_bag_rounded,
                  label: 'Order',
                ),
                const LiquidNavItem(
                  icon: Icons.star_border_rounded,
                  activeIcon: Icons.star_rounded,
                  label: 'Review',
                ),
                const LiquidNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Account',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
