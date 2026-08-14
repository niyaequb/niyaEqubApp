import 'dart:convert';

import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the Islamic Center needs to remember between launches.
///
/// Deliberately kept on SharedPreferences rather than Hive: the background
/// notification isolate needs to read the saved location and method to
/// re-arm alarms, and SharedPreferences is already initialised there.
class IslamicPrefs {
  static SharedPreferences? _prefs;

  static const _kLatitude = 'islamic_latitude';
  static const _kLongitude = 'islamic_longitude';
  static const _kCityName = 'islamic_city_name';
  static const _kCountryName = 'islamic_country_name';
  static const _kMethod = 'islamic_calc_method';
  static const _kAsr = 'islamic_asr_juristic';
  static const _kAdjustments = 'islamic_adjustments';
  static const _kHijriOffset = 'islamic_hijri_offset';
  static const _kAzanEnabledPrefix = 'islamic_azan_';
  static const _kAzanSoundEnabled = 'islamic_azan_sound';
  static const _kPreAzanMinutes = 'islamic_pre_azan_minutes';
  static const _kVibrate = 'islamic_azan_vibrate';
  static const _kReciter = 'islamic_reciter';
  static const _kTranslation = 'islamic_translation';
  static const _kArabicFontSize = 'islamic_arabic_font_size';
  static const _kTranslationFontSize = 'islamic_translation_font_size';
  static const _kLastReadSurah = 'islamic_last_read_surah';
  static const _kLastReadAyah = 'islamic_last_read_ayah';
  static const _kBookmarks = 'islamic_bookmarks';
  static const _kTasbihSessions = 'islamic_tasbih_sessions';
  static const _kTasbihLifetime = 'islamic_tasbih_lifetime';
  static const _kMosqueMode = 'islamic_mosque_mode';
  static const _kMosqueDelay = 'islamic_mosque_delay_minutes';
  static const _kMosqueDuration = 'islamic_mosque_duration_minutes';
  static const _kOnboarded = 'islamic_onboarded';

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<SharedPreferences> get _p async {
    await initialize();
    return _prefs!;
  }

  // ------------------------------------------------------------------
  // Location
  // ------------------------------------------------------------------

  static Future<void> saveLocation({
    required double latitude,
    required double longitude,
    String? city,
    String? country,
  }) async {
    final p = await _p;
    await p.setDouble(_kLatitude, latitude);
    await p.setDouble(_kLongitude, longitude);
    if (city != null) await p.setString(_kCityName, city);
    if (country != null) await p.setString(_kCountryName, country);
  }

  static Future<double?> getLatitude() async => (await _p).getDouble(_kLatitude);
  static Future<double?> getLongitude() async =>
      (await _p).getDouble(_kLongitude);

  static Future<String> getCity() async =>
      (await _p).getString(_kCityName) ?? 'Addis Ababa';

  static Future<String> getCountry() async =>
      (await _p).getString(_kCountryName) ?? 'Ethiopia';

  static Future<bool> hasLocation() async {
    final p = await _p;
    return p.containsKey(_kLatitude) && p.containsKey(_kLongitude);
  }

  // ------------------------------------------------------------------
  // Calculation preferences
  // ------------------------------------------------------------------

  static Future<CalculationMethod> getMethod() async {
    final p = await _p;
    return CalculationMethod.fromKey(p.getString(_kMethod));
  }

  static Future<void> setMethod(CalculationMethod method) async {
    await (await _p).setString(_kMethod, method.key);
  }

  static Future<AsrJuristic> getAsrJuristic() async {
    final p = await _p;
    return p.getString(_kAsr) == 'hanafi'
        ? AsrJuristic.hanafi
        : AsrJuristic.standard;
  }

  static Future<void> setAsrJuristic(AsrJuristic value) async {
    await (await _p).setString(
      _kAsr,
      value == AsrJuristic.hanafi ? 'hanafi' : 'standard',
    );
  }

  static Future<PrayerAdjustments> getAdjustments() async {
    final raw = (await _p).getString(_kAdjustments);
    if (raw == null) return const PrayerAdjustments();
    try {
      return PrayerAdjustments.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PrayerAdjustments();
    }
  }

  static Future<void> setAdjustments(PrayerAdjustments value) async {
    await (await _p).setString(_kAdjustments, jsonEncode(value.toJson()));
  }

  static Future<int> getHijriOffset() async =>
      (await _p).getInt(_kHijriOffset) ?? 0;

  static Future<void> setHijriOffset(int value) async {
    await (await _p).setInt(_kHijriOffset, value.clamp(-2, 2));
  }

  // ------------------------------------------------------------------
  // Azan notification preferences
  // ------------------------------------------------------------------

  /// Per-prayer azan toggle. All five default to on.
  static Future<bool> isAzanEnabled(Prayer prayer) async {
    if (!prayer.isAdhanPrayer) {
      // Sunrise gets a silent reminder only, off by default.
      return (await _p).getBool('$_kAzanEnabledPrefix${prayer.key}') ?? false;
    }
    return (await _p).getBool('$_kAzanEnabledPrefix${prayer.key}') ?? true;
  }

  static Future<void> setAzanEnabled(Prayer prayer, bool enabled) async {
    await (await _p).setBool('$_kAzanEnabledPrefix${prayer.key}', enabled);
  }

  /// When false the notification still fires, but silently.
  static Future<bool> isAzanSoundEnabled() async =>
      (await _p).getBool(_kAzanSoundEnabled) ?? true;

  static Future<void> setAzanSoundEnabled(bool value) async {
    await (await _p).setBool(_kAzanSoundEnabled, value);
  }

  static Future<bool> isVibrateEnabled() async =>
      (await _p).getBool(_kVibrate) ?? true;

  static Future<void> setVibrateEnabled(bool value) async {
    await (await _p).setBool(_kVibrate, value);
  }

  /// Optional "prayer is in N minutes" heads-up. 0 disables it.
  static Future<int> getPreAzanMinutes() async =>
      (await _p).getInt(_kPreAzanMinutes) ?? 0;

  static Future<void> setPreAzanMinutes(int minutes) async {
    await (await _p).setInt(_kPreAzanMinutes, minutes.clamp(0, 60));
  }

  // ------------------------------------------------------------------
  // Quran preferences
  // ------------------------------------------------------------------

  static Future<String> getReciterId() async =>
      (await _p).getString(_kReciter) ?? 'alafasy';

  static Future<void> setReciterId(String id) async {
    await (await _p).setString(_kReciter, id);
  }

  static Future<String> getTranslationId() async =>
      (await _p).getString(_kTranslation) ?? 'en';

  static Future<void> setTranslationId(String id) async {
    await (await _p).setString(_kTranslation, id);
  }

  static Future<double> getArabicFontSize() async =>
      (await _p).getDouble(_kArabicFontSize) ?? 26.0;

  static Future<void> setArabicFontSize(double size) async {
    await (await _p).setDouble(_kArabicFontSize, size.clamp(18.0, 44.0));
  }

  static Future<double> getTranslationFontSize() async =>
      (await _p).getDouble(_kTranslationFontSize) ?? 14.0;

  static Future<void> setTranslationFontSize(double size) async {
    await (await _p).setDouble(_kTranslationFontSize, size.clamp(11.0, 24.0));
  }

  static Future<void> saveLastRead(int surah, int ayah) async {
    final p = await _p;
    await p.setInt(_kLastReadSurah, surah);
    await p.setInt(_kLastReadAyah, ayah);
  }

  static Future<({int surah, int ayah})?> getLastRead() async {
    final p = await _p;
    final surah = p.getInt(_kLastReadSurah);
    if (surah == null) return null;
    return (surah: surah, ayah: p.getInt(_kLastReadAyah) ?? 1);
  }

  /// Bookmarks stored as "surah:ayah" strings.
  static Future<List<String>> getBookmarks() async =>
      (await _p).getStringList(_kBookmarks) ?? <String>[];

  static Future<bool> toggleBookmark(int surah, int ayah) async {
    final p = await _p;
    final list = p.getStringList(_kBookmarks) ?? <String>[];
    final key = '$surah:$ayah';
    final wasBookmarked = list.contains(key);

    if (wasBookmarked) {
      list.remove(key);
    } else {
      list.add(key);
    }

    await p.setStringList(_kBookmarks, list);
    return !wasBookmarked;
  }

  // ------------------------------------------------------------------
  // Tasbih
  // ------------------------------------------------------------------

  /// Saved counter sessions, encoded as JSON.
  static Future<List<Map<String, dynamic>>> getTasbihSessions() async {
    final raw = (await _p).getString(_kTasbihSessions);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> setTasbihSessions(
    List<Map<String, dynamic>> sessions,
  ) async {
    await (await _p).setString(_kTasbihSessions, jsonEncode(sessions));
  }

  static Future<int> getTasbihLifetime() async =>
      (await _p).getInt(_kTasbihLifetime) ?? 0;

  static Future<void> addTasbihLifetime(int delta) async {
    final p = await _p;
    final current = p.getInt(_kTasbihLifetime) ?? 0;
    await p.setInt(_kTasbihLifetime, (current + delta).clamp(0, 1 << 40));
  }

  // ------------------------------------------------------------------
  // Mosque mode
  // ------------------------------------------------------------------

  /// Off by default, deliberately.
  ///
  /// This feature mutes the user's ringer. Turning that on for someone who
  /// never asked for it is how an app makes them miss a call and uninstall.
  /// It also needs a Do Not Disturb grant that only the user can give, so
  /// defaulting to on would just mean a switch that claims to be enabled
  /// while silently doing nothing.
  static Future<bool> isMosqueModeEnabled() async =>
      (await _p).getBool(_kMosqueMode) ?? false;

  static Future<void> setMosqueModeEnabled(bool value) async {
    await (await _p).setBool(_kMosqueMode, value);
  }

  /// Minutes after the adhan before the phone goes silent.
  ///
  /// Defaults to 5: long enough to hear the adhan itself and reach the
  /// mosque, short enough to be silent before the iqamah.
  static Future<int> getMosqueModeDelayMinutes() async =>
      (await _p).getInt(_kMosqueDelay) ?? 5;

  static Future<void> setMosqueModeDelayMinutes(int minutes) async {
    await (await _p).setInt(_kMosqueDelay, minutes.clamp(0, 30));
  }

  /// How long the phone stays silent. Defaults to 30 minutes.
  ///
  /// Clamped to 120 at the top. There is no "until I turn it off" option and
  /// there should not be: the restore alarm is the only thing standing
  /// between this feature and a permanently muted phone.
  static Future<int> getMosqueModeDurationMinutes() async =>
      (await _p).getInt(_kMosqueDuration) ?? 30;

  static Future<void> setMosqueModeDurationMinutes(int minutes) async {
    await (await _p).setInt(_kMosqueDuration, minutes.clamp(5, 120));
  }

  // ------------------------------------------------------------------

  static Future<bool> isOnboarded() async =>
      (await _p).getBool(_kOnboarded) ?? false;

  static Future<void> setOnboarded(bool value) async {
    await (await _p).setBool(_kOnboarded, value);
  }
}
