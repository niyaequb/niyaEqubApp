import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/dashboard/data/repository/agent_dashboard_repository.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_add_member_event.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_add_member_state.dart';

class AgentAddMemberBloc extends Bloc<AgentAddMemberEvent, AgentAddMemberState> {
  final AgentDashboardRepository repository;

  AgentAddMemberBloc({required this.repository})
      : super(AgentAddMemberInitial()) {
    on<AgentAddMemberSubmitEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    AgentAddMemberSubmitEvent event,
    Emitter<AgentAddMemberState> emit,
  ) async {
    emit(AgentAddMemberLoading());

    final result = await repository.addMember(
      name: event.name,
      phone: event.phone,
      email: event.email,
    );

    result.fold(
      (Failure failure) => emit(AgentAddMemberFailure(failure)),
      (_) => emit(AgentAddMemberSuccess()),
    );
  }
}
