import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/agent/main/presentation/screens/agent_main_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/login_screen.dart';
import 'package:niya_equb/features/member/main/presentation/screens/ekub_main_screen.dart';
import 'package:niya_equb/core/service/navigation_service.dart';

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

    _session = PreferencesService.isLoggedIn().then((v) => v == true);
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
    Navigator.pushReplacementNamed(
      context,
      isAgent ? AgentMainScreen.routeName : EkubMainScreen.routeName,
    );
    NavigationService.splashScreenFinished = true;
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
