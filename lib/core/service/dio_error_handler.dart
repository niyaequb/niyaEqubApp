import 'dart:io';

import 'package:dio/dio.dart';

String handleDioError(DioException error) {
  String errorDescription = "";
  if (error.error is SocketException) {
    SocketException socketException = error.error as SocketException;
    if (error.response?.statusCode == 401) {
      // MyApp.navigatorKey.currentState!.pushNamedAndRemoveUntil(
      //   LoginScreen.routeName,
      //   (route) => false,
      // );
    }
    if (socketException.osError?.errorCode == 101 ||
        socketException.osError?.errorCode == 7 ||
        socketException.osError?.errorCode == 8) {
      errorDescription = 'Connect to internet and try again!';
    } else {
      errorDescription =
          "Apologies for the inconvenience, our server is currently not responding and will be back online shortly.";
    }
    return errorDescription;
  } else {
    switch (error.type) {
      case DioExceptionType.cancel:
        errorDescription = "Request to API server was cancelled";
        break;
      case DioExceptionType.connectionTimeout:
        errorDescription = "Connection timeout with API server";
        break;
      case DioExceptionType.connectionError:
        errorDescription = "Internet Connection Problem.";
        break;
      case DioExceptionType.receiveTimeout:
        errorDescription = "Receive timeout in connection with API server";
        break;
      case DioExceptionType.badResponse:
        {
          if (error.response?.data['code'] != null &&
              (error.response?.data['code'] ?? "0") != "0") {
            errorDescription = error.response?.data['msg'];
          } else {
            if (error.response?.statusCode == 200 &&
                ("${(error.response?.data["statusCode"] ?? "0")}" != "0")) {
              if ((error.response?.data['data'] ?? "") != "") {
                errorDescription = (error.response?.data['data'] ?? "");
              } else {
                errorDescription = "Unknown Error";
              }
            } else if (error.response?.statusCode == 422) {
              print("..........${error.response?.data}");
              final data = error.response?.data;
              if (data is Map) {
                if (data["errors"] != null && data["errors"] is Map) {
                  final errors = data["errors"] as Map;
                  if (errors["phone"] != null) {
                    errorDescription = errors["phone"].toString();
                  } else if (errors.isNotEmpty) {
                    errorDescription = errors.values.first[0].toString();
                  }
                } else if (data['message'] != null) {
                  errorDescription = data['message'].toString();
                } else if (data['fault'] != null && data['fault'] is Map) {
                  errorDescription =
                      data['fault']['faultstring']?.toString() ??
                      "Unknown Error";
                } else {
                  errorDescription = "Unknown Error";
                }
              } else {
                errorDescription = "Unknown Error";
              }
              print(errorDescription);
            } else if (error.response?.statusCode == 413) {
              errorDescription = error.response!.statusMessage ?? "";
            } else if (error.response?.statusCode == 400) {
              errorDescription =
                  error.response?.data['message']
                      ?.toString()
                      .replaceAll("[", '')
                      .replaceAll("]", '') ??
                  "Unknown Error";
            } else if (error.response?.statusCode == 401) {
              errorDescription =
                  error.response?.data['message'] ?? "Autherization Failed";
            } else if (error.response?.statusCode == 403) {
              errorDescription = error.response?.data is String
                  ? "403 Forbidden"
                  : error.response?.data['message'] ?? "Unknown Error";
            } else if (error.response?.statusCode == 404) {
              errorDescription = error.response?.data is String
                  ? "404 Unknown Error"
                  : error.response?.data['message'] ?? "Unknown Error";
            } else if (error.response?.statusCode == 409) {
              errorDescription =
                  error.response?.data['message'] +
                      ",\n Minutes left to join: " +
                      error.response?.data["message"].toString() ??
                  "Unknown Error";
            } else if (error.response?.statusCode == 429) {
              errorDescription = error.response?.data['message'];
            } else if (error.response?.statusCode == 500) {
              if (error.response?.data['message'] != null) {
                errorDescription = error.response?.data['message'];
              } else if (error.response?.data['fault'] != null &&
                  error.response?.data['fault']['faultstring'] != null) {
                errorDescription =
                    error.response?.data['fault']['faultstring'] ??
                    "Unknown Error";
              } else {
                errorDescription =
                    "Received invalid status code: ${error.response?.statusCode}";
              }
            } else if (error.response?.statusCode == 429) {
              errorDescription = error.response?.data['message'];
            } else {
              errorDescription =
                  "Received invalid status code: ${error.response?.statusCode}";
            }
          }

          break;
        }

      case DioExceptionType.sendTimeout:
        errorDescription = "Send timeout in connection with API server";
        break;
      case DioExceptionType.badCertificate:
        break;

      case DioExceptionType.unknown:
        break;
    }
    print(errorDescription);
    return errorDescription;
  }
}
