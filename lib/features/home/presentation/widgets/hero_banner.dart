import 'dart:async';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/phone_art.dart';
import '../../../../data/models/product.dart';
import 'design_scale.dart';

/// Auto-sliding hero carousel. Each page reserves 25 design-px above the
/// card; the phone illustration breaks out of the card (and 5 px above the
/// page) like the mockup.
class HeroBannerCarousel extends StatefulWidget {
  const HeroBannerCarousel({super.key, required this.banners});
  final List<PromoBanner> banners;

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel>
    with SingleTickerProviderStateMixin {
  final _page = PageController();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  Timer? _auto;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartAuto();
  }

  void _restartAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!_page.hasClients || widget.banners.length < 2) return;
      _page.animateToPage(
        (_index + 1) % widget.banners.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _float.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      children: [
        SizedBox(
          height: 417 * k,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _restartAuto();
              return false;
            },
            child: PageView.builder(
              controller: _page,
              clipBehavior: Clip.none,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) =>
                  _HeroPage(banner: widget.banners[i], float: _float),
            ),
          ),
        ),
        SizedBox(height: 18 * k),
        _Dots(count: widget.banners.length, index: _index),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            margin: EdgeInsets.symmetric(horizontal: 5 * k),
            width: i == index ? 26 * k : 10 * k,
            height: 10 * k,
            decoration: BoxDecoration(
              color: i == index ? HomeColors.blue : const Color(0xFFC5D2F7),
              borderRadius: BorderRadius.circular(5 * k),
            ),
          ),
      ],
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.banner, required this.float});
  final PromoBanner banner;
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final radius = BorderRadius.circular(40 * k);
    final colors = banner.gradient.map(Color.new).toList();
    final spec = PhoneArtSpec.tryParse(banner.art);
    final hasImage = banner.image != null;
    final phoneColor = spec?.color ?? const Color(0xFF5B3E96);

    return GestureDetector(
      onTap: banner.link == null ? null : () => context.push(banner.link!),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 35 * k),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Card background (clipped).
            Positioned(
              left: 0,
              right: 0,
              top: 25 * k,
              height: 392 * k,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.22),
                      blurRadius: 30 * k,
                      offset: Offset(0, 12 * k),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: hasImage
                      ? AppImage(banner.image!)
                      : _CardBackdrop(colors: colors, phoneColor: phoneColor),
                ),
              ),
            ),
            // 2. Hero phone breaking out of the card.
            if (!hasImage)
              Positioned(
                left: 330 * k,
                top: -5 * k,
                width: 452 * k,
                height: 422 * k,
                child: AnimatedBuilder(
                  animation: float,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      math.sin(float.value * math.pi * 2) * 7 * k,
                    ),
                    child: child,
                  ),
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(0.42)
                        ..rotateX(-0.08)
                        ..rotateZ(0.3),
                      child: PhoneShape(color: phoneColor, height: 430 * k),
                    ),
                  ),
                ),
              ),
            // 3. Glass ring, kept inside the card.
            if (!hasImage)
              Positioned(
                left: 0,
                right: 0,
                top: 25 * k,
                height: 392 * k,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 345 * k,
                          top: 165 * k,
                          width: 460 * k,
                          height: 230 * k,
                          child: AnimatedBuilder(
                            animation: float,
                            builder: (_, _) => CustomPaint(
                              painter: GlassRingPainter(float.value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 4. Copy + CTA.
            if (!hasImage)
              Positioned(
                left: 37 * k,
                top: 64 * k,
                width: 360 * k,
                child: _BannerCopy(banner: banner),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardBackdrop extends StatelessWidget {
  const _CardBackdrop({required this.colors, required this.phoneColor});
  final List<Color> colors;
  final Color phoneColor;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        // Light bloom behind the phone.
        Positioned(
          right: -80 * k,
          top: -40 * k,
          width: 520 * k,
          height: 520 * k,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF9DBBFF).withValues(alpha: 0.55),
                  const Color(0xFF5D86FF).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Light streaks.
        CustomPaint(painter: _StreaksPainter()),
        // Second phone peeking from the right edge.
        Positioned(
          right: -150 * k,
          top: -40 * k,
          child: Transform.rotate(
            angle: 0.32,
            child: Opacity(
              opacity: 0.9,
              child: PhoneShape(
                color: phoneColor,
                height: 430 * k,
                front: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.003
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.004);
    for (var i = 0; i < 4; i++) {
      p.color = Colors.white.withValues(alpha: 0.16 - i * 0.03);
      final path = Path()
        ..moveTo(size.width * 0.38, size.height * (1.05 - i * 0.07))
        ..quadraticBezierTo(
          size.width * 0.7,
          size.height * (0.5 - i * 0.08),
          size.width * 1.05,
          size.height * (0.15 + i * 0.05),
        );
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_StreaksPainter oldDelegate) => false;
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.banner});
  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (banner.badge.isNotEmpty)
          Container(
            height: 46 * k,
            padding: EdgeInsets.only(left: 3 * k, right: 18 * k),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(23 * k),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 40 * k,
                  color: const Color(0xFF22C55E),
                ),
                SizedBox(width: 10 * k),
                Text(
                  banner.badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19.5 * k,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 24 * k),
        Text(
          banner.title,
          maxLines: 3,
          style: TextStyle(
            color: Colors.white,
            fontSize: 46 * k,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 18 * k),
        Text(
          banner.highlights.join('  •  '),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 21.5 * k,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 24 * k),
        Container(
          height: 55 * k,
          padding: EdgeInsets.symmetric(horizontal: 24 * k),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28 * k),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14 * k,
                offset: Offset(0, 6 * k),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                banner.ctaLabel,
                style: TextStyle(
                  color: HomeColors.blueDeep,
                  fontSize: 19.5 * k,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 10 * k),
              Icon(
                Icons.arrow_forward_rounded,
                size: 24 * k,
                color: HomeColors.blueDeep,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
