import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/common.dart';
import '../../../../data/models/review.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../reviews/providers/reviews_provider.dart';

const kMaxReviewPhotos = 5;
const kMaxVideoSeconds = 30;

bool _isFile(String path) => path.startsWith('/');

/// Square thumbnail for a photo or video.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.media,
    this.size = 64,
    this.onTap,
    this.onRemove,
  });

  final ReviewMedia media;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (media.isVideo) {
      content = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B2440), Color(0xFF0A0F1F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            Positioned(
              left: 5,
              bottom: 4,
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white70,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '≤${kMaxVideoSeconds}s',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_isFile(media.path)) {
      content = Image.file(
        File(media.path),
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
      );
    } else {
      content = AppImage(media.path);
    }
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: content,
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: onRemove,
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
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

/// Full-screen swipeable viewer for review photos and videos.
void openMediaViewer(
  BuildContext context,
  List<ReviewMedia> media,
  int initial,
) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _MediaViewer(media: media, initial: initial),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

class _MediaViewer extends StatefulWidget {
  const _MediaViewer({required this.media, required this.initial});
  final List<ReviewMedia> media;
  final int initial;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _page,
              itemCount: widget.media.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final m = widget.media[i];
                if (m.isVideo) return _VideoView(path: m.path);
                return InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: _isFile(m.path)
                        ? Image.file(File(m.path))
                        : AspectRatio(aspectRatio: 1, child: AppImage(m.path)),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_index + 1} / ${widget.media.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.path});
  final String path;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _c = _isFile(widget.path)
      ? VideoPlayerController.file(File(widget.path))
      : VideoPlayerController.networkUrl(Uri.parse(widget.path));
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          _c
            ..setLooping(true)
            ..play();
        })
        .catchError((Object _) {
          if (mounted) setState(() => _error = true);
        });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Text(
          'Video unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _c.value.aspectRatio,
            child: VideoPlayer(_c),
          ),
          if (!_c.value.isPlaying)
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 72,
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 40,
            child: VideoProgressIndicator(
              _c,
              allowScrubbing: true,
              colors: const VideoProgressColors(playedColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          rating >= i
              ? Icons.star_rounded
              : rating >= i - 0.5
              ? Icons.star_half_rounded
              : Icons.star_border_rounded,
          size: size,
          color: const Color(0xFFF7B500),
        ),
    ],
  );
}

/// One review: author, stars, text, media and a "Helpful" vote.
class ReviewTile extends ConsumerWidget {
  const ReviewTile({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = review;
    final voted = ref.watch(helpfulProvider).contains(r.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  r.author[0],
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.author,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (r.verified)
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Verified buyer',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                formatDate(r.createdAt).split(',').first,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StarRow(rating: r.rating.toDouble()),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (r.variant != null) ...[
            const SizedBox(height: 4),
            Text(
              'Variant: ${r.variant}',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 6),
          Text(r.body, style: const TextStyle(height: 1.45)),
          if (r.hasMedia) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => MediaThumb(
                  media: r.media[i],
                  size: 72,
                  onTap: () => openMediaViewer(context, r.media, i),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: voted
                      ? AppColors.primary
                      : theme.colorScheme.outline,
                ),
                onPressed: () =>
                    ref.read(helpfulProvider.notifier).toggle(r.id),
                icon: Icon(
                  voted
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  size: 17,
                ),
                label: Text('Helpful (${r.helpful + (voted ? 1 : 0)})'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.outline,
                ),
                onPressed: () =>
                    showAppSnack(context, 'Thanks, our team will review it'),
                child: const Text('Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rating overview: big average, stars, count and 5→1 bars.
class RatingSummaryView extends StatelessWidget {
  const RatingSummaryView({super.key, required this.summary});
  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Column(
          children: [
            Text(
              summary.average.toStringAsFixed(1),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            StarRow(rating: summary.average, size: 17),
            const SizedBox(height: 4),
            Text(
              '${summary.total} ratings',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (var s = 5; s >= 1; s--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        child: Text('$s', style: const TextStyle(fontSize: 12)),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: Color(0xFFF7B500),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: summary.share(s),
                            minHeight: 7,
                            backgroundColor: const Color(0xFFE6EBF7),
                            color: s >= 4
                                ? AppColors.success
                                : s == 3
                                ? AppColors.warning
                                : AppColors.danger,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(summary.share(s) * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet to write a review with up to 5 photos and a ≤30 s video.
Future<void> showWriteReviewSheet(
  BuildContext context, {
  required String productId,
  String? variant,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WriteReview(productId: productId, variant: variant),
  );
}

class _WriteReview extends ConsumerStatefulWidget {
  const _WriteReview({required this.productId, this.variant});
  final String productId;
  final String? variant;

  @override
  ConsumerState<_WriteReview> createState() => _WriteReviewState();
}

class _WriteReviewState extends ConsumerState<_WriteReview> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();
  int _rating = 0;
  final List<String> _photos = [];
  String? _video;
  bool _busy = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Copies a picked file into app storage so it survives cache clears.
  Future<String> _persist(XFile f) async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/review_media',
    );
    await dir.create(recursive: true);
    final dest =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${f.name}';
    await File(f.path).copy(dest);
    return dest;
  }

  Future<void> _addPhotos() async {
    final left = kMaxReviewPhotos - _photos.length;
    if (left <= 0) return;
    try {
      final files = await _picker.pickMultiImage(
        limit: left,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (files.isEmpty) return;
      setState(() => _busy = true);
      final saved = [for (final f in files.take(left)) await _persist(f)];
      setState(() => _photos.addAll(saved));
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not open photos');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addVideo(ImageSource source) async {
    try {
      final f = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: kMaxVideoSeconds),
      );
      if (f == null) return;
      setState(() => _busy = true);
      // Enforce the 30-second limit for gallery picks too.
      final c = VideoPlayerController.file(File(f.path));
      await c.initialize();
      final seconds = c.value.duration.inMilliseconds / 1000;
      await c.dispose();
      if (seconds > kMaxVideoSeconds + 0.5) {
        if (mounted) {
          showAppSnack(
            context,
            'Video is ${seconds.round()}s. Please choose one up to $kMaxVideoSeconds seconds.',
          );
        }
        return;
      }
      final saved = await _persist(f);
      setState(() => _video = saved);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not add the video');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      return showAppSnack(context, 'Please select a star rating');
    }
    if (_body.text.trim().length < 10) {
      return showAppSnack(context, 'Please write at least 10 characters');
    }
    final user = ref.read(authProvider);
    await ref
        .read(userReviewsProvider.notifier)
        .add(
          Review(
            id: 'u${DateTime.now().microsecondsSinceEpoch}',
            productKey: productKeyOf(widget.productId),
            author: user?.name ?? 'You',
            rating: _rating,
            title: _title.text.trim().isEmpty
                ? _labels[_rating]
                : _title.text.trim(),
            body: _body.text.trim(),
            createdAt: DateTime.now(),
            media: [
              for (final p in _photos) ReviewMedia(p),
              if (_video != null) ReviewMedia(_video!, isVideo: true),
            ],
            verified: user != null,
            variant: widget.variant,
          ),
        );
    if (!mounted) return;
    Navigator.pop(context);
    showAppSnack(context, 'Thanks! Your review is published');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = [
      for (final p in _photos) ReviewMedia(p),
      if (_video != null) ReviewMedia(_video!, isVideo: true),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Write a review',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = i);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        i <= _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 38,
                        color: const Color(0xFFF7B500),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  _labels[_rating],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 4,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your review',
                hintText: 'Condition, battery, delivery, packaging…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photos & video',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Up to $kMaxReviewPhotos photos and 1 video (max $kMaxVideoSeconds seconds)',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < media.length; i++)
                  MediaThumb(
                    media: media[i],
                    size: 72,
                    onTap: () => openMediaViewer(context, media, i),
                    onRemove: () => setState(() {
                      if (media[i].isVideo) {
                        _video = null;
                      } else {
                        _photos.remove(media[i].path);
                      }
                    }),
                  ),
                if (_photos.length < kMaxReviewPhotos)
                  _AddTile(
                    icon: Icons.add_photo_alternate_outlined,
                    label: 'Photo',
                    onTap: _busy ? null : _addPhotos,
                  ),
                if (_video == null) ...[
                  _AddTile(
                    icon: Icons.video_library_outlined,
                    label: 'Video',
                    onTap: _busy ? null : () => _addVideo(ImageSource.gallery),
                  ),
                  _AddTile(
                    icon: Icons.videocam_outlined,
                    label: 'Record',
                    onTap: _busy ? null : () => _addVideo(ImageSource.camera),
                  ),
                ],
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primary.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
