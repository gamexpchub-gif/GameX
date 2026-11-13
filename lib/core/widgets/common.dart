import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Maps the category icon keys stored in data to Material icons.
IconData categoryIcon(String key) => switch (key) {
  'phone' => Icons.smartphone_rounded,
  'laptop' => Icons.laptop_mac_rounded,
  'audio' => Icons.headphones_rounded,
  'gaming' => Icons.sports_esports_rounded,
  'fashion' => Icons.checkroom_rounded,
  'shoes' => Icons.directions_run_rounded,
  'watch' => Icons.watch_rounded,
  'home' => Icons.chair_rounded,
  _ => Icons.category_rounded,
};

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.trailing,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const Spacer(),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.price,
    this.oldPrice,
    this.large = false,
  });

  final double price;
  final double? oldPrice;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          formatPrice(price),
          style:
              (large
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleSmall)
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
        ),
        if (oldPrice != null && oldPrice! > price)
          Text(
            formatPrice(oldPrice!),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}

class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: style?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          ' ($count)',
          style: style?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge(this.percent, {super.key});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '-$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 10,
    this.compact = false,
  });

  final int value;
  final int max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 40.0;
    Widget btn(IconData icon, VoidCallback? onTap) => SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: compact ? 16 : 20,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            Icons.remove_rounded,
            value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: compact ? 24 : 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          btn(
            Icons.add_rounded,
            value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.wifi_off_rounded,
    title: 'Something went wrong',
    message: 'Please check your connection and try again.',
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}

/// Renders an [AsyncValue] with consistent loading / error UI.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(onRetry: onRetry),
    );
  }
}

void showAppSnack(
  BuildContext context,
  String message, {
  String? action,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        action: action == null
            ? null
            : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ),
    );
}
