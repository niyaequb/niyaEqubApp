import 'package:niya_equb/core/language/domain/repository/language_repository_interface.dart';
import 'package:flutter/material.dart';
import '../models/language_model.dart';
import 'language_service_interface.dart';

class LanguageService implements LanguageServiceInterface {
  final LanguageRepositoryInterface languageRepositoryInterface;
  LanguageService({required this.languageRepositoryInterface});

  @override
  bool setLTR(Locale locale) {
    bool isLtr = true;
    locale.languageCode == 'ar' ? isLtr = false : isLtr = true;
    return isLtr;
  }

  @override
  Locale getLocaleFromSharedPref() {
    return languageRepositoryInterface.getLocaleFromSharedPref();
  }

  @override
  setSelectedIndex(List<LanguageModel> languages, Locale locale) {
    int selectedIndex = 0;
    for (int index = 0; index < languages.length; index++) {
      if (languages[index].languageCode == locale.languageCode) {
        selectedIndex = index;
        break;
      }
    }
    return selectedIndex;
  }

  @override
  void saveLanguage(Locale locale) {
    languageRepositoryInterface.saveLanguage(locale);
  }

  @override
  void saveCacheLanguage(Locale locale) {
    languageRepositoryInterface.saveCacheLanguage(locale);
  }

  @override
  Locale getCacheLocaleFromSharedPref() {
    return languageRepositoryInterface.getCacheLocaleFromSharedPref();
  }

  @override
  updateHeader(Locale locale, int? moduleId) {
    // TODO: implement updateHeader
    throw UnimplementedError();
  }
}
