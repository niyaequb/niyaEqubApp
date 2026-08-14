import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/members/data/repository/agent_members_repository.dart';

abstract class AgentMembersState {}

class AgentMembersInitial extends AgentMembersState {}

class AgentMembersLoading extends AgentMembersState {}

class AgentMembersSuccess extends AgentMembersState {
  final List<AgentMember> members;

  AgentMembersSuccess(this.members);
}

class AgentMembersFailure extends AgentMembersState {
  final Failure failure;

  AgentMembersFailure(this.failure);
}
