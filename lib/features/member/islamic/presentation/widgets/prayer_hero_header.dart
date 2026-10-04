import 'dart:async';
// FontFeature reaches material.dart via painting.dart, but importing it
// explicitly keeps the tabular-figures countdown from breaking if that
// re-export ever changes.
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/features/member/islamic/logic/prayer_calculator.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';

/// The panel at the top of the Ibada Center: a fixed Makkah photograph, a live
/// countdown to the next prayer, and the location chip.
///
/// The one-second ticker lives here rather than in the bloc on purpose — a
/// countdown that re-emitted bloc state every second would rebuild the entire
/// page including the feature grid sixty times a minute. Keeping it local
/// means only the digits repaint.
class PrayerHeroHeader extends StatefulWidget {
  const PrayerHeroHeader({
    super.key,
    required this.times,
    required this.locationLabel,
    required this.onTapLocation,
    this.isRefreshing = false,
  });

  final PrayerTimes times;
  final String locationLabel;
  final VoidCallback onTapLocation;
  final bool isRefreshing;

  @override
  State<PrayerHeroHeader> createState() => _PrayerHeroHeaderState();
}

class _PrayerHeroHeaderState extends State<PrayerHeroHeader> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  Prayer? _nextPrayer;

  @override
  void initState() {
    super.initState();
    _recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  @override
  void didUpdateWidget(covariant PrayerHeroHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.times.fajr != widget.times.fajr) _recompute();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _recompute() {
    // Shared with PrayerTimesCard so the countdown and the highlighted column
    // always name the same prayer.
    final upcoming = widget.times.upcomingAt(DateTime.now());

    if (!mounted) return;

    setState(() {
      _nextPrayer = upcoming.prayer;
      _remaining = upcoming.remaining;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNight = IslamicColors.isNightAt(
      now,
      widget.times.maghrib,
      widget.times.fajr,
    );

    // One image, day and night. The ternary that used to pick between day.png
    // and night.png is gone; both branches pointed at the same file anyway.
    const bgImagePath = 'assets/images/ibada/header.jpg';

    return SizedBox(
      // 200 rather than 240. The countdown, the location chip and the safe-area
      // inset together need about 150 of it; the rest was empty image that
      // pushed the prayer-times card down the screen for no gain.
      height: 200.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Photographic background image (header.jpg)
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
            child: Image.asset(
              bgImagePath,
              fit: BoxFit.cover,
              // Cover has to crop one axis, and this panel is much wider than
              // it is tall, so the crop falls on the height. Anchoring at the
              // top keeps the Ka'bah and the logo lockup — which sit in the
              // upper half of the artwork — in frame; centring threw both away
              // and left mostly courtyard.
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                // Fallback gradient in case asset load fails
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: IslamicColors.skyGradient(isNight),
                  ),
                );
              },
            ),
          ),

          // 2. Flat 20% black, edge to edge.
          //
          // Not a gradient any more. The gradient existed to hide a sky that
          // swapped between a day and a night photograph; with one fixed image
          // the only job left is taking a little brightness off the whole
          // frame so white text holds, while leaving the picture plainly
          // visible. 20% is light enough to read the image through, and the
          // countdown and label carry their own drop shadows, which is what
          // lets it stay that light.
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
            child: ColoredBox(color: const Color.fromARGB(230, 0, 0, 0).withValues(alpha: 0.20)),
          ),

          // 3. Header Text & Interactive Controls
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _label(isNight),
                    SizedBox(height: 2.h),
                    _countdown(isNight),
                    SizedBox(height: 8.h),
                    _locationChip(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(bool isNight) {
    final name = _nextPrayer == null ? '' : 'prayer_${_nextPrayer!.key}'.tr;

    return Text(
      '$name ${'after'.tr}',
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        shadows: const [
          Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }

  Widget _countdown(bool isNight) {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    const color = Colors.white;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _digits(h, color),
        _separator(color),
        _digits(m, color),
        _separator(color),
        _digits(s, color),
      ],
    );
  }

  Widget _digits(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        fontSize: 38.sp,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
        letterSpacing: 1,
        shadows: const [
          Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
        ],
        // Stops the width jittering as digits change.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _separator(Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 30.sp,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.85),
          shadows: const [
            Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }

  Widget _locationChip() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30.r),
        onTap: widget.onTapLocation,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 15.sp,
                color: IslamicColors.mosqueDome,
              ),
              SizedBox(width: 6.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 200.w),
                child: Text(
                  widget.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              if (widget.isRefreshing)
                SizedBox(
                  width: 12.sp,
                  height: 12.sp,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else
                Icon(
                  Icons.my_location_rounded,
                  size: 13.sp,
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
