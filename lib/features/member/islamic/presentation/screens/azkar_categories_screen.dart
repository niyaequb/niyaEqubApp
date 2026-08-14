import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/data/models/azkar_model.dart';
import 'package:niya_equb/features/member/islamic/data/static/azkar_data.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/azkar_detail_screen.dart';

class AzkarCategoriesScreen extends StatelessWidget {
  static const String routeName = '/islamic-azkar';

  const AzkarCategoriesScreen({super.key});

  static String? _suggestedCategoryId() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return 'morning';
    if (hour >= 15 && hour < 20) return 'evening';
    if (hour >= 21 || hour < 4) return 'sleep';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final suggested = _suggestedCategoryId();

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: IslamicColors.featureAzkar,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'azkar'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (suggested != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
                child: _suggestionBanner(context, suggested),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.86,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _categoryCard(
                  context,
                  appColors,
                  AzkarData.categories[index],
                ),
                childCount: AzkarData.categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionBanner(BuildContext context, String categoryId) {
    final category = AzkarData.byId(categoryId);
    if (category == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              category.imagePath,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _open(context, category),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'azkar_suggested_now'.tr,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            ('azkar_${category.id}_title').tr,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            ('azkar_${category.id}_subtitle').tr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              height: 1.35,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    dynamic appColors,
    AzkarCategory category,
  ) {
    return Material(
      color: appColors.accentColor,
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, category),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    category.imagePath,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8.h,
                    right: 10.w,
                    child: Text(
                      category.titleAr,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(11.w, 9.h, 11.w, 11.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ('azkar_${category.id}_title').tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: appColors.titleTextColor,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${category.items.length} ${'azkar_items'.tr} · '
                    '${category.totalRepeats} ${'azkar_repetitions'.tr}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w600,
                      color: category.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, AzkarCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AzkarDetailScreen(category: category)),
    );
  }
}