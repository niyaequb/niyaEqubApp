import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/util/app_constants.dart';

// ignore: strict_top_level_inference
AppColors colors(context) => Theme.of(context).extension<AppColors>()!;

ThemeData getAppTheme({
  required BuildContext context,
  required bool isDarkTheme,
}) {
  return ThemeData(
    extensions: <ThemeExtension<AppColors>>[
      AppColors(
        primaryColor: AppStaticColor.primaryAmber,
        accentColor: isDarkTheme
            ? AppStaticColor.surfaceDark
            : AppStaticColor.surfaceLight,
        buttonColor: AppStaticColor.primaryAmber,
        buttonTextColor: AppStaticColor.white,
        bodyTextColor: isDarkTheme
            ? AppStaticColor.textMainDark
            : AppStaticColor.textMainLight,
        bodyTextSmallColor: isDarkTheme
            ? AppStaticColor.textSubDark
            : AppStaticColor.textSubLight,
        titleTextColor: isDarkTheme
            ? AppStaticColor.white
            : AppStaticColor.textMainLight,
        hintTextColor: isDarkTheme
            ? AppStaticColor.textSubDark
            : AppStaticColor.textSubLight,
        scaffoldBackgroundColor: isDarkTheme
            ? AppStaticColor.bgDark
            : AppStaticColor.bgLight,
        borderColor: isDarkTheme
            ? AppStaticColor.borderDark.withValues(
                alpha: AppConstants.hintColorBorderOpacity,
              )
            : AppStaticColor.borderLight.withValues(
                alpha: AppConstants.hintColorBorderOpacity,
              ),
      ),
    ],
    fontFamily: 'Lexend',
    colorScheme: isDarkTheme
        ? ColorScheme.fromSeed(
            seedColor: AppStaticColor.primaryAmber,
            surface: AppStaticColor.bgDark,
            brightness: Brightness.dark,
          )
        : ColorScheme.fromSeed(
            seedColor: AppStaticColor.primaryAmber,
            surface: AppStaticColor.surfaceLight,
            brightness: Brightness.light,
          ),
    useMaterial3: true,
    unselectedWidgetColor: isDarkTheme
        ? AppStaticColor.textSubDark
        : AppStaticColor.textSubLight,
    scaffoldBackgroundColor: isDarkTheme
        ? AppStaticColor.bgDark
        : AppStaticColor.bgLight,
    appBarTheme: AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDarkTheme
          ? AppStaticColor.bgDark
          : AppStaticColor.surfaceLight,
      titleTextStyle: TextStyle(
        color: isDarkTheme
            ? AppStaticColor.white
            : AppStaticColor.textMainLight,
        fontSize: 18.sp, // Slightly larger for Dashboard headers
        fontWeight: FontWeight.w600,
        fontFamily: 'Lexend',
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: false,
      elevation: 0,
      iconTheme: IconThemeData(
        color: isDarkTheme
            ? AppStaticColor.white
            : AppStaticColor.textMainLight,
      ),
    ),
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
      borderSide: const BorderSide(
        color: AppStaticColor.primaryAmber,
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: const BorderSide(color: AppStaticColor.errorRed),
    ),
  );
}
