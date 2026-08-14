import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/members/data/repository/agent_members_repository.dart';
import 'package:niya_equb/features/agent/members/state/agent_members_event.dart';
import 'package:niya_equb/features/agent/members/state/agent_members_state.dart';

class AgentMembersBloc extends Bloc<AgentMembersEvent, AgentMembersState> {
  final AgentMembersRepository repository;

  AgentMembersBloc({required this.repository})
      : super(AgentMembersInitial()) {
    on<AgentMembersLoadEvent>(_onLoad);
  }

  Future<void> _onLoad(
    AgentMembersLoadEvent event,
    Emitter<AgentMembersState> emit,
  ) async {
    emit(AgentMembersLoading());

    final result = await repository.fetchMembers();

    result.fold(
      (Failure failure) => emit(AgentMembersFailure(failure)),
      (members) => emit(AgentMembersSuccess(members)),
    );
  }
}
