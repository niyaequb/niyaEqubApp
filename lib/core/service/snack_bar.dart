import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:niya_equb/shared/widgets/custom_text.dart';

void showErrorSnackBar(BuildContext ctx, String message) {
  var snackBar = SnackBar(
    dismissDirection: DismissDirection.horizontal,
    content: Row(
      children: [
        const Icon(Icons.info, color: Colors.white),
        const SizedBox(width: 10),
        Flexible(
          child: CustomText(title: message, textColor: Colors.white),
        ),
      ],
    ),
    duration: const Duration(seconds: 5),
    backgroundColor: Colors.red,
  );
  ScaffoldMessenger.of(ctx).clearSnackBars();
  ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
}

void showSuccessSnackBar(BuildContext ctx, String message) {
  var snackBar = SnackBar(
    dismissDirection: DismissDirection.horizontal,
    content: Row(
      children: [
        Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            message,
            softWrap: true,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
    duration: const Duration(seconds: 5),
    backgroundColor: Colors.green,
  );
  ScaffoldMessenger.of(ctx).clearSnackBars();
  ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
}

class CustomToast {
  static void showToast(
    String message, {
    Color bgColor = Colors.green,
    Color textColor = Colors.white,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: bgColor,
      textColor: textColor,
      fontSize: 16.0,
    );
  }
}
