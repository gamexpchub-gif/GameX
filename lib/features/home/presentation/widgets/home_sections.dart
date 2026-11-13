import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/brand_marks.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../data/models/product.dart';
import 'design_scale.dart';

const _assets = 'assets/images/home';

// ───────────────────────────── Feature cards ─────────────────────────────

class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.onTap});
  final ValueChanged<int> onTap;

  static const items = [
    ('verified', '100%', 'Verified'),
    ('battery', 'Long Life', 'Battery'),
    ('support', '24/7', 'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: 17 * k),
            Expanded(
              child: _FeatureCard(
                icon: items[i].$1,
                line1: items[i].$2,
                line2: items[i].$3,
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.line1,
    required this.line2,
    required this.onTap,
  });

  final String icon;
  final String line1;
  final String line2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 26 * k,
        color: dark ? null : HomeColors.cardFill,
        child: SizedBox(
          height: 102 * k,
          child: Row(
            children: [
              SizedBox(width: 16 * k),
              Image.asset(
                '$_assets/feature_$icon.png',
                width: 72 * k,
                height: 72 * k,
                filterQuality: FilterQuality.medium,
              ),
              SizedBox(width: 16 * k),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in [line1, line2])
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          line,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 21 * k,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2 * k,
                            color: dark ? Colors.white : HomeColors.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 32 * k,
                color: dark ? Colors.white70 : HomeColors.inkSoft,
              ),
              SizedBox(width: 6 * k),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Trade-in / EMI ────────────────────────────

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.tradeInUpTo,
    required this.emiFrom,
    required this.onExchange,
    required this.onEmi,
  });

  final double tradeInUpTo;
  final double emiFrom;
  final VoidCallback onExchange;
  final VoidCallback onEmi;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    TextStyle s(double size, FontWeight w) => TextStyle(
      fontSize: size * k,
      fontWeight: w,
      color: HomeColors.ink,
      height: 1.2,
      letterSpacing: -0.2 * k,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: SizedBox(
        height: 220 * k,
        child: Stack(
          children: [
            // Background with the three phones (from the design).
            Positioned.fill(
              child: Image.asset(
                '$_assets/offer_card.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Positioned(
              left: 23 * k,
              top: 26 * k,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trade-In Your Old Phone',
                    style: s(22.5, FontWeight.w600),
                  ),
                  SizedBox(height: 7 * k),
                  Text('Get Up to', style: s(22, FontWeight.w400)),
                  SizedBox(height: 7 * k),
                  Text(
                    '${formatPrice(tradeInUpTo)} Off',
                    style: s(31, FontWeight.w700),
                  ),
                  SizedBox(height: 18 * k),
                  _PillButton(
                    label: 'Exchange Now',
                    width: 193 * k,
                    height: 49 * k,
                    filled: true,
                    onTap: onExchange,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 623 * k,
              top: 26 * k,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart EMI', style: s(22.5, FontWeight.w700)),
                  SizedBox(height: 7 * k),
                  Text('Starts From', style: s(22, FontWeight.w400)),
                  SizedBox(height: 7 * k),
                  Text.rich(
                    TextSpan(
                      text: formatPrice(emiFrom),
                      children: [
                        TextSpan(text: ' /mo', style: s(27, FontWeight.w600)),
                      ],
                    ),
                    style: s(29, FontWeight.w700),
                  ),
                  SizedBox(height: 20 * k),
                  _PillButton(
                    label: 'Check EMI',
                    width: 148 * k,
                    height: 47 * k,
                    filled: false,
                    onTap: onEmi,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.width,
    required this.height,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final double width;
  final double height;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fg = filled ? Colors.white : HomeColors.ink;
    return Material(
      color: filled ? HomeColors.blue : Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 17.5 * k,
                  fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              SizedBox(width: 8 * k),
              Icon(Icons.arrow_forward_rounded, size: 21 * k, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Section title ─────────────────────────────

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });
  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: 6 * k)],
          Text(
            title,
            style: TextStyle(
              fontSize: 31 * k,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5 * k,
              color: dark ? Colors.white : HomeColors.ink,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class SeeAllButton extends StatelessWidget {
  const SeeAllButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8 * k, 6 * k, 10 * k, 6 * k),
        child: Row(
          children: [
            Text(
              'See All',
              style: TextStyle(
                fontSize: 22 * k,
                fontWeight: FontWeight.w500,
                color: HomeColors.blue,
              ),
            ),
            SizedBox(width: 12 * k),
            Icon(
              Icons.arrow_forward_rounded,
              size: 27 * k,
              color: HomeColors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Brands ─────────────────────────────

class BrandStrip extends StatelessWidget {
  const BrandStrip({
    super.key,
    required this.brands,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> brands;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: 108 * k,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: 36 * k),
        itemCount: brands.length,
        separatorBuilder: (_, _) => SizedBox(width: 17 * k),
        itemBuilder: (_, i) {
          final b = brands[i];
          final active = b.id == selected;
          return GestureDetector(
            onTap: () => onSelect(b.id),
            child: Container(
              width: 128 * k,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFCFE),
                borderRadius: BorderRadius.circular(24 * k),
                border: Border.all(
                  color: active ? HomeColors.blue : Colors.white,
                  width: active ? 2.6 * k : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2A3D8F).withValues(alpha: 0.07),
                    blurRadius: 16,
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandLogo(b.icon, width: 104 * k, height: 60 * k),
                  SizedBox(height: 2 * k),
                  Text(
                    b.name,
                    style: TextStyle(
                      fontSize: 19.5 * k,
                      height: 1.1,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? HomeColors.blue : HomeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Countdown ─────────────────────────────

/// "Ends in 12 : 24 : 36". Only this small widget rebuilds each second.
class DealCountdown extends StatefulWidget {
  const DealCountdown({super.key});

  @override
  State<DealCountdown> createState() => _DealCountdownState();
}

class _DealCountdownState extends State<DealCountdown> {
  late final Timer _timer;
  Duration _left = _remaining();

  static Duration _remaining() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1).difference(now);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _left = _remaining()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    String two(int n) => n.toString().padLeft(2, '0');
    final digit = TextStyle(
      fontSize: 19 * k,
      color: HomeColors.red,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget box(String v) => Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * k, vertical: 1 * k),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6 * k),
      ),
      child: Text(v, style: digit),
    );
    Widget colon() => Padding(
      padding: EdgeInsets.symmetric(horizontal: 3 * k),
      child: Text(':', style: digit),
    );
    return RepaintBoundary(
      child: Container(
        height: 40 * k,
        padding: EdgeInsets.only(left: 14 * k, right: 12 * k),
        decoration: BoxDecoration(
          color: const Color(0xFFFDE5E8),
          borderRadius: BorderRadius.circular(20 * k),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_rounded, size: 27 * k, color: HomeColors.red),
            SizedBox(width: 8 * k),
            Text(
              'Ends in',
              style: TextStyle(
                fontSize: 18 * k,
                color: HomeColors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 10 * k),
            box(two(_left.inHours)),
            colon(),
            box(two(_left.inMinutes % 60)),
            colon(),
            box(two(_left.inSeconds % 60)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Deal card ─────────────────────────────

String compactCount(int n) {
  if (n >= 1000) {
    final v = (n / 100).round() / 10;
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return '${s}k';
  }
  return '$n';
}

class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.product,
    required this.wished,
    required this.onTap,
    required this.onWish,
    required this.onAddToCart,
    this.ribbon,
  });

  final Product product;
  final bool wished;
  final VoidCallback onTap;
  final VoidCallback onWish;
  final VoidCallback? onAddToCart;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final p = product;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : HomeColors.ink;
    // images[1] is the wide front+back "deal" shot when available.
    final image = p.images.length > 1 && p.images[1].startsWith('asset:')
        ? p.images[1]
        : p.images.first;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: 30 * k,
          color: dark ? null : Colors.white.withValues(alpha: 0.92),
          child: SizedBox(
            height: 278 * k,
            child: Row(
              children: [
                SizedBox(
                  width: 260 * k,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AppImage(
                          image,
                          borderRadius: BorderRadius.circular(26 * k),
                        ),
                      ),
                      if (ribbon != null) _Ribbon(text: ribbon!),
                      Positioned(
                        right: 10 * k,
                        top: 12 * k,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onWish,
                          child: Padding(
                            padding: EdgeInsets.all(6 * k),
                            child: Icon(
                              wished
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 38 * k,
                              color: wished
                                  ? HomeColors.red
                                  : const Color(0xFF5B6688),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 28 * k),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 9 * k,
                      top: 18 * k,
                      bottom: 4 * k,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 28 * k,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3 * k,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 8 * k),
                        if (p.variant != null)
                          Text(
                            p.variant!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19.5 * k,
                              height: 1.15,
                              color: dark ? Colors.white70 : HomeColors.muted,
                            ),
                          ),
                        SizedBox(height: 12 * k),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 27 * k,
                              color: const Color(0xFFF7B500),
                            ),
                            SizedBox(width: 6 * k),
                            Text(
                              p.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 19 * k,
                                fontWeight: FontWeight.w500,
                                color: HomeColors.amber,
                              ),
                            ),
                            SizedBox(width: 6 * k),
                            Text(
                              '(${compactCount(p.reviewCount)} reviews)',
                              style: TextStyle(
                                fontSize: 18.5 * k,
                                color: HomeColors.grey,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14 * k),
                        Row(
                          children: [
                            Text(
                              formatPrice(p.price),
                              style: TextStyle(
                                fontSize: 33 * k,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4 * k,
                                color: ink,
                              ),
                            ),
                            SizedBox(width: 16 * k),
                            if (p.oldPrice != null)
                              Text(
                                formatPrice(p.oldPrice!),
                                style: TextStyle(
                                  fontSize: 22 * k,
                                  color: const Color(0xFF6B7591),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: const Color(0xFF6B7591),
                                ),
                              ),
                            SizedBox(width: 14 * k),
                            if (p.discountPercent > 0)
                              Container(
                                height: 38 * k,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15 * k,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: HomeColors.greenBg,
                                  borderRadius: BorderRadius.circular(19 * k),
                                ),
                                child: Text(
                                  '${p.discountPercent}% OFF',
                                  style: TextStyle(
                                    fontSize: 20 * k,
                                    fontWeight: FontWeight.w700,
                                    color: HomeColors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 14 * k),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            spacing: 9 * k,
                            children: [
                              if (p.verified)
                                const _Chip(
                                  icon: Icons.verified_user_rounded,
                                  iconColor: HomeColors.blue,
                                  label: 'Verified',
                                ),
                              if (p.condition != null)
                                _Chip(
                                  icon: Icons.diamond_outlined,
                                  iconColor: const Color(0xFF5A6FD0),
                                  label: p.condition!,
                                ),
                              if (p.warrantyMonths > 0)
                                _Chip(
                                  icon: Icons.gpp_good_outlined,
                                  iconColor: const Color(0xFF5A6FD0),
                                  label: '${p.warrantyMonths} Month Warranty',
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _AddToCartButton(onTap: onAddToCart),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Positioned(
      left: -4 * k,
      top: -4 * k,
      width: 140 * k,
      height: 140 * k,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: -52 * k,
              top: 30 * k,
              child: Transform.rotate(
                angle: -0.785,
                child: Container(
                  width: 200 * k,
                  height: 36 * k,
                  alignment: Alignment.center,
                  color: HomeColors.blue,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.5 * k,
                      fontWeight: FontWeight.w600,
                    ),
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      height: 33 * k,
      padding: EdgeInsets.symmetric(horizontal: 11 * k),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF0FF),
        borderRadius: BorderRadius.circular(17 * k),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20 * k, color: iconColor),
          SizedBox(width: 7 * k),
          Text(
            label,
            style: TextStyle(
              fontSize: 15.5 * k,
              color: HomeColors.inkSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final enabled = onTap != null;
    return Material(
      color: enabled ? HomeColors.blue : const Color(0xFF9AA5C4),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 331 * k,
          height: 52 * k,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 29 * k,
                color: Colors.white,
              ),
              SizedBox(width: 12 * k),
              Text(
                enabled ? 'Add to Cart' : 'Out of Stock',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21 * k,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
