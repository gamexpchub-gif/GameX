import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/product_card.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wishlistProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(items.isEmpty ? 'Wishlist' : 'Wishlist (${items.length})'),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Your wishlist is empty',
              message: 'Tap the ♥ on any product to save it for later.',
              actionLabel: 'Explore Products',
              onAction: () => context.go('/home'),
            )
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                ProductSliverGrid(products: items),
              ],
            ),
    );
  }
}
