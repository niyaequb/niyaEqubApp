import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomText extends StatelessWidget {
  final String title;
  final TextAlign? textAlign;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool? centerText;
  final double? letterSpacing;
  final TextOverflow textOverflow;
  final int? maxLines;
  final bool softWrap;

  const CustomText({
    super.key,
    required this.title,
    this.fontSize,
    this.textAlign,
    this.letterSpacing,
    this.fontWeight,
    this.textOverflow = TextOverflow.clip, // Changed from ellipsis to clip
    this.centerText,
    this.textColor,
    this.maxLines,
    this.softWrap = true, // Ensure softWrap is enabled
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      softWrap: softWrap, // Enable soft wrapping
      overflow: textOverflow,
      maxLines: maxLines, // null means unlimited lines
      textAlign: centerText == true ? TextAlign.center : textAlign,
      style: GoogleFonts.inter(
        letterSpacing: letterSpacing,
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.bold,
        color: textColor ?? Colors.black,
      ),
    );
  }
}

class CustomClippedText extends StatelessWidget {
  final String title;
  final TextAlign? textAlign;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool? centerText;
  final double? letterSpacing;
  final TextOverflow textOverflow;
  final int? maxLines;
  final bool? showDotsAfterChars;
  final int? maxCharsToShow;
  final String dotsText;
  final bool softWrap;

  CustomClippedText({
    super.key,
    required this.title,
    this.fontSize,
    this.textAlign,
    this.letterSpacing,
    this.fontWeight,
    this.textOverflow = TextOverflow.clip, // Changed from ellipsis to clip
    this.centerText,
    this.textColor,
    this.maxLines,
    this.showDotsAfterChars = false,
    this.maxCharsToShow,
    this.dotsText = '...',
    this.softWrap = true, // Enable soft wrapping
  }) : assert(
         !showDotsAfterChars! || (showDotsAfterChars && maxCharsToShow != null),
         'maxCharsToShow must be provided when showDotsAfterChars is true',
       );

  @override
  Widget build(BuildContext context) {
    String displayText = title;

    if (showDotsAfterChars == true &&
        maxCharsToShow != null &&
        title.length > maxCharsToShow!) {
      displayText = '${title.substring(0, maxCharsToShow)}$dotsText';
    }

    return Text(
      displayText,
      softWrap: softWrap, // Enable soft wrapping
      overflow: textOverflow,
      maxLines: maxLines, // null means unlimited lines
      textAlign: centerText == true ? TextAlign.center : textAlign,
      style: GoogleFonts.inter(
        letterSpacing: letterSpacing,
        fontSize: fontSize ?? 12,
        fontWeight: fontWeight ?? FontWeight.bold,
        color: textColor ?? Colors.black,
      ),
    );
  }
}
