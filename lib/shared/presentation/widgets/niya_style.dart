import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The look of the Equb screens: the maroon of the Niya logo, white and
/// black.
///
/// In light mode: white cards on a warm white page, black text, maroon for
/// headers, buttons and anything selected. In dark mode the same layout on
/// black, with a brighter maroon so it still reads. Every colour those screens
/// use is defined here, so the style is changed in one place and every screen
/// that takes it stays alike. The same values are the app-wide
/// [AppStaticColor] brand colours.
///
/// THESE ARE THE LIGHT VALUES. A screen picks the pair that matches the
/// current mode through [NiyaSkin] — `niya(context).paper` rather than
/// `NiyaPalette.paper`. The constants here are for the places that cannot
/// reach a BuildContext (painters, which are handed their colours) and for the
/// ones that are the same in both modes: the maroon of a filled button, the
/// white on top of it.
class NiyaPalette {
  const NiyaPalette._();

  /// The logo maroon: headers, buttons, frames, selected states.
  static const Color maroon = Color(0xFF8E1B32);

  /// Pressed buttons, the dark end of gradients, small accents.
  static const Color maroonDeep = Color(0xFF6E1426);

  /// The bright end of gradients.
  static const Color maroonLight = Color(0xFFA8263F);

  /// A brighter red, for the logo's fallback mark.
  static const Color crimson = Color(0xFFB8243B);

  /// A faint maroon wash: chips, icon grounds, highlighted rows.
  static const Color rose = Color(0xFFF7E9EC);

  /// Main text.
  static const Color ink = Color(0xFF111111);

  /// Secondary text.
  static const Color inkSoft = Color(0xFF5E5A5B);

  /// Hints, counters, disabled text.
  static const Color inkFaint = Color(0xFF8A8385);

  /// Cards and sheets.
  static const Color paper = Color(0xFFFFFFFF);

  /// The page behind the cards.
  static const Color page = Color(0xFFF7F5F5);

  /// Hairlines and card borders.
  static const Color line = Color(0xFFE9E3E4);

  // THE THREE STATUS COLOURS
  //
  // Each comes in three strengths, because one colour cannot do all three
  // jobs:
  //
  //   * success / warning / danger — FILLS that carry white text: a snackbar,
  //     a red "Delete" button, a paid day on the calendar. White reads at 5:1
  //     or better on each, and they stay visible on a dark card, so they are
  //     used as they are in both modes.
  //   * successText / warningText / dangerText — TEXT and ICONS in light mode.
  //     A shade deeper, because status text usually sits on a pale tint of its
  //     own colour (a pill, a notice), and the fill shades drop under 4.5:1
  //     there.
  //   * successDark / warningDark / dangerDark (below) — text and icons in
  //     dark mode.
  //
  // Screens do not pick between the last two themselves: niya(context).success
  // (and .warning, .danger) is the right text colour for the mode, and
  // niyaTone(context, colour) turns any of the fills into it.

  /// Paid, joined, done.
  static const Color success = Color(0xFF1E7A4C);

  /// Waiting on something.
  static const Color warning = Color(0xFFB45309);

  /// Overdue, failed, removed.
  static const Color danger = Color(0xFFC62828);

  /// [success] as text or an icon on a light surface, its own tint included.
  static const Color successText = Color(0xFF186B42);

  /// [warning] as text or an icon on a light surface.
  static const Color warningText = Color(0xFF9C4706);

  /// [danger] as text or an icon on a light surface.
  static const Color dangerText = Color(0xFFB42121);

  /// The headers: maroon, a little brighter at the top.
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [maroonLight, maroon, maroonDeep],
  );

  /// The main buttons.
  static const LinearGradient buttonSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA0223B), maroon, Color(0xFF7A1730)],
  );

  /// The maroon stub of a ticket card. Vertical, so it reads the same at
  /// every point along the perforation.
  static const LinearGradient maroonStub = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [maroonLight, maroon, maroonDeep],
  );

  // ------------------------------------------------------------------
  // Dark mode
  //
  // The logo maroon is far too dark to read as text on black (2.1:1), so
  // dark mode has its own, brighter one for text and icons. Filled buttons
  // and headers use a maroon in between: bright enough to lift off a black
  // page, dark enough to keep white text on it.
  // ------------------------------------------------------------------

  /// Maroon for text and icons on a dark surface.
  static const Color maroonOnDark = Color(0xFFE8637C);

  /// Maroon for buttons and headers on a dark page. White reads on it.
  static const Color maroonFillDark = Color(0xFFB02A44);

  /// Pressed, and the dark end of a dark-mode gradient.
  static const Color maroonFillDarkDeep = Color(0xFF8E1B32);

  /// The faint maroon wash, on a dark card.
  static const Color roseDark = Color(0xFF301E23);

  static const Color inkDark = Color(0xFFF5F2F2);
  static const Color inkSoftDark = Color(0xFFADA5A7);
  static const Color inkFaintDark = Color(0xFF8A8385);

  /// Cards and sheets, on black.
  static const Color paperDark = Color(0xFF1C1A1B);

  /// The page behind them.
  static const Color pageDark = Color(0xFF111111);

  /// A card raised above another card.
  static const Color raisedDark = Color(0xFF262324);

  static const Color lineDark = Color(0xFF332E2F);

  static const Color successDark = Color(0xFF34C77B);
  static const Color warningDark = Color(0xFFE0A33A);
  static const Color dangerDark = Color(0xFFF87171);

  /// The header band on a dark page.
  static const LinearGradient headerDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFBE3149), maroonFillDark, maroonFillDarkDeep],
  );

  static const LinearGradient buttonSheenDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBE3149), maroonFillDark, Color(0xFF8E1B32)],
  );
}

/// The Equb screens' colours for the mode the phone is in.
///
/// WHY THIS EXISTS
///
/// Those screens used to be drawn from the [NiyaPalette] constants, which
/// made them one fixed light design — in dark mode the Equb list and the
/// group screens stayed white while the rest of the app went black. Reading
/// the colours from here instead gives every one of them both modes without
/// changing a single layout.
///
/// Read it with [niya]: `final skin = niya(context);`.
@immutable
class NiyaSkin {
  const NiyaSkin({
    required this.isDark,
    required this.page,
    required this.paper,
    required this.raised,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.rose,
    required this.accent,
    required this.fill,
    required this.header,
    required this.buttonSheen,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final bool isDark;

  /// Behind the cards.
  final Color page;

  /// The cards themselves.
  final Color paper;

  /// A card on top of a card: a sheet's rows, a nested panel.
  final Color raised;

  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;

  /// The faint maroon wash behind a chip or an icon.
  final Color rose;

  /// Maroon for TEXT, icons and outlines on [page] or [paper].
  final Color accent;

  /// Maroon for a FILL that carries white on top: a button, a header, a
  /// badge. Never use it for text.
  final Color fill;

  final LinearGradient header;
  final LinearGradient buttonSheen;

  final Color success;
  final Color warning;
  final Color danger;

  static const NiyaSkin light = NiyaSkin(
    isDark: false,
    page: NiyaPalette.page,
    paper: NiyaPalette.paper,
    raised: Color(0xFFF1ECED),
    ink: NiyaPalette.ink,
    inkSoft: NiyaPalette.inkSoft,
    inkFaint: NiyaPalette.inkFaint,
    line: NiyaPalette.line,
    rose: NiyaPalette.rose,
    accent: NiyaPalette.maroon,
    fill: NiyaPalette.maroon,
    header: NiyaPalette.header,
    buttonSheen: NiyaPalette.buttonSheen,
    success: NiyaPalette.successText,
    warning: NiyaPalette.warningText,
    danger: NiyaPalette.dangerText,
  );

  static const NiyaSkin dark = NiyaSkin(
    isDark: true,
    page: NiyaPalette.pageDark,
    paper: NiyaPalette.paperDark,
    raised: NiyaPalette.raisedDark,
    ink: NiyaPalette.inkDark,
    inkSoft: NiyaPalette.inkSoftDark,
    inkFaint: NiyaPalette.inkFaintDark,
    line: NiyaPalette.lineDark,
    rose: NiyaPalette.roseDark,
    accent: NiyaPalette.maroonOnDark,
    fill: NiyaPalette.maroonFillDark,
    header: NiyaPalette.headerDark,
    buttonSheen: NiyaPalette.buttonSheenDark,
    success: NiyaPalette.successDark,
    warning: NiyaPalette.warningDark,
    danger: NiyaPalette.dangerDark,
  );
}

/// The Equb colours for the mode the phone is in. See [NiyaSkin].
NiyaSkin niya(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? NiyaSkin.dark
    : NiyaSkin.light;

/// [color] as text or an icon on the page or a card, in the current mode.
///
/// For a colour that arrives from somewhere else — a status style, a value
/// worked out before the context was to hand. The palette's status fills
/// become the text shade for the mode (see NiyaPalette, THE THREE STATUS
/// COLOURS), and in dark mode the logo maroon becomes its light partner.
///
/// Anything else is left alone in light mode. In dark mode a dark colour is
/// lifted towards white, so a pill or a label never sinks into a black card,
/// while a colour that is already light — a theme colour picked for the dark
/// page — is returned as it is rather than washed out further.
///
/// Not for fills that carry white text: those keep the fill colour.
Color niyaTone(BuildContext context, Color color) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (color == NiyaPalette.success) {
    return dark ? NiyaPalette.successDark : NiyaPalette.successText;
  }
  if (color == NiyaPalette.warning) {
    return dark ? NiyaPalette.warningDark : NiyaPalette.warningText;
  }
  if (color == NiyaPalette.danger) {
    return dark ? NiyaPalette.dangerDark : NiyaPalette.dangerText;
  }
  if (!dark) return color;
  if (color == NiyaPalette.maroon) return NiyaPalette.maroonOnDark;
  if (color.computeLuminance() > 0.25) return color;
  return Color.lerp(color, Colors.white, 0.35)!;
}

/// Light status-bar icons, for a screen whose top is a maroon header.
///
/// Not [SystemUiOverlayStyle.light]: that one also paints the Android
/// navigation bar black, which looks wrong under a white page. Leaving the
/// navigation-bar fields null leaves the navigation bar as it is.
const SystemUiOverlayStyle niyaHeaderOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Dark status-bar icons, for a screen whose top is the white page.
const SystemUiOverlayStyle niyaPageOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// Status-bar icons for a screen whose top is the page rather than a header:
/// dark on the white page, light on the black one.
SystemUiOverlayStyle niyaOverlayOverPage(BuildContext context) =>
    niya(context).isDark ? niyaHeaderOverlay : niyaPageOverlay;

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

/// Maroon with the star lattice over it, in white: the band at the top of
/// the Equb screens. Text on it is white.
class NiyaHeaderBackdrop extends StatelessWidget {
  final Widget? child;
  final BorderRadius borderRadius;

  const NiyaHeaderBackdrop({
    super.key,
    this.child,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: niya(context).header),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    color: Colors.white.withValues(alpha: 0.07),
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

/// A maroon eight-pointed star frame with [child] at its centre: the badge
/// the Equb packages wear.
class NiyaStarBadge extends StatelessWidget {
  final double size;
  final Widget child;

  /// Defaults to the card colour of the current mode.
  final Color? fill;

  /// Defaults to the readable maroon of the current mode.
  final Color? frame;

  const NiyaStarBadge({
    super.key,
    required this.size,
    required this.child,
    this.fill,
    this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StarBadgePainter(
          fill: fill ?? skin.paper,
          frame: frame ?? skin.accent,
          shadow: skin.isDark ? 0.5 : 0.18,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _StarBadgePainter extends CustomPainter {
  final Color fill;
  final Color frame;
  final double shadow;

  const _StarBadgePainter({
    required this.fill,
    required this.frame,
    required this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outer = eightPointStar(r * 0.97).shift(center);
    final inner = eightPointStar(r * 0.82).shift(center);

    canvas.drawShadow(outer, Colors.black.withValues(alpha: shadow), 2, false);
    canvas.drawPath(outer, Paint()..color = fill);
    canvas.drawCircle(
      center,
      r * 0.5,
      Paint()..color = frame.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = frame,
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.022
        ..color = frame.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_StarBadgePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.frame != frame ||
      oldDelegate.shadow != shadow;
}

/// A small eight-pointed star, for ornaments.
class NiyaSparkle extends StatelessWidget {
  final double size;

  /// Defaults to the readable maroon of the current mode.
  final Color? color;

  const NiyaSparkle({super.key, this.size = 10, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SparklePainter(color ?? niya(context).accent)),
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

/// A thin rule that fades out towards one end. Maroon by default; pass white
/// for a rule on a maroon header.
class NiyaRule extends StatelessWidget {
  /// True when the rule leads into something on its right, so it is solid on
  /// the right and fades to the left.
  final bool leadsRight;
  final double thickness;

  /// Defaults to the readable maroon of the current mode.
  final Color? color;

  const NiyaRule({
    super.key,
    this.leadsRight = true,
    this.thickness = 1.2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? niya(context).accent;
    final colors = [tint.withValues(alpha: 0), tint.withValues(alpha: 0.7)];
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

/// A section title in a maroon pill between two rules, like the "list of
/// Equbs" banner in the Niya artwork. [onHeader] draws it in white, for use on
/// a maroon [NiyaHeaderBackdrop].
class NiyaOrnamentTitle extends StatelessWidget {
  final String title;
  final bool onHeader;

  const NiyaOrnamentTitle({
    super.key,
    required this.title,
    this.onHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);
    final accent = onHeader ? Colors.white : skin.accent;

    return Row(
      children: [
        Expanded(child: NiyaRule(color: accent)),
        SizedBox(width: 6.w),
        NiyaSparkle(size: 9.r, color: accent),
        Container(
          constraints: BoxConstraints(maxWidth: 230.w),
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: onHeader
                ? Colors.white.withValues(alpha: 0.12)
                : skin.fill,
            borderRadius: BorderRadius.circular(10.r),
            border: onHeader
                ? Border.all(color: Colors.white.withValues(alpha: 0.7))
                : null,
            boxShadow: onHeader
                ? null
                : [
                    BoxShadow(
                      color: skin.fill.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        NiyaSparkle(size: 9.r, color: accent),
        SizedBox(width: 6.w),
        Expanded(child: NiyaRule(leadsRight: false, color: accent)),
      ],
    );
  }
}

/// The Niya mark — the ballot box — from the app's own assets.
///
/// TWO FILES, ONE MARK
///
/// The mark is a black ballot box with a maroon hand. On a dark page the box
/// disappears and only the hand is left floating, which is what a member sees
/// on the home screen in dark mode. [assetDark] is the same artwork with the
/// black drawn in white and the maroon lifted, so the whole mark reads.
///
/// Which one is used follows the ambient theme. Pass [onLight] when the mark
/// sits on something white in both modes — the white disc on the Equb list's
/// header, an avatar circle — because there the ordinary file, black box and
/// all, is the right one even in dark mode.
class NiyaLogo extends StatelessWidget {
  static const String asset = 'assets/images/new-logo.png';
  static const String assetDark = 'assets/images/new-logo-dark.png';

  final double size;

  /// True when the background behind the mark is light whatever the mode.
  final bool onLight;

  const NiyaLogo({super.key, required this.size, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    final useDark =
        !onLight && Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      useDark ? assetDark : asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Decoded at the size it is drawn, not at the file's 960 pixels, so a
      // list of them stays light on memory.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      errorBuilder: (_, _, _) => Icon(
        Icons.how_to_vote_rounded,
        size: size * 0.8,
        color: niya(context).accent,
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

  static const Color _kiswahGold = Color(0xFFC9A24A);

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

    // The gold band of the kiswah, running round both faces. The one gold in
    // the app: it is the Kaaba's own colour, not part of the palette.
    final band = Paint()
      ..color = _kiswahGold
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
    canvas.drawPath(door, Paint()..color = _kiswahGold);
  }

  @override
  bool shouldRepaint(_KaabaPainter oldDelegate) => false;
}

/// A maroon pill button with white text: the call to action of the Equb
/// screens. [inverted] makes it white with maroon text, for a button that
/// sits on a maroon header or stub.
class NiyaPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double? height;
  final double? fontSize;
  final bool inverted;

  const NiyaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height,
    this.fontSize,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);
    final enabled = onPressed != null && !busy;
    final radius = BorderRadius.circular(999);
    // Inverted sits on a maroon ground (a ticket stub, a header), so it stays
    // white with maroon text in both modes.
    final foreground = inverted ? NiyaPalette.maroon : Colors.white;

    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: inverted ? null : skin.buttonSheen,
          color: inverted ? Colors.white : null,
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: (inverted ? Colors.black : skin.fill).withValues(
                      alpha: 0.22,
                    ),
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
            highlightColor: inverted
                ? NiyaPalette.maroon.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.18),
            child: SizedBox(
              height: height ?? 44.h,
              child: Center(
                child: busy
                    ? SizedBox.square(
                        dimension: 18.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: foreground,
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
                                color: foreground,
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: fontSize ?? 15.sp,
                                  fontWeight: FontWeight.w800,
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
