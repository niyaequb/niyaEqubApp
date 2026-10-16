import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color? primaryColor;
  final Color? accentColor;
  final Color? buttonColor;
  final Color? buttonTextColor;
  final Color? bodyTextColor;
  final Color? bodyTextSmallColor;
  final Color? titleTextColor;
  final Color? hintTextColor;
  final Color? borderColor;
  final Color? scaffoldBackgroundColor;

  const AppColors({
    required this.primaryColor,
    required this.accentColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.bodyTextColor,
    required this.bodyTextSmallColor,
    required this.titleTextColor,
    required this.hintTextColor,
    required this.borderColor,
    required this.scaffoldBackgroundColor,
  });

  @override
  AppColors copyWith({
    Color? primaryColor,
    Color? accentColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? titleTextColor,
    Color? bodyTextColor,
    Color? bodyTextSmallColor,
    Color? hintTextColor,
    Color? borderColor,
    Color? scaffoldBackgroundColor,
  }) {
    return AppColors(
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      buttonColor: buttonColor ?? this.buttonColor,
      buttonTextColor: buttonTextColor ?? this.buttonTextColor,
      bodyTextColor: bodyTextColor ?? this.bodyTextColor,
      bodyTextSmallColor: bodyTextSmallColor ?? this.bodyTextSmallColor,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      hintTextColor: hintTextColor ?? this.hintTextColor,
      borderColor: borderColor ?? this.borderColor,
      scaffoldBackgroundColor:
          scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t),
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      buttonColor: Color.lerp(buttonColor, other.buttonColor, t),
      buttonTextColor: Color.lerp(buttonTextColor, other.buttonTextColor, t),
      bodyTextColor: Color.lerp(bodyTextColor, other.bodyTextColor, t),
      bodyTextSmallColor: Color.lerp(
        bodyTextSmallColor,
        other.bodyTextSmallColor,
        t,
      ),
      titleTextColor: Color.lerp(titleTextColor, other.titleTextColor, t),
      hintTextColor: Color.lerp(hintTextColor, other.hintTextColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      scaffoldBackgroundColor: Color.lerp(
        scaffoldBackgroundColor,
        other.scaffoldBackgroundColor,
        t,
      ),
    );
  }
}

/// The Niya colours: the maroon of the logo, with white and black.
///
/// Screens take their colours from here, either through [AppColors] (the ones
/// that follow light and dark mode) or directly (the few that are the same in
/// both). Change a colour here and every screen follows.
class AppStaticColor {
  // --- Brand ---

  /// The logo maroon: app bars, buttons, links, selected states.
  static const Color primary = Color(0xFF8E1B32);

  /// Deeper maroon: pressed buttons, the dark end of gradients, accents.
  static const Color primaryDeep = Color(0xFF6E1426);

  /// Lighter maroon: the bright end of gradients.
  static const Color primaryLight = Color(0xFFA8263F);

  /// Maroon for TEXT and icons in dark mode. The logo maroon on black is
  /// 2.1:1 — unreadable — so dark mode uses this lifted one instead.
  static const Color primaryOnDark = Color(0xFFE8637C);

  /// Maroon for a FILL in dark mode: an app bar, a button, a chip that
  /// carries white on it. Brighter than the logo maroon so it lifts off a
  /// black page, dark enough that white still reads on it.
  static const Color primaryFillDark = Color(0xFFB02A44);

  /// A faint maroon wash: selected rows, chips, icon circles.
  static const Color primaryTint = Color(0xFFF7E9EC);

  /// The brand colour used to be amber. Kept so older code still builds.
  @Deprecated('Use AppStaticColor.primary')
  static const Color primaryAmber = primary;

  static const Color secondaryTeal = Color(0xFF50E3C2); // Success/Growth color

  // --- Dark mode: black, with maroon accents ---
  static const Color bgDark = Color(0xFF111111); // Page
  static const Color surfaceDark = Color(0xFF1C1A1B); // Cards, sheets
  static const Color borderDark = Color(0xFF332E2F); // Dividers, outlines
  static const Color textMainDark = Color(0xFFF5F2F2); // Main text
  static const Color textSubDark = Color(0xFFADA5A7); // Secondary text

  // --- Light mode: white cards on a warm white page, black text ---
  static const Color bgLight = Color(0xFFF7F5F5); // Page
  static const Color surfaceLight = Color(0xFFFFFFFF); // Cards, sheets
  static const Color borderLight = Color(0xFFE9E3E4); // Dividers, outlines
  static const Color textMainLight = Color(0xFF111111); // Main text
  static const Color textSubLight = Color(0xFF5E5A5B); // Secondary text

  // Standard Colors
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}

// --- Dark Mode Implementation ---
final darkColors = AppColors(
  primaryColor: AppStaticColor.primaryOnDark,
  accentColor: AppStaticColor.surfaceDark,
  buttonColor: AppStaticColor.primaryFillDark,
  buttonTextColor: AppStaticColor.white,
  bodyTextColor: AppStaticColor.textMainDark,
  bodyTextSmallColor: AppStaticColor.textSubDark,
  titleTextColor: AppStaticColor.white,
  hintTextColor: AppStaticColor.textSubDark,
  borderColor: AppStaticColor.borderDark,
  scaffoldBackgroundColor: AppStaticColor.bgDark,
);

// --- Light Mode Implementation ---
final lightColors = AppColors(
  primaryColor: AppStaticColor.primary,
  accentColor: AppStaticColor.surfaceLight,
  buttonColor: AppStaticColor.primary,
  buttonTextColor: AppStaticColor.white,
  bodyTextColor: AppStaticColor.textMainLight,
  bodyTextSmallColor: AppStaticColor.textSubLight,
  titleTextColor: AppStaticColor.textMainLight,
  hintTextColor: AppStaticColor.textSubLight,
  borderColor: AppStaticColor.borderLight,
  scaffoldBackgroundColor: AppStaticColor.bgLight,
);
