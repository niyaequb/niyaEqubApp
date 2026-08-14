import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';

abstract class AuthState extends Equatable {}

class AuthLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthSignupLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthSignupSuccess extends AuthState {
  final String message;

  /// True when registration also left the app with a working session, so the
  /// screen can go straight to the home screen instead of the login form.
  final bool isSignedIn;
  final String userType;

  AuthSignupSuccess({
    required this.message,
    this.isSignedIn = false,
    this.userType = 'member',
  });

  bool get isAgent => userType.toLowerCase() == 'agent';

  @override
  List<Object?> get props => [message, isSignedIn, userType];
}

class AuthSignupFailure extends AuthState {
  final Failure failure;
  AuthSignupFailure({required this.failure});
  @override
  List<Object?> get props => [];
}

////////////////////////////////////////////////////////////////
//////////////////
class AuthLoginLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthLoginSuccess extends AuthState {
  AuthLoginSuccess();
  @override
  List<Object?> get props => [];
}

class AuthLoginFailure extends AuthState {
  final Failure failure;
  AuthLoginFailure({required this.failure});
  @override
  List<Object?> get props => [];
}

class AuthLogoutLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthLogoutSuccess extends AuthState {
  AuthLogoutSuccess();
  @override
  List<Object?> get props => [];
}

class AuthLogoutFailure extends AuthState {
  final Failure failure;
  AuthLogoutFailure({required this.failure});
  @override
  List<Object?> get props => [];
}

////////////////////////////////////////////////////////////////
//////////////////
class AuthForgotPasswordLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthForgotPasswordSuccess extends AuthState {
  final String message;
  AuthForgotPasswordSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthForgotPasswordFaulire extends AuthState {
  final Failure failure;
  AuthForgotPasswordFaulire({required this.failure});
  @override
  List<Object?> get props => [];
}

////////////////////////////////////////////////////////////////
//////////////////
class AuthVerifyOtpLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthVerifyOtpSuccess extends AuthState {
  final String message;
  AuthVerifyOtpSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthVerifyOtpFailure extends AuthState {
  final Failure failure;
  AuthVerifyOtpFailure({required this.failure});
  @override
  List<Object?> get props => [];
}

class AuthRequestOtpLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthRequestOtpSuccess extends AuthState {
  final String message;
  AuthRequestOtpSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthRequestOtpFailure extends AuthState {
  final Failure failure;
  AuthRequestOtpFailure({required this.failure});
  @override
  List<Object?> get props => [];
}

////////////////////////////////////////////////////////////////
//////////////////
class AuthResetPasswordLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthResetPasswordSuccess extends AuthState {
  AuthResetPasswordSuccess();
  @override
  List<Object?> get props => [];
}

class AuthResetPasswordFailure extends AuthState {
  final Failure failure;
  AuthResetPasswordFailure({required this.failure});
  @override
  List<Object?> get props => [];
}

class AuthDeleteAccountLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthDeleteAccountSuccess extends AuthState {
  AuthDeleteAccountSuccess();
  @override
  List<Object?> get props => [];
}

class AuthDeleteAccountFailure extends AuthState {
  final Failure failure;

  AuthDeleteAccountFailure({required this.failure});

  @override
  List<Object?> get props => [failure];
}

class AuthChangePasswordLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthChangePasswordSuccess extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthChangePasswordFaulire extends AuthState {
  final Failure message;

  AuthChangePasswordFaulire({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthDeleteAcccountLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthDeleteAcccountSuccess extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthDeleteAcccountFaulire extends AuthState {
  final Failure message;

  AuthDeleteAcccountFaulire({required this.message});

  @override
  List<Object?> get props => [message];
}
