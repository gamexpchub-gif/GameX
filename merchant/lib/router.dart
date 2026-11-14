import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'data/store.dart';
import 'features/account/account_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/earnings/earnings_screen.dart';
import 'features/home/dashboard_screen.dart';
import 'features/listings/listing_editor_screen.dart';
import 'features/listings/listings_screen.dart';
import 'features/live/live_calls_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/shell/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier(ref.read(sellerProvider) != null);
  ref.listen(sellerProvider, (_, s) => signedIn.value = s != null);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: signedIn,
    redirect: (_, s) {
      final atLogin = s.matchedLocation == '/login';
      if (!signedIn.value) return atLogin ? null : '/login';
      if (atLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => SellerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (_, s) =>
                    OrdersScreen(initialTab: s.uri.queryParameters['tab']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/listings',
                builder: (_, _) => const ListingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                builder: (_, _) => const EarningsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/listing/new',
        builder: (_, _) => const ListingEditorScreen(),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, s) =>
            ListingEditorScreen(listingId: s.pathParameters['id']),
      ),
      GoRoute(path: '/live', builder: (_, _) => const LiveCallsScreen()),
    ],
  );
});
