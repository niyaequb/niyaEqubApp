import 'dart:async';

// PlatformDispatcher comes from foundation.dart, which re-exports it. Importing
// dart:ui directly for it collides with material.dart on TextStyle.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:niya_equb/core/service/navigation_service.dart';
import 'package:share_plus/share_plus.dart';

/// Records whatever killed the app and shows it on the next launch.
///
/// The Kotlin half (CrashReporter.kt) owns the file and catches JVM
/// throwables. This half catches the Dart ones and writes them to the same
/// place, so one report covers both sides of the bridge and whoever reads it
/// does not have to know in advance which side failed.
///
/// Nothing is uploaded. The report is shown to whoever is holding the phone
/// and leaves the device only if they tap Send — which, for a crash that only
/// reproduces on a client's handset in another city, is the entire point.
class CrashReporter {
  CrashReporter._();

  static const MethodChannel _channel = MethodChannel('com.niyaet.ekub/crash');

  /// Set once a report has been shown, so a rebuild or a second navigation
  /// cannot raise the same dialog twice.
  static bool _shown = false;

  // ------------------------------------------------------------------
  // Recording
  // ------------------------------------------------------------------

  /// Routes every Dart error Flutter knows about into the report file.
  ///
  /// Three hooks, because Flutter has three separate holes:
  ///
  ///  * [FlutterError.onError] takes synchronous errors thrown inside the
  ///    framework — build, layout, paint.
  ///  * [PlatformDispatcher.onError] takes uncaught asynchronous errors that
  ///    escape to the engine, which is where a failed await in a bloc lands.
  ///  * runZonedGuarded in main() takes what is left.
  ///
  /// Called before runApp, so nothing during start-up is missed.
  static void installDartHandlers() {
    final previousOnError = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      // Still print it. In debug this is the red screen and the console trace,
      // and trading that away for a silent file write would be a bad deal.
      previousOnError?.call(details);

      record(
        'FLUTTER ERROR (${details.library ?? 'framework'})',
        details.exception,
        details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      record('UNCAUGHT DART ERROR (async)', error, stack);
      // False lets the error carry on to the default handler, which prints it.
      // True would swallow it entirely.
      return false;
    };
  }

  /// Writes one error into the report file, replacing any earlier one.
  ///
  /// Deliberately fire-and-forget. This is called from error handlers, and an
  /// await here could stall behind the very failure being recorded.
  static void record(String label, Object error, StackTrace? stack) {
    final body = StringBuffer()
      ..writeln('Source: $label')
      ..writeln()
      ..writeln(error.toString())
      ..writeln()
      ..writeln(stack?.toString() ?? 'no stack trace available');

    debugPrint('[CrashReporter] $label: $error');

    unawaited(
      _channel
          .invokeMethod<bool>('record', {'body': body.toString()})
          .catchError((Object e) {
            // Android only. On iOS, or in a test harness, the channel is not
            // registered — and failing to record must not itself throw.
            debugPrint('[CrashReporter] could not persist report: $e');
            return false;
          }),
    );
  }

  // ------------------------------------------------------------------
  // Reading
  // ------------------------------------------------------------------

  /// The report from the last crash, or null when the last run ended cleanly.
  static Future<String?> lastReport() async {
    try {
      return await _channel.invokeMethod<String>('read');
    } catch (e) {
      debugPrint('[CrashReporter] could not read report: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clear');
    } catch (e) {
      debugPrint('[CrashReporter] could not clear report: $e');
    }
  }

  // ------------------------------------------------------------------
  // Showing
  // ------------------------------------------------------------------

  /// If the previous run crashed, offers the report to the user.
  ///
  /// Called once the first real screen has settled rather than during
  /// start-up: the dialog needs a navigator, and one raised against the splash
  /// mid-pushReplacement is attached to a route that is being torn down.
  ///
  /// This is the path for a crash that happened mid-session. A crash during
  /// start-up never gets here — the app dies before the splash navigates — and
  /// is handled by [SafeModeApp] instead.
  static Future<void> showIfPending() async {
    if (_shown) return;

    final report = await lastReport();
    if (report == null || report.trim().isEmpty) return;

    _shown = true;

    // Cleared as soon as it has been read. If the app crashes again the
    // handler writes a fresh one, and leaving the old text in place would mean
    // the second report never gets seen.
    await clear();

    final context = NavigationService.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CrashReportDialog(report: report),
    );
  }
}

/// The whole app, replaced by the crash report.
///
/// WHY A SEPARATE ROOT AND NOT A DIALOG
///
/// A dialog needs the app to reach a screen first. The crash being chased
/// kills the process during start-up, so the app never gets that far — the
/// report would be written on every run and read on none of them, and the user
/// would sit in a crash loop with a perfect diagnosis they can never see.
///
/// So when a report is found, start-up stops here. Nothing that could have
/// caused the crash has run yet: no Firebase, no plugins, no dependency
/// injection, no cached data read from disk. Just Material and a share button.
/// That is what makes this reachable on a device where everything else fails.
class SafeModeApp extends StatelessWidget {
  const SafeModeApp({super.key, required this.report, required this.onContinue});

  final String report;

  /// Runs the normal start-up. Wired to the Continue button so a user who is
  /// not stuck in a loop is never trapped on this screen.
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Color(0xFFB01F2E),
                ),
                const SizedBox(height: 14),
                const Text(
                  'The app closed unexpectedly',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please send this report to the developer so it can be '
                  'fixed. Nothing has been sent automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        report,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Share.share(
                    report,
                    subject: 'Niya Umrah Equb crash report',
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Send report'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onContinue,
                  child: const Text('Continue to the app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrashReportDialog extends StatelessWidget {
  final String report;

  const _CrashReportDialog({required this.report});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('The app closed unexpectedly'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sorry about that. Sending this report to the developer is what '
              'lets it get fixed. Nothing has been sent automatically.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  report,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Share.share(report, subject: 'Niya Umrah Equb crash report');
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.ios_share_rounded, size: 16),
          label: const Text('Send report'),
        ),
      ],
    );
  }
}
