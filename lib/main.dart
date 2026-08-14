import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// One barrel import. The four deep `package:get/get_*/src/...` imports that
// used to sit here reached into GetX's private source tree for symbols this
// barrel already exports — they break on any internal reshuffle upstream and
// gave nothing in return.
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/constants/hive_constants.dart';
import 'package:niya_equb/core/init/app_injections.dart';
import 'package:niya_equb/core/init/bloc_providers.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/language/controllers/language_controller.dart';
import 'package:niya_equb/core/router/router.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/crash_reporter.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/core/service/navigation_service.dart';
import 'package:niya_equb/core/util/app_constants.dart';
import 'package:niya_equb/core/util/get_di.dart' as di;
import 'package:niya_equb/core/util/messages.dart';
import 'package:niya_equb/features/init/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'package:niya_equb/core/service/background_notification_handler.dart';
import 'package:niya_equb/features/member/islamic/data/repository/quran_repository.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Everything, including the binding, runs inside the guarded zone.
  //
  // Splitting them is a real trap: WidgetsFlutterBinding.ensureInitialized()
  // binds to whatever zone calls it, and if runApp later runs in a different
  // one Flutter throws "Zone mismatch" and the async errors this zone exists
  // to catch go somewhere else entirely.
  runZonedGuarded(
    _bootstrap,
    (Object error, StackTrace stack) {
      CrashReporter.record('UNCAUGHT DART ERROR (zone)', error, stack);
    },
  );
}

/// Runs one start-up step, and keeps going if it throws.
///
/// Start-up used to be a straight line of awaits: any one of them throwing
/// meant runApp was never reached, and an app that never calls runApp shows a
/// white window and then an ANR — indistinguishable from a hang, and with
/// nothing on screen to say what happened. Now a failed step is recorded and
/// the app still boots, degraded, with the reason retrievable afterwards.
Future<void> _guard(String step, Future<void> Function() action) async {
  try {
    await action();
  } catch (e, s) {
    debugPrint('Start-up step "$step" failed: $e');
    CrashReporter.record('START-UP FAILED: $step', e, s);
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything else that can throw.
  CrashReporter.installDartHandlers();

  // Never let a failure show as a blank screen again. The default ErrorWidget
  // in release is an empty grey box, indistinguishable from "still loading",
  // which is exactly what made this hard to diagnose. Put the message on
  // screen instead, and into the crash report so it survives the screenshot.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    CrashReporter.record('WIDGET BUILD ERROR', details.exception, details.stack);

    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Text(
            'Startup error\n\n${details.exception}',
            style: const TextStyle(color: Color(0xFFB01F2E), fontSize: 13),
          ),
        ),
      ),
    );
  };

  // SAFE MODE. Checked here, first, and deliberately in front of every line
  // below that could be the thing that crashed.
  //
  // A device stuck in a launch crash loop never reaches a screen, so a report
  // shown from inside the app is a report nobody can read. Showing it before
  // start-up begins is the only placement that works on the one device that
  // matters — the client's, which is the one that crashes.
  //
  // The report is cleared as it is read, so this screen appears once per
  // crash. Continue runs the normal start-up, so a one-off crash costs a tap
  // rather than a working app.
  final pendingReport = await CrashReporter.lastReport();
  if (pendingReport != null && pendingReport.trim().isNotEmpty) {
    await CrashReporter.clear();
    runApp(SafeModeApp(report: pendingReport, onContinue: _startApp));
    return;
  }

  await _startApp();
}

/// Normal start-up.
///
/// Split out of [_bootstrap] so the safe-mode screen's Continue button can run
/// it on demand — runApp is callable more than once and swaps the root widget,
/// so this replaces the report screen with the real app.
Future<void> _startApp() async {
  // Init order note: IslamicPrefs and date formatting stay BEFORE runApp.
  // An earlier attempt moved them after it to shorten cold start and the app
  // rendered blank white, because anything reading them during a first build
  // threw before the first frame. What is safe to move is work nothing on the
  // first frame touches — see _warmUpIbada() below. What is safe to overlap is
  // steps that do not read each other, which is what the Future.wait calls
  // here do.

  // Independent of each other, so they run together. initializeDateFormatting
  // loads every locale's date symbols and Firebase does a native handshake;
  // serially that was the two biggest costs added end to end.
  //
  // Guarded separately: a Firebase handshake failure (a stale
  // google-services.json, a device with no Play Services) must cost push
  // notifications, not the whole app.
  await _guard('date formatting', initializeDateFormatting);
  await _guard('Firebase', () async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  });

  initAppInjections();

  // di.init() reads SharedPreferences and the language JSON from the asset
  // bundle; Hive.initFlutter() touches neither. Safe to overlap.
  var languages = <String, Map<String, String>>{};
  await _guard('DI and Hive', () async {
    final results = await Future.wait([
      di.init(),
      Hive.initFlutter(),
    ]);
    languages = results[0] as Map<String, Map<String, String>>;
  });

  await _guard('injections', initInjections);

  // Four independent stores: secure storage, the settings box, the response
  // cache and the Ibada prefs. None reads the others, so they open together.
  await _guard('local stores', () async {
    await Future.wait<Object?>([
      PreferencesService.initialize(),
      Hive.openBox(HiveConstants.appSettingsBox),
      AppCache.initialize(),
      IslamicPrefs.initialize(),
    ]);
  });

  // Reached even if every step above failed. A degraded app the user can look
  // at beats a white rectangle they cannot.
  runApp(MyApp(appLanguage: languages));

  // The two genuinely expensive steps, moved off the launch path.
  //
  // QuranRepository.initialize() parses the surah index and
  // AzanNotificationService.initialize() loads the timezone database and
  // rebuilds the notification schedule. Neither is reachable until the user
  // taps into the Ibada tab, but awaiting them before runApp made every cold
  // start wait for both. This is the difference between this app's launch and
  // the previous one's, which had no Ibada Center at all.
  //
  // Guarded so a failure here can never take down launch.
  unawaited(_warmUpIbada());
}

/// Blocks until the app is genuinely on screen and interactive.
///
/// Anything that starts an Android service has to wait for this. Android 12
/// forbids starting a foreground service from the background and throws
/// ForegroundServiceStartNotAllowedException when you try — a Java throw on
/// the platform thread, which no Dart `try` can catch, so the process simply
/// dies. `unawaited(_warmUpIbada())` fires the instant runApp returns, which
/// is before the first frame and therefore before the activity is reliably
/// resumed.
Future<void> _waitUntilForeground() async {
  final binding = WidgetsBinding.instance;

  await binding.endOfFrame;

  // Launched straight into the background — a push notification waking the
  // app, or the user leaving during start-up. Poll rather than give up: the
  // wait costs nothing and the alternative is the Quran player never
  // initialising for that session.
  //
  // A null lifecycleState is treated as good enough. It means the platform has
  // not reported one yet, and a frame having already rendered is decent
  // evidence the window is visible — blocking on null would delay audio init
  // by the full timeout on any device that reports late.
  var waited = Duration.zero;
  const step = Duration(milliseconds: 400);
  const limit = Duration(minutes: 2);

  while (binding.lifecycleState != null &&
      binding.lifecycleState != AppLifecycleState.resumed &&
      waited < limit) {
    await Future<void>.delayed(step);
    waited += step;
  }
}

Future<void> _warmUpIbada() async {
  // FCM registration first: it is the most useful of the deferred steps and
  // the cheapest to get wrong if it is left too late.
  //
  // Off the launch path because initialize() fetches a device token over the
  // network, so every cold start waited on a round trip. Nothing on the first
  // frame needs it — the blocs that listen to messageStream attach to a
  // controller created in the service's constructor, not in initialize().
  try {
    await sl<NotificationService>().initialize();
  } catch (e, s) {
    debugPrint('Notification init failed: $e');
    CrashReporter.record('WARM-UP: notifications', e, s);
  }

  // Binds the Quran player to the platform media session, producing the
  // notification-shade and lock-screen transport controls.
  //
  // This starts a foreground service and was the single most expensive step
  // on the launch path — the previous app had no audio at all, which is much
  // of why it opened faster. It is safe here because QuranAudioController is
  // registered lazily: the first AudioPlayer is not constructed until someone
  // actually opens the Quran reader, which is several taps and several seconds
  // away. It must still complete before that happens, so it runs first.
  //
  // The foreground wait in front of it is not optional on Android 12+. See
  // _waitUntilForeground().
  try {
    await _waitUntilForeground();
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.niyaet.ekub.channel.quran',
      androidNotificationChannelName: 'Quran Recitation',
      // Non-ongoing so the notification is dismissible when paused and the
      // service leaves the foreground instead of pinning a permanent entry.
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    );
  } catch (e, s) {
    debugPrint('Audio session init failed: $e');
    CrashReporter.record('WARM-UP: audio session', e, s);
  }

  try {
    await QuranRepository.initialize();
  } catch (e, s) {
    debugPrint('Quran init failed: $e');
    CrashReporter.record('WARM-UP: quran', e, s);
  }

  try {
    await AzanNotificationService.initialize();
    // Re-arm the rolling azan window on every launch. Cheap and idempotent —
    // the notification ids are deterministic — and the backstop for what the
    // boot receiver misses: a force-stop, a restore from backup, or the user
    // crossing a timezone.
    await AzanNotificationService.rescheduleAll();
  } catch (e, s) {
    debugPrint('Azan init failed: $e');
    CrashReporter.record('WARM-UP: azan', e, s);
  }
}

class MyApp extends StatefulWidget {
  final Map<String, Map<String, String>> appLanguage;
  const MyApp({super.key, required this.appLanguage});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: providers(),
      child: ScreenUtilInit(
        builder: (context, child) {
          return ValueListenableBuilder(
            valueListenable: Hive.box(
              HiveConstants.appSettingsBox,
            ).listenable(),
            builder: (context, appSettingsBox, _) {
              final isDark =
                  appSettingsBox.get(
                        HiveConstants.isDarkTheme,
                        defaultValue: false,
                      )
                      as bool;
              return GetBuilder<LocalizationController>(
                init: Get.find<LocalizationController>(),
                builder: (localizeController) {
                  if (localizeController.isLoading) {
                    return const MaterialApp(
                      home: Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  return GetMaterialApp(
                    navigatorKey: NavigationService.navigatorKey,
                    debugShowCheckedModeBanner: false,
                    locale: localizeController.locale,
                    translations: Messages(languages: widget.appLanguage),
                    fallbackLocale: Locale(
                      AppConstants.languages[0].languageCode!,
                      AppConstants.languages[0].countryCode,
                    ),
                    onGenerateRoute: AppRouter.generateRoute,
                    title: 'app_name'.tr,
                    themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                    theme: getAppTheme(context: context, isDarkTheme: false),
                    darkTheme: getAppTheme(context: context, isDarkTheme: true),
                    home: const SplashScreen(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
