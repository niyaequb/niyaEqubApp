import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/agent/main/presentation/screens/agent_main_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/login_screen.dart';
import 'package:niya_equb/features/member/main/presentation/screens/ekub_main_screen.dart';
import 'package:niya_equb/core/service/navigation_service.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';

/// Opening screen.
///
/// Deliberately identical to the native launch screen: plain white, the logo
/// centred at the same size, and nothing else. No caption, no progress bar, no
/// rings.
///
/// That is the point. Android draws its own launch screen before Flutter
/// exists, and anything here that the native screen does not also have shows
/// up as a second, different-looking splash. Keeping the two the same means
/// the handover is invisible and the app appears to open on one screen rather
/// than two.
///
/// Anything changed here must be changed in the four
/// android/app/src/main/res/drawable*/launch_background.xml files too.
class SplashScreen extends StatefulWidget {
  static const String routeName = '/splash';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Must match `android:width` / `android:height` in the four
  /// launch_background.xml files, or the logo jumps size when Flutter takes
  /// over from the native screen.
  ///
  /// 380 suits the new mark. The previous 560 was compensating for the old
  /// Loading.png, a 640x640 canvas whose artwork filled only the middle 408px
  /// — a third of the file was white margin, so the box had to overshoot the
  /// screen for the mark to look full width. The replacement is trimmed to the
  /// mark and sits at 92% of its canvas, so the box size is now close to the
  /// mark's real size: at 380 the mark renders ~274dp wide, about three
  /// quarters of a phone's width, with nothing running off the edges.
  static const double _logoSize = 380;

  /// Loading.png, not the 1152x1152 Loading_android12*.png files: those carry
  /// deliberate padding so the artwork survives Android 12's circular icon
  /// mask, which makes the mark render *smaller* at any given box size. Right
  /// for the system icon, wrong here where the box is the whole screen.
  static const AssetImage _logo = AssetImage('assets/images/Loading.png');

  late final AnimationController _breathe;
  late final Animation<double> _scale;

  late final Future<bool> _session;

  /// True when the session came from the SuperApp rather than from storage —
  /// which is to say the page's storage did not survive, and any note of a
  /// payment in progress went with it. See _paymentToResume().
  bool _signedInViaHostApp = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // A very slow, very shallow pulse — 3% either way. Enough that the screen
    // reads as alive rather than frozen if start-up runs long, subtle enough
    // that it never looks like a separate animated splash.
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut));

    _session = _resolveSession();
    _begin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_logo, context);
  }

  /// Leaves as soon as the session is known.
  ///
  /// The 400ms floor exists only to avoid a jarring single-frame flash on a
  /// warm start; it is not a branding pause. The native screen has already
  /// shown this same logo for the whole of start-up, so there is nothing to
  /// wait for here.
  Future<void> _begin() async {
    final results = await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 400)),
      _session,
    ]);

    if (!mounted || _navigated) return;
    _navigated = true;

    final isLoggedIn = results[1] as bool;

    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      NavigationService.splashScreenFinished = true;
      return;
    }

    final user = PreferencesService.getUser();
    final isAgent = (user?.type ?? '').toLowerCase() == 'agent';

    // Read BEFORE leaving this screen: pushReplacementNamed disposes it, and
    // the context below would no longer be usable.
    final resume = isAgent ? null : await _paymentToResume();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    navigator.pushReplacementNamed(
      isAgent ? AgentMainScreen.routeName : EkubMainScreen.routeName,
    );

    // Back from the bank app by way of a page reload. Reopen the Equb the
    // member was paying from, on top of the home screen so Back still goes
    // somewhere sensible, and carry on confirming the payment.
    if (resume != null) {
      navigator.pushNamed(
        EqubDetailScreen.routeName,
        arguments: {
          'groupId': resume.groupId,
          'initialTab': 0,
          'awaitReference': resume.reference,
          'awaitQuietly': resume.quiet,
        },
      );
    }

    NavigationService.splashScreenFinished = true;
  }

  /// A payment the member was in the middle of, to reopen its Equb.
  ///
  /// The local note first: if the session came out of storage, storage
  /// survived, and the note is the whole truth (present or absent). Only when
  /// the session had to be re-established through the SuperApp is storage
  /// known to be gone, and then the server is asked instead. That keeps the
  /// extra request off every ordinary launch.
  ///
  /// `quiet` is true for the server's answer. That attempt may be one the
  /// member cancelled, which the bank will never confirm, so if it is still
  /// unresolved when the watch runs out the screen simply shows it as pending
  /// rather than announcing "still confirming".
  Future<({int groupId, String reference, bool quiet})?> _paymentToResume() async {
    final local = await PreferencesService.takePaymentReturn();
    if (local != null) {
      return (groupId: local.groupId, reference: local.reference, quiet: false);
    }
    if (!_signedInViaHostApp) return null;

    final remote = await sl<EkubPackagesRepository>().latestPaymentAttempt();
    return remote == null
        ? null
        : (groupId: remote.groupId, reference: remote.reference, quiet: true);
  }

  /// Whether there is a session to open the app into.
  ///
  /// A stored token first, as always. Failing that — and only inside a bank
  /// super-app, where the host already knows who the member is — the host is
  /// asked, and its answer exchanged for a session by the server.
  ///
  /// That second step is what keeps a member signed in when the Dashen
  /// SuperApp reloads the mini app after a payment, or when a member opens it
  /// from the SuperApp for the first time on a device (Dashen QA, item 9).
  /// Anywhere else it costs nothing: on a phone it returns at once, and in an
  /// ordinary browser there is no host app to answer.
  ///
  /// Bounded in time. Whatever happens, the member reaches either the app or
  /// the ordinary login screen within a few seconds; nothing here can leave
  /// them on the splash.
  Future<bool> _resolveSession() async {
    if (await PreferencesService.isLoggedIn() == true) return true;

    try {
      final identity = await sl<EkubPackagesRepository>()
          .hostAppIdentity()
          .timeout(const Duration(seconds: 8));
      if (identity == null) return false;

      final result = await sl<AuthRepository>()
          .signInWithHostApp(
            provider: identity.provider,
            identifier: identity.identifier,
            appCode: identity.appCode,
            stage: identity.stage,
          )
          .timeout(const Duration(seconds: 12));

      final signedIn = result.fold((_) => false, (ok) => ok);
      _signedInViaHostApp = signedIn;
      return signedIn;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Flat white, matching @color/splash_background exactly. Any gradient or
      // tint here would show as a colour change at the handover.
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Image(
            image: _logo,
            width: _logoSize.r,
            height: _logoSize.r,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
