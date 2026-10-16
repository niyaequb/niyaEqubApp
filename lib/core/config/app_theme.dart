import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_color.dart';

// ignore: strict_top_level_inference
AppColors colors(context) => Theme.of(context).extension<AppColors>()!;

/// The app's look: the maroon of the Niya logo, white and black.
///
/// Light mode is white cards on a warm white page with black text; dark mode
/// is the same layout on black. Either way the app bars and the main buttons
/// are maroon, so every screen reads as the same app. All colours come from
/// [AppStaticColor].
ThemeData getAppTheme({
  required BuildContext context,
  required bool isDarkTheme,
}) {
  // Maroon text on black is too dark to read, so dark mode uses a lifted
  // maroon for text, icons and selected states, and a brighter one than the
  // logo maroon for the things white sits on — an app bar, a button — which
  // would otherwise sink into a black page.
  final accent = isDarkTheme
      ? AppStaticColor.primaryOnDark
      : AppStaticColor.primary;
  final fill = isDarkTheme
      ? AppStaticColor.primaryFillDark
      : AppStaticColor.primary;
  final page = isDarkTheme ? AppStaticColor.bgDark : AppStaticColor.bgLight;
  final card = isDarkTheme
      ? AppStaticColor.surfaceDark
      : AppStaticColor.surfaceLight;
  final text = isDarkTheme
      ? AppStaticColor.textMainDark
      : AppStaticColor.textMainLight;
  final textSoft = isDarkTheme
      ? AppStaticColor.textSubDark
      : AppStaticColor.textSubLight;
  final line = isDarkTheme
      ? AppStaticColor.borderDark
      : AppStaticColor.borderLight;

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.r),
  );

  // Maroon, a shade deeper while pressed.
  final filledButtonStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return text.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.pressed)) {
        return isDarkTheme
            ? AppStaticColor.primary
            : AppStaticColor.primaryDeep;
      }
      return fill;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? text.withValues(alpha: 0.38)
          : Colors.white,
    ),
    overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.08)),
    elevation: const WidgetStatePropertyAll<double>(0),
    shape: WidgetStatePropertyAll(buttonShape),
  );

  return ThemeData(
    extensions: <ThemeExtension<AppColors>>[
      AppColors(
        primaryColor: accent,
        accentColor: card,
        buttonColor: fill,
        buttonTextColor: AppStaticColor.white,
        bodyTextColor: text,
        bodyTextSmallColor: textSoft,
        titleTextColor: isDarkTheme ? AppStaticColor.white : text,
        hintTextColor: textSoft,
        scaffoldBackgroundColor: page,
        borderColor: line,
      ),
    ],
    fontFamily: 'Lexend',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppStaticColor.primary,
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: isDarkTheme
          ? const Color(0xFF4A0F1B)
          : AppStaticColor.primaryTint,
      onPrimaryContainer: isDarkTheme
          ? const Color(0xFFF7D9DF)
          : AppStaticColor.primaryDeep,
      secondary: isDarkTheme ? fill : AppStaticColor.primaryDeep,
      onSecondary: Colors.white,
      surface: card,
      onSurface: text,
      onSurfaceVariant: textSoft,
      // Material 3 tints cards, sheets, dialogs and menus with the seed
      // colour; the brand wants them plain white (or plain dark grey).
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: card,
      surfaceContainerHighest: isDarkTheme
          ? const Color(0xFF262324)
          : const Color(0xFFF1ECED),
      outline: isDarkTheme ? const Color(0xFF4A4345) : const Color(0xFFCFC6C8),
      outlineVariant: line,
      error: AppStaticColor.errorRed,
    ),
    useMaterial3: true,
    unselectedWidgetColor: textSoft,
    scaffoldBackgroundColor: page,
    dividerColor: line,
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: fill,
      foregroundColor: Colors.white,
      // No systemOverlayStyle: the AppBar works out light status-bar icons
      // from its maroon background by itself, and unlike
      // SystemUiOverlayStyle.light it leaves the Android navigation bar alone.
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18.sp, // Slightly larger for Dashboard headers
        fontWeight: FontWeight.w600,
        fontFamily: 'Lexend',
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accent.withValues(alpha: isDarkTheme ? 0.22 : 0.12),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? accent : textSoft,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.sp,
          fontFamily: 'Lexend',
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? accent : textSoft,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filledButtonStyle),
    filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.6)),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: fill,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.25),
      selectionHandleColor: accent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? fill : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide(color: textSoft, width: 1.4),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : textSoft,
      ),
    ),
    // A maroon knob on a light maroon track when on. (A solid maroon track
    // would swallow the maroon knobs some screens ask for.)
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : textSoft,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.35)
            : line,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : textSoft.withValues(alpha: 0.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      modalBackgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1),
    inputDecorationTheme: inputDecorationTheme(isDarkTheme: isDarkTheme),
  );
}

InputDecorationTheme inputDecorationTheme({required bool isDarkTheme}) {
  Color borderColor = isDarkTheme
      ? AppStaticColor.borderDark
      : AppStaticColor.borderLight;

  return InputDecorationTheme(
    isDense: false,
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
    hintStyle: TextStyle(
      color: isDarkTheme
          ? AppStaticColor.textSubDark
          : AppStaticColor.textSubLight,
      fontSize: 14.sp,
      fontWeight: FontWeight.w300,
    ),
    filled: true,
    fillColor: isDarkTheme
        ? AppStaticColor.surfaceDark
        : AppStaticColor.surfaceLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(
        color: isDarkTheme
            ? AppStaticColor.primaryOnDark
            : AppStaticColor.primary,
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: AppStaticColor.errorRed),
    ),
  );
}
