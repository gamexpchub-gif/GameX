import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_image.dart';
import '../../../data/models/product.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../data/inspection.dart';
import 'widgets/trust_ui.dart';

/// Full 32-point inspection report for a listing.
class InspectionReportScreen extends ConsumerWidget {
  const InspectionReportScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productByIdProvider(productId));
    return async.when(
      loading: () => const TrustScaffold(
        title: 'Inspection report',
        children: [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (_, _) => const TrustScaffold(
        title: 'Inspection report',
        children: [
          SizedBox(height: 120),
          Center(child: Text('Could not load the report')),
        ],
      ),
      data: (p) => p == null
          ? const TrustScaffold(
              title: 'Inspection report',
              children: [
                SizedBox(height: 120),
                Center(child: Text('This phone is no longer listed')),
              ],
            )
          : _Report(product: p),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final r = inspectionFor(p);
    final scoreColor = r.score >= 90
        ? TX.green
        : r.score >= 75
        ? TX.amber
        : TX.red;
    return TrustScaffold(
      title: 'Inspection report',
      subtitle: '${p.name} • ${p.memoryLabel ?? ''}',
      children: [
        THero(
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: r.score / 100,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      color: scoreColor == TX.green
                          ? const Color(0xFF4ADE80)
                          : scoreColor,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${r.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'QC score',
                          style: TextStyle(
                            color: Color(0xFFC9D2FF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.passed}/${r.total} checks passed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Legend(
                      color: const Color(0xFF4ADE80),
                      text: '${r.passed} passed',
                    ),
                    _Legend(
                      color: const Color(0xFFFCD34D),
                      text: '${r.minor} cosmetic notes',
                    ),
                    _Legend(
                      color: const Color(0xFFFB7185),
                      text: '${r.failed} issues',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Grade: ${gradeLabels[r.grade]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (p.certificate != null) ...[
          const SizedBox(height: 12),
          TCard(
            onTap: () => context.push('/certificate/${p.certificate}'),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const TIcon(
                  Icons.workspace_premium_rounded,
                  gradient: TX.success,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GAMEX QC certificate',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: TX.ink,
                        ),
                      ),
                      Text(
                        p.certificate!,
                        style: const TextStyle(
                          color: TX.muted,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const TPill(
                  'Verified',
                  color: TX.green,
                  icon: Icons.verified_rounded,
                ),
              ],
            ),
          ),
        ],
        const TTitle('Battery'),
        TCard(child: _Battery(health: r.battery)),
        TTitle(
          'Real photos${r.defects.isEmpty ? '' : ' • ${r.defects.length} marked'}',
        ),
        _PhotoViewer(product: p),
        const TTitle('32-point check'),
        for (final g in r.groups) ...[
          _GroupCard(group: g),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        const Text(
          'Function checks are declared by the seller and verified by GAMEX QC before listing. Cosmetic notes follow the condition grade and marked photos.',
          style: TextStyle(fontSize: 11.5, color: TX.faint, height: 1.4),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
      ],
    ),
  );
}

class _Battery extends StatelessWidget {
  const _Battery({required this.health});
  final int health;

  @override
  Widget build(BuildContext context) {
    final c = health >= 85
        ? TX.green
        : health >= 78
        ? TX.amber
        : TX.red;
    final label = health >= 90
        ? 'Excellent - lasts like new'
        : health >= 85
        ? 'Great - comfortably a full day'
        : health >= 78
        ? 'Fair - may need a mid-day top-up'
        : 'Low - battery replacement advised';
    return Row(
      children: [
        Container(
          width: 64,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: TX.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: health / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: TX.ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$health% health',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: c,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: TX.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({required this.group});
  final InspectionGroup group;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  late bool _open = widget.group.hasIssue;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return TCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        children: [
          Row(
            children: [
              TIcon(g.icon, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  g.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: TX.ink,
                  ),
                ),
              ),
              TPill(
                '${g.passed}/${g.items.length}',
                color: g.hasIssue ? TX.amber : TX.green,
                icon: g.hasIssue
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_rounded,
              ),
              Icon(
                _open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: TX.faint,
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            for (final i in g.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      switch (i.result) {
                        CheckResult.pass => Icons.check_circle_rounded,
                        CheckResult.minor => Icons.error_rounded,
                        CheckResult.fail => Icons.cancel_rounded,
                      },
                      size: 19,
                      color: switch (i.result) {
                        CheckResult.pass => TX.green,
                        CheckResult.minor => TX.amber,
                        CheckResult.fail => TX.red,
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i.name,
                        style: const TextStyle(color: TX.ink),
                      ),
                    ),
                    if (i.note != null)
                      Text(
                        i.note!,
                        style: const TextStyle(fontSize: 12, color: TX.muted),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.product});
  final Product product;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final photos = p.images;
    final defects = p.defects;
    return TCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: MarkedPhoto(src: photos[_i], index: _i, defects: defects),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, k) {
                final marks = defects.where((d) => d.photo == k).length;
                return GestureDetector(
                  onTap: () => setState(() => _i = k),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: k == _i ? TX.violet : TX.line,
                            width: 2,
                          ),
                        ),
                        child: AppImage(
                          photos[k],
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      if (marks > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: TX.red,
                            child: Text(
                              '$marks',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (defects.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var k = 0; k < defects.length; k++)
              GestureDetector(
                onTap: () => setState(
                  () => _i = defects[k].photo.clamp(0, photos.length - 1),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: TX.red,
                        child: Text(
                          '${k + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          defects[k].label,
                          style: const TextStyle(
                            color: TX.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Photo ${defects[k].photo + 1}',
                        style: const TextStyle(fontSize: 12, color: TX.muted),
                      ),
                    ],
                  ),
                ),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: TX.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No cosmetic defects were marked by QC',
                      style: TextStyle(color: TX.muted),
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

/// A photo with numbered defect markers at their exact image positions.
class MarkedPhoto extends StatefulWidget {
  const MarkedPhoto({
    super.key,
    required this.src,
    required this.index,
    required this.defects,
  });
  final String src;
  final int index;
  final List<PhotoDefect> defects;

  @override
  State<MarkedPhoto> createState() => _MarkedPhotoState();
}

class _MarkedPhotoState extends State<MarkedPhoto> {
  double? _aspect;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _aspect = info.image.width / info.image.height);
  });

  ImageProvider get _provider => widget.src.startsWith('asset:')
      ? AssetImage(widget.src.substring(6)) as ImageProvider
      : NetworkImage(widget.src);

  void _resolve() {
    _stream?.removeListener(_listener);
    _stream = _provider.resolve(ImageConfiguration.empty)
      ..addListener(_listener);
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(MarkedPhoto old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src) {
      _aspect = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marks = [
      for (var k = 0; k < widget.defects.length; k++)
        if (widget.defects[k].photo == widget.index) (k + 1, widget.defects[k]),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F7FD), Color(0xFFE8EEFF)],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: _aspect == null
            ? AppImage(widget.src, fit: BoxFit.contain)
            : AspectRatio(
                aspectRatio: _aspect!,
                child: LayoutBuilder(
                  builder: (_, c) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AppImage(widget.src, fit: BoxFit.fill),
                      ),
                      for (final (n, d) in marks)
                        Positioned(
                          left: d.x * c.maxWidth - 13,
                          top: d.y * c.maxHeight - 13,
                          child: Tooltip(
                            message: d.label,
                            triggerMode: TooltipTriggerMode.tap,
                            child: Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: TX.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: TX.red.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Text(
                                '$n',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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
