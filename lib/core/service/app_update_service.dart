import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/play_update_service.dart';
import 'package:niya_equb/core/service/store_version_service.dart';

/// Where the verdict came from. Shown in diagnostics, and it decides how much
/// the app is willing to do with the answer.
enum UpdateSource {
  /// Google Play's own In-App Updates API. Authoritative: Play is telling the
  /// app directly that this device is behind.
  playStore,

  /// The admin panel published this version.
  server,

  /// A store listing was read for it.
  store,

  /// The panel and the listing agreed.
  serverAndStore,

  /// Nothing to report.
  none,
}

/// What is known about the build currently running and the one published.
@immutable
class AppUpdateInfo {
  /// The newest published version name, e.g. "1.0.2".
  ///
  /// CAN BE EMPTY. Google Play's update API reports a versionCode and has no
  /// way to report a version name, so when Play is the only source that
  /// answered there is a known update with no number to show. The sheet says
  /// "A new version is ready" in that case rather than printing a blank.
  final String latestVersion;

  /// The versionCode waiting on Play, when Play is what answered.
  final int? latestVersionCode;

  /// The version running right now, read from the bundle at runtime.
  final String currentVersion;

  /// True when something newer is published.
  final bool updateAvailable;

  /// True when this build may not carry on being used. The prompt cannot be
  /// dismissed and there is no "Not now".
  final bool forceUpdate;

  /// True when Play will run its own download-and-install flow in-app, so the
  /// Update button never has to send anyone to a listing page.
  final bool canUsePlayFlow;

  /// Where the Update button sends them when the in-app flow is unavailable.
  final String? storeUrl;

  /// "What's new", one item per line.
  final List<String> releaseNotes;

  /// "Google Play" or "App Store" — whichever this device installs from.
  final String storeName;

  final String appName;
  final String? iconUrl;
  final DateTime? releasedAt;
  final int? sizeBytes;
  final double? rating;
  final String? contentRating;
  final UpdateSource source;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.storeName,
    required this.appName,
    this.latestVersionCode,
    this.canUsePlayFlow = false,
    this.storeUrl,
    this.releaseNotes = const [],
    this.iconUrl,
    this.releasedAt,
    this.sizeBytes,
    this.rating,
    this.contentRating,
    this.source = UpdateSource.none,
  });

  /// Only worth showing when there is somewhere to send people. A prompt whose
  /// button does nothing is worse than no prompt.
  bool get isActionable =>
      updateAvailable && (canUsePlayFlow || (storeUrl ?? '').isNotEmpty);

  /// Identifies this release for "Not now".
  ///
  /// Usually the version name. Falls back to the versionCode, because a Play-
  /// only answer still has to be skippable exactly once — skipping on an empty
  /// string would suppress every future release as well.
  String get releaseKey => latestVersion.isNotEmpty
      ? latestVersion
      : 'code:${latestVersionCode ?? 'unknown'}';

  /// "1.0.1+25" reads as "1.0.1" to a member. The build number matters to the
  /// comparison, not to the person looking at it.
  String get prettyCurrentVersion => currentVersion.split('+').first;

  /// The published version name, or null when only Play answered and there is
  /// no name to show.
  String? get prettyLatestVersion {
    final name = latestVersion.split('+').first.trim();
    return name.isEmpty ? null : name;
  }

  /// "3.2 MB", or null when the store did not say. Google Play does not
  /// publish a download size on the listing page, and a made-up number on a
  /// screen that is asking someone to trust an update is not worth having.
  String? get prettySize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;

    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }

    final rounded = value >= 100 || unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return '$rounded ${units[unit]}';
  }
}

/// What the server, on its own, had to say.
@immutable
class _ServerVerdict {
  final String latestVersion;
  final String minimumVersion;
  final bool updateAvailable;
  final bool forceUpdate;
  final String storeUrl;
  final List<String> releaseNotes;

  const _ServerVerdict({
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.storeUrl,
    required this.releaseNotes,
  });

  /// True when an admin has actually published a version for this platform.
  /// A reachable server with an empty settings page is not an opinion.
  bool get isConfigured => latestVersion.isNotEmpty;

  static _ServerVerdict fromJson(Map<String, dynamic> json) {
    return _ServerVerdict(
      latestVersion: (json['latest_version']?.toString() ?? '').trim(),
      minimumVersion: (json['minimum_version']?.toString() ?? '').trim(),
      updateAvailable: json['update_available'] == true,
      forceUpdate: json['force_update'] == true,
      storeUrl: (json['store_url']?.toString() ?? '').trim(),
      releaseNotes: (json['release_notes'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

/// Why a check produced no prompt.
///
/// The first version of this returned a bare null for all of these, which made
/// "nothing appears" impossible to diagnose: a missing route, an admin who had
/// not filled the settings in, and a genuinely up-to-date app all looked
/// identical from the outside. Naming the outcomes is what lets the Settings
/// screen say something true.
enum UpdateCheckOutcome {
  /// Newer build published, with a way to get it.
  updateAvailable,

  /// Asked and answered — this is the latest build.
  upToDate,

  /// Nothing could name a published version. Not an error; an unknown.
  notConfigured,

  /// Could not reach anything at all.
  failed,
}

class AppUpdateCheck {
  final UpdateCheckOutcome outcome;
  final AppUpdateInfo? info;

  /// Why, in a sentence a person can act on. Every one of these is written to
  /// be readable by a member, not just a developer, because the manual check
  /// in Settings shows it verbatim — someone who explicitly asked deserves the
  /// real answer rather than "try again later".
  final String? detail;

  /// The raw request and response for each of the three sources, for a
  /// long-press in Settings.
  final String? diagnostics;

  const AppUpdateCheck(
    this.outcome, {
    this.info,
    this.detail,
    this.diagnostics,
  });

  bool get hasUpdate => outcome == UpdateCheckOutcome.updateAvailable;
}

/// Compares dotted version strings.
///
/// The rules match the server's implementation exactly, on purpose:
///
///   * Compared as dotted numbers, so "1.0.10" is above "1.0.9".
///   * Missing parts read as zero, so "1.1" and "1.1.0" are the same release.
///   * A "+build" suffix only breaks a tie between equal dotted parts, which
///     is what makes a hotfix shipped as 1.0.1+26 newer than 1.0.1+25.
///
/// Store versions never carry a build suffix, so comparing a running
/// "1.0.1+25" against a published "1.0.1" is a tie rather than a downgrade —
/// which is the behaviour you want, since a listing has no idea what build
/// number went into the release it is serving.
class VersionCompare {
  const VersionCompare._();

  /// -1 when [a] is older than [b], 0 when they are the same, 1 when newer.
  static int compare(String a, String b) {
    final left = _split(a);
    final right = _split(b);

    final length = math.max(left.parts.length, right.parts.length);

    for (var i = 0; i < length; i++) {
      final l = i < left.parts.length ? left.parts[i] : 0;
      final r = i < right.parts.length ? right.parts[i] : 0;
      if (l != r) return l < r ? -1 : 1;
    }

    if (left.build != right.build) return left.build < right.build ? -1 : 1;
    return 0;
  }

  /// True when [candidate] is a later release than [current].
  static bool isNewer(String candidate, String current) =>
      compare(current, candidate) < 0;

  /// The leading number, e.g. 1 for "1.0.2".
  static int majorOf(String version) => _split(version).parts.first;

  /// The number after the "+", e.g. 25 for "1.0.1+25".
  static int buildOf(String version) => _split(version).build;

  static ({List<int> parts, int build}) _split(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return (parts: const <int>[0], build: 0);

    final halves = trimmed.split('+');
    final parts = halves.first
        .split('.')
        .map((piece) => int.tryParse(piece.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList(growable: false);

    final build = halves.length > 1
        ? (int.tryParse(halves[1].replaceAll(RegExp(r'\D'), '')) ?? 0)
        : 0;

    return (parts: parts.isEmpty ? const <int>[0] : parts, build: build);
  }
}

/// Decides whether this build is out of date, and remembers what the user
/// already said about it.
///
/// THREE SOURCES, IN ORDER OF HOW MUCH THEY CAN BE TRUSTED
///
/// 1. GOOGLE PLAY'S IN-APP UPDATES API (Android). The only supported way for
///    an app to learn that Play has a newer build. Play answers directly, and
///    can run the download and install itself. It answers ONLY for an app
///    installed from Play — a debug or sideloaded build always gets
///    ERROR_API_NOT_AVAILABLE, which is why the other two are not redundant.
///
/// 2. THE SERVER, /app-version. The only thing that can declare a build
///    unusable, because that decision has to be changeable for a version
///    already in people's hands. It is also what makes the feature testable
///    during development, where Play will not answer. It knows a version only
///    if an admin published one, or if the backend's own store lookup is
///    deployed and resolved one.
///
/// 3. THE STORE LISTING, read directly. Apple's lookup API is reliable;
///    Google's listing page is a best-effort read that frequently comes back
///    empty, because Play stopped putting the version in the served HTML.
///    Useful, never load-bearing.
///
/// Availability is Play's call when Play answers. The version *name* can only
/// come from 2 or 3, so a Play-only answer produces a prompt with no number in
/// it, which is correct and better than a wrong one.
///
/// HOW OFTEN THIS NAGS
///
/// An optional update is offered once, then not again for [_snoozeDuration]
/// unless a newer version appears. "Not now" records the release that was
/// skipped, so the same one is never offered twice but the next one still is;
/// a timestamp caps how often a *new* version can interrupt.
///
/// A forced update ignores both.
class AppUpdateService {
  AppUpdateService({
    required this.dio,
    StoreVersionService? storeService,
    PlayUpdateService? playService,
  }) : store = storeService ?? StoreVersionService(),
       play = playService ?? PlayUpdateService();

  final Dio dio;
  final StoreVersionService store;
  final PlayUpdateService play;

  static const String _skippedKey = 'app:update-skipped-version';
  static const String _lastPromptKey = 'app:update-last-prompt';
  static const Duration _snoozeDuration = Duration(days: 3);

  /// When nothing authoritative has set a policy — the server has no published
  /// version — should a newer release be treated as mandatory?
  ///
  /// True by default: this is a money app, an out-of-date build talks to an
  /// API that has moved on, and the whole reason this feature exists is that
  /// people were being left behind on old versions.
  ///
  /// Turn it off for a build with:
  ///
  ///     flutter build apk --dart-define=NIYA_FORCE_UPDATE=false
  ///
  /// It only applies when the server is silent. Once an admin sets a minimum
  /// version in the panel, the server's verdict wins in both directions.
  static const bool forceWhenServerSilent = bool.fromEnvironment(
    'NIYA_FORCE_UPDATE',
    defaultValue: true,
  );

  /// Pretend a newer version was published. For seeing the sheet without
  /// shipping a release — and the only way to exercise it in a debug build,
  /// since Play refuses to answer those:
  ///
  ///     flutter run --dart-define=NIYA_FAKE_STORE_VERSION=9.9.9
  ///
  /// Ignored in release builds, so it cannot escape into a published app.
  static const String _fakeStoreVersion = String.fromEnvironment(
    'NIYA_FAKE_STORE_VERSION',
  );

  PackageInfo? _packageInfo;

  Future<PackageInfo> _info() async =>
      _packageInfo ??= await PackageInfo.fromPlatform();

  /// The running version as "1.0.1+25" — the exact shape the server parses.
  Future<String> currentVersion() async {
    final info = await _info();
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  }

  /// Version without the build number, for display.
  Future<String> displayVersion() async =>
      (await currentVersion()).split('+').first;

  /// The application id / bundle identifier of the running build.
  Future<String> packageId() async => (await _info()).packageName;

  /// The app's own name, as the launcher shows it.
  Future<String> appName() async => (await _info()).appName;

  void _log(String message) {
    if (kDebugMode) debugPrint('[AppUpdate] $message');
  }

  /// The full URL the server check calls. Surfaced in diagnostics because a
  /// wrong base URL and a missing route look identical from inside the app.
  String get endpoint => '${dio.options.baseUrl}${AppEndpoints.appVersion()}';

  /// Hands control to Play's own full-screen update flow. Returns false when
  /// it could not start, so the caller can fall back to the listing.
  Future<bool> startPlayUpdate() => play.startImmediateUpdate();

  /// Asks all three sources and merges them. Always returns a result — never a
  /// bare null — so the caller can tell "up to date" from "could not ask".
  Future<AppUpdateCheck> check({bool forceRefresh = false}) async {
    String version;
    String package;
    String name;

    try {
      version = await currentVersion();
      package = await packageId();
      name = await appName();
    } catch (e) {
      // package_info_plus failing is a build problem, not a network one, and
      // it is worth being loud about: it silently disables the whole feature.
      _log('could not read the running build: $e');
      return AppUpdateCheck(
        UpdateCheckOutcome.failed,
        detail: 'Could not read this app\'s version.',
        diagnostics: 'PackageInfo.fromPlatform() threw:\n$e',
      );
    }

    final isIOS = Platform.isIOS;
    final platform = isIOS ? 'ios' : 'android';
    final storeName = isIOS ? 'App Store' : 'Google Play';

    // All three asked at once. They are independent, two of them are network
    // calls, and the launch prompt is on a timer. Started together, awaited
    // separately, so each keeps its own type.
    final playFuture = _askPlay(version);
    final serverFuture = _askServer(platform, version);
    final storeFuture = _askStore(package, forceRefresh: forceRefresh);

    final (playStatus, playDiagnostics) = await playFuture;
    final (serverVerdict, serverDiagnostics) = await serverFuture;
    final (storeRelease, storeDiagnostics) = await storeFuture;

    final diagnostics =
        '$playDiagnostics\n\n$serverDiagnostics\n\n$storeDiagnostics';

    // ---- version names ---------------------------------------------------

    // A version read off a web page is only trusted when it looks like a
    // release of THIS app. Play listings are full of unrelated numbers —
    // library versions, screen sizes, a user agent in an inline script — and
    // one bad match here would put a blocking screen in front of everyone.
    // "1.1" and "2.0" pass; "122.0.0.0" and "537.36" do not.
    final storeVersion =
        (storeRelease != null &&
            _isPlausibleRelease(version, storeRelease.version))
        ? storeRelease.version
        : null;

    if (storeRelease != null && storeVersion == null) {
      _log(
        'ignoring implausible store version "${storeRelease.version}" '
        'against running $version',
      );
    }

    final named = <String>[
      if (serverVerdict != null && serverVerdict.isConfigured)
        serverVerdict.latestVersion,
      if (storeVersion != null) storeVersion,
    ];

    // Whichever source names the higher version wins. An admin who publishes
    // to the store and forgets the panel is covered by the listing; an admin
    // who needs to name a version the store is still rolling out is covered by
    // the panel.
    var latest = '';
    for (final candidate in named) {
      if (latest.isEmpty || VersionCompare.isNewer(candidate, latest)) {
        latest = candidate;
      }
    }

    // ---- availability ----------------------------------------------------

    final serverSpoke = serverVerdict != null && serverVerdict.isConfigured;
    final storeSpoke = storeVersion != null;
    final playSaysAvailable = playStatus?.available == true;
    final playSaysUpToDate = playStatus?.upToDate == true;

    final namedUpdate = latest.isNotEmpty && VersionCompare.isNewer(
      latest,
      version,
    );

    // Play is the ground truth when it answers. The other two can still name a
    // release Play has not offered this device yet — a staged rollout, or a
    // version an admin is pushing ahead of the store — so they can add an
    // update that Play has not mentioned, but not take one away.
    final updateAvailable = playSaysAvailable || namedUpdate;

    // A prompt has to lead somewhere. Play's in-app flow needs no URL at all;
    // otherwise the panel's link is preferred, then the listing's, and for
    // Android the listing URL is always constructible from the package id.
    final canUsePlayFlow = playSaysAvailable && playStatus!.immediateAllowed;

    final storeUrl = [
      if (serverVerdict != null && serverVerdict.storeUrl.isNotEmpty)
        serverVerdict.storeUrl,
      if (storeRelease != null) storeRelease.storeUrl,
      if (!isIOS) StoreVersionService.playUrlFor(package),
    ].firstWhere((url) => url.trim().isNotEmpty, orElse: () => '');

    // Admin-written notes are for members and are translated; the store's are
    // whatever went into the release listing. Prefer the former.
    final releaseNotes =
        (serverVerdict != null && serverVerdict.releaseNotes.isNotEmpty)
        ? serverVerdict.releaseNotes
        : (storeRelease?.releaseNotes ?? const <String>[]);

    final source = playSaysAvailable
        ? UpdateSource.playStore
        : serverSpoke && storeSpoke
        ? UpdateSource.serverAndStore
        : serverSpoke
        ? UpdateSource.server
        : storeSpoke
        ? UpdateSource.store
        : UpdateSource.none;

    // Forcing is the server's call whenever it has one, because that is the
    // only lever that can be pulled for a build already in people's hands.
    // Only when it has nothing to say does the local policy apply.
    //
    // A debug build is never blocked by a real release — being locked out of
    // the app you are working on is not a feature. The simulated version is
    // the way to exercise the forced sheet while developing.
    final localPolicyForces =
        forceWhenServerSilent &&
        (playSaysAvailable || storeSpoke) &&
        (!kDebugMode || _fakeStoreVersion.isNotEmpty);

    final forceUpdate =
        updateAvailable &&
        (canUsePlayFlow || storeUrl.isNotEmpty) &&
        (serverSpoke ? serverVerdict!.forceUpdate : localPolicyForces);

    final info = AppUpdateInfo(
      latestVersion: latest,
      latestVersionCode: playStatus?.availableVersionCode,
      currentVersion: version,
      updateAvailable: updateAvailable,
      forceUpdate: forceUpdate,
      canUsePlayFlow: canUsePlayFlow,
      storeName: storeRelease?.storeName ?? storeName,
      appName: storeRelease?.appName ?? name,
      storeUrl: storeUrl.isEmpty ? null : storeUrl,
      releaseNotes: releaseNotes,
      iconUrl: storeRelease?.iconUrl,
      releasedAt: storeRelease?.releasedAt,
      sizeBytes: storeRelease?.sizeBytes,
      rating: storeRelease?.rating,
      contentRating: storeRelease?.contentRating,
      source: source,
    );

    _log(
      'running=$version latest=${latest.isEmpty ? '(unnamed)' : latest} '
      'available=$updateAvailable force=$forceUpdate '
      'playFlow=$canUsePlayFlow source=${source.name}',
    );

    // ---- outcome ---------------------------------------------------------

    if (updateAvailable) {
      if (!info.isActionable) {
        return AppUpdateCheck(
          UpdateCheckOutcome.notConfigured,
          info: info,
          detail:
              'A newer version exists but there is no $storeName link to '
              'send you to. Set one in the admin panel under '
              'Settings → App Version.',
          diagnostics: diagnostics,
        );
      }

      return AppUpdateCheck(
        UpdateCheckOutcome.updateAvailable,
        info: info,
        diagnostics: diagnostics,
      );
    }

    // Somebody credible said this build is current.
    if (playSaysUpToDate || serverSpoke || storeSpoke) {
      return AppUpdateCheck(
        UpdateCheckOutcome.upToDate,
        info: info,
        diagnostics: diagnostics,
      );
    }

    // Nothing could name a version. Say exactly why, because "nothing
    // happened" with no reason attached is what made this hard to fix the
    // first time.
    final reachedNothing =
        playStatus == null && serverVerdict == null && storeRelease == null;

    return AppUpdateCheck(
      reachedNothing
          ? UpdateCheckOutcome.failed
          : UpdateCheckOutcome.notConfigured,
      info: info,
      detail: _explainUnknown(
        isIOS: isIOS,
        storeName: storeName,
        playReason: play.lastUnavailableReason,
        serverReached: serverVerdict != null,
        currentVersion: info.prettyCurrentVersion,
      ),
      diagnostics: diagnostics,
    );
  }

  /// The sentence a person sees when the check could not establish anything.
  ///
  /// Written to name the actual cause rather than apologise. Every branch here
  /// corresponds to a different fix, and saying which one applies is the whole
  /// difference between a five-minute fix and a week of guessing.
  String _explainUnknown({
    required bool isIOS,
    required String storeName,
    required String? playReason,
    required bool serverReached,
    required String currentVersion,
  }) {
    final buffer = StringBuffer('You are on $currentVersion. ');

    if (!isIOS && playReason != null) {
      buffer.write('$playReason ');
    } else {
      buffer.write('$storeName did not report a newer version. ');
    }

    buffer.write(
      serverReached
          ? 'The update service is reachable but has no version published '
                'yet — set it in the admin panel under Settings → App Version.'
          : 'The update service could not be reached either.',
    );

    return buffer.toString();
  }

  /// The Play leg. Never throws.
  Future<(PlayUpdateStatus?, String)> _askPlay(String version) async {
    // Debug-only override: pretend Play offered the next build, so the whole
    // flow can be walked through without publishing anything.
    if (kDebugMode && _fakeStoreVersion.isNotEmpty) {
      return (
        null,
        'PLAY    skipped — simulating a store release instead '
            '(--dart-define=NIYA_FAKE_STORE_VERSION=$_fakeStoreVersion)',
      );
    }

    if (!play.isSupported) {
      return (null, 'PLAY    not applicable on this platform');
    }

    final status = await play.check();

    if (status == null) {
      return (
        null,
        'PLAY    no answer\n'
            'Reason: ${play.lastUnavailableReason ?? 'unknown'}',
      );
    }

    return (
      status,
      'PLAY    answered\n'
          'Available: ${status.available}\n'
          'Running build: ${VersionCompare.buildOf(version)}\n'
          'Play build: ${status.availableVersionCode ?? 'not reported'}\n'
          'Immediate flow: ${status.immediateAllowed}\n'
          'Priority: ${status.priority}  Staleness: ${status.stalenessDays ?? '-'} day(s)',
    );
  }

  /// The server leg. Returns its verdict, or null when it could not answer,
  /// plus a block for the diagnostics dialog. Never throws.
  Future<(_ServerVerdict?, String)> _askServer(
    String platform,
    String version,
  ) async {
    final url = '$endpoint?platform=$platform&version=$version';

    try {
      final response = await dio.get(
        AppEndpoints.appVersion(),
        queryParameters: {'platform': platform, 'version': version},
      );

      final data = response.data?['data'];
      final trace =
          'SERVER  GET $url\n'
          'Status: ${response.statusCode}\n'
          'Body: ${_snippet(response.data)}';

      if (data is! Map) return (null, trace);

      final verdict = _ServerVerdict.fromJson(data.cast<String, dynamic>());

      return (
        verdict,
        verdict.isConfigured
            ? trace
            : '$trace\n'
                  '=> Reachable, but no version is published for $platform.',
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      _log('server check failed: $code ${e.message}');

      return (
        null,
        'SERVER  GET $url\n'
            'Status: ${code ?? 'no response'}\n'
            'Type: ${e.type.name}\n'
            'Message: ${e.message}\n'
            '${code == 404 ? '=> The /app-version route is missing. The backend needs deploying.\n' : ''}'
            'Body: ${_snippet(e.response?.data)}',
      );
    } catch (e) {
      _log('server check threw: $e');
      return (null, 'SERVER  GET $url\nThrew: $e');
    }
  }

  /// The listing leg. Never throws.
  Future<(StoreRelease?, String)> _askStore(
    String packageId, {
    bool forceRefresh = false,
  }) async {
    // Debug-only override, so the sheet can be seen without publishing.
    if (kDebugMode && _fakeStoreVersion.isNotEmpty) {
      return (
        StoreRelease(
          version: _fakeStoreVersion,
          storeUrl: Platform.isIOS
              ? 'https://apps.apple.com/app/id0'
              : StoreVersionService.playUrlFor(packageId),
          storeName: Platform.isIOS ? 'App Store' : 'Google Play',
          releaseNotes: const [
            'Simulated release, from --dart-define=NIYA_FAKE_STORE_VERSION.',
          ],
        ),
        'STORE   simulated version $_fakeStoreVersion (debug build only)',
      );
    }

    try {
      final release = await store.fetch(
        packageId: packageId,
        forceRefresh: forceRefresh,
      );

      if (release == null) {
        return (
          null,
          'STORE   $packageId\n'
              'No version could be read from the listing. Normal on Android: '
              'Play no longer puts the version in the page it serves.',
        );
      }

      return (
        release,
        'STORE   $packageId\n'
            'Version: ${release.version}\n'
            'Url: ${release.storeUrl}\n'
            'Notes: ${release.releaseNotes.length} line(s)',
      );
    } catch (e) {
      _log('store check threw: $e');
      return (null, 'STORE   $packageId\nThrew: $e');
    }
  }

  /// Guards against a mis-parsed store version.
  ///
  /// A genuine next release shares this build's major number or is exactly one
  /// ahead. Anything further away came from somewhere else on the page and is
  /// not something to act on, let alone block the app over.
  bool _isPlausibleRelease(String current, String candidate) {
    final currentMajor = VersionCompare.majorOf(current);
    final candidateMajor = VersionCompare.majorOf(candidate);

    return candidateMajor >= currentMajor && candidateMajor <= currentMajor + 1;
  }

  /// Response bodies can be an entire HTML error page. Enough to identify the
  /// problem, not enough to fill the screen.
  String _snippet(Object? body) {
    if (body == null) return 'null';
    final text = body.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 300 ? text : '${text.substring(0, 300)}…';
  }

  /// The launch-time path: checks, then decides whether this is a moment to
  /// interrupt. Returns null when it is not.
  Future<AppUpdateInfo?> checkForPrompt() async {
    final result = await check();

    if (!result.hasUpdate || result.info == null) {
      _log(
        'no prompt: ${result.outcome.name}'
        '${result.detail == null ? '' : ' — ${result.detail}'}',
      );
      return null;
    }

    final info = result.info!;

    // A build declared unusable always prompts, whatever the user said before.
    if (info.forceUpdate) return info;

    final skipped = AppCache.read<String>(_skippedKey);
    if (skipped == info.releaseKey) {
      _log('no prompt: ${info.releaseKey} was skipped by the user');
      return null;
    }

    final since = AppCache.ageOf(_lastPromptKey);
    if (since != null && since < _snoozeDuration) {
      _log('no prompt: last asked ${since.inHours}h ago');
      return null;
    }

    await AppCache.write(_lastPromptKey, DateTime.now().toIso8601String());

    return info;
  }

  /// "Not now" — do not offer this exact release again.
  Future<void> skip(String releaseKey) =>
      AppCache.write(_skippedKey, releaseKey);

  /// Clears the snooze and skip state so the next launch prompts again.
  /// Used by the manual check, where the user has explicitly asked.
  Future<void> resetPromptState() async {
    await AppCache.remove(_skippedKey);
    await AppCache.remove(_lastPromptKey);
  }
}
