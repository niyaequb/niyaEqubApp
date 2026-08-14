import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/dashboard/data/repository/agent_dashboard_repository.dart';

abstract class AgentDashboardState extends Equatable {}

class AgentDashboardLoading extends AgentDashboardState {
  @override
  List<Object?> get props => [];
}

class AgentDashboardSuccess extends AgentDashboardState {
  final AgentDashboardData data;

  AgentDashboardSuccess({required this.data});

  @override
  List<Object?> get props => [data];
}

class AgentDashboardFailure extends AgentDashboardState {
  final Failure failure;

  AgentDashboardFailure({required this.failure});

  @override
  List<Object?> get props => [failure];
}
