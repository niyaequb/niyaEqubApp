abstract class AgentPayoutEvent {}

class AgentPayoutLoadEvent extends AgentPayoutEvent {
  /// Status filter: 'all', 'pending', 'completed', 'failed'
  final String? statusFilter;

  AgentPayoutLoadEvent({this.statusFilter});
}

class AgentPayoutSelectFilterEvent extends AgentPayoutEvent {
  /// Filter: 'all', 'pending', 'completed', 'failed'
  final String status;

  AgentPayoutSelectFilterEvent({required this.status});
}

class AgentPayoutRequestEvent extends AgentPayoutEvent {
  final double amount;

  AgentPayoutRequestEvent({required this.amount});
}
