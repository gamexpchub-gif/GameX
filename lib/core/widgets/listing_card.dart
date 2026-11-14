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
import 'glass.dart';

/// Height of a [ListingCard] in design px (852-wide grid).
const kListingCardHeight = 486.0;

/// Compact product card for the 3-column "New Listings" grid: name,
/// RAM/storage, colour, rating, price/MRP/off, verified, condition,
/// warranty and Buy Now + Add to Cart.
class ListingCard extends ConsumerWidget {
  const ListingCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final p = product;
    final wished = ref.watch(isWishlistedProvider(p.id));
    final condition = (p.condition ?? '').replaceAll(' Condition', '');
    final color = p.colors.isEmpty ? null : Color(p.colors.first);

    TextStyle t(
      double size, {
      FontWeight w = FontWeight.w400,
      Color c = HomeColors.muted,
    }) => TextStyle(fontSize: size * k, fontWeight: w, color: c, height: 1.2);

    Widget line(IconData icon, Color iconColor, String text) => Row(
      children: [
        Icon(icon, size: 17 * k, color: iconColor),
        SizedBox(width: 5 * k),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t(15.5, c: HomeColors.inkSoft),
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: () => context.push('/product/${p.id}'),
      // No blurred shadow: hundreds of these scroll by in the feed.
      child: Glass(
        radius: 22 * k,
        shadow: false,
        color: Colors.white.withValues(alpha: 0.92),
        padding: EdgeInsets.all(9 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + badges.
            SizedBox(
              height: 196 * k,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AppImage(
                      p.images.first,
                      borderRadius: BorderRadius.circular(16 * k),
                    ),
                  ),
                  if (p.discountPercent > 0)
                    Positioned(
                      left: 6 * k,
                      top: 6 * k,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * k,
                          vertical: 3 * k,
                        ),
                        decoration: BoxDecoration(
                          color: HomeColors.blue,
                          borderRadius: BorderRadius.circular(8 * k),
                        ),
                        child: Text(
                          '-${p.discountPercent}%',
                          style: t(14, w: FontWeight.w700, c: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 2 * k,
                    top: 2 * k,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(wishlistProvider.notifier).toggle(p);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(6 * k),
                        child: Icon(
                          wished
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 28 * k,
                          color: wished
                              ? HomeColors.red
                              : const Color(0xFF5B6688),
                        ),
                      ),
                    ),
                  ),
                  if (!p.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16 * k),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'SOLD OUT',
                          style: t(17, w: FontWeight.w800, c: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 10 * k),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t(20, w: FontWeight.w600, c: HomeColors.ink),
            ),
            SizedBox(height: 4 * k),
            Text(p.memoryLabel ?? '', maxLines: 1, style: t(16)),
            SizedBox(height: 4 * k),
            Row(
              children: [
                if (color != null)
                  Container(
                    width: 13 * k,
                    height: 13 * k,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                SizedBox(width: 5 * k),
                Expanded(
                  child: Text(
                    p.colorName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(16),
                  ),
                ),
              ],
            ),
            SizedBox(height: 5 * k),
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 19 * k,
                  color: const Color(0xFFF7B500),
                ),
                SizedBox(width: 3 * k),
                Text(
                  p.rating.toStringAsFixed(1),
                  style: t(15.5, w: FontWeight.w600, c: HomeColors.amber),
                ),
                Text(
                  ' (${compactCount(p.reviewCount)})',
                  style: t(15, c: HomeColors.grey),
                ),
              ],
            ),
            SizedBox(height: 6 * k),
            Text(
              formatPrice(p.price),
              style: t(24, w: FontWeight.w700, c: HomeColors.ink),
            ),
            SizedBox(height: 2 * k),
            Row(
              children: [
                if (p.oldPrice != null)
                  Flexible(
                    child: Text(
                      formatPrice(p.mrp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t(15, c: HomeColors.grey).copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: HomeColors.grey,
                      ),
                    ),
                  ),
                SizedBox(width: 5 * k),
                if (p.discountPercent > 0)
                  Text(
                    '${p.discountPercent}% off',
                    style: t(15, w: FontWeight.w700, c: HomeColors.green),
                  ),
              ],
            ),
            SizedBox(height: 7 * k),
            line(
              Icons.verified_user_rounded,
              HomeColors.blue,
              p.verified ? 'Verified • $condition' : condition,
            ),
            SizedBox(height: 4 * k),
            line(
              Icons.gpp_good_outlined,
              const Color(0xFF5A6FD0),
              p.warrantyMonths > 0
                  ? '${p.warrantyMonths} Month Warranty'
                  : 'No warranty',
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _Btn(
                    filled: true,
                    onTap: p.inStock ? () => buyNow(context, ref, p) : null,
                    child: FittedBox(
                      child: Text(
                        'Buy Now',
                        style: t(16.5, w: FontWeight.w600, c: Colors.white),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 7 * k),
                SizedBox(
                  width: 46 * k,
                  child: _Btn(
                    filled: false,
                    onTap: p.inStock ? () => addToCart(context, ref, p) : null,
                    child: Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 22 * k,
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
  const _Btn({required this.filled, required this.onTap, required this.child});
  final bool filled;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final enabled = onTap != null;
    return Material(
      color: filled
          ? (enabled ? HomeColors.blue : const Color(0xFF9AA5C4))
          : const Color(0xFFEAF0FF),
      borderRadius: BorderRadius.circular(14 * k),
      child: InkWell(
        borderRadius: BorderRadius.circular(14 * k),
        onTap: onTap,
        child: SizedBox(
          height: 46 * k,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * k),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
