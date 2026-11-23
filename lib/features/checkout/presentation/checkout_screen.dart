import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/app_config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/payment_marks.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/order.dart';
import '../../cart/presentation/widgets/price_details.dart';
import '../../cart/providers/cart_provider.dart';
import '../../commerce/data/accessories.dart';
import '../../commerce/data/commerce_api.dart';
import '../../commerce/data/emi.dart';
import '../../commerce/data/protection.dart';
import '../../commerce/presentation/emi_screen.dart';
import '../../commerce/presentation/widgets/commerce_widgets.dart';
import '../../commerce/providers/checkout_extras.dart';
import '../../commerce/services/razorpay_service.dart';
import '../../orders/providers/orders_provider.dart';
import '../providers/address_provider.dart';
import 'widgets/address_sheets.dart';

enum _Delivery { standard, express }

const _expressFee = 150.0;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _payForm = GlobalKey<FormState>();
  final _wallet = TextEditingController();
  final _cardNumber = TextEditingController();
  final _cardExpiry = TextEditingController();
  final _cardCvv = TextEditingController();
  final _cardName = TextEditingController();
  final _note = TextEditingController();

  PaymentMethod get _payment => ref.read(paymentChoiceProvider).method;
  PaymentChoice get _pay => ref.read(paymentChoiceProvider);
  void _setPay(PaymentChoice Function(PaymentChoice) f) =>
      ref.read(paymentChoiceProvider.notifier).update(f);
  _Delivery _delivery = _Delivery.standard;
  bool _agreed = true;
  bool _itemsExpanded = false;
  bool _placing = false;

  @override
  void dispose() {
    for (final c in [
      _wallet,
      _cardNumber,
      _cardExpiry,
      _cardCvv,
      _cardName,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _expressAvailable(Address? a) => kMetroCities.contains(a?.city);

  double _deliveryFee(CartSummary s, Address? a) =>
      _delivery == _Delivery.express && _expressAvailable(a)
      ? s.deliveryFee + _expressFee
      : s.deliveryFee;

  CheckoutTotals _totals(CartSummary s, Address? a) =>
      ref.read(checkoutTotalsProvider(_deliveryFee(s, a)));

  double _total(CartSummary s, Address? a) => _totals(s, a).total;

  /// Why Cash on Delivery is not allowed for this order (null = allowed).
  /// The server enforces the same rules.
  String? _codBlockReason(AppConfig cfg, double total) {
    if (!cfg.codEnabled) {
      return 'Cash on Delivery is paused. Please pay online.';
    }
    final orders = ref.read(ordersProvider);
    final delivered = orders.any((o) => o.status == OrderStatus.delivered);
    final open = orders
        .where(
          (o) =>
              o.paymentMethod == PaymentMethod.cashOnDelivery &&
              (o.isProcessing || o.isShipped),
        )
        .length;
    if (open >= cfg.codMaxOpen) {
      return 'You already have $open Cash on Delivery orders on the way. Please pay online.';
    }
    if (!delivered && total > cfg.codNewLimit) {
      return 'Cash on Delivery is available up to ${formatPrice(cfg.codNewLimit)} on your first order. Please pay online.';
    }
    return null;
  }

  /// "No-cost EMI • HDFC Bank • 6 × ₹8,333" etc.
  String? _paymentNote(double total) {
    final pay = _pay;
    switch (pay.method) {
      case PaymentMethod.emi:
        final b = pay.bank ?? kEmiBanks.first;
        final plan = emiPlan(b, pay.months, total);
        return '${plan.noCost ? 'No-cost EMI' : 'EMI'} • ${b.name} • ${plan.months} × ${formatPrice(plan.monthly.ceilToDouble())}';
      case PaymentMethod.payLater:
        final o = pay.payLater;
        return '${o.title} • ${o.parts} × ${formatPrice(((total + o.fee) / o.parts).ceilToDouble())}';
      case PaymentMethod.card:
        return pay.bank == null ? null : 'Card • ${pay.bank!.name}';
      default:
        return null;
    }
  }

  Future<void> _placeOrder() async {
    final address = ref.read(addressBookProvider).current;
    final items = ref.read(selectedCartProvider);
    final summary = ref.read(cartSummaryProvider);
    if (items.isEmpty) return;
    if (address == null) {
      showAppSnack(context, 'Please add a delivery address');
      showAddressForm(context);
      return;
    }
    final totals = _totals(summary, address);
    if (_payment == PaymentMethod.emi && totals.total < kEmiMinOrder) {
      showAppSnack(
        context,
        'EMI is available on orders above ${formatPrice(kEmiMinOrder)}',
      );
      return;
    }
    if (_payment == PaymentMethod.payLater &&
        !_pay.payLater.allows(totals.total)) {
      showAppSnack(
        context,
        '${_pay.payLater.title} works up to ${formatPrice(_pay.payLater.limit)}',
      );
      return;
    }
    final cfg = ref.read(appConfigProvider).asData?.value ?? AppConfig.offline;
    final codBlock = _codBlockReason(cfg, totals.total);
    if (_payment == PaymentMethod.cashOnDelivery && codBlock != null) {
      showAppSnack(context, codBlock);
      return;
    }
    final gateway = cfg.razorpay && _payment != PaymentMethod.cashOnDelivery;
    if (!gateway &&
        _payment != PaymentMethod.cashOnDelivery &&
        _payment != PaymentMethod.payLater &&
        !(_payForm.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Please complete your payment details');
      return;
    }
    if (!_agreed) {
      showAppSnack(context, 'Please accept the Terms & Return Policy');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _placing = true);
    final orderId = OrdersNotifier.newOrderId(DateTime.now());
    String? paymentRef;
    if (gateway) {
      try {
        paymentRef = await ref
            .read(razorpayServiceProvider)
            .pay(
              keyId: cfg.razorpayKey!,
              orderId: orderId,
              amount: totals.total,
              method: _payment,
              description: '${items.length} item(s) • order $orderId',
            );
      } catch (e) {
        if (!mounted) return;
        setState(() => _placing = false);
        showAppSnack(context, '$e');
        return;
      }
      if (!mounted) return;
    }
    final total = _total(summary, address);

    // Payment / order processing overlay.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _ProcessingDialog(method: _payment, amount: total),
    );

    final Order order;
    try {
      order = await ref
          .read(ordersProvider.notifier)
          .placeOrder(
            items: items,
            address: address,
            payment: _payment,
            subtotal: summary.subtotal,
            deliveryFee: _deliveryFee(summary, address),
            discount: summary.discount,
            lines: totals.orderLines,
            paymentNote: _paymentNote(totals.total),
            tradeIn: totals.tradeIn > 0 ? ref.read(tradeInProvider) : null,
            walletUse: totals.wallet,
            total: totals.total,
            orderId: orderId,
            paymentRef: paymentRef,
          );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _placing = false);
      showAppSnack(context, 'Order not placed: $e');
      return;
    }
    ref.read(cartProvider.notifier).removeKeys({for (final i in items) i.key});
    final api = ref.read(commerceApiProvider);
    for (final i in items) {
      if (i.offerId != null && i.offerId!.startsWith('LOF')) {
        api.markOfferUsed(i.offerId!);
      }
    }
    if (totals.tradeIn > 0) ref.read(tradeInProvider.notifier).set(null);
    ref.read(useWalletProvider.notifier).set(false);
    ref.invalidate(walletProvider);
    ref.invalidate(myOffersProvider);
    ref.read(deselectedProvider.notifier).clear();
    ref.read(promoProvider.notifier).clear();
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.go('/order-success/${order.id}');
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(selectedCartProvider);
    final summary = ref.watch(cartSummaryProvider);
    final address = ref.watch(addressBookProvider).current;
    final theme = Theme.of(context);
    if (!_expressAvailable(address) && _delivery == _Delivery.express) {
      _delivery = _Delivery.standard;
    }
    ref.watch(paymentChoiceProvider);
    final totals = ref.watch(
      checkoutTotalsProvider(_deliveryFee(summary, address)),
    );
    final hasPhone = items.any((i) => !isAccessory(i.product));

    return Scaffold(
      // Light fill behind the rounded sticky bar's corners.
      backgroundColor: const Color(0xFFF1F4FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4FF),
        title: Text('Checkout'.tr(context)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: AppColors.success),
                SizedBox(width: 4),
                Text(
                  'Secure',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AuroraBackground(
        child: items.isEmpty
            ? EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Nothing to checkout',
                message: 'Select items in your cart to continue.',
                actionLabel: 'Go to Cart',
                onAction: () => context.pop(),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                children: [
                  _Steps(current: address == null ? 1 : 2),
                  const SizedBox(height: 14),
                  _addressCard(address),
                  const SizedBox(height: 12),
                  _deliveryCard(summary, address),
                  const SizedBox(height: 12),
                  _itemsCard(items.length, summary),
                  if (hasPhone) ...[
                    const SizedBox(height: 12),
                    _protectionCard(),
                    const SizedBox(height: 12),
                    const CrossSellCard(),
                    const SizedBox(height: 12),
                    _tradeInCard(totals),
                  ],
                  const SizedBox(height: 12),
                  _paymentCard(summary, address),
                  const SizedBox(height: 12),
                  _walletCard(totals),
                  const SizedBox(height: 12),
                  _couponAndNote(summary),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          icon: Icons.receipt_long_rounded,
                          title: 'Order Summary',
                        ),
                        const SizedBox(height: 10),
                        SummaryLines(
                          summary: summary,
                          couponCode: ref.watch(promoProvider),
                          deliveryFeeOverride: summary.deliveryFee,
                          extraSavings:
                              totals.festival + totals.bank + totals.wallet,
                          extraLines: [
                            if (_delivery == _Delivery.express &&
                                _expressAvailable(address))
                              ('Express delivery', _expressFee),
                            ...totals.orderLines,
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        children: const [
                          TextSpan(
                            text: 'Terms of Sale',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: '7-day Return Policy',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : StickyBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatPrice(totals.total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          totals.savings > 0
                              ? 'You save ${formatPrice(totals.savings)}'
                              : 'Incl. GST & delivery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: totals.savings > 0
                                ? AppColors.success
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 196,
                    child: FilledButton(
                      onPressed: _placing ? null : _placeOrder,
                      child: FittedBox(
                        child: Text(switch (_payment) {
                          PaymentMethod.cashOnDelivery => 'Place Order'.tr(
                            context,
                          ),
                          PaymentMethod.emi => 'Pay with EMI',
                          PaymentMethod.payLater => 'Buy now, pay later',
                          _ => 'Pay ${formatPrice(totals.total)}',
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Address ──
  Widget _addressCard(Address? a) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
            icon: Icons.location_on_rounded,
            title: 'Delivery Address',
            trailing: a == null
                ? null
                : TextButton(
                    onPressed: () => showAddressPicker(context),
                    child: const Text('Change'),
                  ),
          ),
          const SizedBox(height: 12),
          if (a == null)
            OutlinedButton.icon(
              onPressed: () => showAddressForm(context),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add delivery address'),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(addressIcon(a.label), color: AppColors.primary),
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
                        Text(a.oneLine, style: const TextStyle(height: 1.35)),
                        const SizedBox(height: 2),
                        Text(
                          a.phone,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Delivery speed ──
  Widget _deliveryCard(CartSummary s, Address? a) {
    final now = DateTime.now();
    final std = DateFormat(
      'EEE, d MMM',
    ).format(now.add(Duration(days: kMetroCities.contains(a?.city) ? 2 : 4)));
    final exp = DateFormat('EEE, d MMM')
        .format(now.add(const Duration(days: 1)));
    final express = _expressAvailable(a);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.local_shipping_rounded,
            title: 'Delivery Option',
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            selected: _delivery == _Delivery.standard,
            onTap: () => setState(() => _delivery = _Delivery.standard),
            leading: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
            ),
            title: 'Standard delivery',
            subtitle: 'Get it by $std',
            trailing: s.deliveryFee == 0 ? 'FREE' : formatPrice(s.deliveryFee),
            trailingColor: s.deliveryFee == 0 ? AppColors.success : null,
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: express ? 1 : 0.5,
            child: _ChoiceTile(
              selected: _delivery == _Delivery.express,
              onTap: express
                  ? () => setState(() => _delivery = _Delivery.express)
                  : null,
              leading: const Icon(Icons.bolt_rounded, color: AppColors.warning),
              title: 'Express delivery',
              subtitle: express
                  ? 'Tomorrow, $exp • Metro cities'
                  : 'Available in metro cities only',
              trailing: '+${formatPrice(_expressFee)}',
            ),
          ),
        ],
      ),
    );
  }

  // ── Items ──
  Widget _itemsCard(int lines, CartSummary s) {
    final items = ref.watch(selectedCartProvider);
    final theme = Theme.of(context);
    final shown = _itemsExpanded ? items : items.take(2).toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
            icon: Icons.shopping_bag_rounded,
            title: 'Items (${s.itemCount})',
            trailing: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Edit'),
            ),
          ),
          const SizedBox(height: 6),
          for (final i in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AppImage(
                    i.product.images.first,
                    width: 56,
                    height: 62,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          i.size ?? i.product.memoryLabel ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          'Qty ${i.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPrice(i.total),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          if (items.length > 2)
            TextButton.icon(
              onPressed: () => setState(() => _itemsExpanded = !_itemsExpanded),
              icon: Icon(
                _itemsExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _itemsExpanded ? 'Show less' : 'Show all ${items.length} items',
              ),
            ),
        ],
      ),
    );
  }

  // ── Payment ──
  Widget _paymentCard(CartSummary s, Address? a) {
    final theme = Theme.of(context);
    const subtitles = {
      PaymentMethod.cashOnDelivery: 'Pay in cash when the phone arrives',
      PaymentMethod.bkash: 'Google Pay, PhonePe, Paytm & any UPI app',
      PaymentMethod.nagad: 'Paytm, Amazon Pay, Mobikwik wallets',
      PaymentMethod.card: 'Visa, Mastercard, Amex, RuPay • bank offers',
      PaymentMethod.emi: 'No-cost EMI on credit cards',
      PaymentMethod.payLater: 'Pay in 15 days, in 3 parts or cardless EMI',
    };
    return SectionCard(
      child: Form(
        key: _payForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeading(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Payment Method',
            ),
            const SizedBox(height: 12),
            for (final m in PaymentMethod.values) ...[
              _ChoiceTile(
                selected: _payment == m,
                onTap: () => _setPay(
                  (p) => p.copyWith(
                    method: m,
                    bankId: m == PaymentMethod.emi && p.bankId == null
                        ? () => kEmiBanks.first.id
                        : null,
                  ),
                ),
                leading: PaymentMark(m, size: 40),
                title: m.label,
                subtitle: subtitles[m]!,
                expanded: _payment == m ? _paymentDetails(m, s, a) : null,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '256-bit SSL encrypted. We never store your card details.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _paymentDetails(PaymentMethod m, CartSummary s, Address? a) {
    switch (m) {
      case PaymentMethod.cashOnDelivery:
        final block = _codBlockReason(
          ref.read(appConfigProvider).asData?.value ?? AppConfig.offline,
          _total(s, a),
        );
        return Text(
          block ??
              'Pay ${formatPrice(_total(s, a))} to the delivery agent. You can check the phone and verify the IMEI before paying.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: block == null ? null : AppColors.danger,
            fontWeight: block == null ? null : FontWeight.w700,
          ),
        );
      case PaymentMethod.bkash when _gateway:
      case PaymentMethod.nagad when _gateway:
        return const Text(
          'You will pay securely on the Razorpay screen after tapping Pay.',
          style: TextStyle(fontSize: 12.5, height: 1.4),
        );
      case PaymentMethod.bkash:
        return TextFormField(
          controller: _wallet,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            hintText: 'yourname@okaxis',
            prefixIcon: Icon(Icons.qr_code_2_rounded),
            isDense: true,
          ),
          validator: (v) =>
              RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch((v ?? '').trim())
              ? null
              : 'Enter a valid UPI ID',
        );
      case PaymentMethod.nagad:
        return TextFormField(
          controller: _wallet,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Wallet mobile number',
            hintText: '98765 43210',
            prefixIcon: Icon(Icons.phone_android_rounded),
            isDense: true,
          ),
          validator: Validators.phone,
        );
      case PaymentMethod.emi:
        final total = _total(s, a);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmiPlanPicker(
              price: total,
              bankId: _pay.bankId ?? kEmiBanks.first.id,
              months: _pay.months,
              onChanged: (b, m) =>
                  _setPay((p) => p.copyWith(bankId: () => b, months: m)),
            ),
            const SizedBox(height: 12),
            _cardFields(),
          ],
        );
      case PaymentMethod.payLater:
        final total = _total(s, a);
        return RadioGroup<String>(
          groupValue: _pay.payLaterId,
          onChanged: (v) => _setPay((p) => p.copyWith(payLaterId: v)),
          child: Column(
            children: [
              for (final o in kPayLater)
                RadioListTile<String>(
                  value: o.id,
                  enabled: o.allows(total),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    o.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    o.allows(total)
                        ? (o.parts == 1
                              ? 'Pay ${formatPrice(total)} by ${DateFormat('d MMM').format(DateTime.now().add(Duration(days: o.days)))}'
                              : '${o.parts} × ${formatPrice(((total + o.fee) / o.parts).ceilToDouble())}${o.fee > 0 ? ' (incl. ${formatPrice(o.fee)} fee)' : ''}')
                        : 'Up to ${formatPrice(o.limit)}',
                  ),
                ),
              const Text(
                'Quick KYC with PAN on the next screen. No credit card needed.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      case PaymentMethod.card:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Card issued by (for bank offers)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in kEmiBanks)
                  ChoiceChip(
                    label: Text(b.name, style: const TextStyle(fontSize: 12)),
                    selected: _pay.bankId == b.id,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) => _setPay(
                      (p) => p.copyWith(bankId: () => v ? b.id : null),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _cardFields(),
          ],
        );
    }
  }

  bool get _gateway =>
      ref.read(appConfigProvider).asData?.value.razorpay ?? false;

  Widget _cardFields() => _gateway
      ? const Text(
          'Card details are entered securely on the Razorpay screen (PCI-DSS compliant). GAMEX never sees your card number.',
          style: TextStyle(fontSize: 12.5, height: 1.4),
        )
      : Column(
          children: [
            TextFormField(
              controller: _cardNumber,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card_rounded),
                isDense: true,
              ),
              validator: Validators.cardNumber,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardExpiry,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      hintText: 'MM/YY',
                      isDense: true,
                    ),
                    validator: Validators.cardExpiry,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _cardCvv,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '•••',
                      isDense: true,
                    ),
                    validator: Validators.cvv,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _cardName,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Name on card',
                isDense: true,
              ),
              validator: (v) => Validators.required(v, 'Name'),
            ),
          ],
        );

  // ── Protection ──
  Widget _protectionCard() {
    final items = ref
        .watch(selectedCartProvider)
        .where((i) => canProtect(i.product.categoryId))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            icon: Icons.shield_rounded,
            title: 'Protect your phone',
          ),
          const SizedBox(height: 4),
          const Text(
            'Screen damage, liquid damage and extended warranty. Claim from the app.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          for (final i in items) ...[
            if (items.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Text(
                  i.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ProtectionPicker(
              phonePrice: i.product.price,
              selected: i.protection,
              onChanged: (id) =>
                  ref.read(cartProvider.notifier).setProtection(i.key, id),
            ),
          ],
        ],
      ),
    );
  }

  // ── Trade-in ──
  Widget _tradeInCard(CheckoutTotals t) {
    final q = ref.watch(tradeInProvider);
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F9F6E), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q == null
                      ? 'Exchange your old phone'
                      : 'Exchange: −${formatPrice(t.tradeIn)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: q == null ? null : AppColors.success,
                  ),
                ),
                Text(
                  q == null
                      ? 'Instant quote, taken off this bill. Picked up at delivery.'
                      : '${q.device.model} • ${q.device.conditionSummary} • hand it over at delivery',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (q == null)
            TextButton(
              onPressed: () =>
                  context.push('/trade-in?price=${t.summary.subtotal.round()}'),
              child: const Text('Get quote'),
            )
          else
            IconButton(
              tooltip: 'Remove trade-in',
              onPressed: () => ref.read(tradeInProvider.notifier).set(null),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }

  // ── Wallet ──
  Widget _walletCard(CheckoutTotals t) {
    final user = ref.watch(walletProvider).asData?.value;
    final on = ref.watch(useWalletProvider);
    if (user == null || t.walletAvailable <= 0) {
      return BankOffersCard(amount: t.beforeCredits, max: 3);
    }
    return Column(
      children: [
        SectionCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: on,
            onChanged: (v) => ref.read(useWalletProvider.notifier).set(v),
            secondary: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              'Use GAMEX wallet (${formatPrice(t.walletAvailable)})',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              on
                  ? '−${formatPrice(t.wallet)} applied'
                  : 'Pay up to ${formatPrice(t.walletCap)} on this order',
              style: TextStyle(color: on ? AppColors.success : null),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BankOffersCard(amount: t.beforeCredits, max: 3),
      ],
    );
  }

  // ── Coupon + note ──
  Widget _couponAndNote(CartSummary s) {
    final code = ref.watch(promoProvider);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => showCouponSheet(context),
            leading: Icon(
              s.discount > 0
                  ? Icons.local_offer_rounded
                  : Icons.local_offer_outlined,
              color: s.discount > 0 ? AppColors.success : AppColors.primary,
            ),
            title: Text(
              s.discount > 0 ? '$code applied' : 'Apply coupon',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: s.discount > 0
                ? Text(
                    'You save ${formatPrice(s.discount)}',
                    style: const TextStyle(color: AppColors.success),
                  )
                : null,
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Delivery instructions (optional)',
              prefixIcon: Icon(Icons.sticky_note_2_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Widgets ─────────────────────────────

/// Cart ✓ — Address — Payment — Done progress header.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['Cart', 'Address', 'Payment', 'Done'];
    return Glass(
      radius: 20,
      color: Colors.white.withValues(alpha: 0.88),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: i <= current
                      ? AppColors.primary
                      : const Color(0xFFE3E8F5),
                  child: i < current
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: i <= current
                                ? Colors.white
                                : const Color(0xFF8C95B0),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i <= current
                        ? AppColors.primary
                        : const Color(0xFF8C95B0),
                  ),
                ),
              ],
            ),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                  decoration: BoxDecoration(
                    color: i < current
                        ? AppColors.primary
                        : const Color(0xFFE3E8F5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingColor,
    this.expanded,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final String? trailing;
  final Color? trailingColor;
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: trailingColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
            if (expanded != null) ...[const SizedBox(height: 12), expanded!],
          ],
        ),
      ),
    );
  }
}

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog({required this.method, required this.amount});
  final PaymentMethod method;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final cod = method == PaymentMethod.cashOnDelivery;
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaymentMark(method, size: 56),
              const SizedBox(height: 18),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              Text(
                cod
                    ? 'Placing your order…'
                    : 'Processing ${formatPrice(amount)}…',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cod
                    ? 'Reserving your phone and booking delivery'
                    : 'Securely connecting to ${method.label}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                'Please don\'t close the app',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1234567812345678" → "1234 5678 1234 5678".
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final capped = digits.length > 19 ? digits.substring(0, 19) : digits;
    final b = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(capped[i]);
    }
    final t = b.toString();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

/// "1228" → "12/28".
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll('/', '');
    if (d.length > 4) d = d.substring(0, 4);
    final t = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
