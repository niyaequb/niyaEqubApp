import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

/// The app's primary button.
///
/// Taps are debounced: a second press within [_tapCooldown] of the first is
/// ignored. Without this, an impatient double tap submits a form twice or
/// pushes the same screen onto the stack twice — and the duplicate screen is
/// what makes the app look like it jumped backwards when you press back.
class RoundedButton extends StatefulWidget {
  RoundedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.submitting = false,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderRadius = 10,
    this.borderSide,
    this.elevation,
    double? fontSize,
    this.fontWeight = FontWeight.w500,
    this.letterSpacing,
    this.height = 45,
    this.width = double.infinity,
    this.icon,
    this.iconGap = 8.0,
    this.alignment = MainAxisAlignment.center,
  }) : fontSize = fontSize ?? 14.r;

  final String label;
  final void Function()? onPressed;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool submitting;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final double borderRadius;
  final BorderSide? borderSide;
  final double? elevation;
  final double fontSize;
  final FontWeight fontWeight;
  final double? letterSpacing;
  final double? height;
  final double? width;
  final Widget? icon;
  final double iconGap;
  final MainAxisAlignment alignment;

  @override
  State<RoundedButton> createState() => _RoundedButtonState();
}

class _RoundedButtonState extends State<RoundedButton> {
  /// Long enough to cover a route transition and a fat-fingered double tap.
  static const Duration _tapCooldown = Duration(milliseconds: 600);

  DateTime? _lastTap;

  void _handleTap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null && now.difference(last) < _tapCooldown) return;

    _lastTap = now;
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final foreground =
        widget.foregroundColor ?? Colors.black.withValues(alpha: .7);

    return Container(
      margin: widget.margin,
      height: widget.height,
      width: widget.width,
      child: ElevatedButton(
        onPressed: (widget.submitting || widget.onPressed == null)
            ? null
            : _handleTap,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return widget.disabledBackgroundColor ??
                  Colors.grey.withValues(alpha: .12);
            }
            return widget.backgroundColor ?? Colors.blue;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return widget.disabledForegroundColor ??
                  Colors.black.withValues(alpha: .3);
            }
            return foreground;
          }),
          padding: WidgetStateProperty.all(widget.padding),
          elevation: WidgetStateProperty.all(widget.elevation),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              side: widget.borderSide ?? BorderSide.none,
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return (widget.foregroundColor ?? Colors.black).withValues(
                alpha: 0.3,
              );
            }
            return null;
          }),
        ),
        child: widget.submitting
            ? Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                ),
              )
            : widget.icon != null
            ? Row(
                mainAxisAlignment: widget.alignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.icon!,
                  SizedBox(width: widget.iconGap),
                  CustomText(
                    title: widget.label,
                    fontSize: widget.fontSize,
                    fontWeight: widget.fontWeight,
                    letterSpacing: widget.letterSpacing,
                    textColor: foreground,
                  ),
                ],
              )
            : CustomText(
                title: widget.label,
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                letterSpacing: widget.letterSpacing,
                textColor: foreground,
              ),
      ),
    );
  }
}
