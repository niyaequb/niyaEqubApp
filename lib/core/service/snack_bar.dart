import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

// HOW THE APP'S MESSAGES LOOK
//
// Floating cards with rounded corners rather than a strip glued to the bottom
// edge, so they sit clear of the tab bar and read as a message rather than as
// part of the screen. The colours are the palette's deep status colours: the
// old Material red and green carried white text at under 4:1 and 3:1, which
// is why a success message could be hard to read in sunlight.

/// The card every message here is drawn on.
SnackBar _niyaSnackBar({
  required Widget content,
  required Color background,
  required Duration duration,
  SnackBarAction? action,
}) {
  return SnackBar(
    dismissDirection: DismissDirection.horizontal,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 4,
    content: content,
    duration: duration,
    backgroundColor: background,
    action: action,
  );
}

void showErrorSnackBar(BuildContext ctx, String message) {
  var snackBar = _niyaSnackBar(
    content: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Flexible(
          child: CustomText(title: message, textColor: Colors.white),
        ),
      ],
    ),
    duration: const Duration(seconds: 5),
    background: NiyaPalette.danger,
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
  var snackBar = _niyaSnackBar(
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
    background: const Color(0xFF2B2728),
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
  var snackBar = _niyaSnackBar(
    content: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white),
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
    background: NiyaPalette.success,
  );
  ScaffoldMessenger.of(ctx).clearSnackBars();
  ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
}

class CustomToast {
  static void showToast(
    String message, {
    Color bgColor = NiyaPalette.success,
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
