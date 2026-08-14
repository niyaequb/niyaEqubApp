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

class AppStaticColor {
  // --- Dashboard Brand Palette ---
  static const Color primaryAmber = Color.fromARGB(
    255,
    215,
    162,
    3,
  ); // Friendly Parent-Blue
  static const Color secondaryTeal = Color(0xFF50E3C2); // Success/Growth color

  // --- Dark Mode Palette (Parent Dashboard Deep) ---
  static const Color bgDark = Color(0xFF1A1D21); // Deep Charcoal
  static const Color surfaceDark = Color(0xFF262A31); // Elevated Card/Accent
  static const Color borderDark = Color(0xFF363C44); // Subtle dividers
  static const Color textMainDark = Color(0xFFF1F3F5); // High emphasis text
  static const Color textSubDark = Color(0xFF9BA3AF); // Low emphasis text

  // --- Light Mode Palette (Clean Dashboard) ---
  static const Color bgLight = Color(0xFFF8FAFC); // Soft White/Blue tint
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White Cards
  static const Color borderLight = Color(0xFFE2E8F0); // Light Gray Border
  static const Color textMainLight = Color(0xFF1E293B); // Dark Navy Text
  static const Color textSubLight = Color(0xFF64748B); // Slate Grey Text

  // Standard Colors
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}

// --- Dark Mode Implementation ---
final darkColors = AppColors(
  primaryColor: AppStaticColor.primaryAmber,
  accentColor: AppStaticColor.surfaceDark,
  buttonColor: AppStaticColor.primaryAmber,
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
  primaryColor: AppStaticColor.primaryAmber,
  accentColor: AppStaticColor.surfaceLight,
  buttonColor: AppStaticColor.primaryAmber,
  buttonTextColor: AppStaticColor.white,
  bodyTextColor: AppStaticColor.textMainLight,
  bodyTextSmallColor: AppStaticColor.textSubLight,
  titleTextColor: AppStaticColor.textMainLight,
  hintTextColor: AppStaticColor.textSubLight,
  borderColor: AppStaticColor.borderLight,
  scaffoldBackgroundColor: AppStaticColor.bgLight,
);
