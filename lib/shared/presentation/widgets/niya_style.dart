import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The look of the Equb screens: the deep navy and gold of the Niya artwork,
/// with the maroon and crimson of the logo.
///
/// Every colour those screens use is defined here, so the style is changed in
/// one place and every screen that takes it stays alike.
class NiyaPalette {
  const NiyaPalette._();

  static const Color nightTop = Color(0xFF172A5C);
  static const Color navy = Color(0xFF0E1A3A);
  static const Color navyDeep = Color(0xFF081127);
  static const Color navySoft = Color(0xFF1A2A55);
  static const Color gold = Color(0xFFC9A24A);
  static const Color goldLight = Color(0xFFE9D39A);
  static const Color goldDeep = Color(0xFF8F6E26);
  static const Color maroon = Color(0xFF7B1E2B);
  static const Color maroonDeep = Color(0xFF55121C);
  static const Color crimson = Color(0xFFB8243B);
  static const Color cream = Color(0xFFF6F1E4);
  static const Color paper = Color(0xFFFFFDF8);
  static const Color sage = Color(0xFFDCE6D3);
  static const Color ink = Color(0xFF1D2433);
  static const Color inkSoft = Color(0xFF5B6475);

  /// The night sky behind the headers: lighter at the top, as in the artwork.
  static const LinearGradient night = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [nightTop, navy, navyDeep],
  );

  /// Gold for buttons and frames.
  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3E2AC), gold, Color(0xFFB08A35)],
  );

  /// The maroon stub of a ticket card. Vertical, so it reads the same at
  /// every point along the perforation.
  static const LinearGradient maroonStub = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF912637), maroon, maroonDeep],
  );
}

/// The outline of an eight-pointed star — two squares, one turned 45° — of
/// outer radius [radius], centred on the origin.
Path eightPointStar(double radius) {
  // Where the two squares' edges cross: cos(45°) / cos(22.5°).
  const inner = 0.7654;
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final r = i.isEven ? radius : radius * inner;
    final angle = -math.pi / 2 + i * math.pi / 8;
    final x = r * math.cos(angle);
    final y = r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// Eight-pointed stars joined by small diamonds, the classic khatam lattice,
/// in fine lines. Painted behind content as a texture.
class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double cell;
  final double strokeWidth;

  const IslamicPatternPainter({
    required this.color,
    this.cell = 46,
    this.strokeWidth = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final star = eightPointStar(cell * 0.34);
    final diamond = Path()
      ..moveTo(0, -cell * 0.12)
      ..lineTo(cell * 0.12, 0)
      ..lineTo(0, cell * 0.12)
      ..lineTo(-cell * 0.12, 0)
      ..close();

    for (var y = 0.0; y <= size.height + cell; y += cell) {
      for (var x = 0.0; x <= size.width + cell; x += cell) {
        canvas.drawPath(star.shift(Offset(x, y)), paint);
        canvas.drawPath(
          diamond.shift(Offset(x + cell / 2, y + cell / 2)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(IslamicPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cell != cell ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Navy with the star lattice over it: the backdrop of the Equb headers.
class NiyaNightBackdrop extends StatelessWidget {
  final Widget? child;
  final BorderRadius borderRadius;

  const NiyaNightBackdrop({
    super.key,
    this.child,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: NiyaPalette.night),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    color: NiyaPalette.gold.withValues(alpha: 0.09),
                  ),
                ),
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// A gold eight-pointed star frame with [child] at its centre: the badge the
/// Equb packages wear.
class NiyaStarBadge extends StatelessWidget {
  final double size;
  final Widget child;
  final Color fill;
  final Color frame;

  const NiyaStarBadge({
    super.key,
    required this.size,
    required this.child,
    this.fill = NiyaPalette.cream,
    this.frame = NiyaPalette.gold,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StarBadgePainter(fill: fill, frame: frame),
        child: Center(child: child),
      ),
    );
  }
}

class _StarBadgePainter extends CustomPainter {
  final Color fill;
  final Color frame;

  const _StarBadgePainter({required this.fill, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outer = eightPointStar(r * 0.97).shift(center);
    final inner = eightPointStar(r * 0.82).shift(center);

    canvas.drawShadow(outer, Colors.black.withValues(alpha: 0.4), 3, false);
    canvas.drawPath(outer, Paint()..color = fill);
    canvas.drawCircle(
      center,
      r * 0.5,
      Paint()..color = frame.withValues(alpha: 0.13),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = frame,
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = frame.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_StarBadgePainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.frame != frame;
}

/// A small gold eight-pointed star, for ornaments.
class NiyaSparkle extends StatelessWidget {
  final double size;
  final Color color;

  const NiyaSparkle({super.key, this.size = 10, this.color = NiyaPalette.gold});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  const _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      eightPointStar(size.shortestSide / 2).shift(size.center(Offset.zero)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// A gold rule that fades out towards one end.
class NiyaGoldRule extends StatelessWidget {
  /// True when the rule leads into something on its right, so it is solid on
  /// the right and fades to the left.
  final bool leadsRight;
  final double thickness;

  const NiyaGoldRule({super.key, this.leadsRight = true, this.thickness = 1.2});

  @override
  Widget build(BuildContext context) {
    final colors = [
      NiyaPalette.gold.withValues(alpha: 0),
      NiyaPalette.gold,
    ];
    return Container(
      height: thickness,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: leadsRight ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// A section title in a gold frame between two gold rules, like the "list of
/// Equbs" banner in the Niya artwork.
class NiyaOrnamentTitle extends StatelessWidget {
  final String title;

  const NiyaOrnamentTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: NiyaGoldRule()),
        SizedBox(width: 6.w),
        NiyaSparkle(size: 9.r),
        Container(
          constraints: BoxConstraints(maxWidth: 230.w),
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: NiyaPalette.navyDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: NiyaPalette.gold, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: NiyaPalette.gold.withValues(alpha: 0.18),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        NiyaSparkle(size: 9.r),
        SizedBox(width: 6.w),
        const Expanded(child: NiyaGoldRule(leadsRight: false)),
      ],
    );
  }
}

/// The Niya mark — the ballot box — from the app's own assets.
class NiyaLogo extends StatelessWidget {
  static const String asset = 'assets/images/new-logo.png';

  final double size;

  const NiyaLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Decoded at the size it is drawn, not at the file's 960 pixels, so a
      // list of them stays light on memory.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      errorBuilder: (_, _, _) => Icon(
        Icons.how_to_vote_rounded,
        size: size * 0.8,
        color: NiyaPalette.crimson,
      ),
    );
  }
}

/// The Kaaba, for the Hajj and Umrah packages. Material has no icon for it.
class KaabaGlyph extends StatelessWidget {
  final double size;

  const KaabaGlyph({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _KaabaPainter()),
    );
  }
}

class _KaabaPainter extends CustomPainter {
  const _KaabaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const body = Color(0xFF1C1C21);

    // A cube seen from a little above: front, right side and top.
    final front = Path()
      ..moveTo(w * 0.10, h * 0.34)
      ..lineTo(w * 0.60, h * 0.44)
      ..lineTo(w * 0.60, h * 0.92)
      ..lineTo(w * 0.10, h * 0.80)
      ..close();
    final side = Path()
      ..moveTo(w * 0.60, h * 0.44)
      ..lineTo(w * 0.90, h * 0.32)
      ..lineTo(w * 0.90, h * 0.78)
      ..lineTo(w * 0.60, h * 0.92)
      ..close();
    final top = Path()
      ..moveTo(w * 0.10, h * 0.34)
      ..lineTo(w * 0.40, h * 0.22)
      ..lineTo(w * 0.90, h * 0.32)
      ..lineTo(w * 0.60, h * 0.44)
      ..close();

    canvas.drawPath(front, Paint()..color = body);
    canvas.drawPath(side, Paint()..color = const Color(0xFF34343C));
    canvas.drawPath(top, Paint()..color = const Color(0xFF4A4A54));

    // The gold band of the kiswah, running round both faces.
    final band = Paint()
      ..color = NiyaPalette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.065;
    canvas.drawLine(Offset(w * 0.10, h * 0.47), Offset(w * 0.60, h * 0.57), band);
    canvas.drawLine(Offset(w * 0.60, h * 0.57), Offset(w * 0.90, h * 0.45), band);

    // The door, on the front face.
    final door = Path()
      ..moveTo(w * 0.42, h * 0.68)
      ..lineTo(w * 0.52, h * 0.70)
      ..lineTo(w * 0.52, h * 0.86)
      ..lineTo(w * 0.42, h * 0.84)
      ..close();
    canvas.drawPath(door, Paint()..color = NiyaPalette.gold);
  }

  @override
  bool shouldRepaint(_KaabaPainter oldDelegate) => false;
}

/// A gold pill button with dark maroon text: the call to action of the Equb
/// screens.
class NiyaGoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double? height;
  final double? fontSize;

  const NiyaGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final radius = BorderRadius.circular(999);

    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: NiyaPalette.goldSheen,
          borderRadius: radius,
          border: Border.all(color: NiyaPalette.goldLight, width: 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: NiyaPalette.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height ?? 44.h,
              child: Center(
                child: busy
                    ? SizedBox.square(
                        dimension: 18.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: NiyaPalette.maroonDeep,
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(
                                icon,
                                size: (fontSize ?? 15.sp) + 2,
                                color: NiyaPalette.maroonDeep,
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: NiyaPalette.maroonDeep,
                                  fontSize: fontSize ?? 15.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
