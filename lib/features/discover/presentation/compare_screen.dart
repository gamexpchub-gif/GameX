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
import 'widgets/fair_price_meter.dart';

/// One comparable attribute. [score] decides the winner (higher wins);
/// null scores never win.
class _Spec {
  const _Spec(this.label, this.icon, this.value, {this.score, this.bar});
  final String label;
  final IconData icon;
  final String Function(Product) value;
  final double? Function(Product)? score;

  /// 0-10 bar instead of plain text.
  final int Function(Product)? bar;
}

const _gradeRank = {'Like New': 4, 'Excellent': 3, 'Good': 2, 'Fair': 1};

/// Side-by-side comparison of 2-3 phones with a GAMEX verdict.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(compareProvider);
    final pool = ref.watch(discoverPoolProvider).asData?.value ?? const [];
    final city = ref.watch(userCityProvider);
    final fair = {for (final p in list) p.id: fairPriceOf(p, market: pool)};

    final groups = <(String, List<_Spec>)>[
      (
        'Price & value',
        [
          _Spec(
            'Price',
            Icons.currency_rupee_rounded,
            (p) => formatPrice(p.price),
            score: (p) => -p.price,
          ),
          _Spec(
            'Fair Price meter',
            Icons.speed_rounded,
            (p) => fair[p.id]!.verdict.label,
            score: (p) => -fair[p.id]!.delta,
          ),
          _Spec('vs market', Icons.savings_outlined, (p) {
            final s = fair[p.id]!.savings;
            return s >= 0
                ? '${formatPrice(s)} less'
                : '${formatPrice(-s)} more';
          }, score: (p) => fair[p.id]!.savings),
        ],
      ),
      (
        'Condition',
        [
          _Spec(
            'Grade',
            Icons.auto_awesome_outlined,
            gradeOf,
            score: (p) => _gradeRank[gradeOf(p)]!.toDouble(),
          ),
          _Spec(
            'Battery health',
            Icons.battery_charging_full_rounded,
            (p) => '${batteryOf(p)}%',
            score: (p) => batteryOf(p).toDouble(),
          ),
          _Spec(
            'GAMEX verified',
            Icons.verified_rounded,
            (p) => p.verified ? 'Yes' : 'No',
          ),
        ],
      ),
      (
        'Performance',
        [
          _Spec('Processor', Icons.memory_rounded, (p) => modelInfo(p).chip),
          _Spec(
            'Gaming',
            Icons.sports_esports_rounded,
            (p) => '${modelInfo(p).gaming}/10',
            score: (p) => modelInfo(p).gaming.toDouble(),
            bar: (p) => modelInfo(p).gaming,
          ),
          _Spec(
            'RAM',
            Icons.developer_board_rounded,
            (p) => p.ram ?? '—',
            score: (p) => ramOf(p).toDouble(),
          ),
          _Spec(
            'Storage',
            Icons.sd_storage_outlined,
            (p) => p.storage ?? '—',
            score: (p) => storageOf(p).toDouble(),
          ),
        ],
      ),
      (
        'Camera, display & battery',
        [
          _Spec(
            'Camera',
            Icons.photo_camera_rounded,
            (p) => '${modelInfo(p).camera}/10',
            score: (p) => modelInfo(p).camera.toDouble(),
            bar: (p) => modelInfo(p).camera,
          ),
          _Spec(
            'Battery life',
            Icons.battery_full_rounded,
            (p) => '${modelInfo(p).battery}/10',
            score: (p) => modelInfo(p).battery.toDouble(),
            bar: (p) => modelInfo(p).battery,
          ),
          _Spec(
            'Battery size',
            Icons.bolt_rounded,
            (p) {
              final m = modelInfo(p).batteryMah;
              return m == 0 ? '—' : '$m mAh';
            },
            score: (p) {
              final m = modelInfo(p).batteryMah;
              return m == 0 ? null : m.toDouble();
            },
          ),
          _Spec('Display', Icons.smartphone_rounded, (p) {
            final d = modelInfo(p).display;
            return d.isEmpty ? (p.specs['Display'] ?? '—') : d;
          }),
          _Spec(
            '5G',
            Icons.cell_tower_rounded,
            (p) => modelInfo(p).is5G ? 'Yes' : 'No (4G)',
            score: (p) => modelInfo(p).is5G ? 1 : 0,
          ),
          _Spec(
            'Launched',
            Icons.event_rounded,
            (p) => '${modelInfo(p).year}',
            score: (p) => modelInfo(p).year.toDouble(),
          ),
        ],
      ),
      (
        'Protection & seller',
        [
          _Spec(
            'Warranty',
            Icons.shield_rounded,
            (p) =>
                p.warrantyMonths == 0 ? 'None' : '${p.warrantyMonths} months',
            score: (p) => p.warrantyMonths.toDouble(),
          ),
          _Spec(
            'Easy return',
            Icons.assignment_return_rounded,
            (p) => p.returnDays == 0 ? 'No returns' : '${p.returnDays} days',
            score: (p) => p.returnDays.toDouble(),
          ),
          _Spec(
            'Seller',
            Icons.storefront_rounded,
            (p) => '${sellerOf(p)}\n${p.rating.toStringAsFixed(1)}★',
            score: (p) => p.rating,
          ),
          _Spec(
            'Ships from',
            Icons.place_outlined,
            (p) => shipsFrom(p) == city
                ? '${shipsFrom(p)} (near you)'
                : shipsFrom(p),
            score: (p) => shipsFrom(p) == city ? 1 : 0,
          ),
        ],
      ),
    ];

    return TrustScaffold(
      title: 'Compare phones',
      subtitle: list.isEmpty
          ? 'Add up to $kMaxCompare phones'
          : '${list.length} of $kMaxCompare selected',
      trailing: list.isEmpty
          ? null
          : TextButton(
              onPressed: () => ref.read(compareProvider.notifier).clear(),
              child: const Text('Clear'),
            ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
      children: [
        _Heads(list: list, pool: pool),
        if (list.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(
              children: [
                const TIcon(Icons.compare_arrows_rounded, size: 60),
                const SizedBox(height: 12),
                Text(
                  list.isEmpty
                      ? 'Pick 2 or 3 phones to compare'
                      : 'Add one more phone',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Price, condition, battery, camera, gaming and warranty side by side, with the best value highlighted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TX.muted, height: 1.35),
                ),
              ],
            ),
          )
        else ...[
          _Verdict(list: list, fair: fair),
          for (final (title, specs) in groups) ...[
            TTitle(title),
            TCard(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Column(
                children: [
                  for (final (i, s) in specs.indexed)
                    _SpecRow(spec: s, list: list, last: i == specs.length - 1),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Scores are GAMEX estimates for each model (0-10). The winning value in every row is highlighted.',
            style: TextStyle(fontSize: 11.5, color: TX.faint, height: 1.35),
          ),
        ],
      ],
    );
  }
}

class _Heads extends ConsumerWidget {
  const _Heads({required this.list, required this.pool});
  final List<Product> list;
  final List<Product> pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = list.length < 2 ? 2 : 3;
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < slots; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: i < list.length
                    ? _Head(p: list[i])
                    : _AddSlot(pool: pool, picked: list),
              ),
            ),
        ],
      ),
    );
  }
}

class _Head extends ConsumerWidget {
  const _Head({required this.p});
  final Product p;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TCard(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
    onTap: () => context.push('/product/${p.id}'),
    child: Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () => ref.read(compareProvider.notifier).toggle(p),
            child: const Icon(Icons.close_rounded, size: 18, color: TX.faint),
          ),
        ),
        SizedBox(
          height: 78,
          child: AppImage(
            p.images.first,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          p.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: TX.ink,
            height: 1.2,
          ),
        ),
        Text(
          p.memoryLabel ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: TX.muted),
        ),
        const Spacer(),
        const SizedBox(height: 4),
        Text(
          formatPrice(p.price),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: TX.blue,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _AddSlot extends ConsumerWidget {
  const _AddSlot({required this.pool, required this.picked});
  final List<Product> pool;
  final List<Product> picked;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    onTap: () => _pick(context, ref),
    child: Container(
      constraints: const BoxConstraints(minHeight: 170),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: TX.violet.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_rounded, color: TX.violet, size: 34),
          SizedBox(height: 6),
          Text(
            'Add phone',
            style: TextStyle(fontWeight: FontWeight.w800, color: TX.violet),
          ),
        ],
      ),
    ),
  );

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet(pool: pool, picked: picked),
    );
    if (p != null) ref.read(compareProvider.notifier).toggle(p);
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.pool, required this.picked});
  final List<Product> pool;
  final List<Product> picked;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final ids = {for (final p in widget.picked) p.id};
    final f = PhoneFilter(text: _q, sort: DiscoverSort.relevance);
    final seen = <String>{};
    final list = [
      for (final p in f.apply(widget.pool))
        if (!ids.contains(p.id) &&
            seen.add('${p.name}|${p.storage}|${gradeOf(p)}'))
          p,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: tInput(
                'Search a phone to compare',
                prefix: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = list[i];
                return TCard(
                  padding: const EdgeInsets.all(10),
                  onTap: () => Navigator.pop(context, p),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: AppImage(
                          p.images.first,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: TX.ink,
                              ),
                            ),
                            Text(
                              '${p.memoryLabel ?? ''} • ${gradeOf(p)} • ${batteryOf(p)}% battery',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TX.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatPrice(p.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: TX.blue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.spec, required this.list, required this.last});
  final _Spec spec;
  final List<Product> list;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scores = [for (final p in list) spec.score?.call(p)];
    final valid = scores.whereType<double>().toList();
    final best = valid.isEmpty ? null : valid.reduce((a, b) => a > b ? a : b);
    final tie = best != null && valid.every((s) => s == best);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0EEFA))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 15, color: TX.violet),
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: TX.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, p) in list.indexed)
                Expanded(
                  child: _cell(
                    p,
                    win: !tie && best != null && scores[i] == best,
                  ),
                ),
              if (list.length == 2) const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(Product p, {required bool win}) {
    final text = spec.value(p);
    final verdictColorFor = spec.label == 'Fair Price meter'
        ? verdictColor(PriceVerdict.values.firstWhere((v) => v.label == text))
        : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: win ? TX.green.withValues(alpha: 0.1) : const Color(0xFFF7F6FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: win ? TX.green.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: win ? FontWeight.w900 : FontWeight.w600,
                    color: verdictColorFor ?? (win ? TX.green : TX.ink),
                  ),
                ),
              ),
              if (win)
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 14,
                  color: Color(0xFFF59E0B),
                ),
            ],
          ),
          if (spec.bar != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: spec.bar!(p) / 10,
                minHeight: 5,
                backgroundColor: TX.line,
                valueColor: AlwaysStoppedAnimation(win ? TX.green : TX.violet),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.list, required this.fair});
  final List<Product> list;
  final Map<String, FairPrice> fair;

  @override
  Widget build(BuildContext context) {
    Product best(double Function(Product) f) =>
        list.reduce((a, b) => f(a) >= f(b) ? a : b);
    double overall(Product p) {
      final m = modelInfo(p);
      return m.allRounder * 1.0 +
          (-fair[p.id]!.delta * 20) +
          (batteryOf(p) - 85) * 0.1 +
          (_gradeRank[gradeOf(p)]! * 0.5) +
          p.warrantyMonths * 0.08;
    }

    final winner = best(overall);
    final picks = [
      ('Best value', Icons.savings_rounded, best((p) => -fair[p.id]!.delta)),
      (
        'Gaming',
        Icons.sports_esports_rounded,
        best((p) => modelInfo(p).gaming + batteryOf(p) / 1000),
      ),
      (
        'Camera',
        Icons.photo_camera_rounded,
        best((p) => modelInfo(p).camera + batteryOf(p) / 1000),
      ),
      (
        'Battery',
        Icons.battery_full_rounded,
        best((p) => modelInfo(p).battery + batteryOf(p) / 100),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: THero(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GAMEX VERDICT',
              style: TextStyle(
                color: Color(0xFFC9D2FF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Best overall: ${winner.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${gradeOf(winner)} • ${batteryOf(winner)}% battery • ${fair[winner.id]!.verdict.label.toLowerCase()} at ${formatPrice(winner.price)}',
              style: const TextStyle(color: Color(0xFFC9D2FF), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, icon, p) in picks)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: const Color(0xFFFFC542)),
                        const SizedBox(width: 5),
                        Text(
                          '$label: ',
                          style: const TextStyle(
                            color: Color(0xFFC9D2FF),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: Builder(
                builder: (context) => TButton(
                  label: 'View ${winner.name}',
                  height: 46,
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => context.push('/product/${winner.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
