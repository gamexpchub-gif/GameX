import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../trust/presentation/product_trust_card.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/review.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../catalog/providers/catalog_providers.dart';
import '../../../checkout/presentation/widgets/address_sheets.dart';
import '../../../checkout/providers/address_provider.dart';
import '../../../home/presentation/widgets/design_scale.dart' show HomeColors;
import '../../../home/presentation/widgets/home_sheets.dart';
import '../../../reviews/providers/reviews_provider.dart';
import '../../../live_review/providers/live_review_provider.dart';
import 'pdp_sheets.dart';
import 'review_widgets.dart';

const _img = 'assets/images/home';

/// Everything below the colour / storage pickers on the product page.
/// Sizes are design px of the 887-px mockup grid.
class PdpSections extends ConsumerStatefulWidget {
  const PdpSections({
    super.key,
    required this.product,
    required this.price,
    required this.variantLabel,
    this.heroVariant,
    this.highlightsKey,
    this.specsKey,
    this.reviewsKey,
  });

  /// Anchors for the quick links at the top of the page.
  final GlobalKey? highlightsKey;
  final GlobalKey? specsKey;
  final GlobalKey? reviewsKey;

  final Product product;
  final double price;
  final String variantLabel;

  /// iPhone studio photo variant for the selected colour.
  final String? heroVariant;

  @override
  ConsumerState<PdpSections> createState() => _PdpSectionsState();
}

class _PdpSectionsState extends ConsumerState<PdpSections> {
  bool _aboutOpen = false;
  bool _specsOpen = false;

  Product get p => widget.product;
  double get d => MediaQuery.sizeOf(context).width / 887;

  TextStyle get _h => TextStyle(
    fontSize: 34 * d,
    fontWeight: FontWeight.w800,
    color: HomeColors.ink,
    letterSpacing: -0.4 * d,
  );
  TextStyle get _t => TextStyle(
    fontSize: 26 * d,
    fontWeight: FontWeight.w700,
    color: HomeColors.ink,
  );
  TextStyle get _s =>
      TextStyle(fontSize: 21 * d, color: HomeColors.muted, height: 1.35);

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 19 * d),
    child: Glass(
      radius: 32 * d,
      color: Colors.white.withValues(alpha: 0.9),
      padding: padding ?? EdgeInsets.fromLTRB(30 * d, 28 * d, 30 * d, 28 * d),
      child: child,
    ),
  );

  Widget _title(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 38 * d, color: HomeColors.blue),
      SizedBox(width: 16 * d),
      Expanded(child: Text(text, style: _h)),
    ],
  );

  Widget _wideButton(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 74 * d,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EDFF),
        borderRadius: BorderRadius.circular(37 * d),
      ),
      child: Row(
        children: [
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 24 * d,
              fontWeight: FontWeight.w700,
              color: HomeColors.blue,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            size: 36 * d,
            color: HomeColors.blue,
          ),
          SizedBox(width: 24 * d),
        ],
      ),
    ),
  );

  Widget get _gap => SizedBox(height: 26 * d);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _conditionCard(),
        _gap,
        if (p.isMarketplace) ...[ProductTrustCard(product: p), _gap],
        _liveCard(),
        _gap,
        _deliverTo(),
        SizedBox(height: 14 * d),
        _freeDelivery(),
        _gap,
        _certified(),
        _gap,
        KeyedSubtree(key: widget.highlightsKey, child: _highlights()),
        _gap,
        _overviewVideo(),
        _gap,
        _about(),
        _gap,
        KeyedSubtree(key: widget.specsKey, child: _specs()),
        _gap,
        _inTheBox(),
        _gap,
        KeyedSubtree(key: widget.reviewsKey, child: _ratings()),
        _gap,
        _qa(),
        _gap,
        _similar(),
        _gap,
        _exchange(),
        SizedBox(height: 34 * d),
        _trust(),
      ],
    );
  }

  // ── Condition ──
  Widget _conditionCard() {
    final grade = (p.condition ?? 'Excellent').replaceAll(' Condition', '');
    const grades = ['Good', 'Excellent', 'Like New'];
    final gi = grades.indexOf(grade).clamp(0, 2);
    final battery = p.batteryHealth == 0 ? 90 : p.batteryHealth;
    final rows = [
      (
        Icons.smartphone_rounded,
        'Screen',
        gi == 0 ? 'Flawless, no dead pixels' : 'Flawless, like new',
      ),
      (
        Icons.crop_square_rounded,
        'Body',
        switch (gi) {
          2 => 'No visible marks',
          1 => 'Micro-scratches, invisible at arm\'s length',
          _ => 'Light visible wear on frame',
        },
      ),
      (
        Icons.battery_charging_full_rounded,
        'Battery health',
        '$battery% of original capacity',
      ),
      (Icons.check_circle_outline_rounded, 'Functions', 'All 52 checks passed'),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.diamond_outlined,
                size: 38 * d,
                color: HomeColors.blue,
              ),
              SizedBox(width: 16 * d),
              Expanded(child: Text('Condition', style: _h)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 18 * d,
                  vertical: 8 * d,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F66FF), Color(0xFF6A3DF5)],
                  ),
                  borderRadius: BorderRadius.circular(20 * d),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 21 * d,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 22 * d),
          Row(
            children: [
              for (var i = 0; i < grades.length; i++) ...[
                if (i > 0) SizedBox(width: 10 * d),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 12 * d,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6 * d),
                          color: i <= gi ? null : const Color(0xFFE6EBF7),
                          gradient: i <= gi
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF1F66FF),
                                    Color(0xFF6A3DF5),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      SizedBox(height: 8 * d),
                      Text(
                        grades[i],
                        style: TextStyle(
                          fontSize: 19 * d,
                          fontWeight: i == gi
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i == gi ? HomeColors.ink : HomeColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 18 * d),
          for (final r in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10 * d),
              child: Row(
                children: [
                  Container(
                    width: 56 * d,
                    height: 56 * d,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3FF),
                      borderRadius: BorderRadius.circular(16 * d),
                    ),
                    child: Icon(r.$1, size: 30 * d, color: HomeColors.blue),
                  ),
                  SizedBox(width: 18 * d),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$2, style: _t.copyWith(fontSize: 22 * d)),
                        Text(r.$3, style: _s),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 30 * d,
                    color: HomeColors.green,
                  ),
                ],
              ),
            ),
          SizedBox(height: 10 * d),
          _wideButton(
            'View Full Condition Report',
            () => showConditionReport(context, p),
          ),
        ],
      ),
    );
  }

  // ── Live review ──
  Widget _liveCard() {
    final req = ref
        .watch(liveRequestsProvider)
        .where(
          (r) => r.active && productKeyOf(r.productId) == productKeyOf(p.id),
        )
        .firstOrNull;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: GestureDetector(
        onTap: () => context.push('/live-review/${p.id}'),
        child: Container(
          padding: EdgeInsets.all(30 * d),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32 * d),
            gradient: const LinearGradient(
              colors: [Color(0xFF0E1033), Color(0xFF2A1466), Color(0xFF5B1E8F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * d,
                      vertical: 6 * d,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5283B),
                      borderRadius: BorderRadius.circular(10 * d),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 11 * d,
                          height: 11 * d,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8 * d),
                        Text(
                          'LIVE REVIEW',
                          style: TextStyle(
                            fontSize: 17 * d,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Free • 10 min',
                    style: TextStyle(fontSize: 19 * d, color: Colors.white70),
                  ),
                ],
              ),
              SizedBox(height: 18 * d),
              Text(
                'See this exact phone live',
                style: TextStyle(
                  fontSize: 34 * d,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8 * d),
              Text(
                'A GAMEX expert shows you this unit on a video call — IMEI, battery health, screen and every scratch — before you buy.',
                style: TextStyle(
                  fontSize: 21 * d,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(height: 22 * d),
              Container(
                height: 70 * d,
                decoration: BoxDecoration(
                  color: req == null ? Colors.white : const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(35 * d),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      req == null
                          ? Icons.videocam_rounded
                          : Icons.event_available_rounded,
                      size: 32 * d,
                      color: req == null
                          ? const Color(0xFFE5283B)
                          : Colors.white,
                    ),
                    SizedBox(width: 12 * d),
                    Text(
                      req == null
                          ? 'Request Live View'
                          : 'Scheduled • ${DateFormat('EEE d MMM, h:mm a').format(req.slot)}',
                      style: TextStyle(
                        fontSize: 22 * d,
                        fontWeight: FontWeight.w800,
                        color: req == null ? HomeColors.ink : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delivery ──
  Widget _deliverTo() {
    final a = ref.watch(addressBookProvider).current;
    return _card(
      padding: EdgeInsets.symmetric(horizontal: 28 * d, vertical: 22 * d),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 42 * d,
            color: HomeColors.blue,
          ),
          SizedBox(width: 18 * d),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a == null
                      ? 'Select delivery location'
                      : 'Deliver to ${a.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t.copyWith(fontSize: 24 * d),
                ),
                Text(
                  a == null
                      ? 'Add your address to see delivery date'
                      : '${a.details}, ${a.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _s,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => a == null
                ? showAddressForm(context)
                : showAddressPicker(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 22 * d,
                vertical: 10 * d,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EDFF),
                borderRadius: BorderRadius.circular(22 * d),
              ),
              child: Text(
                a == null ? 'Add' : 'Change',
                style: TextStyle(
                  fontSize: 22 * d,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _freeDelivery() {
    final city = ref.watch(addressBookProvider).current?.city ?? 'Mumbai';
    final eta = DateTime.now().add(
      Duration(days: kMetroCities.contains(city) ? 2 : 4),
    );
    final free = widget.price >= CartSummary.freeDeliveryThreshold;
    return _card(
      padding: EdgeInsets.symmetric(horizontal: 28 * d, vertical: 20 * d),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_rounded,
            size: 46 * d,
            color: HomeColors.green,
          ),
          SizedBox(width: 18 * d),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: free
                        ? 'FREE Delivery '
                        : 'Delivery ${formatPrice(CartSummary.standardDelivery)} ',
                    children: [
                      if (free)
                        TextSpan(
                          text: formatPrice(CartSummary.standardDelivery),
                          style: TextStyle(
                            color: HomeColors.grey,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: HomeColors.grey,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 24 * d,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.green,
                  ),
                ),
                Text(
                  'Delivery by ${DateFormat('EEE, d MMM').format(eta)}',
                  style: _s,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 38 * d,
            color: HomeColors.blue,
          ),
        ],
      ),
    );
  }

  // ── GAMEX Certified ──
  Widget _certified() {
    final battery = p.batteryHealth == 0 ? 90 : p.batteryHealth;
    final checks = [
      'Battery Health $battery%',
      'Display & Touch - 100%',
      'Camera - Verified',
      'All Functions - Working',
    ];
    final cam = widget.heroVariant;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: GestureDetector(
        onTap: () => showConditionReport(context, p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32 * d),
          child: Container(
            height: 410 * d,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0E1033),
                  Color(0xFF2A1466),
                  Color(0xFF5B2DB8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                if (cam != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 360 * d,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Colors.transparent, Colors.black],
                        stops: [0, 0.45],
                      ).createShader(r),
                      child: Image.asset(
                        '$_img/pdp_cam_$cam.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(32 * d, 30 * d, 24 * d, 26 * d),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            '$_img/icon_certified.png',
                            width: 76 * d,
                            height: 80 * d,
                          ),
                          SizedBox(width: 18 * d),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GAMEX Certified',
                                style: TextStyle(
                                  fontSize: 36 * d,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Tested  •  Verified  •  Trusted',
                                style: TextStyle(
                                  fontSize: 21 * d,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      for (final c in checks)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12 * d),
                          child: Row(
                            children: [
                              Container(
                                width: 32 * d,
                                height: 32 * d,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 22 * d,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 16 * d),
                              Text(
                                c,
                                style: TextStyle(
                                  fontSize: 24 * d,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        'Tap to view full condition report  ›',
                        style: TextStyle(
                          fontSize: 19 * d,
                          color: const Color(0xFFB9C7FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Highlights ──
  Widget _highlights() {
    final s = p.specs;
    final display = s['Display'] ?? '';
    final items = [
      (
        Icons.memory_rounded,
        s['Processor'] ?? 'Flagship chipset',
        'Next-gen performance',
      ),
      (
        Icons.photo_camera_outlined,
        '${(s['Rear Camera'] ?? '48MP').split(' ').first} Pro Camera',
        'Pro-level photos & 4K videos',
      ),
      (
        Icons.smartphone_rounded,
        display.split(',').first,
        display.contains('120Hz')
            ? '120Hz smooth display'
            : 'Bright, vivid display',
      ),
      (
        Icons.battery_charging_full_rounded,
        s['Battery'] ?? 'All-day battery',
        'Video playback',
      ),
      (
        Icons.verified_rounded,
        s['OS'] ?? 'Latest OS',
        'Smooth, secure and powerful',
      ),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Highlights', style: _h),
          SizedBox(height: 18 * d),
          for (final h in items)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12 * d),
              child: Row(
                children: [
                  Icon(h.$1, size: 50 * d, color: HomeColors.blue),
                  SizedBox(width: 26 * d),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.$2, style: _t),
                        Text(h.$3, style: _s),
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

  // ── Product video ──
  Widget _overviewVideo() {
    final cam = widget.heroVariant;
    final videos = [
      for (final r in ref.watch(reviewsProvider(p.id)))
        ...r.media.where((m) => m.isVideo),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: GestureDetector(
        onTap: () => videos.isEmpty
            ? showAppSnack(context, 'Product video will be available soon')
            : openMediaViewer(context, videos, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32 * d),
          child: SizedBox(
            height: 372 * d,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cam != null)
                  Image.asset(
                    '$_img/pdp_hero_$cam.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(-0.2, -0.4),
                  )
                else
                  AppImage(p.images.first),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x330B0820), Color(0xCC0B0820)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 130 * d,
                    height: 130 * d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(color: Colors.white, width: 4 * d),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 84 * d,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 34 * d,
                  bottom: 28 * d,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Overview',
                        style: TextStyle(
                          fontSize: 32 * d,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        videos.isEmpty
                            ? 'Watch in 2 min'
                            : '${videos.length} customer videos',
                        style: TextStyle(
                          fontSize: 21 * d,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── About ──
  Widget _about() {
    final s = p.specs;
    final intro =
        'The ${p.brand == 'Apple' ? 'Apple ' : ''}${p.name} delivers a powerful ${s['Processor'] ?? 'flagship chipset'}, '
        'a pro-grade ${(s['Rear Camera'] ?? '').split(' ').first} camera, a stunning ${(s['Display'] ?? 'display').split(',').first} '
        'display and all-day battery life in a premium design.';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About the Product', style: _h),
          SizedBox(height: 14 * d),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Text(
              _aboutOpen ? '$intro\n\n${p.description}' : intro,
              style: TextStyle(
                fontSize: 23 * d,
                height: 1.5,
                color: HomeColors.inkSoft,
              ),
            ),
          ),
          SizedBox(height: 10 * d),
          GestureDetector(
            onTap: () => setState(() => _aboutOpen = !_aboutOpen),
            child: Row(
              children: [
                Text(
                  _aboutOpen ? 'Read Less' : 'Read More',
                  style: TextStyle(
                    fontSize: 23 * d,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.blue,
                  ),
                ),
                Icon(
                  _aboutOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 34 * d,
                  color: HomeColors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Specifications ──
  Widget _specs() {
    final s = p.specs;
    final rows = <(IconData, String, String)>[
      (Icons.sell_outlined, 'Brand', p.brand),
      (Icons.phone_iphone_rounded, 'Model', p.name),
      (Icons.sd_storage_outlined, 'Storage', p.storage ?? '-'),
      (Icons.memory_rounded, 'RAM', p.ram ?? '-'),
      for (final k in [
        'Display',
        'Processor',
        'Rear Camera',
        'Front Camera',
        'Battery',
        'OS',
      ])
        if (s[k] != null) (_specIcon(k), k, s[k]!),
    ];
    final extra = <(IconData, String, String)>[
      (Icons.network_cell_rounded, 'Network', s['Network'] ?? '5G'),
      (
        Icons.inventory_2_outlined,
        'In the box',
        s['In the box'] ?? 'Phone, cable',
      ),
      (
        Icons.diamond_outlined,
        'Condition',
        (p.condition ?? 'Excellent').replaceAll(' Condition', ''),
      ),
      (
        Icons.battery_full_rounded,
        'Battery health',
        '${p.batteryHealth == 0 ? 90 : p.batteryHealth}%',
      ),
      (Icons.qr_code_2_rounded, 'IMEI status', 'Clean • Blacklist-free'),
      (Icons.gpp_good_outlined, 'Warranty', '${p.warrantyMonths} months GAMEX'),
    ];
    final shown = _specsOpen ? [...rows, ...extra] : rows;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(Icons.fact_check_outlined, 'Specifications'),
          SizedBox(height: 20 * d),
          for (var i = 0; i < shown.length; i++)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * d,
                vertical: 18 * d,
              ),
              decoration: BoxDecoration(
                color: i.isEven ? const Color(0xFFF1F5FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(14 * d),
              ),
              child: Row(
                children: [
                  Icon(shown[i].$1, size: 28 * d, color: HomeColors.blue),
                  SizedBox(width: 14 * d),
                  Text(
                    shown[i].$2,
                    style: TextStyle(
                      fontSize: 22 * d,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                  ),
                  SizedBox(width: 16 * d),
                  Expanded(
                    child: Text(
                      shown[i].$3,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 22 * d,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 20 * d),
          _wideButton(
            _specsOpen ? 'Show Less' : 'View Full Specifications',
            () => setState(() => _specsOpen = !_specsOpen),
          ),
        ],
      ),
    );
  }

  IconData _specIcon(String k) => switch (k) {
    'Display' => Icons.smartphone_rounded,
    'Processor' => Icons.developer_board_rounded,
    'Rear Camera' => Icons.photo_camera_outlined,
    'Front Camera' => Icons.camera_front_outlined,
    'Battery' => Icons.battery_charging_full_rounded,
    _ => Icons.settings_suggest_outlined,
  };

  // ── What's in the box ──
  Widget _inTheBox() {
    Widget tile(Widget visual, String label) => Expanded(
      child: Column(
        children: [
          Container(
            height: 150 * d,
            margin: EdgeInsets.symmetric(horizontal: 8 * d),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FD),
              borderRadius: BorderRadius.circular(20 * d),
            ),
            child: Center(child: visual),
          ),
          SizedBox(height: 12 * d),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21 * d,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: HomeColors.ink,
            ),
          ),
        ],
      ),
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.inventory_2_outlined, "What's in the Box"),
          SizedBox(height: 20 * d),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(
                SizedBox(
                  width: 120 * d,
                  height: 130 * d,
                  child: AppImage(p.images.first),
                ),
                p.name.replaceFirst(' ', '\n'),
              ),
              tile(
                Container(
                  width: 96 * d,
                  height: 96 * d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD7DCE8),
                      width: 9 * d,
                    ),
                  ),
                ),
                'USB-C\nCable',
              ),
              tile(
                Container(
                  width: 92 * d,
                  height: 120 * d,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10 * d),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10 * d,
                      ),
                    ],
                  ),
                  child: Icon(
                    p.brand == 'Apple'
                        ? Icons.apple
                        : Icons.description_outlined,
                    color: const Color(0xFFC9CED9),
                    size: 46 * d,
                  ),
                ),
                'Documentation\n& Warranty',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Ratings & reviews ──
  Widget _ratings() {
    final summary = ref.watch(ratingSummaryProvider(p.id));
    final reviews = ref.watch(reviewsProvider(p.id));
    final media = <ReviewMedia>[for (final r in reviews) ...r.media];
    if (media.length < 3 && widget.heroVariant != null) {
      media.insertAll(0, [
        ReviewMedia('asset:$_img/pdp_cam_${widget.heroVariant}.jpg'),
        ReviewMedia(p.images.first),
      ]);
    }
    final total = NumberFormat.decimalPattern('en_IN').format(summary.total);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(Icons.star_border_rounded, 'Ratings & Reviews ($total)'),
          SizedBox(height: 24 * d),
          Row(
            children: [
              Column(
                children: [
                  Text.rich(
                    TextSpan(
                      text: summary.average.toStringAsFixed(1),
                      children: [
                        TextSpan(
                          text: '/5',
                          style: TextStyle(
                            fontSize: 26 * d,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 76 * d,
                      fontWeight: FontWeight.w800,
                      color: HomeColors.ink,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 10 * d),
                  StarRow(rating: summary.average, size: 34 * d),
                ],
              ),
              SizedBox(width: 30 * d),
              Expanded(
                child: Column(
                  children: [
                    for (var s = 5; s >= 1; s--)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5 * d),
                        child: Row(
                          children: [
                            Text(
                              '$s★',
                              style: TextStyle(
                                fontSize: 20 * d,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 10 * d),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6 * d),
                                child: LinearProgressIndicator(
                                  value: summary.share(s),
                                  minHeight: 12 * d,
                                  backgroundColor: const Color(0xFFE9EDF7),
                                  color: const Color(0xFF1E9E4A),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 64 * d,
                              child: Text(
                                '${(summary.share(s) * 100).round()}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 20 * d),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24 * d),
          Row(
            children: [
              for (var i = 0; i < 3 && i < media.length; i++) ...[
                if (i > 0) SizedBox(width: 14 * d),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: GestureDetector(
                      onTap: () => openMediaViewer(context, media, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18 * d),
                        child: media[i].path.contains('pdp_')
                            ? Image.asset(
                                media[i].path.substring(6),
                                fit: BoxFit.cover,
                              )
                            : MediaThumb(media: media[i], size: 300 * d),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 22 * d),
          _wideButton(
            'Read All Reviews',
            () => showAllReviewsSheet(
              context,
              product: p,
              variant: widget.variantLabel,
            ),
          ),
          SizedBox(height: 12 * d),
          Center(
            child: TextButton.icon(
              onPressed: () => showWriteReviewSheet(
                context,
                productId: p.id,
                variant: widget.variantLabel,
              ),
              icon: Icon(Icons.rate_review_outlined, size: 30 * d),
              label: Text(
                'Write a review with photos & video',
                style: TextStyle(fontSize: 21 * d),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Q&A ──
  Widget _qa() {
    final qs = ref.watch(questionsProvider(p.id));
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(Icons.forum_outlined, 'Questions & Answers'),
          SizedBox(height: 8 * d),
          for (final q in qs.take(2)) QaCard(question: q, compact: true),
          SizedBox(height: 22 * d),
          _wideButton('View All Q&A', () => showAllQuestionsSheet(context, p)),
        ],
      ),
    );
  }

  // ── Similar products ──
  Widget _similar() {
    final key = productKeyOf(p.id);
    final list =
        (ref
                    .watch(
                      productsProvider((
                        categoryId: p.categoryId,
                        query: null,
                        sort: ProductSort.popular,
                      )),
                    )
                    .asData
                    ?.value ??
                const <Product>[])
            .where((x) => x.id != key)
            .toList();
    final fill = list.length < 3
        ? (ref.watch(featuredProductsProvider).asData?.value ??
                  const <Product>[])
              .where((x) => x.id != key && !list.contains(x))
              .take(6 - list.length)
        : const <Product>[];
    final items = [...list, ...fill];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40 * d),
          child: _title(Icons.local_offer_outlined, 'Similar Products'),
        ),
        SizedBox(height: 20 * d),
        SizedBox(
          height: 470 * d,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 19 * d),
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(width: 18 * d),
            itemBuilder: (_, i) => _SimilarCard(product: items[i], d: d),
          ),
        ),
      ],
    );
  }

  // ── Exchange ──
  Widget _exchange() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: Container(
        padding: EdgeInsets.fromLTRB(36 * d, 34 * d, 30 * d, 34 * d),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32 * d),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1466), Color(0xFF5B2DB8), Color(0xFF8A4FE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sync_rounded, size: 80 * d, color: Colors.white),
            SizedBox(width: 24 * d),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exchange Your Old Phone',
                    style: TextStyle(
                      fontSize: 32 * d,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8 * d),
                  Text(
                    'Get up to ${formatPrice(15000)} off on exchange',
                    style: TextStyle(
                      fontSize: 23 * d,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  SizedBox(height: 22 * d),
                  GestureDetector(
                    onTap: () => showTradeInSheet(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 34 * d,
                        vertical: 16 * d,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30 * d),
                      ),
                      child: Text(
                        'Check Value',
                        style: TextStyle(
                          fontSize: 23 * d,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trust() {
    final items = [
      (Icons.verified_user_outlined, 'Secure\nPayment'),
      (Icons.swap_horiz_rounded, 'Easy Returns\n(7 Days)'),
      (Icons.workspace_premium_outlined, 'Genuine\nProducts'),
      (Icons.groups_outlined, 'Trusted by 1L+\nCustomers'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 19 * d),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in items)
            Expanded(
              child: Column(
                children: [
                  Icon(t.$1, size: 52 * d, color: HomeColors.blue),
                  SizedBox(height: 10 * d),
                  Text(
                    t.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20 * d,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.product, required this.d});
  final Product product;
  final double d;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () => context.push('/product/${p.id}'),
      child: Glass(
        radius: 26 * d,
        color: Colors.white.withValues(alpha: 0.92),
        padding: EdgeInsets.all(14 * d),
        child: SizedBox(
          width: 252 * d,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 230 * d,
                child: AppImage(
                  p.images.first,
                  borderRadius: BorderRadius.circular(18 * d),
                ),
              ),
              SizedBox(height: 16 * d),
              Text(
                '${p.name} (${p.storage ?? ''})',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22 * d,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.ink,
                ),
              ),
              SizedBox(height: 12 * d),
              Text(
                formatPrice(p.price),
                style: TextStyle(
                  fontSize: 26 * d,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.ink,
                ),
              ),
              if (p.oldPrice != null)
                Text(
                  formatPrice(p.mrp),
                  style: TextStyle(
                    fontSize: 20 * d,
                    color: HomeColors.grey,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: HomeColors.grey,
                  ),
                ),
              SizedBox(height: 8 * d),
              if (p.discountPercent > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * d,
                    vertical: 4 * d,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE1E4),
                    borderRadius: BorderRadius.circular(10 * d),
                  ),
                  child: Text(
                    '${p.discountPercent}% OFF',
                    style: TextStyle(
                      fontSize: 19 * d,
                      fontWeight: FontWeight.w700,
                      color: HomeColors.red,
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
