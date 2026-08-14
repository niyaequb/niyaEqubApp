import 'package:flutter/material.dart';

/// Guards against the two ways a fast tap or a slow network turns into a
/// visible navigation glitch.
///
/// **Double push.** Two taps land before the first route finishes animating in,
/// so the same screen is pushed twice. Popping once lands on the duplicate, so
/// it looks like the app "went back" to where you started.
///
/// **A stale screen navigating.** A screen that is still mounted underneath the
/// current one keeps listening to a shared bloc. When that bloc emits, the
/// buried screen runs its listener and pushes — throwing the user backwards out
/// of the screen they were on. This is the one that looks like signup bouncing
/// back to login.
class NavGuard {
  NavGuard._();

  static DateTime? _lastNavigation;

  /// How long after a navigation further navigations are ignored. Roughly one
  /// route transition — long enough to swallow a double tap, short enough that
  /// a deliberate second tap still works.
  static const Duration cooldown = Duration(milliseconds: 600);

  /// Whether [context] is allowed to navigate right now.
  ///
  /// False when the widget is gone, when its route is no longer the top-most
  /// one (something is already on top, so this screen is stale), or when
  /// another navigation just happened.
  static bool allows(BuildContext context) {
    if (!context.mounted) return false;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    final last = _lastNavigation;
    if (last != null && DateTime.now().difference(last) < cooldown) {
      return false;
    }
    return true;
  }

  /// Runs [action] only if navigation is currently allowed, and starts the
  /// cooldown. Returns whether it ran.
  static bool run(BuildContext context, VoidCallback action) {
    if (!allows(context)) return false;
    _lastNavigation = DateTime.now();
    action();
    return true;
  }

  /// Clears the cooldown. Only needed if a navigation is cancelled before it
  /// happens and the next tap must be accepted immediately.
  static void reset() => _lastNavigation = null;
}

extension NavGuardContext on BuildContext {
  /// `Navigator.pushNamed`, but a second tap during the transition is ignored,
  /// and a screen buried under another one cannot push.
  Future<T?>? pushOnce<T>(String routeName, {Object? arguments}) {
    Future<T?>? result;
    NavGuard.run(this, () {
      result = Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
    });
    return result;
  }

  /// For navigations that don't go through a named route — `Get.to`, a manual
  /// `MaterialPageRoute`, a bottom sheet. Same guarantees.
  void navigateOnce(VoidCallback action) => NavGuard.run(this, action);

  /// True when this widget's route is the one the user is looking at.
  ///
  /// Bloc listeners that navigate should check this first, otherwise every
  /// still-mounted screen further down the stack reacts to the same state and
  /// fights over the navigator.
  bool get isTopRoute {
    if (!mounted) return false;
    final route = ModalRoute.of(this);
    return route == null || route.isCurrent;
  }
}
