abstract class AuthEvent {}

class AuthSignup extends AuthEvent {
  final String phone;
  final String password;
  final String email;
  final String name;
  final String userType; // 'member' | 'agent'
  final String? referralCode;
  final String? city;
  AuthSignup({
    required this.phone,
    required this.password,
    required this.email,
    required this.name,
    required this.userType,
    this.referralCode,
    this.city,
  });
}

class AuthRequestOtpEvent extends AuthEvent {
  final String phoneNumber;
  AuthRequestOtpEvent({required this.phoneNumber});
}

class AuthVerifyOtpEvent extends AuthEvent {
  final String phoneNumber;
  final String otp;
  final String verificationId;
  AuthVerifyOtpEvent({
    required this.phoneNumber,
    required this.otp,
    required this.verificationId,
  });
}

class AuthDeleteAccount extends AuthEvent {
  AuthDeleteAccount();
}

class AuthLogin extends AuthEvent {
  final String phone;
  final String password;
  AuthLogin({required this.phone, required this.password});
}

class AuthLogoutEvent extends AuthEvent {}

class AuthVerifyOtp extends AuthEvent {
  final String phone;
  final String otp;
  AuthVerifyOtp({required this.phone, required this.otp});
}

class AuthResetPasswordEvent extends AuthEvent {
  final String phone;
  final String newPassword;
  AuthResetPasswordEvent({required this.phone, required this.newPassword});
}

class AuthChangePassword extends AuthEvent {
  final String oldPassword;
  final String newPassword;
  AuthChangePassword({required this.newPassword, required this.oldPassword});
}

class AuthDeleteAccountEvent extends AuthEvent {
  AuthDeleteAccountEvent();
}