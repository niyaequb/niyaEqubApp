import 'package:niya_equb/core/init/failures.dart';

abstract class AgentAddMemberState {}

class AgentAddMemberInitial extends AgentAddMemberState {}

class AgentAddMemberLoading extends AgentAddMemberState {}

class AgentAddMemberSuccess extends AgentAddMemberState {}

class AgentAddMemberFailure extends AgentAddMemberState {
  final Failure failure;

  AgentAddMemberFailure(this.failure);
}
