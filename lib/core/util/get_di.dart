import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:niya_equb/core/language/controllers/language_controller.dart';
import 'package:niya_equb/core/language/domain/models/language_model.dart';
import 'package:niya_equb/core/language/domain/repository/language_repository.dart';
import 'package:niya_equb/core/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../language/domain/repository/language_repository_interface.dart';
import '../language/domain/service/language_service.dart';
import '../language/domain/service/language_service_interface.dart';

Future<Map<String, Map<String, String>>> init() async {
  /// Core
  final sharedPreferences = await SharedPreferences.getInstance();
  Get.lazyPut(() => sharedPreferences);
  Get.lazyPut(
    () => LocalizationController(languageServiceInterface: Get.find()),
  );

  LanguageRepositoryInterface languageRepositoryInterface = LanguageRepository(
    sharedPreferences: Get.find(),
  );
  Get.lazyPut(() => languageRepositoryInterface);

  LanguageServiceInterface languageServiceInterface = LanguageService(
    languageRepositoryInterface: Get.find(),
  );
  Get.lazyPut(() => languageServiceInterface);

  /// Retrieving localized data
  Map<String, Map<String, String>> languages = {};
  for (LanguageModel languageModel in AppConstants.languages) {
    String jsonStringValues = await rootBundle.loadString(
      'assets/lang/${languageModel.languageCode}.json',
    );
    Map<String, dynamic> mappedJson = jsonDecode(jsonStringValues);
    Map<String, String> json = {};
    mappedJson.forEach((key, value) {
      json[key] = value.toString();
    });
    languages['${languageModel.languageCode}_${languageModel.countryCode}'] =
        json;
  }

  // NOTE: this used to `print(languages)`, dumping all three complete
  // translation files — several thousand lines — to the console on every
  // single launch, before runApp. Console writes go over the platform channel
  // and are synchronous, so on a physical device that alone added visible
  // seconds of blank screen to every cold start.
  return languages;
}
