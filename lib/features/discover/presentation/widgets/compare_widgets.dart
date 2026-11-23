import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_image.dart';
import '../../../../data/models/product.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import '../../providers/discover_providers.dart';

/// Adds/removes [p] from the compare list with feedback.
void toggleCompare(BuildContext context, WidgetRef ref, Product p) {
  HapticFeedback.selectionClick();
  final r = ref.read(compareProvider.notifier).toggle(p);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final n = ref.read(compareProvider).length;
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(switch (r) {
        CompareResult.added =>
          n == 1
              ? 'Added. Pick one more phone to compare'
              : 'Added to compare ($n/$kMaxCompare)',
        CompareResult.removed => 'Removed from compare',
        CompareResult.full => 'You can compare up to $kMaxCompare phones',
      }),
      action: n >= 2 || r == CompareResult.full
          ? SnackBarAction(
              label: 'COMPARE',
              onPressed: () => context.push('/compare'),
            )
          : null,
    ),
  );
}

/// Round "compare" toggle that sits on top of a product card.
class CompareToggle extends ConsumerWidget {
  const CompareToggle({
    super.key,
    required this.product,
    this.size = 30,
    this.compact = false,
  });
  final Product product;
  final double size;

  /// Icon only (tight spaces such as grid cards).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(isComparedProvider(product.id));
    return GestureDetector(
      onTap: () => toggleCompare(context, ref, product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: size,
        width: compact ? size : null,
        padding: compact
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(horizontal: size * 0.28),
        decoration: BoxDecoration(
          gradient: on ? TX.chip : null,
          color: on ? null : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: TX.soft(0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              on ? Icons.check_rounded : Icons.compare_arrows_rounded,
              size: size * 0.55,
              color: on ? Colors.white : TX.violet,
            ),
            if (!compact) ...[
              SizedBox(width: size * 0.12),
              Text(
                'Compare',
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  color: on ? Colors.white : TX.violet,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Floating bar with the phones picked for comparison.
class CompareTray extends ConsumerWidget {
  const CompareTray({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(compareProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1.4),
          end: Offset.zero,
        ).animate(a),
        child: c,
      ),
      child: list.isEmpty
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('tray'),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              decoration: BoxDecoration(
                gradient: TX.night,
                borderRadius: BorderRadius.circular(22),
                boxShadow: TX.soft(0.3),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < kMaxCompare; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: i < list.length
                          ? GestureDetector(
                              onTap: () => ref
                                  .read(compareProvider.notifier)
                                  .toggle(list[i]),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: AppImage(
                                      list[i].images.first,
                                      fit: BoxFit.contain,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  const Positioned(
                                    right: -4,
                                    top: -4,
                                    child: CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Color(0xFFE11D48),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: list.length < 2
                        ? null
                        : () => context.push('/compare'),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: list.length < 2 ? Colors.white24 : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        list.length < 2
                            ? 'Add 1 more'
                            : 'Compare ${list.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: list.length < 2 ? Colors.white : TX.violet,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
