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
    if (url.startsWith('asset:')) {
      // Decode at (roughly) the displayed size instead of full resolution.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final img = LayoutBuilder(
        builder: (context, c) {
          final w = width ?? (c.maxWidth.isFinite ? c.maxWidth : null);
          return Image.asset(
            url.substring(6),
            fit: BoxFit.contain,
            width: width,
            height: height,
            cacheWidth: w == null ? null : (w * dpr).round().clamp(64, 1200),
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          );
        },
      );
      // Product photos sit on the same soft panel colour they were shot on.
      final boxed = Container(
        width: width,
        height: height,
        color: const Color(0xFFE8EDF9),
        alignment: Alignment.center,
        child: img,
      );
      return borderRadius == null
          ? boxed
          : ClipRRect(borderRadius: borderRadius!, child: boxed);
    }
    if (url.startsWith('acc:')) {
      final tile = SizedBox(
        width: width,
        height: height,
        child: AccessoryArt(url),
      );
      return borderRadius == null
          ? tile
          : ClipRRect(borderRadius: borderRadius!, child: tile);
    }
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

/// Drawn tile for accessories: `acc:<kind>/<ARGB hex>`.
class AccessoryArt extends StatelessWidget {
  const AccessoryArt(this.spec, {super.key});
  final String spec;

  static const _icons = <String, IconData>{
    'case': Icons.smartphone_rounded,
    'glass': Icons.layers_rounded,
    'lens': Icons.camera_rounded,
    'charger': Icons.power_rounded,
    'cable': Icons.cable_rounded,
    'buds': Icons.headphones_rounded,
    'battery': Icons.battery_charging_full_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final parts = spec.substring(4).split('/');
    final kind = parts.first;
    final color = Color(
      int.tryParse(parts.length > 1 ? parts[1] : '', radix: 16) ?? 0xFF8FB4FF,
    );
    final dark = color.computeLuminance() < 0.35;
    return LayoutBuilder(
      builder: (context, c) {
        final s =
            (c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 80)
                .toDouble();
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF1F4FF), Color(0xFFE4E9FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              width: s * 0.62,
              height: s * 0.62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.18),
                gradient: LinearGradient(
                  colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: s * 0.12,
                    offset: Offset(0, s * 0.05),
                  ),
                ],
              ),
              child: Icon(
                _icons[kind] ?? Icons.devices_other_rounded,
                size: s * 0.34,
                color: dark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        );
      },
    );
  }
}
