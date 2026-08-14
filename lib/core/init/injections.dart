import 'package:get_it/get_it.dart';
import 'package:niya_equb/core/init/agent_injection.dart';
import 'package:niya_equb/core/init/auth_injection.dart';
import 'package:niya_equb/core/init/dio_network.dart';
import 'package:niya_equb/core/init/ekub_injection.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> initInjections() async {
  await initSharedPrefsInjections();
  await initDioInjections();
  await initAuthInjections();
  await initEkubInjections();
  await initAgentInjections();
}

Future<void> initSharedPrefsInjections() async {
  if (!sl.isRegistered<SharedPreferences>()) {
    sl.registerSingletonAsync<SharedPreferences>(() async {
      return await SharedPreferences.getInstance();
    });
  }
  await sl.isReady<SharedPreferences>();
}

Future<void> initDioInjections() async {
  DioNetwork.initDio();
}
