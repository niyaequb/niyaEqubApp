import 'dart:async';

import 'package:flutter/material.dart';

import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/app_update_service.dart';
import 'package:niya_equb/shared/widgets/app_update_sheet.dart';

/// Puts the update sheet in front of the user, at the two moments it matters.
///
/// Mix into the State of a screen that is the app's landing surface, then call
/// [startAppUpdateWatch] from initState and [stopAppUpdateWatch] from dispose.
///
/// WHY TWO MOMENTS
///
/// Checking only on launch misses the most common case there is: a member who
/// leaves the app open for days on a phone that never gets cold-started. The
/// release goes out, they never see it. Re-checking when the app comes back to
/// the foreground catches them, and is also what makes the prompt reappear
/// after someone taps Update, visits the store and comes back without
/// installing.
///
/// WHY IT LIVES HERE AND NOT IN A SCREEN
///
/// Members and agents land on different screens, and both need this. Written
/// twice it drifts; written once, a change to the timing is a change in one
/// place.
///
/// Everything about *whether* to interrupt still belongs to
/// AppUpdateService.checkForPrompt(). This is only timing and plumbing.
mixin AppUpdateGate<T extends StatefulWidget> on State<T> {
  /// Long enough for the first frame to land and the tab content to paint, so
  /// the sheet slides over a finished screen rather than a half-built one.
  static const Duration _launchDelay = Duration(milliseconds: 1200);

  /// Shorter on resume — the screen is already there.
  static const Duration _resumeDelay = Duration(milliseconds: 500);

  /// A floor on how often coming back to the app can trigger a network check.
  /// Switching to the banking app to pay and straight back is extremely
  /// common, and none of those returns is worth a request.
  static const Duration _resumeThrottle = Duration(minutes: 30);

  AppLifecycleListener? _lifecycle;

  bool _running = false;
  bool _sheetOpen = false;
  DateTime? _lastCheck;

  void startAppUpdateWatch() {
    _lifecycle = AppLifecycleListener(onResume: _onResumed);
    unawaited(_maybePrompt(_launchDelay));
  }

  void stopAppUpdateWatch() {
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _onResumed() {
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < _resumeThrottle) {
      return;
    }
    unawaited(_maybePrompt(_resumeDelay));
  }

  Future<void> _maybePrompt(Duration delay) async {
    // A check already in flight, or a sheet already up. The forced sheet in
    // particular stays on screen while the user is away at the store, and
    // must not be stacked on top of itself when they come back.
    if (_running || _sheetOpen) return;
    _running = true;

    try {
      await Future<void>.delayed(delay);
      if (!mounted) return;

      final info = await sl<AppUpdateService>().checkForPrompt();
      _lastCheck = DateTime.now();

      // The check is a network call, so the member may well have navigated
      // away or backgrounded the app while it was in flight.
      if (!mounted || info == null) return;

      _sheetOpen = true;
      await showAppUpdateSheet(context, info);
    } catch (e) {
      // An update prompt is never worth taking a screen down for.
      debugPrint('Update prompt skipped: $e');
    } finally {
      _sheetOpen = false;
      _running = false;
    }
  }
}
