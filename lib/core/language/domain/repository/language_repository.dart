import 'package:niya_equb/core/language/domain/repository/language_repository_interface.dart';
import 'package:flutter/material.dart';
import 'package:niya_equb/core/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageRepository implements LanguageRepositoryInterface {
  final SharedPreferences sharedPreferences;
  LanguageRepository({required this.sharedPreferences});

  @override
  Locale getLocaleFromSharedPref() {
    return Locale(
      sharedPreferences.getString(AppConstants.languageCode) ??
          AppConstants.languages[0].languageCode!,
      sharedPreferences.getString(AppConstants.countryCode) ??
          AppConstants.languages[0].countryCode,
    );
  }

  @override
  void saveLanguage(Locale locale) {
    sharedPreferences.setString(AppConstants.languageCode, locale.languageCode);
    sharedPreferences.setString(AppConstants.countryCode, locale.countryCode!);
  }

  @override
  void saveCacheLanguage(Locale locale) {
    sharedPreferences.setString(
      AppConstants.cacheLanguageCode,
      locale.languageCode,
    );
    sharedPreferences.setString(
      AppConstants.cacheCountryCode,
      locale.countryCode!,
    );
  }

  @override
  Locale getCacheLocaleFromSharedPref() {
    return Locale(
      sharedPreferences.getString(AppConstants.cacheLanguageCode) ??
          AppConstants.languages[0].languageCode!,
      sharedPreferences.getString(AppConstants.cacheCountryCode) ??
          AppConstants.languages[0].countryCode,
    );
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
