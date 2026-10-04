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

/// Neutral, for things that are neither a success nor a failure.
///
/// "We could not establish what the latest version is" is information, not an
/// error, and painting it red made a normal state look like a broken app.
/// Longer-lived than the other two because these messages say what to do next,
/// and optionally carries an action for the detail behind them.
void showInfoSnackBar(
  BuildContext ctx,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  var snackBar = SnackBar(
    dismissDirection: DismissDirection.horizontal,
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: CustomText(
            title: message,
            textColor: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
    duration: const Duration(seconds: 9),
    backgroundColor: const Color(0xFF334155),
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(
            label: actionLabel,
            textColor: Colors.white,
            onPressed: onAction,
          )
        : null,
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
