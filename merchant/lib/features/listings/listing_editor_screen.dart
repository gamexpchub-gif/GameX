import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

const _brands = [
  'Apple',
  'Samsung',
  'Google',
  'OnePlus',
  'vivo',
  'Xiaomi',
  'Realme',
  'Nothing',
  'Motorola',
];
const _rams = ['4GB', '6GB', '8GB', '12GB', '16GB'];
const _storages = ['64GB', '128GB', '256GB', '512GB', '1TB'];
const _accessories = ['Box', 'Charger', 'Cable', 'Bill', 'Case'];
const _samples = [
  '/img/deal_iphone14pro.png',
  '/img/deal_iphone_blue.png',
  '/img/deal_iphone_midnight.png',
  '/img/deal_iphone_purple.png',
  '/img/deal_iphone_starlight.png',
  '/img/deal_iphone_titanium.png',
];

/// 5-step wizard to create or edit a listing.
class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({super.key, this.listingId});
  final String? listingId;

  @override
  ConsumerState<ListingEditorScreen> createState() => _EditorState();
}

class _EditorState extends ConsumerState<ListingEditorScreen> {
  static const _steps = ['Photos', 'Details', 'Condition', 'Price', 'Review'];
  int _step = 0;
  bool _saving = false;
  late Listing _l;
  late final bool _isNew;
  late final TextEditingController _model, _color, _imei, _price, _mrp, _notes;

  @override
  void initState() {
    super.initState();
    final existing = widget.listingId == null
        ? null
        : ref.read(listingByIdProvider(widget.listingId!));
    _isNew = existing == null;
    _l =
        existing ??
        Listing(
          id: newListingId(),
          brand: 'Apple',
          model: '',
          ram: '6GB',
          storage: '128GB',
          color: '',
          grade: Grade.excellent,
          battery: 90,
          imei: '',
          price: 0,
          mrp: 0,
          stock: 1,
          warrantyMonths: 6,
          photos: const [],
          status: ListingStatus.draft,
          createdAt: DateTime.now(),
          checks: {for (final c in kChecklist) c: false},
        );
    _model = TextEditingController(text: _l.model);
    _color = TextEditingController(text: _l.color);
    _imei = TextEditingController(text: _l.imei);
    _price = TextEditingController(text: _l.price == 0 ? '' : '${_l.price}');
    _mrp = TextEditingController(text: _l.mrp == 0 ? '' : '${_l.mrp}');
    _notes = TextEditingController(text: _l.notes);
  }

  @override
  void dispose() {
    for (final c in [_model, _color, _imei, _price, _mrp, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Listing get _current => _l.copyWith(
    model: _model.text.trim(),
    color: _color.text.trim(),
    imei: _imei.text.trim(),
    price: int.tryParse(_price.text) ?? 0,
    mrp: int.tryParse(_mrp.text) ?? 0,
    notes: _notes.text.trim(),
  );

  String? _validate(int step) {
    final l = _current;
    switch (step) {
      case 0:
        if (l.photos.isEmpty) return 'Add at least one photo';
      case 1:
        if (l.model.length < 2) return 'Enter the model name';
        if (l.color.isEmpty) return 'Enter the colour';
      case 2:
        if (!validImei(l.imei)) return 'Enter a valid 15-digit IMEI';
        if (l.checks.values.any((v) => !v)) {
          return 'Complete all function checks';
        }
      case 3:
        if (l.price < 1000) return 'Enter a selling price';
        if (l.mrp < l.price) return 'MRP must be at least the selling price';
    }
    return null;
  }

  void _next() {
    final err = _validate(_step);
    if (err != null) {
      snack(context, err, icon: Icons.error_outline_rounded);
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _step++);
  }

  Future<void> _save({required bool submit}) async {
    if (submit) {
      for (var i = 0; i < 4; i++) {
        final err = _validate(i);
        if (err != null) {
          setState(() => _step = i);
          snack(context, err, icon: Icons.error_outline_rounded);
          return;
        }
      }
    }
    setState(() => _saving = true);
    final l = _current.copyWith(
      status: submit ? ListingStatus.inReview : ListingStatus.draft,
    );
    try {
      await ref.read(syncProvider.notifier).saveListing(l, submit: submit);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      snack(context, e.toString(), icon: Icons.cloud_off_rounded);
      return;
    }
    if (!mounted) return;
    if (submit) {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: C.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: C.green,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Submitted for QC',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${l.title} (${l.id}) is being checked by the GAMEX quality team. It usually goes live within minutes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Back to listings',
                  onPressed: () => Navigator.pop(c),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      snack(context, 'Saved as draft');
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New listing' : 'Edit listing'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(submit: false),
            child: const Text(
              'Save draft',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: i < _step ? () => setState(() => _step = i) : null,
                      child: Column(
                        children: [
                          Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              gradient: i <= _step ? C.brandGradient : null,
                              color: i <= _step ? null : C.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _steps[i],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: i == _step
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: i == _step ? C.primary : C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_l.status == ListingStatus.rejected && _l.rejectReason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Panel(
                color: C.red.withValues(alpha: 0.06),
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.report_gmailerrorred_rounded,
                      color: C.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'GAMEX QC: ${_l.rejectReason}\nFix it and submit again.',
                        style: const TextStyle(
                          color: C.red,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_l.certificate != null && _step == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Pill(
                'GAMEX Certified • ${_l.certificate}',
                color: C.green,
                icon: Icons.verified_rounded,
              ),
            ),
          ...switch (_step) {
            0 => _photos(),
            1 => _details(),
            2 => _condition(),
            3 => _pricing(),
            _ => _review(),
          },
        ],
      ),
      bottomNavigationBar: ActionBar(
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: _step < 4
                  ? GradientButton(label: 'Continue', onPressed: _next)
                  : GradientButton(
                      label: 'Submit for QC',
                      icon: Icons.rocket_launch_rounded,
                      busy: _saving,
                      onPressed: () => _save(submit: true),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Step 1: photos ----------
  List<Widget> _photos() {
    Future<void> pick(ImageSource src) async {
      try {
        final f = await ImagePicker().pickImage(
          source: src,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (f != null) {
          setState(() => _l = _l.copyWith(photos: [..._l.photos, f.path]));
        }
      } catch (_) {
        if (mounted) {
          snack(
            context,
            'Could not open ${src.name}',
            icon: Icons.error_outline,
          );
        }
      }
    }

    return [
      const _Heading(
        'Add clear photos',
        'Front, back, sides and any marks. Listings with 5+ photos sell 2× faster.',
      ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (var i = 0; i < _l.photos.length; i++)
            Stack(
              children: [
                Positioned.fill(child: Photo(_l.photos[i], radius: 16, pad: 8)),
                if (i == 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: C.ink,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'COVER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => setState(
                      () =>
                          _l = _l.copyWith(photos: [..._l.photos]..removeAt(i)),
                    ),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.close_rounded, size: 15, color: C.ink),
                    ),
                  ),
                ),
              ],
            ),
          if (_l.photos.length < 8) ...[
            _AddTile(
              icon: Icons.photo_camera_rounded,
              label: 'Camera',
              onTap: () => pick(ImageSource.camera),
            ),
            _AddTile(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              onTap: () => pick(ImageSource.gallery),
            ),
          ],
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Or use a sample photo (demo)',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _samples.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: _l.photos.length >= 8
                ? null
                : () => setState(
                    () => _l = _l.copyWith(photos: [..._l.photos, _samples[i]]),
                  ),
            child: Photo(_samples[i], size: 70),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const _Tip(
        'Shoot in daylight on a plain background. Show the IMEI screen (*#06#) in one photo.',
      ),
    ];
  }

  // ---------- Step 2: details ----------
  List<Widget> _details() => [
    const _Heading('Phone details', 'Exactly as shown in Settings → About.'),
    const _Label('Brand'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final b in _brands)
          ChoiceChip(
            label: Text(b),
            selected: _l.brand == b,
            onSelected: (_) => setState(() => _l = _l.copyWith(brand: b)),
          ),
      ],
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _model,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Model',
        hintText: 'e.g. iPhone 14 Pro',
      ),
    ),
    const SizedBox(height: 16),
    const _Label('RAM'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in _rams)
          ChoiceChip(
            label: Text(r),
            selected: _l.ram == r,
            onSelected: (_) => setState(() => _l = _l.copyWith(ram: r)),
          ),
      ],
    ),
    const SizedBox(height: 16),
    const _Label('Storage'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in _storages)
          ChoiceChip(
            label: Text(s),
            selected: _l.storage == s,
            onSelected: (_) => setState(() => _l = _l.copyWith(storage: s)),
          ),
      ],
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _color,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Colour',
        hintText: 'e.g. Deep Purple',
      ),
    ),
  ];

  // ---------- Step 3: condition ----------
  List<Widget> _condition() => [
    const _Heading(
      'Condition & checks',
      'Honest grading means fewer returns and a higher seller rating.',
    ),
    for (final g in Grade.values)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.all(12),
          color: _l.grade == g
              ? gradeColor(g).withValues(alpha: 0.06)
              : Colors.white,
          onTap: () => setState(() => _l = _l.copyWith(grade: g)),
          child: Row(
            children: [
              Icon(
                _l.grade == g
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: _l.grade == g ? gradeColor(g) : C.faint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: gradeColor(g),
                      ),
                    ),
                    Text(
                      g.description,
                      style: const TextStyle(fontSize: 12.5, color: C.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 8),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Battery health',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_l.battery}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _l.battery >= 90
                      ? C.green
                      : _l.battery >= 80
                      ? C.amber
                      : C.red,
                ),
              ),
            ],
          ),
          Slider(
            value: _l.battery.toDouble(),
            min: 60,
            max: 100,
            divisions: 40,
            onChanged: (v) =>
                setState(() => _l = _l.copyWith(battery: v.round())),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _imei,
      keyboardType: TextInputType.number,
      maxLength: 15,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'IMEI (dial *#06#)',
        counterText: '',
        prefixIcon: const Icon(Icons.qr_code_2_rounded),
        suffixIcon: _imei.text.length == 15
            ? Icon(
                validImei(_imei.text)
                    ? Icons.verified_rounded
                    : Icons.error_rounded,
                color: validImei(_imei.text) ? C.green : C.red,
              )
            : null,
        helperText: _imei.text.length == 15 && !validImei(_imei.text)
            ? 'This IMEI fails the checksum — please re-check'
            : 'Verified against the blacklist database on submit',
      ),
    ),
    const SizedBox(height: 12),
    Panel(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            child: Row(
              children: [
                const Text(
                  'Function checks',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(
                    () => _l = _l.copyWith(
                      checks: {for (final c in kChecklist) c: true},
                    ),
                  ),
                  child: const Text('All working'),
                ),
              ],
            ),
          ),
          for (final c in kChecklist)
            CheckboxListTile(
              dense: true,
              value: _l.checks[c] ?? false,
              onChanged: (v) => setState(
                () => _l = _l.copyWith(checks: {..._l.checks, c: v ?? false}),
              ),
              title: Text(c, style: const TextStyle(fontSize: 14)),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    const _Label('In the box'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in _accessories)
          FilterChip(
            label: Text(a),
            selected: _l.accessories.contains(a),
            onSelected: (v) => setState(
              () => _l = _l.copyWith(
                accessories: v
                    ? [..._l.accessories, a]
                    : _l.accessories.where((e) => e != a).toList(),
              ),
            ),
          ),
      ],
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _notes,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Notes for buyers (optional)',
        hintText: 'e.g. Tiny scratch near the camera',
        alignLabelWithHint: true,
      ),
    ),
  ];

  // ---------- Step 4: price ----------
  List<Widget> _pricing() {
    final price = int.tryParse(_price.text) ?? 0;
    final mrp = int.tryParse(_mrp.text) ?? 0;
    final factor = switch (_l.grade) {
      Grade.likeNew => (0.70, 0.78),
      Grade.excellent => (0.62, 0.72),
      Grade.good => (0.52, 0.62),
      Grade.fair => (0.42, 0.52),
    };
    final suggest = mrp > 0
        ? (
            (mrp * factor.$1 / 100).round() * 100,
            (mrp * factor.$2 / 100).round() * 100,
          )
        : null;
    return [
      const _Heading(
        'Price & stock',
        'You see exactly what you earn on each sale.',
      ),
      TextField(
        controller: _mrp,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Original MRP',
          prefixText: '₹ ',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _price,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: 'Your selling price',
          prefixText: '₹ ',
          helperText: mrp > price && price > 0
              ? 'Buyers see ${(((mrp - price) / mrp) * 100).round()}% off'
              : null,
        ),
      ),
      if (suggest != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.violet.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: C.violet),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Smart price for ${_l.grade.label}: ${inr(suggest.$1)} – ${inr(suggest.$2)}',
                  style: const TextStyle(
                    color: C.violet,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _price.text =
                      '${((suggest.$1 + suggest.$2) / 200).round() * 100}',
                ),
                child: const Text('Use'),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 14),
      Panel(
        child: Column(
          children: [
            KeyValue('Selling price', inr(price)),
            KeyValue(
              'Commission (8%)',
              '− ${inr(Fees.commission(price))}',
              color: C.red,
            ),
            KeyValue(
              'Fixed fee',
              '− ${inr(price > 0 ? Fees.fixedFee : 0)}',
              color: C.red,
            ),
            KeyValue(
              'GST on fees (18%)',
              '− ${inr(price > 0 ? (Fees.commission(price) + Fees.fixedFee) * Fees.gstOnFees : 0)}',
              color: C.red,
            ),
            KeyValue('Shipping', 'FREE', color: C.green),
            const Divider(height: 18),
            KeyValue(
              'You earn',
              inr(price > 0 ? Fees.payout(price) : 0),
              bold: true,
              color: C.green,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Panel(
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Units in stock',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.outlined(
              onPressed: _l.stock > 1
                  ? () => setState(() => _l = _l.copyWith(stock: _l.stock - 1))
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${_l.stock}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton.outlined(
              onPressed: () =>
                  setState(() => _l = _l.copyWith(stock: _l.stock + 1)),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const _Label('Seller warranty'),
      Wrap(
        spacing: 8,
        children: [
          for (final m in [0, 3, 6, 12])
            ChoiceChip(
              label: Text(m == 0 ? 'None' : '$m months'),
              selected: _l.warrantyMonths == m,
              onSelected: (_) =>
                  setState(() => _l = _l.copyWith(warrantyMonths: m)),
            ),
        ],
      ),
    ];
  }

  // ---------- Step 5: review ----------
  List<Widget> _review() {
    final l = _current;
    return [
      const _Heading(
        'Review & submit',
        'This is how buyers will see your phone.',
      ),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.25,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: l.photos.isEmpty
                        ? const ColoredBox(color: C.bg)
                        : Photo(l.photos.first, radius: 0, pad: 18),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Pill(
                      l.grade.label,
                      color: gradeColor(l.grade),
                      icon: Icons.diamond_outlined,
                    ),
                  ),
                  if (l.discount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: C.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${l.discount}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${l.variant} • ${l.color}',
                    style: const TextStyle(color: C.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr(l.price),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        inr(l.mrp),
                        style: const TextStyle(
                          color: C.faint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pill(
                        'Battery ${l.battery}%',
                        color: C.green,
                        icon: Icons.battery_5_bar_rounded,
                      ),
                      if (l.warrantyMonths > 0)
                        Pill(
                          '${l.warrantyMonths}M warranty',
                          color: C.violet,
                          icon: Icons.gpp_good_outlined,
                        ),
                      Pill(
                        '${l.photos.length} photos',
                        color: C.primary,
                        icon: Icons.photo_library_outlined,
                      ),
                      Pill(
                        '${l.stock} in stock',
                        color: C.amber,
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          children: [
            KeyValue('IMEI', l.imei.isEmpty ? '—' : l.imei),
            KeyValue(
              'Checks passed',
              '${l.checks.values.where((v) => v).length}/${kChecklist.length}',
            ),
            KeyValue(
              'In the box',
              l.accessories.isEmpty ? 'Phone only' : l.accessories.join(', '),
            ),
            KeyValue(
              'You earn per sale',
              inr(l.price > 0 ? Fees.payout(l.price) : 0),
              bold: true,
              color: C.green,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const _Tip(
        'By submitting you confirm this phone is not stolen, financed or locked, and matches the photos.',
      ),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.text);
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: C.muted, height: 1.35)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: C.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: C.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: C.primary.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: C.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: C.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
