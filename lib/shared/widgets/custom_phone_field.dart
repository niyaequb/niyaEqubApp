import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/util/phone_input_formatter.dart';

class CustomPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final double borderRadius;
  final String? Function(String?)? validator;
  final double? maxHeight;
  CustomPhoneField({
    super.key,
    required this.controller,
    required this.label,
    this.borderRadius = 12,
    this.validator,
    this.maxHeight = 60,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = appColors.primaryColor ?? Colors.blue;

    return TextFormField(
      controller: controller,

      keyboardType: TextInputType.phone,
      style: GoogleFonts.inter(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 14,
      ),
      // Keeps the value at the 9 digit national number: a typed `09` becomes
      // `9`, `07` becomes `7`, and a pasted `+251...` / `0...` number loses its
      // prefix instead of tripping the "exactly 9 digits" validator.
      inputFormatters: const [EthiopianPhoneInputFormatter()],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.white38 : Colors.grey,
          fontSize: 16,
        ),
        filled: isDark,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),

        // Static +251 Prefix with UI consistency
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_outlined, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                "+251",
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 20,
                width: 1,
                color: isDark
                    ? Colors.white10
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF38434F)
                : primaryColor.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
