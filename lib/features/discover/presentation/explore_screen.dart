import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/listing_card.dart';
import '../../../data/models/product.dart';
import '../../checkout/providers/address_provider.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/phone_filter.dart';
import '../data/phone_intel.dart';
import '../providers/discover_providers.dart';
import 'filter_sheet.dart';
import 'widgets/compare_widgets.dart';
import 'widgets/fair_price_meter.dart';
import 'widgets/voice_search.dart';

/// Buyer's city for "near me" (from the selected address).
final userCityProvider = Provider<String>((ref) {
  final c = ref.watch(addressBookProvider).current?.city;
  return c != null && kCities.contains(c) ? c : 'Mumbai';
});

/// Smart Filter: search + every filter a second-hand phone buyer needs.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.initial = const PhoneFilter()});
  final PhoneFilter initial;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late PhoneFilter _f = widget.initial;
  late final _search = TextEditingController(text: widget.initial.text);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _set(PhoneFilter f) {
    HapticFeedback.selectionClick();
    setState(() => _f = f);
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _f = _f.copyWith(text: v.trim()));
    });
  }

  /// Applies natural-language search ("5G samsung under 30k").
  void _smart(String q) {
    final parsed = parseSmartQuery(q, _f);
    _search.text = parsed.text;
    _set(parsed);
  }

  Future<void> _voice() async {
    final said = await showVoiceSearch(context);
    if (said != null && said.isNotEmpty) _smart(said);
  }

  Future<void> _openFilters(List<Product> pool) async {
    final f = await showFilterSheet(
      context,
      pool: pool,
      filter: _f,
      userCity: ref.read(userCityProvider),
    );
    if (f != null) _set(f);
  }

  Future<void> _pickSort() async {
    final s = await showModalBottomSheet<DiscoverSort>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort by',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: TX.ink,
              ),
            ),
            const SizedBox(height: 6),
            for (final s in DiscoverSort.values)
              ListTile(
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: s == _f.sort
                        ? FontWeight.w900
                        : FontWeight.w500,
                    color: s == _f.sort ? TX.violet : TX.ink,
                  ),
                ),
                trailing: s == _f.sort
                    ? const Icon(Icons.check_circle_rounded, color: TX.violet)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (s != null) _set(_f.copyWith(sort: s));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(discoverPoolProvider);
    final pool = async.asData?.value ?? const <Product>[];
    final city = ref.watch(userCityProvider);
    final results = _f.apply(pool);
    final top = MediaQuery.paddingOf(context).top;
    final w = MediaQuery.sizeOf(context).width;
    final cardW = (w - 32 - 12) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F3FF), Color(0xFFF0F4FF), Color(0xFFF7F2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
                    child: _header(pool),
                  ),
                ),
                SliverToBoxAdapter(child: _quickChips(city)),
                if (_f.priority != null)
                  SliverToBoxAdapter(child: _priorityBanner()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 6),
                    child: Row(
                      children: [
                        Text(
                          async.isLoading && pool.isEmpty
                              ? 'Finding phones…'
                              : '${results.length} phone${results.length == 1 ? '' : 's'} found',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TX.ink,
                          ),
                        ),
                        const Spacer(),
                        if (_f.count > 0)
                          TextButton(
                            onPressed: () => _set(_f.cleared()),
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (async.isLoading && pool.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (results.isEmpty)
                  SliverToBoxAdapter(child: _empty())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 14,
                        mainAxisExtent: listingCardHeight(cardW) + 40,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => ResultCard(product: results[i], pool: pool),
                        childCount: results.length,
                      ),
                    ),
                  ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: CompareTray()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(List<Product> pool) => Row(
    children: [
      TrustRoundButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: TX.soft(0.06),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: TX.muted, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onText,
                  onSubmitted: _smart,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: TX.ink, fontSize: 14.5),
                  decoration: const InputDecoration(
                    hintText: 'Try "5G Samsung under 30k"',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                onPressed: _voice,
                icon: const Icon(Icons.mic_rounded, color: TX.violet),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () => _openFilters(pool),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: TX.chip,
                borderRadius: BorderRadius.circular(16),
                boxShadow: TX.soft(0.25),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
            if (_f.count > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_f.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _quickChips(String city) {
    final under30 = _f.maxPrice == 30000 && _f.minPrice == kMinPrice;
    final likeNew = _f.grades.length == 1 && _f.grades.contains('Like New');
    final ram8 = _f.ram.containsAll({8, 12, 16}) && _f.ram.length == 3;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          for (final c in [
            FChip(
              _f.sort == DiscoverSort.relevance ? 'Sort' : _f.sort.label,
              _f.sort != DiscoverSort.relevance,
              _pickSort,
              icon: Icons.swap_vert_rounded,
            ),
            FChip(
              'Under ₹30K',
              under30,
              () => _set(
                under30
                    ? _f.copyWith(maxPrice: kMaxPrice)
                    : _f.copyWith(minPrice: kMinPrice, maxPrice: 30000),
              ),
            ),
            FChip(
              'Battery 85%+',
              _f.minBattery == 85,
              () => _set(_f.copyWith(minBattery: _f.minBattery == 85 ? 0 : 85)),
              icon: Icons.battery_charging_full_rounded,
            ),
            FChip(
              '5G',
              _f.only5G,
              () => _set(_f.copyWith(only5G: !_f.only5G)),
              icon: Icons.cell_tower_rounded,
            ),
            FChip(
              'Near me ($city)',
              _f.city == city,
              () =>
                  _set(_f.copyWith(city: () => _f.city == city ? null : city)),
              icon: Icons.near_me_rounded,
            ),
            FChip(
              'Warranty',
              _f.warranty,
              () => _set(_f.copyWith(warranty: !_f.warranty)),
              icon: Icons.shield_rounded,
            ),
            FChip(
              'Like New',
              likeNew,
              () => _set(_f.copyWith(grades: likeNew ? {} : {'Like New'})),
            ),
            FChip(
              '8GB+ RAM',
              ram8,
              () => _set(_f.copyWith(ram: ram8 ? {} : {8, 12, 16})),
            ),
            FChip(
              'Seller 4.5★+',
              _f.minRating == 4.5,
              () => _set(_f.copyWith(minRating: _f.minRating == 4.5 ? 0 : 4.5)),
            ),
          ])
            Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      ),
    );
  }

  Widget _priorityBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: TX.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: TX.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ranked for ${_f.priority!.label.toLowerCase()}: ${_f.priority!.hint.toLowerCase()}',
              style: const TextStyle(
                fontSize: 12.5,
                color: TX.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _set(_f.copyWith(priority: () => null)),
            icon: const Icon(Icons.close_rounded, size: 18, color: TX.muted),
          ),
        ],
      ),
    ),
  );

  Widget _empty() {
    final labels = filterLabels(_f);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        children: [
          const TIcon(Icons.search_off_rounded, size: 64),
          const SizedBox(height: 14),
          const Text(
            'No phones match all of these',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: TX.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            labels.isEmpty
                ? 'Try another search.'
                : 'You asked for: ${labels.join(' • ')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: TX.muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          if (_f.hasBudget && _f.maxPrice < kMaxPrice)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TGhost(
                label:
                    'Stretch budget to ₹${((_f.maxPrice * 1.25) / 1000).round()}K',
                icon: Icons.trending_up_rounded,
                onTap: () => _set(
                  _f.copyWith(
                    maxPrice: (_f.maxPrice * 1.25).clamp(kMinPrice, kMaxPrice),
                  ),
                ),
              ),
            ),
          TButton(
            label: 'Clear all filters',
            icon: Icons.filter_alt_off_rounded,
            onTap: () {
              _search.clear();
              _set(const PhoneFilter());
            },
          ),
        ],
      ),
    );
  }
}

/// Listing card + Fair Price chip + Compare toggle.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.product, required this.pool});
  final Product product;
  final List<Product> pool;

  @override
  Widget build(BuildContext context) {
    final fair = fairPriceOf(product, market: pool);
    return Column(
      children: [
        Expanded(child: ListingCard(product: product)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FairPriceChip(fair: fair, dense: true),
              ),
            ),
            const SizedBox(width: 6),
            CompareToggle(product: product, size: 28, compact: true),
          ],
        ),
      ],
    );
  }
}
