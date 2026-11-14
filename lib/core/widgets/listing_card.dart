import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/product.dart';
import '../../features/home/presentation/widgets/design_scale.dart';
import '../../features/home/presentation/widgets/home_sections.dart'
    show compactCount;
import '../../features/wishlist/providers/wishlist_provider.dart';
import '../utils/formatters.dart';
import 'app_image.dart';
import 'commerce_actions.dart';

/// Card design grid: 388 px wide × 640 px tall (2-column feed).
const _gridW = 388.0;
const _gridH = 640.0;

/// Height of a [ListingCard] rendered [width] logical px wide.
double listingCardHeight(double width) => width * _gridH / _gridW;

/// Product card for the 2-column "New Listings" feed (and rails): square
/// photo with condition + discount badges, name, RAM/storage • colour,
/// rating, price/MRP/off, verified / condition / warranty chips and
/// Buy Now + Add to Cart. Scales with its width.
class ListingCard extends ConsumerWidget {
  const ListingCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, c) => _content(context, ref, c.maxWidth / _gridW),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, double u) {
    final p = product;
    final wished = ref.watch(isWishlistedProvider(p.id));
    final condition = (p.condition ?? 'Excellent').replaceAll(' Condition', '');
    final color = p.colors.isEmpty ? null : Color(p.colors.first);
    final meta = [p.memoryLabel, p.colorName].whereType<String>().join('  •  ');

    TextStyle t(
      double size, {
      FontWeight w = FontWeight.w400,
      Color c = HomeColors.muted,
    }) => TextStyle(fontSize: size * u, fontWeight: w, color: c, height: 1.2);

    Widget chip(IconData icon, String text, Color fg, Color bg) => Container(
      height: 30 * u,
      padding: EdgeInsets.symmetric(horizontal: 10 * u),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15 * u),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17 * u, color: fg),
          SizedBox(width: 5 * u),
          Text(
            text,
            style: t(15, w: FontWeight.w600, c: fg),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => context.push('/product/${p.id}'),
      child: Container(
        padding: EdgeInsets.all(12 * u),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28 * u),
          border: Border.all(color: const Color(0xFFE7ECF8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square photo + badges.
            AspectRatio(
              aspectRatio: 364 / 320,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AppImage(
                      p.images.first,
                      borderRadius: BorderRadius.circular(20 * u),
                    ),
                  ),
                  if (p.discountPercent > 0)
                    Positioned(
                      left: 10 * u,
                      top: 10 * u,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * u,
                          vertical: 4 * u,
                        ),
                        decoration: BoxDecoration(
                          color: HomeColors.blue,
                          borderRadius: BorderRadius.circular(10 * u),
                        ),
                        child: Text(
                          '-${p.discountPercent}%',
                          style: t(16, w: FontWeight.w800, c: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6 * u,
                    top: 6 * u,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(wishlistProvider.notifier).toggle(p);
                      },
                      child: Container(
                        width: 44 * u,
                        height: 44 * u,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          wished
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 26 * u,
                          color: wished
                              ? HomeColors.red
                              : const Color(0xFF5B6688),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10 * u,
                    bottom: 10 * u,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * u,
                        vertical: 5 * u,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1230).withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(10 * u),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.diamond_outlined,
                            size: 15 * u,
                            color: const Color(0xFF9FD3FF),
                          ),
                          SizedBox(width: 5 * u),
                          Text(
                            condition,
                            style: t(14.5, w: FontWeight.w700, c: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (p.batteryHealth > 0)
                    Positioned(
                      right: 10 * u,
                      bottom: 10 * u,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * u,
                          vertical: 5 * u,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10 * u),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.battery_5_bar_rounded,
                              size: 16 * u,
                              color: HomeColors.green,
                            ),
                            SizedBox(width: 3 * u),
                            Text(
                              '${p.batteryHealth}%',
                              style: t(
                                14.5,
                                w: FontWeight.w700,
                                c: HomeColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!p.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20 * u),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'SOLD OUT',
                          style: t(22, w: FontWeight.w800, c: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 14 * u),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t(25, w: FontWeight.w700, c: HomeColors.ink),
            ),
            SizedBox(height: 5 * u),
            Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 15 * u,
                    height: 15 * u,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  SizedBox(width: 7 * u),
                ],
                Expanded(
                  child: Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 7 * u),
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 22 * u,
                  color: const Color(0xFFF7B500),
                ),
                SizedBox(width: 4 * u),
                Text(
                  p.rating.toStringAsFixed(1),
                  style: t(17, w: FontWeight.w700, c: HomeColors.amber),
                ),
                Text(
                  '  (${compactCount(p.reviewCount)} reviews)',
                  style: t(16, c: HomeColors.grey),
                ),
              ],
            ),
            SizedBox(height: 9 * u),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(p.price),
                  style: t(30, w: FontWeight.w800, c: HomeColors.ink),
                ),
                SizedBox(width: 8 * u),
                if (p.oldPrice != null)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 3 * u),
                      child: Text(
                        formatPrice(p.mrp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(17, c: HomeColors.grey).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: HomeColors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (p.discountPercent > 0)
              Padding(
                padding: EdgeInsets.only(top: 2 * u),
                child: Text(
                  '${p.discountPercent}% off • Save ${formatPrice(p.mrp - p.price)}',
                  style: t(16, w: FontWeight.w700, c: HomeColors.green),
                ),
              ),
            SizedBox(height: 10 * u),
            Wrap(
              spacing: 6 * u,
              runSpacing: 6 * u,
              children: [
                if (p.verified)
                  chip(
                    Icons.verified_user_rounded,
                    'Verified',
                    HomeColors.blue,
                    const Color(0xFFE8EFFF),
                  ),
                if (p.warrantyMonths > 0)
                  chip(
                    Icons.gpp_good_outlined,
                    '${p.warrantyMonths}M Warranty',
                    const Color(0xFF6A3DF5),
                    const Color(0xFFF0EAFF),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _Btn(
                    u: u,
                    filled: true,
                    onTap: p.inStock ? () => buyNow(context, ref, p) : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 22 * u,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4 * u),
                        Text(
                          'Buy Now',
                          style: t(18, w: FontWeight.w700, c: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8 * u),
                SizedBox(
                  width: 56 * u,
                  child: _Btn(
                    u: u,
                    filled: false,
                    onTap: p.inStock ? () => addToCart(context, ref, p) : null,
                    child: Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 24 * u,
                      color: HomeColors.blue,
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
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.u,
    required this.filled,
    required this.onTap,
    required this.child,
  });
  final double u;
  final bool filled;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: filled
          ? (enabled ? HomeColors.blue : const Color(0xFF9AA5C4))
          : const Color(0xFFEAF0FF),
      borderRadius: BorderRadius.circular(16 * u),
      child: InkWell(
        borderRadius: BorderRadius.circular(16 * u),
        onTap: onTap,
        child: SizedBox(
          height: 54 * u,
          child: Center(child: child),
        ),
      ),
    );
  }
}
