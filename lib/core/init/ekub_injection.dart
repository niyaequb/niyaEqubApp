import 'package:niya_equb/core/init/dio_network.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/app_update_service.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/features/member/draw/data/repository/ekub_draw_repository.dart';
import 'package:niya_equb/features/member/draw/state/ekub_draw_bloc.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_bloc.dart';
import 'package:niya_equb/features/member/groups/state/group_list_bloc.dart';
import 'package:niya_equb/features/member/home/data/repository/ekub_home_repository.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_bloc.dart';
import 'package:niya_equb/features/member/islamic/data/repository/quran_repository.dart';
import 'package:niya_equb/features/member/islamic/services/quran_audio_controller.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_bloc.dart';
import 'package:niya_equb/features/member/islamic/state/quran_bloc.dart';
import 'package:niya_equb/features/member/notifications/data/repository/ekub_notifications_repository.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_bloc.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_bloc.dart';
import 'package:niya_equb/features/member/payments/data/repository/ekub_payments_repository.dart';
import 'package:niya_equb/features/member/payments/state/ekub_payments_bloc.dart';
import 'package:niya_equb/features/member/profile/data/repository/ekub_profile_repository.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_bloc.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_bloc.dart';
import 'package:niya_equb/features/member/settings/data/repository/settings_repository.dart';
import 'package:niya_equb/features/member/settings/state/settings_bloc.dart';

Future<void> initEkubInjections() async {
  // Data layer
  sl.registerSingleton<EkubHomeRepository>(
    EkubHomeRepository(dio: DioNetwork.appAPI),
  );
  sl.registerSingleton<EkubPackagesRepository>(
    EkubPackagesRepository(dio: DioNetwork.appAPI),
  );
  sl.registerSingleton<EkubPaymentsRepository>(
    EkubPaymentsRepository(dio: DioNetwork.appAPI),
  );
  sl.registerSingleton<EkubDrawRepository>(
    EkubDrawRepository(dio: DioNetwork.appAPI),
  );
  sl.registerSingleton<EkubNotificationsRepository>(
    EkubNotificationsRepository(),
  );
  sl.registerSingleton<EkubProfileRepository>(
    EkubProfileRepository(
      dio: DioNetwork.appAPI,
      authRepository: sl<AuthRepository>(),
    ),
  );
  sl.registerSingleton<SettingsRepository>(
    SettingsRepository(dio: DioNetwork.appAPI),
  );
  sl.registerSingleton<GroupEqubRepository>(
    GroupEqubRepository(dio: DioNetwork.appAPI),
  );

  // Ibada Center. QuranRepository builds its own Dio: the verse API is a
  // public CDN, not our backend, so it must not inherit the auth interceptor
  // or the app base URL.
  sl.registerSingleton<QuranRepository>(QuranRepository());

  // One player for the whole app. Recitation has to outlive the reader screen,
  // and the platform media session is process-wide — a second player instance
  // would hijack the notification controls from the first.
  //
  // Lazy so no ExoPlayer/AVPlayer is spun up at launch for users who never
  // open the Quran, and as a second line of defence on init ordering: the
  // AudioPlayer cannot be constructed before JustAudioBackground.init() has
  // run, whatever else moves around in main().
  sl.registerLazySingleton<QuranAudioController>(
    () => QuranAudioController(repository: sl()),
  );

  // Presentation layer
  sl.registerFactory<EkubHomeBloc>(
    () => EkubHomeBloc(repository: sl(), packagesRepository: sl(), notificationService: sl()),
  );
  sl.registerFactory<EkubPackagesBloc>(
    () => EkubPackagesBloc(repository: sl(), notificationService: sl()),
  );
  sl.registerFactory<EkubPaymentsBloc>(
    () => EkubPaymentsBloc(repository: sl()),
  );
  sl.registerFactory<EkubDrawBloc>(() => EkubDrawBloc(repository: sl()));
  sl.registerFactory<EkubNotificationsBloc>(
    () => EkubNotificationsBloc(repository: sl()),
  );
  sl.registerFactory<EkubProfileBloc>(() => EkubProfileBloc(repository: sl()));
  sl.registerFactory<EqubDetailBloc>(() => EqubDetailBloc(repository: sl()));
  sl.registerFactory<SettingsBloc>(() => SettingsBloc(repository: sl()));
  sl.registerFactory<GroupListBloc>(() => GroupListBloc(repository: sl()));
  sl.registerFactory<GroupDetailBloc>(() => GroupDetailBloc(repository: sl()));
  sl.registerFactory<IslamicCenterBloc>(() => IslamicCenterBloc());
  sl.registerFactory<QuranBloc>(() => QuranBloc(repository: sl()));

  // Services
  sl.registerLazySingleton<NotificationService>(() => NotificationService());

  // Version check. A singleton so the PackageInfo lookup happens once per
  // launch rather than on every screen that asks.
  sl.registerLazySingleton<AppUpdateService>(
    () => AppUpdateService(dio: DioNetwork.appAPI),
  );
}
