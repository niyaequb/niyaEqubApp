import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Turns a failed request into one sentence a member can act on.
///
/// WHAT WENT WRONG WITH THE VERSION THIS REPLACES
///
/// It read `error.response?.data['code']` as its very first act, before
/// establishing that the body was a map at all. A response body is not
/// guaranteed to be JSON: a platform 502, a proxy timeout, a WAF block page
/// or a Laravel HTML error page all arrive as a String. Subscripting a String
/// throws NoSuchMethodError — and it throws INSIDE the repository's
/// `on DioException catch` block, so it escaped as an unhandled async error
/// instead of becoming a message. The screen sat there having apparently done
/// nothing. Every single type read in this file is now guarded.
///
/// Three more faults are fixed with it:
///
///   * `badCertificate` and `unknown` fell out of the switch with the message
///     still an empty string, so the user got a blank red bar and no
///     information whatsoever.
///   * The 409 branch built its message as `a + ",\n Minutes left to join: "
///     + a` — the same field twice — and `??` binds looser than `+`, so the
///     "Unknown Error" fallback was dead code and a null message threw.
///   * 429 and 500 assigned `data['message']` straight into a non-nullable
///     String, which is a TypeError the moment the field is absent.
///
/// WHAT THIS FILE IS NOT ALLOWED TO DO
///
/// Throw. It runs on the failure path, where anything it throws replaces a
/// bad error message with no error message and a frozen screen. Every branch
/// ends at a plain String, and there is a `default` so a future dio release
/// adding an exception type cannot reintroduce the blank-message bug.
///
/// It also imports no `dart:io`. The SocketException branch it used to have
/// inspected Linux errno values (101, 7, 8) that the browser cannot supply,
/// which is why the MiniApp needed a whole overridden copy. dio reports the
/// same failures as `connectionError` on both platforms.
///
/// STILL IN ENGLISH, DELIBERATELY
///
/// These strings are not run through GetX `.tr`. Adding keys without real
/// Amharic and Oromo translations would show raw key names to the people most
/// likely to hit an error. Translating them properly is a follow-up that
/// wants a native speaker, not a guess.
String handleDioError(DioException error) {
  final message = switch (error.type) {
    DioExceptionType.cancel => 'Request cancelled.',

    // All three timeouts get one sentence. The distinction between "could not
    // start" and "started and stalled" means nothing to a member, and the
    // first thing to try is the same either way.
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'The server took too long to respond. Check your connection and try again.',

    DioExceptionType.connectionError => _connectionError(error),

    DioExceptionType.badCertificate =>
      'Could not verify a secure connection to the server.',

    DioExceptionType.badResponse => _badResponse(error),

    // Covers `unknown` and anything a future dio version introduces. Never
    // an empty string.
    _ => 'Something went wrong. Please try again in a moment.',
  };

  if (kDebugMode) {
    debugPrint(
      'handleDioError [${error.type.name}] '
      '${error.response?.statusCode ?? '-'} '
      '${error.requestOptions.method} ${error.requestOptions.uri}: $message',
    );
  }

  return message;
}

/// Could not reach the server at all.
String _connectionError(DioException error) {
  // In a browser this ALSO fires when the request was blocked by CORS, which
  // is by far the likeliest cause while a backend is being set up and is
  // invisible to Dart — the browser reports it only to its own console. The
  // user-facing sentence stays the connectivity one, because that is the right
  // advice for a real member, but a developer hint goes to the console so the
  // true cause is one glance away.
  if (kIsWeb && kDebugMode) {
    debugPrint(
      'dio connectionError for ${error.requestOptions.uri}. In a browser this '
      'is often CORS rather than connectivity — check the console for a '
      'blocked-origin message, and see BACKEND_REQUIREMENTS.md.',
    );
  }

  return 'Connect to internet and try again!';
}

/// The server answered, but not with success.
String _badResponse(DioException error) {
  final response = error.response;
  final status = response?.statusCode;
  final data = response?.data;

  // Legacy gateway envelope: `{code, msg}`, where a non-zero code carries the
  // real reason. Checked first because when it is present it is more specific
  // than the status code. Guarded on `data is Map`, which is exactly the
  // guard the old first line was missing.
  if (data is Map) {
    final code = data['code'];
    if (code != null && '$code' != '0' && data['msg'] != null) {
      return data['msg'].toString();
    }
  }

  return switch (status) {
    400 => _serverMessage(data)?.replaceAll('[', '').replaceAll(']', '') ??
        'The request could not be completed.',

    // The backend returns 401 for a wrong password, an unknown phone number
    // and an unverified phone alike, each with its own message. Passing it
    // through is right; the fallback only covers a 401 with no body.
    401 => _serverMessage(data) ??
        'Your phone number or password is incorrect.',

    403 => _serverMessage(data) ??
        'This account is not allowed to do that.',

    404 => _serverMessage(data) ??
        'We could not find what you asked for.',

    409 => _conflict(data),

    413 => 'That file is too large to upload.',

    422 => _validationMessage(data) ??
        'Please check the details you entered and try again.',

    429 => _serverMessage(data) ??
        'Too many attempts. Please wait a moment and try again.',

    _ => _serverError(status, data),
  };
}

/// 5xx, or a status this client does not recognise.
String _serverError(int? status, dynamic data) {
  if (status != null && status >= 500) {
    // The server's own message wins when it says something. When it does not
    // — a bare 502 from the platform, an HTML page from a proxy — the status
    // number goes in the sentence, because "something went wrong" gives
    // support nothing to go on and the number is the one clue that survives
    // being relayed over the phone.
    return _serverMessage(data) ??
        'The server is having a problem right now (error $status). '
            'Please try again shortly.';
  }

  return 'Unexpected response from the server'
      '${status == null ? '' : ' (status $status)'}.';
}

/// 409, with the retry window appended when the server sends one.
String _conflict(dynamic data) {
  final message = _serverMessage(data) ??
      'That conflicts with something that already exists.';

  if (data is! Map) return message;

  // The old code appended `data['message']` here — the same field it had
  // already used as the message — so every conflict read
  // "X,\n Minutes left to join: X". Whatever field the backend actually uses
  // is one of these; when none is present the window is simply left off
  // rather than invented.
  final minutes =
      data['minutes_left'] ?? data['minutes'] ?? data['retry_after_minutes'];

  return minutes == null ? message : '$message\nMinutes left to join: $minutes';
}

/// A displayable message from a response body, or null if there is none.
///
/// Returns null rather than a placeholder so each caller can supply a fallback
/// that suits its status code.
String? _serverMessage(dynamic data) {
  if (data is! Map) return null;

  final message = data['message'];
  if (message != null) {
    final text = message.toString().trim();
    if (text.isNotEmpty) return text;
  }

  final fault = data['fault'];
  if (fault is Map && fault['faultstring'] != null) {
    final text = fault['faultstring'].toString().trim();
    if (text.isNotEmpty) return text;
  }

  return null;
}

/// Laravel's validation shape: `{message, errors: {field: [messages]}}`.
String? _validationMessage(dynamic data) {
  if (data is! Map) return null;

  final errors = data['errors'];

  if (errors is Map && errors.isNotEmpty) {
    // Phone first. It is the field members get wrong most often and the one
    // both the login and the register screen lead with, so surfacing its
    // error ahead of the others is almost always the right guess.
    final phone = errors['phone'];
    if (phone != null) return _firstMessage(phone);

    return _firstMessage(errors.values.first);
  }

  return _serverMessage(data);
}

/// One string out of a field's error list.
String _firstMessage(dynamic value) {
  if (value is List && value.isNotEmpty) return value.first.toString();
  return value.toString();
}
