import 'package:niya_equb/core/init/app_shared_prefs.dart';
import 'package:niya_equb/core/init/injections.dart';

void initAppInjections() {
  sl.registerFactory<AppSharedPrefs>(() => AppSharedPrefs(sl()));
}
