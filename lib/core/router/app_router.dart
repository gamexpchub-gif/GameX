import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/categories_screen.dart';
import '../../features/catalog/presentation/category_products_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/order_success_screen.dart';
import '../../features/commerce/presentation/alerts_screen.dart';
import '../../features/commerce/presentation/emi_screen.dart';
import '../../features/commerce/presentation/offers_screen.dart';
import '../../features/commerce/presentation/sale_screen.dart';
import '../../features/commerce/presentation/trade_in_screen.dart';
import '../../features/commerce/presentation/wallet_screen.dart';
import '../../features/discover/data/phone_filter.dart';
import '../../features/discover/presentation/compare_screen.dart';
import '../../features/discover/presentation/explore_screen.dart';
import '../../features/discover/presentation/finder_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/live_review/presentation/live_review_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/product/presentation/product_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/reviews_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/trust/presentation/certificate_screen.dart';
import '../../features/trust/presentation/imei_check_screen.dart';
import '../../features/trust/presentation/inspection_report_screen.dart';
import '../../features/trust/presentation/live_chat_screen.dart';
import '../../features/trust/presentation/scan_certificate_screen.dart';
import '../../features/trust/presentation/seller_profile_screen.dart';
import '../../features/trust/presentation/trust_hub_screen.dart';
import '../../features/trust/presentation/warranty_card_screen.dart';
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
    GoRoute(
      path: '/explore',
      builder: (_, s) => ExploreScreen(
        initial: s.extra is PhoneFilter
            ? s.extra! as PhoneFilter
            : parseSmartQuery(s.uri.queryParameters['q'] ?? ''),
      ),
    ),
    GoRoute(path: '/compare', builder: (_, _) => const CompareScreen()),
    GoRoute(
      path: '/trade-in',
      builder: (_, s) => TradeInScreen(
        newPhonePrice:
            double.tryParse(s.uri.queryParameters['price'] ?? '') ?? 0,
      ),
    ),
    GoRoute(
      path: '/emi',
      builder: (_, s) => EmiScreen(
        price: double.tryParse(s.uri.queryParameters['price'] ?? '') ?? 0,
        name: s.uri.queryParameters['name'],
      ),
    ),
    GoRoute(path: '/offers', builder: (_, _) => const OffersScreen()),
    GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const NotificationsScreen(),
    ),
    GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
    GoRoute(path: '/sale', builder: (_, _) => const SaleScreen()),
    GoRoute(path: '/finder', builder: (_, _) => const FinderScreen()),
    GoRoute(path: '/trust', builder: (_, _) => const TrustHubScreen()),
    GoRoute(
      path: '/trust/scan',
      builder: (_, _) => const ScanCertificateScreen(),
    ),
    GoRoute(
      path: '/trust/imei',
      builder: (_, s) =>
          ImeiCheckScreen(initial: s.uri.queryParameters['imei']),
    ),
    GoRoute(
      path: '/certificate/:code',
      builder: (_, s) => CertificateScreen(code: s.pathParameters['code']!),
    ),
    GoRoute(
      path: '/product/:id/report',
      builder: (_, s) =>
          InspectionReportScreen(productId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/seller/:id',
      builder: (_, s) => SellerProfileScreen(sellerId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/warranty/:orderId/:itemId',
      builder: (_, s) => WarrantyCardScreen(
        orderId: s.pathParameters['orderId']!,
        itemId: s.pathParameters['itemId']!,
      ),
    ),
    GoRoute(
      path: '/live-chat/:id',
      builder: (_, s) => LiveChatScreen(liveId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/live-review/:id',
      builder: (_, s) => LiveReviewScreen(productId: s.pathParameters['id']!),
    ),
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
