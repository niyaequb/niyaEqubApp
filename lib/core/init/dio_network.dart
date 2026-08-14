import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:niya_equb/core/init/helper.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/core/service/navigation_service.dart';

import '../util/logger.dart';
import 'network_constant.dart';

class DioNetwork {
  static late Dio appAPI;
  static late Dio retryAPI;
  static const String _refreshPath = 'auth/refresh';

  static void initDio() {
    appAPI = Dio(baseOptions(apiUrl));
    appAPI.interceptors.add(appQueuedInterceptorsWrapper());

    retryAPI = Dio(baseOptions(apiUrl));
  }

  static QueuedInterceptorsWrapper appQueuedInterceptorsWrapper() {
    return QueuedInterceptorsWrapper(
      onRequest: (RequestOptions options, r) async {
        Map<String, dynamic> headers = Helper.getHeaders();

        if (kDebugMode) {
          print(json.encode(headers));
        }
        String token = await PreferencesService.getAccessToken() ?? "";
        // logger(token);
        if (token != "") {
          headers["Authorization"] = 'Bearer $token';
        }
        options.headers = headers;
        appAPI.options.headers = headers;
        return r.next(options);
      },
      onError: (error, ErrorInterceptorHandler handler) async {
        if (error.response?.statusCode == 401) {
          // Avoid infinite refresh loops
          final path = error.requestOptions.path;
          final extra = error.requestOptions.extra;
          if (path.contains(_refreshPath) ||
              (extra['__retried'] == true) ||
              (extra['__skip_refresh'] == true)) {
            return handler.next(error);
          }

          logger(error.requestOptions.uri.toString());
          if (error.requestOptions.uri.toString().contains("login")) {
            return handler.next(error);
          }

          // Nothing to refresh, and nobody to sign out. A 401 here belongs to
          // a request that went out while logged out — the FCM token sync on
          // cold start is the usual one — and bouncing to login from here was
          // stacking a second login screen on top of the one the splash had
          // just opened.
          final sessionToken =
              (await PreferencesService.getAccessToken() ?? '').trim();
          if (sessionToken.isEmpty) {
            return handler.next(error);
          }

          // Attempt to refresh the token
          final refreshed = await _refreshToken();
          if (refreshed) {
            final options = error.response!.requestOptions;
            final newHeaders = Helper.getHeaders();
            String? token = await PreferencesService.getAccessToken() ?? "";
            if (token != "") {
              newHeaders["Authorization"] = 'Bearer $token';
            }
            options.headers = newHeaders;
            options.extra['__retried'] = true;
            final response = await appAPI.fetch(options);
            return handler.resolve(response);
          } else {
            // The single place a dead session sends the user back to login.
            // _refreshToken() used to do this too, on its own, and the pair of
            // pushes is what animated the login screen in twice.
            await NavigationService.returnToLogin();
          }
        }
        return handler.next(error);
      },
      onResponse:
          (
            Response<dynamic> response,
            ResponseInterceptorHandler handler,
          ) async {
            // This is a QueuedInterceptor, so every response is processed one
            // at a time. Re-encoding each payload with indentation here meant
            // release builds paid for logs nobody would ever read, and each
            // list request queued behind the last one's encode.
            if (kDebugMode) {
              try {
                developer.log(
                  const JsonEncoder.withIndent('  ').convert(response.data),
                );
              } catch (_) {
                developer.log('${response.data}');
              }
            }

            return handler.next(response);
          },
    );
  }

  static BaseOptions baseOptions(String url) {
    Map<String, dynamic> headers = Helper.getHeaders();

    return BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (s) {
        return s! < 300;
      },
      headers: headers..removeWhere((key, value) => value == null),
      responseType: ResponseType.json,
    );
  }

  static String? _extractToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      final direct = data['token'] ?? data['access_token'];
      if (direct is String && direct.trim().isNotEmpty) return direct.trim();
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        final t = nested['token'] ?? nested['access_token'];
        if (t is String && t.trim().isNotEmpty) return t.trim();
      }
    }
    return null;
  }

  static Future<bool> _refreshToken() async {
    logger("refreshing token...");
    try {
      Map<String, dynamic> headers = Helper.getHeaders();
      // Prefer refresh token if available, otherwise fall back to access token.
      final refreshToken = await PreferencesService.getRefreshToken();
      final accessToken = await PreferencesService.getAccessToken();

      final bearer = (refreshToken != null && refreshToken.trim().isNotEmpty)
          ? refreshToken.trim()
          : (accessToken ?? '').trim();

      if (bearer.isNotEmpty) {
        headers["Authorization"] = 'Bearer $bearer';
      }

      final response = await retryAPI.post(
        _refreshPath,
        options: Options(
          headers: headers,
          extra: const {'__skip_refresh': true},
        ),
      );
      logger("refresh token response");
      logger(response.data);
      if (kDebugMode) {
        print(response.statusCode);
      }
      final status = response.statusCode ?? 0;
      if (status != 200 && status != 201) return false;

      final newToken = _extractToken(response.data);
      if (newToken == null || newToken.isEmpty) return false;

      await PreferencesService.writeAccessToken(newToken);

      // If backend also returns refreshToken, persist it.
      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        final newRefresh = map['refreshToken'] ?? map['refresh_token'];
        if (newRefresh is String && newRefresh.trim().isNotEmpty) {
          await PreferencesService.writeRefreshToken(newRefresh.trim());
        }
      }

      return true;
    } catch (e) {
      if (e is DioException) {
        logger(e.response?.data);
        // Deliberately does not navigate. Every caller of this method already
        // sends the user back to login when it returns false, and doing it
        // here as well meant one expired token pushed the login route twice.
      } else {
        logger("Non-Dio Error in _refreshToken: ${e.toString()}");
      }
      return false;
    }
  }
}
