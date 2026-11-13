import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../providers/cart_provider.dart';

/// Itemised price breakdown used by cart, checkout and order details.
class SummaryLines extends StatelessWidget {
  const SummaryLines({
    super.key,
    required this.summary,
    this.couponCode,
    this.extraLines = const [],
    this.deliveryFeeOverride,
  });

  final CartSummary summary;
  final String? couponCode;

  /// Additional (label, amount) lines, e.g. express delivery.
  final List<(String, double)> extraLines;

  /// Delivery fee to show instead of the summary's (checkout options).
  final double? deliveryFeeOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delivery = deliveryFeeOverride ?? summary.deliveryFee;
    final total =
        summary.subtotal +
        delivery -
        summary.discount +
        extraLines.fold(0.0, (s, e) => s + e.$2);

    Widget line(
      String label,
      String value, {
      Color? color,
      bool bold = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                  : TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style:
                (bold
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
          ),
        ],
      ),
    );

    final count = summary.itemCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(
          'Price${count > 0 ? ' ($count item${count == 1 ? '' : 's'})' : ''}',
          formatPrice(summary.mrpTotal),
        ),
        if (summary.mrpDiscount > 0)
          line(
            'Discount on MRP',
            '-${formatPrice(summary.mrpDiscount)}',
            color: AppColors.success,
          ),
        if (summary.discount > 0)
          line(
            'Coupon${couponCode == null ? '' : ' ($couponCode)'}',
            '-${formatPrice(summary.discount)}',
            color: AppColors.success,
          ),
        line(
          'Delivery fee',
          delivery == 0 ? 'FREE' : formatPrice(delivery),
          color: delivery == 0 ? AppColors.success : null,
        ),
        for (final e in extraLines) line(e.$1, formatPrice(e.$2)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1),
        ),
        line('Total amount', formatPrice(total), bold: true),
        if (summary.totalSavings > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  size: 20,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You save ${formatPrice(summary.totalSavings)} on this order',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Coupon picker: type a code or pick from the available list.
Future<void> showCouponSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CouponSheet(),
    );

class _CouponSheet extends ConsumerStatefulWidget {
  const _CouponSheet();

  @override
  ConsumerState<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<_CouponSheet> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _apply(String code) {
    final subtotal = ref.read(cartSummaryProvider).subtotal;
    final coupon = couponByCode(code.trim().toUpperCase());
    if (coupon == null) {
      setState(() => _error = 'This coupon code is not valid');
      return;
    }
    if (subtotal < coupon.minOrder) {
      setState(
        () => _error =
            'Add ${formatPrice(coupon.minOrder - subtotal)} more to use ${coupon.code}',
      );
      return;
    }
    ref.read(promoProvider.notifier).apply(coupon.code);
    Navigator.pop(context);
    showAppSnack(
      context,
      '${coupon.code} applied • You save ${formatPrice(couponDiscount(coupon, subtotal))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = ref.watch(cartSummaryProvider).subtotal;
    final applied = ref.watch(promoProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Apply coupon',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    prefixIcon: const Icon(Icons.local_offer_outlined),
                    errorText: _error,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 52),
                  ),
                  onPressed: () => _apply(_c.text),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Available coupons',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final c in coupons) ...[
            _CouponTile(
              coupon: c,
              eligible: subtotal >= c.minOrder,
              saving: couponDiscount(c, subtotal),
              applied: applied == c.code,
              onApply: () => _apply(c.code),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({
    required this.coupon,
    required this.eligible,
    required this.saving,
    required this.applied,
    required this.onApply,
  });

  final Coupon coupon;
  final bool eligible;
  final double saving;
  final bool applied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: eligible ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: applied ? AppColors.success : AppColors.border,
            width: applied ? 1.6 : 1,
          ),
          color: Colors.white,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 52,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(15),
                  ),
                ),
                child: const RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Text(
                      'OFFER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(coupon.title),
                      const SizedBox(height: 4),
                      Text(
                        eligible
                            ? 'You save ${formatPrice(saving)}'
                            : 'Min. order ${formatPrice(coupon.minOrder)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: eligible
                              ? AppColors.success
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: applied
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                        )
                      : TextButton(
                          onPressed: eligible ? onApply : null,
                          child: const Text('APPLY'),
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
