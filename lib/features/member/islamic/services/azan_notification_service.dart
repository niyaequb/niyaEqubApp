import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:niya_equb/features/member/islamic/services/mosque_mode_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Deliberately NOT core/util/logger.dart.
///
/// That logger opens with `if (!kDebugMode) return;`, so every diagnostic in
/// this file evaporated in exactly the build where the azan was broken. A
/// scheduled adhan cannot be observed from a debug session — the whole point
/// is that it fires hours later, from a process Dart is not running in — so
/// release logging is the only way to see anything.
///
/// debugPrint survives release builds (the name is misleading; only
/// kDebugMode-guarded code is tree-shaken). Read it with:
///
///     adb logcat -s flutter:V
void _log(Object? message) => debugPrint('[Azan] $message');

/// Schedules and displays the five daily azan notifications.
///
/// Two mechanisms work together:
///
///   * **Local exact alarms** are the primary trigger. Prayer times are
///     computed on-device, so a rolling window of alarms can be booked days
///     ahead and will still fire with no network, in airplane mode, or with
///     the app force-stopped. This is what every serious prayer app does.
///   * **Firebase push** is layered on top for anything the server wants to
///     announce — a jama'ah change, a community Ramadan schedule, an Eid
///     takbir. Push is not used as the primary azan trigger because FCM makes
///     no delivery-time guarantee, and an azan that arrives four minutes late
///     is worse than none.
///
/// Both paths render through the same channels, so the sound, vibration and
/// full-screen behaviour are identical whichever one fires.
class AzanNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// How many days of alarms to keep booked. Seven days is 35 alarms, well
  /// inside Android's pending-intent budget, and gives a wide margin before
  /// the user next opens the app.
  static const int scheduleWindowDays = 7;

  /// Bump this when the channel's sound or importance changes — Android
  /// freezes a channel's settings at creation, so the id has to change for
  /// users to pick up the new configuration.
  ///
  /// v1 -> v2: added AudioAttributesUsage.alarm. Anyone who already ran v1 has
  /// a channel frozen on the notification stream and would never hear the
  /// change without a new id.
  static const String azanChannelId = 'azan_channel_v2';
  static const String azanSilentChannelId = 'azan_silent_channel_v2';
  static const String preAzanChannelId = 'pre_azan_channel_v2';

  /// Retired ids, deleted at startup so the app's notification settings do not
  /// accumulate a dead "Azan (Prayer Call)" row per version.
  static const List<String> _retiredChannelIds = [
    'azan_channel_v1',
    'azan_silent_channel_v1',
    'pre_azan_channel_v1',
  ];

  /// Filename (without extension) of the adhan in android/app/src/main/res/raw.
  static const String azanSoundName = 'azan';

  static bool _timezoneReady = false;

  // ------------------------------------------------------------------
  // Setup
  // ------------------------------------------------------------------

  /// Call once during app start, after Firebase is up.
  static Future<void> initialize() async {
    await _ensureTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        _log('notification tapped: ${response.payload}');
      },
    );

    await _createChannels();
    await _requestPlatformPermissions();
  }

  static Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;

    tzdata.initializeTimeZones();

    try {
      // flutter_timezone 4.x returns the IANA name directly as a String.
      // 5.x wraps it in a TimezoneInfo and this becomes `name.identifier` —
      // the type is annotated explicitly so bumping the constraint fails here
      // at compile time instead of somewhere subtler.
      final String name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // Falling back to UTC does not shift the adhan. Prayer times are local
      // DateTimes, and tz.TZDateTime.from preserves the absolute instant when
      // it converts — Android schedules on epoch millis, and iOS builds its
      // trigger from the matching UTC components plus the UTC zone. The zone
      // only really matters for recurring triggers, which this does not use.
      _log('could not resolve IANA timezone, falling back to UTC — $e');
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    }

    _timezoneReady = true;
  }

  static Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    // Named parameter, unlike createNotificationChannel() below, which takes
    // its argument positionally. That inconsistency is real in the plugin's
    // API, not a typo — v21 converted some methods on this class to named
    // arguments and left others alone. Signature per the 21.0.0 docs:
    //   deleteNotificationChannel({required String channelId})
    //   createNotificationChannel(AndroidNotificationChannel notificationChannel)
    for (final id in _retiredChannelIds) {
      try {
        await android.deleteNotificationChannel(channelId: id);
      } catch (_) {
        // Nothing to delete on a fresh install. Not worth reporting.
      }
    }

    // The loud one, with the adhan as its sound.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        azanChannelId,
        'Azan (Prayer Call)',
        description:
            'Plays the adhan at each of the five daily prayer times.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(azanSoundName),
        // Routes the adhan through the ALARM stream instead of the
        // notification stream. Without this the call to prayer is governed by
        // notification volume — which many people keep low or at zero — and is
        // muted outright by Do Not Disturb, including the Bedtime schedule
        // that covers Fajr for most users. The rest of this class already
        // treats the azan as an alarm (category: alarm, full-screen intent);
        // this is the piece that makes the audio agree.
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // Same alert, no sound — for users who want the banner only.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        azanSilentChannelId,
        'Prayer Time (Silent)',
        description: 'Prayer time alerts without the adhan sound.',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      ),
    );

    // The "prayer in N minutes" heads-up.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        preAzanChannelId,
        'Prayer Reminder',
        description: 'Advance reminder before each prayer time.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  static Future<void> _requestPlatformPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Only the standard runtime dialog here. The exact-alarm grant is
      // deliberately NOT requested at start-up: on Android 12+ it launches a
      // full system settings screen, and doing that from main() before
      // runApp() dumps a first-time user into Android settings before they
      // have seen the app at all. It is requested from the prayer settings
      // screen instead, where the user has asked for it.
      await android?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Opens the Android exact-alarm settings screen, then reports whether the
  /// grant is now in place. Call this from a user-initiated action only.
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      _log('exact alarm request failed — $e');
    }

    final granted = await canScheduleExactAlarms();

    // Alarms booked while the grant was missing are inexact. Re-book them now
    // that we can be precise.
    if (granted) await rescheduleAll();

    return granted;
  }

  /// True when the OS will let us fire at an exact instant. The settings
  /// screen surfaces this so the user can fix it rather than silently getting
  /// a late adhan.
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  // ------------------------------------------------------------------
  // Scheduling
  // ------------------------------------------------------------------

  /// Recomputes prayer times and re-books the whole rolling window.
  ///
  /// Safe to call often — it cancels the previous window first, and the ids
  /// are deterministic, so repeated calls converge rather than pile up.
  static Future<void> rescheduleAll() async {
    try {
      await _ensureTimezone();

      final location = await IslamicLocationService.cachedOrDefault();
      final method = await IslamicPrefs.getMethod();
      final asr = await IslamicPrefs.getAsrJuristic();
      final adjustments = await IslamicPrefs.getAdjustments();
      final soundEnabled = await IslamicPrefs.isAzanSoundEnabled();
      final vibrate = await IslamicPrefs.isVibrateEnabled();
      final preMinutes = await IslamicPrefs.getPreAzanMinutes();

      await cancelAll();

      final now = DateTime.now();
      final schedule = PrayerCalculator.calculateRange(
        from: now,
        days: scheduleWindowDays,
        latitude: location.latitude,
        longitude: location.longitude,
        method: method,
        asr: asr,
        adjustments: adjustments,
      );

      // Resolve the per-prayer toggles once rather than per day.
      final enabled = <Prayer, bool>{};
      for (final prayer in Prayer.values) {
        enabled[prayer] = await IslamicPrefs.isAzanEnabled(prayer);
      }

      var booked = 0;

      for (final day in schedule) {
        for (final entry in day.ordered) {
          final prayer = entry.key;
          final time = entry.value;

          if (enabled[prayer] != true) continue;
          if (!time.isAfter(now)) continue;

          final dayKey = _dayKey(time);

          await _scheduleOne(
            id: prayer.notificationBase + dayKey,
            title: _titleFor(prayer),
            body: _bodyFor(prayer, time, location.city),
            when: time,
            channelId: soundEnabled && prayer.isAdhanPrayer
                ? azanChannelId
                : azanSilentChannelId,
            playSound: soundEnabled && prayer.isAdhanPrayer,
            vibrate: vibrate,
            fullScreen: soundEnabled && prayer.isAdhanPrayer,
            payload: {
              'type': 'azan',
              'prayer': prayer.key,
              'time': time.toIso8601String(),
            },
          );
          booked++;

          if (preMinutes > 0 && prayer.isAdhanPrayer) {
            final reminderAt = time.subtract(Duration(minutes: preMinutes));
            if (reminderAt.isAfter(now)) {
              await _scheduleOne(
                id: prayer.notificationBase + dayKey + 500,
                title: '${_titleFor(prayer)} soon',
                body:
                    '${_prayerLabel(prayer)} is in $preMinutes minutes '
                    '(${_formatTime(time)}).',
                when: reminderAt,
                channelId: preAzanChannelId,
                playSound: true,
                vibrate: vibrate,
                fullScreen: false,
                payload: {
                  'type': 'pre_azan',
                  'prayer': prayer.key,
                  'time': time.toIso8601String(),
                },
              );
              booked++;
            }
          }
        }
      }

      await _armMosqueMode(schedule, enabled, now);

      _log('booked $booked notifications for ${location.label}');
    } catch (e, stack) {
      _log('rescheduleAll failed — $e');
      _log(stack);
    }
  }

  static Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String channelId,
    required bool playSound,
    required bool vibrate,
    required bool fullScreen,
    required Map<String, dynamic> payload,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == preAzanChannelId ? 'Prayer Reminder' : 'Azan (Prayer Call)',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: playSound,
      sound: playSound && channelId == azanChannelId
          ? const RawResourceAndroidNotificationSound(azanSoundName)
          : null,
      // Must match the channel. On Android 8+ the channel wins, but these
      // details are also what pre-Oreo devices and the full-screen path read.
      audioAttributesUsage: channelId == azanChannelId
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      enableVibration: vibrate,
      // A full-screen intent is what makes the adhan behave like an alarm
      // rather than a banner the user scrolls past.
      fullScreenIntent: fullScreen,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(body),
      autoCancel: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      // iOS wants the extension; keep a .caf copy next to the .wav.
      sound: playSound && channelId == azanChannelId ? 'azan.caf' : null,
      interruptionLevel: fullScreen
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode(payload),
      );
    } catch (e) {
      // Most likely the exact-alarm grant was revoked mid-session. Retry
      // inexactly rather than losing the notification entirely.
      _log('exact schedule failed for id $id, retrying inexact — $e');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode(payload),
        );
      } catch (e2) {
        _log('inexact schedule also failed for id $id — $e2');
      }
    }
  }

  /// Cancels every azan and reminder we own, leaving Equb notifications alone.
  ///
  /// Asks the platform which notifications are actually pending rather than
  /// blindly cancelling every id in the range. Sweeping the full space would
  /// be 6 prayers x 367 days x 2 = over four thousand platform-channel round
  /// trips, which visibly freezes the UI. In practice there are ~35 pending.
  static Future<void> cancelAll() async {
    await _cancelWhere((id) => _ownedIds.any((base) => _isInBand(id, base)));
  }

  /// Cancel just one prayer across the whole window — used when a toggle flips.
  static Future<void> cancelPrayer(Prayer prayer) async {
    await _cancelWhere((id) => _isInBand(id, prayer.notificationBase));
  }

  static List<int> get _ownedIds =>
      Prayer.values.map((p) => p.notificationBase).toList();

  /// Ids run from base to base+366 for the azan and base+500 to base+866 for
  /// the matching reminder, so one band covers both.
  static bool _isInBand(int id, int base) => id >= base && id <= base + 866;

  static Future<void> _cancelWhere(bool Function(int id) predicate) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (predicate(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (e) {
      _log('could not enumerate pending notifications — $e');
    }
  }

  /// Fires the adhan immediately, so the user can hear what they signed up for
  /// before trusting it at 5am.
  static Future<void> previewAzan({String? prayerLabel}) async {
    final soundEnabled = await IslamicPrefs.isAzanSoundEnabled();
    final vibrate = await IslamicPrefs.isVibrateEnabled();

    await _plugin.show(
      id: 99001,
      title: 'Azan preview',
      body: prayerLabel == null
          ? 'This is how the prayer call will sound and look.'
          : 'This is how the $prayerLabel notification will appear.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          soundEnabled ? azanChannelId : azanSilentChannelId,
          'Azan (Prayer Call)',
          importance: Importance.max,
          priority: Priority.high,
          playSound: soundEnabled,
          sound: soundEnabled
              ? const RawResourceAndroidNotificationSound(azanSoundName)
              : null,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: vibrate,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: soundEnabled,
          sound: soundEnabled ? 'azan.caf' : null,
        ),
      ),
      payload: jsonEncode({'type': 'azan_preview'}),
    );
  }

  /// Arms the mosque-mode silence windows alongside the azan alarms.
  ///
  /// Deliberately driven off the SAME computed schedule and the same per-
  /// prayer toggles the adhan uses. Recomputing prayer times separately for
  /// this would let the two drift apart after a location or method change,
  /// and a phone that mutes itself at the wrong time is worse than one that
  /// does not mute at all.
  ///
  /// Only prayers with the azan switched on get a silence window: if the user
  /// has turned Fajr off, they are not going to the mosque for it.
  static Future<void> _armMosqueMode(
    List<PrayerTimes> schedule,
    Map<Prayer, bool> enabled,
    DateTime now,
  ) async {
    if (!MosqueModeService.isSupported) return;

    if (!await IslamicPrefs.isMosqueModeEnabled()) {
      // Also lifts a silence currently in force, so switching the feature off
      // mid-window cannot strand the ringer. See MosqueMode.kt.
      await MosqueModeService.cancelAll();
      return;
    }

    final times = <DateTime>[];
    for (final day in schedule) {
      for (final prayer in Prayer.values) {
        if (!prayer.isAdhanPrayer) continue;
        if (enabled[prayer] != true) continue;

        final at = day.timeFor(prayer);
        if (at.isAfter(now)) times.add(at);
      }
    }

    times.sort();

    // Capped well below the seven-day azan window. Each entry is a separate
    // AlarmManager pending intent, and there is no benefit to booking a mute
    // for next Thursday when rescheduleAll runs on every app open anyway.
    const maxWindows = 15;
    final capped = times.length > maxWindows
        ? times.sublist(0, maxWindows)
        : times;

    await MosqueModeService.schedule(
      prayerTimes: capped,
      delay: Duration(minutes: await IslamicPrefs.getMosqueModeDelayMinutes()),
      duration: Duration(
        minutes: await IslamicPrefs.getMosqueModeDurationMinutes(),
      ),
    );
  }

  /// Books a real scheduled azan [seconds] from now, through the exact same
  /// code path a 5am Fajr uses.
  ///
  /// previewAzan() cannot prove a release build works: it calls show(), which
  /// renders immediately from Dart while the engine is alive. The thing that
  /// breaks under R8 is the OTHER path — zonedSchedule() hands the whole
  /// notification to AlarmManager as Gson JSON, and
  /// ScheduledNotificationReceiver rebuilds it later with no Flutter engine in
  /// the process. A preview passing while scheduled azans stayed silent is
  /// exactly the symptom that hides this bug.
  ///
  /// Lock the phone after calling this. If nothing fires, check logcat for the
  /// receiver rather than assuming the schedule never landed.
  static Future<void> scheduleTestAzan({int seconds = 60}) async {
    await _ensureTimezone();

    final when = DateTime.now().add(Duration(seconds: seconds));
    _log('booking test azan for $when (exact alarms: '
        '${await canScheduleExactAlarms()})');

    await _scheduleOne(
      id: 99002,
      title: 'Test azan',
      body: 'If you can hear the adhan, scheduled notifications are working.',
      when: when,
      channelId: azanChannelId,
      playSound: true,
      vibrate: true,
      fullScreen: true,
      payload: {'type': 'azan_test'},
    );

    final pending = await _plugin.pendingNotificationRequests();
    _log('pending after booking: ${pending.length} '
        '(ids: ${pending.map((p) => p.id).take(10).join(', ')})');
  }

  // ------------------------------------------------------------------
  // Firebase push path
  // ------------------------------------------------------------------

  /// True when a push message is an azan/prayer announcement from the server.
  static bool isAzanMessage(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    return type == 'azan' ||
        type == 'prayer_time' ||
        type == 'pre_azan' ||
        type == 'islamic_announcement';
  }

  /// Renders a server-pushed azan through the same channel as a local one, so
  /// it sounds and behaves identically.
  ///
  /// Written to be callable from the background isolate — it creates its own
  /// plugin instance and channels rather than assuming [initialize] has run.
  static Future<void> showFromRemote(Map<String, dynamic> data) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();

      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // This definition MUST stay byte-for-byte equivalent to the one in
      // _createChannels(). Android freezes a channel's settings at creation
      // and silently ignores every later change, so whichever of the two runs
      // first on a given device wins forever. If a push landed before the user
      // ever opened the app, a mismatch here would permanently pin the adhan
      // to the notification stream.
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          azanChannelId,
          'Azan (Prayer Call)',
          description:
              'Plays the adhan at each of the five daily prayer times.',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(azanSoundName),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          enableLights: true,
        ),
      );

      final prayerKey = data['prayer']?.toString();
      final withSound = data['silent']?.toString() != 'true';

      final title =
          data['title']?.toString() ??
          (prayerKey == null
              ? 'Prayer time'
              : '${_labelForKey(prayerKey)} — time to pray');

      final body =
          data['body']?.toString() ??
          (prayerKey == null
              ? 'It is time for prayer.'
              : 'It is now time for ${_labelForKey(prayerKey)}.');

      await plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            withSound ? azanChannelId : azanSilentChannelId,
            'Azan (Prayer Call)',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            playSound: withSound,
            sound: withSound
                ? const RawResourceAndroidNotificationSound(azanSoundName)
                : null,
            audioAttributesUsage: withSound
                ? AudioAttributesUsage.alarm
                : AudioAttributesUsage.notification,
            fullScreenIntent: withSound,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: withSound,
            sound: withSound ? 'azan.caf' : null,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (e) {
      _log('showFromRemote failed — $e');
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Day-of-year, used to spread ids across the rolling window without
  /// colliding between prayers.
  static int _dayKey(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  static String _titleFor(Prayer prayer) {
    if (prayer == Prayer.sunrise) return 'Sunrise (Shurooq)';
    return '${_prayerLabel(prayer)} — time to pray';
  }

  static String _bodyFor(Prayer prayer, DateTime time, String city) {
    if (prayer == Prayer.sunrise) {
      return 'The sun has risen in $city at ${_formatTime(time)}. '
          'The time for Fajr has ended.';
    }
    return 'It is now ${_formatTime(time)} in $city. '
        'Hayya \'alas-salah — hasten to the prayer.';
  }

  static String _prayerLabel(Prayer prayer) => _labelForKey(prayer.key);

  static String _labelForKey(String key) => switch (key) {
    'fajr' => 'Fajr',
    'sunrise' => 'Sunrise',
    'dhuhr' => 'Dhuhr',
    'asr' => 'Asr',
    'maghrib' => 'Maghrib',
    'isha' => 'Isha',
    _ => 'Prayer',
  };

  static String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $suffix';
  }
}
