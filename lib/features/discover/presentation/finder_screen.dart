import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/models/product.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/phone_filter.dart';
import '../data/phone_intel.dart';
import '../providers/discover_providers.dart';
import 'explore_screen.dart' show userCityProvider;
import 'filter_sheet.dart' show FChip;
import 'widgets/fair_price_meter.dart';

class _Budget {
  const _Budget(this.label, this.sub, this.min, this.max);
  final String label;
  final String sub;
  final double min;
  final double max;
}

const _budgets = [
  _Budget('Under ₹20K', 'Smart value picks', kMinPrice, 20000),
  _Budget('₹20K – ₹35K', 'Best mid-range', 20000, 35000),
  _Budget('₹35K – ₹50K', 'Upper mid / older flagships', 35000, 50000),
  _Budget('₹50K – ₹75K', 'Recent flagships', 50000, 75000),
  _Budget('₹75K+', 'The very best', 75000, kMaxPrice),
];

enum _Cond {
  likeNew('Like New only', 'Looks and feels brand new', {'Like New'}),
  excellent('Excellent or better', 'Tiny marks you won\'t notice', {
    'Like New',
    'Excellent',
  }),
  any('Any condition', 'Save more, all phones fully working', {});

  const _Cond(this.label, this.sub, this.grades);
  final String label;
  final String sub;
  final Set<String> grades;
}

class FinderPick {
  const FinderPick(this.product, this.match, this.reasons, this.fair);
  final Product product;
  final int match;
  final List<String> reasons;
  final FairPrice fair;
}

/// Ranks [pool] for the quiz answers. Relaxes filters when too few match.
(List<FinderPick>, String?) findPhones(
  List<Product> pool, {
  required double min,
  required double max,
  required Priority priority,
  required Set<String> brands,
  required Set<String> grades,
  required bool need5G,
  required String city,
}) {
  String? note;
  List<Product> candidates(Set<String> b, Set<String> g, double hi) => [
    for (final p in pool)
      if (p.inStock &&
          p.price >= min * 0.85 &&
          p.price <= hi &&
          (b.isEmpty || b.contains(p.brand)) &&
          (g.isEmpty || g.contains(gradeOf(p))) &&
          (!need5G || modelInfo(p).is5G))
        p,
  ];
  var list = candidates(brands, grades, max * 1.05);
  if (_distinct(list) < 3 && grades.isNotEmpty) {
    list = candidates(brands, const {}, max * 1.05);
    note = 'We included more conditions to give you enough choice.';
  }
  if (_distinct(list) < 3 && brands.isNotEmpty) {
    list = candidates(const {}, const {}, max * 1.05);
    note = 'Few phones from your brands in this budget, so we added others.';
  }
  if (_distinct(list) < 3) {
    list = candidates(const {}, const {}, max * 1.25);
    note = 'We stretched your budget slightly to find the best options.';
  }

  final scored = <(FinderPick, double)>[];
  for (final p in list) {
    final m = modelInfo(p);
    final fair = fairPriceOf(p, market: pool);
    final s =
        priority.scoreOf(m) / 10 * 0.5 +
        ((0.25 - fair.delta).clamp(0.0, 0.5) / 0.5) * 0.2 +
        ((batteryOf(p) - 80) / 20).clamp(0.0, 1.0) * 0.1 +
        (kGrades.length - kGrades.indexOf(gradeOf(p))) / 4 * 0.1 +
        ((m.year - 2019) / 6).clamp(0.0, 1.0) * 0.1 -
        (p.price > max ? 0.08 : 0);
    final reasons = <String>[
      switch (priority) {
        Priority.gaming => 'Gaming ${m.gaming}/10 • ${m.chip}',
        Priority.camera =>
          'Camera ${m.camera}/10 • ${m.display.isEmpty ? m.chip : m.display}',
        Priority.battery =>
          'Battery ${m.battery}/10${m.batteryMah > 0 ? ' • ${m.batteryMah} mAh' : ''}',
        Priority.allRounder =>
          'Gaming ${m.gaming} • Camera ${m.camera} • Battery ${m.battery}',
      },
      if (fair.verdict == PriceVerdict.great)
        '${formatPrice(fair.savings)} below market price'
      else if (fair.verdict == PriceVerdict.fair)
        'Fairly priced for its condition',
      '${gradeOf(p)} • ${batteryOf(p)}% battery health',
      if (p.warrantyMonths > 0) '${p.warrantyMonths}-month warranty',
      if (shipsFrom(p) == city) 'Ships from $city, fast delivery',
      if (p.price > max) 'Slightly above your budget',
    ];
    scored.add((
      FinderPick(p, (62 + s * 38).round().clamp(50, 99), reasons, fair),
      s,
    ));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final seen = <String>{};
  return (
    [
      for (final (pick, _) in scored)
        if (seen.add(pick.product.name)) pick,
    ].take(3).toList(),
    note,
  );
}

int _distinct(List<Product> l) => {for (final p in l) p.name}.length;

/// "Phone Finder": a 4-question quiz that recommends the best 3 phones.
class FinderScreen extends ConsumerStatefulWidget {
  const FinderScreen({super.key});

  @override
  ConsumerState<FinderScreen> createState() => _FinderScreenState();
}

class _FinderScreenState extends ConsumerState<FinderScreen> {
  int _step = 0;
  _Budget? _budget;
  Priority? _priority;
  Set<String> _brands = {};
  _Cond _cond = _Cond.excellent;
  bool _need5G = true;

  static const _steps = 4;

  void _next() {
    HapticFeedback.selectionClick();
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      context.canPop() ? context.pop() : context.go('/home');
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final done = _step >= _steps;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F2FF),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6F3FF), Color(0xFFEFF3FF), Color(0xFFF7F2FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
                child: Row(
                  children: [
                    TrustRoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _back,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone Finder',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: TX.ink,
                            ),
                          ),
                          Text(
                            done
                                ? 'Your top matches'
                                : 'Question ${_step + 1} of $_steps',
                            style: const TextStyle(
                              color: TX.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() {
                          _step = 0;
                          _budget = null;
                          _priority = null;
                          _brands = {};
                        }),
                        child: const Text('Start over'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            gradient: i <= _step ? TX.cta : null,
                            color: i <= _step ? null : TX.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(a),
                      child: c,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _budgetStep(),
                      1 => _priorityStep(),
                      2 => _brandStep(),
                      3 => _condStep(),
                      _ => _results(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _question(
    String q,
    String sub,
    List<Widget> children, {
    Widget? bottom,
  }) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            Text(
              q,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: TX.ink,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(sub, style: const TextStyle(color: TX.muted, fontSize: 14)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
      if (bottom != null)
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            14 + MediaQuery.paddingOf(context).bottom,
          ),
          child: bottom,
        ),
    ],
  );

  Widget _option({
    required IconData icon,
    required Gradient gradient,
    required String title,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? TX.violet : Colors.transparent,
            width: 2,
          ),
          boxShadow: TX.soft(selected ? 0.18 : 0.06),
        ),
        child: Row(
          children: [
            TIcon(icon, gradient: gradient, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: TX.ink,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12.5, color: TX.muted),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0.25,
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: TX.violet,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static const _grads = [
    LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
    LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF2563EB)]),
    LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF7C3AED)]),
    LinearGradient(colors: [Color(0xFFF472B6), Color(0xFFDB2777)]),
    LinearGradient(colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)]),
  ];

  Widget _budgetStep() => _question(
    'What\'s your budget?',
    'We\'ll find the best phones you can get for it.',
    [
      for (final (i, b) in _budgets.indexed)
        _option(
          icon: Icons.currency_rupee_rounded,
          gradient: _grads[i],
          title: b.label,
          sub: b.sub,
          selected: _budget == b,
          onTap: () {
            setState(() => _budget = b);
            Future.delayed(const Duration(milliseconds: 220), () {
              if (mounted && _step == 0) _next();
            });
          },
        ),
    ],
  );

  Widget _priorityStep() => _question(
    'What will you use it for most?',
    'Pick the one that matters most to you.',
    [
      for (final (i, p) in Priority.values.indexed)
        _option(
          icon: switch (p) {
            Priority.gaming => Icons.sports_esports_rounded,
            Priority.camera => Icons.photo_camera_rounded,
            Priority.battery => Icons.battery_charging_full_rounded,
            Priority.allRounder => Icons.auto_awesome_rounded,
          },
          gradient: _grads[(i + 1) % _grads.length],
          title: p.label,
          sub: p.hint,
          selected: _priority == p,
          onTap: () {
            setState(() => _priority = p);
            Future.delayed(const Duration(milliseconds: 220), () {
              if (mounted && _step == 1) _next();
            });
          },
        ),
    ],
  );

  Widget _brandStep() => _question(
    'Any favourite brands?',
    'Choose one or more, or skip for all brands.',
    [
      Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          FChip(
            'Any brand',
            _brands.isEmpty,
            () => setState(() => _brands = {}),
            icon: Icons.all_inclusive_rounded,
          ),
          for (final b in kBrands)
            FChip(
              b == 'Apple' ? 'iPhone' : b,
              _brands.contains(b),
              () => setState(
                () => _brands = _brands.contains(b)
                    ? ({..._brands}..remove(b))
                    : {..._brands, b},
              ),
            ),
        ],
      ),
    ],
    bottom: TButton(
      label: _brands.isEmpty ? 'Skip, any brand' : 'Next',
      icon: Icons.arrow_forward_rounded,
      onTap: _next,
    ),
  );

  Widget _condStep() => _question(
    'How should it look?',
    'Every GAMEX phone works 100%. Condition is only about looks.',
    [
      for (final (i, c) in _Cond.values.indexed)
        _option(
          icon: switch (c) {
            _Cond.likeNew => Icons.diamond_rounded,
            _Cond.excellent => Icons.auto_awesome_rounded,
            _Cond.any => Icons.savings_rounded,
          },
          gradient: _grads[(i + 2) % _grads.length],
          title: c.label,
          sub: c.sub,
          selected: _cond == c,
          onTap: () => setState(() => _cond = c),
        ),
      TCard(
        padding: EdgeInsets.zero,
        child: SwitchListTile(
          value: _need5G,
          onChanged: (v) => setState(() => _need5G = v),
          secondary: const Icon(Icons.cell_tower_rounded, color: TX.violet),
          title: const Text(
            'Must have 5G',
            style: TextStyle(fontWeight: FontWeight.w800, color: TX.ink),
          ),
        ),
      ),
    ],
    bottom: TButton(
      label: 'Show my top 3 phones',
      icon: Icons.auto_awesome_rounded,
      onTap: _next,
    ),
  );

  Widget _results() {
    final pool = ref.watch(discoverPoolProvider).asData?.value;
    if (pool == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final b = _budget ?? _budgets[1];
    final pr = _priority ?? Priority.allRounder;
    final city = ref.watch(userCityProvider);
    final (picks, note) = findPhones(
      pool,
      min: b.min,
      max: b.max,
      priority: pr,
      brands: _brands,
      grades: _cond.grades,
      need5G: _need5G,
      city: city,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        THero(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR PERFECT MATCH',
                      style: TextStyle(
                        color: Color(0xFFC9D2FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      picks.isEmpty
                          ? 'No phones found'
                          : '${picks.length} phones picked for ${pr.label.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${b.label} • ${_brands.isEmpty ? 'Any brand' : _brands.join(', ')} • ${_cond.label}${_need5G ? ' • 5G' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFC9D2FF),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFFC542),
                size: 54,
              ),
            ],
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: TX.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    style: const TextStyle(fontSize: 12.5, color: TX.muted),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        for (final (i, pick) in picks.indexed) ...[
          _PickCard(rank: i + 1, pick: pick),
          const SizedBox(height: 12),
        ],
        if (picks.length >= 2)
          TGhost(
            label: 'Compare these ${picks.length}',
            icon: Icons.compare_arrows_rounded,
            color: TX.violet,
            onTap: () {
              ref.read(compareProvider.notifier).replaceAll([
                for (final p in picks) p.product,
              ]);
              context.push('/compare');
            },
          ),
        const SizedBox(height: 10),
        TButton(
          label: 'See all matching phones',
          icon: Icons.tune_rounded,
          onTap: () => context.push(
            '/explore',
            extra: PhoneFilter(
              minPrice: b.min,
              maxPrice: b.max,
              brands: _brands,
              grades: _cond.grades,
              only5G: _need5G,
              priority: pr,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.rank, required this.pick});
  final int rank;
  final FinderPick pick;

  @override
  Widget build(BuildContext context) {
    final p = pick.product;
    final medal = switch (rank) {
      1 => const [Color(0xFFFCD34D), Color(0xFFF59E0B)],
      2 => const [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
      _ => const [Color(0xFFFDBA74), Color(0xFFC2410C)],
    };
    return TCard(
      onTap: () => context.push('/product/${p.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F0FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: AppImage(
                      p.images.first,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Positioned(
                    left: -6,
                    top: -6,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: medal),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: TX.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: TX.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pick.match}% match',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${p.memoryLabel ?? ''} • ${p.colorName ?? ''}',
                      style: const TextStyle(fontSize: 12, color: TX.muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatPrice(p.price),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: TX.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FairPriceChip(fair: pick.fair, dense: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in pick.reasons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    r.startsWith('Slightly')
                        ? Icons.info_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: r.startsWith('Slightly') ? TX.amber : TX.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(fontSize: 13, color: TX.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
