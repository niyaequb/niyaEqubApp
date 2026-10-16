// A home-screen banner picture that is kept on the phone between launches.
//
// WHY THE BANNERS LOADED EVERY TIME
//
// The banner LIST was cached (AppCache, CacheKeys.promotions) but the
// pictures were drawn with Image.network, which keeps a decoded picture in
// memory only. Every cold start therefore downloaded every banner again, and
// the carousel showed empty grey cards until each one arrived.
//
// CachedNetworkImage writes the file to the app's cache folder on first
// download and reads it from there afterwards, so from the second launch on a
// banner appears with the first frame, even offline.
//
// THE CACHE KEY IS THE PATH, NOT THE WHOLE URL
//
// The same picture can come back under different URLs: a different host
// (cms.niya-et.com vs a CDN), or a signed URL whose query string changes on
// every request. Keyed by the full URL, each of those would be a new download.
// Keyed by the path, it is the same file. An admin who replaces a banner
// uploads a new file, which gets a new path, so a changed banner is never
// hidden behind the old one.
//
// The web build replaces this file (MiniApp/web_overrides/features/member/
// home/presentation/widgets/banner_image.dart) with one that has the same
// class and the same two statics, because a browser has no disk cache for
// this package to fill.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

class BannerImage extends StatelessWidget {
  const BannerImage({
    super.key,
    required this.url,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor = const Color(0x00000000),
  });

  final String url;
  final BoxFit fit;

  /// Used by the web version only (an <img> cannot be clipped by Flutter).
  /// Accepted here so the home screen is the same file on both builds.
  final BorderRadius? borderRadius;

  /// Painted while the picture is read or downloaded, so a card is never
  /// see-through for a frame.
  final Color placeholderColor;

  final WidgetBuilder errorBuilder;

  /// The key the picture is stored under. See the note at the top.
  static String cacheKeyFor(String url) {
    final path = Uri.tryParse(url)?.path;
    return 'banner:${(path == null || path.isEmpty) ? url : path}';
  }

  /// Starts reading (or downloading) [url] now, so it is ready before its card
  /// slides into view. Safe to call repeatedly: a picture already in memory
  /// resolves at once, and a failure is ignored here — the card itself shows
  /// the error state if the picture really cannot be loaded.
  static Future<void> precache(BuildContext context, String url) {
    return precacheImage(
      CachedNetworkImageProvider(url, cacheKey: cacheKeyFor(url)),
      context,
      onError: (_, _) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKeyFor(url),
      fit: fit,
      // A picture read from disk should simply be there, not fade in.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      // When the banner list refreshes, keep showing the old picture until
      // the new one is ready instead of flashing the placeholder.
      useOldImageOnUrlChange: true,
      placeholder: (_, _) => ColoredBox(color: placeholderColor),
      errorWidget: (context, _, _) => errorBuilder(context),
    );
  }
}
