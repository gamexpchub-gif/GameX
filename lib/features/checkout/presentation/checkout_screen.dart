import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/providers/orders_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _area;
  late final TextEditingController _details;
  final _notes = TextEditingController();
  String _city = 'Dhaka';
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  bool _placing = false;

  static const _cities = [
    'Dhaka',
    'Chattogram',
    'Sylhet',
    'Rajshahi',
    'Khulna',
    'Barishal',
    'Rangpur',
    'Mymensingh',
  ];

  @override
  void initState() {
    super.initState();
    final saved = ref.read(savedAddressProvider);
    final user = ref.read(authProvider);
    _name = TextEditingController(text: saved?.fullName ?? user?.name ?? '');
    _phone = TextEditingController(text: saved?.phone ?? user?.phone ?? '');
    _area = TextEditingController(text: saved?.area ?? '');
    _details = TextEditingController(text: saved?.details ?? '');
    if (saved != null && _cities.contains(saved.city)) _city = saved.city;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _details, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_form.currentState!.validate()) {
      showAppSnack(context, 'Please complete your delivery address');
      return;
    }
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;
    final summary = ref.read(cartSummaryProvider);

    setState(() => _placing = true);
    final order = await ref
        .read(ordersProvider.notifier)
        .placeOrder(
          items: items,
          address: Address(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            city: _city,
            area: _area.text.trim(),
            details: _details.text.trim(),
          ),
          payment: _payment,
          subtotal: summary.subtotal,
          deliveryFee: summary.deliveryFee,
          discount: summary.discount,
        );
    ref.read(cartProvider.notifier).clear();
    ref.read(promoProvider.notifier).clear();
    HapticFeedback.heavyImpact();
    if (mounted) context.go('/order-success/${order.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ref.watch(cartSummaryProvider);
    final count = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _SectionTitle(
              icon: Icons.location_on_outlined,
              title: 'Delivery address',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => Validators.required(v, 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '01XXXXXXXXX',
                      ),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: const InputDecoration(
                        labelText: 'City / Division',
                      ),
                      items: [
                        for (final c in _cities)
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
                  ],
                ),
              ),
            ),
            _SectionTitle(
              icon: Icons.payments_outlined,
              title: 'Payment method',
            ),
            Card(
              child: RadioGroup<PaymentMethod>(
                groupValue: _payment,
                onChanged: (v) => setState(() => _payment = v ?? _payment),
                child: Column(
                  children: [
                    for (final m in PaymentMethod.values)
                      RadioListTile<PaymentMethod>(
                        value: m,
                        title: Text(
                          m.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(_paymentHint(m)),
                        secondary: _PaymentIcon(method: m),
                      ),
                  ],
                ),
              ),
            ),
            _SectionTitle(
              icon: Icons.sticky_note_2_outlined,
              title: 'Order note (optional)',
            ),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Anything the delivery person should know?',
              ),
            ),
            _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Order summary ($count items)',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SummaryLines(summary: summary),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your payment information is encrypted and secure.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FilledButton(
            onPressed: _placing || count == 0 ? null : _placeOrder,
            child: _placing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(
                    _payment == PaymentMethod.cashOnDelivery
                        ? 'Place Order'
                        : 'Pay & Place Order',
                  ),
          ),
        ),
      ),
    );
  }

  String _paymentHint(PaymentMethod m) => switch (m) {
    PaymentMethod.cashOnDelivery => 'Pay when you receive the product',
    PaymentMethod.bkash => 'Pay with your bKash account',
    PaymentMethod.nagad => 'Pay with your Nagad account',
    PaymentMethod.card => 'Visa, Mastercard, Amex',
  };
}

class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({required this.method});
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (method) {
      PaymentMethod.cashOnDelivery => (
        Icons.local_atm_rounded,
        AppColors.success,
      ),
      PaymentMethod.bkash => (
        Icons.phone_android_rounded,
        const Color(0xFFE2136E),
      ),
      PaymentMethod.nagad => (
        Icons.phone_iphone_rounded,
        const Color(0xFFF7941D),
      ),
      PaymentMethod.card => (Icons.credit_card_rounded, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
