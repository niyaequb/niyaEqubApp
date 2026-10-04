import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niya_equb/features/member/islamic/data/models/azkar_model.dart';
import 'package:niya_equb/features/member/islamic/data/static/umrah_duas.dart';

/// One rite of Umrah, in the order it is performed.
class UmrahStep {
  final String id;
  final String titleEn;
  final String titleAr;

  /// What to do, in plain language.
  final List<String> actions;

  /// Supplications tied to this step. Empty where none are narrated.
  final List<Dhikr> duas;

  /// Mistakes that are common enough to be worth naming.
  final String? caution;

  /// Where the ruling or supplication comes from.
  final String reference;

  final IconData icon;

  const UmrahStep({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.actions,
    this.duas = const [],
    this.caution,
    required this.reference,
    required this.icon,
  });
}

/// A reward promised for Umrah in the Qur'an or the Sunnah.
///
/// Kept as data rather than hardcoded into the screen so the virtues can be
/// reordered, translated and cited the same way the rites are. Every entry
/// carries its own [reference] — an unattributed hadith in a religious app is
/// worse than no hadith.
class UmrahVirtue {
  final String title;
  final String body;
  final String reference;
  final IconData icon;

  const UmrahVirtue({
    required this.title,
    required this.body,
    required this.reference,
    required this.icon,
  });
}

/// One of the acts an Umrah is not valid without.
class UmrahPillar {
  final String label;
  final String hint;
  final IconData icon;

  const UmrahPillar({
    required this.label,
    required this.hint,
    required this.icon,
  });
}

/// The rites of Umrah and the supplications narrated for them.
class UmrahData {
  static List<UmrahStep> get steps => [
        _ihram,
        _talbiyah,
        _enteringHaram,
        _tawaf,
        _maqam,
        _zamzam,
        _sai,
        _halq,
      ];

  static UmrahStep? byId(String id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // What Umrah is, and why it is done
  //
  // These come FIRST on the guide screen, ahead of the rites. Someone opening
  // it for the first time needs to know what they are being asked to do and
  // what is promised for it; the step-by-step is what they come back for on
  // the day.
  // ---------------------------------------------------------------------

  /// The acts an Umrah is not valid without — shown as an at-a-glance strip
  /// so the whole rite fits on one screen before the detail begins.
  static List<UmrahPillar> get pillars => [
        UmrahPillar(
          label: 'umrah_pillar_ihram'.tr,
          hint: 'umrah_pillar_ihram_hint'.tr,
          icon: Icons.checkroom_rounded,
        ),
        UmrahPillar(
          label: 'umrah_pillar_tawaf'.tr,
          hint: 'umrah_pillar_tawaf_hint'.tr,
          icon: Icons.rotate_right_rounded,
        ),
        UmrahPillar(
          label: 'umrah_pillar_sai'.tr,
          hint: 'umrah_pillar_sai_hint'.tr,
          icon: Icons.directions_walk_rounded,
        ),
        UmrahPillar(
          label: 'umrah_pillar_halq'.tr,
          hint: 'umrah_pillar_halq_hint'.tr,
          icon: Icons.content_cut_rounded,
        ),
      ];

  /// Short facts for the chips under the definition.
  static List<String> get quickFacts => [
        'umrah_fact_anytime'.tr,
        'umrah_fact_duration'.tr,
        'umrah_fact_lesser'.tr,
      ];

  static List<UmrahVirtue> get virtues => [
        UmrahVirtue(
          title: 'umrah_virtue_1_title'.tr,
          body: 'umrah_virtue_1_body'.tr,
          reference: 'bukhari_muslim_ref'.tr,
          icon: Icons.cleaning_services_rounded,
        ),
        UmrahVirtue(
          title: 'umrah_virtue_2_title'.tr,
          body: 'umrah_virtue_2_body'.tr,
          reference: 'bukhari_muslim_ref'.tr,
          icon: Icons.nightlight_round,
        ),
        UmrahVirtue(
          title: 'umrah_virtue_3_title'.tr,
          body: 'umrah_virtue_3_body'.tr,
          reference: 'umrah_virtue_3_reference'.tr,
          icon: Icons.local_fire_department_rounded,
        ),
        UmrahVirtue(
          title: 'umrah_virtue_4_title'.tr,
          body: 'umrah_virtue_4_body'.tr,
          reference: 'umrah_virtue_4_reference'.tr,
          icon: Icons.volunteer_activism_rounded,
        ),
        UmrahVirtue(
          title: 'umrah_virtue_5_title'.tr,
          body: 'umrah_virtue_5_body'.tr,
          reference: 'umrah_virtue_5_reference'.tr,
          icon: Icons.mosque_rounded,
        ),
        UmrahVirtue(
          title: 'umrah_virtue_6_title'.tr,
          body: 'umrah_virtue_6_body'.tr,
          reference: 'umrah_virtue_6_reference'.tr,
          icon: Icons.diversity_1_rounded,
        ),
      ];

  /// Every supplication in the guide, grouped by when it is said.
  ///
  /// Lives in umrah_duas.dart rather than being flattened out of [steps]: a
  /// pilgrim looking for the travel du'a or the du'a for drinking Zamzam
  /// should not have to remember which rite it was filed under, and several
  /// belong to no rite at all.
  static List<AzkarCategory> get duaCategories => UmrahDuas.categories;

  /// Kept for the old single-list entry point.
  static AzkarCategory get azkarCategory => AzkarCategory(
        id: 'umrah',
        titleEn: 'umrah_azkar_title'.tr,
        titleAr: 'أذكار العمرة',
        subtitleEn: 'umrah_azkar_subtitle'.tr,
        imagePath: 'assets/images/ibada/img_5.png',
        accent: const Color.fromARGB(255, 223, 145, 9),
        items: [
          for (final step in steps) ...step.duas,
        ],
      );

  // ---------------------------------------------------------------------

  static UmrahStep get _ihram => UmrahStep(
        id: 'ihram',
        titleEn: 'ihram_title'.tr,
        titleAr: 'الإحرام',
        icon: Icons.checkroom_rounded,
        actions: [
          'ihram_action_1'.tr,
          'ihram_action_2'.tr,
          'ihram_action_3'.tr,
          'ihram_action_4'.tr,
          'ihram_action_5'.tr,
        ],
        duas: [
          Dhikr(
            arabic: 'اللَّهُمَّ إِنِّي أُرِيدُ الْعُمْرَةَ فَيَسِّرْهَا لِي وَتَقَبَّلْهَا مِنِّي',
            transliteration:
                'Allahumma inni uridul-\'umrata fa yassirha li wa taqabbalha minni',
            translation: 'ihram_dua_1_translation'.tr,
            reference: 'ihram_dua_1_reference'.tr,
          ),
        ],
        caution: 'ihram_caution'.tr,
        reference: 'ihram_reference'.tr,
      );

  static UmrahStep get _talbiyah => UmrahStep(
        id: 'talbiyah',
        titleEn: 'talbiyah_title'.tr,
        titleAr: 'التلبية',
        icon: Icons.campaign_rounded,
        actions: [
          'talbiyah_action_1'.tr,
          'talbiyah_action_2'.tr,
          'talbiyah_action_3'.tr,
          'talbiyah_action_4'.tr,
        ],
        duas: [
          Dhikr(
            arabic: 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ '
                'لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، '
                'لَا شَرِيكَ لَكَ',
            transliteration: 'Labbayk Allahumma labbayk, labbayka la sharika laka '
                'labbayk, innal-hamda wan-ni\'mata laka wal-mulk, la sharika lak',
            translation: 'talbiyah_dua_1_translation'.tr,
            repeat: 3,
            reference: 'bukhari_muslim_ref'.tr,
            virtue: 'talbiyah_dua_1_virtue'.tr,
          ),
        ],
        reference: 'bukhari_muslim_ref'.tr,
      );

  static UmrahStep get _enteringHaram => UmrahStep(
        id: 'entering_haram',
        titleEn: 'entering_haram_title'.tr,
        titleAr: 'دخول المسجد الحرام',
        icon: Icons.door_front_door_rounded,
        actions: [
          'entering_haram_action_1'.tr,
          'entering_haram_action_2'.tr,
        ],
        duas: [
          Dhikr(
            arabic: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
            transliteration: 'Allahummaf-tah li abwaba rahmatik',
            translation: 'entering_haram_dua_1_translation'.tr,
            reference: 'muslim_ref'.tr,
          ),
        ],
        caution: 'entering_haram_caution'.tr,
        reference: 'entering_haram_reference'.tr,
      );

  static UmrahStep get _tawaf => UmrahStep(
        id: 'tawaf',
        titleEn: 'tawaf_title'.tr,
        titleAr: 'الطواف',
        icon: Icons.rotate_right_rounded,
        actions: [
          'tawaf_action_1'.tr,
          'tawaf_action_2'.tr,
          'tawaf_action_3'.tr,
          'tawaf_action_4'.tr,
        ],
        duas: [
          Dhikr(
            arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ '
                'حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
            transliteration: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati '
                'hasanatan wa qina \'adhaban-nar',
            translation: 'tawaf_dua_1_translation'.tr,
            reference: 'tawaf_dua_1_reference'.tr,
          ),
        ],
        caution: 'tawaf_caution'.tr,
        reference: 'tawaf_reference'.tr,
      );

  static UmrahStep get _maqam => UmrahStep(
        id: 'maqam',
        titleEn: 'maqam_title'.tr,
        titleAr: 'ركعتان خلف المقام',
        icon: Icons.self_improvement_rounded,
        actions: [
          'maqam_action_1'.tr,
          'maqam_action_2'.tr,
          'maqam_action_3'.tr,
        ],
        duas: [
          Dhikr(
            arabic: 'وَاتَّخِذُوا مِن مَّقَامِ إِبْرَاهِيمَ مُصَلًّى',
            transliteration: 'Wattakhidhu min maqami Ibrahima musalla',
            translation: 'maqam_dua_1_translation'.tr,
            reference: 'maqam_dua_1_reference'.tr,
          ),
        ],
        reference: 'maqam_reference'.tr,
      );

  static UmrahStep get _zamzam => UmrahStep(
        id: 'zamzam',
        titleEn: 'zamzam_title'.tr,
        titleAr: 'ماء زمزم',
        icon: Icons.water_drop_rounded,
        actions: [
          'zamzam_action_1'.tr,
          'zamzam_action_2'.tr,
        ],
        reference: 'zamzam_reference'.tr,
      );

  static UmrahStep get _sai => UmrahStep(
        id: 'sai',
        titleEn: 'sai_title'.tr,
        titleAr: 'السعي',
        icon: Icons.directions_walk_rounded,
        actions: [
          'sai_action_1'.tr,
          'sai_action_2'.tr,
          'sai_action_3'.tr,
          'sai_action_4'.tr,
        ],
        duas: [
          // The verse in full. It appeared here as only its opening clause —
          // the fragment the Prophet ﷺ recited on approaching Safa — but a
          // quarter of an ayah ending without the rest reads as a truncation
          // bug, and a reader following along cannot tell where the verse
          // actually ends.
          Dhikr(
            arabic: 'إِنَّ ٱلصَّفَا وَٱلْمَرْوَةَ مِن شَعَآئِرِ ٱللَّهِ ۖ فَمَنْ '
                'حَجَّ ٱلْبَيْتَ أَوِ ٱعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَن '
                'يَطَّوَّفَ بِهِمَا ۚ وَمَن تَطَوَّعَ خَيْرًا فَإِنَّ ٱللَّهَ '
                'شَاكِرٌ عَلِيمٌ',
            transliteration: "Innas-Safa wal-Marwata min sha'a'irillah, faman "
                "hajjal-bayta awi'tamara fala junaha 'alayhi an yattawwafa "
                "bihima, wa man tatawwa'a khayran fa innallaha shakirun 'alim",
            translation: 'sai_verse_full'.tr,
            reference: 'sai_dua_1_reference'.tr,
          ),
          Dhikr(
            arabic: 'أَبْدَأُ بِمَا بَدَأَ اللَّهُ بِهِ',
            transliteration: "Abda'u bima bada'allahu bih",
            translation: 'dua_abdau'.tr,
            reference: 'ref_muslim'.tr,
            virtue: 'dua_abdau_virtue'.tr,
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
            reference: 'sai_dua_2_reference'.tr,
          ),
          Dhikr(
            arabic: 'رَبِّ اغْفِرْ وَارْحَمْ، إِنَّكَ أَنْتَ الْأَعَزُّ الْأَكْرَمُ',
            transliteration: "Rabbighfir warham, innaka antal-a'azzul-akram",
            translation: 'dua_between_sai'.tr,
            reference: 'ref_ibn_umar_athar'.tr,
          ),
        ],
        caution: 'sai_caution'.tr,
        reference: 'sai_reference'.tr,
      );

  static UmrahStep get _halq => UmrahStep(
        id: 'halq',
        titleEn: 'halq_title'.tr,
        titleAr: 'الحلق أو التقصير',
        icon: Icons.content_cut_rounded,
        actions: [
          'halq_action_1'.tr,
          'halq_action_2'.tr,
          'halq_action_3'.tr,
        ],
        caution: 'halq_caution'.tr,
        reference: 'bukhari_muslim_ref'.tr,
      );

  /// Things that are forbidden from entering ihram until the hair is cut.
  static List<String> get ihramProhibitions => [
        'prohibition_1'.tr,
        'prohibition_2'.tr,
        'prohibition_3'.tr,
        'prohibition_4'.tr,
        'prohibition_5'.tr,
        'prohibition_6'.tr,
      ];
}