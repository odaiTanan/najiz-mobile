import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:najiz_go_express/core/utils/media_url_resolver.dart';

/// Downloads remote images into the on-disk cache before widgets request them.
class RemoteImageCacheWarmer {
  RemoteImageCacheWarmer._();

  static Future<void> warmUrls(
    Iterable<String?> rawUrls, {
    int maxCount = 12,
    int? cacheWidth,
    int? cacheHeight,
  }) async {
    var count = 0;
    for (final raw in rawUrls) {
      if (count >= maxCount) break;
      final url = MediaUrlResolver.resolve(raw);
      if (url == null) continue;
      count++;
      try {
        await _resolveProvider(
          CachedNetworkImageProvider(
            url,
            maxWidth: cacheWidth,
            maxHeight: cacheHeight,
          ),
        );
      } catch (_) {
        // Ignore individual warm-up failures.
      }
    }
  }

  static Future<void> _resolveProvider(ImageProvider provider) {
    final completer = Completer<void>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        stream.removeListener(listener);
      },
    );
  }
}
