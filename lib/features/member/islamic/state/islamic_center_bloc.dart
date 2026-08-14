import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/islamic/logic/hijri_date.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_event.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_state.dart';

/// Owns prayer times, location and azan preferences.
///
/// Every mutation follows the same shape: persist, recompute, emit, then
/// re-arm the alarms. Rescheduling is deliberately fire-and-forget so a slow
/// AlarmManager call never blocks a toggle animation.
class IslamicCenterBloc extends Bloc<IslamicCenterEvent, IslamicCenterState> {
  IslamicCenterBloc() : super(const IslamicCenterInitial()) {
    on<IslamicCenterLoadEvent>(_onLoad);
    on<IslamicCenterRefreshLocationEvent>(_onRefreshLocation);
    on<IslamicCenterSetCityEvent>(_onSetCity);
    on<IslamicCenterUpdateSettingsEvent>(_onUpdateSettings);
    on<IslamicCenterToggleAzanEvent>(_onToggleAzan);
    on<IslamicCenterUpdateAlertPrefsEvent>(_onUpdateAlertPrefs);
    on<IslamicCenterChangeDateEvent>(_onChangeDate);
  }

  Future<void> _onLoad(
    IslamicCenterLoadEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    if (!event.isSilent && state is! IslamicCenterReady) {
      emit(const IslamicCenterLoading());
    }

    try {
      final ready = await _build(DateTime.now());
      emit(ready);

      // First run: nothing has ever been scheduled, so arm the window now.
      if (!await IslamicPrefs.isOnboarded()) {
        await IslamicPrefs.setOnboarded(true);
        _fireAndForget(AzanNotificationService.rescheduleAll());
      }
    } catch (e, stack) {
      logger('IslamicCenter: load failed — $e');
      logger(stack.toString());
      emit(
        const IslamicCenterFailure(
          'Could not work out prayer times. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRefreshLocation(
    IslamicCenterRefreshLocationEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    final current = state;
    if (current is IslamicCenterReady) {
      emit(current.copyWith(isRefreshing: true));
    }

    final result = await IslamicLocationService.refresh();

    try {
      final selected = current is IslamicCenterReady
          ? current.selectedDate
          : DateTime.now();

      final ready = await _build(
        selected,
        locationOverride: result.location,
        issue: result.isSuccess ? null : result.outcome,
      );

      emit(ready);
      _fireAndForget(AzanNotificationService.rescheduleAll());
    } catch (e) {
      logger('IslamicCenter: refresh failed — $e');
      if (current is IslamicCenterReady) {
        emit(current.copyWith(isRefreshing: false));
      }
    }
  }

  Future<void> _onSetCity(
    IslamicCenterSetCityEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    final location = await IslamicLocationService.setManualCity(event.city);
    final current = state;
    final selected = current is IslamicCenterReady
        ? current.selectedDate
        : DateTime.now();

    emit(await _build(selected, locationOverride: location));
    _fireAndForget(AzanNotificationService.rescheduleAll());
  }

  Future<void> _onUpdateSettings(
    IslamicCenterUpdateSettingsEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    if (event.method != null) {
      await IslamicPrefs.setMethod(event.method!);
    }
    if (event.asrJuristic != null) {
      await IslamicPrefs.setAsrJuristic(event.asrJuristic!);
    }
    if (event.adjustments != null) {
      await IslamicPrefs.setAdjustments(event.adjustments!);
    }
    if (event.hijriOffset != null) {
      await IslamicPrefs.setHijriOffset(event.hijriOffset!);
    }

    final current = state;
    final selected = current is IslamicCenterReady
        ? current.selectedDate
        : DateTime.now();

    emit(await _build(selected));
    _fireAndForget(AzanNotificationService.rescheduleAll());
  }

  Future<void> _onToggleAzan(
    IslamicCenterToggleAzanEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    await IslamicPrefs.setAzanEnabled(event.prayer, event.enabled);

    final current = state;
    if (current is IslamicCenterReady) {
      // Optimistic update — the switch should move under the finger, not after
      // a round trip through AlarmManager.
      final updated = Map<String, bool>.from(current.azanEnabled)
        ..[event.prayer.key] = event.enabled;
      emit(current.copyWith(azanEnabled: updated));
    }

    if (event.enabled) {
      _fireAndForget(AzanNotificationService.rescheduleAll());
    } else {
      _fireAndForget(AzanNotificationService.cancelPrayer(event.prayer));
    }
  }

  Future<void> _onUpdateAlertPrefs(
    IslamicCenterUpdateAlertPrefsEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    if (event.soundEnabled != null) {
      await IslamicPrefs.setAzanSoundEnabled(event.soundEnabled!);
    }
    if (event.vibrateEnabled != null) {
      await IslamicPrefs.setVibrateEnabled(event.vibrateEnabled!);
    }
    if (event.preAzanMinutes != null) {
      await IslamicPrefs.setPreAzanMinutes(event.preAzanMinutes!);
    }

    final current = state;
    if (current is IslamicCenterReady) {
      emit(
        current.copyWith(
          soundEnabled: event.soundEnabled,
          vibrateEnabled: event.vibrateEnabled,
          preAzanMinutes: event.preAzanMinutes,
        ),
      );
    }

    _fireAndForget(AzanNotificationService.rescheduleAll());
  }

  Future<void> _onChangeDate(
    IslamicCenterChangeDateEvent event,
    Emitter<IslamicCenterState> emit,
  ) async {
    emit(await _build(event.date));
  }

  // ------------------------------------------------------------------

  /// Reads every preference and produces a fully populated state.
  Future<IslamicCenterReady> _build(
    DateTime date, {
    IslamicLocation? locationOverride,
    LocationOutcome? issue,
  }) async {
    final location =
        locationOverride ?? await IslamicLocationService.cachedOrDefault();

    final method = await IslamicPrefs.getMethod();
    final asr = await IslamicPrefs.getAsrJuristic();
    final adjustments = await IslamicPrefs.getAdjustments();
    final hijriOffset = await IslamicPrefs.getHijriOffset();

    final times = PrayerCalculator.calculate(
      date: date,
      latitude: location.latitude,
      longitude: location.longitude,
      method: method,
      asr: asr,
      adjustments: adjustments,
    );

    final azanEnabled = <String, bool>{};
    for (final prayer in Prayer.values) {
      azanEnabled[prayer.key] = await IslamicPrefs.isAzanEnabled(prayer);
    }

    return IslamicCenterReady(
      location: location,
      selectedDate: DateTime(date.year, date.month, date.day),
      times: times,
      hijri: HijriDate.fromGregorian(date, dayOffset: hijriOffset),
      method: method,
      asrJuristic: asr,
      adjustments: adjustments,
      hijriOffset: hijriOffset,
      azanEnabled: azanEnabled,
      soundEnabled: await IslamicPrefs.isAzanSoundEnabled(),
      vibrateEnabled: await IslamicPrefs.isVibrateEnabled(),
      preAzanMinutes: await IslamicPrefs.getPreAzanMinutes(),
      canScheduleExact: await AzanNotificationService.canScheduleExactAlarms(),
      locationIssue: issue,
      isRefreshing: false,
    );
  }
  /// Rescheduling touches AlarmManager and can take a moment. Nothing in the
  /// UI depends on its result, so it is dispatched without awaiting — but
  /// failures are still logged rather than swallowed into a bare future.
  void _fireAndForget(Future<void> future) {
    unawaited(
      future.catchError((Object e) {
        logger('IslamicCenter: background task failed — $e');
      }),
    );
  }
}
