import 'package:niya_equb/core/init/dio_network.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/features/auth/state/auth_bloc.dart';

/// Registered synchronously, but declared as a Future to match the other
/// init*Injections functions — initInjections() awaits all five in a row, and
/// Dart forbids awaiting a `void` expression, so a plain `void` here is a
/// compile error at the call site rather than a style choice.
Future<void> initAuthInjections() async {
  sl.registerSingleton<AuthRepository>(AuthRepository(DioNetwork.appAPI));
  sl.registerFactory<AuthBloc>(() => AuthBloc(authRepository: sl()));
}
