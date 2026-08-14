import 'package:equatable/equatable.dart';
import 'package:niya_equb/features/member/islamic/logic/hijri_date.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';

abstract class IslamicCenterState extends Equatable {
  const IslamicCenterState();

  @override
  List<Object?> get props => [];
}

class IslamicCenterInitial extends IslamicCenterState {
  const IslamicCenterInitial();
}

class IslamicCenterLoading extends IslamicCenterState {
  const IslamicCenterLoading();
}

class IslamicCenterReady extends IslamicCenterState {
  final IslamicLocation location;
  final DateTime selectedDate;
  final PrayerTimes times;
  final HijriDate hijri;

  final CalculationMethod method;
  final AsrJuristic asrJuristic;
  final PrayerAdjustments adjustments;
  final int hijriOffset;

  /// Per-prayer azan toggles.
  final Map<String, bool> azanEnabled;
  final bool soundEnabled;
  final bool vibrateEnabled;
  final int preAzanMinutes;

  /// False when Android has refused the exact-alarm grant — the UI surfaces a
  /// fix-it prompt rather than letting the adhan quietly drift.
  final bool canScheduleExact;

  /// Set when the last location attempt could not get a fresh fix. The screen
  /// still renders using the cached position; this just explains why.
  final LocationOutcome? locationIssue;

  /// True while a background refresh is in flight, for a subtle indicator.
  final bool isRefreshing;

  const IslamicCenterReady({
    required this.location,
    required this.selectedDate,
    required this.times,
    required this.hijri,
    required this.method,
    required this.asrJuristic,
    required this.adjustments,
    required this.hijriOffset,
    required this.azanEnabled,
    required this.soundEnabled,
    required this.vibrateEnabled,
    required this.preAzanMinutes,
    required this.canScheduleExact,
    this.locationIssue,
    this.isRefreshing = false,
  });

  bool isAzanOn(Prayer prayer) => azanEnabled[prayer.key] ?? false;

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  IslamicCenterReady copyWith({
    IslamicLocation? location,
    DateTime? selectedDate,
    PrayerTimes? times,
    HijriDate? hijri,
    CalculationMethod? method,
    AsrJuristic? asrJuristic,
    PrayerAdjustments? adjustments,
    int? hijriOffset,
    Map<String, bool>? azanEnabled,
    bool? soundEnabled,
    bool? vibrateEnabled,
    int? preAzanMinutes,
    bool? canScheduleExact,
    LocationOutcome? locationIssue,
    bool clearLocationIssue = false,
    bool? isRefreshing,
  }) {
    return IslamicCenterReady(
      location: location ?? this.location,
      selectedDate: selectedDate ?? this.selectedDate,
      times: times ?? this.times,
      hijri: hijri ?? this.hijri,
      method: method ?? this.method,
      asrJuristic: asrJuristic ?? this.asrJuristic,
      adjustments: adjustments ?? this.adjustments,
      hijriOffset: hijriOffset ?? this.hijriOffset,
      azanEnabled: azanEnabled ?? this.azanEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
      preAzanMinutes: preAzanMinutes ?? this.preAzanMinutes,
      canScheduleExact: canScheduleExact ?? this.canScheduleExact,
      locationIssue: clearLocationIssue
          ? null
          : (locationIssue ?? this.locationIssue),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    location.latitude,
    location.longitude,
    location.city,
    selectedDate,
    times.fajr,
    times.asr,
    times.isha,
    hijri.day,
    hijri.month,
    hijri.year,
    method.key,
    asrJuristic,
    hijriOffset,
    azanEnabled,
    soundEnabled,
    vibrateEnabled,
    preAzanMinutes,
    canScheduleExact,
    locationIssue,
    isRefreshing,
  ];
}

class IslamicCenterFailure extends IslamicCenterState {
  final String message;
  const IslamicCenterFailure(this.message);

  @override
  List<Object?> get props => [message];
}
