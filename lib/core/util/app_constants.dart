import 'package:niya_equb/core/router/app_assets.dart';

import '../language/domain/models/language_model.dart';

class AppConstants {
  static const double hintColorBorderOpacity = .2;
  static const String countryCode = 'country_code';
  static const String cacheCountryCode = 'cache_country_code';
  static const String fontFamily = 'Poppins';
  static const String cacheLanguageCode = 'cache_language_code';
  static const double appVersion = 2.10;
  static const String languageCode = 'language_code';
  static List<LanguageModel> languages = [
    LanguageModel(
      imageUrl: AppAssets.ethiopia,
      languageName: 'Amharic',
      countryCode: 'ET',
      languageCode: 'am',
    ),
    LanguageModel(
      imageUrl: AppAssets.englis,
      languageName: 'English',
      countryCode: 'US',
      languageCode: 'en',
    ),
    LanguageModel(
      imageUrl: AppAssets.oromo,
      languageName: 'Afaan Oromo',
      countryCode: 'ET',
      languageCode: 'om',
    ),
  ];

  static const List<String> ethiopianCities = [
    "Addis Ababa",
    "Dire Dawa",
    "Jimma",
    "Desse",
    "Semera",
    "Adama",
    "Jijiga",
    "Harar",
    "Worabe",
    "Shashemene",
    "Bahir Dar",
    "Hawassa",
    "Gondar",
    "Nekemte",
    "Asossa",
    "Mekelle",
    "Gambela",
    "Arba Minch",
    "Asela",
    "Wolkite",
    "Kombolcha",
    "Moyale",
    "Debre birhan",
    "Woliso",
    "Bati",
    "Woldiya",
    "Kebri dehar",
    "Bale robe",
    "Ambo",
    "Kemissie",
  ];
}
