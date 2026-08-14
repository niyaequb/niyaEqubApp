import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';

/// The mosque skyline behind the countdown.
///
/// Drawn rather than shipped as a PNG: it costs no download size, scales to
/// any screen without a set of @2x/@3x variants, and repaints itself in night
/// colours after Maghrib instead of needing a second asset.
class MosqueSkyline extends StatelessWidget {
  const MosqueSkyline({super.key, required this.isNight});

  final bool isNight;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MosquePainter(isNight: isNight),
        size: Size.infinite,
      ),
    );
  }
}

class _MosquePainter extends CustomPainter {
  _MosquePainter({required this.isNight});

  final bool isNight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = isNight
        ? IslamicColors.mosqueBodyDark
        : IslamicColors.mosqueBody;
    final shade = isNight
        ? IslamicColors.mosqueShadeDark
        : IslamicColors.mosqueShade;
    final ground = isNight ? IslamicColors.sandDark : IslamicColors.sand;

    _paintCelestialBody(canvas, size);
    _paintBackMosque(canvas, w, h, shade);
    _paintMainMosque(canvas, w, h, body, shade);
    _paintGround(canvas, w, h, ground);
  }

  /// Sun in the top-right by day, crescent moon and stars by night.
  void _paintCelestialBody(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.86, size.height * 0.16);

    if (isNight) {
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawCircle(
        centre,
        size.height * 0.09,
        Paint()..color = const Color(0xFFFDE68A),
      );
      canvas.drawCircle(
        centre.translate(size.height * 0.045, -size.height * 0.02),
        size.height * 0.08,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();

      // Seeded so the stars do not dance between frames.
      final random = math.Random(7);
      final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
      for (var i = 0; i < 18; i++) {
        canvas.drawCircle(
          Offset(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height * 0.55,
          ),
          random.nextDouble() * 1.4 + 0.6,
          starPaint,
        );
      }
    } else {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFEF3C7).withValues(alpha: 0.9),
            const Color(0xFFFEF3C7).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: centre, radius: size.height * 0.28),
        );
      canvas.drawCircle(centre, size.height * 0.28, glow);
      canvas.drawCircle(
        centre,
        size.height * 0.085,
        Paint()..color = const Color(0xFFFEF9C3),
      );
    }
  }

  /// Faded second row of domes, for depth.
  void _paintBackMosque(Canvas canvas, double w, double h, Color shade) {
    final paint = Paint()..color = shade.withValues(alpha: 0.55);
    final baseY = h * 0.86;

    _dome(canvas, Offset(w * 0.18, baseY - h * 0.30), w * 0.075, paint);
    _rect(canvas, w * 0.105, baseY - h * 0.30, w * 0.15, h * 0.30, paint);
    _minaret(canvas, w * 0.05, baseY, h * 0.42, w * 0.022, paint);
    _minaret(canvas, w * 0.30, baseY, h * 0.38, w * 0.020, paint);

    _dome(canvas, Offset(w * 0.87, baseY - h * 0.26), w * 0.065, paint);
    _rect(canvas, w * 0.805, baseY - h * 0.26, w * 0.13, h * 0.26, paint);
    _minaret(canvas, w * 0.96, baseY, h * 0.40, w * 0.020, paint);
  }

  /// The central mosque, with the gold dome as the focal point.
  void _paintMainMosque(
    Canvas canvas,
    double w,
    double h,
    Color body,
    Color shade,
  ) {
    final baseY = h * 0.88;
    final bodyPaint = Paint()..color = body;
    final shadePaint = Paint()..color = shade;

    _rect(canvas, w * 0.34, baseY - h * 0.34, w * 0.32, h * 0.34, bodyPaint);

    _dome(
      canvas,
      Offset(w * 0.50, baseY - h * 0.34),
      w * 0.115,
      Paint()..color = IslamicColors.mosqueDome,
    );

    final finialPaint = Paint()
      ..color = IslamicColors.mosqueDome
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.50, baseY - h * 0.34 - w * 0.115),
      Offset(w * 0.50, baseY - h * 0.34 - w * 0.155),
      finialPaint,
    );
    canvas.drawCircle(
      Offset(w * 0.50, baseY - h * 0.34 - w * 0.165),
      w * 0.011,
      finialPaint,
    );

    _dome(
      canvas,
      Offset(w * 0.375, baseY - h * 0.26),
      w * 0.055,
      Paint()..color = IslamicColors.mosqueDomeAlt,
    );
    _dome(
      canvas,
      Offset(w * 0.625, baseY - h * 0.26),
      w * 0.055,
      Paint()..color = IslamicColors.mosqueDomeAlt,
    );

    // Arched entrance.
    final archTop = baseY - h * 0.17;
    final arch = Path()
      ..moveTo(w * 0.455, baseY)
      ..lineTo(w * 0.455, archTop)
      ..arcToPoint(
        Offset(w * 0.545, archTop),
        radius: Radius.circular(w * 0.045),
        clockwise: true,
      )
      ..lineTo(w * 0.545, baseY)
      ..close();
    canvas.drawPath(arch, shadePaint);

    // Side windows.
    for (final x in [0.395, 0.585]) {
      final top = baseY - h * 0.14;
      final window = Path()
        ..moveTo(w * x, baseY - h * 0.03)
        ..lineTo(w * x, top)
        ..arcToPoint(
          Offset(w * (x + 0.028), top),
          radius: Radius.circular(w * 0.014),
          clockwise: true,
        )
        ..lineTo(w * (x + 0.028), baseY - h * 0.03)
        ..close();
      canvas.drawPath(window, shadePaint);
    }

    _minaret(canvas, w * 0.295, baseY, h * 0.56, w * 0.026, bodyPaint);
    _minaret(canvas, w * 0.705, baseY, h * 0.56, w * 0.026, bodyPaint);
  }

  void _paintGround(Canvas canvas, double w, double h, Color ground) {
    final path = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.5, h * 0.855, w, h * 0.88)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = ground);
  }

  /// An onion dome: a circle cut at the springing line, drawn slightly tall.
  void _dome(Canvas canvas, Offset centre, double radius, Paint paint) {
    final path = Path()
      ..moveTo(centre.dx - radius, centre.dy)
      ..cubicTo(
        centre.dx - radius,
        centre.dy - radius * 1.35,
        centre.dx + radius,
        centre.dy - radius * 1.35,
        centre.dx + radius,
        centre.dy,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _rect(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    Paint paint,
  ) {
    canvas.drawRect(Rect.fromLTWH(left, top, width, height), paint);
  }

  void _minaret(
    Canvas canvas,
    double centreX,
    double baseY,
    double height,
    double width,
    Paint paint,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(centreX - width / 2, baseY - height, width, height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        centreX - width * 0.95,
        baseY - height * 0.72,
        width * 1.9,
        width * 0.55,
      ),
      paint,
    );
    _dome(canvas, Offset(centreX, baseY - height), width * 0.75, paint);
  }

  @override
  bool shouldRepaint(covariant _MosquePainter oldDelegate) =>
      oldDelegate.isNight != isNight;
}
