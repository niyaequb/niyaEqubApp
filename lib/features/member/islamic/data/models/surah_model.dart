/// Offline index entry for one surah.
class SurahInfo {
  final int number;
  final String arabicName;
  final String englishName;
  final String englishTranslation;
  final int ayahCount;

  /// True for Meccan, false for Medinan.
  final bool isMeccan;

  const SurahInfo(
    this.number,
    this.arabicName,
    this.englishName,
    this.englishTranslation,
    this.ayahCount,
    this.isMeccan,
  );

  /// Every surah opens with the Basmalah except At-Tawbah, and Al-Fatihah
  /// counts it as its own first ayah rather than a heading.
  bool get showsBasmalah => number != 1 && number != 9;
}

/// One verse, as returned by the API and cached locally.
class Ayah {
  final int numberInSurah;

  /// 1..6236 across the whole mushaf — the key the audio CDN uses.
  final int globalNumber;
  final String arabic;
  final String? translation;
  final int? juz;
  final int? page;

  /// True when a prostration is recommended at this verse.
  final bool sajdah;

  const Ayah({
    required this.numberInSurah,
    required this.globalNumber,
    required this.arabic,
    this.translation,
    this.juz,
    this.page,
    this.sajdah = false,
  });

  Ayah copyWith({String? translation}) => Ayah(
    numberInSurah: numberInSurah,
    globalNumber: globalNumber,
    arabic: arabic,
    translation: translation ?? this.translation,
    juz: juz,
    page: page,
    sajdah: sajdah,
  );

  Map<String, dynamic> toJson() => {
    'n': numberInSurah,
    'g': globalNumber,
    'a': arabic,
    't': translation,
    'j': juz,
    'p': page,
    's': sajdah,
  };

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
    numberInSurah: json['n'] as int,
    globalNumber: json['g'] as int,
    arabic: json['a'] as String,
    translation: json['t'] as String?,
    juz: json['j'] as int?,
    page: json['p'] as int?,
    sajdah: (json['s'] ?? false) as bool,
  );
}

/// A fully loaded surah: index entry plus its verses.
class SurahContent {
  final SurahInfo info;
  final List<Ayah> ayahs;

  const SurahContent({required this.info, required this.ayahs});

  Map<String, dynamic> toJson() => {
    'number': info.number,
    'ayahs': ayahs.map((a) => a.toJson()).toList(),
  };
}

/// A reciter available for playback.
class Reciter {
  final String id;

  /// Path segment on the CDN, e.g. `ar.alafasy`.
  final String edition;

  /// Which bitrate directory this reciter's files actually live in.
  ///
  /// NOT a quality preference — a required part of the path. The CDN is laid
  /// out as `/quran/audio/{bitrate}/{edition}/{ayah}.mp3`, and each edition
  /// only exists at the bitrates it was encoded in. Ask for a combination that
  /// was never uploaded and the bucket answers 403 Forbidden rather than 404,
  /// because listing is denied — so a missing file reads like a permissions
  /// problem.
  ///
  /// That is what broke Abdul Basit and As-Sudais: both were requested at 128,
  /// both exist only at 192, and the reciters that did work were the ones
  /// encoded at 128.
  ///
  /// Check https://cdn.islamic.network/quran/info/by-ayah/info.json before
  /// adding a reciter — whichever bitrate directory holds their folder is the
  /// number that belongs here.
  final int bitrate;

  final String name;
  final String arabicName;

  const Reciter({
    required this.id,
    required this.edition,
    required this.bitrate,
    required this.name,
    required this.arabicName,
  });

  static const alafasy = Reciter(
    id: 'alafasy',
    edition: 'ar.alafasy',
    bitrate: 128,
    name: 'Mishary Rashid Alafasy',
    arabicName: 'مشاري راشد العفاسي',
  );

  static const husary = Reciter(
    id: 'husary',
    edition: 'ar.husary',
    bitrate: 128,
    name: 'Mahmoud Khalil Al-Husary',
    arabicName: 'محمود خليل الحصري',
  );

  static const minshawi = Reciter(
    id: 'minshawi',
    edition: 'ar.minshawi',
    bitrate: 128,
    name: 'Mohamed Siddiq El-Minshawi',
    arabicName: 'محمد صديق المنشاوي',
  );

  /// 192 only. Requesting this at 128 is what produced the 403.
  static const abdulbasit = Reciter(
    id: 'abdulbasit',
    edition: 'ar.abdulbasitmurattal',
    bitrate: 192,
    name: 'Abdul Basit (Murattal)',
    arabicName: 'عبد الباسط عبد الصمد',
  );

  /// 192 only, same as Abdul Basit.
  static const sudais = Reciter(
    id: 'sudais',
    edition: 'ar.abdurrahmaansudais',
    bitrate: 192,
    name: 'Abdurrahmaan As-Sudais',
    arabicName: 'عبدالرحمن السديس',
  );

  static const shaatree = Reciter(
    id: 'shaatree',
    edition: 'ar.shaatree',
    bitrate: 128,
    name: 'Abu Bakr Ash-Shaatree',
    arabicName: 'أبو بكر الشاطري',
  );

  static const List<Reciter> all = [
    alafasy,
    husary,
    minshawi,
    abdulbasit,
    sudais,
    shaatree,
  ];

  static Reciter fromId(String? id) =>
      all.firstWhere((r) => r.id == id, orElse: () => alafasy);
}

/// A translation edition available alongside the Arabic.
class TranslationEdition {
  final String id;
  final String label;

  /// Identifier used by the API, e.g. `en.sahih`.
  final String edition;

  const TranslationEdition({
    required this.id,
    required this.label,
    required this.edition,
  });

  static const none = TranslationEdition(
    id: 'none',
    label: 'Arabic only',
    edition: '',
  );

  static const english = TranslationEdition(
    id: 'en',
    label: 'English',
    edition: 'en.sahih',
  );

  static const amharic = TranslationEdition(
    id: 'am',
    label: 'አማርኛ (Amharic)',
    edition: 'am.sadiq',
  );

  static const transliteration = TranslationEdition(
    id: 'translit',
    label: 'Transliteration',
    edition: 'en.transliteration',
  );

  static const List<TranslationEdition> all = [
    none,
    english,
    amharic,
    transliteration,
  ];

  static TranslationEdition fromId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => english);
}
