import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/product_repository.dart';
import '../providers/catalog_providers.dart';

/// Product listing for a category. `categoryId == 'all'` lists everything;
/// [flashSale] limits it to flash-sale items.
class CategoryProductsScreen extends ConsumerStatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    this.flashSale = false,
  });

  final String categoryId;
  final bool flashSale;

  @override
  ConsumerState<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState
    extends ConsumerState<CategoryProductsScreen> {
  ProductSort _sort = ProductSort.popular;
  bool _inStockOnly = false;

  String? get _catId => widget.categoryId == 'all' ? null : widget.categoryId;

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<ProductSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<ProductSort>(
          groupValue: _sort,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sort by',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              for (final s in ProductSort.values)
                RadioListTile<ProductSort>(value: s, title: Text(s.label)),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final query = (categoryId: _catId, query: null, sort: _sort);
    final products = ref.watch(productsProvider(query));
    final title = widget.flashSale
        ? 'Flash Sale'
        : _catId == null
        ? 'All Products'
        : ref.watch(categoryByIdProvider(_catId!)).asData?.value?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: Text(_sort.label),
                  onPressed: _pickSort,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('In stock'),
                  selected: _inStockOnly,
                  onSelected: (v) => setState(() => _inStockOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const SingleChildScrollView(
                child: ProductGridSkeleton(count: 6),
              ),
              error: (_, _) => ErrorRetry(
                onRetry: () => ref.invalidate(productsProvider(query)),
              ),
              data: (all) {
                final list = all
                    .where((p) => !widget.flashSale || p.isFlashSale)
                    .where((p) => !_inStockOnly || p.inStock)
                    .toList();
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products found',
                    message: 'Try changing the filters.',
                  );
                }
                return CustomScrollView(
                  slivers: [ProductSliverGrid(products: list)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
