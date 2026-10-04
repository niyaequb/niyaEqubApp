import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/data/static/umrah_data.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/umrah_dua_categories_screen.dart';

/// The Umrah guide.
///
/// READING ORDER IS THE DESIGN
///
/// The page used to open on the list of things forbidden in ihram, which is a
/// strange first thing to say to someone who may not yet know what Umrah is.
/// It now runs:
///
///   1. What Umrah actually is, in the language and in the sharia.
///   2. What is promised for it — the reason anyone saves for years to go.
///   3. What ihram forbids, placed before the rites because it binds from the
///      moment ihram is entered.
///   4. The four acts that make one complete, at a glance.
///   5. The rites, in order, which is what people return to on the day.
///   6. The azkar, and the sourcing notice.
///
/// Someone opening this for the first time gets an answer; someone standing at
/// the miqat scrolls to section five.
class UmrahGuideScreen extends StatefulWidget {
  static const String routeName = '/islamic-umrah';

  const UmrahGuideScreen({super.key});

  @override
  State<UmrahGuideScreen> createState() => _UmrahGuideScreenState();
}

class _UmrahGuideScreenState extends State<UmrahGuideScreen> {
  static const Color _accent = Color.fromARGB(255, 235, 152, 10);
  static const Color _deep = Color(0xFF1F6F4A);

  final Set<int> _open = {0};

  /// Opens the categorised du'a collection.
  ///
  /// Used to push a single AzkarDetailScreen holding every supplication in one
  /// flat run. That list could only ever contain du'as attached to a rite, so
  /// the travel du'a, the du'a on first seeing the Ka'bah and the du'a for
  /// Zamzam had nowhere to live — which is most of what "the du'as are not
  /// complete" meant.
  void _openAzkar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UmrahDuaCategoriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _hero(),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 28.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Order: what it is -> why do it -> what it forbids -> what
                // makes it valid -> how to perform it -> the du'as.
                //
                // The prohibitions sit third, not last. They bind from the
                // moment ihram is entered, which is before the first rite, so
                // burying them under the step list means reaching them after
                // the point where they could still be acted on.

                // 1. What is Umrah?
                _meaningCard(appColors),
                SizedBox(height: 16.h),

                // 2. Why perform Umrah
                _sectionTitle(
                  appColors,
                  'umrah_virtues_title'.tr,
                  'umrah_virtues_subtitle'.tr,
                ),
                SizedBox(height: 10.h),
                for (final v in UmrahData.virtues) _virtueCard(appColors, v),
                SizedBox(height: 12.h),

                // 3. Forbidden while in ihram
                _prohibitionsCard(appColors),
                SizedBox(height: 18.h),

                // 4. What makes Umrah complete
                _sectionTitle(
                  appColors,
                  'umrah_pillars_title'.tr,
                  'umrah_pillars_subtitle'.tr,
                ),
                SizedBox(height: 10.h),
                _pillarStrip(appColors),
                SizedBox(height: 18.h),

                // 5. The rites, in order
                _sectionTitle(
                  appColors,
                  'umrah_steps'.tr,
                  'umrah_steps_subtitle'.tr,
                ),
                SizedBox(height: 10.h),
                for (var i = 0; i < UmrahData.steps.length; i++)
                  _stepCard(appColors, i),
                SizedBox(height: 14.h),

                // 6. Umrah Azkar
                _azkarShortcut(),
                SizedBox(height: 14.h),

                _reviewNotice(appColors),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Hero
  // ------------------------------------------------------------------

  /// Collapsing header carrying the daytime Makkah photograph.
  ///
  /// Always header.jpg, never header.jpg: this screen is read while planning as
  /// often as on the night itself, and a dark header above a light page reads
  /// as a bug rather than a mood.
  Widget _hero() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 186.h,
      backgroundColor: _accent,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: 'umrah_azkar'.tr,
          icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
          onPressed: _openAzkar,
        ),
      ],
      // Only shown once collapsed, so the expanded hero stays uncluttered.
      title: Text(
        'umrah_guide'.tr,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/ibada/header.jpg',
              fit: BoxFit.cover,
              // A missing asset would otherwise leave the title sitting on
              // bare white, which looks broken. The accent colour is the same
              // one the app bar collapses to, so the failure is invisible.
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: _accent),
            ),
            // Bottom-weighted scrim: the title sits low and so does the
            // brightest part of the photograph, so the darkening has to favour
            // the lower half or the text lands on the courtyard glare.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.52),
                  ],
                  stops: const [0.0, 0.34, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 16.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'العمرة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF3CE7B),
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'umrah_guide'.tr,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 10),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'umrah_hero_tagline'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.92),
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
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

  // ------------------------------------------------------------------
  // 1. Meaning
  // ------------------------------------------------------------------

  Widget _meaningCard(dynamic appColors) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _deep.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _deep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 18.sp,
                  color: _deep,
                ),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: Text(
                  'umrah_meaning_title'.tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: appColors.titleTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 11.h),
          Text(
            'umrah_meaning_lead'.tr,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.6,
              color: appColors.bodyTextColor,
            ),
          ),
          SizedBox(height: 13.h),
          _definitionRow(
            appColors,
            label: 'umrah_meaning_linguistic_label'.tr,
            body: 'umrah_meaning_linguistic_body'.tr,
          ),
          SizedBox(height: 9.h),
          _definitionRow(
            appColors,
            label: 'umrah_meaning_shariah_label'.tr,
            body: 'umrah_meaning_shariah_body'.tr,
          ),
          SizedBox(height: 13.h),
          Wrap(
            spacing: 7.w,
            runSpacing: 7.h,
            children: [
              for (final fact in UmrahData.quickFacts) _factChip(fact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _definitionRow(
    dynamic appColors, {
    required String label,
    required String body,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: _deep.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border(
          left: BorderSide(color: _deep.withValues(alpha: 0.55), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: _deep,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            body,
            style: TextStyle(
              fontSize: 11.5.sp,
              height: 1.55,
              color: appColors.bodyTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _factChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF9A6206),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 4. Pillars
  // ------------------------------------------------------------------

  /// Horizontally scrolling rather than a grid.
  ///
  /// The labels and hints are far longer in Amharic than in English, and a
  /// fixed grid overflows on the narrow phones this app is mostly used on. A
  /// strip of fixed-width cards cannot overflow at any text length.
  Widget _pillarStrip(dynamic appColors) {
    final pillars = UmrahData.pillars;

    return SizedBox(
      height: 116.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        itemCount: pillars.length,
        separatorBuilder: (_, _) => SizedBox(width: 9.w),
        itemBuilder: (context, index) {
          final p = pillars[index];
          return Container(
            width: 132.w,
            padding: EdgeInsets.all(11.w),
            decoration: BoxDecoration(
              color: appColors.accentColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: appColors.borderColor ?? Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26.w,
                      height: 26.w,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(p.icon, size: 14.sp, color: _accent),
                    ),
                    const Spacer(),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: _accent.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  p.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                    color: appColors.titleTextColor,
                  ),
                ),
                SizedBox(height: 3.h),
                Expanded(
                  child: Text(
                    p.hint,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      height: 1.4,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // 2. Virtues
  // ------------------------------------------------------------------

  Widget _virtueCard(dynamic appColors, UmrahVirtue v) {
    return Container(
      margin: EdgeInsets.only(bottom: 9.h),
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: appColors.borderColor ?? Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: _deep.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(v.icon, size: 17.sp, color: _deep),
          ),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.title,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: appColors.titleTextColor,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  v.body,
                  style: TextStyle(
                    fontSize: 11.sp,
                    height: 1.55,
                    color: appColors.bodyTextColor,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 11.sp,
                      color: appColors.bodyTextSmallColor,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        v.reference,
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w600,
                          color: appColors.bodyTextSmallColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Shared
  // ------------------------------------------------------------------

  Widget _sectionTitle(dynamic appColors, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.w,
              height: 15.h,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: appColors.titleTextColor,
                ),
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 3.h),
          Padding(
            padding: EdgeInsets.only(left: 11.w),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5.sp,
                height: 1.4,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _azkarShortcut() {
    return Material(
      borderRadius: BorderRadius.circular(16.r),
      color: _accent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: _openAzkar,
        child: Padding(
          padding: EdgeInsets.all(15.w),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: Colors.white, size: 26.sp),
              SizedBox(width: 13.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'umrah_azkar'.tr,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'umrah_azkar_hint'.tr,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        height: 1.35,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 14.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 3. Forbidden while in ihram
  // ------------------------------------------------------------------

  Widget _prohibitionsCard(dynamic appColors) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.do_not_disturb_on_rounded,
                size: 18.sp,
                color: const Color(0xFFB91C1C),
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: Text(
                  'umrah_prohibitions'.tr,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'umrah_prohibitions_subtitle'.tr,
            style: TextStyle(
              fontSize: 10.sp,
              height: 1.4,
              color: const Color(0xFF991B1B),
            ),
          ),
          SizedBox(height: 10.h),
          for (final item in UmrahData.ihramProhibitions)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Container(
                      width: 5.w,
                      height: 5.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB91C1C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 11.sp,
                        height: 1.45,
                        color: appColors.bodyTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 5. The rites
  // ------------------------------------------------------------------

  Widget _stepCard(dynamic appColors, int index) {
    final step = UmrahData.steps[index];
    final isOpen = _open.contains(index);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isOpen
              ? _accent.withValues(alpha: 0.45)
              : (appColors.borderColor ?? Colors.transparent),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: () => setState(() {
                isOpen ? _open.remove(index) : _open.add(index);
              }),
              child: Padding(
                padding: EdgeInsets.all(13.w),
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.titleEn,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                              color: appColors.titleTextColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            step.titleAr,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: appColors.bodyTextSmallColor,
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
            ),
            if (isOpen)
              Padding(
                padding: EdgeInsets.fromLTRB(13.w, 0, 13.w, 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final action in step.actions)
                      Padding(
                        padding: EdgeInsets.only(bottom: 7.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14.sp,
                              color: _accent,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                action,
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  height: 1.5,
                                  color: appColors.bodyTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    for (final dua in step.duas) ...[
                      SizedBox(height: 8.h),
                      _duaBlock(appColors, dua),
                    ],

                    if (step.caution != null) ...[
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 15.sp,
                              color: const Color(0xFFB45309),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                step.caution!,
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 9.h),
                    Text(
                      step.reference,
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w600,
                        color: appColors.bodyTextSmallColor,
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

  Widget _duaBlock(dynamic appColors, dynamic dua) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(11.r),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dua.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              height: 2.0,
              color: appColors.titleTextColor,
            ),
          ),
          SizedBox(height: 9.h),
          Text(
            dua.transliteration,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: _accent,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            dua.translation,
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.5,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewNotice(dynamic appColors) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: appColors.borderColor ?? Colors.transparent),
      ),
      child: Text(
        'umrah_review_notice'.tr,
        style: TextStyle(
          fontSize: 10.sp,
          height: 1.5,
          color: appColors.bodyTextSmallColor,
        ),
      ),
    );
  }
}
