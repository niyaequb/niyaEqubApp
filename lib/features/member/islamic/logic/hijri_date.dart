/// Offline Hijri conversion using the tabular (arithmetic) Islamic calendar.
///
/// The tabular calendar is deterministic, which is exactly what a scheduler
/// needs — but it can differ from local moon sighting by a day. [dayOffset]
/// lets the user nudge it to match the announcement of their own community,
/// which is how every serious prayer app handles this.
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

  /// e.g. "16 Safar 1448"
  String get formatted => '$day $monthNameEn $year';

  /// e.g. "١٦ صَفَر ١٤٤٨" — Arabic-Indic digits, for the Arabic locale.
  String get formattedAr =>
      '${_toArabicDigits(day)} $monthNameAr ${_toArabicDigits(year)}';

  /// Converts a Gregorian date to Hijri. [dayOffset] shifts the result by a
  /// whole number of days before conversion (typically -1, 0 or +1).
  factory HijriDate.fromGregorian(DateTime date, {int dayOffset = 0}) {
    final shifted = DateTime(date.year, date.month, date.day + dayOffset);
    final jd = _gregorianToJulianDay(shifted);
    return _julianDayToHijri(jd);
  }

  /// Converts back, so the calendar screen can highlight a Hijri day.
  DateTime toGregorian({int dayOffset = 0}) {
    final jd = _hijriToJulianDay(this);
    final g = _julianDayToGregorian(jd);
    return DateTime(g.year, g.month, g.day - dayOffset);
  }

  /// True during Ramadan — used to surface the fasting-specific widgets.
  bool get isRamadan => month == 9;

  @override
  String toString() => formatted;

  // ---------------------------------------------------------------------

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
