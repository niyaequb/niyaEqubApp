import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/auth/models/user.dart';

abstract class EkubProfileState extends Equatable {}

class EkubProfileLoading extends EkubProfileState {
  final UserModel? user;
  final String? accessToken;

  EkubProfileLoading({required this.user, required this.accessToken});

  @override
  List<Object?> get props => [user, accessToken];
}

class EkubProfileLoaded extends EkubProfileState {
  final UserModel user;
  final String? accessToken;

  EkubProfileLoaded({required this.user, required this.accessToken});

  Map<String, String>? get imageHeaders {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  List<Object?> get props => [user, accessToken];
}

class EkubProfileFailure extends EkubProfileState {
  final Failure failure;
  final UserModel? user;
  final String? accessToken;

  EkubProfileFailure({
    required this.failure,
    required this.user,
    required this.accessToken,
  });

  @override
  List<Object?> get props => [failure, user, accessToken];
}

class EkubProfileUpdateLoading extends EkubProfileState {
  final UserModel user;
  final String? accessToken;

  EkubProfileUpdateLoading({required this.user, required this.accessToken});

  Map<String, String>? get imageHeaders {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  List<Object?> get props => [user, accessToken];
}

class EkubProfileUpdateSuccess extends EkubProfileState {
  final UserModel user;
  final String? accessToken;

  EkubProfileUpdateSuccess({required this.user, required this.accessToken});

  Map<String, String>? get imageHeaders {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  List<Object?> get props => [user, accessToken];
}

class EkubProfileUpdateFailure extends EkubProfileState {
  final Failure failure;
  final UserModel user;
  final String? accessToken;

  EkubProfileUpdateFailure({
    required this.failure,
    required this.user,
    required this.accessToken,
  });

  Map<String, String>? get imageHeaders {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  List<Object?> get props => [failure, user, accessToken];
}

class EkubProfileDeleteAccountLoading extends EkubProfileState {
  final UserModel user;
  final String? accessToken;

  EkubProfileDeleteAccountLoading({
    required this.user,
    required this.accessToken,
  });

  Map<String, String>? get imageHeaders {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  List<Object?> get props => [user, accessToken];
}

class EkubProfileDeleteAccountSuccess extends EkubProfileState {
  @override
  List<Object?> get props => [];
}

class EkubProfileDeleteAccountFailure extends EkubProfileState {
  final Failure failure;
  final UserModel user;
  final String? accessToken;

  EkubProfileDeleteAccountFailure({
    required this.failure,
    required this.user,
    required this.accessToken,
  });

  Map<String, String>? get imageHeaders {
    final token = accessToken;
    if (token == null || token.trim().isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  List<Object?> get props => [failure, user, accessToken];
}
