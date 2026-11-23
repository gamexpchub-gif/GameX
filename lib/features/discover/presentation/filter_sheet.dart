import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models/product.dart';
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/phone_filter.dart';
import '../data/phone_intel.dart';

/// Full Smart Filter sheet. Returns the new filter, or null if dismissed.
Future<PhoneFilter?> showFilterSheet(
  BuildContext context, {
  required List<Product> pool,
  required PhoneFilter filter,
  required String userCity,
}) => showModalBottomSheet<PhoneFilter>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _FilterSheet(pool: pool, start: filter, userCity: userCity),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.pool,
    required this.start,
    required this.userCity,
  });
  final List<Product> pool;
  final PhoneFilter start;
  final String userCity;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late PhoneFilter f = widget.start;

  int get _count => widget.pool.where(f.matches).length;

  void _set(PhoneFilter n) {
    HapticFeedback.selectionClick();
    setState(() => f = n);
  }

  Set<T> _flip<T>(Set<T> s, T v) =>
      s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  static String _money(double v) => v >= kMaxPrice
      ? '₹1.6L+'
      : v >= 100000
      ? '₹${(v / 100000).toStringAsFixed(2)}L'
      : '₹${(v / 1000).round()}K';

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Container(
      height: h * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F4FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: TX.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                const Text(
                  'Smart filters',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: f.count == 0 ? null : () => _set(f.cleared()),
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                _section(
                  'Budget',
                  trailing: Text(
                    '${_money(f.minPrice)} – ${_money(f.maxPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TX.violet,
                    ),
                  ),
                  child: Column(
                    children: [
                      RangeSlider(
                        values: RangeValues(f.minPrice, f.maxPrice),
                        min: kMinPrice,
                        max: kMaxPrice,
                        divisions: 62,
                        onChanged: (v) => setState(
                          () => f = f.copyWith(
                            minPrice: (v.start / 1000).round() * 1000,
                            maxPrice: (v.end / 1000).round() * 1000,
                          ),
                        ),
                      ),
                      _chips<(double, double)>(
                        const [
                          (kMinPrice, 20000),
                          (20000, 35000),
                          (35000, 50000),
                          (50000, 75000),
                          (75000, kMaxPrice),
                        ],
                        label: (r) => r.$1 <= kMinPrice
                            ? 'Under ₹20K'
                            : r.$2 >= kMaxPrice
                            ? '₹75K+'
                            : '${_money(r.$1)}–${_money(r.$2)}',
                        selected: (r) =>
                            f.minPrice == r.$1 && f.maxPrice == r.$2,
                        onTap: (r) => _set(
                          f.minPrice == r.$1 && f.maxPrice == r.$2
                              ? f.copyWith(
                                  minPrice: kMinPrice,
                                  maxPrice: kMaxPrice,
                                )
                              : f.copyWith(minPrice: r.$1, maxPrice: r.$2),
                        ),
                      ),
                    ],
                  ),
                ),
                _section(
                  'Brand',
                  child: _chips<String>(
                    kBrands,
                    label: (b) => b == 'Xiaomi' ? 'Xiaomi / Redmi' : b,
                    selected: f.brands.contains,
                    onTap: (b) => _set(f.copyWith(brands: _flip(f.brands, b))),
                  ),
                ),
                _section(
                  'Condition',
                  child: _chips<String>(
                    kGrades,
                    label: (g) => g,
                    selected: f.grades.contains,
                    onTap: (g) => _set(f.copyWith(grades: _flip(f.grades, g))),
                  ),
                ),
                _section(
                  'Battery health',
                  child: _chips<int>(
                    const [0, 80, 85, 90, 95],
                    label: (v) => v == 0 ? 'Any' : '$v%+',
                    selected: (v) => f.minBattery == v,
                    onTap: (v) => _set(f.copyWith(minBattery: v)),
                  ),
                ),
                _section(
                  'RAM',
                  child: _chips<int>(
                    kRamOptions,
                    label: (v) => v == 16 ? '16GB+' : '${v}GB',
                    selected: f.ram.contains,
                    onTap: (v) => _set(f.copyWith(ram: _flip(f.ram, v))),
                  ),
                ),
                _section(
                  'Storage',
                  child: _chips<int>(
                    kStorageOptions,
                    label: (v) => v == 512 ? '512GB+' : '${v}GB',
                    selected: f.storage.contains,
                    onTap: (v) =>
                        _set(f.copyWith(storage: _flip(f.storage, v))),
                  ),
                ),
                _section(
                  'Seller rating',
                  child: _chips<double>(
                    const [0, 4.0, 4.5, 4.8],
                    label: (v) => v == 0 ? 'Any' : '$v★ & up',
                    selected: (v) => f.minRating == v,
                    onTap: (v) => _set(f.copyWith(minRating: v)),
                  ),
                ),
                _section(
                  'Ships from',
                  child: _chips<String?>(
                    [null, ...kCities],
                    label: (c) => c == null
                        ? 'Anywhere'
                        : c == widget.userCity
                        ? '$c (my city)'
                        : c,
                    selected: (c) => f.city == c,
                    onTap: (c) => _set(f.copyWith(city: () => c)),
                  ),
                ),
                TCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _switch(
                        Icons.cell_tower_rounded,
                        '5G phones only',
                        'Ready for Jio & Airtel 5G',
                        f.only5G,
                        (v) => _set(f.copyWith(only5G: v)),
                      ),
                      _switch(
                        Icons.shield_rounded,
                        'With seller warranty',
                        '3 to 12 months, claim in the app',
                        f.warranty,
                        (v) => _set(f.copyWith(warranty: v)),
                      ),
                      _switch(
                        Icons.inventory_2_rounded,
                        'In stock only',
                        'Hide sold-out listings',
                        f.inStock,
                        (v) => _set(f.copyWith(inStock: v)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: TX.soft(0.08),
            ),
            child: TButton(
              label: _count == 0
                  ? 'No phones match'
                  : 'Show $_count phone${_count == 1 ? '' : 's'}',
              icon: Icons.tune_rounded,
              onTap: _count == 0 ? null : () => Navigator.pop(context, f),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, {required Widget child, Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _chips<T>(
    List<T> items, {
    required String Function(T) label,
    required bool Function(T) selected,
    required void Function(T) onTap,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final i in items) FChip(label(i), selected(i), () => onTap(i)),
    ],
  );

  Widget _switch(
    IconData icon,
    String title,
    String sub,
    bool v,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile(
    value: v,
    onChanged: onChanged,
    secondary: Icon(icon, color: TX.violet),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, color: TX.ink),
    ),
    subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: TX.muted)),
  );
}

/// Gradient selectable chip used across the discover screens.
class FChip extends StatelessWidget {
  const FChip(this.label, this.selected, this.onTap, {super.key, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        gradient: selected ? TX.chip : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.transparent : TX.line),
        boxShadow: selected ? TX.soft(0.18) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? Colors.white : TX.violet),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : TX.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
