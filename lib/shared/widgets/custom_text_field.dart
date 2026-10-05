import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final Widget? icon;
  final Widget? prefixIcon; // Added to match your dialog implementation
  final int? maxLines;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final double labelFontSize;
  final double? borderRadius;
  final bool? enabled;

  const CustomTextField({
    super.key,
    required this.label,
    this.icon,
    this.prefixIcon,
    required this.controller,
    this.enabled = true,
    this.labelFontSize = 14,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.borderRadius = 10,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBrandColor =
        appColors.primaryColor ?? AppStaticColor.primaryAmber;

    // The dark palette is read from the theme rather than hardcoded, so a
    // subtree that installs its own AppColors - the Equb night screens, for
    // one - gets fields in ITS colours instead of these. The fallbacks are the
    // values this field used before, so ordinary dark mode is unchanged if the
    // theme ever arrives without them. The light branch below is deliberately
    // left alone: its amber-tinted border is how every form in the app looks.
    final Color darkBorder = appColors.borderColor ?? const Color(0xFF38434F);
    final Color darkText = appColors.titleTextColor ?? Colors.white;
    final Color darkHint = appColors.hintTextColor ?? Colors.white38;
    final Color darkFill =
        (appColors.accentColor ?? Colors.white).withValues(alpha: 0.04);

    return TextFormField(
      enabled: enabled,
      maxLines: maxLines,
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      // Logic: Use white text in dark mode, black in light mode
      style: GoogleFonts.inter(
        color: isDark ? darkText : Colors.black,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon ?? icon,
        labelStyle: GoogleFonts.inter(
          color: isDark ? darkHint : Colors.grey,
          fontSize: labelFontSize,
        ),
        filled: isDark,
        // Using a very slight fill in dark mode makes the input area clearer
        fillColor: isDark ? darkFill : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),

        // Enabled Border
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: BorderSide(
            color: isDark ? darkBorder : primaryBrandColor.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),

        // Focused Border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: BorderSide(color: primaryBrandColor, width: 1.5),
        ),

        // Error Border
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),

        // Focused Error Border
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),

        // Disabled Border
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: BorderSide(
            color: isDark
                  ? darkBorder.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
          ),
        ),
      ),
    );
  }
}
