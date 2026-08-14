import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:niya_equb/features/member/profile/data/repository/ekub_profile_repository.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_event.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_state.dart';

class EkubProfileBloc extends Bloc<EkubProfileEvent, EkubProfileState> {
  final EkubProfileRepository repository;

  EkubProfileBloc({required this.repository})
    : super(
        EkubProfileLoading(
          user: PreferencesService.getUser(),
          accessToken: null,
        ),
      ) {
    on<EkubProfileLoadEvent>(_onLoad);
    on<EkubProfileRefreshEvent>(_onRefresh);
    on<EkubProfileUpdateEvent>(_onUpdate);
    on<EkubProfileDeleteAccountEvent>(_onDeleteAccount);
  }

  Future<String?> _loadToken() async {
    return await PreferencesService.getAccessToken();
  }

  void _onLoad(
    EkubProfileLoadEvent event,
    Emitter<EkubProfileState> emit,
  ) async {
    logger('EkubProfileBloc: Loading data (silent: ${event.isSilent})');
    final cached = PreferencesService.getUser();
    final token = await _loadToken();
    if (!event.isSilent) {
      emit(EkubProfileLoading(user: cached, accessToken: token));
    }

    Either<Failure, UserModel> result = await repository.fetchMe();
    result.fold(
      (failure) => emit(
        EkubProfileFailure(failure: failure, user: cached, accessToken: token),
      ),
      (user) => emit(EkubProfileLoaded(user: user, accessToken: token)),
    );
  }

  void _onRefresh(
    EkubProfileRefreshEvent event,
    Emitter<EkubProfileState> emit,
  ) async {
    final token = await _loadToken();
    final currentUser = switch (state) {
      EkubProfileLoaded s => s.user,
      EkubProfileUpdateLoading s => s.user,
      EkubProfileUpdateSuccess s => s.user,
      EkubProfileUpdateFailure s => s.user,
      EkubProfileLoading s => s.user,
      EkubProfileFailure s => s.user,
      _ => PreferencesService.getUser(),
    };

    emit(EkubProfileLoading(user: currentUser, accessToken: token));

    Either<Failure, UserModel> result = await repository.fetchMe();
    result.fold(
      (failure) => emit(
        EkubProfileFailure(
          failure: failure,
          user: currentUser,
          accessToken: token,
        ),
      ),
      (user) => emit(EkubProfileLoaded(user: user, accessToken: token)),
    );
  }

  void _onUpdate(
    EkubProfileUpdateEvent event,
    Emitter<EkubProfileState> emit,
  ) async {
    final token = await _loadToken();
    final currentUser = switch (state) {
      EkubProfileLoaded s => s.user,
      EkubProfileUpdateLoading s => s.user,
      EkubProfileUpdateSuccess s => s.user,
      EkubProfileUpdateFailure s => s.user,
      EkubProfileFailure s => s.user ?? PreferencesService.getUser(),
      EkubProfileLoading s => s.user ?? PreferencesService.getUser(),
      _ => PreferencesService.getUser(),
    };

    if (currentUser == null) {
      emit(
        EkubProfileFailure(
          failure: ServerFailure('No cached user found', null),
          user: null,
          accessToken: token,
        ),
      );
      return;
    }

    emit(EkubProfileUpdateLoading(user: currentUser, accessToken: token));

    Either<Failure, UserModel> result = await repository.update(
      name: event.name,
      email: event.email,
      password: event.password,
      profilePicture: event.profilePicture,
      bankName: event.bankName,
      accountNumber: event.accountNumber,
      accountHolderName: event.accountHolderName,
      city: event.city,
    );
    result.fold(
      (failure) => emit(
        EkubProfileUpdateFailure(
          failure: failure,
          user: currentUser,
          accessToken: token,
        ),
      ),
      (user) => emit(EkubProfileUpdateSuccess(user: user, accessToken: token)),
    );
  }

  void _onDeleteAccount(
    EkubProfileDeleteAccountEvent event,
    Emitter<EkubProfileState> emit,
  ) async {
    final token = await _loadToken();
    final currentUser = switch (state) {
      EkubProfileLoaded s => s.user,
      EkubProfileUpdateLoading s => s.user,
      EkubProfileUpdateSuccess s => s.user,
      EkubProfileUpdateFailure s => s.user,
      EkubProfileFailure s => s.user ?? PreferencesService.getUser(),
      EkubProfileLoading s => s.user ?? PreferencesService.getUser(),
      _ => PreferencesService.getUser(),
    };

    if (currentUser == null) {
      emit(
        EkubProfileDeleteAccountFailure(
          failure: ServerFailure('No cached user found', null),
          user: UserModel(
            id: -1,
            name: '',
            phone: '',
            type: '',
          ), // Return empty user object as fallback
          accessToken: token,
        ),
      );
      return;
    }

    emit(
      EkubProfileDeleteAccountLoading(user: currentUser, accessToken: token),
    );

    final result = await repository.deleteAccount();
    result.fold(
      (failure) => emit(
        EkubProfileDeleteAccountFailure(
          failure: failure,
          user: currentUser,
          accessToken: token,
        ),
      ),
      (_) => emit(EkubProfileDeleteAccountSuccess()),
    );
  }
}
