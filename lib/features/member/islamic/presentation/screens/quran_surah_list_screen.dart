import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';
import 'package:niya_equb/features/member/islamic/data/repository/quran_repository.dart';
import 'package:niya_equb/features/member/islamic/data/static/surah_data.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/quran_reader_screen.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';

/// Surah index with search, offline badges and bookmarks.
class QuranSurahListScreen extends StatefulWidget {
  static const String routeName = '/islamic-quran';

  const QuranSurahListScreen({super.key});

  @override
  State<QuranSurahListScreen> createState() => _QuranSurahListScreenState();
}

class _QuranSurahListScreenState extends State<QuranSurahListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  List<SurahInfo> _results = SurahData.all;
  List<String> _bookmarks = [];
  ({int surah, int ayah})? _lastRead;
  TranslationEdition _translation = TranslationEdition.english;

  QuranRepository get _repository => sl<QuranRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final bookmarks = await IslamicPrefs.getBookmarks();
    final lastRead = await IslamicPrefs.getLastRead();
    final translationId = await IslamicPrefs.getTranslationId();

    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
      _lastRead = lastRead;
      _translation = TranslationEdition.fromId(translationId);
    });
  }

  void _onSearchChanged() {
    setState(() => _results = SurahData.search(_searchController.text));
  }

  Future<void> _openSurah(int number, {int? ayah}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuranReaderScreen(surahNumber: number, initialAyah: ayah),
      ),
    );
    await _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: IslamicColors.featureQuran,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'quran'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'surahs'.tr),
            Tab(text: 'bookmarks'.tr),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_lastRead != null) _continueCard(appColors),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_surahTab(appColors), _bookmarkTab(appColors)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueCard(dynamic appColors) {
    final surah = SurahData.byNumber(_lastRead!.surah);

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IslamicColors.featureQuran, Color(0xFF15803D)],
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () => _openSurah(_lastRead!.surah, ayah: _lastRead!.ayah),
          child: Padding(
            padding: EdgeInsets.all(13.w),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26.sp),
                SizedBox(width: 11.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'continue_reading'.tr,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${surah.englishName} · ${'ayah'.tr} ${_lastRead!.ayah}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  surah.arabicName,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _surahTab(dynamic appColors) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 6.h),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13.sp, color: appColors.titleTextColor),
            decoration: InputDecoration(
              hintText: 'search_surah'.tr,
              prefixIcon: Icon(Icons.search_rounded, size: 19.sp),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, size: 18.sp),
                      onPressed: () => _searchController.clear(),
                    ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? _empty(appColors, 'no_surah_found'.tr)
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 24.h),
                  separatorBuilder: (_, _) => SizedBox(height: 6.h),
                  itemCount: _results.length,
                  itemBuilder: (context, index) =>
                      _surahTile(appColors, _results[index]),
                ),
        ),
      ],
    );
  }

  Widget _surahTile(dynamic appColors, SurahInfo surah) {
    final isOffline = _repository.isCached(surah.number, _translation);

    return Material(
      color: appColors.accentColor,
      borderRadius: BorderRadius.circular(13.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(13.r),
        onTap: () => _openSurah(surah.number),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
          child: Row(
            children: [
              // Ayah-count medallion, in the eight-point star shape the mushaf
              // uses for surah numbers.
              SizedBox(
                width: 40.w,
                height: 40.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 27.w,
                        height: 27.w,
                        decoration: BoxDecoration(
                          color: IslamicColors.featureQuran.withValues(
                            alpha: 0.13,
                          ),
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                      ),
                    ),
                    Container(
                      width: 27.w,
                      height: 27.w,
                      decoration: BoxDecoration(
                        color: IslamicColors.featureQuran.withValues(
                          alpha: 0.13,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                    Text(
                      '${surah.number}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: IslamicColors.featureQuran,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            surah.englishName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: appColors.titleTextColor,
                            ),
                          ),
                        ),
                        if (isOffline) ...[
                          SizedBox(width: 5.w),
                          Icon(
                            Icons.offline_pin_rounded,
                            size: 12.sp,
                            color: IslamicColors.accentTeal,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${surah.ayahCount} ${'ayahs'.tr}',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w500,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                surah.arabicName,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: IslamicColors.featureQuran,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookmarkTab(dynamic appColors) {
    if (_bookmarks.isEmpty) {
      return _empty(appColors, 'no_bookmarks'.tr);
    }

    // Sort by surah then ayah so the list reads in mushaf order.
    final parsed =
        _bookmarks
            .map((b) {
              final parts = b.split(':');
              if (parts.length != 2) return null;
              final surah = int.tryParse(parts[0]);
              final ayah = int.tryParse(parts[1]);
              if (surah == null || ayah == null) return null;
              return (surah: surah, ayah: ayah);
            })
            .whereType<({int surah, int ayah})>()
            .toList()
          ..sort((a, b) {
            final bySurah = a.surah.compareTo(b.surah);
            return bySurah != 0 ? bySurah : a.ayah.compareTo(b.ayah);
          });

    return ListView.separated(
      padding: EdgeInsets.all(12.w),
      separatorBuilder: (_, _) => SizedBox(height: 6.h),
      itemCount: parsed.length,
      itemBuilder: (context, index) {
        final entry = parsed[index];
        final surah = SurahData.byNumber(entry.surah);

        return Material(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(13.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(13.r),
            onTap: () => _openSurah(entry.surah, ayah: entry.ayah),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark_rounded,
                    color: IslamicColors.mosqueDome,
                    size: 19.sp,
                  ),
                  SizedBox(width: 11.w),
                  Expanded(
                    child: Text(
                      '${surah.englishName} · ${'ayah'.tr} ${entry.ayah}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: appColors.titleTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18.sp,
                      color: appColors.bodyTextSmallColor,
                    ),
                    onPressed: () async {
                      await IslamicPrefs.toggleBookmark(
                        entry.surah,
                        entry.ayah,
                      );
                      await _loadPrefs();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _empty(dynamic appColors, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 46.sp,
            color: appColors.bodyTextSmallColor?.withValues(alpha: 0.5),
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 12.5.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }
}
