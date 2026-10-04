import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niya_equb/features/member/islamic/data/models/azkar_model.dart';

/// The full du'a collection for Umrah, grouped by when each one is said.
///
/// WHY THIS IS SEPARATE FROM umrah_data.dart
///
/// The step list answers "what do I do now"; this answers "what do I say".
/// They overlap but are not the same set: several of these — the travel du'a,
/// the du'a on first seeing the Ka'bah, the du'a when drinking Zamzam — belong
/// to no single rite, and a pilgrim looking for one of them should not have to
/// remember which step it was filed under.
///
/// ON COMPLETENESS AND ACCURACY
///
/// Every entry carries a reference. Where something is widely circulated but
/// not authentically established, it is either left out or marked in its
/// [virtue] line — a du'a printed without a source in an app people will
/// recite from at the Ka'bah is worse than one left out.
///
/// Two things are deliberately said rather than left implied:
///
///   * Qur'anic verses are given IN FULL. The Safa verse used to appear as
///     only its opening clause, which is the fragment the Prophet ﷺ recited
///     when approaching Safa — but printing a quarter of an ayah and ending it
///     without the rest reads as a truncation error, and a reader following
///     along has no way to know where the verse actually ends.
///   * Where nothing specific is narrated — during the circuits of tawaf, on
///     each trip of sa'i — the collection says so instead of inventing
///     something. The absence is itself the ruling.
class UmrahDuas {
  const UmrahDuas._();

  static const Color _accent = Color.fromARGB(255, 223, 145, 9);

  /// All categories, in the order the journey happens.
  static List<AzkarCategory> get categories => [
        beforeTravel,
        ihramAndTalbiyah,
        arrivingAtTheHaram,
        duringTawaf,
        afterTawaf,
        duringSai,
        completing,
        generalDuas,
      ];

  static AzkarCategory? byId(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 1. Before travelling
  // ------------------------------------------------------------------

  static AzkarCategory get beforeTravel => AzkarCategory(
        id: 'umrah_dua_travel',
        titleEn: 'dua_cat_travel'.tr,
        titleAr: 'أذكار السفر',
        subtitleEn: 'dua_cat_travel_sub'.tr,
        imagePath: 'assets/images/ibada/img_1.png',
        accent: _accent,
        items: [
          Dhikr(
            arabic: 'بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ '
                'وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
            transliteration: "Bismillah, tawakkaltu 'alallah, wa la hawla wa la "
                'quwwata illa billah',
            translation: 'dua_leaving_home'.tr,
            reference: 'ref_abu_dawud_tirmidhi'.tr,
            virtue: 'dua_leaving_home_virtue'.tr,
          ),
          Dhikr(
            arabic: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ '
                'مُقْرِنِينَ، وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
            transliteration: "Subhanalladhi sakhkhara lana hadha wa ma kunna "
                'lahu muqrinin, wa inna ila rabbina lamunqalibun',
            translation: 'dua_mounting'.tr,
            reference: 'ref_muslim'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ '
                'وَالتَّقْوَى، وَمِنَ الْعَمَلِ مَا تَرْضَى. اللَّهُمَّ هَوِّنْ '
                'عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ',
            transliteration: "Allahumma inna nas'aluka fi safarina hadhal-birra "
                "wat-taqwa, wa minal-'amali ma tarda. Allahumma hawwin 'alayna "
                "safarana hadha watwi 'anna bu'dah",
            translation: 'dua_journey'.tr,
            reference: 'ref_muslim'.tr,
          ),
          Dhikr(
            arabic: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
            transliteration: "A'udhu bi kalimatillahit-tammati min sharri ma khalaq",
            translation: 'dua_stopping_place'.tr,
            repeat: 3,
            reference: 'ref_muslim'.tr,
            virtue: 'dua_stopping_place_virtue'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 2. Ihram and talbiyah
  // ------------------------------------------------------------------

  static AzkarCategory get ihramAndTalbiyah => AzkarCategory(
        id: 'umrah_dua_ihram',
        titleEn: 'dua_cat_ihram'.tr,
        titleAr: 'الإحرام والتلبية',
        subtitleEn: 'dua_cat_ihram_sub'.tr,
        imagePath: 'assets/images/ibada/img_2.png',
        accent: _accent,
        items: [
          Dhikr(
            arabic: 'لَبَّيْكَ اللَّهُمَّ عُمْرَةً',
            transliteration: "Labbayk Allahumma 'umratan",
            translation: 'dua_intention_spoken'.tr,
            reference: 'ref_muslim'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنِّي أُرِيدُ الْعُمْرَةَ فَيَسِّرْهَا لِي '
                'وَتَقَبَّلْهَا مِنِّي',
            transliteration: "Allahumma inni uridul-'umrata fa yassirha li wa "
                'taqabbalha minni',
            translation: 'ihram_dua_1_translation'.tr,
            reference: 'ihram_dua_1_reference'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ مَحِلِّي حَيْثُ حَبَسْتَنِي',
            transliteration: 'Allahumma mahilli haythu habastani',
            translation: 'dua_conditional_ihram'.tr,
            reference: 'ref_bukhari_muslim'.tr,
            virtue: 'dua_conditional_ihram_virtue'.tr,
          ),
          Dhikr(
            arabic: 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ '
                'لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، '
                'لَا شَرِيكَ لَكَ',
            transliteration: 'Labbayk Allahumma labbayk, labbayka la sharika laka '
                "labbayk, innal-hamda wan-ni'mata laka wal-mulk, la sharika lak",
            translation: 'talbiyah_dua_1_translation'.tr,
            reference: 'ref_bukhari_muslim'.tr,
            virtue: 'talbiyah_dua_1_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ رِضَاكَ وَالْجَنَّةَ، '
                'وَأَعُوذُ بِكَ مِنْ سَخَطِكَ وَالنَّارِ',
            transliteration: "Allahumma inni as'aluka ridaka wal-jannah, wa "
                "a'udhu bika min sakhatika wan-nar",
            translation: 'dua_after_talbiyah'.tr,
            reference: 'ref_ibn_khuzaymah'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 3. Arriving at the Haram
  // ------------------------------------------------------------------

  static AzkarCategory get arrivingAtTheHaram => AzkarCategory(
        id: 'umrah_dua_arrival',
        titleEn: 'dua_cat_arrival'.tr,
        titleAr: 'دخول المسجد الحرام',
        subtitleEn: 'dua_cat_arrival_sub'.tr,
        imagePath: 'assets/images/ibada/img_3.png',
        accent: _accent,
        items: [
          Dhikr(
            arabic: 'بِسْمِ اللَّهِ، وَالصَّلَاةُ وَالسَّلَامُ عَلَى رَسُولِ '
                'اللَّهِ. اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
            transliteration: 'Bismillah, was-salatu was-salamu ala Rasulillah. '
                'Allahummaf-tah li abwaba rahmatik',
            translation: 'dua_entering_masjid_full'.tr,
            reference: 'ref_muslim_ibn_majah'.tr,
            virtue: 'dua_entering_masjid_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، '
                'تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
            transliteration: 'Allahumma antas-salam, wa minkas-salam, tabarakta '
                'ya dhal-jalali wal-ikram',
            translation: 'dua_seeing_kabah'.tr,
            reference: 'ref_seeing_kabah'.tr,
            virtue: 'dua_seeing_kabah_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
            transliteration: "Allahumma inni as'aluka min fadlik",
            translation: 'dua_leaving_masjid'.tr,
            reference: 'ref_muslim'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 4. During tawaf
  //
  // Tawaf is seven circuits, not seven recitations. Each circuit runs the
  // same three steps once: the takbir at the Black Stone where the circuit
  // begins, general dhikr while walking, and the Qur'anic du'a on the last
  // stretch between the Yamani corner and the Stone.
  //
  // The items are therefore in the order they are actually said, and the
  // repetition is carried by `cycles: 7` on the category rather than by a
  // repeat count on any one du'a. The first entry previously had repeat: 7,
  // which told a pilgrim to stand at the Stone saying the takbir seven times
  // before walking a single lap.
  // ------------------------------------------------------------------

  static AzkarCategory get duringTawaf => AzkarCategory(
        id: 'umrah_dua_tawaf',
        titleEn: 'dua_cat_tawaf'.tr,
        titleAr: 'أذكار الطواف',
        subtitleEn: 'dua_cat_tawaf_sub'.tr,
        imagePath: 'assets/images/ibada/img_4.png',
        accent: _accent,
        cycles: 7,
        cycleLabelKey: 'tawaf_circuit',
        items: [
          // Step 1 — at the Black Stone, where each circuit starts and ends.
          Dhikr(
            arabic: 'بِسْمِ اللَّهِ، وَاللَّهُ أَكْبَرُ',
            transliteration: 'Bismillah, wallahu akbar',
            translation: 'dua_black_stone'.tr,
            reference: 'ref_bukhari'.tr,
            virtue: 'dua_black_stone_virtue'.tr,
          ),
          // Step 2 — while walking the circuit. Nothing specific is narrated
          // for the circuits themselves, so this is offered as dhikr a
          // pilgrim may say, not as a prescribed formula.
          Dhikr(
            arabic: 'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا '
                'اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا '
                'بِاللَّهِ الْعَلِيِّ الْعَظِيمِ',
            transliteration: 'Subhanallah, walhamdulillah, wa la ilaha illallah, '
                "wallahu akbar, wa la hawla wa la quwwata illa billahil-'aliyyil-"
                "'azim",
            translation: 'dua_tawaf_general'.tr,
            reference: 'ref_no_specific_tawaf'.tr,
            virtue: 'dua_tawaf_general_virtue'.tr,
          ),
          // Step 3 — between the Yamani corner and the Black Stone, closing
          // the circuit.
          Dhikr(
            arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ '
                'حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
            transliteration: "Rabbana atina fid-dunya hasanatan wa fil-akhirati "
                "hasanatan wa qina 'adhaban-nar",
            translation: 'tawaf_dua_1_translation'.tr,
            reference: 'tawaf_dua_1_reference'.tr,
            virtue: 'dua_between_corners_virtue'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 5. After tawaf — Maqam Ibrahim, Multazam, Zamzam
  // ------------------------------------------------------------------

  static AzkarCategory get afterTawaf => AzkarCategory(
        id: 'umrah_dua_after_tawaf',
        titleEn: 'dua_cat_after_tawaf'.tr,
        titleAr: 'بعد الطواف',
        subtitleEn: 'dua_cat_after_tawaf_sub'.tr,
        imagePath: 'assets/images/ibada/img_5.png',
        accent: _accent,
        items: [
          Dhikr(
            arabic: 'وَاتَّخِذُوا مِن مَّقَامِ إِبْرَاهِيمَ مُصَلًّى',
            transliteration: 'Wattakhidhu min maqami Ibrahima musalla',
            translation: 'maqam_dua_1_translation'.tr,
            reference: 'maqam_dua_1_reference'.tr,
            virtue: 'dua_maqam_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا '
                'وَاسِعًا، وَشِفَاءً مِنْ كُلِّ دَاءٍ',
            transliteration: "Allahumma inni as'aluka 'ilman nafi'an, wa rizqan "
                "wasi'an, wa shifa'an min kulli da'",
            translation: 'dua_zamzam'.tr,
            reference: 'ref_zamzam'.tr,
            virtue: 'dua_zamzam_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ اغْفِرْ لِي وَارْحَمْنِي وَاهْدِنِي '
                'وَعَافِنِي وَارْزُقْنِي',
            transliteration: "Allahummaghfir li warhamni wahdini wa 'afini "
                'warzuqni',
            translation: 'dua_multazam'.tr,
            reference: 'ref_general_supplication'.tr,
            virtue: 'dua_multazam_virtue'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 6. Sa'i
  // ------------------------------------------------------------------

  static AzkarCategory get duringSai => AzkarCategory(
        id: 'umrah_dua_sai',
        titleEn: 'dua_cat_sai'.tr,
        titleAr: 'أذكار السعي',
        subtitleEn: 'dua_cat_sai_sub'.tr,
        imagePath: 'assets/images/ibada/img_6.png',
        accent: _accent,
        items: [
          // The verse IN FULL. See the class note.
          Dhikr(
            arabic: 'إِنَّ ٱلصَّفَا وَٱلْمَرْوَةَ مِن شَعَآئِرِ ٱللَّهِ ۖ فَمَنْ '
                'حَجَّ ٱلْبَيْتَ أَوِ ٱعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَن '
                'يَطَّوَّفَ بِهِمَا ۚ وَمَن تَطَوَّعَ خَيْرًا فَإِنَّ ٱللَّهَ '
                'شَاكِرٌ عَلِيمٌ',
            transliteration: "Innas-Safa wal-Marwata min sha'a'irillah, faman "
                "hajjal-bayta awi'tamara fala junaha 'alayhi an yattawwafa bihima, "
                'wa man tatawwa\'a khayran fa innallaha shakirun \'alim',
            translation: 'sai_verse_full'.tr,
            reference: 'sai_dua_1_reference'.tr,
            virtue: 'sai_verse_full_virtue'.tr,
          ),
          Dhikr(
            arabic: 'أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ',
            transliteration: "Abda'u bima bada'allahu bih",
            translation: 'dua_abdau'.tr,
            reference: 'ref_muslim'.tr,
            virtue: 'dua_abdau_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ',
            transliteration: 'Allahu akbar, Allahu akbar, Allahu akbar',
            translation: 'dua_takbir_safa'.tr,
            repeat: 3,
            reference: 'ref_muslim'.tr,
          ),
          Dhikr(
            arabic: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ '
                'الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. '
                'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ، أَنْجَزَ وَعْدَهُ، '
                'وَنَصَرَ عَبْدَهُ، وَهَزَمَ الْأَحْزَابَ وَحْدَهُ',
            transliteration: 'La ilaha illallahu wahdahu la sharika lah, lahul-'
                "mulku wa lahul-hamdu wa huwa 'ala kulli shay'in qadir. La ilaha "
                "illallahu wahdah, anjaza wa'dah, wa nasara 'abdah, wa hazamal-"
                'ahzaba wahdah',
            translation: 'sai_dua_2_translation'.tr,
            repeat: 3,
            reference: 'ref_muslim'.tr,
            virtue: 'dua_safa_marwah_virtue'.tr,
          ),
          Dhikr(
            arabic: 'رَبِّ اغْفِرْ وَارْحَمْ، إِنَّكَ أَنْتَ الْأَعَزُّ الْأَكْرَمُ',
            transliteration: "Rabbighfir warham, innaka antal-a'azzul-akram",
            translation: 'dua_between_sai'.tr,
            reference: 'ref_ibn_umar_athar'.tr,
            virtue: 'dua_between_sai_virtue'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 7. Completing
  // ------------------------------------------------------------------

  static AzkarCategory get completing => AzkarCategory(
        id: 'umrah_dua_completing',
        titleEn: 'dua_cat_completing'.tr,
        titleAr: 'إتمام العمرة',
        subtitleEn: 'dua_cat_completing_sub'.tr,
        imagePath: 'assets/images/ibada/azkar_6.png',
        accent: _accent,
        items: [
          Dhikr(
            arabic: 'اللَّهُمَّ اغْفِرْ لِلْمُحَلِّقِينَ',
            transliteration: "Allahummaghfir lil-muhalliqin",
            translation: 'dua_halq'.tr,
            reference: 'ref_bukhari_muslim'.tr,
            virtue: 'dua_halq_virtue'.tr,
          ),
          Dhikr(
            arabic: 'رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ',
            transliteration: "Rabbana taqabbal minna innaka antas-Sami'ul-'Alim",
            translation: 'dua_acceptance'.tr,
            reference: 'ref_baqarah_127'.tr,
          ),
          Dhikr(
            arabic: 'آيِبُونَ، تَائِبُونَ، عَابِدُونَ، لِرَبِّنَا حَامِدُونَ',
            transliteration: "Ayibuna, ta'ibuna, 'abiduna, li rabbina hamidun",
            translation: 'dua_returning'.tr,
            reference: 'ref_bukhari_muslim'.tr,
            virtue: 'dua_returning_virtue'.tr,
          ),
        ],
      );

  // ------------------------------------------------------------------
  // 8. General du'as
  // ------------------------------------------------------------------

  static AzkarCategory get generalDuas => AzkarCategory(
        id: 'umrah_dua_general',
        titleEn: 'dua_cat_general'.tr,
        titleAr: 'أدعية جامعة',
        subtitleEn: 'dua_cat_general_sub'.tr,
        imagePath: 'assets/images/ibada/azkar_1.png',
        accent: _accent,
        items: [
          Dhikr(
            arabic: 'رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ '
                'يَوْمَ يَقُومُ الْحِسَابُ',
            transliteration: "Rabbanaghfir li wa liwalidayya wa lil-mu'minina "
                'yawma yaqumul-hisab',
            translation: 'dua_parents'.tr,
            reference: 'ref_ibrahim_41'.tr,
          ),
          Dhikr(
            arabic: 'رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِن ذُرِّيَّتِي، '
                'رَبَّنَا وَتَقَبَّلْ دُعَاءِ',
            transliteration: "Rabbij'alni muqimas-salati wa min dhurriyyati, "
                "rabbana wa taqabbal du'a",
            translation: 'dua_offspring'.tr,
            reference: 'ref_ibrahim_40'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى '
                'وَالْعَفَافَ وَالْغِنَى',
            transliteration: "Allahumma inni as'alukal-huda wat-tuqa wal-'afafa "
                'wal-ghina',
            translation: 'dua_guidance'.tr,
            reference: 'ref_muslim'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ إِنَّكَ عَفُوٌّ كَرِيمٌ تُحِبُّ الْعَفْوَ '
                'فَاعْفُ عَنِّي',
            transliteration: "Allahumma innaka 'afuwwun karimun tuhibbul-'afwa "
                "fa'fu 'anni",
            translation: 'dua_pardon'.tr,
            reference: 'ref_tirmidhi_ibn_majah'.tr,
          ),
          Dhikr(
            arabic: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا '
                'هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ',
            transliteration: "Astaghfirullahal-'Azimalladhi la ilaha illa huwal-"
                'Hayyul-Qayyumu wa atubu ilayh',
            translation: 'dua_istighfar'.tr,
            repeat: 3,
            reference: 'ref_abu_dawud_tirmidhi'.tr,
            virtue: 'dua_istighfar_virtue'.tr,
          ),
          Dhikr(
            arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، '
                'كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، '
                'إِنَّكَ حَمِيدٌ مَجِيدٌ',
            transliteration: "Allahumma salli 'ala Muhammadin wa 'ala ali "
                "Muhammad, kama sallayta 'ala Ibrahima wa 'ala ali Ibrahim, "
                'innaka Hamidun Majid',
            translation: 'dua_salawat'.tr,
            reference: 'ref_bukhari_muslim'.tr,
          ),
        ],
      );
}
