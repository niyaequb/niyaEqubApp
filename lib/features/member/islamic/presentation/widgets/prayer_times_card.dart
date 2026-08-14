import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/logic/hijri_date.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';

/// The white card under the hero: date strip, the six times, and the night
/// markers. Mirrors the layout of the reference app.
///
/// Stateful because the highlighted column has to move on its own when a
/// prayer time arrives. Driving it purely from bloc state left the highlight
/// stale until something unrelated triggered a rebuild.
class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({
    super.key,
    required this.times,
    required this.hijri,
    required this.selectedDate,
    required this.azanEnabled,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onToday,
    required this.onToggleAzan,
    required this.onOpenSettings,
  });

  final PrayerTimes times;
  final HijriDate hijri;
  final DateTime selectedDate;

  /// Keyed by [Prayer.key].
  final Map<String, bool> azanEnabled;

  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onToday;
  final void Function(Prayer prayer, bool enabled) onToggleAzan;
  final VoidCallback onOpenSettings;

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  Timer? _rolloverTimer;

  /// The prayer being counted down to. Null when viewing another day, where
  /// "next" has no meaning.
  Prayer? _upcoming;

  bool get _isToday {
    final now = DateTime.now();
    return widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _upcoming = _computeUpcoming();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant PrayerTimesCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // New day selected, or times recalculated after a location or method
    // change — both invalidate the current highlight.
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.times.fajr != widget.times.fajr) {
      final next = _computeUpcoming();
      if (next != _upcoming) setState(() => _upcoming = next);
      _armTimer();
    }
  }

  @override
  void dispose() {
    _rolloverTimer?.cancel();
    super.dispose();
  }

  Prayer? _computeUpcoming() {
    if (!_isToday) return null;
    return widget.times.upcomingAt(DateTime.now()).prayer;
  }

  /// Wakes exactly when the highlight needs to move rather than ticking all
  /// day. The transition instants are already known, so a one-shot timer per
  /// prayer costs six wakeups a day instead of 86,400.
  void _armTimer() {
    _rolloverTimer?.cancel();
    if (!_isToday) return;

    final remaining = widget.times.upcomingAt(DateTime.now()).remaining;

    // Capped so a long overnight wait still re-checks periodically — protects
    // against the device clock jumping or the app being suspended and resumed
    // across the boundary.
    const cap = Duration(minutes: 15);
    final wait = remaining + const Duration(seconds: 1);

    _rolloverTimer = Timer(wait > cap ? cap : wait, () {
      if (!mounted) return;

      final next = _computeUpcoming();
      if (next != _upcoming) setState(() => _upcoming = next);
      _armTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _dateStrip(context, appColors),
          Divider(height: 1, color: appColors.borderColor),
          _timesRow(context, appColors),
          _nightMarkers(context, appColors),
        ],
      ),
    );
  }

  Widget _dateStrip(BuildContext context, dynamic appColors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onPreviousDay,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 22.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _isToday ? null : widget.onToday,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(
                    DateFormat('d MMMM yyyy').format(widget.selectedDate),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: appColors.titleTextColor,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    widget.hijri.formatted,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: IslamicColors.primary,
                    ),
                  ),
                  if (!_isToday)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        'back_to_today'.tr,
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w600,
                          color: appColors.bodyTextSmallColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onNextDay,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 22.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          IconButton(
            onPressed: widget.onOpenSettings,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.tune_rounded,
              size: 18.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timesRow(BuildContext context, dynamic appColors) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 2.w),
      child: Row(
        children: widget.times.ordered.map((entry) {
          return Expanded(
            child: _PrayerColumn(
              prayer: entry.key,
              time: entry.value,
              // Highlights the prayer being counted down to, not the one
              // already in force — the point of the highlight is to answer
              // "what's next", matching the hero countdown above it.
              isNext: _upcoming == entry.key,
              azanOn: widget.azanEnabled[entry.key.key] ?? false,
              onToggle: () => widget.onToggleAzan(
                entry.key,
                !(widget.azanEnabled[entry.key.key] ?? false),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _nightMarkers(BuildContext context, dynamic appColors) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 12.w, right: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _marker(
              context,
              'midnight'.tr,
              widget.times.midnight,
              appColors,
            ),
          ),
          Container(
            width: 1,
            height: 18.h,
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            color: appColors.borderColor,
          ),
          Flexible(
            child: _marker(
              context,
              'last_third'.tr,
              widget.times.lastThird,
              appColors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _marker(
    BuildContext context,
    String label,
    DateTime time,
    dynamic appColors,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: IslamicColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            DateFormat('HH:mm').format(time),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: IslamicColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerColumn extends StatelessWidget {
  const _PrayerColumn({
    required this.prayer,
    required this.time,
    required this.isNext,
    required this.azanOn,
    required this.onToggle,
  });

  final Prayer prayer;
  final DateTime time;

  /// True for the prayer the countdown is running towards.
  final bool isNext;

  final bool azanOn;
  final VoidCallback onToggle;

  IconData get _icon => switch (prayer) {
    Prayer.fajr => Icons.nightlight_round,
    Prayer.sunrise => Icons.wb_twilight_rounded,
    Prayer.dhuhr => Icons.wb_sunny_rounded,
    Prayer.asr => Icons.wb_cloudy_rounded,
    Prayer.maghrib => Icons.wb_twilight_rounded,
    Prayer.isha => Icons.dark_mode_rounded,
  };

  Color get _iconColor => switch (prayer) {
    Prayer.fajr => const Color(0xFF6366F1),
    Prayer.sunrise => const Color(0xFFF59E0B),
    Prayer.dhuhr => const Color(0xFFFBBF24),
    Prayer.asr => const Color(0xFF60A5FA),
    Prayer.maghrib => const Color(0xFFF97316),
    Prayer.isha => const Color(0xFF4F46E5),
  };

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return InkWell(
      // Sunrise is a marker, not a prayer — no azan to toggle.
      onTap: prayer.isAdhanPrayer ? onToggle : null,
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 2.w),
        decoration: BoxDecoration(
          color: isNext
              ? IslamicColors.activePrayer.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isNext
                ? IslamicColors.activePrayer.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'prayer_${prayer.key}'.tr,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  color: isNext
                      ? IslamicColors.primary
                      : appColors.bodyTextSmallColor,
                ),
              ),
            ),
            SizedBox(height: 5.h),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_icon, size: 20.sp, color: _iconColor),
                if (prayer.isAdhanPrayer)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      azanOn
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      size: 10.sp,
                      color: azanOn
                          ? IslamicColors.accentTeal
                          : appColors.bodyTextSmallColor?.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 5.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormat('h:mm').format(time),
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isNext
                      ? IslamicColors.primary
                      : appColors.titleTextColor,
                ),
              ),
            ),
            Text(
              DateFormat('a').format(time),
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
