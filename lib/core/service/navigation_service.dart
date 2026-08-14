// lib/shared/services/navigation_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool splashScreenFinished = false;

  static BuildContext? get context => navigatorKey.currentState?.context;

  /// Held as a literal rather than `LoginScreen.routeName` so this service
  /// stays importable from the network layer without dragging a screen — and
  /// its widgets, and their blocs — in behind it. Must match
  /// LoginScreen.routeName.
  static const String loginRoute = '/login';

  /// The name of the route the user is currently looking at.
  ///
  /// `popUntil` with a predicate that is true on the first route pops nothing;
  /// it is the supported way to read the top of the stack from outside the
  /// widget tree.
  static String? get currentRouteName {
    String? name;
    navigatorKey.currentState?.popUntil((route) {
      name = route.settings.name;
      return true;
    });
    return name;
  }

  static bool get isOnLoginScreen => currentRouteName == loginRoute;

  /// Covers the gap between clearing the session and the login route actually
  /// landing on the stack.
  static bool _returningToLogin = false;

  /// Ends the session and returns to login — once, however many callers ask
  /// at the same moment.
  ///
  /// One expired token produces several of these calls in a row: the refresh
  /// attempt fails, the interceptor gives up, and every request queued behind
  /// it comes back 401 as well. Each used to run its own
  /// `pushNamedAndRemoveUntil`, and two of those back to back animate the
  /// login screen in twice — the glitch where login appears to open, then
  /// open again.
  ///
  /// Two guards, because one does not cover it. [isOnLoginScreen] turns away
  /// everything that arrives after the route is on the stack; the latch turns
  /// away the callers that arrive during the `await` below, while there is
  /// still nothing on the stack to see.
  static Future<void> returnToLogin() async {
    if (_returningToLogin) return;
    _returningToLogin = true;

    try {
      await PreferencesService.clearUserData();

      final navigator = navigatorKey.currentState;
      if (navigator == null || isOnLoginScreen) return;

      // Deliberately not awaited: the future returned here completes when the
      // login route is itself popped, and a route pushed with
      // `removeUntil((_) => false)` underneath it never is.
      unawaited(navigator.pushNamedAndRemoveUntil(loginRoute, (_) => false));
    } finally {
      // Released on a timer rather than at once, so a burst of 401s from
      // requests that were already in flight collapses into this single
      // navigation while a later, genuine expiry still works.
      Timer(const Duration(milliseconds: 800), () => _returningToLogin = false);
    }
  }
}
