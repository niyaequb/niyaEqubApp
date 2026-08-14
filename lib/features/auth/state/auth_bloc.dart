import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthLoading()) {
    on<AuthLogin>(_onLogin);
    on<AuthSignup>(_onAuthSignup);
    on<AuthRequestOtpEvent>(_onRequestOtp);
    on<AuthVerifyOtpEvent>(_onVerifyOtp);
    on<AuthLogoutEvent>(_onLogout);
    on<AuthResetPasswordEvent>(_onResetPassword);
    on<AuthDeleteAccountEvent>(_onDeleteAccount);
  }
  void _onDeleteAccount(
    AuthDeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthDeleteAccountLoading());
    Either<Failure, dynamic> result = await authRepository.deleteAccount();
    result.fold(
      (Failure failure) => emit(AuthDeleteAccountFailure(failure: failure)),
      (dynamic success) {
        emit(AuthDeleteAccountSuccess());
      },
    );
  }

  void _onResetPassword(
    AuthResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthResetPasswordLoading());
    Either<Failure, String> result = await authRepository.resetPassword(
      event.phone,
      event.newPassword,
    );
    result.fold(
      (Failure failure) => emit(AuthResetPasswordFailure(failure: failure)),
      (String message) {
        emit(AuthResetPasswordSuccess());
      },
    );
  }

  void _onLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLogoutLoading());
    Either<Failure, dynamic> result = await authRepository.logout();
    result.fold(
      (Failure failure) => emit(AuthLogoutFailure(failure: failure)),
      (dynamic success) {
        emit(AuthLogoutSuccess());
      },
    );
  }

  void _onVerifyOtp(AuthVerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthVerifyOtpLoading());
    Either<Failure, String> result = await authRepository.verifyOtp(
      event.phoneNumber,
      event.otp,
      event.verificationId,
    );
    result.fold(
      (Failure failure) {
        logger(failure.errorMessage);
        emit(AuthVerifyOtpFailure(failure: failure));
      },
      (String message) {
        emit(AuthVerifyOtpSuccess(message: message));
      },
    );
  }

  void _onRequestOtp(AuthRequestOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthRequestOtpLoading());
    Either<Failure, String> result = await authRepository.requestOtp(
      event.phoneNumber,
    );
    result.fold(
      (Failure failure) => emit(AuthRequestOtpFailure(failure: failure)),
      (String message) {
        emit(AuthRequestOtpSuccess(message: message));
      },
    );
  }

  void _onLogin(AuthLogin event, Emitter<AuthState> emit) async {
    emit(AuthLoginLoading());
    Either<Failure, dynamic> result = await authRepository.login(
      event.phone,
      event.password,
    );
    result.fold((Failure failure) => emit(AuthLoginFailure(failure: failure)), (
      dynamic model,
    ) {
      sl<NotificationService>().initialize();
      emit(AuthLoginSuccess());
    });
  }

  void _onAuthSignup(AuthSignup event, Emitter<AuthState> emit) async {
    emit(AuthSignupLoading());
    Either<Failure, AuthSignupResult> result = await authRepository.signup(
      event.phone,
      event.name,
      event.email,
      event.password,
      userType: event.userType,
      referralCode: event.referralCode,
      city: event.city,
    );
    result.fold(
      (Failure failure) => emit(AuthSignupFailure(failure: failure)),
      (AuthSignupResult signup) {
        // Registers the device for push only once there is a session to
        // attach the FCM token to.
        if (signup.isSignedIn) {
          sl<NotificationService>().initialize();
        }
        emit(
          AuthSignupSuccess(
            message: signup.message,
            isSignedIn: signup.isSignedIn,
            userType: signup.userType,
          ),
        );
      },
    );
  }

  // void _onUpdatePassword(
  //     AuthUpdatePassword event, Emitter<AuthState> emit) async {
  //   emit(AuthUpdatePasswordLoading());
  //   Either<Failure, bool> result =
  //       await authUsecase.changePassword(event.param);
  //   result.fold(
  //       (Failure failure) => emit(
  //             AuthUpdatePasswordFaulire(failure: failure),
  //           ), (bool changed) {
  //     emit(AuthUpdatePasswordSuccess(changed: changed));
  //   });
  // }
}
