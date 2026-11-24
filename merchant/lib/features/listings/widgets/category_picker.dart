import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/catalog.dart';
import 'listing_ui.dart';

/// Full-screen picker: search everything ("iphone 13") or browse
/// Category › Brand › Model. Returns the chosen path; `model == null` means
/// the seller will type the model themselves.
Future<CatalogHit?> showCategoryPicker(
  BuildContext context, {
  ProductCategory? category,
  String? brand,
}) => showModalBottomSheet<CatalogHit>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xFFF6F5FF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
  builder: (_) => _Picker(category: category, brand: brand),
);

class _Picker extends StatefulWidget {
  const _Picker({this.category, this.brand});
  final ProductCategory? category;
  final String? brand;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final _q = TextEditingController();
  ProductCategory? _cat;
  String? _brand;

  @override
  void initState() {
    super.initState();
    _cat = widget.category;
    _brand = widget.brand != null &&
            (widget.category?.brands.containsKey(widget.brand) ?? false)
        ? widget.brand
        : null;
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _back() {
    HapticFeedback.selectionClick();
    setState(() {
      _q.clear();
      if (_brand != null) {
        _brand = null;
      } else {
        _cat = null;
      }
    });
  }

  String get _hint => _brand != null
      ? 'Search $_brand models'
      : _cat != null
      ? 'Search brands in ${_cat!.plural}'
      : 'Search e.g. iPhone 13, Galaxy S23, AirPods';

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: LX.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                if (_cat != null)
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                else
                  const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Choose product category',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: LX.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          _crumbs(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _q,
              autofocus: _cat == null,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_q.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: LX.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: LX.line),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey('${_cat?.name}|$_brand|${q.isEmpty}'),
                child: _cat == null && q.isNotEmpty
                    ? _global(q)
                    : _cat == null
                    ? _categories()
                    : _brand == null
                    ? _brands(q)
                    : _models(q),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crumbs() {
    final parts = [
      ('All categories', () => setState(() => _cat = _brand = null)),
      if (_cat != null) (_cat!.plural, () => setState(() => _brand = null)),
      if (_brand != null) (_brand!, () {}),
    ];
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final (i, p) in parts.indexed) ...[
            if (i > 0)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: LX.muted,
              ),
            GestureDetector(
              onTap: () {
                _q.clear();
                p.$2();
              },
              child: Center(
                child: Text(
                  p.$1,
                  style: TextStyle(
                    fontWeight: i == parts.length - 1
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: i == parts.length - 1 ? LX.violet : LX.muted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categories() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          'What are you selling?',
          style: TextStyle(color: LX.muted, fontWeight: FontWeight.w600),
        ),
      ),
      for (final c in kCategories)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LxCard(
            onTap: () => setState(() => _cat = c),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LX.chip,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(c.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.plural,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: LX.ink,
                        ),
                      ),
                      Text(
                        '${c.brands.length} brands • ${c.brands.values.fold<int>(0, (t, m) => t + m.length)} models',
                        style: const TextStyle(color: LX.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: LX.muted),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _global(String q) {
    final hits = searchCatalog(q, limit: 40);
    if (hits.isEmpty) {
      return _empty(
        'No match for "$q"',
        'Pick the category and brand, then type the model yourself.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final h = hits[i];
        return LxCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          onTap: () {
            if (h.model == null) {
              _q.clear();
              setState(() {
                _cat = h.category;
                _brand = h.brand;
              });
            } else {
              Navigator.pop(context, h);
            }
          },
          child: Row(
            children: [
              BrandBadge(h.brand, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.model ?? '${h.brand} — all models',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: LX.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      h.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: LX.muted),
                    ),
                  ],
                ),
              ),
              Icon(h.category.icon, size: 20, color: LX.violet),
            ],
          ),
        );
      },
    );
  }

  Widget _brands(String q) {
    final c = _cat!;
    final all = c.brands.keys.toList();
    final list = [
      for (final b in all)
        if (b.toLowerCase().contains(q.toLowerCase())) b,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (list.isEmpty)
          _empty('No brand "$q"', 'Add it as another brand below.')
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final b in list)
                LxCard(
                  padding: const EdgeInsets.all(8),
                  radius: 18,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _q.clear();
                    setState(() => _brand = b);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BrandBadge(b, size: 42),
                      const SizedBox(height: 8),
                      Text(
                        b,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: LX.ink,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${c.brands[b]!.length} models',
                        style: const TextStyle(fontSize: 11, color: LX.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 14),
        _OtherTile(
          title: 'Other brand',
          subtitle: 'Not in the list? Type the brand name',
          onTap: () async {
            final b = await _ask(context, 'Brand name', q);
            if (b != null && mounted) {
              Navigator.pop(context, CatalogHit(c, b));
            }
          },
        ),
      ],
    );
  }

  Widget _models(String q) {
    final c = _cat!;
    final models = c.brands[_brand] ?? const <String>[];
    final ql = q.toLowerCase().replaceAll(' ', '');
    final list = [
      for (final m in models)
        if (m.toLowerCase().replaceAll(' ', '').contains(ql)) m,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final m in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LxCard(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
              radius: 16,
              onTap: () => Navigator.pop(context, CatalogHit(c, _brand!, m)),
              child: Row(
                children: [
                  Icon(c.icon, size: 20, color: LX.violet),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: LX.ink,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: LX.muted),
                ],
              ),
            ),
          ),
        if (list.isEmpty)
          _empty('No model "$q"', 'Use "My model isn\'t listed" below.'),
        const SizedBox(height: 6),
        _OtherTile(
          title: 'My model isn\'t listed',
          subtitle: 'Type the exact model name',
          onTap: () async {
            final m = await _ask(context, 'Model name', q);
            if (m != null && mounted) {
              Navigator.pop(context, CatalogHit(c, _brand!, m));
            }
          },
        ),
      ],
    );
  }

  Widget _empty(String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
    child: Column(
      children: [
        const Icon(Icons.search_off_rounded, size: 44, color: LX.muted),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, color: LX.ink),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: LX.muted),
        ),
      ],
    ),
  );
}

Future<String?> _ask(BuildContext context, String label, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.pop(d, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(d, c.text.trim().isEmpty ? null : c.text.trim()),
          child: const Text('Use this'),
        ),
      ],
    ),
  );
}

class _OtherTile extends StatelessWidget {
  const _OtherTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DashedBox(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: LX.violet, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: LX.violet,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: LX.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Brand logo when bundled, otherwise a gradient monogram.
class BrandBadge extends StatelessWidget {
  const BrandBadge(this.brand, {super.key, this.size = 40});
  final String brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = brandLogo(brand);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: logo == null ? null : Colors.white,
        gradient: logo == null ? LX.chip : null,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: logo == null ? null : Border.all(color: LX.line),
      ),
      alignment: Alignment.center,
      child: logo != null
          ? Image.asset(
              'assets/img/brands/brand_$logo.png',
              fit: BoxFit.contain,
            )
          : Text(
              brand.characters.first.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}
