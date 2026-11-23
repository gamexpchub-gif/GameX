import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/models/order.dart';
import '../../orders/providers/orders_provider.dart';
import 'widgets/trust_ui.dart';

/// "GAMEX Trust Center": every protection a buyer has, in one place.
class TrustHubScreen extends ConsumerWidget {
  const TrustHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref
        .watch(ordersProvider)
        .where((o) => o.hasSellerItems)
        .toList();
    final delivered = orders
        .where((o) => o.status == OrderStatus.delivered)
        .toList();
    return TrustScaffold(
      title: 'GAMEX Trust Center',
      subtitle: 'Buy second-hand with zero worry',
      children: [
        THero(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'GAMEX PROMISE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Every phone is checked,\ncertified & protected.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '32-point QC • Open-box delivery • 7-day returns • Seller warranty',
                      style: TextStyle(
                        color: Color(0xFFC9D2FF),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const RadialGradient(
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.6, 1],
                ).createShader(r),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 92,
                  color: Color(0xFF8FB4FF),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.08,
          children: [
            _Tool(
              icon: Icons.qr_code_scanner_rounded,
              gradient: TX.chip,
              title: 'Scan Certificate',
              text: 'Scan the QR on the box to verify your phone',
              onTap: () => context.push('/trust/scan'),
            ),
            _Tool(
              icon: Icons.fact_check_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF0E7490)],
              ),
              title: 'IMEI Checker',
              text: 'Lost, stolen or locked? Check before you buy',
              onTap: () => context.push('/trust/imei'),
            ),
            _Tool(
              icon: Icons.workspace_premium_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
              ),
              title: 'Warranty Cards',
              text: delivered.isEmpty
                  ? 'Your digital warranty lives here'
                  : '${delivered.length} phone(s) covered',
              onTap: delivered.isEmpty
                  ? null
                  : () => context.push('/order/${delivered.first.id}'),
            ),
            _Tool(
              icon: Icons.assignment_return_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
              ),
              title: 'Easy Returns',
              text: '7-day return with free doorstep pickup',
              onTap: delivered.isEmpty
                  ? null
                  : () => context.push('/order/${delivered.first.id}'),
            ),
          ],
        ),
        const TTitle('How GAMEX protects you'),
        const TCard(
          child: Column(
            children: [
              _Promise(
                Icons.verified_rounded,
                'GAMEX QC certificate',
                'Every listing is inspected by our QC team. A tamper-proof QR certificate ships in the box.',
              ),
              _Promise(
                Icons.inventory_2_rounded,
                'Open-box delivery',
                'Check the phone in front of the delivery partner. Share the OTP only when you are happy.',
              ),
              _Promise(
                Icons.assignment_return_rounded,
                '7-day easy return',
                'Changed your mind or found an issue? Free pickup, refund after a quick check.',
              ),
              _Promise(
                Icons.shield_rounded,
                'Seller warranty',
                'Up to 12 months. Raise a claim from the warranty card in one tap.',
              ),
              _Promise(
                Icons.gpp_good_rounded,
                'IMEI blacklist screening',
                'Phones reported lost, stolen or financed can never be listed on GAMEX.',
                last: true,
              ),
            ],
          ),
        ),
        if (delivered.isNotEmpty) ...[
          const TTitle('Your protected phones'),
          for (final o in delivered.take(5)) ...[
            TCard(
              onTap: () => context.push('/order/${o.id}'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: AppImage(
                      o.items.first.product.images.first,
                      borderRadius: BorderRadius.circular(14),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.items.first.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TX.ink,
                          ),
                        ),
                        Text(
                          'Order ${o.id} • ${formatDate(o.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: TX.muted),
                        ),
                      ],
                    ),
                  ),
                  const TPill(
                    'Protected',
                    color: TX.green,
                    icon: Icons.shield_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TIcon(icon, gradient: gradient, size: 44),
            const Spacer(),
            Icon(
              Icons.arrow_outward_rounded,
              color: onTap == null ? TX.line : TX.faint,
              size: 20,
            ),
          ],
        ),
        const Spacer(),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: TX.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: TX.muted, height: 1.3),
        ),
      ],
    ),
  );
}

class _Promise extends StatelessWidget {
  const _Promise(this.icon, this.title, this.text, {this.last = false});
  final IconData icon;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          TIcon(icon, size: 36),
          if (!last)
            Container(
              width: 2,
              height: 34,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: TX.line,
            ),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(top: 2, bottom: last ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TX.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: TX.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
