import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/product.dart';
import '../../features/cart/providers/cart_provider.dart';
import '../../features/wishlist/providers/wishlist_provider.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';
import 'common.dart';
import 'skeleton.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.width});

  final Product product;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wished = ref.watch(isWishlistedProvider(product.id));

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/product/${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: AppImage(product.images.first)),
                    if (product.discountPercent > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DiscountBadge(product.discountPercent),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _RoundIconButton(
                        icon: wished
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: wished ? AppColors.danger : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(wishlistProvider.notifier).toggle(product);
                        },
                      ),
                    ),
                    if (!product.inStock)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black45,
                          alignment: Alignment.center,
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RatingRow(
                      rating: product.rating,
                      count: product.reviewCount,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: PriceTag(
                        price: product.price,
                        oldPrice: product.oldPrice,
                      ),
                    ),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Add to cart',
                      onPressed: product.inStock
                          ? () {
                              if (product.sizes.isNotEmpty ||
                                  product.colors.isNotEmpty) {
                                context.push('/product/${product.id}');
                                return;
                              }
                              HapticFeedback.lightImpact();
                              ref.read(cartProvider.notifier).add(product);
                              showAppSnack(
                                context,
                                'Added to cart',
                                action: 'VIEW',
                                onAction: () => context.push('/cart'),
                              );
                            }
                          : null,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

/// Sliver grid of product cards.
class ProductSliverGrid extends StatelessWidget {
  const ProductSliverGrid({super.key, required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid.builder(
        gridDelegate: productGridDelegate,
        itemCount: products.length,
        itemBuilder: (_, i) => ProductCard(product: products[i]),
      ),
    );
  }
}

/// Horizontal carousel of product cards.
class ProductCarousel extends StatelessWidget {
  const ProductCarousel({super.key, required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ProductCard(product: products[i], width: 170),
      ),
    );
  }
}
