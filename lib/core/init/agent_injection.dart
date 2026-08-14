import 'package:niya_equb/core/init/dio_network.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/agent/dashboard/data/repository/agent_dashboard_repository.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_add_member_bloc.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_bloc.dart';
import 'package:niya_equb/features/agent/members/data/repository/agent_members_repository.dart';
import 'package:niya_equb/features/agent/members/state/agent_members_bloc.dart';
import 'package:niya_equb/features/agent/payout/data/repository/agent_payout_repository.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_bloc.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';

Future<void> initAgentInjections() async {
  sl.registerSingleton<AgentDashboardRepository>(
    AgentDashboardRepository(dio: DioNetwork.appAPI),
  );
  sl.registerSingleton<AgentPayoutRepository>(
    AgentPayoutRepository(
      dio: DioNetwork.appAPI,
      dashboardRepository: sl(),
      authRepository: sl<AuthRepository>(),
    ),
  );
  sl.registerSingleton<AgentMembersRepository>(
    AgentMembersRepository(dio: DioNetwork.appAPI),
  );
  sl.registerFactory<AgentDashboardBloc>(
    () => AgentDashboardBloc(repository: sl()),
  );
  sl.registerFactory<AgentAddMemberBloc>(
    () => AgentAddMemberBloc(repository: sl()),
  );
  sl.registerFactory<AgentMembersBloc>(
    () => AgentMembersBloc(repository: sl()),
  );
  sl.registerFactory<AgentPayoutBloc>(
    () => AgentPayoutBloc(repository: sl()),
  );
}
