abstract class AgentAddMemberEvent {}

class AgentAddMemberSubmitEvent extends AgentAddMemberEvent {
  final String name;
  final String phone;
  final String? email;

  AgentAddMemberSubmitEvent({
    required this.name,
    required this.phone,
    this.email,
  });
}
