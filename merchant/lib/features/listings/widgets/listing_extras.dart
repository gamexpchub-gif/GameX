// Listing editor sections: variants (colour / storage with their own price),
// product highlight photos, specifications and the inspection checklist.
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets.dart';
import '../../../data/catalog.dart';
import '../../../data/models.dart';
import 'listing_ui.dart';

const kRams = ['3GB', '4GB', '6GB', '8GB', '12GB', '16GB', '24GB'];
const kStorages = ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB', '2TB'];

Future<String?> _pickImage(BuildContext context) async {
  try {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    return f?.path;
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Could not open the gallery', icon: Icons.error_outline);
    }
    return null;
  }
}

Color _swatch(String name, int? hex) =>
    Color(hex ?? colourHex(name) ?? 0xFFB9BCCB);

// ═══════════════════════════════ VARIANTS ═══════════════════════════════

/// "Main option" + extra colour / storage variants with their own price.
class VariantsCard extends StatelessWidget {
  const VariantsCard({super.key, required this.listing, required this.onChanged});
  final Listing listing;
  final ValueChanged<Listing> onChanged;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final l = listing;
    final v = await showModalBottomSheet<ListingVariant>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF6F5FF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _VariantSheet(
        listing: l,
        initial: index == null ? null : l.variants[index],
      ),
    );
    if (v == null) return;
    final list = [...l.variants];
    if (index == null) {
      list.add(v);
    } else {
      list[index] = v;
    }
    onChanged(l.copyWith(variants: list));
  }

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final mainLabel =
        '${l.ram.isEmpty ? '' : '${l.ram} / '}${l.storage} • ${l.color.isEmpty ? '—' : l.color}';
    return LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LxSection(
            icon: Icons.style_outlined,
            title: 'Variants',
            optional: true,
            subtitle: 'Other colours or storage with their own price',
            trailing: l.variants.length >= 30
                ? null
                : GestureDetector(
                    onTap: () => _edit(context),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, color: LX.violet, size: 20),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: LX.violet,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          _VariantRow(
            colour: _swatch(l.color, null),
            title: mainLabel,
            badge: 'MAIN',
            price: l.price,
            mrp: l.mrp,
            stock: l.stock,
          ),
          for (final (i, v) in l.variants.indexed) ...[
            const SizedBox(height: 8),
            _VariantRow(
              colour: _swatch(v.color, v.colorHex),
              title: v.label,
              price: v.price,
              mrp: v.mrp,
              stock: v.stock,
              photo: v.photo,
              onTap: () => _edit(context, i),
              onDelete: () {
                HapticFeedback.selectionClick();
                onChanged(
                  l.copyWith(variants: [...l.variants]..removeAt(i)),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          if (l.variants.isEmpty)
            DashedBox(
              onTap: () => _edit(context),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: LX.violet),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Have the same model in another colour or storage? Add it here with its own price and stock.',
                        style: TextStyle(color: LX.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              '${l.variants.length + 1} options • ${l.totalStock} units in total. Buyers pick colour & storage and see that price.',
              style: const TextStyle(color: LX.muted, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({
    required this.colour,
    required this.title,
    required this.price,
    required this.mrp,
    required this.stock,
    this.badge,
    this.photo,
    this.onTap,
    this.onDelete,
  });
  final Color colour;
  final String title;
  final int price;
  final int mrp;
  final int stock;
  final String? badge;
  final String? photo;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: badge != null ? const Color(0xFFF3EFFF) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LX.line),
        ),
        child: Row(
          children: [
            if (photo != null)
              Photo(photo!, size: 38, radius: 10, pad: 0)
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                  border: Border.all(color: LX.line, width: 2),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: LX.ink,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LX.chip,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${price == 0 ? 'Price in step 4' : inr(price)}${mrp > price ? '  •  MRP ${inr(mrp)}' : ''}  •  $stock in stock',
                    style: const TextStyle(fontSize: 12, color: LX.muted),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: LX.red),
              ),
          ],
        ),
      ),
    ),
  );
}

class _VariantSheet extends StatefulWidget {
  const _VariantSheet({required this.listing, this.initial});
  final Listing listing;
  final ListingVariant? initial;

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  late String _colour;
  late String _storage;
  late String _ram;
  late final TextEditingController _price, _mrp, _otherColour;
  late int _stock;
  String? _photo;

  static const _quick = [
    'Black', 'White', 'Blue', 'Purple', 'Green', 'Red', 'Gold', 'Silver',
    'Pink', 'Grey', 'Midnight', 'Starlight', 'Natural Titanium', 'Black Titanium',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    final l = widget.listing;
    _colour = v?.color ?? '';
    _storage = v?.storage ?? l.storage;
    _ram = v?.ram ?? l.ram;
    _stock = v?.stock ?? 1;
    _photo = v?.photo;
    _price = TextEditingController(text: v == null ? '' : '${v.price}');
    _mrp = TextEditingController(text: v == null || v.mrp == 0 ? '' : '${v.mrp}');
    _otherColour = TextEditingController(
      text: _quick.contains(_colour) ? '' : _colour,
    );
  }

  @override
  void dispose() {
    for (final c in [_price, _mrp, _otherColour]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _colourName =>
      _quick.contains(_colour) ? _colour : _otherColour.text.trim();

  void _save() {
    final l = widget.listing;
    final price = int.tryParse(_price.text) ?? 0;
    final mrp = int.tryParse(_mrp.text) ?? price;
    final colour = _colourName;
    String? err;
    if (colour.isEmpty) {
      err = 'Choose the colour';
    } else if (price < 500) {
      err = 'Enter the selling price';
    } else if (mrp < price) {
      err = 'MRP must be at least the selling price';
    } else {
      bool same(String c, String s, String r) =>
          c.toLowerCase() == colour.toLowerCase() &&
          s == _storage &&
          r == _ram;
      final dupMain = same(l.color, l.storage, l.ram);
      final dupOther = l.variants.any(
        (v) => v.id != widget.initial?.id && same(v.color, v.storage, v.ram),
      );
      if (dupMain || dupOther) err = 'This colour + storage already exists';
    }
    if (err != null) {
      return snack(context, err, icon: Icons.error_outline_rounded);
    }
    Navigator.pop(
      context,
      ListingVariant(
        id: widget.initial?.id ??
            'V${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
        color: colour,
        colorHex: colourHex(colour),
        storage: _storage,
        ram: _ram,
        price: price,
        mrp: mrp,
        stock: _stock,
        photo: _photo,
      ),
    );
  }

  Widget _chips(List<String> items, String value, ValueChanged<String> set) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in items)
            LxPill(
              label: v,
              selected: v == value,
              onTap: () => setState(() => set(v)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final l = widget.listing;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: LX.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.initial == null ? 'Add variant' : 'Edit variant',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: LX.ink,
                    ),
                  ),
                  Text(
                    '${l.title.isEmpty ? 'This product' : l.title} in another colour or storage',
                    style: const TextStyle(color: LX.muted),
                  ),
                  const SizedBox(height: 18),
                  const _Label('Colour'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _quick)
                        GestureDetector(
                          onTap: () => setState(() => _colour = c),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _swatch(c, null),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _colour == c ? LX.violet : LX.line,
                                    width: _colour == c ? 3 : 1.5,
                                  ),
                                ),
                                child: _colour == c
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color:
                                            _swatch(c, null).computeLuminance() >
                                                0.5
                                            ? LX.ink
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 54,
                                child: Text(
                                  c,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: LX.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _otherColour,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) => setState(() => _colour = v.trim()),
                    decoration: _input('Or type the colour name, e.g. Desert Titanium'),
                  ),
                  const SizedBox(height: 18),
                  const _Label('Storage'),
                  _chips(kStorages, _storage, (v) => _storage = v),
                  if (l.deviceType != 'Earbuds & Audio') ...[
                    const SizedBox(height: 18),
                    const _Label('RAM'),
                    _chips(kRams, _ram, (v) => _ram = v),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Label('Selling price'),
                            TextField(
                              controller: _price,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _input('₹ price', prefix: '₹ '),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Label('MRP'),
                            TextField(
                              controller: _mrp,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _input('Original price', prefix: '₹ '),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (l.price > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Main option is ${inr(l.price)} (${l.storage} • ${l.color})',
                      style: const TextStyle(fontSize: 12, color: LX.muted),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: _Label('Units in stock')),
                      _RoundBtn(
                        Icons.remove_rounded,
                        _stock > 0 ? () => setState(() => _stock--) : null,
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '$_stock',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _RoundBtn(
                        Icons.add_rounded,
                        _stock < 99 ? () => setState(() => _stock++) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _Label('Photo of this colour (optional)'),
                  Row(
                    children: [
                      if (_photo != null) ...[
                        Photo(_photo!, size: 64, radius: 14, pad: 0),
                        const SizedBox(width: 10),
                      ],
                      LxPill(
                        label: _photo == null ? 'Add photo' : 'Change',
                        selected: false,
                        leading: const Icon(Icons.add_a_photo_outlined, size: 18),
                        onTap: () async {
                          final p = await _pickImage(context);
                          if (p != null) setState(() => _photo = p);
                        },
                      ),
                      if (_photo != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _photo = null),
                          child: const Text('Remove'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: LxButton(
                  label: widget.initial == null ? 'Add variant' : 'Save variant',
                  icon: Icons.check_rounded,
                  height: 54,
                  onTap: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════ HIGHLIGHTS ═══════════════════════════════

/// Feature images shown on the product page ("48MP camera", "120Hz").
class HighlightsCard extends StatelessWidget {
  const HighlightsCard({
    super.key,
    required this.listing,
    required this.onChanged,
  });
  final Listing listing;
  final ValueChanged<Listing> onChanged;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final l = listing;
    final h = await showModalBottomSheet<Highlight>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF6F5FF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) =>
          _HighlightSheet(initial: index == null ? null : l.highlights[index]),
    );
    if (h == null) return;
    final list = [...l.highlights];
    if (index == null) {
      list.add(h);
    } else {
      list[index] = h;
    }
    onChanged(l.copyWith(highlights: list));
  }

  @override
  Widget build(BuildContext context) {
    final hs = listing.highlights;
    return LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LxSection(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: 'Product Highlights',
            optional: true,
            subtitle: 'Banner photos of key features — shown big on the product page',
          ),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, h) in hs.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => _edit(context, i),
                      child: SizedBox(
                        width: 130,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Photo(h.image, radius: 16, pad: 0),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.75),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  h.title.isEmpty ? 'Highlight ${i + 1}' : h.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () => onChanged(
                                  listing.copyWith(
                                    highlights: [...hs]..removeAt(i),
                                  ),
                                ),
                                child: const CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: LX.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (hs.length < 10)
                  SizedBox(
                    width: 130,
                    child: DashedBox(
                      onTap: () => _edit(context),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: LX.violet,
                              size: 30,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Add highlight',
                              style: TextStyle(
                                color: LX.violet,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Photo + caption',
                              style: TextStyle(color: LX.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
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

class _HighlightSheet extends StatefulWidget {
  const _HighlightSheet({this.initial});
  final Highlight? initial;

  @override
  State<_HighlightSheet> createState() => _HighlightSheetState();
}

class _HighlightSheetState extends State<_HighlightSheet> {
  String? _image;
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _text = TextEditingController(text: widget.initial?.text);

  static const _ideas = [
    'Pro camera system',
    '120Hz smooth display',
    'All-day battery',
    'Fast charging',
    'Flagship performance',
    'Premium design',
    'Original box & bill',
    'Like-new condition',
  ];

  @override
  void initState() {
    super.initState();
    _image = widget.initial?.image;
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Product highlight',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: LX.ink,
                ),
              ),
              const Text(
                'A clear photo of one feature (camera, screen, box…) with a short caption.',
                style: TextStyle(color: LX.muted),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final p = await _pickImage(context);
                  if (p != null) setState(() => _image = p);
                },
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _image == null
                      ? const DashedBox(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: LX.violet,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tap to choose photo',
                                  style: TextStyle(
                                    color: LX.violet,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Photo(_image!, radius: 18, pad: 0),
                ),
              ),
              const SizedBox(height: 14),
              const _Label('Caption'),
              TextField(
                controller: _title,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: _input('e.g. 48MP Pro camera'),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final i in _ideas)
                    ActionChip(
                      label: Text(i, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _title.text = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const _Label('Short description (optional)'),
              TextField(
                controller: _text,
                maxLength: 160,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _input('e.g. Night mode and 4K video — tested by us'),
              ),
              const SizedBox(height: 8),
              LxButton(
                label: 'Save highlight',
                icon: Icons.check_rounded,
                height: 54,
                onTap: () {
                  if (_image == null) {
                    return snack(
                      context,
                      'Choose a photo',
                      icon: Icons.error_outline_rounded,
                    );
                  }
                  Navigator.pop(
                    context,
                    Highlight(
                      image: _image!,
                      title: _title.text.trim(),
                      text: _text.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════ SPECIFICATIONS ═══════════════════════════════

class SpecsCard extends StatelessWidget {
  const SpecsCard({super.key, required this.listing, required this.onChanged});
  final Listing listing;
  final ValueChanged<Listing> onChanged;

  Future<void> _open(BuildContext context) async {
    final rows = await Navigator.of(context).push<List<SpecRow>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SpecEditor(listing: listing),
      ),
    );
    if (rows != null) onChanged(listing.copyWith(specs: rows));
  }

  @override
  Widget build(BuildContext context) {
    final specs = listing.specs;
    final total = specTemplate(listing.deviceType).length;
    final groups = <String, List<SpecRow>>{};
    for (final s in specs) {
      (groups[s.group] ??= []).add(s);
    }
    return LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LxSection(
            icon: Icons.list_alt_rounded,
            title: 'Specifications',
            optional: true,
            subtitle: specs.isEmpty
                ? 'Display, processor, camera, battery…'
                : '${specs.length} added • buyers compare these',
            trailing: GestureDetector(
              onTap: () => _open(context),
              child: Text(
                specs.isEmpty ? 'Add' : 'Edit',
                style: const TextStyle(
                  color: LX.violet,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (specs.isEmpty)
            DashedBox(
              onTap: () => _open(context),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add_rounded, color: LX.violet),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$total ready-made fields with one-tap suggestions. Listings with full specs get more orders.',
                        style: const TextStyle(color: LX.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final e in groups.entries.take(3)) ...[
              Text(
                e.key.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                  color: LX.violet,
                ),
              ),
              const SizedBox(height: 4),
              for (final r in e.value.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          r.key,
                          style: const TextStyle(color: LX.muted, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
          if (groups.length > 3)
            Text(
              '+ ${groups.length - 3} more sections',
              style: const TextStyle(color: LX.muted, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

class _SpecEditor extends StatefulWidget {
  const _SpecEditor({required this.listing});
  final Listing listing;

  @override
  State<_SpecEditor> createState() => _SpecEditorState();
}

class _SpecEditorState extends State<_SpecEditor> {
  late final List<SpecField> _fields = specTemplate(widget.listing.deviceType);
  final _ctrl = <String, TextEditingController>{};
  final _custom = <(TextEditingController, TextEditingController)>[];

  String _id(SpecField f) => '${f.group}|${f.key}';

  @override
  void initState() {
    super.initState();
    final existing = {
      for (final r in widget.listing.specs) '${r.group}|${r.key}': r.value,
    };
    for (final f in _fields) {
      _ctrl[_id(f)] = TextEditingController(text: existing.remove(_id(f)));
    }
    for (final r in widget.listing.specs) {
      if (existing.containsKey('${r.group}|${r.key}')) {
        _custom.add((
          TextEditingController(text: r.key),
          TextEditingController(text: r.value),
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    for (final (a, b) in _custom) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  void _done() {
    Navigator.pop(context, [
      for (final f in _fields)
        if (_ctrl[_id(f)]!.text.trim().isNotEmpty)
          SpecRow(f.group, f.key, _ctrl[_id(f)]!.text.trim()),
      for (final (k, v) in _custom)
        if (k.text.trim().isNotEmpty && v.text.trim().isNotEmpty)
          SpecRow('Other', k.text.trim(), v.text.trim()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<SpecField>>{};
    for (final f in _fields) {
      (groups[f.group] ??= []).add(f);
    }
    final filled = _ctrl.values.where((c) => c.text.trim().isNotEmpty).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F5FF),
        title: const Text(
          'Specifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            '${widget.listing.title.isEmpty ? widget.listing.deviceType : widget.listing.title} • $filled of ${_fields.length} filled. RAM, storage, colour, network and SIM are added automatically.',
            style: const TextStyle(color: LX.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          for (final e in groups.entries) ...[
            LxCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: LX.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final f in e.value) _field(f),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          LxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Other details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: LX.ink,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (i, (k, v)) in _custom.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: k,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _input('Name'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: v,
                            decoration: _input('Value'),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _custom.removeAt(i)),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: LX.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: _custom.length >= 20
                      ? null
                      : () => setState(
                          () => _custom.add((
                            TextEditingController(),
                            TextEditingController(),
                          )),
                        ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add your own row'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LxButton(label: 'Save specifications', icon: Icons.check_rounded, onTap: _done),
        ],
      ),
    );
  }

  Widget _field(SpecField f) {
    final c = _ctrl[_id(f)]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            decoration: _input(f.key).copyWith(
              labelText: f.key,
              hintText: f.suggestions.isEmpty ? null : 'e.g. ${f.suggestions.first}',
              suffixIcon: c.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(c.clear),
                    ),
            ),
          ),
          if (f.suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in f.suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        selected: c.text == s,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => c.text = s),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════ INSPECTION ═══════════════════════════════

/// Tick what works. Buyers see the full report: ticks for working items,
/// "Not working / not checked" for the rest.
class InspectionCard extends StatelessWidget {
  const InspectionCard({
    super.key,
    required this.listing,
    required this.onChanged,
  });
  final Listing listing;
  final ValueChanged<Listing> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final groups = inspectionFor(l.deviceType, l.brand);
    final items = [for (final g in groups) ...g.items];
    final ok = items.where((i) => l.checks[i] == true).length;
    final pct = items.isEmpty ? 0.0 : ok / items.length;
    void set(String item, bool v) => onChanged(
      l.copyWith(
        checks: {
          for (final i in items) i: l.checks[i] ?? false,
          item: v,
        },
      ),
    );
    return LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LxSection(
            icon: Icons.fact_check_outlined,
            title: 'Inspection Checklist',
            subtitle: 'Tick everything that works — buyers see this report',
            trailing: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                final all = ok < items.length;
                onChanged(l.copyWith(checks: {for (final i in items) i: all}));
              },
              child: Text(ok < items.length ? 'Tick all' : 'Clear'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: LX.line,
                    color: pct == 1
                        ? LX.green
                        : pct >= 0.75
                        ? const Color(0xFFF59E0B)
                        : LX.red,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$ok / ${items.length} working',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final g in groups) ...[
            Row(
              children: [
                Icon(g.icon, size: 18, color: LX.violet),
                const SizedBox(width: 6),
                Text(
                  g.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: LX.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final i in g.items)
              _CheckRow(
                label: i,
                value: l.checks[i] == true,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  set(i, v);
                },
              ),
            const SizedBox(height: 8),
          ],
          if (ok < items.length)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFC2410C)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unticked items are shown to buyers as "Not working / not checked". Be honest — GAMEX QC re-tests every phone.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF9A3412)),
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: value ? const Color(0xFFF0FDF4) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value ? const Color(0xFFBBF7D0) : LX.line,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? LX.green : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: value ? LX.green : const Color(0xFFC9CBDD),
                    width: 1.6,
                  ),
                ),
                child: value
                    ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value ? LX.ink : LX.muted,
                  ),
                ),
              ),
              Text(
                value ? 'Working' : 'Not checked',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: value ? LX.green : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════ helpers ═══════════════════════════════

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, color: LX.ink),
    ),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: onTap == null ? LX.line : Colors.white,
    shape: const CircleBorder(side: BorderSide(color: LX.line)),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20),
      ),
    ),
  );
}

InputDecoration _input(String hint, {String? prefix}) => InputDecoration(
  hintText: hint,
  prefixText: prefix,
  filled: true,
  fillColor: Colors.white,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: LX.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: LX.line),
  ),
);
