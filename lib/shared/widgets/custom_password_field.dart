import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:niya_equb/core/config/app_theme.dart';

class CustomPasswordField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final double borderRadius;
  final double labelFontSize;

  const CustomPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.labelFontSize = 14,
    this.borderRadius = 10,
    this.validator,
  });

  @override
  State<CustomPasswordField> createState() => _CustomPasswordFieldState();
}

class _CustomPasswordFieldState extends State<CustomPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    // 1. Determine if the app is currently in Dark Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Fetch your brand colors
    final appColors = colors(context);
    final primaryColor = appColors.primaryColor ?? Colors.blue;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      // 3. Dynamic text color
      style: GoogleFonts.inter(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 14,
      ),
      cursorColor: primaryColor,
      decoration: InputDecoration(
        // We use hintText instead of labelText to keep the UI clean
        // since we build custom labels in the LoginScreen
        hintText: widget.label,
        hintStyle: GoogleFonts.inter(
          color: isDark ? Colors.white38 : Colors.grey,
          fontSize: widget.labelFontSize,
        ),
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent,
        filled: isDark,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: isDark ? Colors.white54 : Colors.grey,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        // 4. Dynamic Borders
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
