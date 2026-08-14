import 'package:flutter/material.dart';

/// Palette for the Ibada Center.
///
/// The Equb side of the app is amber; this section runs on its own sky-blue
/// and teal scheme so it reads as a distinct space the moment you land on it,
/// the way the reference app does. Everything is centralised here — swapping
/// the section to the brand amber is a change to [primary] and [gradientTop]
/// and nothing else.
class IslamicColors {
  const IslamicColors._();

  // --- Core ---
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color primaryDeep = Color(0xFF075985);
  static const Color accentGold = Color(0xFFD7A203);
  static const Color accentTeal = Color(0xFF14B8A6);

  // --- Sky gradient behind the mosque ---
  static const Color gradientTop = Color(0xFF7DD3FC);
  static const Color gradientMid = Color(0xFFBAE6FD);
  static const Color gradientBottom = Color(0xFFFDE9C8);

  static const Color nightTop = Color(0xFF0F172A);
  static const Color nightMid = Color(0xFF1E293B);
  static const Color nightBottom = Color(0xFF334155);

  // --- Mosque silhouette ---
  static const Color mosqueBody = Color(0xFFF1F5F9);
  static const Color mosqueBodyDark = Color(0xFF475569);
  static const Color mosqueDome = Color(0xFFF59E0B);
  static const Color mosqueDomeAlt = Color(0xFF0EA5E9);
  static const Color mosqueShade = Color(0xFFCBD5E1);
  static const Color mosqueShadeDark = Color(0xFF334155);
  static const Color sand = Color(0xFFFCD9A0);
  static const Color sandDark = Color(0xFF1E293B);

  /// Per-feature accents for the circular grid.
  static const Color featureQuran = Color(0xFF16A34A);
  static const Color featureQibla = Color(0xFF0EA5E9);
  static const Color featureAzkar = Color(0xFF8B5CF6);
  static const Color featureTasbih = Color(0xFFF59E0B);
  /// Umrah guide. Replaced featureNames when the 99 Names screen was retired.
  static const Color featureUmrah = Color(0xFF0D9488);
  static const Color featureSettings = Color(0xFF64748B);
  static const Color featureDuaa = Color(0xFFEC4899);
  static const Color featureCalendar = Color(0xFFEF4444);

  /// Highlight for the prayer that is currently in force.
  static const Color activePrayer = Color(0xFF0EA5E9);

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
