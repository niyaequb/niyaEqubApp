import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/settings/data/models/settings_model.dart';

import 'package:niya_equb/features/member/settings/data/models/faq_model.dart';

abstract class SettingsState {}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final SettingsModel settings;
  final List<FaqModel>? faqs;
  
  SettingsLoaded({required this.settings, this.faqs});
}

class SettingsFailure extends SettingsState {
  final Failure failure;
  SettingsFailure({required this.failure});
}
