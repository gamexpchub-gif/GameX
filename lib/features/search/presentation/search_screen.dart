import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/storage.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/product_repository.dart';
import '../../catalog/providers/catalog_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late List<String> _recent;

  static const _popular = [
    'iPhone',
    'Galaxy',
    'Pixel',
    'OnePlus',
    'vivo',
    'Xiaomi',
  ];

  @override
  void initState() {
    super.initState();
    _recent =
        ref
            .read(localStoreProvider)
            .readJson(
              LocalStore.recentSearches,
              (j) => List<String>.from(j as List),
            ) ??
        [];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    _controller.text = q;
    setState(() {
      _query = q;
      _recent = [
        q,
        ..._recent.where((r) => r.toLowerCase() != q.toLowerCase()),
      ].take(8).toList();
    });
    ref.read(localStoreProvider).writeJson(LocalStore.recentSearches, _recent);
  }

  void _clearRecent() {
    setState(() => _recent = []);
    ref.read(localStoreProvider).remove(LocalStore.recentSearches);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'Search products, brands…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: _query.isEmpty ? _suggestions() : _results(),
    );
  }

  Widget _suggestions() {
    final theme = Theme.of(context);
    Widget chips(List<String> items) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in items)
          ActionChip(label: Text(s), onPressed: () => _submit(s)),
      ],
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Recent searches',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: _clearRecent, child: const Text('Clear')),
            ],
          ),
          chips(_recent),
          const SizedBox(height: 24),
        ],
        Text(
          'Popular searches',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        chips(_popular),
      ],
    );
  }

  Widget _results() {
    final query = (categoryId: null, query: _query, sort: ProductSort.popular);
    return ref
        .watch(productsProvider(query))
        .when(
          loading: () => const SingleChildScrollView(
            padding: EdgeInsets.only(top: 8),
            child: ProductGridSkeleton(),
          ),
          error: (_, _) => ErrorRetry(
            onRetry: () => ref.invalidate(productsProvider(query)),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No results for "$_query"',
                  message: 'Check the spelling or try a different keyword.',
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          '${list.length} results',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                    ProductSliverGrid(products: list),
                  ],
                ),
        );
  }
}
