import 'package:hijri/hijri_calendar.dart';

/// Hijri conversion for the Ibada Center.
///
/// WHY THIS USES A LOOKUP TABLE AND NOT A FORMULA
///
/// This class used to compute dates with the Kuwaiti algorithm — the tabular
/// (arithmetic) Islamic calendar, which assigns 30-day and 29-day months on a
/// fixed 30-year leap cycle. It is elegant, offline and completely
/// deterministic, and it was wrong on screen.
///
/// On 14 August 2026 it produced "29 Safar 1448". The correct Umm al-Qura date
/// is 1 Rabi' al-Awwal 1448 — the day Rabi' al-Awwal actually began. Two days
/// out, on the date shown under the prayer times.
///
/// That is not a bug in the arithmetic; it is the arithmetic working exactly
/// as designed. A fixed leap cycle cannot track the moon, because the motions
/// of the sun and moon are not linear. The tabular calendar is documented to
/// drift from Umm al-Qura by one or even two days in either direction, and no
/// amount of correcting the formula changes that — the drift is the method.
///
/// Umm al-Qura is not computed at all. It is a published table of month
/// starts, fixed in advance from 1356 AH (March 1937) to 1500 AH (November
/// 2077), and it is what Saudi Arabia, IslamicFinder, Aladhan and every
/// printed calendar in the region agree on. The `hijri` package ships that
/// table, so a lookup gives the same answer those sources give.
///
/// ON FETCHING IT FROM AN API INSTEAD
///
/// A network call would return the same numbers, because the online
/// converters are reading this same table. It would also mean the date under
/// the prayer times is blank on a phone with no signal — and prayer times
/// themselves work offline, so the date would be the one thing that did not.
/// The table is small, exact, and already on the device. Nothing is gained by
/// asking a server for it.
///
/// [dayOffset] is still here and still matters. Umm al-Qura is the Saudi
/// sighting; a community in Ethiopia may announce a day either side of it, and
/// the setting lets a user match their own mosque.
class HijriDate {
  final int year;
  final int month; // 1..12
  final int day; // 1..30

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  static const List<String> monthNamesEn = [
    'Muharram',
    'Safar',
    "Rabi' al-Awwal",
    "Rabi' al-Thani",
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  static const List<String> monthNamesAr = [
    'مُحَرَّم',
    'صَفَر',
    'رَبيع الأوّل',
    'رَبيع الآخر',
    'جُمادى الأولى',
    'جُمادى الآخرة',
    'رَجَب',
    'شَعْبان',
    'رَمَضان',
    'شَوّال',
    'ذو القِعْدة',
    'ذو الحِجّة',
  ];

  String get monthNameEn => monthNamesEn[(month - 1).clamp(0, 11)];
  String get monthNameAr => monthNamesAr[(month - 1).clamp(0, 11)];

  /// e.g. "1 Rabi' al-Awwal 1448"
  String get formatted => '$day $monthNameEn $year';

  /// e.g. "١ رَبيع الأوّل ١٤٤٨" — Arabic-Indic digits, for the Arabic locale.
  String get formattedAr =>
      '${_toArabicDigits(day)} $monthNameAr ${_toArabicDigits(year)}';

  /// True during Ramadan — used to surface the fasting-specific widgets.
  bool get isRamadan => month == 9;

  /// The window the Umm al-Qura table covers, expressed in Gregorian years.
  ///
  /// 1356 AH began in March 1937 and 1500 AH ends in November 2077. Outside
  /// this range the table has nothing to say, and the tabular algorithm —
  /// imprecise but unbounded — is a better answer than a thrown exception or
  /// a silently clamped date. In practice nothing in this app looks outside
  /// it; the fallback exists so that a birth-date picker or a far-future
  /// calendar view can never crash the screen.
  static const int _firstSupportedYear = 1938;
  static const int _lastSupportedYear = 2076;

  /// Converts a Gregorian date to Hijri. [dayOffset] shifts the result by a
  /// whole number of days before conversion (typically -1, 0 or +1).
  factory HijriDate.fromGregorian(DateTime date, {int dayOffset = 0}) {
    final shifted = DateTime(date.year, date.month, date.day + dayOffset);

    if (shifted.year >= _firstSupportedYear &&
        shifted.year <= _lastSupportedYear) {
      try {
        final h = HijriCalendar.fromDate(shifted);

        // Sanity-check before trusting it. A lookup that falls off the end of
        // the table can come back as zeroes rather than throwing, and a date
        // reading "0 Muharram 0" on the home screen is worse than one that is
        // merely a day out.
        if (h.hYear > 0 && h.hMonth >= 1 && h.hMonth <= 12 && h.hDay >= 1) {
          return HijriDate(year: h.hYear, month: h.hMonth, day: h.hDay);
        }
      } catch (_) {
        // Fall through to the arithmetic calendar below.
      }
    }

    return _tabularFromGregorian(shifted);
  }

  /// Converts back, so the calendar screen can highlight a Hijri day.
  DateTime toGregorian({int dayOffset = 0}) {
    try {
      final g = HijriCalendar().hijriToGregorian(year, month, day);
      if (g.year >= _firstSupportedYear && g.year <= _lastSupportedYear) {
        return DateTime(g.year, g.month, g.day - dayOffset);
      }
    } catch (_) {
      // Fall through.
    }

    final jd = _hijriToJulianDay(this);
    final g = _julianDayToGregorian(jd);
    return DateTime(g.year, g.month, g.day - dayOffset);
  }

  @override
  String toString() => formatted;

  // ---------------------------------------------------------------------
  // Tabular fallback
  //
  // Retained, not deleted. It is wrong by a day or two against Umm al-Qura,
  // which is why it is no longer the primary path — but it works for any date
  // in history, and an approximate date beyond 2076 beats a crash.
  // ---------------------------------------------------------------------

  static HijriDate _tabularFromGregorian(DateTime date) {
    return _julianDayToHijri(_gregorianToJulianDay(date));
  }

  static int _gregorianToJulianDay(DateTime date) {
    int year = date.year;
    int month = date.month;
    final int day = date.day;

    if (month < 3) {
      year -= 1;
      month += 12;
    }

    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();

    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;
  }

  static _G _julianDayToGregorian(int jd) {
    final a = jd + 32044;
    final b = ((4 * a + 3) / 146097).floor();
    final c = a - ((146097 * b) / 4).floor();
    final d = ((4 * c + 3) / 1461).floor();
    final e = c - ((1461 * d) / 4).floor();
    final m = ((5 * e + 2) / 153).floor();

    final day = e - ((153 * m + 2) / 5).floor() + 1;
    final month = m + 3 - 12 * (m / 10).floor();
    final year = 100 * b + d - 4800 + (m / 10).floor();

    return _G(year, month, day);
  }

  /// Kuwaiti algorithm — the widely used arithmetic approximation.
  static HijriDate _julianDayToHijri(int jd) {
    final l0 = jd - 1948440 + 10632;
    final n = ((l0 - 1) / 10631).floor();
    var l = l0 - 10631 * n + 354;

    final j =
        ((10985 - l) / 5316).floor() * ((50 * l) / 17719).floor() +
        (l / 5670).floor() * ((43 * l) / 15238).floor();

    l =
        l -
        ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
        (j / 16).floor() * ((15238 * j) / 43).floor() +
        29;

    final month = ((24 * l) / 709).floor();
    final day = l - ((709 * month) / 24).floor();
    final year = 30 * n + j - 30;

    return HijriDate(year: year, month: month, day: day);
  }

  static int _hijriToJulianDay(HijriDate h) {
    return ((11 * h.year + 3) / 30).floor() +
        354 * h.year +
        30 * h.month -
        ((h.month - 1) / 2).floor() +
        h.day +
        1948440 -
        385;
  }

  static String _toArabicDigits(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((c) {
          final i = int.tryParse(c);
          return i == null ? c : digits[i];
        })
        .join();
  }
}

class _G {
  final int year;
  final int month;
  final int day;
  const _G(this.year, this.month, this.day);
}
