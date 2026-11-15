import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import 'widgets/listing_ui.dart';

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
const _rams = ['4GB', '6GB', '8GB', '12GB', '16GB', '24GB'];
const _storages = ['64GB', '128GB', '256GB', '512GB', '1TB', '2TB'];
const _accessories = ['Box', 'Charger', 'Cable', 'Bill', 'Case'];
const _networks = ['5G / 4G / 3G / 2G', '4G / 3G / 2G', 'Wi-Fi only'];
const _sims = [
  'Dual SIM (Nano)',
  'Dual SIM (Nano + eSIM)',
  'Single SIM (Nano)',
  'eSIM only',
];
const _devices = [
  ('Mobile Phone', Icons.smartphone_rounded),
  ('Tablet', Icons.tablet_android_rounded),
  ('Smartwatch', Icons.watch_rounded),
];
const _maxPhotos = 20;
const _samples = [
  '/img/deal_iphone_starlight.png',
  '/img/deal_iphone_blue.png',
  '/img/deal_iphone_midnight.png',
  '/img/deal_iphone_purple.png',
  '/img/deal_iphone14pro.png',
  '/img/deal_iphone_titanium.png',
];

/// Model keyword → (brand, typical RAM) for "Auto Fill".
const _known = <String, (String, String)>{
  'iphone 15 pro max': ('Apple', '8GB'),
  'iphone 15 pro': ('Apple', '8GB'),
  'iphone 16': ('Apple', '8GB'),
  'iphone 15': ('Apple', '6GB'),
  'iphone 14 pro': ('Apple', '6GB'),
  'iphone 14': ('Apple', '6GB'),
  'iphone 13': ('Apple', '4GB'),
  'iphone 12': ('Apple', '4GB'),
  'galaxy s24 ultra': ('Samsung', '12GB'),
  'galaxy s24': ('Samsung', '8GB'),
  'galaxy s23 ultra': ('Samsung', '12GB'),
  'galaxy s23': ('Samsung', '8GB'),
  'galaxy z flip': ('Samsung', '8GB'),
  'pixel 8 pro': ('Google', '12GB'),
  'pixel 8': ('Google', '8GB'),
  'pixel 7a': ('Google', '8GB'),
  'oneplus 12': ('OnePlus', '12GB'),
  'nord': ('OnePlus', '8GB'),
  'x100': ('vivo', '16GB'),
  'xiaomi 14': ('Xiaomi', '12GB'),
  'redmi note': ('Xiaomi', '8GB'),
  'gt 6': ('Realme', '12GB'),
  'phone (2': ('Nothing', '12GB'),
  'edge 50': ('Motorola', '12GB'),
};
const _brandWords = {
  'iphone': 'Apple',
  'galaxy': 'Samsung',
  'samsung': 'Samsung',
  'pixel': 'Google',
  'oneplus': 'OnePlus',
  'nord': 'OnePlus',
  'vivo': 'vivo',
  'redmi': 'Xiaomi',
  'xiaomi': 'Xiaomi',
  'poco': 'Xiaomi',
  'realme': 'Realme',
  'nothing': 'Nothing',
  'moto': 'Motorola',
  'edge': 'Motorola',
};

/// 5-step wizard to create or edit a listing.
class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({super.key, this.listingId});
  final String? listingId;

  @override
  ConsumerState<ListingEditorScreen> createState() => _EditorState();
}

class _EditorState extends ConsumerState<ListingEditorScreen> {
  int _step = 0;
  bool _saving = false;
  bool _declared = false;
  bool _extrasOpen = true;
  late Listing _l;
  late final bool _isNew;
  late final List<String> _brandList;
  late final TextEditingController _model,
      _imei,
      _price,
      _mrp,
      _notes,
      _otherColour;
  final _scroll = ScrollController();

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
          color: 'Black',
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
    _brandList = [..._brands, if (!_brands.contains(_l.brand)) _l.brand];
    final knownColour = kColours.any((c) => c.$1 == _l.color);
    _model = TextEditingController(text: _l.model);
    _imei = TextEditingController(text: _l.imei);
    _price = TextEditingController(text: _l.price == 0 ? '' : '${_l.price}');
    _mrp = TextEditingController(text: _l.mrp == 0 ? '' : '${_l.mrp}');
    _notes = TextEditingController(text: _l.notes);
    _otherColour = TextEditingController(text: knownColour ? '' : _l.color);
  }

  @override
  void dispose() {
    for (final c in [_model, _imei, _price, _mrp, _notes, _otherColour]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  bool get _otherColourSelected => !kColours.any((c) => c.$1 == _l.color);

  Listing get _current => _l.copyWith(
    model: _model.text.trim(),
    color: _otherColourSelected ? _otherColour.text.trim() : _l.color,
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
        if (l.color.isEmpty) return 'Choose the colour';
        if (!validImei(l.imei)) {
          return 'Enter a valid 15-digit IMEI (dial *#06#)';
        }
      case 2:
        if (l.checks.values.any((v) => !v)) {
          return 'Confirm all detailed checks';
        }
      case 3:
        if (l.price < 1000) return 'Enter your selling price';
        if (l.mrp < l.price) return 'MRP must be at least the selling price';
    }
    return null;
  }

  void _goTo(int s) {
    FocusScope.of(context).unfocus();
    setState(() => _step = s);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _next() {
    final err = _validate(_step);
    if (err != null) {
      return snack(context, err, icon: Icons.error_outline_rounded);
    }
    HapticFeedback.selectionClick();
    _goTo(_step + 1);
  }

  Future<void> _save({required bool submit}) async {
    if (submit) {
      for (var i = 0; i < 4; i++) {
        final err = _validate(i);
        if (err != null) {
          _goTo(i);
          snack(context, err, icon: Icons.error_outline_rounded);
          return;
        }
      }
      if (!_declared) {
        return snack(
          context,
          'Please confirm the seller declaration',
          icon: Icons.error_outline_rounded,
        );
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
      await _showSubmitted(l);
    } else {
      snack(context, 'Saved as draft');
    }
    if (mounted) context.pop();
  }

  Future<void> _showSubmitted(Listing l) => showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/img/listing/hero_shield.png', height: 110),
            const SizedBox(height: 10),
            const Text(
              'Submitted for QC',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: LX.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${l.title} (${l.id}) is with the GAMEX quality team. You\'ll get a notification when it is approved and live.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: LX.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            LxButton(
              label: 'Back to listings',
              height: 54,
              onTap: () => Navigator.pop(c),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: LxBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, 6),
              child: Column(
                children: [
                  LxHeader(
                    subtitle: _isNew ? 'New Listing' : 'Edit Listing',
                    onBack: () => _step > 0 ? _goTo(_step - 1) : context.pop(),
                    onSaveDraft: _saving ? null : () => _save(submit: false),
                  ),
                  const SizedBox(height: 14),
                  LxStepper(step: _step, onTap: _goTo),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (_l.status == ListingStatus.rejected &&
                      _l.rejectReason != null)
                    _rejectBanner(),
                  ...switch (_step) {
                    0 => _photos(),
                    1 => _details(),
                    2 => _condition(),
                    3 => _pricing(),
                    _ => _review(),
                  },
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + pad.bottom),
              child: _step == 0
                  ? LxButton(
                      label: 'Continue',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onTap: _next,
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: LxGhostButton(
                            label: 'Back',
                            icon: Icons.arrow_back_rounded,
                            onTap: () => _goTo(_step - 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _step < 4
                              ? LxButton(
                                  label: 'Continue',
                                  icon: _step == 2 ? Icons.check_rounded : null,
                                  trailingIcon: _step == 2
                                      ? null
                                      : Icons.arrow_forward_rounded,
                                  onTap: _next,
                                )
                              : LxButton(
                                  label: 'Submit for QC',
                                  icon: Icons.rocket_launch_rounded,
                                  busy: _saving,
                                  onTap: () => _save(submit: true),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rejectBanner() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LxCard(
      color: const Color(0xFFFFF1F2),
      borderColor: const Color(0xFFFECDD3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_gmailerrorred_rounded, color: LX.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'GAMEX QC: ${_l.rejectReason}\nFix it and submit again.',
              style: const TextStyle(
                color: LX.red,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ================================================================ PHOTOS

  Future<void> _pick(ImageSource src) async {
    final room = _maxPhotos - _l.photos.length;
    if (room <= 0) {
      return snack(
        context,
        'Maximum $_maxPhotos photos',
        icon: Icons.info_outline_rounded,
      );
    }
    try {
      final picker = ImagePicker();
      final files = src == ImageSource.camera
          ? [
              ?await picker.pickImage(
                source: src,
                maxWidth: 1600,
                imageQuality: 85,
              ),
            ]
          : await picker.pickMultiImage(
              maxWidth: 1600,
              imageQuality: 85,
              limit: room > 1 ? room : null,
            );
      if (files.isEmpty) return;
      setState(
        () => _l = _l.copyWith(
          photos: [..._l.photos, ...files.take(room).map((f) => f.path)],
        ),
      );
    } catch (_) {
      if (mounted) {
        snack(
          context,
          'Could not open the ${src == ImageSource.camera ? 'camera' : 'gallery'}',
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _arrange() async {
    if (_l.photos.length < 2) {
      return snack(
        context,
        'Add at least 2 photos to arrange',
        icon: Icons.info_outline_rounded,
      );
    }
    final list = [..._l.photos];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SizedBox(
          height: MediaQuery.sizeOf(c).height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Arrange photos',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              const Text(
                'Drag to reorder. The first photo is the cover.',
                style: TextStyle(color: LX.muted),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  onReorderItem: (a, b) =>
                      set(() => list.insert(b, list.removeAt(a))),
                  itemBuilder: (_, i) => ListTile(
                    key: ValueKey('${list[i]}#$i'),
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Photo(list[i], size: 56, radius: 12),
                    title: Text(
                      i == 0 ? 'Cover photo' : 'Photo ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.drag_indicator_rounded),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: LxButton(
                  label: 'Done',
                  height: 52,
                  onTap: () => Navigator.pop(c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _l = _l.copyWith(photos: list));
  }

  List<Widget> _photos() {
    final n = _l.photos.length;
    const reqs = [
      ('req_front', 'Front View'),
      ('req_back', 'Back View'),
      ('req_side', 'Side View'),
      ('req_closeup', 'Close-up\n(Marks)'),
      ('req_imei', 'IMEI\nScreen'),
    ];
    return [
      const LxHero(
        lead: 'Add',
        accent: 'Product Photos',
        subtitle: 'Upload clear, high-quality photos to get more views and sell faster.',
        image: 'hero_photos',
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _BigAction(
                    icon: Icons.photo_camera_outlined,
                    title: 'Take Photo',
                    subtitle: 'Use Camera',
                    onTap: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigAction(
                    icon: Icons.photo_library_outlined,
                    title: 'Choose from Gallery',
                    subtitle: 'Select Multiple',
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DashedBox(
              onTap: n == 0 ? () => _pick(ImageSource.gallery) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _CountPill(n: n),
                    ),
                    if (n == 0) ...[
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => LX.chip.createShader(r),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to Upload Photos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LX.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Up to 20 photos • the first one is the cover',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: LX.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _l = _l.copyWith(photos: [..._samples.take(3)]),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Use sample photos (demo)'),
                      ),
                    ] else
                      _photoGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _Tool(
            icon: Icons.collections_outlined,
            label: 'Bulk\nUpload',
            onTap: () => _pick(ImageSource.gallery),
          ),
          _Tool(
            icon: Icons.auto_fix_high_outlined,
            label: 'Auto\nEnhance',
            soon: true,
            onTap: _soon,
          ),
          _Tool(
            icon: Icons.highlight_alt_rounded,
            label: 'Remove\nBackground',
            soon: true,
            onTap: _soon,
          ),
          _Tool(
            icon: Icons.crop_rounded,
            label: 'Crop &\nResize',
            soon: true,
            onTap: _soon,
          ),
          _Tool(
            icon: Icons.swap_horiz_rounded,
            label: 'Arrange\nOrder',
            onTap: _arrange,
          ),
        ],
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.info_outline_rounded,
              title: 'Photo Requirements',
              subtitle: 'Shoot these 5 angles for faster QC approval',
            ),
            Row(
              children: [
                for (var i = 0; i < reqs.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i < reqs.length - 1 ? 6 : 0,
                      ),
                      child: _ReqTile(
                        image: reqs[i].$1,
                        label: reqs[i].$2,
                        done: n > i,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        color: const Color(0xFFFFFBF0),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Photo Tips for Better Sales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LX.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _Tip('Use good lighting (daylight is best).'),
                  _Tip('Keep a plain and clean background.'),
                  _Tip('Include front, back, sides, top and bottom.'),
                  _Tip('Show any scratches or defects clearly.'),
                ],
              ),
            ),
            Image.asset('assets/img/listing/tips_camera.png', width: 78),
          ],
        ),
      ),
    ];
  }

  void _soon() => snack(
    context,
    'Coming soon — use your phone\'s editor for now',
    icon: Icons.schedule_rounded,
  );

  Widget _photoGrid() {
    final photos = _l.photos;
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: photos.length < _maxPhotos ? photos.length + 1 : photos.length,
      itemBuilder: (_, i) {
        if (i == photos.length) {
          return GestureDetector(
            onTap: () => _pick(ImageSource.gallery),
            child: Container(
              decoration: BoxDecoration(
                color: LX.violet.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LX.violet.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.add_rounded, color: LX.violet, size: 28),
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: Photo(photos[i], radius: 14, pad: 6)),
            if (i == 0)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    gradient: LX.chip,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'COVER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 3,
              top: 3,
              child: GestureDetector(
                onTap: () => setState(
                  () => _l = _l.copyWith(photos: [...photos]..removeAt(i)),
                ),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: LX.soft(0.2),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: LX.ink,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================================================================ DETAILS

  void _autoFill({bool announce = true}) {
    final m = _model.text.toLowerCase().trim();
    if (m.isEmpty) {
      return snack(
        context,
        'Type the model first, e.g. iPhone 13',
        icon: Icons.info_outline_rounded,
      );
    }
    String? brand;
    String? ram;
    for (final e in _known.entries) {
      if (m.contains(e.key)) {
        (brand, ram) = e.value;
        break;
      }
    }
    if (brand == null) {
      for (final e in _brandWords.entries) {
        if (m.contains(e.key)) {
          brand = e.value;
          break;
        }
      }
    }
    if (brand == null) {
      return snack(
        context,
        'Couldn\'t recognise this model — pick the brand manually',
        icon: Icons.info_outline_rounded,
      );
    }
    setState(() => _l = _l.copyWith(brand: brand, ram: ram));
    if (announce) {
      snack(
        context,
        ram == null
            ? 'Brand set to $brand'
            : 'Detected $brand • $ram RAM — check storage & colour',
      );
    }
  }

  Future<void> _addBrand() async {
    final c = TextEditingController();
    final b = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add brand'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. iQOO'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (b == null || b.isEmpty) return;
    setState(() {
      if (!_brandList.contains(b)) _brandList.add(b);
      _l = _l.copyWith(brand: b);
    });
  }

  Future<void> _scanImei() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/img/listing/req_imei.png', width: 64),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'On the phone you are selling, dial *#06# and copy the IMEI. Then tap Paste.',
                      style: TextStyle(height: 1.4, color: LX.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LxButton(
                label: 'Paste IMEI',
                icon: Icons.content_paste_rounded,
                height: 52,
                onTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final digits = (data?.text ?? '').replaceAll(
                    RegExp(r'\D'),
                    '',
                  );
                  if (!c.mounted) return;
                  Navigator.pop(c);
                  if (digits.length >= 15) {
                    setState(() => _imei.text = digits.substring(0, 15));
                  } else if (mounted) {
                    snack(
                      context,
                      'No IMEI found in clipboard',
                      icon: Icons.info_outline_rounded,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _details() {
    final imeiOk = validImei(_imei.text);
    return [
      const LxHero(
        lead: 'Product',
        accent: 'Details',
        subtitle: 'Add accurate device information to get more views and sell faster.',
        image: 'hero_details',
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          _Feature(
            icon: Icons.auto_awesome_outlined,
            title: 'Auto Fill',
            subtitle: 'From model name',
            onTap: _autoFill,
          ),
          const SizedBox(width: 8),
          _Feature(
            icon: Icons.smartphone_rounded,
            title: 'Smart Detect',
            subtitle: 'Brand & RAM',
            onTap: _autoFill,
          ),
          const SizedBox(width: 8),
          const _Feature(
            icon: Icons.bar_chart_rounded,
            title: 'Visibility',
            subtitle: 'Full details sell faster',
          ),
        ],
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.phone_iphone_rounded,
              title: 'Device Type',
              required: true,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in _devices)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: LxPill(
                        label: d.$1,
                        selected: _l.deviceType == d.$1,
                        leading: Icon(
                          d.$2,
                          size: 18,
                          color: _l.deviceType == d.$1 ? Colors.white : LX.ink,
                        ),
                        onTap: () =>
                            setState(() => _l = _l.copyWith(deviceType: d.$1)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LxSection(
              icon: Icons.sell_outlined,
              title: 'Brand',
              required: true,
              trailing: GestureDetector(
                onTap: _addBrand,
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: LX.violet, size: 20),
                    Text(
                      'Add Brand',
                      style: TextStyle(
                        color: LX.violet,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.7,
              children: [
                for (final b in _brandList)
                  _BrandTile(
                    brand: b,
                    selected: _l.brand == b,
                    onTap: () => setState(() => _l = _l.copyWith(brand: b)),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.layers_outlined,
              title: 'Model',
              required: true,
            ),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _model,
                    hint: 'e.g. iPhone 15 Pro Max',
                    suffix: const Icon(Icons.search_rounded, color: LX.muted),
                    onSubmitted: (_) => _autoFill(announce: false),
                  ),
                ),
                const SizedBox(width: 10),
                _SmallAction(
                  icon: Icons.document_scanner_outlined,
                  label: 'Detect\nBrand',
                  onTap: _autoFill,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _chipCard(
              Icons.memory_rounded,
              'RAM',
              _rams,
              _l.ram,
              (v) => _l = _l.copyWith(ram: v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _chipCard(
              Icons.sd_storage_outlined,
              'Storage',
              _storages,
              _l.storage,
              (v) => _l = _l.copyWith(storage: v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.palette_outlined,
              title: 'Colour',
              required: true,
            ),
            Row(
              children: [
                for (final c in kColours)
                  Expanded(
                    child: _Swatch(
                      label: c.$1,
                      color: c.$2,
                      selected: _l.color == c.$1,
                      onTap: () =>
                          setState(() => _l = _l.copyWith(color: c.$1)),
                    ),
                  ),
                Expanded(
                  child: _Swatch(
                    label: 'Other',
                    selected: _otherColourSelected,
                    onTap: () => setState(
                      () => _l = _l.copyWith(
                        color: _otherColour.text.isEmpty
                            ? ''
                            : _otherColour.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_otherColourSelected) ...[
              const SizedBox(height: 10),
              _Field(
                controller: _otherColour,
                hint: 'Colour name, e.g. Starlight',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.qr_code_2_rounded,
              title: 'IMEI Number',
              required: true,
            ),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _imei,
                    hint: 'Enter IMEI (15 digits)',
                    keyboard: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    onChanged: (_) => setState(() {}),
                    suffix: _imei.text.length == 15
                        ? Icon(
                            imeiOk
                                ? Icons.verified_rounded
                                : Icons.error_rounded,
                            color: imeiOk ? LX.green : LX.red,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                _SmallAction(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan\nIMEI',
                  onTap: _scanImei,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _imei.text.length == 15 && !imeiOk
                      ? Icons.error_outline_rounded
                      : Icons.verified_user_rounded,
                  size: 16,
                  color: _imei.text.length == 15 && !imeiOk ? LX.red : LX.green,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _imei.text.length == 15 && !imeiOk
                        ? 'This IMEI fails the check digit — please re-check.'
                        : 'IMEI adds trust and is verified by GAMEX QC.',
                    style: const TextStyle(fontSize: 12.5, color: LX.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _dropCard(
              Icons.cell_tower_rounded,
              'Network Type',
              _networks,
              _l.network,
              (v) => _l = _l.copyWith(network: v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dropCard(
              Icons.sim_card_outlined,
              'SIM Type',
              _sims,
              _l.sim,
              (v) => _l = _l.copyWith(sim: v),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _chipCard(
    IconData icon,
    String title,
    List<String> items,
    String value,
    void Function(String) set,
  ) => LxCard(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LxSection(icon: icon, title: title, required: true),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 6,
          childAspectRatio: 1.55,
          children: [
            for (final v in items)
              GestureDetector(
                onTap: () => setState(() => set(v)),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: v == value ? LX.chip : null,
                    color: v == value ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: v == value ? Colors.transparent : LX.line,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: v == value ? Colors.white : LX.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _dropCard(
    IconData icon,
    String title,
    List<String> items,
    String value,
    void Function(String) set,
  ) => LxCard(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LxSection(icon: icon, title: title),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: LX.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: const TextStyle(
                color: LX.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                fontFamily: 'Inter',
              ),
              items: [
                for (final i in items)
                  DropdownMenuItem(
                    value: i,
                    child: Text(i, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => set(v ?? value)),
            ),
          ),
        ),
      ],
    ),
  );

  // ================================================================ CONDITION

  List<Widget> _condition() {
    const art = {
      Grade.likeNew: 'cond_likenew',
      Grade.excellent: 'cond_excellent',
      Grade.good: 'cond_good',
      Grade.fair: 'cond_fair',
    };
    const short = {
      Grade.likeNew: 'No visible marks',
      Grade.excellent: 'Micro-scratches only',
      Grade.good: 'Light signs of use',
      Grade.fair: 'Noticeable scratches',
    };
    const checkIcons = [
      Icons.visibility_outlined,
      Icons.fingerprint_rounded,
      Icons.photo_camera_outlined,
      Icons.volume_up_outlined,
      Icons.wifi_rounded,
      Icons.electrical_services_rounded,
      Icons.vibration_rounded,
      Icons.lock_open_rounded,
    ];
    final allOk =
        _l.checks.values.every((v) => v) &&
        _l.checks.length == kChecklist.length;
    final health = _l.battery >= 85 && allOk
        ? 'Excellent'
        : _l.battery >= 75
        ? 'Good'
        : 'Fair';
    final healthColor = health == 'Excellent'
        ? LX.green
        : health == 'Good'
        ? const Color(0xFFF59E0B)
        : LX.red;
    final imeiOk = validImei(_imei.text);
    return [
      const LxHero(
        lead: 'Condition',
        accent: '& Checks',
        subtitle:
            'Honest grading means fewer returns and a higher seller rating.',
        image: 'hero_condition',
        leadingImage: 'hero_shield',
      ),
      const SizedBox(height: 10),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.star_outline_rounded,
              title: 'Select Condition',
              subtitle: 'Choose the option that matches your device',
            ),
            Row(
              children: [
                for (final g in Grade.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: g == Grade.fair ? 0 : 7),
                      child: _GradeCard(
                        image: art[g]!,
                        title: g.label,
                        subtitle: short[g]!,
                        selected: _l.grade == g,
                        onTap: () => setState(() => _l = _l.copyWith(grade: g)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          children: [
            LxSection(
              icon: Icons.monitor_heart_outlined,
              title: 'Device Health',
              subtitle: 'Let buyers know the current health status',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: healthColor,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      health,
                      style: TextStyle(
                        color: healthColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _HealthTile(
                    child: Row(
                      children: [
                        Icon(
                          Icons.battery_charging_full_rounded,
                          size: 40,
                          color: _l.battery >= 85
                              ? LX.green
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_l.battery}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: LX.ink,
                                ),
                              ),
                              const Text(
                                'Battery Health',
                                style: TextStyle(fontSize: 12, color: LX.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HealthTile(
                    onTap: () => _goTo(1),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 34,
                          color: LX.ink,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'IMEI',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: LX.ink,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    imeiOk
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    size: 14,
                                    color: imeiOk ? LX.green : LX.red,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      imeiOk
                                          ? 'Checksum valid'
                                          : 'Add in Details',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: imeiOk ? LX.green : LX.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: LX.blue,
                thumbColor: LX.violet,
                inactiveTrackColor: LX.line,
                trackHeight: 5,
              ),
              child: Slider(
                value: _l.battery.toDouble(),
                min: 60,
                max: 100,
                divisions: 40,
                label: '${_l.battery}%',
                onChanged: (v) =>
                    setState(() => _l = _l.copyWith(battery: v.round())),
              ),
            ),
            const Text(
              'Drag to set battery health (Settings → Battery)',
              style: TextStyle(fontSize: 12, color: LX.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          children: [
            LxSection(
              icon: Icons.fact_check_outlined,
              title: 'Detailed Checks',
              subtitle: 'Confirm the device features and condition',
              trailing: GestureDetector(
                onTap: () => setState(
                  () => _l = _l.copyWith(
                    checks: {for (final c in kChecklist) c: !allOk},
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: LX.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allOk
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: LX.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        allOk ? 'All Set' : 'Select All',
                        style: const TextStyle(
                          color: LX.blue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 7,
              childAspectRatio: 0.66,
              children: [
                for (var i = 0; i < kChecklist.length; i++)
                  _CheckTile(
                    icon: checkIcons[i],
                    label: kChecklist[i],
                    value: _l.checks[kChecklist[i]] ?? false,
                    onChanged: (v) => setState(
                      () => _l = _l.copyWith(
                        checks: {..._l.checks, kChecklist[i]: v},
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.inventory_2_outlined,
              title: 'In the Box',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _accessories)
                  LxPill(
                    label: a,
                    dense: true,
                    selected: _l.accessories.contains(a),
                    onTap: () => setState(
                      () => _l = _l.copyWith(
                        accessories: _l.accessories.contains(a)
                            ? (_l.accessories.where((e) => e != a).toList())
                            : [..._l.accessories, a],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const LxSection(
              icon: Icons.edit_note_rounded,
              title: 'Additional Notes',
              optional: true,
            ),
            _Field(
              controller: _notes,
              hint: 'Add any extra information about the device…',
              maxLines: 2,
            ),
          ],
        ),
      ),
    ];
  }

  // ================================================================ PRICE

  List<Widget> _pricing() {
    final price = int.tryParse(_price.text) ?? 0;
    final mrp = int.tryParse(_mrp.text) ?? 0;
    final earn = price > 0 ? Fees.payout(price) : 0.0;
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
    final wide = MediaQuery.sizeOf(context).width >= 560;

    final breakdown = LxCard(
      child: Column(
        children: [
          const LxSection(
            icon: Icons.layers_outlined,
            title: 'Earnings Breakdown',
          ),
          _Row(Icons.schedule_rounded, 'Selling price', inr(price)),
          _Row(
            Icons.percent_rounded,
            'Commission (8%)',
            '- ${inr(Fees.commission(price))}',
            color: LX.red,
          ),
          _Row(
            Icons.receipt_outlined,
            'Fixed fee',
            '- ${inr(price > 0 ? Fees.fixedFee : 0)}',
            color: LX.red,
          ),
          _Row(
            Icons.request_quote_outlined,
            'GST on fees (18%)',
            '- ${inr(price > 0 ? (Fees.commission(price) + Fees.fixedFee) * Fees.gstOnFees : 0)}',
            color: LX.red,
          ),
          const _Row(
            Icons.local_shipping_outlined,
            'Shipping',
            'FREE',
            color: LX.green,
          ),
          const Divider(height: 16),
          Row(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LX.chip.createShader(r),
                child: const Icon(Icons.savings_outlined, size: 26),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'You Earn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LX.ink,
                  ),
                ),
              ),
              Text(
                inr(earn),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: LX.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final insight = LxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LxSection(
            icon: Icons.insights_rounded,
            title: 'Profit Insight',
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF6F3FF), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You receive',
                        style: TextStyle(
                          color: LX.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FittedBox(
                        child: Text(
                          inr(earn),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: LX.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text(
                      'Payout',
                      style: TextStyle(
                        color: LX.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: LX.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        price > 0
                            ? '${(earn * 100 / price).toStringAsFixed(1)}%'
                            : '—',
                        style: const TextStyle(
                          color: LX.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price > 0
                ? 'Of your ${inr(price)} selling price, after all GAMEX fees. Paid 7 days after delivery.'
                : 'Enter a selling price to see your payout.',
            style: const TextStyle(fontSize: 12, color: LX.muted),
          ),
        ],
      ),
    );

    return [
      const LxHero(
        lead: 'Price',
        accent: '& Stock',
        subtitle:
            'Set the right price, manage stock and add warranty & offers.',
        image: 'hero_price',
      ),
      const SizedBox(height: 10),
      LxCard(
        child: Column(
          children: [
            _PriceRow(
              icon: Icons.sell_outlined,
              title: 'Original MRP (₹)',
              subtitle: 'Manufacturer\'s original price',
              controller: _mrp,
              onChanged: () => setState(() {}),
            ),
            const Divider(height: 18),
            _PriceRow(
              icon: Icons.sell_rounded,
              title: 'Your Selling Price (₹)',
              subtitle: mrp > price && price > 0
                  ? 'Buyers see ${(((mrp - price) / mrp) * 100).round()}% off'
                  : 'The price buyers will see',
              required: true,
              controller: _price,
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      if (suggest != null) ...[
        const SizedBox(height: 10),
        LxCard(
          color: const Color(0xFFF5F0FF),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: LX.violet),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Suggested for ${_l.grade.label}: ${inr(suggest.$1)} – ${inr(suggest.$2)}',
                  style: const TextStyle(
                    color: LX.violet,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _price.text =
                      '${((suggest.$1 + suggest.$2) / 200).round() * 100}',
                ),
                child: const Text(
                  'Use',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (wide)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: breakdown),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: insight),
            ],
          ),
        )
      else ...[
        breakdown,
        const SizedBox(height: 12),
        insight,
      ],
      const SizedBox(height: 12),
      LxCard(
        child: Row(
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => LX.chip.createShader(r),
              child: const Icon(Icons.inventory_2_outlined, size: 30),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Units in Stock',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: LX.ink,
                    ),
                  ),
                  Text(
                    'How many units are you listing?',
                    style: TextStyle(fontSize: 12.5, color: LX.muted),
                  ),
                ],
              ),
            ),
            _RoundIcon(
              icon: Icons.remove_rounded,
              onTap: _l.stock > 1
                  ? () => setState(() => _l = _l.copyWith(stock: _l.stock - 1))
                  : null,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${_l.stock}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: LX.ink,
                ),
              ),
            ),
            _RoundIcon(
              icon: Icons.add_rounded,
              onTap: () =>
                  setState(() => _l = _l.copyWith(stock: _l.stock + 1)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LxSection(
              icon: Icons.verified_user_outlined,
              title: 'Seller Warranty',
              subtitle: 'Offer warranty to build buyer trust',
            ),
            Row(
              children: [
                for (final m in [0, 3, 6, 12])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: m == 12 ? 0 : 6),
                      child: LxPill(
                        dense: true,
                        label: m == 0 ? 'None' : '$m Months',
                        selected: _l.warrantyMonths == m,
                        onTap: () =>
                            setState(() => _l = _l.copyWith(warrantyMonths: m)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LxSection(
              icon: Icons.card_giftcard_rounded,
              title: 'Extra Options',
              optional: true,
              subtitle: 'Boost visibility and sales with these options',
              trailing: IconButton(
                onPressed: () => setState(() => _extrasOpen = !_extrasOpen),
                icon: Icon(
                  _extrasOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ),
            if (_extrasOpen)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  _OptionTile(
                    icon: Icons.discount_outlined,
                    title: 'Offer Discount',
                    subtitle: _l.offerPercent == 0
                        ? 'e.g. 5% – 20% off'
                        : '${_l.offerPercent}% extra off',
                    value: _l.offerPercent > 0,
                    onChanged: (v) => setState(
                      () => _l = _l.copyWith(offerPercent: v ? 5 : 0),
                    ),
                    onTap: _l.offerPercent > 0
                        ? () => setState(
                            () => _l = _l.copyWith(
                              offerPercent: _l.offerPercent >= 20
                                  ? 5
                                  : _l.offerPercent + 5,
                            ),
                          )
                        : null,
                  ),
                  const _OptionTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Free Shipping',
                    subtitle: 'Paid by GAMEX',
                    value: true,
                    onChanged: null,
                  ),
                  _OptionTile(
                    icon: Icons.assignment_return_outlined,
                    title: 'Return Policy',
                    subtitle: _l.returnDays == 0
                        ? 'No returns'
                        : '${_l.returnDays} days (tap to change)',
                    value: _l.returnDays > 0,
                    onChanged: (v) =>
                        setState(() => _l = _l.copyWith(returnDays: v ? 7 : 0)),
                    onTap: _l.returnDays > 0
                        ? () => setState(
                            () => _l = _l.copyWith(
                              returnDays: _l.returnDays == 7 ? 15 : 7,
                            ),
                          )
                        : null,
                  ),
                  const _OptionTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'GAMEX Verified',
                    subtitle: 'Badge after QC',
                    value: true,
                    onChanged: null,
                  ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  // ================================================================ REVIEW

  List<Widget> _review() {
    final l = _current;
    final checks = l.checks.values.where((v) => v).length;
    final logo = brandLogo(l.brand);
    return [
      const LxHero(
        lead: 'Review',
        accent: '& Submit',
        subtitle: 'Check all details before publishing your listing.',
        image: 'hero_review',
      ),
      const SizedBox(height: 10),
      LxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewGallery(photos: l.photos),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LX.line),
                  ),
                  child: logo == null
                      ? const Icon(Icons.smartphone_rounded)
                      : Image.asset(
                          'assets/img/brands/brand_$logo.png',
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: LX.ink,
                        ),
                      ),
                      Text(
                        '${l.ram} RAM • ${l.storage} Storage',
                        style: const TextStyle(color: LX.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                GradientText(
                  inr(l.price),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (l.mrp > l.price)
                  Text(
                    inr(l.mrp),
                    style: const TextStyle(
                      color: LX.muted,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 16,
                    ),
                  ),
                if (l.discount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: LX.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${l.discount}% OFF',
                      style: const TextStyle(
                        color: LX.green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  icon: Icons.battery_full_rounded,
                  color: LX.green,
                  label: 'Battery',
                  value: '${l.battery}%',
                ),
                const SizedBox(width: 8),
                _Stat(
                  icon: Icons.verified_user_outlined,
                  color: LX.blue,
                  label: 'Checks',
                  value: '$checks/${kChecklist.length}',
                ),
                const SizedBox(width: 8),
                _Stat(
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFFF59E0B),
                  label: 'In Stock',
                  value: '${l.stock} Unit${l.stock > 1 ? 's' : ''}',
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        child: Column(
          children: [
            LxSection(
              icon: Icons.list_alt_rounded,
              title: 'Listing Details',
              trailing: GestureDetector(
                onTap: () => _goTo(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6DDFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: LX.violet),
                      SizedBox(width: 4),
                      Text(
                        'Edit Details',
                        style: TextStyle(
                          color: LX.violet,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Detail(Icons.person_outline_rounded, 'Brand', l.brand),
            _Detail(Icons.smartphone_rounded, 'Model', l.model),
            _Detail(Icons.memory_rounded, 'RAM', l.ram),
            _Detail(Icons.sd_storage_outlined, 'Storage', l.storage),
            _Detail(Icons.palette_outlined, 'Colour', l.color),
            _Detail(Icons.verified_outlined, 'Condition', l.grade.label),
            _Detail(
              Icons.qr_code_2_rounded,
              'IMEI',
              l.imei.isEmpty ? '—' : l.imei,
            ),
            _Detail(
              Icons.shield_outlined,
              'Warranty',
              l.warrantyMonths == 0 ? 'None' : '${l.warrantyMonths} Months',
            ),
            _Detail(
              Icons.cell_tower_rounded,
              'Network • SIM',
              '${l.network} • ${l.sim}',
            ),
            _Detail(
              Icons.assignment_return_outlined,
              'Returns',
              l.returnDays == 0 ? 'No returns' : '${l.returnDays} days',
              last: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LxCard(
                onTap: () => _goTo(2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LxSection(
                      icon: Icons.inventory_2_outlined,
                      title: 'In the Box',
                    ),
                    Text(
                      l.accessories.isEmpty
                          ? 'Phone only'
                          : l.accessories.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: LX.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LxCard(
                onTap: () => _goTo(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LxSection(
                      icon: Icons.savings_outlined,
                      title: 'Your Earnings',
                    ),
                    FittedBox(
                      child: Text(
                        inr(l.price > 0 ? Fees.payout(l.price) : 0),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: LX.green,
                        ),
                      ),
                    ),
                    const Text(
                      'Per sale (after fees & GST)',
                      style: TextStyle(fontSize: 11.5, color: LX.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LxCard(
        borderColor: _declared ? const Color(0xFFBBF7D0) : Colors.white,
        onTap: () => setState(() => _declared = !_declared),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _declared
                      ? [const Color(0xFF34D399), const Color(0xFF16A34A)]
                      : [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)],
                ),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seller Declaration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LX.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'I confirm this phone is not stolen, financed or locked, and matches the photos and details provided.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: LX.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            LxSwitch(
              value: _declared,
              onChanged: (v) => setState(() => _declared = v),
            ),
          ],
        ),
      ),
    ];
  }
}

// ==================================================================== pieces

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        gradient: LX.cta,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: LX.soft(0.3),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.n});
  final int n;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      gradient: LX.chip,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 16),
        const SizedBox(width: 5),
        Text(
          '$n / $_maxPhotos',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.soon = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: LxCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          radius: 18,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => LX.chip.createShader(r),
                    child: Icon(icon, size: 26),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 28,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: LX.ink,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (soon)
                Positioned(
                  right: 0,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SOON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReqTile extends StatelessWidget {
  const _ReqTile({
    required this.image,
    required this.label,
    required this.done,
  });
  final String image;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? const Color(0xFFBBF7D0) : LX.line),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.92,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/img/listing/$image.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done ? LX.green : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: LX.soft(0.2),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: done ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: LX.ink,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_rounded, color: LX.green, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: LX.ink),
          ),
        ),
      ],
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: LxCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      onTap: onTap,
      child: Row(
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => LX.chip.createShader(r),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: LX.ink,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: LX.muted,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({
    required this.brand,
    required this.selected,
    required this.onTap,
  });
  final String brand;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = brandLogo(brand);
    final wordmark = brand == 'Samsung' || brand == 'vivo';
    final img = logo == null
        ? null
        : Image.asset(
            'assets/img/brands/brand_$logo.png',
            height: wordmark ? 15 : 20,
            fit: BoxFit.contain,
            color: selected && (brand == 'Apple' || brand == 'Nothing')
                ? Colors.white
                : null,
          );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: selected ? LX.chip : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.white : LX.line,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: selected ? LX.soft(0.3) : LX.soft(0.05),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (img != null)
                  wordmark && selected
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: img,
                        )
                      : img,
                if (!wordmark || logo == null) ...[
                  if (logo != null) const SizedBox(width: 6),
                  Text(
                    brand,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected ? Colors.white : LX.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboard,
    this.formatters,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final Widget? suffix;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(maxLines > 1 ? 16 : 26);
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: maxLines,
      textCapitalization: keyboard == null
          ? TextCapitalization.words
          : TextCapitalization.none,
      style: const TextStyle(fontWeight: FontWeight.w600, color: LX.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9AA0B8),
          fontWeight: FontWeight.w500,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: r,
          borderSide: const BorderSide(color: LX.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r,
          borderSide: const BorderSide(color: LX.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r,
          borderSide: const BorderSide(color: LX.violet, width: 1.6),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6DDFE)),
        boxShadow: LX.soft(0.10),
      ),
      child: Row(
        children: [
          Icon(icon, color: LX.violet, size: 22),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: LX.violet,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? LX.violet.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? LX.violet.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    gradient: color == null
                        ? const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ],
                          )
                        : RadialGradient(
                            center: const Alignment(-0.4, -0.5),
                            colors: [
                              Color.lerp(color, Colors.white, 0.35)!,
                              color!,
                            ],
                          ),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        gradient: LX.chip,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: LX.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String image;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF7F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? LX.violet : LX.line,
            width: selected ? 1.8 : 1.2,
          ),
          boxShadow: selected ? LX.soft(0.2) : null,
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/img/listing/$image.png',
              height: 52,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: LX.ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 30,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: LX.muted,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? LX.chip : null,
                border: selected
                    ? null
                    : Border.all(color: const Color(0xFFB8BED3), width: 1.6),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LX.line),
      ),
      child: child,
    ),
  );
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFF5F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: value ? const Color(0xFFC7D7FE) : LX.line),
        ),
        child: Column(
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) =>
                  (value
                          ? LX.chip
                          : const LinearGradient(
                              colors: [Color(0xFF9AA0B8), Color(0xFF9AA0B8)],
                            ))
                      .createShader(r),
              child: Icon(icon, size: 26),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: LX.ink,
                  height: 1.15,
                ),
              ),
            ),
            SizedBox(
              height: 26,
              child: LxSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.onChanged,
    this.required = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: LX.violet.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => LX.chip.createShader(r),
            child: Icon(icon, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (required)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: LX.red),
                      ),
                  ],
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: LX.ink,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: LX.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: TextField(
            key: ValueKey(title),
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            onChanged: (_) => onChanged(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: LX.ink,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LX.ink,
              ),
              hintText: '0',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: LX.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: LX.violet, width: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.color = LX.ink});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: LX.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: LX.ink, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
      ],
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: onTap == null ? LX.line : const Color(0xFF3A3F63),
          width: 1.4,
        ),
      ),
      child: Icon(icon, color: onTap == null ? LX.line : LX.ink),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LX.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: LX.violet.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: LX.violet),
                ),
                const Spacer(),
                LxSwitch(value: value, onChanged: onChanged),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: LX.ink,
                fontSize: 13.5,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: LX.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewGallery extends StatefulWidget {
  const _ReviewGallery({required this.photos});
  final List<String> photos;

  @override
  State<_ReviewGallery> createState() => _ReviewGalleryState();
}

class _ReviewGalleryState extends State<_ReviewGallery> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.photos;
    if (p.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F0FA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('No photos', style: TextStyle(color: LX.muted)),
      );
    }
    final i = _i.clamp(0, p.length - 1);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.45,
          child: Stack(
            children: [
              Positioned.fill(child: Photo(p[i], radius: 18, pad: 14)),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1F2340),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${i + 1} / ${p.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: p.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, k) => GestureDetector(
              onTap: () => setState(() => _i = k),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: k == i ? LX.violet : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Photo(p[k], size: 48, radius: 9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 11, color: LX.muted),
                ),
                FittedBox(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label, this.value, {this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFEFEEF8))),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: LX.muted),
        const SizedBox(width: 10),
        SizedBox(
          width: 108,
          child: Text(label, style: const TextStyle(color: LX.muted)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, color: LX.ink),
          ),
        ),
      ],
    ),
  );
}
