import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';
import 'package:niya_equb/features/member/islamic/data/static/surah_data.dart';

/// Fetches Quran text and caches it permanently on device.
///
/// The surah index ships with the app, so the list, search and audio all work
/// offline from first launch. Verse text is pulled once per surah + translation
/// pair and then stored in Hive forever — the text of the Quran does not
/// change, so there is no invalidation policy and no TTL. In practice a user
/// who reads a surah once never hits the network for it again.
class QuranRepository {
  QuranRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.alquran.cloud/v1/',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  static const String boxName = 'quranCacheBox';

  /// Audio CDN root. The bitrate is NOT fixed here — it varies per reciter and
  /// is part of the path. See Reciter.bitrate.
  static const String _audioBase = 'https://cdn.islamic.network/quran';

  static Box? _box;

  static Future<void> initialize() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox(boxName);
  }

  static Box? get _cache => (_box?.isOpen ?? false) ? _box : null;

  String _cacheKey(int surah, String translationEdition) =>
      'surah_${surah}_${translationEdition.isEmpty ? 'ar' : translationEdition}';

  /// Loads a surah, preferring the cache.
  ///
  /// Throws [QuranUnavailable] only when the surah is not cached *and* the
  /// network fails — the caller can then show a retry affordance rather than
  /// an empty page.
  Future<SurahContent> getSurah(
    int surahNumber, {
    TranslationEdition translation = TranslationEdition.english,
  }) async {
    final info = SurahData.byNumber(surahNumber);
    final key = _cacheKey(surahNumber, translation.edition);

    final cached = _readCache(key, info);
    if (cached != null) return cached;

    try {
      final editions = translation.edition.isEmpty
          ? 'quran-uthmani'
          : 'quran-uthmani,${translation.edition}';

      final response = await _dio.get<dynamic>('surah/$surahNumber/editions/$editions');

      final content = _parseResponse(response.data, info);
      await _writeCache(key, content);
      return content;
    } on DioException catch (e) {
      logger('Quran: fetch failed for surah $surahNumber — ${e.message}');

      // Arabic-only may already be cached even when the translated pair is not.
      if (translation.edition.isNotEmpty) {
        final arabicOnly = _readCache(_cacheKey(surahNumber, ''), info);
        if (arabicOnly != null) return arabicOnly;
      }

      throw QuranUnavailable(
        'Could not load ${info.englishName}. Check your connection and try '
        'again — once loaded, it stays available offline.',
      );
    } catch (e) {
      logger('Quran: unexpected error for surah $surahNumber — $e');
      throw QuranUnavailable('Something went wrong loading this surah.');
    }
  }

  /// True when the surah is already on device for the given translation.
  bool isCached(int surahNumber, TranslationEdition translation) {
    final box = _cache;
    if (box == null) return false;
    return box.containsKey(_cacheKey(surahNumber, translation.edition));
  }

  /// Number of surahs available offline — shown in settings so the user knows
  /// what they can read on a plane.
  int cachedSurahCount(TranslationEdition translation) {
    final box = _cache;
    if (box == null) return 0;

    var count = 0;
    for (var i = 1; i <= 114; i++) {
      if (box.containsKey(_cacheKey(i, translation.edition))) count++;
    }
    return count;
  }

  Future<void> clearCache() async {
    await _cache?.clear();
  }

  // ------------------------------------------------------------------
  // Audio
  // ------------------------------------------------------------------

  /// Continuous recitation of a whole surah.
  String surahAudioUrl(int surahNumber, Reciter reciter) =>
      '$_audioBase/audio-surah/${reciter.bitrate}/${reciter.edition}/$surahNumber.mp3';

  /// A single verse, keyed by its 1..6236 position in the mushaf.
  ///
  /// The bitrate segment comes from the reciter rather than a constant. It
  /// used to be hardcoded to 128, which silently limited the app to the
  /// reciters that happen to be encoded at that rate — the rest returned 403
  /// and surfaced to the user as "check your connection", which sent everyone
  /// looking at the network instead of the URL.
  String ayahAudioUrl(int surahNumber, int ayahNumber, Reciter reciter) {
    final global = SurahData.globalAyahNumber(surahNumber, ayahNumber);
    return '$_audioBase/audio/${reciter.bitrate}/${reciter.edition}/$global.mp3';
  }

  // ------------------------------------------------------------------
  // Cache plumbing
  // ------------------------------------------------------------------

  SurahContent? _readCache(String key, SurahInfo info) {
    final box = _cache;
    if (box == null) return null;

    final raw = box.get(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw as String);
      final list = (decoded['ayahs'] as List)
          .map((e) => Ayah.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (list.isEmpty) return null;
      return SurahContent(info: info, ayahs: list);
    } catch (e) {
      logger('Quran: corrupt cache entry $key, dropping it — $e');
      box.delete(key);
      return null;
    }
  }

  Future<void> _writeCache(String key, SurahContent content) async {
    try {
      await _cache?.put(key, jsonEncode(content.toJson()));
    } catch (e) {
      logger('Quran: could not cache $key — $e');
    }
  }

  SurahContent _parseResponse(dynamic data, SurahInfo info) {
    final payload = data is String ? jsonDecode(data) : data;
    final editions = payload['data'];

    if (editions is! List || editions.isEmpty) {
      throw const FormatException('Unexpected Quran API shape');
    }

    final arabicAyahs = (editions.first['ayahs'] as List)
        .cast<Map<String, dynamic>>();

    List<Map<String, dynamic>>? translationAyahs;
    if (editions.length > 1) {
      translationAyahs = (editions[1]['ayahs'] as List)
          .cast<Map<String, dynamic>>();
    }

    final ayahs = <Ayah>[];

    for (var i = 0; i < arabicAyahs.length; i++) {
      final a = arabicAyahs[i];
      final numberInSurah = (a['numberInSurah'] as num).toInt();

      // The API embeds the Basmalah at the head of ayah 1 for every surah
      // except Al-Fatihah and At-Tawbah. Strip it, because the reader renders
      // the Basmalah as its own ornamented header.
      var arabic = (a['text'] ?? '').toString();
      if (numberInSurah == 1 && info.showsBasmalah) {
        arabic = _stripLeadingBasmalah(arabic);
      }

      ayahs.add(
        Ayah(
          numberInSurah: numberInSurah,
          globalNumber: (a['number'] as num?)?.toInt() ??
              SurahData.globalAyahNumber(info.number, numberInSurah),
          arabic: arabic.trim(),
          translation: translationAyahs != null && i < translationAyahs.length
              ? (translationAyahs[i]['text'] ?? '').toString()
              : null,
          juz: (a['juz'] as num?)?.toInt(),
          page: (a['page'] as num?)?.toInt(),
          sajdah: a['sajda'] == true || a['sajda'] is Map,
        ),
      );
    }

    if (ayahs.isEmpty) {
      throw const FormatException('Quran API returned no verses');
    }

    return SurahContent(info: info, ayahs: ayahs);
  }

  static String _stripLeadingBasmalah(String text) {
    // Match the Basmalah in its several Unicode spellings without depending on
    // exact diacritics: everything up to and including the word "الرحيم" when
    // it appears within the first stretch of the verse.
    const marker = 'الرحيم';
    final normalized = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');

    final index = normalized.indexOf(marker);
    if (index < 0 || index > 45) return text;

    // Walk the original string counting non-diacritic characters until we pass
    // the marker, so the diacritics in the remainder survive intact.
    var seen = 0;
    final target = index + marker.length;

    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      final isDiacritic =
          (code >= 0x064B && code <= 0x0652) || code == 0x0670;
      if (!isDiacritic) seen++;
      if (seen >= target) {
        return text.substring(i + 1).trim();
      }
    }

    return text;
  }
}

/// Raised when a surah is neither cached nor reachable.
class QuranUnavailable implements Exception {
  final String message;
  const QuranUnavailable(this.message);

  @override
  String toString() => message;
}
