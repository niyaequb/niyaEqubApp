import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/settings/data/models/faq_model.dart';
import 'package:niya_equb/features/member/settings/data/models/settings_model.dart';
import 'package:niya_equb/features/member/settings/data/repository/settings_repository.dart';
import 'package:niya_equb/features/member/settings/state/settings_event.dart';
import 'package:niya_equb/features/member/settings/state/settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository repository;

  SettingsBloc({required this.repository}) : super(SettingsInitial()) {
    on<SettingsLoadEvent>(_onLoad);
  }

  Future<void> _onLoad(
    SettingsLoadEvent event,
    Emitter<SettingsState> emit,
  ) async {
    // Settings barely change, so the cached copy goes out first and the screen
    // never waits on the network to show support details or legal text.
    final cachedSettings = repository.cachedSettings();
    if (cachedSettings != null) {
      emit(SettingsLoaded(settings: cachedSettings, faqs: repository.cachedFaqs()));
    } else {
      emit(SettingsLoading());
    }

    final results = await Future.wait([
      repository.getSettings(),
      repository.getFaqs(),
    ]);
    final settingsResult = results[0] as Either<Failure, SettingsModel>;
    final faqsResult = results[1] as Either<Failure, List<FaqModel>>;

    settingsResult.fold(
      (failure) {
        // Don't replace cached settings that are already on screen.
        if (cachedSettings == null) emit(SettingsFailure(failure: failure));
      },
      (settings) {
        emit(
          SettingsLoaded(
            settings: settings,
            faqs: faqsResult.fold(
              (_) => repository.cachedFaqs(),
              (faqList) => faqList,
            ),
          ),
        );
      },
    );
  }
}
