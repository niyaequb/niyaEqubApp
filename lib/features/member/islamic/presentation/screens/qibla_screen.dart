import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/logic/qibla_calculator.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/services/compass_heading.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';

/// Live Qibla compass.
///
/// FAST: the heading comes from the phone's own fused compass
/// (CompassHeading), which follows the phone at once, and the dial is turned
/// directly on every reading instead of chasing it with a 220 ms animation
/// that restarted on each one. Only the dial repaints, not the whole screen.
///
/// CORRECT: three things used to pull the needle off.
///   * North. The bearing to the Kaaba is measured from TRUE north and a
///     compass finds MAGNETIC north. The heading is now corrected to true
///     north (on iPhone by iOS, on Android from the World Magnetic Model).
///   * Calibration. iPhone's raw magnetometer includes the phone's own
///     magnetism; the platform heading is calibrated by the OS, and the
///     screen asks for a figure-eight whenever the OS says it is unsure.
///   * Position. The bearing was worked out from the last saved location, or
///     Addis Ababa if none had ever been saved. The screen now takes a fresh
///     fix as it opens and redraws when it arrives.
class QiblaScreen extends StatefulWidget {
  static const String routeName = '/islamic-qibla';

  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassReading>? _compassSub;

  /// The smoothed heading the dial is drawn at, degrees from north.
  final ValueNotifier<double> _heading = ValueNotifier<double>(0);
  bool _hasHeading = false;

  IslamicLocation? _location;
  bool _locating = false;
  double _qiblaBearing = 0;
  double _distanceKm = 0;

  bool _sensorsAvailable = true;
  bool _trueNorth = false;
  bool _needsCalibration = false;
  bool _isTilted = false;
  bool _wasAligned = false;

  /// Degrees of tolerance before we call it aligned and buzz once.
  static const double _alignTolerance = 3.0;

  // HOW THE NEEDLE IS SMOOTHED
  //
  // One fixed amount cannot do both jobs. Enough smoothing to hold the needle
  // still on a phone lying on a table is enough to leave it trailing behind a
  // phone being turned, which is what "not fast" means in practice.
  //
  // So the amount depends on how far the reading has moved. A turn of more
  // than [_snapAt] degrees is taken almost whole — the member is moving the
  // phone and wants the needle with them — and anything smaller is eased in,
  // more gently the smaller it is. Standing still, that is the old steady
  // needle; turning, it keeps up.

  /// Taken from a reading that has barely moved: noise, so mostly ignored.
  static const double _smoothingSlow = 0.25;

  /// Taken from a reading that has clearly moved.
  static const double _smoothingFast = 0.9;

  /// Degrees of change from which a reading counts as the phone turning.
  static const double _snapAt = 10.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _heading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // The saved position first, so the dial is usable immediately...
    final cached = await IslamicLocationService.cachedOrDefault();
    if (!mounted) return;
    _useLocation(cached);

    // ...then a fresh fix. A member who travelled, or never set a location,
    // would otherwise be shown the direction from somewhere else.
    setState(() => _locating = true);
    final result = await IslamicLocationService.refresh();
    if (!mounted) return;
    setState(() => _locating = false);

    final fresh = result.location;
    if (result.isSuccess && fresh != null && _movedFrom(cached, fresh)) {
      _useLocation(fresh);
    }
  }

  bool _movedFrom(IslamicLocation a, IslamicLocation b) =>
      (a.latitude - b.latitude).abs() > 0.005 ||
      (a.longitude - b.longitude).abs() > 0.005;

  void _useLocation(IslamicLocation location) {
    setState(() {
      _location = location;
      _qiblaBearing = QiblaCalculator.bearing(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _distanceKm = QiblaCalculator.distanceKm(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    });

    // (Re)started with the position, so Android can correct to true north
    // for where the member actually is.
    _compassSub?.cancel();
    _compassSub = CompassHeading.watch(
      latitude: location.latitude,
      longitude: location.longitude,
    ).listen(
      _onReading,
      onError: (Object _) {
        if (mounted) setState(() => _sensorsAvailable = false);
      },
    );
  }

  void _onReading(CompassReading reading) {
    if (!mounted) return;

    // A phone tilted past the point where its top edge means anything would
    // send the needle swinging. The needle holds its last good position and
    // the banner says why, which is the one thing that makes the swing
    // understandable rather than looking broken.
    if (reading.isTilted) {
      // A reading arriving at all proves the phone has the sensors, even
      // when this one cannot be used.
      if (!_isTilted || !_sensorsAvailable) {
        setState(() {
          _isTilted = true;
          _sensorsAvailable = true;
        });
      }
      return;
    }

    // Measured along the circle, so 359° -> 1° is a 2° step, not 358°.
    final previous = _heading.value;
    final delta = QiblaCalculator.shortestDelta(previous, reading.heading);

    final double next;
    if (!_hasHeading) {
      next = reading.heading;
    } else {
      final moved = delta.abs();
      final share = moved >= _snapAt
          ? _smoothingFast
          : _smoothingSlow +
                (_smoothingFast - _smoothingSlow) * (moved / _snapAt);
      next = (previous + share * delta + 360) % 360;
    }
    _hasHeading = true;

    // Sub-0.15° changes are noise on a phone lying still.
    if (QiblaCalculator.shortestDelta(previous, next).abs() >= 0.15) {
      _heading.value = next;
    }

    final aligned =
        QiblaCalculator.shortestDelta(next, _qiblaBearing).abs() <=
        _alignTolerance;

    // Buzz on the way INTO alignment only; a rumble for as long as the
    // member holds still would be maddening.
    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();

    if (aligned != _wasAligned ||
        reading.trueNorth != _trueNorth ||
        reading.needsCalibration != _needsCalibration ||
        reading.isTilted != _isTilted ||
        !_sensorsAvailable) {
      setState(() {
        _wasAligned = aligned;
        _trueNorth = reading.trueNorth;
        _needsCalibration = reading.needsCalibration;
        _isTilted = reading.isTilted;
        _sensorsAvailable = true;
      });
    }
  }

  double _offsetFrom(double heading) =>
      QiblaCalculator.shortestDelta(heading, _qiblaBearing);

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: IslamicColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'qibla'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _location == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Column(
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _heading,
                    builder: (context, heading, _) =>
                        _statusBanner(appColors, heading),
                  ),
                  // A tilted phone is the commonest reason the line looks
                  // wrong, so it is said before anything else.
                  if (_isTilted && _sensorsAvailable) ...[
                    SizedBox(height: 8.h),
                    _banner(
                      icon: Icons.screen_lock_rotation_rounded,
                      color: IslamicColors.readableOf(
                        context,
                        const Color(0xFFB45309),
                      ),
                      text: 'qibla_lay_flat'.tr,
                    ),
                  ],
                  if (_needsCalibration && _sensorsAvailable) ...[
                    SizedBox(height: 8.h),
                    _banner(
                      icon: Icons.threesixty_rounded,
                      color: IslamicColors.readableOf(
                        context,
                        const Color(0xFFB45309),
                      ),
                      text: 'qibla_calibrate_now'.tr,
                    ),
                  ],
                  SizedBox(height: 14.h),
                  _dial(appColors),
                  SizedBox(height: 20.h),
                  _coordinateChip(appColors),
                  SizedBox(height: 12.h),
                  ValueListenableBuilder<double>(
                    valueListenable: _heading,
                    builder: (context, heading, _) =>
                        _readouts(appColors, heading),
                  ),
                  SizedBox(height: 16.h),
                  _calibrationHint(appColors),
                ],
              ),
            ),
    );
  }

  Widget _statusBanner(dynamic appColors, double heading) {
    if (!_sensorsAvailable) {
      return _banner(
        icon: Icons.sensors_off_rounded,
        color: const Color(0xFFEF4444),
        text: 'qibla_no_sensor'.tr,
      );
    }

    final offset = _offsetFrom(heading);

    if (offset.abs() <= _alignTolerance) {
      return _banner(
        icon: Icons.check_circle_rounded,
        color: IslamicColors.success,
        text: 'qibla_aligned'.tr,
      );
    }

    final direction = offset > 0
        ? 'qibla_turn_right'.tr
        : 'qibla_turn_left'.tr;

    return _banner(
      icon: offset > 0 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded,
      // Readable maroon in both themes.
      color: appColors.primaryColor ?? IslamicColors.primary,
      text: '$direction ${offset.abs().round()}°',
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dial(dynamic appColors) {
    final size = math.min(300.w, MediaQuery.sizeOf(context).width * 0.82);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The rose turns against the heading so north stays true. Turned
          // directly on each reading: no animation to lag behind the phone.
          ValueListenableBuilder<double>(
            valueListenable: _heading,
            builder: (context, heading, child) => Transform.rotate(
              angle: -heading * math.pi / 180,
              child: child,
            ),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(size, size),
                painter: _CompassRosePainter(
                  isDark: isDark,
                  qiblaBearing: _qiblaBearing,
                  isAligned: _wasAligned,
                ),
              ),
            ),
          ),

          // Fixed pointer at the top edge, marking "straight ahead".
          Positioned(
            top: 0,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 34.sp,
              color: _wasAligned
                  ? IslamicColors.success
                  : appColors.bodyTextSmallColor,
            ),
          ),

          // Centre hub.
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _wasAligned
                  ? IslamicColors.success
                  : IslamicColors.primary,
              boxShadow: [
                BoxShadow(
                  color:
                      (_wasAligned
                              ? IslamicColors.success
                              : IslamicColors.primary)
                          .withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.mosque_rounded,
              color: Colors.white,
              size: 22.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordinateChip(dynamic appColors) {
    final location = _location!;
    final lat = QiblaCalculator.formatCoordinate(
      location.latitude,
      isLatitude: true,
    );
    final lng = QiblaCalculator.formatCoordinate(
      location.longitude,
      isLatitude: false,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: appColors.borderColor ?? Colors.transparent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_locating) ...[
                SizedBox(
                  width: 11.r,
                  height: 11.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: IslamicColors.readable(context),
                  ),
                ),
                SizedBox(width: 7.w),
              ] else ...[
                Icon(
                  Icons.place_rounded,
                  size: 13.sp,
                  color: IslamicColors.readable(context),
                ),
                SizedBox(width: 4.w),
              ],
              Flexible(
                child: Text(
                  _locating ? 'qibla_finding_location'.tr : location.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                    color: appColors.titleTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            '$lat   $lng',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readouts(dynamic appColors, double heading) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _readout(
              appColors,
              icon: Icons.route_rounded,
              value: '${_distanceKm.round()} km',
              label: 'distance_from_kaaba'.tr,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _readout(
              appColors,
              icon: Icons.navigation_rounded,
              value: '${_qiblaBearing.toStringAsFixed(1)}°',
              label: 'qibla_from_north'.tr,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _readout(
              appColors,
              icon: Icons.explore_rounded,
              value: QiblaCalculator.cardinal(heading),
              label: 'heading'.tr,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readout(
    dynamic appColors, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: appColors.borderColor ?? Colors.transparent),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 17.sp,
            color: appColors.primaryColor ?? IslamicColors.primary,
          ),
          SizedBox(height: 5.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: appColors.titleTextColor,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calibrationHint(dynamic appColors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _trueNorth ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 13.sp,
                color: _trueNorth
                    ? IslamicColors.success
                    : appColors.bodyTextSmallColor,
              ),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  _trueNorth
                      ? 'qibla_true_north'.tr
                      : 'qibla_magnetic_only'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: appColors.titleTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'qibla_calibration_hint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5.sp,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'qibla_magnetic_note'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5.sp,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: appColors.bodyTextSmallColor?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dial face: tick marks, cardinal letters and the Kaaba marker.
class _CompassRosePainter extends CustomPainter {
  _CompassRosePainter({
    required this.isDark,
    required this.qiblaBearing,
    required this.isAligned,
  });

  final bool isDark;
  final double qiblaBearing;
  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final faceColor = isDark ? const Color(0xFF1C1A1B) : Colors.white;
    final tickColor = isDark ? Colors.white24 : Colors.black26;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    // Face and rim.
    canvas.drawCircle(centre, radius - 4, Paint()..color = faceColor);
    canvas.drawCircle(
      centre,
      radius - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = IslamicColors.primary.withValues(alpha: 0.85),
    );

    // Degree ticks every 5°, longer every 30°.
    for (var deg = 0; deg < 360; deg += 5) {
      final isMajor = deg % 30 == 0;
      final angle = (deg - 90) * math.pi / 180;
      final outer = radius - 14;
      final inner = outer - (isMajor ? 14 : 7);

      canvas.drawLine(
        centre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        centre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        Paint()
          ..color = tickColor
          ..strokeWidth = isMajor ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );

      if (isMajor && deg % 90 != 0) {
        _text(
          canvas,
          '$deg',
          centre +
              Offset(
                math.cos(angle) * (inner - 14),
                math.sin(angle) * (inner - 14),
              ),
          9,
          tickColor,
        );
      }
    }

    // Cardinal letters.
    const cardinals = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    cardinals.forEach((deg, letter) {
      final angle = (deg - 90) * math.pi / 180;
      final position =
          centre +
          Offset(
            math.cos(angle) * (radius - 46),
            math.sin(angle) * (radius - 46),
          );
      _text(
        canvas,
        letter,
        position,
        16,
        deg == 0
            ? (isDark ? IslamicColors.primaryOnDark : IslamicColors.primary)
            : textColor,
        bold: true,
      );
    });

    _paintQiblaMarker(canvas, centre, radius);
  }

  void _paintQiblaMarker(Canvas canvas, Offset centre, double radius) {
    final angle = (qiblaBearing - 90) * math.pi / 180;
    final markerColor = isAligned
        ? IslamicColors.success
        : IslamicColors.mosqueDome;

    // Beam from hub to rim, showing the line to Makkah.
    canvas.drawLine(
      centre,
      centre + Offset(math.cos(angle) * (radius - 30), math.sin(angle) * (radius - 30)),
      Paint()
        ..color = markerColor.withValues(alpha: 0.55)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Kaaba badge on the rim.
    final markerCentre =
        centre + Offset(math.cos(angle) * (radius - 30), math.sin(angle) * (radius - 30));

    canvas.drawCircle(markerCentre, 17, Paint()..color = markerColor);
    canvas.drawCircle(
      markerCentre,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );

    // A simple Kaaba glyph — a cube with its gold band.
    final cube = Rect.fromCenter(center: markerCentre, width: 15, height: 15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cube, const Radius.circular(2)),
      Paint()..color = const Color(0xFF111827),
    );
    // A white edge, so the black cube stands out on the maroon badge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(cube, const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white,
    );
    canvas.drawLine(
      Offset(cube.left, markerCentre.dy - 2),
      Offset(cube.right, markerCentre.dy - 2),
      Paint()
        ..color = const Color(0xFFFBBF24)
        ..strokeWidth = 2.5,
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset centre,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompassRosePainter oldDelegate) =>
      oldDelegate.qiblaBearing != qiblaBearing ||
      oldDelegate.isAligned != isAligned ||
      oldDelegate.isDark != isDark;
}
