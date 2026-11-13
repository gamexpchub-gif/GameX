import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/models/product.dart';
import 'design_scale.dart';

/// Swipeable hero carousel. No timers or looping animations (smooth on
/// low-end Android). Each page is 417 design-px tall: the card starts 25 px
/// down and the artwork overflows 5 px above the page, exactly like the
/// mockup where the phone pokes out of the card.
class HeroBannerCarousel extends StatefulWidget {
  const HeroBannerCarousel({super.key, required this.banners});
  final List<PromoBanner> banners;

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  final _page = PageController();
  final _index = ValueNotifier<int>(0);

  @override
  void dispose() {
    _page.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      children: [
        SizedBox(
          height: 417 * k,
          child: PageView.builder(
            controller: _page,
            clipBehavior: Clip.none,
            itemCount: widget.banners.length,
            onPageChanged: (i) => _index.value = i,
            itemBuilder: (_, i) =>
                RepaintBoundary(child: _HeroPage(banner: widget.banners[i])),
          ),
        ),
        SizedBox(height: 18 * k),
        ValueListenableBuilder<int>(
          valueListenable: _index,
          builder: (_, i, _) => _Dots(count: widget.banners.length, index: i),
        ),
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
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.5 * k),
            width: i == index ? 26 * k : 10 * k,
            height: 10 * k,
            decoration: BoxDecoration(
              color: i == index ? HomeColors.blue : const Color(0xFFC3D2FA),
              borderRadius: BorderRadius.circular(5 * k),
            ),
          ),
      ],
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.banner});
  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final colors = banner.gradient.map(Color.new).toList();
    final image = banner.image;
    final radius = BorderRadius.circular(40 * k);

    Widget art;
    if (image == null) {
      art = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(colors: colors),
        ),
      );
    } else if (image.startsWith('asset:')) {
      // Artwork includes the phone poking out above the card (5 + 25 px).
      art = Image.asset(
        image.substring(6),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    } else {
      art = ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
      );
    }

    return GestureDetector(
      onTap: banner.link == null ? null : () => context.push(banner.link!),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 35 * k),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Soft shadow under the card.
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
                      color: colors.first.withValues(alpha: 0.18),
                      blurRadius: 26 * k,
                      offset: Offset(0, 10 * k),
                      blurStyle: BlurStyle.outer,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: image != null && image.startsWith('asset:')
                  ? -5 * k
                  : 25 * k,
              height: image != null && image.startsWith('asset:')
                  ? 422 * k
                  : 392 * k,
              child: art,
            ),
            if (banner.title.isNotEmpty)
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
            padding: EdgeInsets.only(left: 2 * k, right: 18 * k),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(23 * k),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/home/icon_certified.png',
                  width: 42 * k,
                  height: 45 * k,
                  filterQuality: FilterQuality.medium,
                ),
                SizedBox(width: 9 * k),
                Text(
                  banner.badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19 * k,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 22 * k),
        Text(
          banner.title,
          maxLines: 3,
          style: TextStyle(
            color: Colors.white,
            fontSize: 44 * k,
            height: 1.13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6 * k,
          ),
        ),
        SizedBox(height: 16 * k),
        Text(
          banner.highlights.join('  •  '),
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.5 * k,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 22 * k),
        Container(
          height: 55 * k,
          padding: EdgeInsets.symmetric(horizontal: 24 * k),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28 * k),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                banner.ctaLabel,
                style: TextStyle(
                  color: HomeColors.blueDeep,
                  fontSize: 19 * k,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 12 * k),
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
