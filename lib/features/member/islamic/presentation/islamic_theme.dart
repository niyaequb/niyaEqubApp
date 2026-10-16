import 'package:flutter/material.dart';

/// Palette for the Ibada Center.
///
/// The Ibada Center wears the same maroon, white and black as the rest of the
/// app, so moving between the tabs never feels like changing apps. Everything
/// is centralised here.
///
/// These are fixed colours, the same in light and dark mode. Use them for
/// fills — app bars, buttons, chips, switches — where white sits on top. For
/// maroon TEXT or icons on a card or page, use `colors(context).primaryColor`
/// instead: it is this maroon in light mode and a lighter one in dark mode,
/// where the logo maroon is too dark to read.
class IslamicColors {
  const IslamicColors._();

  // --- Core: the Niya maroon ---
  static const Color primary = Color(0xFF8E1B32);
  static const Color primaryDark = Color(0xFF6E1426);
  static const Color primaryDeep = Color(0xFF4F0E1B);
  static const Color accentGold = Color(0xFFC9A24A);

  /// The logo maroon is too dark to read on black; this one is not. Same
  /// value as [AppStaticColor.primaryOnDark].
  static const Color primaryOnDark = Color(0xFFE8637C);

  /// Maroon for TEXT and small icons on a card or page: [primary] in light
  /// mode, [primaryOnDark] in dark mode. Fills stay [primary].
  static Color readable(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? primaryOnDark : primary;

  /// [color] as text or an icon on a card or page: itself in light mode,
  /// lifted towards white in dark mode so it can be read on black.
  static Color readableOf(BuildContext context, Color color) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, 0.35)!
      : color;

  /// The section's second accent: mosque mode, the adhan bell.
  static const Color accent = Color(0xFF6E1426);

  /// Done, aligned, on: the Qibla when the phone points at the Kaaba.
  static const Color success = Color(0xFF1E7A4C);

  // --- Sky gradient behind the header (only seen if the photo fails) ---
  static const Color gradientTop = Color(0xFFA8263F);
  static const Color gradientMid = Color(0xFF8E1B32);
  static const Color gradientBottom = Color(0xFF6E1426);

  static const Color nightTop = Color(0xFF1A0B10);
  static const Color nightMid = Color(0xFF2A1016);
  static const Color nightBottom = Color(0xFF3A1820);

  // --- Mosque silhouette ---
  static const Color mosqueBody = Color(0xFFFFFFFF);
  static const Color mosqueBodyDark = Color(0xFF3A2A2E);
  static const Color mosqueDome = Color(0xFF8E1B32);
  static const Color mosqueDomeAlt = Color(0xFF6E1426);
  static const Color mosqueShade = Color(0xFFE9E3E4);
  static const Color mosqueShadeDark = Color(0xFF2A1F22);
  static const Color sand = Color(0xFFF7E9EC);
  static const Color sandDark = Color(0xFF1C1A1B);

  /// Per-feature accents for the circular grid. One maroon throughout, so
  /// the grid reads as one set; settings is the quiet grey.
  static const Color featureQuran = primary;
  static const Color featureQibla = primary;
  static const Color featureAzkar = primary;
  static const Color featureTasbih = primary;

  /// Umrah guide. Replaced featureNames when the 99 Names screen was retired.
  static const Color featureUmrah = primary;
  static const Color featureSettings = Color(0xFF5E5A5B);
  static const Color featureDuaa = primary;
  static const Color featureCalendar = primary;

  /// Highlight for the prayer that is currently in force.
  static const Color activePrayer = primary;

  static LinearGradient skyGradient(bool isNight) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isNight
          ? const [nightTop, nightMid, nightBottom]
          : const [gradientTop, gradientMid, gradientBottom],
    );
  }

  /// The header goes to its night palette between Maghrib and Fajr, so opening
  /// the app at 3am does not blast a daytime sky at you.
  static bool isNightAt(DateTime now, DateTime? maghrib, DateTime? fajr) {
    if (maghrib == null || fajr == null) {
      return now.hour >= 18 || now.hour < 6;
    }
    return now.isAfter(maghrib) || now.isBefore(fajr);
  }
}
