import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/presentation/widgets/mosque_mode_card.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_bloc.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_event.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_state.dart';

/// Everything that governs when the azan fires and how the times are derived.
class PrayerSettingsScreen extends StatelessWidget {
  static const String routeName = '/islamic-prayer-settings';

  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: IslamicColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'prayer_settings'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: BlocBuilder<IslamicCenterBloc, IslamicCenterState>(
        builder: (context, state) {
          if (state is! IslamicCenterReady) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 30.h),
            children: [
              if (!state.canScheduleExact) _exactAlarmCard(context, appColors),
              _azanSection(context, appColors, state),
              SizedBox(height: 12.h),
              _alertSection(context, appColors, state),
              SizedBox(height: 12.h),
              _calculationSection(context, appColors, state),
              SizedBox(height: 12.h),
              _adjustmentSection(context, appColors, state),
              SizedBox(height: 12.h),
              _hijriSection(context, appColors, state),
              SizedBox(height: 16.h),
              _footerNote(appColors),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------

  Widget _card({
    required dynamic appColors,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor ?? Colors.transparent),
      ),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: appColors.titleTextColor,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 3.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5.sp,
                height: 1.4,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ],
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }

  /// Android 12+ can quietly downgrade our alarms; this is the fix path.
  Widget _exactAlarmCard(BuildContext context, dynamic appColors) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alarm_off_rounded,
                color: const Color(0xFFB45309),
                size: 20.sp,
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: Text(
                  'exact_alarm_title'.tr,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          Text(
            'exact_alarm_body'.tr,
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.45,
              color: const Color(0xFF92400E),
            ),
          ),
          SizedBox(height: 10.h),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
              ),
              onPressed: () async {
                await AzanNotificationService.requestExactAlarmPermission();
                if (context.mounted) {
                  context.read<IslamicCenterBloc>().add(
                    const IslamicCenterLoadEvent(isSilent: true),
                  );
                }
              },
              child: Text(
                'grant_permission'.tr,
                style: TextStyle(fontSize: 11.5.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _azanSection(
    BuildContext context,
    dynamic appColors,
    IslamicCenterReady state,
  ) {
    return _card(
      appColors: appColors,
      title: 'azan_notifications'.tr,
      subtitle: 'azan_notifications_hint'.tr,
      children: [
        ...Prayer.values.where((p) => p.isAdhanPrayer).map((prayer) {
          return SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: IslamicColors.primary,
            value: state.isAzanOn(prayer),
            title: Text(
              'prayer_${prayer.key}'.tr,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: appColors.titleTextColor,
              ),
            ),
            onChanged: (value) => context.read<IslamicCenterBloc>().add(
              IslamicCenterToggleAzanEvent(prayer, value),
            ),
          );
        }),
        Divider(height: 18.h, color: appColors.borderColor),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeThumbColor: IslamicColors.primary,
          value: state.isAzanOn(Prayer.sunrise),
          title: Text(
            'prayer_sunrise'.tr,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: appColors.titleTextColor,
            ),
          ),
          subtitle: Text(
            'sunrise_reminder_hint'.tr,
            style: TextStyle(
              fontSize: 10.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          onChanged: (value) => context.read<IslamicCenterBloc>().add(
            IslamicCenterToggleAzanEvent(Prayer.sunrise, value),
          ),
        ),
      ],
    );
  }

  Widget _alertSection(
    BuildContext context,
    dynamic appColors,
    IslamicCenterReady state,
  ) {
    return _card(
      appColors: appColors,
      title: 'alert_style'.tr,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeThumbColor: IslamicColors.primary,
          value: state.soundEnabled,
          title: Text(
            'play_adhan_sound'.tr,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: appColors.titleTextColor,
            ),
          ),
          subtitle: Text(
            'play_adhan_sound_hint'.tr,
            style: TextStyle(
              fontSize: 10.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          onChanged: (value) => context.read<IslamicCenterBloc>().add(
            IslamicCenterUpdateAlertPrefsEvent(soundEnabled: value),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeThumbColor: IslamicColors.primary,
          value: state.vibrateEnabled,
          title: Text(
            'vibration'.tr,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: appColors.titleTextColor,
            ),
          ),
          onChanged: (value) => context.read<IslamicCenterBloc>().add(
            IslamicCenterUpdateAlertPrefsEvent(vibrateEnabled: value),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'pre_azan_reminder'.tr,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: appColors.titleTextColor,
          ),
        ),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 7.w,
          runSpacing: 7.h,
          children: [0, 5, 10, 15, 20, 30].map((minutes) {
            final selected = state.preAzanMinutes == minutes;
            return ChoiceChip(
              label: Text(
                minutes == 0 ? 'off'.tr : '$minutes ${'min'.tr}',
                style: TextStyle(fontSize: 10.5.sp),
              ),
              selected: selected,
              selectedColor: IslamicColors.primary.withValues(alpha: 0.2),
              onSelected: (_) => context.read<IslamicCenterBloc>().add(
                IslamicCenterUpdateAlertPrefsEvent(preAzanMinutes: minutes),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 12.h),
        // Two buttons rather than one, because they exercise two completely
        // different code paths and only one of them can catch a release
        // regression:
        //
        //   Preview -> plugin.show(). Rendered immediately by the live Dart
        //              isolate. Proves the sound file is present and the
        //              channel is configured.
        //   Test    -> plugin.zonedSchedule(). Handed to AlarmManager as Gson
        //              JSON and rebuilt later by ScheduledNotificationReceiver
        //              in a process with no Flutter engine running. This is
        //              the path R8 breaks in release builds.
        //
        // Preview passing while Test stays silent is the exact signature of a
        // missing keep rule. That asymmetry is why the release regression went
        // unnoticed. Keep both.
        //
        // Stacked rather than side by side: 'test_scheduled_azan' is short in
        // English and long in Amharic, and two Expanded buttons in a Row
        // overflow there.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => AzanNotificationService.previewAzan(),
            icon: Icon(Icons.volume_up_rounded, size: 17.sp),
            label: Text(
              'preview_azan'.tr,
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ),
        // SizedBox(height: 8.h),
        // SizedBox(
        //   width: double.infinity,
        //   child: OutlinedButton.icon(
        //     onPressed: () async {
        //       await AzanNotificationService.scheduleTestAzan();
        //       if (!context.mounted) return;
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         SnackBar(
        //           content: Text(
        //             'test_scheduled_azan_booked'.tr,
        //             style: TextStyle(fontSize: 11.5.sp),
        //           ),
        //           duration: const Duration(seconds: 6),
        //         ),
        //       );
        //     },
        //     icon: Icon(Icons.alarm_rounded, size: 17.sp),
        //     label: Text(
        //       'test_scheduled_azan'.tr,
        //       style: TextStyle(fontSize: 12.sp),
        //     ),
        //   ),
        // ),
        SizedBox(height: 7.h),
        Text(
          'test_scheduled_azan_hint'.tr,
          style: TextStyle(
            fontSize: 9.5.sp,
            height: 1.45,
            color: appColors.bodyTextSmallColor,
          ),
        ),

        // Mosque mode lives in the alerts section rather than a section of
        // its own, because it is a rule about what happens AFTER the adhan.
        // Splitting it out would leave the user configuring the same event in
        // two places.
        const MosqueModeCard(),
      ],
    );
  }

  
  Widget _calculationSection(
    BuildContext context,
    dynamic appColors,
    IslamicCenterReady state,
  ) {
    return _card(
      appColors: appColors,
      title: 'calculation_method'.tr,
      subtitle: 'calculation_method_hint'.tr,
      children: [
        ...CalculationMethod.all.map((method) {
          final selected = method.key == state.method.key;
          return RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: method.key,
            groupValue: state.method.key,
            activeColor: IslamicColors.primary,
            title: Text(
              method.label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: appColors.titleTextColor,
              ),
            ),
            subtitle: Text(
              method.ishaInterval > 0
                  ? 'Fajr ${method.fajrAngle}° · Isha +${method.ishaInterval} min'
                  : 'Fajr ${method.fajrAngle}° · Isha ${method.ishaAngle}°',
              style: TextStyle(
                fontSize: 9.5.sp,
                color: appColors.bodyTextSmallColor,
              ),
            ),
            onChanged: (_) => context.read<IslamicCenterBloc>().add(
              IslamicCenterUpdateSettingsEvent(method: method),
            ),
          );
        }),
        Divider(height: 18.h, color: appColors.borderColor),
        Text(
          'asr_calculation'.tr,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: appColors.titleTextColor,
          ),
        ),
        SizedBox(height: 7.h),
        Row(
          children: [
            Expanded(
              child: _segment(
                context,
                appColors,
                label: 'asr_standard'.tr,
                hint: 'asr_standard_hint'.tr,
                selected: state.asrJuristic == AsrJuristic.standard,
                onTap: () => context.read<IslamicCenterBloc>().add(
                  const IslamicCenterUpdateSettingsEvent(
                    asrJuristic: AsrJuristic.standard,
                  ),
                ),
              ),
            ),
            SizedBox(width: 9.w),
            Expanded(
              child: _segment(
                context,
                appColors,
                label: 'asr_hanafi'.tr,
                hint: 'asr_hanafi_hint'.tr,
                selected: state.asrJuristic == AsrJuristic.hanafi,
                onTap: () => context.read<IslamicCenterBloc>().add(
                  const IslamicCenterUpdateSettingsEvent(
                    asrJuristic: AsrJuristic.hanafi,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segment(
    BuildContext context,
    dynamic appColors, {
    required String label,
    required String hint,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: selected
              ? IslamicColors.primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected
                ? IslamicColors.primary
                : (appColors.borderColor ?? Colors.transparent),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected
                    ? IslamicColors.primary
                    : appColors.titleTextColor,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.sp,
                height: 1.3,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adjustmentSection(
    BuildContext context,
    dynamic appColors,
    IslamicCenterReady state,
  ) {
    return _card(
      appColors: appColors,
      title: 'manual_adjustments'.tr,
      subtitle: 'manual_adjustments_hint'.tr,
      children: Prayer.values.map((prayer) {
        final value = state.adjustments.forPrayer(prayer);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 3.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'prayer_${prayer.key}'.tr,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: appColors.titleTextColor,
                  ),
                ),
              ),
              _stepButton(
                appColors,
                icon: Icons.remove_rounded,
                onTap: () => _adjust(context, state, prayer, value - 1),
              ),
              SizedBox(
                width: 46.w,
                child: Text(
                  value == 0
                      ? '0'
                      : (value > 0 ? '+$value' : '$value'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    color: value == 0
                        ? appColors.bodyTextSmallColor
                        : IslamicColors.primary,
                  ),
                ),
              ),
              _stepButton(
                appColors,
                icon: Icons.add_rounded,
                onTap: () => _adjust(context, state, prayer, value + 1),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _adjust(
    BuildContext context,
    IslamicCenterReady state,
    Prayer prayer,
    int value,
  ) {
    final clamped = value.clamp(-60, 60);
    final current = state.adjustments;

    final updated = switch (prayer) {
      Prayer.fajr => current.copyWith(fajr: clamped),
      Prayer.sunrise => current.copyWith(sunrise: clamped),
      Prayer.dhuhr => current.copyWith(dhuhr: clamped),
      Prayer.asr => current.copyWith(asr: clamped),
      Prayer.maghrib => current.copyWith(maghrib: clamped),
      Prayer.isha => current.copyWith(isha: clamped),
    };

    context.read<IslamicCenterBloc>().add(
      IslamicCenterUpdateSettingsEvent(adjustments: updated),
    );
  }

  Widget _stepButton(
    dynamic appColors, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: appColors.borderColor ?? Colors.transparent,
          ),
        ),
        child: Icon(icon, size: 15.sp, color: appColors.bodyTextSmallColor),
      ),
    );
  }

  Widget _hijriSection(
    BuildContext context,
    dynamic appColors,
    IslamicCenterReady state,
  ) {
    return _card(
      appColors: appColors,
      title: 'hijri_date'.tr,
      subtitle: 'hijri_offset_hint'.tr,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                state.hijri.formatted,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: IslamicColors.primary,
                ),
              ),
            ),
            _stepButton(
              appColors,
              icon: Icons.remove_rounded,
              onTap: () => context.read<IslamicCenterBloc>().add(
                IslamicCenterUpdateSettingsEvent(
                  hijriOffset: (state.hijriOffset - 1).clamp(-2, 2),
                ),
              ),
            ),
            SizedBox(
              width: 46.w,
              child: Text(
                state.hijriOffset == 0
                    ? '0'
                    : (state.hijriOffset > 0
                          ? '+${state.hijriOffset}'
                          : '${state.hijriOffset}'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                  color: state.hijriOffset == 0
                      ? appColors.bodyTextSmallColor
                      : IslamicColors.primary,
                ),
              ),
            ),
            _stepButton(
              appColors,
              icon: Icons.add_rounded,
              onTap: () => context.read<IslamicCenterBloc>().add(
                IslamicCenterUpdateSettingsEvent(
                  hijriOffset: (state.hijriOffset + 1).clamp(-2, 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _footerNote(dynamic appColors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Text(
        'prayer_settings_footer'.tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9.5.sp,
          height: 1.5,
          color: appColors.bodyTextSmallColor?.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
