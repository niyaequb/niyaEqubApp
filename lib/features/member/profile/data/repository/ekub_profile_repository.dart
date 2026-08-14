import 'dart:io';

import 'package:dio/dio.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';

class EkubProfileRepository {
  final Dio dio;
  final AuthRepository authRepository;

  EkubProfileRepository({required this.dio, required this.authRepository});

  ResultFuture<UserModel> fetchMe() {
    return authRepository.me();
  }

  ResultFuture<UserModel> update({
    String? name,
    String? email,
    String? password,
    File? profilePicture,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
    String? city,
  }) {
    return authRepository.updateProfile(
      name: name,
      email: email,
      password: password,
      profilePicture: profilePicture,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolderName: accountHolderName,
      city: city,
    );
  }

  Future<String?> getAccessToken() {
    return PreferencesService.getAccessToken();
  }

  ResultFuture<String> deleteAccount() {
    return authRepository.deleteAccount();
  }
}
