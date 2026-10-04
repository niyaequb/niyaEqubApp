import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/data/models/azkar_model.dart';
import 'package:niya_equb/features/member/islamic/data/static/umrah_duas.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/azkar_detail_screen.dart';

/// The du'a collection for Umrah, listed by occasion.
///
/// Replaces the single flat list the Azkar button used to open. That list held
/// only the supplications attached to a rite, in rite order, which left two
/// problems: anything belonging to no rite — the travel du'a, the du'a on
/// first seeing the Ka'bah, the du'a for drinking Zamzam — had nowhere to
/// live, and finding one meant scrolling the whole thing.
///
/// Grouped by occasion instead, so a pilgrim standing at Safa opens Sa'i and
/// nothing else.
class UmrahDuaCategoriesScreen extends StatelessWidget {
  static const String routeName = '/islamic-umrah-duas';

  const UmrahDuaCategoriesScreen({super.key});

  static const Color _accent = Color.fromARGB(255, 235, 152, 10);

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final categories = UmrahDuas.categories;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'umrah_azkar'.tr,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'أذكار وأدعية العمرة',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 24.h),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          if (index == 0) return _intro(appColors);
          return _categoryCard(context, appColors, categories[index - 1], index);
        },
      ),
    );
  }

  Widget _intro(dynamic appColors) {
    return Container(
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13.r),
        border: Border.all(color: _accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16.sp, color: _accent),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'umrah_dua_intro'.tr,
              style: TextStyle(
                fontSize: 10.5.sp,
                height: 1.5,
                color: appColors.bodyTextColor,
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
    int position,
  ) {
    return Material(
      color: appColors.accentColor,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AzkarDetailScreen(category: category),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(13.w),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Text(
                    '$position',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.titleEn,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: appColors.titleTextColor,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      category.titleAr,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: _accent,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      category.subtitleEn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        height: 1.4,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                children: [
                  Text(
                    '${category.items.length}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                  Text(
                    'duas_count_label'.tr,
                    style: TextStyle(
                      fontSize: 8.5.sp,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
