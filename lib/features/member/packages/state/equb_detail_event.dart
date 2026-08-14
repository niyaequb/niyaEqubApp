import 'package:equatable/equatable.dart';

abstract class EqubDetailEvent extends Equatable {
  const EqubDetailEvent();

  @override
  List<Object?> get props => [];
}

class EqubDetailLoadEvent extends EqubDetailEvent {
  final int groupId;
  final bool isSilent;
  const EqubDetailLoadEvent(this.groupId, {this.isSilent = false});
  @override
  List<Object?> get props => [groupId, isSilent];
}

class EqubDetailInitiatePaymentEvent extends EqubDetailEvent {
  final int membershipId;
  final double amount;
  final String paymentDate;
  const EqubDetailInitiatePaymentEvent({
    required this.membershipId,
    required this.amount,
    required this.paymentDate,
  });

  @override
  List<Object?> get props => [membershipId, amount];
}

class EqubDetailDrawStartedEvent extends EqubDetailEvent {
  final List<String> candidates;
  const EqubDetailDrawStartedEvent({required this.candidates});

  @override
  List<Object?> get props => [candidates];
}

class EqubDetailDrawCompletedEvent extends EqubDetailEvent {
  final String winnerName;
  const EqubDetailDrawCompletedEvent({required this.winnerName});

  @override
  List<Object?> get props => [winnerName];
}

class EqubDetailDrawTimeoutEvent extends EqubDetailEvent {
  const EqubDetailDrawTimeoutEvent();

  @override
  List<Object?> get props => [];
}

class EqubDetailLeaveEvent extends EqubDetailEvent {
  final int membershipId;
  const EqubDetailLeaveEvent(this.membershipId);

  @override
  List<Object?> get props => [membershipId];
}
