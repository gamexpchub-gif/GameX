import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/order.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/widgets/common.dart';
import '../../../discover/providers/discover_providers.dart';
import '../../data/address_service.dart';
import '../../providers/address_provider.dart';

const kDivisions = [
  'Mumbai',
  'Delhi',
  'Bengaluru',
  'Kolkata',
  'Chennai',
  'Hyderabad',
  'Pune',
  'Ahmedabad',
  'Jaipur',
  'Lucknow',
];

/// Cities with next-day express delivery.
const kMetroCities = {
  'Mumbai',
  'Delhi',
  'Bengaluru',
  'Kolkata',
  'Chennai',
  'Hyderabad',
};

IconData addressIcon(String label) => switch (label) {
  'Office' => Icons.work_outline_rounded,
  'Other' => Icons.place_outlined,
  _ => Icons.home_outlined,
};

/// Lists saved addresses; pick one, edit, delete or add a new one.
Future<void> showAddressPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddressPicker(),
    );

/// Add (index == null) or edit an address.
Future<void> showAddressForm(BuildContext context, {int? index}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddressForm(index: index),
    );

class _AddressPicker extends ConsumerWidget {
  const _AddressPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(addressBookProvider);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Delivery address',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: book.addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = book.addresses[i];
                  final sel = i == book.selected;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ref.read(addressBookProvider.notifier).select(i);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: sel
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.white,
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border,
                          width: sel ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            sel
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: sel
                                ? AppColors.primary
                                : theme.colorScheme.outline,
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
                                        a.fullName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AddressLabelTag(a.label),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.oneLine,
                                  style: const TextStyle(height: 1.35),
                                ),
                                Text(
                                  a.phone,
                                  style: TextStyle(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                Navigator.pop(context);
                                showAddressForm(context, index: i);
                              } else {
                                ref
                                    .read(addressBookProvider.notifier)
                                    .remove(i);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (book.addresses.isNotEmpty) const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showAddressForm(context);
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add new address'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressLabelTag extends StatelessWidget {
  const AddressLabelTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(addressIcon(label), size: 12, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({this.index});
  final int? index;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _phone,
      _pin,
      _city,
      _state,
      _area,
      _details,
      _landmark;
  String _label = 'Home';
  double? _lat, _lng;
  List<String> _areas = const [];
  bool _pinBusy = false;
  bool _locBusy = false;
  String? _pinNote;
  bool _pinOk = false;

  AddressService get _svc => ref.read(addressServiceProvider);

  @override
  void initState() {
    super.initState();
    final i = widget.index;
    final e = i == null ? null : ref.read(addressBookProvider).addresses[i];
    final user = ref.read(authProvider);
    _name = TextEditingController(text: e?.fullName ?? user?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? user?.phone ?? '');
    _pin = TextEditingController(text: e?.pincode ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _state = TextEditingController(text: e?.state ?? '');
    _area = TextEditingController(text: e?.area ?? '');
    _details = TextEditingController(text: e?.details ?? '');
    _landmark = TextEditingController(text: e?.landmark ?? '');
    _label = e?.label ?? 'Home';
    _lat = e?.lat;
    _lng = e?.lng;
    _pinOk = (e?.pincode ?? '').length == 6;
    // New address with no saved ones yet: try to fill it from the location.
    if (e == null && ref.read(addressBookProvider).addresses.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _useLocation(quiet: true),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _pin,
      _city,
      _state,
      _area,
      _details,
      _landmark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lookupPin(String pin, {bool keepArea = false}) async {
    if (pin.length != 6) {
      setState(() {
        _pinOk = false;
        _pinNote = null;
        _areas = const [];
      });
      return;
    }
    setState(() => _pinBusy = true);
    final info = await _svc.lookup(pin);
    if (!mounted || _pin.text != pin) return;
    setState(() {
      _pinBusy = false;
      if (info == null) {
        _pinOk = false;
        _pinNote = 'We could not find this PIN code';
        _areas = const [];
        return;
      }
      _pinOk = true;
      _city.text = info.city;
      _state.text = info.state;
      _areas = info.areas;
      _pinNote = info.exact
          ? '${info.city}, ${info.state}'
          : '${info.city}, ${info.state} (please check)';
      if (!keepArea && _areas.length == 1) _area.text = _areas.first;
    });
  }

  Future<void> _useLocation({bool quiet = false}) async {
    setState(() => _locBusy = true);
    try {
      final l = await _svc.current();
      if (!mounted) return;
      setState(() {
        _lat = l.lat;
        _lng = l.lng;
        if (l.street.isNotEmpty && _details.text.trim().isEmpty) {
          _details.text = l.street;
        }
        if (l.area.isNotEmpty) _area.text = l.area;
        if (l.city.isNotEmpty) _city.text = l.city;
        if (l.state.isNotEmpty) _state.text = l.state;
        if (l.pincode.isNotEmpty) _pin.text = l.pincode;
      });
      if (l.pincode.isNotEmpty) await _lookupPin(l.pincode, keepArea: true);
      if (mounted && !quiet) {
        showAppSnack(
          context,
          'Address filled from your location — add house / flat no.',
        );
      }
    } on LocationProblem catch (e) {
      if (mounted && !quiet) {
        showAppSnack(
          context,
          e.message,
          action: e.openSettings ? 'SETTINGS' : null,
          onAction: e.openSettings ? _svc.openSettings : null,
        );
      }
    } catch (_) {
      if (mounted && !quiet) {
        showAppSnack(
          context,
          'Could not get your location. Enter the PIN code instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _locBusy = false);
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (!_pinOk) {
      showAppSnack(context, 'Enter a valid PIN code');
      return;
    }
    final pin = _pin.text.trim();
    ref
        .read(addressBookProvider.notifier)
        .upsert(
          Address(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            pincode: pin,
            area: _area.text.trim(),
            details: _details.text.trim(),
            landmark: _landmark.text.trim(),
            label: _label,
            lat: _lat,
            lng: _lng,
          ),
          index: widget.index,
        );
    // Product pages show delivery dates for this PIN from now on.
    ref.read(deliveryPinProvider.notifier).set(pin);
    Navigator.pop(context);
  }

  InputDecoration _dec(
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.index == null ? 'Add delivery address' : 'Edit address',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              // One tap: fill everything from the phone's location.
              Material(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _locBusy ? null : _useLocation,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _locBusy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _locBusy
                                    ? 'Finding your location…'
                                    : 'Use my current location',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                _lat != null
                                    ? 'Location added • accurate doorstep delivery'
                                    : 'Fills PIN, city, area and street automatically',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (_lat != null)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _lookupPin,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
                decoration:
                    _dec(
                      'PIN code',
                      Icons.pin_drop_outlined,
                      hint: '6-digit PIN',
                      suffix: _pinBusy
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _pinOk
                          ? const Icon(
                              Icons.verified_rounded,
                              color: AppColors.success,
                            )
                          : null,
                    ).copyWith(
                      counterText: '',
                      helperText: _pinNote,
                      helperStyle: TextStyle(
                        color: _pinOk ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                validator: (v) => RegExp(r'^[1-9]\d{5}$').hasMatch(v ?? '')
                    ? null
                    : 'Enter the 6-digit PIN code',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec(
                        'City / District',
                        Icons.location_city_outlined,
                      ),
                      validator: (v) => Validators.required(v, 'City'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _state,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('State', Icons.map_outlined),
                      validator: (v) => Validators.required(v, 'State'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                textCapitalization: TextCapitalization.words,
                decoration: _dec(
                  'Area / Locality',
                  Icons.near_me_outlined,
                  hint: 'e.g. Andheri West',
                ),
                validator: (v) => Validators.required(v, 'Area'),
              ),
              if (_areas.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in _areas.take(12))
                      ChoiceChip(
                        label: Text(a),
                        selected: _area.text == a,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _area.text = a),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                maxLines: 2,
                textCapitalization: TextCapitalization.words,
                decoration: _dec(
                  'House / flat no., building, street',
                  Icons.home_work_outlined,
                ).copyWith(alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().length < 5
                    ? 'Add house / flat number and street'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _landmark,
                textCapitalization: TextCapitalization.words,
                decoration: _dec(
                  'Landmark (optional)',
                  Icons.flag_outlined,
                  hint: 'e.g. near City Mall',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Contact for delivery',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Full name', Icons.person_outline),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _dec(
                  'Mobile number',
                  Icons.phone_outlined,
                  hint: '98765 43210',
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final l in const ['Home', 'Office', 'Other'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(addressIcon(l), size: 16),
                        label: Text(l),
                        selected: _label == l,
                        onSelected: (_) => setState(() => _label = l),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: _save,
                child: const Text('Save & deliver here'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
