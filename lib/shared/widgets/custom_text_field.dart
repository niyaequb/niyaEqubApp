import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final primaryBrandColor = appColors.primaryColor;

    // LinkedIn Dark Palette Colors
    const Color darkBorder = Color(0xFF38434F);
    const Color darkText = Colors.white;
    const Color darkHint = Colors.white38;

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
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),

        // Enabled Border
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: BorderSide(
            color: isDark ? darkBorder : primaryBrandColor!.withOpacity(0.3),
            width: 1.0,
          ),
        ),

        // Focused Border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: BorderSide(color: primaryBrandColor!, width: 1.5),
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
            color: isDark ? darkBorder.withOpacity(0.5) : Colors.grey.shade200,
          ),
        ),
      ),
    );
  }
}
