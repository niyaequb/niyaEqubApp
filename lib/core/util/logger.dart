import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only logger.
///
/// This used to run on every response and on every parsed model, re-encoding
/// the payload with indentation before handing it to `developer.log` — in
/// release builds too, where nobody can read it. On a long Equb list that was
/// milliseconds of pure waste per item, so it is now a no-op outside debug.
void logger(dynamic data) {
  if (!kDebugMode) return;

  try {
    developer.log(const JsonEncoder.withIndent('  ').convert(data));
  } catch (_) {
    // Not JSON-encodable (a model, an exception, ...) — print it plainly
    // rather than throwing from a log call.
    developer.log(data.toString());
  }
}
