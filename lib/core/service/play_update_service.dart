import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart' as play;

/// What Google Play itself says about this particular install.
///
/// Deliberately a plain value object rather than the plugin's own type, so the
/// rest of the app never imports in_app_update and nothing outside this file
/// has to care that the API is Android-only.
@immutable
class PlayUpdateStatus {
  /// Play has a newer build for this device, right now.
  final bool available;

  /// Play answered, and this device is on the newest build. This is the only
  /// genuinely authoritative "you are up to date" the app can get on Android.
  final bool upToDate;

  /// The versionCode of the build waiting on Play — the number after the "+"
  /// in pubspec's `version:`. Play has no way to report the version *name*.
  final int? availableVersionCode;

  /// Whether Play will run its own full-screen update flow in-app.
  final bool immediateAllowed;
  final bool flexibleAllowed;

  /// 0–5, set per release in the Play Developer API. Google's intended signal
  /// for "how hard should the app push this".
  final int priority;

  /// How long this device has been behind. Google's other intended signal.
  final int? stalenessDays;

  const PlayUpdateStatus({
    required this.available,
    required this.upToDate,
    required this.availableVersionCode,
    required this.immediateAllowed,
    required this.flexibleAllowed,
    required this.priority,
    required this.stalenessDays,
  });

  /// True when Play answered at all — which already tells us this build came
  /// from the store rather than a sideload.
  bool get answered => available || upToDate;
}

/// Google Play's In-App Updates API, wrapped so every failure is survivable.
///
/// WHY THIS IS THE PRIMARY SOURCE ON ANDROID
///
/// There is no public API that reports the version on a Play listing, and the
/// listing page stopped reliably carrying the version number in its served
/// HTML. Reading it is therefore a guess that fails silently — which is
/// exactly what produced "No published version could be found for android".
///
/// This API is the supported answer. Play tells the app directly whether the
/// device is behind, and can run the download and install itself without ever
/// leaving the app.
///
/// THE ONE LIMITATION THAT MATTERS
///
/// It only answers for an app installed from Play. A debug build, a
/// `flutter run` build, or a sideloaded APK gets ERROR_API_NOT_AVAILABLE every
/// time. So this cannot be tested locally, and the server check underneath it
/// is not redundant — it is how the feature works during development and how
/// an admin forces an upgrade on a build already in the wild.
class PlayUpdateService {
  /// Why the last check returned nothing. Surfaced in the Settings
  /// diagnostics, because "Play said nothing" and "Play is not reachable from
  /// this build" are very different problems with the same symptom.
  String? lastUnavailableReason;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  void _log(String message) {
    if (kDebugMode) debugPrint('[PlayUpdate] $message');
  }

  /// Asks Play. Returns null when Play could not be asked at all.
  Future<PlayUpdateStatus?> check() async {
    lastUnavailableReason = null;

    if (!isSupported) {
      lastUnavailableReason = 'Not an Android build.';
      return null;
    }

    try {
      final info = await play.InAppUpdate.checkForUpdate();

      final availability = info.updateAvailability;
      final available =
          availability == play.UpdateAvailability.updateAvailable ||
          availability ==
              play.UpdateAvailability.developerTriggeredUpdateInProgress;
      final upToDate =
          availability == play.UpdateAvailability.updateNotAvailable;

      if (!available && !upToDate) {
        lastUnavailableReason =
            'Play returned "unknown" — usually a device with no Play '
            'Services, or an app that was not installed from the store.';
        _log(lastUnavailableReason!);
        return null;
      }

      _log(
        'availability=$availability code=${info.availableVersionCode} '
        'immediate=${info.immediateUpdateAllowed} '
        'priority=${info.updatePriority} '
        'stale=${info.clientVersionStalenessDays}',
      );

      return PlayUpdateStatus(
        available: available,
        upToDate: upToDate,
        availableVersionCode: info.availableVersionCode,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
        priority: info.updatePriority,
        stalenessDays: info.clientVersionStalenessDays,
      );
    } catch (e) {
      // ERROR_API_NOT_AVAILABLE is the expected, normal answer for any build
      // that did not come from Play. It is not worth a crash report and not
      // worth showing to a member.
      final text = e.toString();

      lastUnavailableReason = text.contains('ERROR_API_NOT_AVAILABLE')
          ? 'This build was not installed from Google Play, so Play cannot '
                'report updates for it. Expected for debug and sideloaded '
                'builds.'
          : 'Play could not be asked: $text';

      _log(lastUnavailableReason!);
      return null;
    }
  }

  /// Runs Play's own full-screen update: it downloads, installs and restarts
  /// the app without the user ever reaching the store listing.
  ///
  /// Returns false when the flow could not start or the user backed out, so
  /// the caller can fall back to opening the listing.
  Future<bool> startImmediateUpdate() async {
    if (!isSupported) return false;

    try {
      await play.InAppUpdate.performImmediateUpdate();
      return true;
    } catch (e) {
      _log('immediate update failed: $e');
      return false;
    }
  }
}
