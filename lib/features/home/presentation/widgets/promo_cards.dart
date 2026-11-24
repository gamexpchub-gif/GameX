import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../catalog/providers/catalog_providers.dart';

/// Opens a banner link: in-app route (`/sale`) or web address.
Future<void> openBannerLink(BuildContext context, String link) async {
  final l = link.trim();
  if (l.isEmpty) return;
  if (l.startsWith('/')) {
    context.push(l);
    return;
  }
  final uri = Uri.tryParse(l.contains('://') ? l : 'https://$l');
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Auto-sliding promo cards with a button, managed from Admin → Banners.
class PromoCardsCarousel extends ConsumerStatefulWidget {
  const PromoCardsCarousel({super.key});

  @override
  ConsumerState<PromoCardsCarousel> createState() => _PromoState();
}

class _PromoState extends ConsumerState<PromoCardsCarousel> {
  final _page = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _timer;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _advance());
  }

  void _advance() {
    final n = ref.read(promoCardsProvider).asData?.value.length ?? 0;
    if (n < 2 || _touching || !_page.hasClients || !mounted) return;
    if (!TickerMode.getValuesNotifier(context).value.enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _page.animateToPage(
      (_i + 1) % n,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(promoCardsProvider).asData?.value ?? const [];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: Listener(
            onPointerDown: (_) => _touching = true,
            onPointerUp: (_) => _touching = false,
            onPointerCancel: (_) => _touching = false,
            child: PageView.builder(
              controller: _page,
              itemCount: cards.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _Card(card: cards[i]),
              ),
            ),
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _i
                        ? Color(cards[i].color)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});
  final PromoCard card;

  @override
  Widget build(BuildContext context) {
    final base = Color(card.color);
    final dark = Color.lerp(base, Colors.black, 0.35)!;
    final img = card.image;
    return GestureDetector(
      onTap: () => openBannerLink(context, card.link),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, dark],
          ),
          boxShadow: [
            BoxShadow(
              color: base.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (img != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (img != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        dark.withValues(alpha: 0.85),
                        dark.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            // soft decorative circles
            Positioned(
              right: -30,
              top: -40,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -50,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (card.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.cta,
                          style: TextStyle(
                            color: dark,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 15, color: dark),
                      ],
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
}
