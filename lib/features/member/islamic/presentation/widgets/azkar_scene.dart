import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustrated scenes for the azkar categories.
///
/// Drawn rather than shipped as PNGs, matching what mosque_skyline.dart
/// already does in this feature. Three reasons that matters here:
///
///   1. Seven categories at 3 densities would be 21 raster files. This app is
///      already carrying a 5 MB azan.wav, and the resource shrinker turned out
///      to be an active hazard (see android/app/src/main/res/raw/keep.xml).
///   2. The scenes recolour with the category accent for free, so adding an
///      eighth category needs no artwork.
///   3. Vector output stays sharp on any screen, including the tablet layouts.
///
/// The trade-off is honest: a hand-drawn illustration from a designer will
/// always have more character than parametric geometry. If you later commission
/// artwork, [AzkarScene] is the single seam to swap — replace its build() with
/// an Image.asset and nothing else in the feature changes.
enum AzkarSceneVariant { dawn, dusk, night, mosque, sunrise, calm, pattern }

/// Maps a category id to its scene.
///
/// Both spellings of the after-prayer id are accepted because the constant in
/// azkar_data.dart is named `_afterPrayer` and I did not want the illustration
/// to silently fall through to the generic pattern if the id string uses snake
/// case. Unknown ids get [AzkarSceneVariant.pattern], which is a deliberate
/// design: a new category renders something reasonable on day one.
AzkarSceneVariant azkarSceneFor(String categoryId) {
  switch (categoryId) {
    case 'morning':
      return AzkarSceneVariant.dawn;
    case 'evening':
      return AzkarSceneVariant.dusk;
    case 'sleep':
      return AzkarSceneVariant.night;
    case 'afterPrayer':
    case 'after_prayer':
      return AzkarSceneVariant.mosque;
    case 'waking':
      return AzkarSceneVariant.sunrise;
    case 'distress':
      return AzkarSceneVariant.calm;
    default:
      return AzkarSceneVariant.pattern;
  }
}

class _ScenePalette {
  const _ScenePalette({
    required this.skyTop,
    required this.skyBottom,
    required this.silhouette,
    required this.celestial,
    this.stars = false,
    this.clouds = false,
    this.rays = false,
    this.crescent = false,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color silhouette;
  final Color celestial;
  final bool stars;
  final bool clouds;
  final bool rays;
  final bool crescent;
}

_ScenePalette _paletteFor(AzkarSceneVariant variant) {
  switch (variant) {
    case AzkarSceneVariant.dawn:
      return const _ScenePalette(
        skyTop: Color(0xFFFDE9C8),
        skyBottom: Color(0xFFFBBF77),
        silhouette: Color(0xFF7C4A12),
        celestial: Color(0xFFF59E0B),
        clouds: true,
        rays: true,
      );
    case AzkarSceneVariant.dusk:
      return const _ScenePalette(
        skyTop: Color(0xFF6D5BA6),
        skyBottom: Color(0xFFEC8B5E),
        silhouette: Color(0xFF2E2350),
        celestial: Color(0xFFFF9D5C),
        clouds: true,
      );
    case AzkarSceneVariant.night:
      return const _ScenePalette(
        skyTop: Color(0xFF0F172A),
        skyBottom: Color(0xFF3B3170),
        silhouette: Color(0xFF080C1A),
        celestial: Color(0xFFE8E3FF),
        stars: true,
        crescent: true,
      );
    case AzkarSceneVariant.mosque:
      return const _ScenePalette(
        skyTop: Color(0xFF7DD3FC),
        skyBottom: Color(0xFFBAE6FD),
        silhouette: Color(0xFF075985),
        celestial: Color(0xFFFDE68A),
      );
    case AzkarSceneVariant.sunrise:
      return const _ScenePalette(
        skyTop: Color(0xFFBAE6FD),
        skyBottom: Color(0xFFFDE9C8),
        silhouette: Color(0xFF0C4A6E),
        celestial: Color(0xFFFBBF24),
        rays: true,
        clouds: true,
      );
    case AzkarSceneVariant.calm:
      return const _ScenePalette(
        skyTop: Color(0xFF99F6E4),
        skyBottom: Color(0xFFCFFAFE),
        silhouette: Color(0xFF115E59),
        celestial: Color(0xFF14B8A6),
        clouds: true,
      );
    case AzkarSceneVariant.pattern:
      return const _ScenePalette(
        skyTop: Color(0xFFDDD6FE),
        skyBottom: Color(0xFFEDE9FE),
        silhouette: Color(0xFF5B21B6),
        celestial: Color(0xFF8B5CF6),
      );
  }
}

/// A drawn scene sized to fill its parent.
///
/// [accent] tints the silhouette toward the category colour so the card, the
/// app bar and the artwork all agree. Pass null to use the variant's own
/// silhouette colour unchanged.
class AzkarScene extends StatelessWidget {
  const AzkarScene({
    super.key,
    required this.variant,
    this.accent,
    this.borderRadius,
  });

  final AzkarSceneVariant variant;
  final Color? accent;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scene = RepaintBoundary(
      child: CustomPaint(
        painter: _AzkarScenePainter(
          palette: _paletteFor(variant),
          accent: accent,
        ),
        size: Size.infinite,
      ),
    );

    if (borderRadius == null) return scene;
    return ClipRRect(borderRadius: borderRadius!, child: scene);
  }
}

class _AzkarScenePainter extends CustomPainter {
  _AzkarScenePainter({required this.palette, this.accent});

  final _ScenePalette palette;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // --- Sky -------------------------------------------------------------
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ).createShader(rect),
    );

    // --- Stars -----------------------------------------------------------
    //
    // Seeded so the layout is stable across repaints. An unseeded Random here
    // would make the stars twitch every time the widget rebuilds, which on a
    // scrolling list is very visible.
    if (palette.stars) {
      final rng = math.Random(7);
      final starPaint = Paint()..color = Colors.white;
      for (var i = 0; i < 26; i++) {
        final x = rng.nextDouble() * w;
        final y = rng.nextDouble() * h * 0.6;
        final r = 0.6 + rng.nextDouble() * 1.5;
        starPaint.color = Colors.white.withValues(
          alpha: 0.35 + rng.nextDouble() * 0.55,
        );
        canvas.drawCircle(Offset(x, y), r, starPaint);
      }
    }

    // --- Celestial body --------------------------------------------------
    final bodyCentre = Offset(w * 0.72, h * 0.30);
    final bodyRadius = math.min(w, h) * 0.13;

    if (palette.rays) {
      final rayPaint = Paint()
        ..color = palette.celestial.withValues(alpha: 0.28)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final angle = (math.pi * 2 / 8) * i;
        final inner = bodyRadius * 1.45;
        final outer = bodyRadius * 2.1;
        canvas.drawLine(
          bodyCentre + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
          bodyCentre + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
          rayPaint,
        );
      }
    }

    // Soft halo, then the body itself.
    canvas.drawCircle(
      bodyCentre,
      bodyRadius * 1.6,
      Paint()..color = palette.celestial.withValues(alpha: 0.22),
    );

    if (palette.crescent) {
      // Path.combine with difference is the clean way to cut a crescent:
      // BlendMode.clear would need a saveLayer and would punch through the sky
      // gradient underneath as well.
      final full = Path()
        ..addOval(Rect.fromCircle(center: bodyCentre, radius: bodyRadius));
      final bite = Path()
        ..addOval(
          Rect.fromCircle(
            center: bodyCentre.translate(-bodyRadius * 0.42, -bodyRadius * 0.2),
            radius: bodyRadius * 0.92,
          ),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, full, bite),
        Paint()..color = palette.celestial,
      );
    } else {
      canvas.drawCircle(
        bodyCentre,
        bodyRadius,
        Paint()..color = palette.celestial,
      );
    }

    // --- Clouds ----------------------------------------------------------
    if (palette.clouds) {
      final cloudPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.55);
      _cloud(canvas, Offset(w * 0.22, h * 0.24), w * 0.16, cloudPaint);
      _cloud(
        canvas,
        Offset(w * 0.86, h * 0.52),
        w * 0.11,
        Paint()..color = Colors.white.withValues(alpha: 0.38),
      );
    }

    // --- Mosque silhouette ----------------------------------------------
    final silhouette = accent == null
        ? palette.silhouette
        : Color.lerp(palette.silhouette, accent!, 0.45)!;

    canvas.drawPath(_mosquePath(size), Paint()..color = silhouette);

    // --- Geometric star, generic variant only ----------------------------
    if (palette.crescent == false && palette.stars == false) {
      _eightPointStar(
        canvas,
        Offset(w * 0.18, h * 0.62),
        math.min(w, h) * 0.09,
        Paint()..color = Colors.white.withValues(alpha: 0.30),
      );
    }
  }

  void _cloud(Canvas canvas, Offset centre, double radius, Paint paint) {
    canvas.drawCircle(centre, radius * 0.6, paint);
    canvas.drawCircle(
      centre.translate(radius * 0.55, radius * 0.12),
      radius * 0.45,
      paint,
    );
    canvas.drawCircle(
      centre.translate(-radius * 0.55, radius * 0.15),
      radius * 0.4,
      paint,
    );
  }

  /// Dome, body and two minarets, unioned into one filled path.
  ///
  /// Overlapping sub-shapes are fine: the default non-zero fill rule merges
  /// them into a single silhouette with no seams.
  Path _mosquePath(Size size) {
    final w = size.width;
    final h = size.height;
    final base = h + 1; // run past the bottom edge so there is no hairline
    final path = Path();

    // Central body and dome.
    final bodyLeft = w * 0.34;
    final bodyRight = w * 0.66;
    path.addRect(Rect.fromLTRB(bodyLeft, h * 0.62, bodyRight, base));
    path.addOval(Rect.fromLTRB(bodyLeft, h * 0.44, bodyRight, h * 0.78));

    // Finial above the dome.
    path.addRect(
      Rect.fromLTRB(w * 0.495, h * 0.36, w * 0.505, h * 0.48),
    );
    path.addOval(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.355), radius: w * 0.012),
    );

    // Minarets.
    for (final x in [w * 0.20, w * 0.76]) {
      final mw = w * 0.045;
      path.addRect(Rect.fromLTRB(x, h * 0.52, x + mw, base));
      path.addOval(
        Rect.fromLTRB(x - mw * 0.28, h * 0.45, x + mw * 1.28, h * 0.60),
      );
      path.addRect(
        Rect.fromLTRB(
          x + mw * 0.44,
          h * 0.40,
          x + mw * 0.56,
          h * 0.50,
        ),
      );
    }

    // Low wall tying the group together.
    path.addRect(Rect.fromLTRB(0, h * 0.86, w, base));

    return path;
  }

  void _eightPointStar(
    Canvas canvas,
    Offset centre,
    double radius,
    Paint paint,
  ) {
    // Two overlaid squares at 45 degrees — the simplest construction of the
    // khatim/rub el hizb motif.
    for (final rotation in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final angle = rotation + (math.pi / 2) * i;
        final point = centre +
            Offset(math.cos(angle) * radius, math.sin(angle) * radius);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AzkarScenePainter old) =>
      old.palette != palette || old.accent != accent;
}
