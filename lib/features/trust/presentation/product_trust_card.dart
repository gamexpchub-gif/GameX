import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models/product.dart';
import '../data/inspection.dart';
import 'widgets/trust_ui.dart';

/// Product page card: QC certificate, inspection score, seller and returns.
class ProductTrustCard extends StatelessWidget {
  const ProductTrustCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final r = inspectionFor(p);
    return TCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TIcon(
                Icons.verified_user_rounded,
                gradient: TX.success,
                size: 40,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GAMEX Trust',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: TX.ink,
                      ),
                    ),
                    Text(
                      'Inspected • certified • protected',
                      style: TextStyle(fontSize: 12.5, color: TX.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/trust'),
                child: const Text(
                  'Learn more',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  icon: Icons.assignment_turned_in_rounded,
                  title: '${r.passed}/${r.total} checks',
                  subtitle: r.defects.isEmpty
                      ? 'View report'
                      : '${r.defects.length} marks on photos',
                  onTap: () => context.push('/product/${p.id}/report'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  icon: Icons.workspace_premium_rounded,
                  title: p.certificate == null ? 'QC passed' : 'Certificate',
                  subtitle: p.certificate ?? 'GAMEX verified',
                  onTap: p.certificate == null
                      ? null
                      : () => context.push('/certificate/${p.certificate}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Open-box delivery',
                  subtitle: 'Check before you accept',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  icon: Icons.assignment_return_outlined,
                  title: p.returnDays == 0
                      ? 'No returns'
                      : '${p.returnDays}-day return',
                  subtitle: p.returnDays == 0
                      ? 'Sold as is'
                      : 'Free doorstep pickup',
                ),
              ),
            ],
          ),
          if (p.sellerId != null) ...[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFF6F4FF),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/seller/${p.sellerId}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: TX.chip,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          (p.sellerName ?? 'S')
                              .split(' ')
                              .where((w) => w.isNotEmpty)
                              .take(2)
                              .map((w) => w[0])
                              .join()
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sold by',
                              style: TextStyle(fontSize: 11.5, color: TX.muted),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.sellerName ?? 'GAMEX seller',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: TX.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: TX.blue,
                                ),
                              ],
                            ),
                            Text(
                              '${p.sellerCity ?? ''}${p.rating > 0 ? ' • ★ ${p.rating.toStringAsFixed(1)}' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TX.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'View store',
                        style: TextStyle(
                          color: TX.violet,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: TX.violet),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: TX.line),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => TX.chip.createShader(r),
              child: Icon(icon, size: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: TX.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: TX.muted),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: TX.faint,
              ),
          ],
        ),
      ),
    ),
  );
}
