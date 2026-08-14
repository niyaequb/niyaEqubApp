import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/config/app_color.dart';

class CustomSearchableDropdown extends StatefulWidget {
  final String label;
  final String? hint;
  final List<String> options;
  final TextEditingController controller;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final double borderRadius;

  const CustomSearchableDropdown({
    super.key,
    required this.label,
    this.hint,
    required this.options,
    required this.controller,
    this.prefixIcon,
    this.validator,
    this.borderRadius = 10,
  });

  @override
  State<CustomSearchableDropdown> createState() => _CustomSearchableDropdownState();
}

class _CustomSearchableDropdownState extends State<CustomSearchableDropdown> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
  }

  void _showDropdown(BuildContext context, AppColors appColors, bool isDark) {
    _searchController.clear();
    setState(() {
      _filteredOptions = widget.options;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: appColors.scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                children: [
                  // HandleBar
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10.h),
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: "search".tr,
                        prefixIcon: Icon(Icons.search, size: 20.sp, color: appColors.primaryColor),
                        hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 14.sp),
                        filled: isDark,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          _filteredOptions = widget.options
                              .where((option) => option.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        final isSelected = widget.controller.text == option;
                        return ListTile(
                          title: Text(
                            option,
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14.sp,
                            ),
                          ),
                          trailing: isSelected ? Icon(Icons.check, color: appColors.primaryColor) : null,
                          onTap: () {
                            widget.controller.text = option;
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
        // Trigger a rebuild of the parent widget to show validation if needed
        if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBrandColor = appColors.primaryColor;

    const Color darkBorder = Color(0xFF38434F);
    const Color darkText = Colors.white;
    const Color darkHint = Colors.white38;

    return InkWell(
      onTap: () => _showDropdown(context, appColors, isDark),
      child: IgnorePointer(
        child: TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          readOnly: true,
          style: GoogleFonts.inter(
            color: isDark ? darkText : Colors.black,
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: appColors.primaryColor),
            labelStyle: GoogleFonts.inter(
              color: isDark ? darkHint : Colors.grey,
              fontSize: 14.sp,
            ),
            filled: isDark,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
            contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(
                color: isDark ? darkBorder : primaryBrandColor!.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: primaryBrandColor!, width: 1.5),
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
        ),
      ),
    );
  }
}
