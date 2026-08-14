import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/language/domain/models/language_model.dart';
import 'package:niya_equb/core/language/domain/service/language_service_interface.dart';
import 'package:niya_equb/core/util/app_constants.dart';

class LocalizationController extends GetxController implements GetxService {
  final LanguageServiceInterface languageServiceInterface;
  LocalizationController({required this.languageServiceInterface});

  Locale _locale = Locale(
    AppConstants.languages[0].languageCode!,
    AppConstants.languages[0].countryCode,
  );
  Locale get locale => _locale;

  bool _isLtr = true;
  bool get isLtr => _isLtr;

  List<LanguageModel> _languages = [];
  List<LanguageModel> get languages => _languages;

  int _selectedLanguageIndex = 1;
  int get selectedLanguageIndex => _selectedLanguageIndex;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  @override
  void onInit() {
    super.onInit();
    loadCurrentLanguage();
  }

  void setLanguage(Locale locale, {bool fromBottomSheet = false}) {
    Get.updateLocale(locale);
    _locale = locale;
    _isLtr = languageServiceInterface.setLTR(_locale);

    if (!fromBottomSheet) {
      saveLanguage(_locale);
    }

    update();
  }

  Future<void> loadCurrentLanguage() async {
    _isLoading = true;
    update();

    _locale = languageServiceInterface.getLocaleFromSharedPref();
    _isLtr = _locale.languageCode != 'ar';
    _selectedLanguageIndex = languageServiceInterface.setSelectedIndex(
      AppConstants.languages,
      _locale,
    );
    _languages = [];
    _languages.addAll(AppConstants.languages);

    _isLoading = false;
    update();
  }

  void saveLanguage(Locale locale) async {
    languageServiceInterface.saveLanguage(locale);
  }

  void saveCacheLanguage(Locale? locale) {
    languageServiceInterface.saveCacheLanguage(
      locale ?? languageServiceInterface.getLocaleFromSharedPref(),
    );
  }

  void setSelectLanguageIndex(int index) {
    _selectedLanguageIndex = index;
    update();
  }

  Locale getCacheLocaleFromSharedPref() {
    return languageServiceInterface.getCacheLocaleFromSharedPref();
  }

  void searchSelectedLanguage() {
    for (var language in AppConstants.languages) {
      if (language.languageCode!.toLowerCase().contains(
        _locale.languageCode.toLowerCase(),
      )) {
        _selectedLanguageIndex = AppConstants.languages.indexOf(language);
      }
    }
  }
}
