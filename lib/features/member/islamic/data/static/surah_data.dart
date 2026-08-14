import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';

/// The 114 surahs with Hafs ayah counts, bundled offline.
///
/// Only the index lives here — the verse text is fetched and cached by
/// [QuranRepository]. Shipping the index locally means the surah list, the
/// search and the global-ayah maths for per-ayah audio all work with no
/// network at all.
class SurahData {
  static const List<SurahInfo> all = [
    SurahInfo(1, 'الفاتحة', 'Al-Fatihah', 'The Opener', 7, true),
    SurahInfo(2, 'البقرة', 'Al-Baqarah', 'The Cow', 286, false),
    SurahInfo(3, 'آل عمران', "Ali 'Imran", 'Family of Imran', 200, false),
    SurahInfo(4, 'النساء', 'An-Nisa', 'The Women', 176, false),
    SurahInfo(5, 'المائدة', "Al-Ma'idah", 'The Table Spread', 120, false),
    SurahInfo(6, 'الأنعام', "Al-An'am", 'The Cattle', 165, true),
    SurahInfo(7, 'الأعراف', "Al-A'raf", 'The Heights', 206, true),
    SurahInfo(8, 'الأنفال', 'Al-Anfal', 'The Spoils of War', 75, false),
    SurahInfo(9, 'التوبة', 'At-Tawbah', 'The Repentance', 129, false),
    SurahInfo(10, 'يونس', 'Yunus', 'Jonah', 109, true),
    SurahInfo(11, 'هود', 'Hud', 'Hud', 123, true),
    SurahInfo(12, 'يوسف', 'Yusuf', 'Joseph', 111, true),
    SurahInfo(13, 'الرعد', "Ar-Ra'd", 'The Thunder', 43, false),
    SurahInfo(14, 'ابراهيم', 'Ibrahim', 'Abraham', 52, true),
    SurahInfo(15, 'الحجر', 'Al-Hijr', 'The Rocky Tract', 99, true),
    SurahInfo(16, 'النحل', 'An-Nahl', 'The Bee', 128, true),
    SurahInfo(17, 'الإسراء', 'Al-Isra', 'The Night Journey', 111, true),
    SurahInfo(18, 'الكهف', 'Al-Kahf', 'The Cave', 110, true),
    SurahInfo(19, 'مريم', 'Maryam', 'Mary', 98, true),
    SurahInfo(20, 'طه', 'Taha', 'Ta-Ha', 135, true),
    SurahInfo(21, 'الأنبياء', 'Al-Anbya', 'The Prophets', 112, true),
    SurahInfo(22, 'الحج', 'Al-Hajj', 'The Pilgrimage', 78, false),
    SurahInfo(23, 'المؤمنون', "Al-Mu'minun", 'The Believers', 118, true),
    SurahInfo(24, 'النور', 'An-Nur', 'The Light', 64, false),
    SurahInfo(25, 'الفرقان', 'Al-Furqan', 'The Criterion', 77, true),
    SurahInfo(26, 'الشعراء', "Ash-Shu'ara", 'The Poets', 227, true),
    SurahInfo(27, 'النمل', 'An-Naml', 'The Ant', 93, true),
    SurahInfo(28, 'القصص', 'Al-Qasas', 'The Stories', 88, true),
    SurahInfo(29, 'العنكبوت', "Al-'Ankabut", 'The Spider', 69, true),
    SurahInfo(30, 'الروم', 'Ar-Rum', 'The Romans', 60, true),
    SurahInfo(31, 'لقمان', 'Luqman', 'Luqman', 34, true),
    SurahInfo(32, 'السجدة', 'As-Sajdah', 'The Prostration', 30, true),
    SurahInfo(33, 'الأحزاب', 'Al-Ahzab', 'The Combined Forces', 73, false),
    SurahInfo(34, 'سبإ', 'Saba', 'Sheba', 54, true),
    SurahInfo(35, 'فاطر', 'Fatir', 'Originator', 45, true),
    SurahInfo(36, 'يس', 'Ya-Sin', 'Ya Sin', 83, true),
    SurahInfo(37, 'الصافات', 'As-Saffat', 'Those Who Set The Ranks', 182, true),
    SurahInfo(38, 'ص', 'Sad', 'The Letter Sad', 88, true),
    SurahInfo(39, 'الزمر', 'Az-Zumar', 'The Troops', 75, true),
    SurahInfo(40, 'غافر', 'Ghafir', 'The Forgiver', 85, true),
    SurahInfo(41, 'فصلت', 'Fussilat', 'Explained in Detail', 54, true),
    SurahInfo(42, 'الشورى', 'Ash-Shuraa', 'The Consultation', 53, true),
    SurahInfo(43, 'الزخرف', 'Az-Zukhruf', 'The Ornaments of Gold', 89, true),
    SurahInfo(44, 'الدخان', 'Ad-Dukhan', 'The Smoke', 59, true),
    SurahInfo(45, 'الجاثية', 'Al-Jathiyah', 'The Crouching', 37, true),
    SurahInfo(46, 'الأحقاف', 'Al-Ahqaf', 'The Wind-Curved Sandhills', 35, true),
    SurahInfo(47, 'محمد', 'Muhammad', 'Muhammad', 38, false),
    SurahInfo(48, 'الفتح', 'Al-Fath', 'The Victory', 29, false),
    SurahInfo(49, 'الحجرات', 'Al-Hujurat', 'The Rooms', 18, false),
    SurahInfo(50, 'ق', 'Qaf', 'The Letter Qaf', 45, true),
    SurahInfo(51, 'الذاريات', 'Adh-Dhariyat', 'The Winnowing Winds', 60, true),
    SurahInfo(52, 'الطور', 'At-Tur', 'The Mount', 49, true),
    SurahInfo(53, 'النجم', 'An-Najm', 'The Star', 62, true),
    SurahInfo(54, 'القمر', 'Al-Qamar', 'The Moon', 55, true),
    SurahInfo(55, 'الرحمن', 'Ar-Rahman', 'The Beneficent', 78, false),
    SurahInfo(56, 'الواقعة', "Al-Waqi'ah", 'The Inevitable', 96, true),
    SurahInfo(57, 'الحديد', 'Al-Hadid', 'The Iron', 29, false),
    SurahInfo(58, 'المجادلة', 'Al-Mujadila', 'The Pleading Woman', 22, false),
    SurahInfo(59, 'الحشر', 'Al-Hashr', 'The Exile', 24, false),
    SurahInfo(60, 'الممتحنة', 'Al-Mumtahanah', 'She That Is To Be Examined', 13, false),
    SurahInfo(61, 'الصف', 'As-Saf', 'The Ranks', 14, false),
    SurahInfo(62, 'الجمعة', "Al-Jumu'ah", 'The Congregation, Friday', 11, false),
    SurahInfo(63, 'المنافقون', 'Al-Munafiqun', 'The Hypocrites', 11, false),
    SurahInfo(64, 'التغابن', 'At-Taghabun', 'The Mutual Disillusion', 18, false),
    SurahInfo(65, 'الطلاق', 'At-Talaq', 'The Divorce', 12, false),
    SurahInfo(66, 'التحريم', 'At-Tahrim', 'The Prohibition', 12, false),
    SurahInfo(67, 'الملك', 'Al-Mulk', 'The Sovereignty', 30, true),
    SurahInfo(68, 'القلم', 'Al-Qalam', 'The Pen', 52, true),
    SurahInfo(69, 'الحاقة', 'Al-Haqqah', 'The Reality', 52, true),
    SurahInfo(70, 'المعارج', "Al-Ma'arij", 'The Ascending Stairways', 44, true),
    SurahInfo(71, 'نوح', 'Nuh', 'Noah', 28, true),
    SurahInfo(72, 'الجن', 'Al-Jinn', 'The Jinn', 28, true),
    SurahInfo(73, 'المزمل', 'Al-Muzzammil', 'The Enshrouded One', 20, true),
    SurahInfo(74, 'المدثر', 'Al-Muddaththir', 'The Cloaked One', 56, true),
    SurahInfo(75, 'القيامة', 'Al-Qiyamah', 'The Resurrection', 40, true),
    SurahInfo(76, 'الانسان', 'Al-Insan', 'The Man', 31, false),
    SurahInfo(77, 'المرسلات', 'Al-Mursalat', 'The Emissaries', 50, true),
    SurahInfo(78, 'النبإ', 'An-Naba', 'The Tidings', 40, true),
    SurahInfo(79, 'النازعات', "An-Nazi'at", 'Those Who Drag Forth', 46, true),
    SurahInfo(80, 'عبس', "'Abasa", 'He Frowned', 42, true),
    SurahInfo(81, 'التكوير', 'At-Takwir', 'The Overthrowing', 29, true),
    SurahInfo(82, 'الإنفطار', 'Al-Infitar', 'The Cleaving', 19, true),
    SurahInfo(83, 'المطففين', 'Al-Mutaffifin', 'The Defrauding', 36, true),
    SurahInfo(84, 'الإنشقاق', 'Al-Inshiqaq', 'The Sundering', 25, true),
    SurahInfo(85, 'البروج', 'Al-Buruj', 'The Mansions of the Stars', 22, true),
    SurahInfo(86, 'الطارق', 'At-Tariq', 'The Nightcomer', 17, true),
    SurahInfo(87, 'الأعلى', "Al-A'la", 'The Most High', 19, true),
    SurahInfo(88, 'الغاشية', 'Al-Ghashiyah', 'The Overwhelming', 26, true),
    SurahInfo(89, 'الفجر', 'Al-Fajr', 'The Dawn', 30, true),
    SurahInfo(90, 'البلد', 'Al-Balad', 'The City', 20, true),
    SurahInfo(91, 'الشمس', 'Ash-Shams', 'The Sun', 15, true),
    SurahInfo(92, 'الليل', 'Al-Layl', 'The Night', 21, true),
    SurahInfo(93, 'الضحى', 'Ad-Duhaa', 'The Morning Hours', 11, true),
    SurahInfo(94, 'الشرح', 'Ash-Sharh', 'The Relief', 8, true),
    SurahInfo(95, 'التين', 'At-Tin', 'The Fig', 8, true),
    SurahInfo(96, 'العلق', "Al-'Alaq", 'The Clot', 19, true),
    SurahInfo(97, 'القدر', 'Al-Qadr', 'The Power', 5, true),
    SurahInfo(98, 'البينة', 'Al-Bayyinah', 'The Clear Proof', 8, false),
    SurahInfo(99, 'الزلزلة', 'Az-Zalzalah', 'The Earthquake', 8, false),
    SurahInfo(100, 'العاديات', "Al-'Adiyat", 'The Courser', 11, true),
    SurahInfo(101, 'القارعة', "Al-Qari'ah", 'The Calamity', 11, true),
    SurahInfo(102, 'التكاثر', 'At-Takathur', 'The Rivalry in World Increase', 8, true),
    SurahInfo(103, 'العصر', "Al-'Asr", 'The Declining Day', 3, true),
    SurahInfo(104, 'الهمزة', 'Al-Humazah', 'The Traducer', 9, true),
    SurahInfo(105, 'الفيل', 'Al-Fil', 'The Elephant', 5, true),
    SurahInfo(106, 'قريش', 'Quraysh', 'Quraysh', 4, true),
    SurahInfo(107, 'الماعون', "Al-Ma'un", 'The Small Kindnesses', 7, true),
    SurahInfo(108, 'الكوثر', 'Al-Kawthar', 'The Abundance', 3, true),
    SurahInfo(109, 'الكافرون', 'Al-Kafirun', 'The Disbelievers', 6, true),
    SurahInfo(110, 'النصر', 'An-Nasr', 'The Divine Support', 3, false),
    SurahInfo(111, 'المسد', 'Al-Masad', 'The Palm Fibre', 5, true),
    SurahInfo(112, 'الإخلاص', 'Al-Ikhlas', 'The Sincerity', 4, true),
    SurahInfo(113, 'الفلق', 'Al-Falaq', 'The Daybreak', 5, true),
    SurahInfo(114, 'الناس', 'An-Nas', 'Mankind', 6, true),
  ];

  static const int totalAyahs = 6236;

  static SurahInfo byNumber(int number) => all[(number - 1).clamp(0, 113)];

  /// Running total of ayahs before [surahNumber]. Needed to turn a
  /// (surah, ayah) pair into the 1..6236 global index the per-ayah audio CDN
  /// is keyed on.
  static int ayahOffsetBefore(int surahNumber) {
    var total = 0;
    for (var i = 0; i < surahNumber - 1; i++) {
      total += all[i].ayahCount;
    }
    return total;
  }

  static int globalAyahNumber(int surahNumber, int ayahNumber) =>
      ayahOffsetBefore(surahNumber) + ayahNumber;

  /// Case- and diacritic-insensitive search across both name forms.
  static List<SurahInfo> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;

    final asNumber = int.tryParse(q);
    if (asNumber != null && asNumber >= 1 && asNumber <= 114) {
      return [byNumber(asNumber)];
    }

    return all.where((s) {
      return s.englishName.toLowerCase().contains(q) ||
          s.englishTranslation.toLowerCase().contains(q) ||
          s.arabicName.contains(query.trim()) ||
          s.englishName.toLowerCase().replaceAll(RegExp("[-' ]"), '').contains(
            q.replaceAll(RegExp("[-' ]"), ''),
          );
    }).toList();
  }
}
