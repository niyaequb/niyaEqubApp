import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/dashboard/data/repository/agent_dashboard_repository.dart';
import 'package:niya_equb/features/agent/payout/data/repository/agent_payout_repository.dart';

abstract class AgentPayoutState extends Equatable {}

class AgentPayoutInitial extends AgentPayoutState {
  @override
  List<Object?> get props => [];
}

class AgentPayoutLoading extends AgentPayoutState {
  @override
  List<Object?> get props => [];
}

class AgentPayoutSuccess extends AgentPayoutState {
  final AgentDashboardData? dashboard;
  final List<AgentPayment> payments;
  final bool hasBankInfo;
  /// Current filter: 'all', 'pending', 'completed', 'failed'
  final String statusFilter;

  AgentPayoutSuccess({
    this.dashboard,
    this.payments = const [],
    required this.hasBankInfo,
    this.statusFilter = 'all',
  });

  @override
  List<Object?> get props => [dashboard, payments, hasBankInfo, statusFilter];
}

class AgentPayoutFailure extends AgentPayoutState {
  final Failure failure;

  AgentPayoutFailure({required this.failure});

  @override
  List<Object?> get props => [failure];
}

class AgentPayoutRequestLoading extends AgentPayoutState {
  @override
  List<Object?> get props => [];
}
