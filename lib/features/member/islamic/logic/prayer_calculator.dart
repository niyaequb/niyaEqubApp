import 'dart:math' as math;

/// Offline astronomical prayer-time engine.
///
/// This is a self-contained implementation of the standard solar-position
/// algorithm used by PrayTimes.org / the Adhan family of libraries. It runs
/// entirely on-device: no network, no API key, no rate limit. That matters
/// because the azan alarms are scheduled days in advance and must keep firing
/// when the phone is offline or in airplane mode.
///
/// All angles are handled in degrees; helpers convert to radians only at the
/// trigonometric boundary.
enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerX on Prayer {
  /// Stable key used for translations, prefs and notification ids.
  String get key => switch (this) {
    Prayer.fajr => 'fajr',
    Prayer.sunrise => 'sunrise',
    Prayer.dhuhr => 'dhuhr',
    Prayer.asr => 'asr',
    Prayer.maghrib => 'maghrib',
    Prayer.isha => 'isha',
  };

  /// Sunrise (Shurooq) is a time marker, not a prayer — it never gets an azan.
  bool get isAdhanPrayer => this != Prayer.sunrise;

  /// Deterministic notification id base, so re-scheduling replaces rather than
  /// duplicates. Offset by day-of-year in the scheduler.
  int get notificationBase => switch (this) {
    Prayer.fajr => 1000,
    Prayer.sunrise => 2000,
    Prayer.dhuhr => 3000,
    Prayer.asr => 4000,
    Prayer.maghrib => 5000,
    Prayer.isha => 6000,
  };
}

/// How Asr is derived: shadow length equal to the object (Shafi'i, Maliki,
/// Hanbali) or twice the object (Hanafi).
enum AsrJuristic { standard, hanafi }

/// Angle conventions published by the major calculation authorities.
class CalculationMethod {
  final String key;
  final String label;
  final double fajrAngle;
  final double ishaAngle;

  /// When > 0, Isha is a fixed number of minutes after Maghrib and
  /// [ishaAngle] is ignored (Umm al-Qura convention).
  final int ishaInterval;

  /// Minutes added to true solar noon before Dhuhr is announced.
  final double dhuhrMinutes;

  const CalculationMethod({
    required this.key,
    required this.label,
    required this.fajrAngle,
    required this.ishaAngle,
    this.ishaInterval = 0,
    this.dhuhrMinutes = 1,
  });

  static const muslimWorldLeague = CalculationMethod(
    key: 'mwl',
    label: 'Muslim World League',
    fajrAngle: 18,
    ishaAngle: 17,
  );

  static const egyptian = CalculationMethod(
    key: 'egypt',
    label: 'Egyptian General Authority',
    fajrAngle: 19.5,
    ishaAngle: 17.5,
  );

  static const karachi = CalculationMethod(
    key: 'karachi',
    label: 'University of Islamic Sciences, Karachi',
    fajrAngle: 18,
    ishaAngle: 18,
  );

  static const ummAlQura = CalculationMethod(
    key: 'umm_al_qura',
    label: 'Umm al-Qura, Makkah',
    fajrAngle: 18.5,
    ishaAngle: 0,
    ishaInterval: 90,
  );

  static const dubai = CalculationMethod(
    key: 'dubai',
    label: 'Dubai',
    fajrAngle: 18.2,
    ishaAngle: 18.2,
  );

  static const isna = CalculationMethod(
    key: 'isna',
    label: 'Islamic Society of North America',
    fajrAngle: 15,
    ishaAngle: 15,
  );

  static const qatar = CalculationMethod(
    key: 'qatar',
    label: 'Qatar',
    fajrAngle: 18,
    ishaAngle: 0,
    ishaInterval: 90,
  );

  static const kuwait = CalculationMethod(
    key: 'kuwait',
    label: 'Kuwait',
    fajrAngle: 18,
    ishaAngle: 17.5,
  );

  static const List<CalculationMethod> all = [
    muslimWorldLeague,
    egyptian,
    karachi,
    ummAlQura,
    dubai,
    isna,
    qatar,
    kuwait,
  ];

  static CalculationMethod fromKey(String? key) {
    return all.firstWhere(
      (m) => m.key == key,
      orElse: () => muslimWorldLeague,
    );
  }
}

/// The six computed daily times, already converted to the device's local zone.
class PrayerTimes {
  final DateTime date;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const PrayerTimes({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  DateTime timeFor(Prayer prayer) => switch (prayer) {
    Prayer.fajr => fajr,
    Prayer.sunrise => sunrise,
    Prayer.dhuhr => dhuhr,
    Prayer.asr => asr,
    Prayer.maghrib => maghrib,
    Prayer.isha => isha,
  };

  /// Ordered pairs, handy for rendering the times row.
  List<MapEntry<Prayer, DateTime>> get ordered => [
    MapEntry(Prayer.fajr, fajr),
    MapEntry(Prayer.sunrise, sunrise),
    MapEntry(Prayer.dhuhr, dhuhr),
    MapEntry(Prayer.asr, asr),
    MapEntry(Prayer.maghrib, maghrib),
    MapEntry(Prayer.isha, isha),
  ];

  /// Midpoint of the night — the boundary many scholars give for delaying Isha.
  DateTime get midnight {
    final nightLength = fajr.add(const Duration(days: 1)).difference(maghrib);
    return maghrib.add(Duration(seconds: nightLength.inSeconds ~/ 2));
  }

  /// Start of the last third of the night (tahajjud).
  DateTime get lastThird {
    final nightLength = fajr.add(const Duration(days: 1)).difference(maghrib);
    return maghrib.add(
      Duration(seconds: (nightLength.inSeconds * 2) ~/ 3),
    );
  }

  /// The next upcoming entry relative to [now], or null if Isha has passed.
  MapEntry<Prayer, DateTime>? nextAfter(DateTime now) {
    for (final entry in ordered) {
      if (entry.value.isAfter(now)) return entry;
    }
    return null;
  }

  /// The prayer the user is waiting for, and how long until it.
  ///
  /// Wraps past Isha to tomorrow's Fajr rather than returning nothing, so
  /// callers never have to special-case late evening. This is the single
  /// source of truth for both the hero countdown and the highlight in the
  /// times row — deriving "next" separately in each is exactly how those two
  /// ended up disagreeing, with the countdown showing Isha while the row
  /// highlighted Maghrib.
  ({Prayer prayer, Duration remaining}) upcomingAt(DateTime now) {
    final next = nextAfter(now);

    if (next != null) {
      final remaining = next.value.difference(now);
      return (
        prayer: next.key,
        remaining: remaining.isNegative ? Duration.zero : remaining,
      );
    }

    // Isha has passed. Tomorrow's Fajr is within a minute or two of today's
    // plus a day, which is close enough for a countdown; the exact value is
    // recomputed once the date rolls over.
    final remaining = fajr.add(const Duration(days: 1)).difference(now);
    return (
      prayer: Prayer.fajr,
      remaining: remaining.isNegative ? Duration.zero : remaining,
    );
  }

  /// The prayer whose window is currently in force.
  ///
  /// Not used for the times-row highlight — that tracks [upcomingAt] instead,
  /// since "which prayer is next" is what a glance at the row should answer.
  /// Kept for logic that genuinely needs the current window, such as deciding
  /// which azkar set to suggest.
  Prayer currentAt(DateTime now) {
    Prayer current = Prayer.isha;
    for (final entry in ordered) {
      if (!entry.value.isAfter(now)) {
        current = entry.key;
      }
    }
    return current;
  }
}

/// Per-prayer manual correction in minutes, for matching the local masjid.
class PrayerAdjustments {
  final int fajr;
  final int sunrise;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;

  const PrayerAdjustments({
    this.fajr = 0,
    this.sunrise = 0,
    this.dhuhr = 0,
    this.asr = 0,
    this.maghrib = 0,
    this.isha = 0,
  });

  int forPrayer(Prayer p) => switch (p) {
    Prayer.fajr => fajr,
    Prayer.sunrise => sunrise,
    Prayer.dhuhr => dhuhr,
    Prayer.asr => asr,
    Prayer.maghrib => maghrib,
    Prayer.isha => isha,
  };

  PrayerAdjustments copyWith({
    int? fajr,
    int? sunrise,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
  }) => PrayerAdjustments(
    fajr: fajr ?? this.fajr,
    sunrise: sunrise ?? this.sunrise,
    dhuhr: dhuhr ?? this.dhuhr,
    asr: asr ?? this.asr,
    maghrib: maghrib ?? this.maghrib,
    isha: isha ?? this.isha,
  );

  Map<String, dynamic> toJson() => {
    'fajr': fajr,
    'sunrise': sunrise,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
  };

  factory PrayerAdjustments.fromJson(Map<String, dynamic> json) =>
      PrayerAdjustments(
        fajr: (json['fajr'] ?? 0) as int,
        sunrise: (json['sunrise'] ?? 0) as int,
        dhuhr: (json['dhuhr'] ?? 0) as int,
        asr: (json['asr'] ?? 0) as int,
        maghrib: (json['maghrib'] ?? 0) as int,
        isha: (json['isha'] ?? 0) as int,
      );
}

class PrayerCalculator {
  /// Standard refraction-corrected solar depression at sunrise/sunset.
  static const double _sunsetAngle = 0.833;

  /// Computes the six times for [date] at ([latitude], [longitude]).
  ///
  /// [date] is interpreted in the device's local zone, and the returned
  /// DateTimes are local too, so they can be compared against DateTime.now()
  /// and handed to the notification scheduler directly.
  static PrayerTimes calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    CalculationMethod method = CalculationMethod.muslimWorldLeague,
    AsrJuristic asr = AsrJuristic.standard,
    PrayerAdjustments adjustments = const PrayerAdjustments(),
  }) {
    final day = DateTime(date.year, date.month, date.day);

    // Device offset from UTC, in hours, for this specific date. Reading it per
    // date rather than caching keeps DST transitions honest.
    final tzOffset = day.timeZoneOffset.inMinutes / 60.0;

    // Julian day for local solar noon at this longitude.
    final jd = _julianDay(day) - longitude / (15.0 * 24.0);
    final sun = _sunPosition(jd);
    final decl = sun.declination;
    final eqt = sun.equationOfTime;

    // True solar noon expressed in local clock hours.
    final noon = 12.0 + tzOffset - longitude / 15.0 - eqt;

    double? beforeNoon(double angle) {
      final t = _hourAngle(angle, latitude, decl);
      return t == null ? null : noon - t;
    }

    double? afterNoon(double angle) {
      final t = _hourAngle(angle, latitude, decl);
      return t == null ? null : noon + t;
    }

    // Asr: the sun angle at which an object's shadow reaches the juristic
    // multiple of its own length, plus the noon shadow.
    final shadowFactor = asr == AsrJuristic.hanafi ? 2.0 : 1.0;
    final asrAngle = -_atanDeg(
      1.0 / (shadowFactor + _tanDeg((latitude - decl).abs())),
    );

    final fajrHour = beforeNoon(method.fajrAngle);
    final sunriseHour = beforeNoon(_sunsetAngle);
    final dhuhrHour = noon + method.dhuhrMinutes / 60.0;
    final asrHour = afterNoon(asrAngle);
    final maghribHour = afterNoon(_sunsetAngle);
    final ishaHour = method.ishaInterval > 0
        ? (maghribHour == null
              ? null
              : maghribHour + method.ishaInterval / 60.0)
        : afterNoon(method.ishaAngle);

    // At extreme latitudes the sun never reaches the Fajr/Isha depression and
    // the hour angle is undefined. Fall back to the "one-seventh of the night"
    // rule so the UI still has something sane to show.
    final resolvedSunrise = sunriseHour ?? (noon - 6);
    final resolvedMaghrib = maghribHour ?? (noon + 6);
    final nightLength = 24 - (resolvedMaghrib - resolvedSunrise);
    final resolvedFajr = fajrHour ?? (resolvedSunrise - nightLength / 7);
    final resolvedIsha = ishaHour ?? (resolvedMaghrib + nightLength / 7);
    final resolvedAsr = asrHour ?? (noon + 3);

    DateTime build(double hour, Prayer prayer) {
      final base = _hoursToDateTime(day, hour);
      return base.add(Duration(minutes: adjustments.forPrayer(prayer)));
    }

    return PrayerTimes(
      date: day,
      fajr: build(resolvedFajr, Prayer.fajr),
      sunrise: build(resolvedSunrise, Prayer.sunrise),
      dhuhr: build(dhuhrHour, Prayer.dhuhr),
      asr: build(resolvedAsr, Prayer.asr),
      maghrib: build(resolvedMaghrib, Prayer.maghrib),
      isha: build(resolvedIsha, Prayer.isha),
    );
  }

  /// Convenience wrapper producing [days] consecutive days starting at [from].
  /// Used by the scheduler, which pre-books a rolling window of alarms.
  static List<PrayerTimes> calculateRange({
    required DateTime from,
    required int days,
    required double latitude,
    required double longitude,
    CalculationMethod method = CalculationMethod.muslimWorldLeague,
    AsrJuristic asr = AsrJuristic.standard,
    PrayerAdjustments adjustments = const PrayerAdjustments(),
  }) {
    return List.generate(days, (i) {
      return calculate(
        date: DateTime(from.year, from.month, from.day + i),
        latitude: latitude,
        longitude: longitude,
        method: method,
        asr: asr,
        adjustments: adjustments,
      );
    });
  }

  // ---------------------------------------------------------------------
  // Astronomy
  // ---------------------------------------------------------------------

  static double _julianDay(DateTime date) {
    int year = date.year;
    int month = date.month;
    final double day = date.day.toDouble();

    if (month <= 2) {
      year -= 1;
      month += 12;
    }

    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();

    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static _SunPosition _sunPosition(double jd) {
    final d = jd - 2451545.0;

    // Mean anomaly and mean longitude of the sun.
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);

    // Apparent ecliptic longitude, first two equation-of-centre terms.
    final l = _fixAngle(q + 1.915 * _sinDeg(g) + 0.020 * _sinDeg(2 * g));

    // Obliquity of the ecliptic.
    final e = 23.439 - 0.00000036 * d;

    final declination = _asinDeg(_sinDeg(e) * _sinDeg(l));

    // Right ascension in hours.
    var ra = _atan2Deg(_cosDeg(e) * _sinDeg(l), _cosDeg(l)) / 15.0;
    ra = _fixHour(ra);

    final equationOfTime = q / 15.0 - ra;

    return _SunPosition(declination: declination, equationOfTime: equationOfTime);
  }

  /// Hours from solar noon at which the sun sits [angle] degrees below the
  /// horizon. Returns null when the sun never reaches that depression.
  static double? _hourAngle(double angle, double latitude, double declination) {
    final numerator =
        -_sinDeg(angle) - _sinDeg(declination) * _sinDeg(latitude);
    final denominator = _cosDeg(declination) * _cosDeg(latitude);

    if (denominator == 0) return null;

    final ratio = numerator / denominator;
    if (ratio > 1 || ratio < -1) return null;

    return _acosDeg(ratio) / 15.0;
  }

  static DateTime _hoursToDateTime(DateTime day, double hours) {
    // Guard against the fallback branches producing out-of-range values.
    var h = hours;
    var dayShift = 0;
    while (h < 0) {
      h += 24;
      dayShift -= 1;
    }
    while (h >= 24) {
      h -= 24;
      dayShift += 1;
    }

    final totalSeconds = (h * 3600).round();
    return DateTime(
      day.year,
      day.month,
      day.day + dayShift,
    ).add(Duration(seconds: totalSeconds));
  }

  // ---------------------------------------------------------------------
  // Degree-based trig helpers
  // ---------------------------------------------------------------------

  static double _deg2rad(double d) => d * math.pi / 180.0;
  static double _rad2deg(double r) => r * 180.0 / math.pi;

  static double _sinDeg(double d) => math.sin(_deg2rad(d));
  static double _cosDeg(double d) => math.cos(_deg2rad(d));
  static double _tanDeg(double d) => math.tan(_deg2rad(d));
  static double _asinDeg(double x) => _rad2deg(math.asin(x));
  static double _acosDeg(double x) => _rad2deg(math.acos(x));
  static double _atanDeg(double x) => _rad2deg(math.atan(x));
  static double _atan2Deg(double y, double x) => _rad2deg(math.atan2(y, x));

  static double _fixAngle(double a) {
    var v = a - 360.0 * (a / 360.0).floor();
    if (v < 0) v += 360.0;
    return v;
  }

  static double _fixHour(double h) {
    var v = h - 24.0 * (h / 24.0).floor();
    if (v < 0) v += 24.0;
    return v;
  }
}

class _SunPosition {
  final double declination;
  final double equationOfTime;
  const _SunPosition({
    required this.declination,
    required this.equationOfTime,
  });
}
