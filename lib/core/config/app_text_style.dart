import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';

class AppTextStyle {
  final BuildContext context;
  AppTextStyle(this.context);

  TextStyle get title => TextStyle(
    color: colors(context).titleTextColor,
    fontSize: 28.sp,
    fontWeight: FontWeight.w700,
  );
  TextStyle get subTitle => TextStyle(
    color: colors(context).titleTextColor,
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
  );
  TextStyle get bodyText => TextStyle(
    color: colors(context).titleTextColor,
    fontSize: 16.sp,
    fontWeight: FontWeight.w300,
  );
  TextStyle get bodyTextSmall => TextStyle(
    color: colors(context).bodyTextSmallColor,
    fontSize: 14.sp,
    fontWeight: FontWeight.w300,
  );
  TextStyle get buttonText => TextStyle(
    color: colors(context).buttonTextColor,
    fontSize: 16.sp,
    fontWeight: FontWeight.w300,
  );
  TextStyle get hintText => TextStyle(
    color: colors(context).hintTextColor,
    fontSize: 21.sp,
    fontWeight: FontWeight.w300,
  );
  TextStyle get appBarText => TextStyle(
    color: colors(context).titleTextColor,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
  );
}
