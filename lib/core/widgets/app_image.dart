import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import 'phone_art.dart';
import 'skeleton.dart';

/// Network image with caching, skeleton placeholder and graceful error state.
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final spec = PhoneArtSpec.tryParse(url);
    if (spec != null) {
      final art = SizedBox(
        width: width,
        height: height,
        child: PhoneArt(spec: spec),
      );
      return borderRadius == null
          ? art
          : ClipRRect(borderRadius: borderRadius!, child: art);
    }
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => Skeleton(width: width, height: height),
      errorWidget: (context, _, _) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
