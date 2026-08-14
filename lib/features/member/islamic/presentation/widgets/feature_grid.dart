import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';

/// One tile in the circular feature grid.
class IslamicFeature {
  final String labelKey;
  final IconData? icon;
  final String? imagePath;
  final Color color;
  final VoidCallback onTap;

  /// Optional short badge, e.g. a resume marker or a count.
  final String? badge;

  const IslamicFeature({
    required this.labelKey,
    this.icon,
    this.imagePath,
    required this.color,
    required this.onTap,
    this.badge,
  });
}

/// The grid of round, colour-coded shortcuts, matching the reference app's
/// layout: circular icon/image over a two-line label.
class FeatureGrid extends StatelessWidget {
  const FeatureGrid({
    super.key,
    required this.features,
    required this.labels,
    this.crossAxisCount = 3, // 3 columns -> 2 rows for 6 items
  });

  final List<IslamicFeature> features;

  /// Resolved labels, passed in so the grid stays free of translation calls
  /// and is trivially testable.
  final List<String> labels;

  /// Number of columns in the grid (defaults to 3 so 6 items fit in 2 rows).
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: features.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 4.h,
          crossAxisSpacing: 6.w,
          childAspectRatio: crossAxisCount == 3 ? 1.2 : 0.78,
        ),
        itemBuilder: (context, index) {
          return _FeatureTile(
            feature: features[index],
            label: index < labels.length ? labels[index] : '',
          );
        },
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.label});

  final IslamicFeature feature;
  final String label;

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: feature.onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: feature.color.withValues(alpha: isDark ? 0.22 : 0.13),
                  border: Border.all(
                    color: feature.color.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: feature.imagePath != null
                    ? ClipOval(
                        child: Image.asset(
                          feature.imagePath!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : (feature.icon != null
                        ? Icon(
                            feature.icon,
                            size: 24.sp,
                            color: feature.color,
                          )
                        : const SizedBox.shrink()),
              ),
              if (feature.badge != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: feature.color,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: appColors.accentColor ?? Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: BoxConstraints(minWidth: 16.w),
                    child: Text(
                      feature.badge!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: appColors.titleTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}