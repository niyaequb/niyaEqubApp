import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:niya_equb/features/member/islamic/services/mosque_mode_service.dart';

/// Mosque mode controls for the prayer settings screen.
///
/// Self-contained on purpose: it owns its own state and reloads itself, so it
/// can be dropped anywhere in the settings tree without the host screen having
/// to know anything about it. It also has to survive the user leaving to a
/// system settings page and coming back, which an inherited-state approach
/// makes awkward.
class MosqueModeCard extends StatefulWidget {
  const MosqueModeCard({super.key});

  @override
  State<MosqueModeCard> createState() => _MosqueModeCardState();
}

class _MosqueModeCardState extends State<MosqueModeCard>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _enabled = false;
  bool _hasPermission = false;
  bool _silencedNow = false;
  int _delay = 5;
  int _duration = 30;

  static const List<int> _delayChoices = [0, 3, 5, 10, 15];
  static const List<int> _durationChoices = [15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The DND grant is given on a system page, so the only way to notice it
    // was granted is to re-check when the app comes back.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final enabled = await IslamicPrefs.isMosqueModeEnabled();
    final permission = await MosqueModeService.hasPermission();
    final silenced = await MosqueModeService.isCurrentlySilenced();
    final delay = await IslamicPrefs.getMosqueModeDelayMinutes();
    final duration = await IslamicPrefs.getMosqueModeDurationMinutes();

    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hasPermission = permission;
      _silencedNow = silenced;
      _delay = delay;
      _duration = duration;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await IslamicPrefs.setMosqueModeEnabled(value);

    // Deliberately no longer jumps to the system Do Not Disturb page.
    //
    // Switching to vibrate needs no special grant, so hijacking the user to a
    // settings screen the moment they flip the switch demands a permission the
    // feature does not require. The notice below offers it as a refinement
    // instead, which is what it now is.
    await AzanNotificationService.rescheduleAll();
    await _load();
  }

  Future<void> _setDelay(int minutes) async {
    setState(() => _delay = minutes);
    await IslamicPrefs.setMosqueModeDelayMinutes(minutes);
    await AzanNotificationService.rescheduleAll();
  }

  Future<void> _setDuration(int minutes) async {
    setState(() => _duration = minutes);
    await IslamicPrefs.setMosqueModeDurationMinutes(minutes);
    await AzanNotificationService.rescheduleAll();
  }

  @override
  Widget build(BuildContext context) {
    // Hidden entirely on iOS. There is no public API to change the ringer or
    // a Focus mode there, so showing a switch would be a promise the platform
    // cannot keep.
    if (!MosqueModeService.isSupported) return const SizedBox.shrink();
    if (_loading) return const SizedBox.shrink();

    final appColors = colors(context);

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: appColors.borderColor ?? Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: IslamicColors.accentTeal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.vibration_rounded,
                  size: 18.sp,
                  color: IslamicColors.accentTeal,
                ),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'mosque_mode'.tr,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: appColors.titleTextColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'mosque_mode_hint'.tr,
                      style: TextStyle(
                        fontSize: 10.sp,
                        height: 1.4,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: IslamicColors.accentTeal,
                onChanged: _setEnabled,
              ),
            ],
          ),

          // Timing controls are shown whenever the feature is on, and are NO
          // LONGER gated on the Do Not Disturb grant.
          //
          // They used to be hidden behind `_enabled && _hasPermission`, so a
          // user without that grant saw a switch, a warning, and nothing to
          // configure — and since the old native code also refused to act
          // without it, the feature genuinely did nothing. That combination is
          // almost certainly what "it's not working" meant.
          if (_enabled) ...[
            SizedBox(height: 14.h),
            _chipRow(
              appColors,
              label: 'mosque_mode_delay'.tr,
              choices: _delayChoices,
              selected: _delay,
              onSelect: _setDelay,
              formatter: (m) => m == 0 ? 'mosque_mode_immediate'.tr : '$m ${'min'.tr}',
            ),
            SizedBox(height: 12.h),
            _chipRow(
              appColors,
              label: 'mosque_mode_duration'.tr,
              choices: _durationChoices,
              selected: _duration,
              onSelect: _setDuration,
              formatter: (m) => '$m ${'min'.tr}',
            ),
            SizedBox(height: 12.h),
            Text(
              'mosque_mode_restore_note'.trParams({'minutes': '$_duration'}),
              style: TextStyle(
                fontSize: 9.5.sp,
                height: 1.45,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ],

          // Advisory, and placed last so it reads as a footnote rather than a
          // blocker.
          if (_enabled && !_hasPermission) ...[
            SizedBox(height: 12.h),
            _permissionNotice(appColors),
          ],

          if (_silencedNow) ...[
            SizedBox(height: 12.h),
            _activeNotice(appColors),
          ],
        ],
      ),
    );
  }

  Widget _permissionNotice(dynamic appColors) {
    return Container(
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11.r),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 17.sp,
            color: const Color(0xFFB45309),
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'mosque_mode_permission_body'.tr,
              style: TextStyle(
                fontSize: 10.sp,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await MosqueModeService.openPermissionSettings();
            },
            child: Text(
              'grant'.tr,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown while a vibrate window is open, with a manual way out.
  ///
  /// The restore alarm handles this automatically, but someone whose plans
  /// changed should never have to wait it out or dig through system settings.
  Widget _activeNotice(dynamic appColors) {
    return Container(
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: IslamicColors.accentTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.vibration_rounded,
            size: 17.sp,
            color: IslamicColors.accentTeal,
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'mosque_mode_active'.tr,
              style: TextStyle(
                fontSize: 10.sp,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: appColors.bodyTextColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await MosqueModeService.restoreNow();
              await _load();
            },
            child: Text(
              'mosque_mode_unmute'.tr,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: IslamicColors.accentTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow(
    dynamic appColors, {
    required String label,
    required List<int> choices,
    required int selected,
    required ValueChanged<int> onSelect,
    required String Function(int) formatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: appColors.bodyTextColor,
          ),
        ),
        SizedBox(height: 7.h),
        Wrap(
          spacing: 7.w,
          runSpacing: 7.h,
          children: choices.map((value) {
            final isSelected = value == selected;
            return GestureDetector(
              onTap: () => onSelect(value),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? IslamicColors.accentTeal
                      : IslamicColors.accentTeal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: IslamicColors.accentTeal.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  formatter(value),
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : IslamicColors.accentTeal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
