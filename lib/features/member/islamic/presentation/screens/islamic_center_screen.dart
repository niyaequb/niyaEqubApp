import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/data/static/surah_data.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/azkar_categories_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/prayer_settings_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/qibla_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/quran_reader_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/quran_surah_list_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/tasbih_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/umrah_guide_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/widgets/feature_grid.dart';
import 'package:niya_equb/features/member/islamic/presentation/widgets/prayer_hero_header.dart';
import 'package:niya_equb/features/member/islamic/presentation/widgets/prayer_times_card.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_bloc.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_event.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_state.dart';

/// The Ibada Center home — prayer times, then everything else one tap away.
class IslamicCenterScreen extends StatefulWidget {
  static const String routeName = '/islamic-center';

  const IslamicCenterScreen({super.key});

  @override
  State<IslamicCenterScreen> createState() => _IslamicCenterScreenState();
}

class _IslamicCenterScreenState extends State<IslamicCenterScreen> {
  ({int surah, int ayah})? _lastRead;

  @override
  void initState() {
    super.initState();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final value = await IslamicPrefs.getLastRead();
    if (mounted) setState(() => _lastRead = value);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      body: BlocBuilder<IslamicCenterBloc, IslamicCenterState>(
        builder: (context, state) {
          if (state is IslamicCenterLoading || state is IslamicCenterInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is IslamicCenterFailure) {
            return _errorView(context, state.message);
          }

          final ready = state as IslamicCenterReady;

          return RefreshIndicator(
            color: IslamicColors.primary,
            onRefresh: () async {
              context.read<IslamicCenterBloc>().add(
                const IslamicCenterRefreshLocationEvent(),
              );
              await _loadLastRead();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(bottom: 24.h),
              children: [
                PrayerHeroHeader(
                  times: ready.times,
                  locationLabel: ready.location.label,
                  isRefreshing: ready.isRefreshing,
                  onTapLocation: () => _showLocationSheet(context, ready),
                ),
                Transform.translate(
                  offset: Offset(0, -18.h),
                  child: PrayerTimesCard(
                    times: ready.times,
                    hijri: ready.hijri,
                    selectedDate: ready.selectedDate,
                    azanEnabled: ready.azanEnabled,
                    onPreviousDay: () => _shiftDay(context, ready, -1),
                    onNextDay: () => _shiftDay(context, ready, 1),
                    onToday: () => context.read<IslamicCenterBloc>().add(
                      IslamicCenterChangeDateEvent(DateTime.now()),
                    ),
                    onToggleAzan: (prayer, enabled) =>
                        context.read<IslamicCenterBloc>().add(
                          IslamicCenterToggleAzanEvent(prayer, enabled),
                        ),
                    onOpenSettings: () => _openSettings(context),
                  ),
                ),

                if (!ready.canScheduleExact)
                  _exactAlarmWarning(context),

                if (ready.locationIssue != null)
                  _locationNotice(context, ready),

                if (_lastRead != null) _continueReadingCard(context),

                SizedBox(height: 6.h),
                _sectionLabel(context, 'ibada_tools'.tr),
                SizedBox(height: 8.h),
                _grid(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------

  Widget _grid(BuildContext context) {
    final features = <IslamicFeature>[
      IslamicFeature(
        labelKey: 'umrah_guide',
        imagePath: 'assets/images/ibada/img_5.png',
        color: IslamicColors.featureTasbih,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UmrahGuideScreen()),
        ),
      ),
      IslamicFeature(
        labelKey: 'quran',
        imagePath: 'assets/images/ibada/img_1.png', 
        color: IslamicColors.featureQuran,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuranSurahListScreen()),
        ),
      ),
      IslamicFeature(
        labelKey: 'qibla',
        imagePath: 'assets/images/ibada/img_2.png',
        color: IslamicColors.featureQibla,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QiblaScreen()),
        ),
      ),
      IslamicFeature(
        labelKey: 'azkar',
        imagePath: 'assets/images/ibada/img_3.png',
        color: IslamicColors.featureAzkar,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AzkarCategoriesScreen()),
        ),
      ),
      IslamicFeature(
        labelKey: 'tasbih',
        imagePath: 'assets/images/ibada/img_4.png',
        color: IslamicColors.featureTasbih,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TasbihScreen()),
        ),
      ),
      
      IslamicFeature(
        labelKey: 'prayer_settings',
        imagePath: 'assets/images/ibada/img_6.png',
        color: IslamicColors.featureSettings,
        onTap: () => _openSettings(context),
      ),
    ];

    return FeatureGrid(
      features: features,
      labels: features.map((f) => f.labelKey.tr).toList(),
    );
  }
  
  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: colors(context).titleTextColor,
        ),
      ),
    );
  }

  Widget _continueReadingCard(BuildContext context) {
    final appColors = colors(context);
    final surah = SurahData.byNumber(_lastRead!.surah);

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 8.h),
      child: Material(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuranReaderScreen(
                surahNumber: _lastRead!.surah,
                initialAyah: _lastRead!.ayah,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(9.w),
                  decoration: BoxDecoration(
                    color: IslamicColors.featureQuran.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Icon(
                    Icons.bookmark_rounded,
                    color: IslamicColors.featureQuran,
                    size: 19.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'continue_reading'.tr,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: appColors.bodyTextSmallColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${surah.englishName} · ${'ayah'.tr} ${_lastRead!.ayah}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: appColors.titleTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  surah.arabicName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: IslamicColors.featureQuran,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Android 12+ can silently downgrade our alarms to inexact, which makes the
  /// adhan drift by minutes. Better to say so than to be quietly wrong.
  Widget _exactAlarmWarning(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.alarm_off_rounded,
              color: const Color(0xFFB45309),
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'exact_alarm_warning'.tr,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openSettings(context),
              child: Text(
                'fix'.tr,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationNotice(BuildContext context, IslamicCenterReady ready) {
    final message = switch (ready.locationIssue!) {
      LocationOutcome.serviceDisabled => 'location_service_off'.tr,
      LocationOutcome.permissionDenied => 'location_permission_denied'.tr,
      LocationOutcome.permissionDeniedForever =>
        'location_permission_forever'.tr,
      _ => 'location_unavailable'.tr,
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: IslamicColors.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_off_rounded,
              color: IslamicColors.primaryDark,
              size: 19.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                '$message ${'using_saved_location'.trParams({'city': ready.location.city})}',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: colors(context).bodyTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showLocationSheet(context, ready),
              child: Text(
                'change'.tr,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: IslamicColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48.sp,
              color: colors(context).bodyTextSmallColor,
            ),
            SizedBox(height: 14.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: colors(context).bodyTextSmallColor,
              ),
            ),
            SizedBox(height: 18.h),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: IslamicColors.primary,
              ),
              onPressed: () => context.read<IslamicCenterBloc>().add(
                const IslamicCenterLoadEvent(),
              ),
              child: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------

  void _shiftDay(BuildContext context, IslamicCenterReady ready, int delta) {
    final next = ready.selectedDate.add(Duration(days: delta));
    context.read<IslamicCenterBloc>().add(IslamicCenterChangeDateEvent(next));
  }

  void _openSettings(BuildContext context) {
    final bloc = context.read<IslamicCenterBloc>();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: const PrayerSettingsScreen(),
            ),
          ),
        )
        .then((_) => _loadLastRead());
  }

  void _showLocationSheet(BuildContext context, IslamicCenterReady ready) {
    final bloc = context.read<IslamicCenterBloc>();
    final appColors = colors(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors.scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 38.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: appColors.borderColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(height: 14.h),
              ListTile(
                leading: Icon(
                  Icons.my_location_rounded,
                  color: IslamicColors.primary,
                ),
                title: Text(
                  'use_my_location'.tr,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: appColors.titleTextColor,
                  ),
                ),
                subtitle: Text(
                  'use_my_location_hint'.tr,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: appColors.bodyTextSmallColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  bloc.add(const IslamicCenterRefreshLocationEvent());
                },
              ),
              Divider(height: 1, color: appColors.borderColor),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'choose_city'.tr,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: IslamicLocationService.selectableCities.length,
                  itemBuilder: (context, index) {
                    final city =
                        IslamicLocationService.selectableCities[index];
                    final isSelected = city.name == ready.location.city;

                    return ListTile(
                      dense: true,
                      title: Text(
                        city.label,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? IslamicColors.primary
                              : appColors.bodyTextColor,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: IslamicColors.primary,
                              size: 18.sp,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        bloc.add(IslamicCenterSetCityEvent(city));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
