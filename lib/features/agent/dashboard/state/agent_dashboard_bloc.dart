import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/dashboard/data/repository/agent_dashboard_repository.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_event.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_state.dart';

class AgentDashboardBloc
    extends Bloc<AgentDashboardEvent, AgentDashboardState> {
  final AgentDashboardRepository repository;

  AgentDashboardBloc({required this.repository})
    : super(AgentDashboardLoading()) {
    on<AgentDashboardLoadEvent>(_onLoad);
  }

  Future<void> _onLoad(
    AgentDashboardLoadEvent event,
    Emitter<AgentDashboardState> emit,
  ) async {
    emit(AgentDashboardLoading());

    final result = await repository.fetchDashboard();

    result.fold(
      (Failure failure) => emit(AgentDashboardFailure(failure: failure)),
      (AgentDashboardData data) => emit(AgentDashboardSuccess(data: data)),
    );
  }
}
