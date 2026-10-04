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

  /// Which bank to pay through, or null to let the bloc work it out.
  ///
  /// Nullable because the screen usually does not know yet: it dispatches
  /// without one, and if more than one bank is live the bloc comes back asking
  /// the member to choose and the event is re-dispatched with their answer.
  /// With a single bank there is nothing to ask and the round trip is skipped.
  final String? provider;

  const EqubDetailInitiatePaymentEvent({
    required this.membershipId,
    required this.amount,
    required this.paymentDate,
    this.provider,
  });

  EqubDetailInitiatePaymentEvent withProvider(String provider) =>
      EqubDetailInitiatePaymentEvent(
        membershipId: membershipId,
        amount: amount,
        paymentDate: paymentDate,
        provider: provider,
      );

  @override
  List<Object?> get props => [membershipId, amount, provider];
}

/// Settles every place the member pays for in this Equb at once — their own
/// and any held for someone under "My Responsibility People".
///
/// No amount is carried: the server prices each place from its own membership,
/// so the total on the confirmation screen and the total actually charged come
/// from the same source and cannot drift apart.
class EqubDetailInitiateBatchPaymentEvent extends EqubDetailEvent {
  final List<int> membershipIds;
  final String paymentDate;

  /// Which bank to pay through, or null to let the bloc work it out. See
  /// [EqubDetailInitiatePaymentEvent.provider].
  final String? provider;

  const EqubDetailInitiateBatchPaymentEvent({
    required this.membershipIds,
    required this.paymentDate,
    this.provider,
  });

  EqubDetailInitiateBatchPaymentEvent withProvider(String provider) =>
      EqubDetailInitiateBatchPaymentEvent(
        membershipIds: membershipIds,
        paymentDate: paymentDate,
        provider: provider,
      );

  @override
  List<Object?> get props => [membershipIds, paymentDate, provider];
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

/// Watch for the bank to confirm a payment the member has just authorised.
///
/// Dispatched when the member comes back from the bank app. Reading the Equb
/// once, immediately, is what used to happen, and it could only ever show the
/// payment as unconfirmed: the server asks the bank AFTER it has answered a
/// read, so the answer is always one read behind. The bloc therefore reads a
/// few times over the next minute and stops as soon as the bank has decided.
class EqubDetailAwaitSettlementEvent extends EqubDetailEvent {
  final int groupId;

  /// The reference the bank was sent: the contribution's own, or the batch's
  /// when several places were paid in one charge.
  final String reference;

  /// When true and the bank has still not decided by the end of the watch,
  /// the banner simply goes away and the payment shows as pending, with no
  /// "still confirming" message. Used when the payment was recovered from the
  /// server after a reload, where it may be an attempt the member cancelled.
  final bool quietIfUnresolved;

  const EqubDetailAwaitSettlementEvent({
    required this.groupId,
    required this.reference,
    this.quietIfUnresolved = false,
  });

  @override
  List<Object?> get props => [groupId, reference, quietIfUnresolved];
}

/// The banner has been shown; put the watch back to rest.
class EqubDetailSettlementSeenEvent extends EqubDetailEvent {
  const EqubDetailSettlementSeenEvent();
}
