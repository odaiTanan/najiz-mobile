import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/utils/media_url_resolver.dart';
import 'package:najiz_go_express/core/widgets/image_loading_pattern.dart';

class NetworkImageWithFallback extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Map<String, String>? headers;

  /// Decode/cache a smaller bitmap for list thumbnails (logical px * ~2).
  final int? cacheWidth;
  final int? cacheHeight;

  const NetworkImageWithFallback({
    super.key,
    required this.url,
    required this.fit,
    this.headers,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrlResolver.resolve(url);
    if (resolved == null) return _patternPlaceholder();

    final diskWidth = cacheWidth ?? 1024;
    final diskHeight = cacheHeight ?? 1024;

    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      httpHeaders: headers,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxWidthDiskCache: diskWidth,
      maxHeightDiskCache: diskHeight,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => _patternPlaceholder(),
      errorWidget: (_, _, _) => _patternPlaceholder(),
    );
  }

  Widget _patternPlaceholder() {
    return ImageLoadingPattern(fit: fit);
  }
}
