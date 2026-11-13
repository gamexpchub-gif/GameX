import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/categories_screen.dart';
import '../../features/catalog/presentation/category_products_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/order_success_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/product/presentation/product_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/reviews_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/wishlist/presentation/wishlist_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (_, s) => LoginScreen(redirectTo: s.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/register',
      builder: (_, s) =>
          RegisterScreen(redirectTo: s.uri.queryParameters['from']),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categories',
              builder: (_, _) => const CategoriesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/reviews', builder: (_, _) => const ReviewsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/category/:id',
      builder: (_, s) => CategoryProductsScreen(
        categoryId: s.pathParameters['id']!,
        flashSale: s.uri.queryParameters['flash'] == '1',
      ),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (_, s) =>
          ProductDetailScreen(productId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
    GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
    GoRoute(
      path: '/order-success/:id',
      builder: (_, s) => OrderSuccessScreen(orderId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
    GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen()),
    GoRoute(
      path: '/order/:id',
      builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
    ),
  ],
);
