import 'package:flutter_screenutil/flutter_screenutil.dart';

class Helper {
  /// Get svg picture path

  /// Get vertical space
  static double getVerticalSpace() {
    return 10.h;
  }

  /// Get horizontal space
  static double getHorizontalSpace() {
    return 10.w;
  }

  /// Get Dio Header
  static Map<String, dynamic> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    }..removeWhere((key, value) => value == null);
    // Tokens tokens = await LocalStorage.getTokens();
    // return {
    // 'Content-Type': 'application/json',
    // 'Accept': 'application/json',
    //   'Authorization': 'Bearer ${tokens.accessToken}',
    // };
  }
}
