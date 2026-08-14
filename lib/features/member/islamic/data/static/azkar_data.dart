import 'package:flutter/material.dart';
import 'package:niya_equb/features/member/islamic/data/models/azkar_model.dart';

/// Azkar bundled offline, grouped by occasion.
class AzkarData {
  static List<AzkarCategory> get categories => [
        _morning,
        _evening,
        _afterPrayer,
        _sleep,
        _waking,
        _distress,
        _general,
      ];

  static AzkarCategory? byId(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static final _morning = AzkarCategory(
    id: 'morning',
    titleEn: 'Morning Azkar',
    titleAr: '',
    subtitleEn: 'Recited after Fajr until sunrise',
    imagePath: 'assets/images/ibada/azkar_1.png',
    accent: const Color(0xFFF59E0B),
    items: [
      Dhikr(
        arabic:
            'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\n'
            'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ '
            'لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ '
            'يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ '
            'وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        transliteration:
            'Allahu la ilaha illa huwal-hayyul-qayyum, la ta\'khudhuhu '
            'sinatun wa la nawm...',
        translation: 'dhikr_ayat_kursi',
        repeat: 1,
        reference: 'Al-Baqarah 2:255 (Ayat al-Kursi)',
        virtue: 'dhikr_virtue_morning',
      ),
      Dhikr(
        arabic:
            'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ '
            'وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
        transliteration:
            'Qul huwa Allahu ahad. Allahus-samad. Lam yalid wa lam yulad. '
            'Wa lam yakun lahu kufuwan ahad.',
        translation: 'dhikr_ikhlas',
        repeat: 3,
        reference: 'Surah Al-Ikhlas 112',
      ),
      Dhikr(
        arabic:
            'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ '
            'وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ '
            'وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
        transliteration:
            'Qul a\'udhu bi rabbil-falaq. Min sharri ma khalaq...',
        translation: 'dhikr_falaq',
        repeat: 3,
        reference: 'Surah Al-Falaq 113',
      ),
      Dhikr(
        arabic:
            'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ '
            'مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ '
            'مِنَ الْجِنَّةِ وَالنَّاسِ',
        transliteration: 'Qul a\'udhu bi rabbin-nas. Malikin-nas...',
        translation: 'dhikr_nas',
        repeat: 3,
        reference: 'Surah An-Nas 114',
      ),
      Dhikr(
        arabic:
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ '
            'وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        transliteration:
            'Asbahna wa asbahal-mulku lillah, walhamdu lillah, la ilaha '
            'illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamd, wa '
            'huwa \'ala kulli shay\'in qadir.',
        translation: 'dhikr_morning_dominion',
        repeat: 1,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، '
            'وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، '
            'أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ '
            'الذُّنُوبَ إِلَّا أَنْتَ',
        transliteration:
            'Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana '
            '\'abduk...',
        translation: 'dhikr_sayyid_istighfar',
        repeat: 1,
        reference: 'Sahih al-Bukhari (Sayyid al-Istighfar)',
        virtue: 'dhikr_virtue_istighfar',
      ),
      Dhikr(
        arabic:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي '
            'السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
        transliteration:
            'Bismillahil-ladhi la yadurru ma\'asmihi shay\'un fil-ardi wa la '
            'fis-sama\'i wa huwas-sami\'ul-\'alim.',
        translation: 'dhikr_protection',
        repeat: 3,
        reference: 'Sunan Abu Dawud, at-Tirmidhi',
      ),
      Dhikr(
        arabic:
            'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ '
            'وَسَلَّمَ نَبِيًّا',
        transliteration:
            'Raditu billahi rabban, wa bil-Islami dinan, wa bi Muhammadin '
            'sallallahu \'alayhi wa sallama nabiyyan.',
        translation: 'dhikr_contentment',
        repeat: 3,
        reference: 'Sunan Abu Dawud',
      ),
      Dhikr(
        arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
        transliteration: "Subhanallahi wa bihamdih.",
        translation: 'dhikr_subhanallah_bihamdih',
        repeat: 100,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
        virtue: 'dhikr_virtue_tasbih',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، '
            'وَإِلَيْكَ النُّشُورُ',
        transliteration:
            'Allahumma bika asbahna, wa bika amsayna, wa bika nahya, wa bika '
            'namutu, wa ilaykan-nushur.',
        translation: 'dhikr_morning_entry',
        repeat: 1,
        reference: 'Sunan at-Tirmidhi',
      ),
      Dhikr(
        arabic:
            'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، '
            'وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ '
            'أَبِينَا إِبْرَاهِيمَ، حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
        transliteration:
            "Asbahna 'ala fitratil-Islam, wa 'ala kalimatil-ikhlas, wa 'ala "
            'dini nabiyyina Muhammadin sallallahu \'alayhi wa sallam, wa \'ala '
            'millati abina Ibrahim, hanifan musliman wa ma kana minal-'
            'mushrikin.',
        translation: 'dhikr_fitrah',
        repeat: 1,
        reference: 'Musnad Ahmad',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ، '
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي دِينِي وَدُنْيَايَ وَأَهْلِي '
            'وَمَالِي',
        transliteration:
            "Allahumma inni as'alukal-'afwa wal-'afiyata fid-dunya wal-akhirah, "
            "Allahumma inni as'alukal-'afwa wal-'afiyata fi dini wa dunyaya wa "
            'ahli wa mali.',
        translation: 'dhikr_pardon_wellbeing',
        repeat: 1,
        reference: 'Sunan Abu Dawud, Ibn Majah',
      ),
      Dhikr(
        arabic:
            'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، '
            'وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
        transliteration:
            "Ya Hayyu ya Qayyumu bi rahmatika astaghith, aslih li sha'ni "
            "kullahu, wa la takilni ila nafsi tarfata 'ayn.",
        translation: 'dhikr_ya_hayyu',
        repeat: 1,
        reference: 'Sunan an-Nasa\'i (al-Kubra), al-Hakim',
      ),
      Dhikr(
        arabic:
            'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        transliteration:
            "A'udhu bi kalimatillahit-tammati min sharri ma khalaq.",
        translation: 'dhikr_perfect_words',
        repeat: 3,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، '
            'وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
        transliteration:
            "Subhanallahi wa bihamdihi 'adada khalqih, wa rida nafsih, wa "
            'zinata \'arshih, wa midada kalimatih.',
        translation: 'dhikr_subhanallah_count',
        repeat: 3,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، '
            'وَعَمَلًا مُتَقَبَّلًا',
        transliteration:
            "Allahumma inni as'aluka 'ilman nafi'an, wa rizqan tayyiban, wa "
            "'amalan mutaqabbalan.",
        translation: 'dhikr_beneficial_knowledge',
        repeat: 1,
        reference: 'Sunan Ibn Majah',
      ),
      Dhikr(
        arabic: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
        transliteration: 'Astaghfirullaha wa atubu ilayh.',
        translation: 'dhikr_astaghfirullah_repent',
        repeat: 100,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ '
            'وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        transliteration:
            'La ilaha illallahu wahdahu la sharika lah, lahul-mulku wa '
            'lahul-hamd, wa huwa \'ala kulli shay\'in qadir.',
        translation: 'dhikr_unit_praise',
        repeat: 10,
        reference: 'Sahih Muslim',
      ),
    ],
  );

  static final _evening = AzkarCategory(
    id: 'evening',
    titleEn: 'Evening Azkar',
    titleAr: '',
    subtitleEn: 'Recited after Asr until Maghrib',
    imagePath: 'assets/images/ibada/azkar_2.png',
    accent: const Color(0xFF6366F1),
    items: [
      Dhikr(
        arabic:
            'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ '
            'لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ '
            'وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        transliteration:
            'Allahu la ilaha illa huwal-hayyul-qayyum...',
        translation: 'dhikr_ayat_kursi',
        repeat: 1,
        reference: 'Al-Baqarah 2:255 (Ayat al-Kursi)',
        virtue: 'dhikr_virtue_evening',
      ),
      Dhikr(
        arabic:
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ '
            'وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        transliteration:
            'Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha '
            'illallahu wahdahu la sharika lah...',
        translation: 'dhikr_evening_dominion',
        repeat: 1,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، '
            'وَإِلَيْكَ الْمَصِيرُ',
        transliteration:
            'Allahumma bika amsayna, wa bika asbahna, wa bika nahya, wa bika '
            'namutu, wa ilaykal-masir.',
        translation: 'dhikr_evening_entry',
        repeat: 1,
        reference: 'Sunan at-Tirmidhi',
      ),
      Dhikr(
        arabic:
            'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        transliteration:
            "A'udhu bi kalimatillahit-tammati min sharri ma khalaq.",
        translation: 'dhikr_perfect_words',
        repeat: 3,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي '
            'السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
        transliteration:
            'Bismillahil-ladhi la yadurru ma\'asmihi shay\'un fil-ardi wa la '
            'fis-sama\'i wa huwas-sami\'ul-\'alim.',
        translation: 'dhikr_protection',
        repeat: 3,
        reference: 'Sunan Abu Dawud, at-Tirmidhi',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي '
            'فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ',
        transliteration:
            "Allahumma 'afini fi badani, Allahumma 'afini fi sam'i, Allahumma "
            "'afini fi basari, la ilaha illa ant.",
        translation: 'dhikr_wellbeing',
        repeat: 3,
        reference: 'Sunan Abu Dawud',
      ),
      Dhikr(
        arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
        transliteration: 'Subhanallahi wa bihamdih.',
        translation: 'dhikr_subhanallah_bihamdih',
        repeat: 100,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
        transliteration: 'Astaghfirullaha wa atubu ilayh.',
        translation: 'dhikr_astaghfirullah_repent',
        repeat: 100,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
    ],
  );

  static final _afterPrayer = AzkarCategory(
    id: 'after_prayer',
    titleEn: 'After Prayer',
    titleAr: '',
    subtitleEn: 'Said after each obligatory salah',
    imagePath: 'assets/images/ibada/azkar_3.png',
    accent: const Color(0xFF10B981),
    items: [
      Dhikr(
        arabic: 'أَسْتَغْفِرُ اللَّهَ',
        transliteration: 'Astaghfirullah.',
        translation: 'dhikr_astaghfirullah_simple',
        repeat: 3,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ '
            'وَالْإِكْرَامِ',
        transliteration:
            'Allahumma antas-salam, wa minkas-salam, tabarakta ya dhal-jalali '
            'wal-ikram.',
        translation: 'dhikr_tasleem',
        repeat: 1,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ '
            'وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ '
            'لِمَا مَنَعْتَ',
        transliteration:
            'La ilaha illallahu wahdahu la sharika lah... Allahumma la mani\'a '
            'lima a\'tayt, wa la mu\'tiya lima mana\'t.',
        translation: 'dhikr_unit_praise',
        repeat: 1,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ '
            'لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ '
            'يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ '
            'وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        transliteration:
            'Allahu la ilaha illa huwal-hayyul-qayyum, la ta\'khudhuhu sinatun '
            'wa la nawm, lahu ma fis-samawati wa ma fil-ard...',
        translation: 'dhikr_ayat_kursi',
        repeat: 1,
        reference: 'Al-Baqarah 2:255 — an-Nasa\'i, al-Kabir',
        virtue: 'dhikr_virtue_after_kursi',
      ),
      Dhikr(
        arabic: 'سُبْحَانَ اللَّهِ',
        transliteration: 'Subhanallah.',
        translation: 'dhikr_subhanallah',
        repeat: 33,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic: 'الْحَمْدُ لِلَّهِ',
        transliteration: 'Alhamdulillah.',
        translation: 'dhikr_alhamdulillah',
        repeat: 33,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic: 'اللَّهُ أَكْبَرُ',
        transliteration: 'Allahu Akbar.',
        translation: 'dhikr_allahu_akbar',
        repeat: 34,
        reference: 'Sahih Muslim',
        virtue: 'dhikr_virtue_after_prayer',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ، وَشُكْرِكَ، وَحُسْنِ عِبَادَتِكَ',
        transliteration:
            "Allahumma a'inni 'ala dhikrika, wa shukrika, wa husni "
            "'ibadatik.",
        translation: 'dhikr_help_worship',
        repeat: 1,
        reference: 'Sunan Abu Dawud, an-Nasa\'i',
      ),
    ],
  );

  static final _sleep = AzkarCategory(
    id: 'sleep',
    titleEn: 'Before Sleep',
    titleAr: '',
    subtitleEn: 'Said when going to bed',
    imagePath: 'assets/images/ibada/azkar_4.png',
    accent: const Color(0xFF8B5CF6),
    items: [
      Dhikr(
        arabic: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
        transliteration: 'Bismika Allahumma amutu wa ahya.',
        translation: 'dhikr_sleep_bismika',
        repeat: 1,
        reference: 'Sahih al-Bukhari',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
        transliteration: "Allahumma qini 'adhabaka yawma tab'athu 'ibadak.",
        translation: 'dhikr_sleep_protection',
        repeat: 3,
        reference: 'Sunan at-Tirmidhi',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي '
            'إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ',
        transliteration:
            'Allahumma aslamtu nafsi ilayk, wa fawwadtu amri ilayk, wa alja\'tu '
            'zahri ilayk, raghbatan wa rahbatan ilayk...',
        translation: 'dhikr_sleep_submit',
        repeat: 1,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
      Dhikr(
        arabic: 'سُبْحَانَ اللَّهِ',
        transliteration: 'Subhanallah.',
        translation: 'dhikr_subhanallah',
        repeat: 33,
        reference: 'Sahih al-Bukhari',
      ),
      Dhikr(
        arabic: 'الْحَمْدُ لِلَّهِ',
        transliteration: 'Alhamdulillah.',
        translation: 'dhikr_alhamdulillah',
        repeat: 33,
        reference: 'Sahih al-Bukhari',
      ),
      Dhikr(
        arabic: 'اللَّهُ أَكْبَرُ',
        transliteration: 'Allahu Akbar.',
        translation: 'dhikr_allahu_akbar',
        repeat: 34,
        reference: 'Sahih al-Bukhari',
      ),
    ],
  );

  static final _waking = AzkarCategory(
    id: 'waking',
    titleEn: 'On Waking',
    titleAr: '',
    subtitleEn: 'Said on waking from sleep',
    imagePath: 'assets/images/ibada/azkar_5.png',
    accent: const Color(0xFFEC4899),
    items: [
      Dhikr(
        arabic:
            'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
        transliteration:
            "Alhamdu lillahil-ladhi ahyana ba'da ma amatana wa ilayhin-nushur.",
        translation: 'dhikr_waking_praise',
        repeat: 1,
        reference: 'Sahih al-Bukhari',
      ),
      Dhikr(
        arabic:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ '
            'وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا '
            'اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
        transliteration:
            'La ilaha illallahu wahdahu la sharika lah... wa la hawla wa la '
            'quwwata illa billah.',
        translation: 'dhikr_unit_praise',
        repeat: 1,
        reference: 'Sahih al-Bukhari',
      ),
    ],
  );

  static final _distress = AzkarCategory(
    id: 'distress',
    titleEn: 'Distress & Anxiety',
    titleAr: '',
    subtitleEn: 'For worry, grief and hardship',
    imagePath: 'assets/images/ibada/azkar_6.png',
    accent: const Color(0xFFEF4444),
    items: [
      Dhikr(
        arabic:
            'لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ '
            'الْعَظِيمِ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ '
            'الْكَرِيمِ',
        transliteration:
            "La ilaha illallahul-'Azimul-Halim, la ilaha illallahu rabbul-"
            "'arshil-'azim...",
        translation: 'dhikr_distress_magnificent',
        repeat: 1,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
      Dhikr(
        arabic:
            'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
        transliteration:
            'La ilaha illa anta subhanaka inni kuntu minaz-zalimin.',
        translation: 'dhikr_yunus',
        repeat: 1,
        reference: 'Al-Anbya 21:87 (the supplication of Yunus)',
      ),
      Dhikr(
        arabic: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
        transliteration: "Hasbunallahu wa ni'mal-wakil.",
        translation: 'dhikr_hasbunallah',
        repeat: 7,
        reference: 'Ali \'Imran 3:173',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ رَحْمَتَكَ أَرْجُو، فَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ، وَأَصْلِحْ '
            'لِي شَأْنِي كُلَّهُ، لَا إِلَهَ إِلَّا أَنْتَ',
        transliteration:
            'Allahumma rahmataka arju, fala takilni ila nafsi tarfata \'ayn...',
        translation: 'dhikr_mercy_hope',
        repeat: 1,
        reference: 'Sunan Abu Dawud',
      ),
      Dhikr(
        arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
        transliteration: 'La hawla wa la quwwata illa billah.',
        translation: 'dhikr_la_hawla',
        repeat: 10,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
    ],
  );

  static final _general = AzkarCategory(
    id: 'general',
    titleEn: 'Tasbih & Istighfar',
    titleAr: '',
    subtitleEn: 'Short remembrances for any time',
    imagePath: 'assets/images/ibada/azkar_7.png',
    accent: const Color(0xFF0EA5E9),
    items: [
      Dhikr(
        arabic:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
        transliteration: "Subhanallahi wa bihamdih, subhanallahil-'Azim.",
        translation: 'dhikr_subhanallahi_azim',
        repeat: 100,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
        virtue: 'dhikr_virtue_general',
      ),
      Dhikr(
        arabic:
            'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
        transliteration:
            'Subhanallah, walhamdulillah, wa la ilaha illallah, wallahu '
            'akbar.',
        translation: 'dhikr_unit_praise',
        repeat: 33,
        reference: 'Sahih Muslim',
      ),
      Dhikr(
        arabic: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ',
        transliteration: "Astaghfirullahal-'Azima wa atubu ilayh.",
        translation: 'dhikr_astaghfirullah_azim',
        repeat: 100,
        reference: 'Sahih al-Bukhari',
      ),
      Dhikr(
        arabic:
            'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى '
            'إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ',
        transliteration:
            'Allahumma salli \'ala Muhammadin wa \'ala ali Muhammad, kama '
            'sallayta \'ala Ibrahima wa \'ala ali Ibrahim, innaka hamidun '
            'majid.',
        translation: 'dhikr_durood',
        repeat: 10,
        reference: 'Sahih al-Bukhari, Sahih Muslim',
      ),
    ],
  );
}