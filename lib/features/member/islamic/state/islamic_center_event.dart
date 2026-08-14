import 'package:equatable/equatable.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';

abstract class IslamicCenterEvent extends Equatable {
  const IslamicCenterEvent();

  @override
  List<Object?> get props => [];
}

/// Loads cached location and computes today's times. Does not touch the GPS.
class IslamicCenterLoadEvent extends IslamicCenterEvent {
  final bool isSilent;
  const IslamicCenterLoadEvent({this.isSilent = false});

  @override
  List<Object?> get props => [isSilent];
}

/// Asks for a fresh GPS fix, then recomputes and re-arms the azan alarms.
class IslamicCenterRefreshLocationEvent extends IslamicCenterEvent {
  const IslamicCenterRefreshLocationEvent();
}

/// Applies a manually chosen city.
class IslamicCenterSetCityEvent extends IslamicCenterEvent {
  final SelectableCity city;
  const IslamicCenterSetCityEvent(this.city);

  @override
  List<Object?> get props => [city.name];
}

/// Persists a new calculation preference and reschedules.
class IslamicCenterUpdateSettingsEvent extends IslamicCenterEvent {
  final CalculationMethod? method;
  final AsrJuristic? asrJuristic;
  final PrayerAdjustments? adjustments;
  final int? hijriOffset;

  const IslamicCenterUpdateSettingsEvent({
    this.method,
    this.asrJuristic,
    this.adjustments,
    this.hijriOffset,
  });

  @override
  List<Object?> get props => [method?.key, asrJuristic, hijriOffset];
}

/// Flips one prayer's azan on or off.
class IslamicCenterToggleAzanEvent extends IslamicCenterEvent {
  final Prayer prayer;
  final bool enabled;

  const IslamicCenterToggleAzanEvent(this.prayer, this.enabled);

  @override
  List<Object?> get props => [prayer, enabled];
}

/// Global sound / vibration / pre-reminder switches.
class IslamicCenterUpdateAlertPrefsEvent extends IslamicCenterEvent {
  final bool? soundEnabled;
  final bool? vibrateEnabled;
  final int? preAzanMinutes;

  const IslamicCenterUpdateAlertPrefsEvent({
    this.soundEnabled,
    this.vibrateEnabled,
    this.preAzanMinutes,
  });

  @override
  List<Object?> get props => [soundEnabled, vibrateEnabled, preAzanMinutes];
}

/// Moves to another calendar day in the times view.
class IslamicCenterChangeDateEvent extends IslamicCenterEvent {
  final DateTime date;
  const IslamicCenterChangeDateEvent(this.date);

  @override
  List<Object?> get props => [date];
}
