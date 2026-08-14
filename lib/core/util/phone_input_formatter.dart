import 'package:flutter/services.dart';

/// Turns whatever the user types into the 9 digit national number the API
/// expects, while they type.
///
/// The field already shows a fixed `+251` prefix, so a leading trunk `0` or a
/// pasted country code would push the number to 10-12 digits and fail
/// validation. This trims them away instead of making the user notice:
///
/// * `09`               -> `9`
/// * `07`               -> `7`
/// * `0912345678`       -> `912345678`
/// * `251912345678`     -> `912345678`
/// * `+251 91 234 5678` -> `912345678`
class EthiopianPhoneInputFormatter extends TextInputFormatter {
  const EthiopianPhoneInputFormatter({this.maxLength = 9});

  /// Length of the national number, without the country code.
  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = normalizeLocalPhone(newValue.text, maxLength: maxLength);

    if (cleaned == newValue.text) return newValue;

    // Shift the caret by however many characters were dropped, so the cursor
    // stays under the user's finger instead of jumping to the start.
    final removed = newValue.text.length - cleaned.length;
    final offset = (newValue.selection.baseOffset - removed).clamp(
      0,
      cleaned.length,
    );

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}

/// Drops everything that is not a digit, then removes a `251` country code
/// and any leading zeros, leaving just the national number.
///
/// Safe to call on already-clean input: `912345678` comes back unchanged.
String normalizeLocalPhone(String input, {int maxLength = 9}) {
  var digits = input.replaceAll(RegExp(r'\D'), '');

  // `+251 9...`, `251 9...` and `2519...` all collapse to `9...`. Guarded on
  // length so that someone who has only typed `251` so far still sees it.
  while (digits.length > 3 && digits.startsWith('251')) {
    digits = digits.substring(3);
  }

  // `09...` -> `9...`, `07...` -> `7...`. Looping also covers a stray `00251`.
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.length > maxLength) digits = digits.substring(0, maxLength);
  return digits;
}

/// `09 12 34 56 78` -> `+251912345678`.
///
/// Use this wherever a phone number is about to be sent to the API so the
/// `+251` prefix is never hand-assembled from a raw controller value again.
String toInternationalPhone(String input) {
  final local = normalizeLocalPhone(input);
  return local.isEmpty ? '' : '+251$local';
}
