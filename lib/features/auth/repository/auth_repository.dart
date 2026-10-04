import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/core/util/phone_input_formatter.dart';
import 'package:niya_equb/features/auth/models/user.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// Outcome of a registration.
///
/// [isSignedIn] tells the caller whether the app already holds a working
/// session, i.e. whether the new user can go straight to the home screen or
/// still has to pass through the login form.
class AuthSignupResult {
  final String message;
  final bool isSignedIn;
  final String userType;

  const AuthSignupResult({
    required this.message,
    required this.isSignedIn,
    required this.userType,
  });

  bool get isAgent => userType.toLowerCase() == 'agent';
}

class AuthRepository {
  final Dio dio;

  AuthRepository(this.dio);

  /// Pulls a JWT out of a response body, wherever the endpoint happens to put
  /// it (`token`, `access_token`, or nested under `data`).
  static String? _extractToken(dynamic body) {
    if (body is! Map) return null;

    final direct = body['token'] ?? body['access_token'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();

    final nested = body['data'];
    if (nested is Map) {
      final token = nested['token'] ?? nested['access_token'];
      if (token is String && token.trim().isNotEmpty) return token.trim();
    }
    return null;
  }

  Future<Response<dynamic>> _meRequest({required bool usePost}) {
    if (usePost) return dio.post(AuthEndpoint.me());
    return dio.get(AuthEndpoint.me());
  }

  /// Turns an unexpected client-side error into something a member can read.
  ///
  /// The bare `e.toString()` these catch blocks used to return is Dart
  /// internals. "type 'Null' is not a subtype of type 'String'" is a message
  /// members were genuinely shown — it names no action, means nothing outside
  /// an IDE, and makes a working app look broken. The detail still goes to the
  /// log, which is where it was always useful and never harmful.
  static Failure _unexpected(Object error, String where) {
    logger('Unexpected auth error in $where: $error');

    return ServerFailure(
      'Something went wrong on this device. Please try again.',
      null,
    );
  }

  /// Requests an OTP code for a given phone number
  ResultFuture<String> requestOtp(String phoneNumber) async {
    try {
      final result = await dio.post(
        AuthEndpoint.requestOtp(),
        data: {'phone': phoneNumber},
      );

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      return Right(result.data['verificationId']);
    } on DioException catch (e) {
      logger(e.response?.data);
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Verifies if a phone number is already registered in the system
  Future<bool> isPhoneRegistered(String phoneNumber) async {
    try {
      final result = await dio.post(
        AuthEndpoint.checkUser(),
        data: {'phone': phoneNumber},
      );
      if (result.data == null) {
        throw "Unknown Error";
      }
      return result.data['status'] == "exists";
    } on DioException catch (e) {
      logger(e.response?.data);
      throw handleDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /// Resets password and caches user/token from the response
  ResultFuture<String> resetPassword(String phone, String newPassword) async {
    try {
      final result = await dio.post(
        AuthEndpoint.resetPassword(),
        data: {
          'phone': toInternationalPhone(phone),
          'password': newPassword,
        },
      );

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }

      final message =
          (result.data is Map
              ? result.data['message']?.toString()
              : null) ??
          'Password reset successfully.';

      final token = _extractToken(result.data);

      if (token == null) {
        // Deliberately still a success. The password HAS been changed by this
        // point — the server commits it before signing a session and answers
        // with a null token when signing fails. Reporting a failure would send
        // the member back to try their OLD password, which no longer works,
        // and they would lock themselves out by drawing an entirely reasonable
        // conclusion. Sending them to the sign-in screen is the right outcome.
        return Right(message);
      }

      await PreferencesService.writeAccessToken(token);

      final userJson =
          result.data['agent_profile'] ??
          result.data['member_profile'] ??
          result.data['user'];
      if (userJson is Map<String, dynamic>) {
        await PreferencesService.saveUser(UserModel.fromJson(userJson));
      }

      // Was `Right(result.data['message'])`, which put a raw dynamic into a
      // ResultFuture<String>. A response without a message field made that a
      // TypeError at the await, reported as a failed reset even though the
      // password had already changed.
      return Right(message);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(_unexpected(e, 'resetPassword'));
    }
  }

  /// Deletes account and clears all local data
  ResultFuture<String> deleteAccount() async {
    try {
      final result = await dio.post(AuthEndpoint.delete());

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      await PreferencesService.clearUserData();
      await AppCache.clear();
      return Right(result.data['message']);
    } on DioException catch (e) {
      await PreferencesService.clearUserData();
      await AppCache.clear();
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Verifies the 4-digit OTP code
  ResultFuture<String> verifyOtp(
    String phoneNumber,
    String otp,
    String verificationId,
  ) async {
    try {
      final result = await dio.post(
        AuthEndpoint.verifyOtp(),
        data: {
          'phone': phoneNumber,
          'code': otp,
          'verificationId': verificationId,
        },
      );

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      return const Right("Otp verified successfully");
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Registers a new user and signs them in.
  ///
  /// `/auth/register` already issues a JWT, so a brand new member has no reason
  /// to be sent back to the login form — the token is stored and the profile
  /// fetched here, and the caller can go straight to the home screen.
  ///
  /// Two fallbacks keep that safe: if the register response carries no token we
  /// log in with the password the user just chose, and if `/auth/me` then
  /// refuses the session (an agent account, for instance, starts deactivated
  /// until an admin approves it) the local session is dropped and
  /// [AuthSignupResult.isSignedIn] comes back false so the app falls back to
  /// the login screen.
  ResultFuture<AuthSignupResult> signup(
    String phone,
    String name,
    String email,
    String password, {
    required String userType,
    String? referralCode,
    String? city,
  }) async {
    try {
      final data = <String, dynamic>{
        "full_name": name,
        "email": email.isEmpty ? null : email,
        "password": password,
        "phone": phone,
        "type": userType,
        "referral_code": (referralCode != null && referralCode.isNotEmpty)
            ? referralCode
            : null,
        "city": (city != null && city.isNotEmpty) ? city : null,
        "password_confirmation": password,
        'phone_verified_at': DateTime.now().toIso8601String(),
      };
      final result = await dio.post(AuthEndpoint.register(), data: data);

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }

      final body = result.data;
      final message =
          (body is Map ? body['message']?.toString() : null) ??
          "Registration completed successfully";

      // A new account must never inherit whatever the previous user on this
      // phone left cached.
      await AppCache.clear();

      var isSignedIn = false;

      final token = _extractToken(body);
      if (token != null) {
        await PreferencesService.writeAccessToken(token);
        isSignedIn = true;
      } else {
        // Older backends answer register without a token; the credentials were
        // just set, so signing in is transparent to the user.
        final loginResult = await login(phone, password);
        isSignedIn = loginResult.isRight();
      }

      if (isSignedIn) {
        // Doubles as a session check and gives us the canonical profile
        // (real id, type and phone) rather than guessing at the register body.
        final profile = await me();
        if (profile.isLeft()) {
          await PreferencesService.clearUserData();
          isSignedIn = false;
        }
      }

      return Right(
        AuthSignupResult(
          message: message,
          isSignedIn: isSignedIn,
          userType: userType,
        ),
      );
    } on DioException catch (e) {
      logger(e.response?.data);
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(_unexpected(e, 'signup'));
    }
  }

  /// Authenticates user and caches their data and token
  ResultFuture<String> login(String phone, String password) async {
    try {
      final result = await dio.post(
        AuthEndpoint.login(),
        // Normalised here rather than trusted from the caller. The login screen
        // passes raw controller text — nine national digits, because the +251
        // shown in the field is decoration and never part of the value — while
        // every other call in this class sends +251XXXXXXXXX. The two only
        // agreed because the backend re-normalises whatever it is given, so
        // they converged by luck rather than by design, and the luck would have
        // run out the first time that request class changed.
        //
        // toInternationalPhone() is idempotent, so a caller already passing the
        // international form is unaffected.
        data: {'phone': toInternationalPhone(phone), 'password': password},
      );

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }

      final token = _extractToken(result.data);

      if (token == null) {
        // A 200 carrying no token is not a successful sign-in and must not be
        // recorded as one. This used to read result.data['token'] straight into
        // writeAccessToken(String), which threw a raw TypeError that members
        // saw as "type 'Null' is not a subtype of type 'String'".
        //
        // The server really does answer this way: registration returns a null
        // token when the account was created but a session could not be signed.
        // Checked BEFORE the cache is cleared, so a failed attempt does not
        // quietly sign out whoever was already using the phone.
        return Left(
          ServerFailure(
            'The server did not return a session. Please try again in a moment.',
            result.statusCode,
          ),
        );
      }

      // Whoever was signed in before may not be who is signing in now.
      await AppCache.clear();

      await PreferencesService.writeAccessToken(token);

      final userJson =
          result.data['agent'] ??
          result.data['agent_profile'] ??
          result.data['member'] ??
          result.data['user'];
      if (userJson is Map<String, dynamic>) {
        await PreferencesService.saveUser(UserModel.fromJson(userJson));
      }

      return Right(result.data['message'] ?? "Login successful");
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(_unexpected(e, 'login'));
    }
  }

  /// Fetches current logged-in user profile
  ResultFuture<UserModel> me() async {
    try {
      Response<dynamic> result;
      try {
        result = await _meRequest(usePost: false);
      } on DioException catch (e) {
        // Some backends expose /auth/me as POST instead of GET.
        if (e.response?.statusCode == 405) {
          result = await _meRequest(usePost: true);
        } else {
          rethrow;
        }
      }
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }

      final data = result.data;
      Map<String, dynamic>? userJson;
      if (data is Map<String, dynamic>) {
        final candidate =
            data['user'] ??
            data['agent'] ??
            data['agent_profile'] ??
            data['member'] ??
            data['data'];
        if (candidate is Map<String, dynamic>) {
          userJson = Map<String, dynamic>.from(candidate);
          // Some responses also include profile_picture_url at the top-level.
          final topUrl = data['profile_picture_url'];
          if (topUrl != null && topUrl.toString().trim().isNotEmpty) {
            userJson['profile_picture_url'] = topUrl;
          }
        } else {
          userJson = data;
        }
      }

      if (userJson == null) {
        throw ServerException("Invalid profile response", result.statusCode);
      }

      final user = UserModel.fromJson(userJson);
      await PreferencesService.saveUser(user);
      return Right(user);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Updates current user profile (multipart)
  ResultFuture<UserModel> updateProfile({
    String? name,
    String? username,
    String? email,
    String? password,
    File? profilePicture,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
    String? city,
  }) async {
    try {
      final map = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) map['name'] = name.trim();
      if (username != null && username.trim().isNotEmpty) {
        map['username'] = username.trim();
      }
      if (email != null && email.trim().isNotEmpty) map['email'] = email.trim();
      if (password != null && password.trim().isNotEmpty) {
        map['password'] = password;
      }
      if (bankName != null && bankName.trim().isNotEmpty) {
        map['bank_name'] = bankName.trim();
      }
      if (accountNumber != null && accountNumber.trim().isNotEmpty) {
        map['account_number'] = accountNumber.trim();
      }
      if (accountHolderName != null && accountHolderName.trim().isNotEmpty) {
        map['account_holder_name'] = accountHolderName.trim();
      }
      if (city != null && city.trim().isNotEmpty) {
        map['city'] = city.trim();
      }
      if (profilePicture != null) {
        final fileName = profilePicture.path.split(Platform.pathSeparator).last;
        map['profile_picture'] = await MultipartFile.fromFile(
          profilePicture.path,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(map);
      final result = await dio.post(
        AuthEndpoint.update(),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }

      final data = result.data;
      Map<String, dynamic>? userJson;
      if (data is Map<String, dynamic>) {
        final candidate =
            data['user'] ??
            data['agent'] ??
            data['agent_profile'] ??
            data['member'] ??
            data['data'];
        if (candidate is Map<String, dynamic>) {
          userJson = Map<String, dynamic>.from(candidate);
          // Some responses also include profile_picture_url at the top-level.
          final topUrl = data['profile_picture_url'];
          if (topUrl != null && topUrl.toString().trim().isNotEmpty) {
            userJson['profile_picture_url'] = topUrl;
          }
        } else {
          userJson = data;
        }
      }

      if (userJson == null) {
        throw ServerException("Invalid profile response", result.statusCode);
      }

      final user = UserModel.fromJson(userJson);
      await PreferencesService.saveUser(user);
      return Right(user);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Logs out user and clears local cache
  ResultFuture<String> logout() async {
    try {
      final result = await dio.post(AuthEndpoint.logout());

      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      await PreferencesService.clearUserData();
      await AppCache.clear();
      return Right(result.data['message']);
    } on DioException catch (e) {
      // Clear data anyway on session failure
      await PreferencesService.clearUserData();
      await AppCache.clear();
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Signs the member in from the bank's host app, with no password.
  ///
  /// WHY THIS EXISTS
  ///
  /// The Dashen SuperApp reloads the mini app when it hands back after a
  /// payment, and a member whose session did not survive that reload was sent
  /// to the login screen in the middle of paying (Dashen QA, item 9). The
  /// SuperApp already knows who the member is; this asks it, and exchanges
  /// its answer for a Niya session the same way a password sign-in would.
  ///
  /// [identifier] is the opaque customer identifier the host app hands out.
  /// It proves nothing on its own: the server exchanges it WITH THE BANK, over
  /// its own authenticated call, and only a bank-confirmed phone number that
  /// matches an existing Niya account yields a session. A forged identifier
  /// is refused by the bank, not by us.
  ///
  /// Right(true) when signed in. Right(false) when the bank recognised the
  /// customer but there is no Niya account for them yet — not an error; they
  /// go on to the ordinary login and registration screens. Left for anything
  /// that went wrong, which the caller treats exactly like Right(false).
  ResultFuture<bool> signInWithHostApp({
    required String provider,
    required String identifier,
    String? appCode,
    String? stage,
  }) async {
    try {
      final result = await dio.post(
        MemberEndpoints.paymentIdentify(provider),
        data: {
          'customeridentifier': identifier,
          if (appCode != null && appCode.isNotEmpty) 'appcode': appCode,
          if (stage != null && stage.isNotEmpty) 'stage': stage,
        },
      );

      final body = result.data;
      if (body is! Map || body['registered'] != true) {
        return const Right(false);
      }

      final token = _extractToken(body);
      if (token == null) return const Right(false);

      // The same order as login(): clear whoever was here before, then the
      // token, then the user.
      await AppCache.clear();
      await PreferencesService.writeAccessToken(token);

      final userJson = body['user'];
      if (userJson is Map<String, dynamic>) {
        try {
          await PreferencesService.saveUser(UserModel.fromJson(userJson));
        } catch (_) {
          // The bare user row may not carry everything UserModel wants.
          // /auth/me below fills it in properly either way.
        }
      }

      // The canonical profile shape, as every other sign-in leaves behind.
      // A failure here does not undo the session: the token is valid, and
      // the profile screen fetches this again on its own.
      await me();

      return const Right(true);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(_unexpected(e, 'signInWithHostApp'));
    }
  }
}
