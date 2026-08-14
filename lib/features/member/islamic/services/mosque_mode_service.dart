import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Dart face of the mosque-mode MethodChannel.
///
/// Drops the phone to vibrate a few minutes after each adhan so it does not
/// ring out during the congregation, then puts the ringer back automatically
/// and says so with a notification.
///
/// VIBRATE, NOT SILENT. An earlier version muted the phone completely and
/// switched Do Not Disturb on, which meant an urgent call was lost outright
/// and nothing that arrived during prayer was visible afterwards. Vibrate is
/// what people actually want: nothing audible, but the phone still taps your
/// leg and everything is waiting normally when you finish.
///
/// Everything that matters happens in Kotlin (android/app/src/main/kotlin/
/// com/niyaet/ekub/MosqueMode.kt). This class only hands over a list of
/// timestamps while the app is in the foreground; by the time the alarms fire
/// there is no Dart running at all. That was the point of doing it natively —
/// see the class comment on MosqueMode.kt.
///
/// iOS DOES NOTHING HERE, DELIBERATELY.
///
/// There is no public API on iOS to change the ringer switch, mute the device,
/// or toggle a Focus mode. Not restricted, not entitlement-gated: absent. Any
/// app claiming to do this on iPhone is either using a private API or is
/// really just asking the user to build a Shortcuts automation. [isSupported]
/// returns false there so the settings UI can hide the toggle rather than
/// offer something that silently never works.
class MosqueModeService {
  MosqueModeService._();

  static const MethodChannel _channel =
      MethodChannel('com.niyaet.ekub/mosque_mode');

  static void _log(Object? message) => debugPrint('[MosqueMode] $message');

  /// Whether the platform can do this at all.
  static bool get isSupported => Platform.isAndroid;

  /// Whether the user has granted Do Not Disturb access.
  ///
  /// No longer required for the feature to work — dropping to vibrate does not
  /// toggle Do Not Disturb, so it needs no special grant. It still matters in
  /// one case: a user who was already on silent when a window opened can only
  /// be put back on silent with this grant, and without it they come back on
  /// vibrate instead.
  ///
  /// Worth surfacing in settings as a refinement, but no longer as a blocker —
  /// the old build gated everything on it and did nothing at all when it was
  /// missing, which looked exactly like the feature being broken.
  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasDndAccess') ?? false;
    } on PlatformException catch (e) {
      _log('hasDndAccess failed — $e');
      return false;
    }
  }

  /// Opens the system Do Not Disturb access page.
  ///
  /// There is no runtime permission dialog for this grant; sending the user to
  /// settings is the only route.
  static Future<void> openPermissionSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('openDndSettings');
    } on PlatformException catch (e) {
      _log('openDndSettings failed — $e');
    }
  }

  /// Arms one vibrate window per entry in [prayerTimes], each offset by
  /// [delay] and lasting [duration].
  ///
  /// Replaces any previously armed alarms, so call it on every reschedule.
  /// Past times are dropped natively rather than firing immediately.
  ///
  /// The notification copy is resolved HERE, in the foreground, and handed to
  /// the native side to store. It cannot be resolved when the alarm fires:
  /// there is no Flutter engine alive at that moment, so GetX translations are
  /// unreachable and the text would fall back to English for every user.
  static Future<int> schedule({
    required List<DateTime> prayerTimes,
    Duration delay = const Duration(minutes: 5),
    Duration duration = const Duration(minutes: 30),
  }) async {
    if (!isSupported) return 0;

    final triggers = prayerTimes
        .map((t) => t.add(delay).millisecondsSinceEpoch)
        .toList(growable: false);

    try {
      final count = await _channel.invokeMethod<int>('schedule', {
        'triggerAtMillis': triggers,
        'durationMinutes': duration.inMinutes,
        'onTitle': 'mosque_mode_on_title'.tr,
        // Carries a literal {time} placeholder. The native side swaps in the
        // window's end time formatted to the device's own 12h/24h setting,
        // which Dart cannot know at scheduling time.
        'onBody': 'mosque_mode_on_body'.tr,
        'offTitle': 'mosque_mode_off_title'.tr,
        'offBody': 'mosque_mode_off_body'.tr,
      });
      _log('armed ${count ?? 0} vibrate windows '
          '(+${delay.inMinutes}min, ${duration.inMinutes}min long)');
      return count ?? 0;
    } on PlatformException catch (e) {
      _log('schedule failed — $e');
      return 0;
    }
  }

  /// Cancels every armed alarm and lifts a window currently in force.
  ///
  /// The native side deliberately does both. Cancelling alone would kill the
  /// pending restore alarm and strand a phone on vibrate with nothing left to
  /// put the ringer back.
  static Future<void> cancelAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('cancelAll');
    } on PlatformException catch (e) {
      _log('cancelAll failed — $e');
    }
  }

  /// Whether a vibrate window is open right now. Drives the settings banner.
  static Future<bool> isCurrentlySilenced() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isCurrentlySilenced') ?? false;
    } on PlatformException catch (e) {
      _log('isCurrentlySilenced failed — $e');
      return false;
    }
  }

  /// Manual escape hatch: restore the ringer immediately.
  static Future<void> restoreNow() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('restoreNow');
    } on PlatformException catch (e) {
      _log('restoreNow failed — $e');
    }
  }
}
