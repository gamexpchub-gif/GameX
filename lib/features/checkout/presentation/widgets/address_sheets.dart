import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/order.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/address_provider.dart';

const kDivisions = [
  'Dhaka',
  'Chattogram',
  'Sylhet',
  'Rajshahi',
  'Khulna',
  'Barishal',
  'Rangpur',
  'Mymensingh',
];

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
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _area;
  late final TextEditingController _details;
  String _city = 'Dhaka';
  String _label = 'Home';

  @override
  void initState() {
    super.initState();
    final i = widget.index;
    final existing = i == null
        ? null
        : ref.read(addressBookProvider).addresses[i];
    final user = ref.read(authProvider);
    _name = TextEditingController(text: existing?.fullName ?? user?.name ?? '');
    _phone = TextEditingController(text: existing?.phone ?? user?.phone ?? '');
    _area = TextEditingController(text: existing?.area ?? '');
    _details = TextEditingController(text: existing?.details ?? '');
    if (existing != null) {
      _city = kDivisions.contains(existing.city) ? existing.city : 'Dhaka';
      _label = existing.label;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _details]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    ref
        .read(addressBookProvider.notifier)
        .upsert(
          Address(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            city: _city,
            area: _area.text.trim(),
            details: _details.text.trim(),
            label: _label,
          ),
          index: widget.index,
        );
    Navigator.pop(context);
  }

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
                widget.index == null ? 'Add new address' : 'Edit address',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(
                  labelText: 'Division / City',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: [
                  for (final c in kDivisions)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _city = v ?? _city),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _area,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Area / Thana',
                  hintText: 'e.g. Dhanmondi',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (v) => Validators.required(v, 'Area'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'House, road, landmark',
                  alignLabelWithHint: true,
                ),
                validator: (v) => Validators.required(v, 'Address'),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: _save, child: const Text('Save address')),
            ],
          ),
        ),
      ),
    );
  }
}
