import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/logic/qibla_calculator.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_location_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Live Qibla compass.
///
/// Heading comes from fusing the accelerometer and magnetometer rather than
/// from a compass plugin — see [QiblaCalculator.azimuthFrom] for why. Both
/// streams are low-pass filtered before use, because raw magnetometer output
/// on a mid-range Android phone jitters by several degrees and makes the
/// needle unreadable.
class QiblaScreen extends StatefulWidget {
  static const String routeName = '/islamic-qibla';

  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  List<double>? _gravity;
  List<double>? _magnetic;

  /// Continuous heading in degrees; may run outside 0..360 so the needle
  /// animates the short way round instead of spinning back through zero.
  double _displayHeading = 0;
  double _rawHeading = 0;

  IslamicLocation? _location;
  double _qiblaBearing = 0;
  double _distanceKm = 0;

  bool _sensorsAvailable = true;
  bool _wasAligned = false;

  /// Degrees of tolerance before we call it aligned and buzz once.
  static const double _alignTolerance = 3.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final location = await IslamicLocationService.cachedOrDefault();

    if (!mounted) return;

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

    _startSensors();
  }

  void _startSensors() {
    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.uiInterval,
          ).listen(
            (event) {
              _gravity = QiblaCalculator.lowPass(
                [event.x, event.y, event.z],
                _gravity,
              );
              _updateHeading();
            },
            onError: (_) {
              if (mounted) setState(() => _sensorsAvailable = false);
            },
            cancelOnError: false,
          );

      _magSub =
          magnetometerEventStream(
            samplingPeriod: SensorInterval.uiInterval,
          ).listen(
            (event) {
              _magnetic = QiblaCalculator.lowPass(
                [event.x, event.y, event.z],
                _magnetic,
              );
              _updateHeading();
            },
            onError: (_) {
              if (mounted) setState(() => _sensorsAvailable = false);
            },
            cancelOnError: false,
          );
    } catch (_) {
      if (mounted) setState(() => _sensorsAvailable = false);
    }
  }

  void _updateHeading() {
    final gravity = _gravity;
    final magnetic = _magnetic;
    if (gravity == null || magnetic == null) return;

    final azimuth = QiblaCalculator.azimuthFrom(
      gravity: gravity,
      geomagnetic: magnetic,
    );
    if (azimuth == null) return;

    // Accumulate the shortest delta so the dial never takes the long way.
    final delta = QiblaCalculator.shortestDelta(_rawHeading, azimuth);

    // Ignore sub-degree noise; otherwise the needle shivers when the phone is
    // flat on a table.
    if (delta.abs() < 0.4) return;

    _rawHeading = azimuth;

    if (!mounted) return;
    setState(() => _displayHeading += delta);

    _checkAlignment(azimuth);
  }

  void _checkAlignment(double heading) {
    final offset = QiblaCalculator.shortestDelta(heading, _qiblaBearing).abs();
    final aligned = offset <= _alignTolerance;

    // Buzz on the transition into alignment only — a continuous rumble while
    // the user holds position would be maddening.
    if (aligned && !_wasAligned) {
      HapticFeedback.mediumImpact();
    }
    _wasAligned = aligned;
  }

  double get _offsetFromQibla =>
      QiblaCalculator.shortestDelta(_rawHeading, _qiblaBearing);

  bool get _isAligned => _offsetFromQibla.abs() <= _alignTolerance;

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
                  _statusBanner(appColors),
                  SizedBox(height: 14.h),
                  _dial(appColors),
                  SizedBox(height: 20.h),
                  _coordinateChip(appColors),
                  SizedBox(height: 12.h),
                  _readouts(appColors),
                  SizedBox(height: 16.h),
                  _calibrationHint(appColors),
                ],
              ),
            ),
    );
  }

  Widget _statusBanner(dynamic appColors) {
    if (!_sensorsAvailable) {
      return _banner(
        icon: Icons.sensors_off_rounded,
        color: const Color(0xFFEF4444),
        text: 'qibla_no_sensor'.tr,
      );
    }

    if (_isAligned) {
      return _banner(
        icon: Icons.check_circle_rounded,
        color: IslamicColors.accentTeal,
        text: 'qibla_aligned'.tr,
      );
    }

    final direction = _offsetFromQibla > 0
        ? 'qibla_turn_right'.tr
        : 'qibla_turn_left'.tr;

    return _banner(
      icon: _offsetFromQibla > 0
          ? Icons.rotate_right_rounded
          : Icons.rotate_left_rounded,
      color: IslamicColors.primary,
      text: '$direction ${_offsetFromQibla.abs().round()}°',
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

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The rose rotates opposite the heading so north stays true.
          AnimatedRotation(
            turns: -_displayHeading / 360,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: Size(size, size),
              painter: _CompassRosePainter(
                isDark: Theme.of(context).brightness == Brightness.dark,
                qiblaBearing: _qiblaBearing,
                isAligned: _isAligned,
              ),
            ),
          ),

          // Fixed pointer at the top edge, marking "straight ahead".
          Positioned(
            top: 0,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 34.sp,
              color: _isAligned
                  ? IslamicColors.accentTeal
                  : appColors.bodyTextSmallColor,
            ),
          ),

          // Centre hub.
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isAligned
                  ? IslamicColors.accentTeal
                  : IslamicColors.primary,
              boxShadow: [
                BoxShadow(
                  color:
                      (_isAligned
                              ? IslamicColors.accentTeal
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
      child: Text(
        '$lat   $lng',
        style: TextStyle(
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w700,
          color: appColors.titleTextColor,
        ),
      ),
    );
  }

  Widget _readouts(dynamic appColors) {
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
              value: QiblaCalculator.cardinal(_rawHeading),
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
          Icon(icon, size: 17.sp, color: IslamicColors.primary),
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

    final faceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
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
        deg == 0 ? IslamicColors.primary : textColor,
        bold: true,
      );
    });

    _paintQiblaMarker(canvas, centre, radius);
  }

  void _paintQiblaMarker(Canvas canvas, Offset centre, double radius) {
    final angle = (qiblaBearing - 90) * math.pi / 180;
    final markerColor = isAligned
        ? IslamicColors.accentTeal
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
