import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/brand_marks.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/phone_art.dart';
import '../../../../data/models/product.dart';
import 'design_scale.dart';

// ───────────────────────────── Feature cards ─────────────────────────────

class FeatureItem {
  const FeatureItem(
    this.icon,
    this.iconColor,
    this.tint,
    this.line1,
    this.line2,
  );
  final IconData icon;
  final Color iconColor;
  final Color tint;
  final String line1;
  final String line2;
}

class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.onTap});
  final ValueChanged<int> onTap;

  static const items = [
    FeatureItem(
      Icons.verified_user_rounded,
      Color(0xFF1F4FEA),
      Color(0xFFDDE6FF),
      '100%',
      'Verified',
    ),
    FeatureItem(
      Icons.battery_full_rounded,
      Color(0xFF22B455),
      Color(0xFFD9F5E3),
      'Long Life',
      'Battery',
    ),
    FeatureItem(
      Icons.headset_mic_rounded,
      Color(0xFF1F4FEA),
      Color(0xFFDDE6FF),
      '24/7',
      'Support',
    ),
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
              child: _FeatureCard(item: items[i], onTap: () => onTap(i)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, required this.onTap});
  final FeatureItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 26 * k,
        opacity: 0.6,
        child: SizedBox(
          height: 102 * k,
          child: Row(
            children: [
              SizedBox(width: 18 * k),
              Container(
                width: 70 * k,
                height: 70 * k,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [item.tint.withValues(alpha: 0.6), item.tint],
                  ),
                ),
                child: Icon(item.icon, size: 40 * k, color: item.iconColor),
              ),
              SizedBox(width: 16 * k),
              Expanded(
                child: Text(
                  '${item.line1}\n${item.line2}',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 21 * k,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : HomeColors.ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 32 * k,
                color: dark ? Colors.white70 : HomeColors.inkSoft,
              ),
              SizedBox(width: 12 * k),
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
    const ink = HomeColors.ink;
    TextStyle s(double size, FontWeight w) =>
        TextStyle(fontSize: size * k, fontWeight: w, color: ink, height: 1.25);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: Container(
        height: 220 * k,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30 * k),
          gradient: const LinearGradient(
            colors: [Color(0xFFE8ECFF), Color(0xFFDCE2FF), Color(0xFFE4E3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B3E9E).withValues(alpha: 0.07),
              blurRadius: 26 * k,
              blurStyle: BlurStyle.outer,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Trade-in copy.
            Positioned(
              left: 23 * k,
              top: 25 * k,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trade-In Your Old Phone',
                    style: s(22.5, FontWeight.w700),
                  ),
                  SizedBox(height: 6 * k),
                  Text('Get Up to', style: s(22, FontWeight.w400)),
                  SizedBox(height: 6 * k),
                  Text(
                    '${formatPrice(tradeInUpTo)} Off',
                    style: s(31, FontWeight.w800),
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
            // Three phones + exchange arrows.
            Positioned(
              left: 362 * k,
              top: 8 * k,
              width: 245 * k,
              height: 205 * k,
              child: const _TradePhones(),
            ),
            // EMI copy.
            Positioned(
              left: 612 * k,
              top: 25 * k,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart EMI', style: s(22.5, FontWeight.w800)),
                  SizedBox(height: 6 * k),
                  Text('Starts From', style: s(22, FontWeight.w400)),
                  SizedBox(height: 6 * k),
                  Text.rich(
                    TextSpan(
                      text: formatPrice(emiFrom),
                      children: [
                        TextSpan(text: ' /mo', style: s(27, FontWeight.w700)),
                      ],
                    ),
                    style: s(29, FontWeight.w800),
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

class _TradePhones extends StatelessWidget {
  const _TradePhones();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final h = 178 * k;
    Widget phone(double left, double top, double angle, Color c) => Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: PhoneShape(color: c, height: h),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        phone(40 * k, 8 * k, -0.06, const Color(0xFFB9BEC9)),
        phone(95 * k, 2 * k, 0, const Color(0xFF2B2E36)),
        phone(152 * k, 6 * k, 0.06, const Color(0xFF7B5BC7)),
        // Exchange arrows badge.
        Positioned(
          left: 76 * k,
          top: 100 * k,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF21C26B), Color(0xFFC6E33A), Color(0xFFF7C934)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ).createShader(r),
            child: Icon(Icons.sync_rounded, size: 90 * k),
          ),
        ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: filled
              ? const LinearGradient(
                  colors: [Color(0xFF2B5DFF), Color(0xFF1543D8)],
                )
              : null,
          color: filled ? null : Colors.white,
          boxShadow: [
            BoxShadow(
              color: (filled ? const Color(0xFF1F4FEA) : Colors.black)
                  .withValues(alpha: filled ? 0.3 : 0.06),
              blurRadius: 14 * k,
              offset: Offset(0, 6 * k),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 17.5 * k,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            SizedBox(width: 8 * k),
            Icon(Icons.arrow_forward_rounded, size: 21 * k, color: fg),
          ],
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
          if (leading != null) ...[leading!, SizedBox(width: 8 * k)],
          Text(
            title,
            style: TextStyle(
              fontSize: 31 * k,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
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
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6 * k),
        child: Row(
          children: [
            Text(
              'See All',
              style: TextStyle(
                fontSize: 22 * k,
                fontWeight: FontWeight.w600,
                color: HomeColors.blue,
              ),
            ),
            SizedBox(width: 10 * k),
            Icon(
              Icons.arrow_forward_rounded,
              size: 26 * k,
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
      height: 112 * k,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: 36 * k, vertical: 3 * k),
        itemCount: brands.length,
        separatorBuilder: (_, _) => SizedBox(width: 17 * k),
        itemBuilder: (_, i) {
          final b = brands[i];
          final active = b.id == selected;
          return GestureDetector(
            onTap: () => onSelect(b.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 128 * k,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24 * k),
                border: Border.all(
                  color: active ? HomeColors.blue : Colors.transparent,
                  width: 2.4 * k,
                ),
              ),
              child: Glass(
                radius: 22 * k,
                opacity: active ? 0.85 : 0.6,
                borderColor: active ? Colors.transparent : null,
                shadow: !active,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 50 * k,
                      child: Center(child: BrandMark(b.icon, size: 46 * k)),
                    ),
                    SizedBox(height: 10 * k),
                    Text(
                      b.name,
                      style: TextStyle(
                        fontSize: 19.5 * k,
                        fontWeight: FontWeight.w600,
                        color: active ? HomeColors.blue : HomeColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Countdown ─────────────────────────────

class DealCountdown extends StatefulWidget {
  const DealCountdown({super.key});

  @override
  State<DealCountdown> createState() => _DealCountdownState();
}

class _DealCountdownState extends State<DealCountdown> {
  late Timer _timer;
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
    final time =
        '${two(_left.inHours)} : ${two(_left.inMinutes % 60)} : ${two(_left.inSeconds % 60)}';
    return Container(
      height: 40 * k,
      padding: EdgeInsets.symmetric(horizontal: 14 * k),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E6).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20 * k),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 26 * k, color: HomeColors.red),
          SizedBox(width: 8 * k),
          Text(
            'Ends in  ',
            style: TextStyle(
              fontSize: 18 * k,
              color: HomeColors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 19 * k,
              color: HomeColors.red,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Deal card ─────────────────────────────

String compactCount(int n) {
  if (n >= 1000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 1 : 1).replaceAll('.0', '')}k';
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
    final spec = PhoneArtSpec.tryParse(p.images.first);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * k),
      child: GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: 30 * k,
          opacity: 0.72,
          child: SizedBox(
            height: 284 * k,
            child: Row(
              children: [
                // Image panel.
                SizedBox(
                  width: 260 * k,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28 * k),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFF4F6FB), Color(0xFFE6EAF4)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: spec == null
                                ? null
                                : Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      18 * k,
                                      22 * k,
                                      10 * k,
                                      6 * k,
                                    ),
                                    child: PhoneArt(
                                      spec: PhoneArtSpec(spec.color, 'duo'),
                                      background: false,
                                    ),
                                  ),
                          ),
                        ),
                        if (ribbon != null) _Ribbon(text: ribbon!),
                        Positioned(
                          right: 12 * k,
                          top: 16 * k,
                          child: GestureDetector(
                            onTap: onWish,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (c, a) =>
                                  ScaleTransition(scale: a, child: c),
                              child: Icon(
                                wished
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(wished),
                                size: 34 * k,
                                color: wished
                                    ? HomeColors.red
                                    : const Color(0xFF6B7591),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 28 * k),
                // Details.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 9 * k,
                      top: 18 * k,
                      bottom: 12 * k,
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
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 4 * k),
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
                        SizedBox(height: 8 * k),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 26 * k,
                              color: const Color(0xFFF5B400),
                            ),
                            SizedBox(width: 6 * k),
                            Text(
                              p.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 19 * k,
                                fontWeight: FontWeight.w600,
                                color: HomeColors.amber,
                              ),
                            ),
                            Text(
                              ' (${compactCount(p.reviewCount)} reviews)',
                              style: TextStyle(
                                fontSize: 18.5 * k,
                                color: const Color(0xFF8A93AD),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12 * k),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              formatPrice(p.price),
                              style: TextStyle(
                                fontSize: 33 * k,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(width: 14 * k),
                            if (p.oldPrice != null)
                              Text(
                                formatPrice(p.oldPrice!),
                                style: TextStyle(
                                  fontSize: 22 * k,
                                  color: const Color(0xFF8A93AD),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: const Color(0xFF8A93AD),
                                ),
                              ),
                            const Spacer(),
                            if (p.discountPercent > 0)
                              Container(
                                height: 38 * k,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14 * k,
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
                                    fontWeight: FontWeight.w800,
                                    color: HomeColors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 12 * k),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            spacing: 8 * k,
                            children: [
                              if (p.verified)
                                _Chip(
                                  icon: Icons.verified_user_rounded,
                                  iconColor: HomeColors.blue,
                                  label: 'Verified',
                                ),
                              if (p.condition != null)
                                _Chip(
                                  icon: Icons.diamond_outlined,
                                  iconColor: const Color(0xFF6C7CC9),
                                  label: p.condition!,
                                ),
                              if (p.warrantyMonths > 0)
                                _Chip(
                                  icon: Icons.shield_outlined,
                                  iconColor: const Color(0xFF6C7CC9),
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
      left: -44 * k,
      top: 22 * k,
      child: Transform.rotate(
        angle: -0.785,
        child: Container(
          width: 200 * k,
          height: 34 * k,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2B5DFF), Color(0xFF1543D8)],
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18 * k,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      height: 32 * k,
      padding: EdgeInsets.symmetric(horizontal: 10 * k),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8 * k),
        border: Border.all(color: const Color(0xFFE3E7F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19 * k, color: iconColor),
          SizedBox(width: 6 * k),
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

class _AddToCartButton extends StatefulWidget {
  const _AddToCartButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 331 * k,
          height: 52 * k,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26 * k),
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFF2B5DFF), Color(0xFF1543D8)]
                  : const [Color(0xFFA3AEC9), Color(0xFF8D97B3)],
            ),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: const Color(0xFF1F4FEA).withValues(alpha: 0.22),
                  blurRadius: 14 * k,
                  offset: Offset(0, 4 * k),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 28 * k,
                color: Colors.white,
              ),
              SizedBox(width: 12 * k),
              Text(
                enabled ? 'Add to Cart' : 'Out of Stock',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21 * k,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
