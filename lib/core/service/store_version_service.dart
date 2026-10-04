import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:niya_equb/core/service/app_cache.dart';

/// One published release, described by the store itself.
///
/// Every field except [version], [storeUrl] and [storeName] is optional,
/// because the two stores volunteer very different amounts of information:
/// Apple's lookup API returns a tidy JSON record with the size, the rating and
/// the release notes, while Google Play only ever gives up a version number
/// and, on a good day, the "What's new" text.
@immutable
class StoreRelease {
  /// The marketing version on the store, e.g. "1.0.2". Never carries a
  /// "+build" suffix — neither store publishes one.
  final String version;

  /// Where the Update button sends people.
  final String storeUrl;

  /// "Google Play" or "App Store". Shown in the sheet header.
  final String storeName;

  /// "What's new", one entry per line.
  final List<String> releaseNotes;

  final String? appName;
  final String? iconUrl;
  final DateTime? releasedAt;
  final int? sizeBytes;
  final double? rating;
  final String? contentRating;

  const StoreRelease({
    required this.version,
    required this.storeUrl,
    required this.storeName,
    this.releaseNotes = const [],
    this.appName,
    this.iconUrl,
    this.releasedAt,
    this.sizeBytes,
    this.rating,
    this.contentRating,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'store_url': storeUrl,
    'store_name': storeName,
    'release_notes': releaseNotes,
    'app_name': appName,
    'icon_url': iconUrl,
    'released_at': releasedAt?.toIso8601String(),
    'size_bytes': sizeBytes,
    'rating': rating,
    'content_rating': contentRating,
  };

  static StoreRelease? fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString() ?? '';
    final storeUrl = json['store_url']?.toString() ?? '';
    if (version.isEmpty || storeUrl.isEmpty) return null;

    return StoreRelease(
      version: version,
      storeUrl: storeUrl,
      storeName: json['store_name']?.toString() ?? '',
      releaseNotes: (json['release_notes'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false),
      appName: json['app_name']?.toString(),
      iconUrl: json['icon_url']?.toString(),
      releasedAt: DateTime.tryParse('${json['released_at']}'),
      sizeBytes: json['size_bytes'] is num
          ? (json['size_bytes'] as num).toInt()
          : int.tryParse('${json['size_bytes']}'),
      rating: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse('${json['rating']}'),
      contentRating: json['content_rating']?.toString(),
    );
  }
}

/// Asks Google Play and the App Store what the newest published version is.
///
/// WHY THIS EXISTS ALONGSIDE THE SERVER CHECK
///
/// The server endpoint is still the authority on *policy* — whether a build is
/// below the minimum and must be blocked. But it only knows what an admin
/// typed into the panel, so a release that goes live on Play while nobody
/// updates the setting is invisible to it. That is exactly the case this
/// class covers: the store is asked directly, so publishing is enough.
///
/// Neither call needs an account, a key or a plugin:
///
///   * Apple publishes a documented JSON lookup endpoint. It returns the
///     version, the release notes, the size, the rating and the artwork.
///   * Google publishes no equivalent, so the listing page is read and the
///     version pulled out of it. Play has reshuffled that page before and
///     will again, so several patterns are tried in turn and a miss is
///     treated as "could not tell" rather than "up to date".
///
/// EVERY FAILURE IS SOFT. A store that cannot be reached, a page that cannot
/// be parsed and a device with no network all return null, and the caller
/// falls back to whatever the server said.
class StoreVersionService {
  StoreVersionService({Dio? client})
    : _dio =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 12),
              followRedirects: true,
              maxRedirects: 5,
              // Deliberately NOT DioNetwork.appAPI. That instance carries the
              // API base URL and an interceptor that attaches the member's
              // bearer token and bounces to login on a 401 — neither of which
              // belongs on a request to Google or Apple.
              validateStatus: (status) => status != null && status < 400,
              // Both responses are parsed by hand: Play returns HTML, and
              // Apple's content type is text/javascript, which Dio's JSON
              // decoder will not touch on its own.
              responseType: ResponseType.plain,
            ),
          );

  final Dio _dio;

  /// How long a store answer is trusted before it is asked again. Long enough
  /// that opening the app ten times in an evening costs one request, short
  /// enough that a release published this morning is noticed today.
  static const Duration cacheFor = Duration(hours: 6);

  static const String _cachePrefix = 'app:store-release';

  /// A version string a store could plausibly have published. Anything else is
  /// a parsing accident, and acting on one would be worse than doing nothing:
  /// this number can put a blocking screen in front of the whole app.
  static final RegExp _versionShape = RegExp(r'^\d{1,4}(\.\d{1,5}){1,3}$');

  static void _log(String message) {
    if (kDebugMode) debugPrint('[StoreVersion] $message');
  }

  /// The public listing page for an Android package. Always constructible,
  /// even when the version could not be read, so there is somewhere to send
  /// people either way.
  static String playUrlFor(String packageId) =>
      'https://play.google.com/store/apps/details?id=$packageId';

  /// The newest release on this device's store, or null when it could not be
  /// established.
  ///
  /// [packageId] is the Android application id or the iOS bundle identifier —
  /// they are the same string for this app, and both come from PackageInfo at
  /// runtime rather than being hardcoded.
  Future<StoreRelease?> fetch({
    required String packageId,
    bool forceRefresh = false,
    Duration maxAge = cacheFor,
  }) async {
    if (packageId.trim().isEmpty) return null;

    final platform = Platform.isIOS ? 'ios' : 'android';
    final cacheKey = '$_cachePrefix:$platform:$packageId';

    if (!forceRefresh) {
      final cached = AppCache.read<Map>(cacheKey, maxAge: maxAge);
      if (cached != null) {
        final release = StoreRelease.fromJson(cached.cast<String, dynamic>());
        if (release != null) {
          _log('cache hit: ${release.version}');
          return release;
        }
      }
    }

    StoreRelease? release;
    try {
      release = Platform.isIOS
          ? await _fetchAppStore(packageId)
          : await _fetchPlayStore(packageId);
    } catch (e) {
      _log('lookup failed: $e');
      return null;
    }

    if (release != null) {
      await AppCache.write(cacheKey, release.toJson());
    }

    return release;
  }

  // ---------------------------------------------------------------- App Store

  /// Apple's lookup service. Documented, stable, and returns everything the
  /// sheet wants to show.
  ///
  /// The country matters: an app is listed per storefront, and asking the
  /// wrong one returns zero results rather than an error. The device's own
  /// region is tried first, then Ethiopia, then the US.
  Future<StoreRelease?> _fetchAppStore(String bundleId) async {
    final deviceCountry = ui.PlatformDispatcher.instance.locale.countryCode;

    final countries = <String>{
      if (deviceCountry != null && deviceCountry.trim().isNotEmpty)
        deviceCountry.trim().toUpperCase(),
      'ET',
      'US',
    };

    for (final country in countries) {
      final url =
          'https://itunes.apple.com/lookup'
          '?bundleId=$bundleId&country=$country&limit=1';

      _log('GET $url');

      final response = await _dio.get<String>(url);
      final body = response.data ?? '';
      if (body.isEmpty) continue;

      Map<String, dynamic> decoded;
      try {
        final raw = jsonDecode(body);
        if (raw is! Map) continue;
        decoded = raw.cast<String, dynamic>();
      } catch (_) {
        continue;
      }

      final results = decoded['results'];
      if (results is! List || results.isEmpty) continue;

      final first = results.first;
      if (first is! Map) continue;
      final app = first.cast<String, dynamic>();

      final version = (app['version']?.toString() ?? '').trim();
      if (!_versionShape.hasMatch(version)) continue;

      final trackId = app['trackId'];
      final storeUrl =
          (app['trackViewUrl']?.toString().trim().isNotEmpty ?? false)
          ? app['trackViewUrl'].toString().trim()
          : (trackId == null ? '' : 'https://apps.apple.com/app/id$trackId');

      if (storeUrl.isEmpty) continue;

      _log('App Store says $version');

      return StoreRelease(
        version: version,
        storeUrl: storeUrl,
        storeName: 'App Store',
        releaseNotes: _splitNotes(app['releaseNotes']?.toString() ?? ''),
        appName: app['trackName']?.toString(),
        iconUrl:
            app['artworkUrl512']?.toString() ??
            app['artworkUrl100']?.toString(),
        releasedAt: DateTime.tryParse(
          '${app['currentVersionReleaseDate'] ?? app['releaseDate']}',
        ),
        sizeBytes: int.tryParse('${app['fileSizeBytes']}'),
        rating: app['averageUserRating'] is num
            ? (app['averageUserRating'] as num).toDouble()
            : null,
        contentRating: app['trackContentRating']?.toString(),
      );
    }

    _log('App Store returned no listing for $bundleId');
    return null;
  }

  // -------------------------------------------------------------- Play Store

  /// Reads the public listing page.
  ///
  /// There is no official API for this — the Play Developer API reports what
  /// *you* uploaded, needs a service account, and is not something an app
  /// should carry credentials for. So the page it is.
  ///
  /// `hl=en&gl=US` is pinned on purpose. The page is localised, and parsing a
  /// layout that changes with the caller's language is a bug waiting for the
  /// first user in Addis to open it.
  Future<StoreRelease?> _fetchPlayStore(String packageId) async {
    final url = '${playUrlFor(packageId)}&hl=en&gl=US';
    _log('GET $url');

    final response = await _dio.get<String>(
      url,
      options: Options(
        headers: const {
          // Play serves a stripped page to clients that do not look like a
          // browser, and the stripped page has no version in it.
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ),
    );

    final html = response.data ?? '';

    // A listing page is hundreds of kilobytes. Anything short is a consent
    // wall, a redirect stub or an error page.
    if (html.length < 2000) {
      _log('page too short to be a listing (${html.length} bytes)');
      return null;
    }

    if (html.contains('We\'re sorry, the requested URL was not found')) {
      _log('no listing for $packageId');
      return null;
    }

    final version = _playVersion(html);
    if (version == null) {
      // Genuinely common and genuinely fine: "Varies with device" listings
      // publish no version at all. Returning null keeps the server's answer
      // in charge instead of inventing one.
      _log('could not read a version from the listing');
      return null;
    }

    _log('Play says $version');

    return StoreRelease(
      version: version,
      storeUrl: playUrlFor(packageId),
      storeName: 'Google Play',
      releaseNotes: _playReleaseNotes(html),
      appName: _playAppName(html),
      releasedAt: _playUpdatedAt(html),
    );
  }

  /// Patterns are tried in order, newest layout first, and the first one that
  /// yields something version-shaped wins.
  static String? _playVersion(String html) {
    final patterns = <RegExp>[
      // Current layout. The version sits on its own in a nested array inside
      // one of the AF_initDataCallback payloads at the bottom of the page.
      RegExp(r'\[\[\["(\d{1,4}(?:\.\d{1,5}){1,3})"\]\]'),
      RegExp(r'\[\["(\d{1,4}(?:\.\d{1,5}){1,3})"\]\]'),
      // Older server-rendered layout, still served to some clients.
      RegExp(
        r'itemprop\s*=\s*"softwareVersion"[^>]*>\s*([^<]+)<',
        caseSensitive: false,
      ),
      RegExp(
        r'Current Version.{0,160}?(\d{1,4}(?:\.\d{1,5}){1,3})',
        dotAll: true,
      ),
      RegExp(r'"version"\s*:\s*"(\d{1,4}(?:\.\d{1,5}){1,3})"'),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(html)) {
        final candidate = (match.group(1) ?? '').trim();
        if (_versionShape.hasMatch(candidate)) return candidate;
      }
    }

    return null;
  }

  /// The "What's new" block, when the page carries one.
  ///
  /// Purely cosmetic — the sheet hides the section when this comes back empty
  /// — so this leans towards returning nothing rather than returning the
  /// wrong paragraph.
  static List<String> _playReleaseNotes(String html) {
    final marker = RegExp(
      r"What.{0,8}s new",
      caseSensitive: false,
    ).firstMatch(html);
    if (marker == null) return const [];

    final end = math.min(marker.end + 8000, html.length);
    final window = html.substring(marker.end, end);

    for (final match in RegExp(
      r'"((?:[^"\\]|\\.){24,1500})"',
    ).allMatches(window)) {
      final decoded = _decodeJsString(match.group(1) ?? '');
      if (!_looksLikeProse(decoded)) continue;
      final notes = _splitNotes(decoded);
      if (notes.isNotEmpty) return notes;
    }

    return const [];
  }

  static String? _playAppName(String html) {
    final match = RegExp(
      r'<meta\s+property="og:title"\s+content="([^"]{1,120})"',
      caseSensitive: false,
    ).firstMatch(html);

    final name = _decodeHtmlEntities((match?.group(1) ?? '').trim());
    if (name.isEmpty) return null;

    // Play appends the store name to the OG title.
    return name.replaceAll(RegExp(r'\s*[-–—]\s*Apps on Google Play$'), '');
  }

  static DateTime? _playUpdatedAt(String html) {
    final marker = RegExp(
      r'Updated on',
      caseSensitive: false,
    ).firstMatch(html);
    if (marker == null) return null;

    final end = math.min(marker.end + 400, html.length);
    final window = html.substring(marker.end, end);

    final match = RegExp(
      r'([A-Z][a-z]{2})\s+(\d{1,2}),\s*(\d{4})',
    ).firstMatch(window);
    if (match == null) return null;

    const months = <String, int>{
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };

    final month = months[match.group(1)];
    final day = int.tryParse(match.group(2) ?? '');
    final year = int.tryParse(match.group(3) ?? '');
    if (month == null || day == null || year == null) return null;

    return DateTime(year, month, day);
  }

  // ------------------------------------------------------------------ shared

  /// Release notes arrive as one blob with newlines or `<br>` in it. The sheet
  /// renders a bullet per entry, so it is split here rather than there.
  static List<String> _splitNotes(String raw) {
    if (raw.trim().isEmpty) return const [];

    final normalised = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    return _decodeHtmlEntities(normalised)
        .split(RegExp(r'\r\n|\r|\n'))
        .map((line) => line.trim())
        // Leading bullet glyphs are re-added by the widget.
        .map((line) => line.replaceFirst(RegExp(r'^[-•*·]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(8)
        .toList(growable: false);
  }

  /// True when a candidate string reads like sentences a person wrote, rather
  /// than a URL, a token or a run of CSS that happened to be quoted.
  static bool _looksLikeProse(String value) {
    final text = value.trim();
    if (text.length < 20) return false;
    if (!RegExp(r'[A-Za-z]{3}').hasMatch(text)) return false;
    if (text.startsWith('http') || text.startsWith('//')) return false;
    if (text.contains('{') || text.contains(';}')) return false;
    if (RegExp(r'^[A-Za-z0-9+/=_-]{40,}$').hasMatch(text)) return false;
    return text.contains(' ');
  }

  /// Play embeds its strings inside JavaScript literals, so `<` arrives as
  /// `<` and a newline as `\n`.
  static String _decodeJsString(String value) {
    var out = value
        .replaceAll(r'\/', '/')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\t', ' ');

    out = out.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );

    return out.replaceAll('\\\\', '\\');
  }

  static String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
