import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/product_card.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../wishlist/providers/wishlist_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productByIdProvider(productId));
    return product.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(
          onRetry: () => ref.invalidate(productByIdProvider(productId)),
        ),
      ),
      data: (p) => p == null
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Product not found',
                message: 'This product may have been removed.',
              ),
            )
          : _ProductView(product: p),
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.product});
  final Product product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  int _image = 0;
  int _qty = 1;
  String? _size;
  int? _color;

  Product get p => widget.product;

  @override
  void initState() {
    super.initState();
    if (p.colors.isNotEmpty) _color = p.colors.first;
  }

  bool _validateOptions() {
    if (p.sizes.isNotEmpty && _size == null) {
      showAppSnack(context, 'Please select a size');
      return false;
    }
    return true;
  }

  void _addToCart({bool buyNow = false}) {
    if (!_validateOptions()) return;
    HapticFeedback.mediumImpact();
    ref
        .read(cartProvider.notifier)
        .add(p, quantity: _qty, size: _size, color: _color);
    if (buyNow) {
      context.push('/cart');
    } else {
      showAppSnack(
        context,
        'Added to cart',
        action: 'VIEW',
        onAction: () => context.push('/cart'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wished = ref.watch(isWishlistedProvider(p.id));
    final maxQty = p.stock < CartNotifier.maxPerItem
        ? p.stock
        : CartNotifier.maxPerItem;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.sizeOf(context).width,
            pinned: true,
            stretch: true,
            actions: [
              IconButton.filledTonal(
                onPressed: () => showAppSnack(context, 'Share link copied'),
                icon: const Icon(Icons.share_outlined),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final added = ref.read(wishlistProvider.notifier).toggle(p);
                  showAppSnack(
                    context,
                    added ? 'Saved to wishlist' : 'Removed from wishlist',
                  );
                },
                icon: Icon(
                  wished
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: wished ? AppColors.danger : null,
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  PageView.builder(
                    itemCount: p.images.length,
                    onPageChanged: (i) => setState(() => _image = i),
                    itemBuilder: (_, i) => AppImage(p.images[i]),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < p.images.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _image ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _image
                                  ? AppColors.primary
                                  : Colors.white70,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p.brand.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      _StockPill(stock: p.stock),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RatingRow(rating: p.rating, count: p.reviewCount),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: PriceTag(
                          price: p.price,
                          oldPrice: p.oldPrice,
                          large: true,
                        ),
                      ),
                      if (p.discountPercent > 0)
                        DiscountBadge(p.discountPercent),
                    ],
                  ),
                  if (p.colors.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Color',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final c in p.colors)
                          GestureDetector(
                            onTap: () => setState(() => _color = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _color == c
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (p.sizes.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Size',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in p.sizes)
                          ChoiceChip(
                            label: Text(s),
                            selected: _size == s,
                            onSelected: (_) => setState(() => _size = s),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text(
                        'Quantity',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      QuantityStepper(
                        value: _qty,
                        max: maxQty < 1 ? 1 : maxQty,
                        onChanged: (v) => setState(() => _qty = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _Perks(),
                  const SizedBox(height: 22),
                  Text(
                    'Description',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _Related(product: p)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.dividerTheme.color ?? AppColors.border,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: p.inStock ? _addToCart : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Add to Cart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: p.inStock ? () => _addToCart(buyNow: true) : null,
                  child: Text(p.inStock ? 'Buy Now' : 'Out of Stock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.stock});
  final int stock;

  @override
  Widget build(BuildContext context) {
    final (label, color) = stock == 0
        ? ('Out of stock', AppColors.danger)
        : stock < 10
        ? ('Only $stock left', AppColors.warning)
        : ('In stock', AppColors.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Perks extends StatelessWidget {
  const _Perks();

  @override
  Widget build(BuildContext context) {
    Widget perk(IconData icon, String title, String sub) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            perk(Icons.local_shipping_outlined, 'Fast Delivery', '1-3 days'),
            perk(Icons.verified_outlined, '100% Original', 'Brand warranty'),
            perk(Icons.autorenew_rounded, 'Easy Return', '7 days'),
          ],
        ),
      ),
    );
  }
}

class _Related extends ConsumerWidget {
  const _Related({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(
      productsProvider((
        categoryId: product.categoryId,
        query: null,
        sort: ProductSort.popular,
      )),
    );
    final list = (related.asData?.value ?? const <Product>[])
        .where((p) => p.id != product.id)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'You may also like',
          onSeeAll: () => context.push('/category/${product.categoryId}'),
        ),
        ProductCarousel(products: list),
      ],
    );
  }
}
