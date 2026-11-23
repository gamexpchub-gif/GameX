import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/storage.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/product_repository.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../discover/data/phone_filter.dart';
import '../../discover/presentation/filter_sheet.dart' show FChip;
import '../../discover/presentation/widgets/voice_search.dart';
import '../../discover/providers/discover_providers.dart';
import '../../trust/presentation/widgets/trust_ui.dart';

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

  static const _smartExamples = [
    'iPhone under 40k',
    '5G Samsung with good camera',
    'gaming phone 8GB RAM',
    'battery valo phone 25 hazar er niche',
    'like new pixel in Bengaluru',
  ];

  Future<void> _voice() async {
    final said = await showVoiceSearch(context);
    if (said != null && said.trim().isNotEmpty) _submit(said);
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    _controller.text = q;
    final smart = parseSmartQuery(q);
    if (smart.count > 0) {
      _remember(q);
      context.push('/explore', extra: smart);
      return;
    }
    setState(() => _query = q);
    _remember(q);
  }

  void _remember(String q) {
    setState(() {
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
            onChanged: (v) {
              setState(() {});
              _onChanged(v);
            },
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'Try "iPhone under 40k"',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _controller.text.isEmpty
                  ? IconButton(
                      tooltip: 'Voice search',
                      icon: const Icon(Icons.mic_rounded, color: TX.violet),
                      onPressed: _voice,
                    )
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
        Row(
          children: [
            _tool(Icons.travel_explore_rounded, 'Phone Finder', '/finder'),
            const SizedBox(width: 10),
            _tool(Icons.tune_rounded, 'Smart Filter', '/explore'),
            const SizedBox(width: 10),
            _tool(Icons.compare_arrows_rounded, 'Compare', '/compare'),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: TX.violet),
            const SizedBox(width: 6),
            Text(
              'Search like you talk',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Budget, brand, RAM, 5G, battery, city: we turn it into filters.',
          style: TextStyle(color: theme.colorScheme.outline, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _smartExamples)
              FChip(e, false, () => _submit(e), icon: Icons.north_west_rounded),
          ],
        ),
        const SizedBox(height: 24),
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

  Widget _tool(IconData icon, String label, String route) => Expanded(
    child: GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: TX.soft(0.07),
        ),
        child: Column(
          children: [
            TIcon(icon, size: 36),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: TX.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Banner shown while typing when the text contains filters.
  Widget _smartBanner(PhoneFilter f) {
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    final n = f.apply(pool).length;
    return GestureDetector(
      onTap: () => context.push('/explore', extra: f),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: TX.night,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC542)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filterLabels(f).join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Smart search found $n phone${n == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFFC9D2FF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _results() {
    final smart = parseSmartQuery(_query);
    if (smart.count > 0) {
      final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _smartBanner(smart)),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ProductSliverGrid(products: smart.apply(pool).take(30).toList()),
        ],
      );
    }
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
