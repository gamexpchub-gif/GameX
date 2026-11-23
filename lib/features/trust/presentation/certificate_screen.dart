import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api.dart';
import '../../../core/widgets/app_image.dart';
import '../data/inspection.dart';
import '../data/trust_api.dart';
import 'widgets/trust_ui.dart';

/// Result of scanning / entering a GAMEX QC certificate.
class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(certificateProvider(code));
    return TrustScaffold(
      title: 'Certificate check',
      subtitle: code,
      children: async.when(
        loading: () => const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
        error: (e, _) => [
          _NotFound(
            code: code,
            offline: e is ApiException && e.offline,
            onRetry: () => ref.invalidate(certificateProvider(code)),
          ),
        ],
        data: (c) => _valid(context, ref, c),
      ),
    );
  }

  List<Widget> _valid(BuildContext context, WidgetRef ref, CertificateInfo c) {
    final api = ref.read(trustApiProvider);
    final report = buildInspection(
      grade: c.grade,
      battery: c.battery,
      checks: c.checks,
    );
    final ok = !c.blacklisted;
    return [
      THero(
        gradient: ok ? TX.success : TX.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ok
                            ? 'Genuine GAMEX certificate'
                            : 'Warning: IMEI blacklisted',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        ok ? 'This phone passed GAMEX quality check' : 'Do not accept this phone. Contact GAMEX support.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppImage(api.image(c.photo), fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${c.memory} • ${c.color}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.certificate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
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
      ),
      const SizedBox(height: 12),
      TCard(
        color: const Color(0xFFFFFBEB),
        border: const Color(0xFFFDE68A),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TIcon(
              Icons.dialpad_rounded,
              gradient: LinearGradient(
                colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
              ),
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Match the IMEI',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TX.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Dial *#06# on the phone. The number must match exactly:',
                    style: TextStyle(fontSize: 12.5, color: TX.muted),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    c.imei,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: TX.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const TTitle('Certificate details'),
      TCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            TRow(
              'Condition',
              gradeLabels[c.grade] ?? c.grade,
              icon: Icons.diamond_outlined,
            ),
            TRow(
              'Battery health',
              '${c.battery}%',
              icon: Icons.battery_charging_full_rounded,
              valueColor: c.battery >= 85 ? TX.green : TX.amber,
            ),
            TRow(
              'Checks passed',
              '${report.passed}/${report.total}',
              icon: Icons.fact_check_outlined,
            ),
            TRow(
              'Warranty',
              c.warranty == 0 ? 'None' : '${c.warranty} months',
              icon: Icons.shield_outlined,
            ),
            TRow(
              'Inspected by',
              c.qcBy ?? 'GAMEX QC',
              icon: Icons.person_search_outlined,
            ),
            if (c.qcAt != null)
              TRow(
                'Inspected on',
                DateFormat('d MMM yyyy').format(c.qcAt!),
                icon: Icons.event_available_outlined,
              ),
            if (c.sellerName != null)
              TRow(
                'Seller',
                '${c.sellerName}, ${c.sellerCity ?? ''}',
                icon: Icons.storefront_outlined,
                last: true,
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          if (c.sellerId != null)
            Expanded(
              child: TGhost(
                label: 'Seller',
                icon: Icons.storefront_outlined,
                onTap: () => context.push('/seller/${c.sellerId}'),
              ),
            ),
          if (c.sellerId != null) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TButton(
              label: c.live ? 'Full inspection report' : 'View report',
              icon: Icons.assignment_turned_in_outlined,
              onTap: () => context.push('/product/${c.listingId}/report'),
            ),
          ),
        ],
      ),
    ];
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({
    required this.code,
    required this.offline,
    required this.onRetry,
  });
  final String code;
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 20),
      THero(
        gradient: offline ? TX.night : TX.danger,
        child: Column(
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.gpp_bad_rounded,
              color: Colors.white,
              size: 56,
            ),
            const SizedBox(height: 10),
            Text(
              offline ? 'Can\'t reach GAMEX' : 'Certificate not found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              offline
                  ? 'Check your internet connection and try again.'
                  : '“$code” is not a GAMEX certificate. If it came with a phone sold as GAMEX certified, do not accept it and contact support.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TGhost(
              label: 'Scan again',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => context.pushReplacement('/trust/scan'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ),
        ],
      ),
    ],
  );
}
