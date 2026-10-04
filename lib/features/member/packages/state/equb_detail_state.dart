import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/service/payments/payment_bridge.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_event.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';

abstract class EqubDetailState extends Equatable {
  const EqubDetailState();

  @override
  List<Object?> get props => [];
}

class EqubDetailInitial extends EqubDetailState {}

/// Where the screen is in confirming a payment the member has just made.
///
/// Carried on [EqubDetailSuccess] rather than as states of its own, so that
/// confirming a payment never swaps the Equb screen out for a spinner: the
/// member keeps seeing their schedule, history and draw while the bank is
/// asked, and the banner above them says what is happening.
enum SettlementWatch {
  /// Nothing is being confirmed.
  none,

  /// Back from the bank app; asking the server, which asks the bank.
  confirming,

  /// The bank confirmed the payment. Shown once, then back to [none].
  confirmed,

  /// The bank reported the payment as not completed.
  failed,

  /// Still unconfirmed after the watch ran out. Not a failure: the server
  /// keeps asking the bank on its own, and the row updates when it lands.
  stillPending,
}

class EqubDetailLoading extends EqubDetailState {}

class EqubDetailSuccess extends EqubDetailState {
  final int? groupId;
  final EqubGroup group;
  final List<EqubPayment> payments;
  final List<EqubDraw> draws;
  final List<PaymentScheduleItem> schedule;
  final bool isDrawing;
  final String? winnerName;
  final List<String> candidates;
  final double? exchangeRate;
  final SettlementWatch settlement;

  const EqubDetailSuccess({
    this.groupId,
    required this.group,
    required this.payments,
    required this.draws,
    this.schedule = const [],
    this.isDrawing = false,
    this.winnerName,
    this.candidates = const [],
    this.exchangeRate,
    this.settlement = SettlementWatch.none,
  });

  @override
  List<Object?> get props => [
    groupId,
    group,
    payments,
    draws,
    schedule,
    isDrawing,
    winnerName,
    candidates,
    exchangeRate,
    settlement,
  ];

  EqubDetailSuccess copyWith({
    int? groupId,
    EqubGroup? group,
    List<EqubPayment>? payments,
    List<EqubDraw>? draws,
    List<PaymentScheduleItem>? schedule,
    bool? isDrawing,
    String? winnerName,
    List<String>? candidates,
    double? exchangeRate,
    SettlementWatch? settlement,
  }) {
    return EqubDetailSuccess(
      groupId: groupId ?? this.groupId,
      group: group ?? this.group,
      payments: payments ?? this.payments,
      draws: draws ?? this.draws,
      schedule: schedule ?? this.schedule,
      isDrawing: isDrawing ?? this.isDrawing,
      winnerName: winnerName ?? this.winnerName,
      candidates: candidates ?? this.candidates,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      settlement: settlement ?? this.settlement,
    );
  }
}

class EqubDetailFailure extends EqubDetailState {
  final Failure failure;
  const EqubDetailFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class EqubDetailPaymentLoading extends EqubDetailState {}

/// A signed order is ready for the member to authorise.
///
/// Named Success for continuity, but note what it means: a bank order exists,
/// no money has moved. Settlement happens later and is decided by the server.
class EqubDetailPaymentSuccess extends EqubDetailState {
  final PaymentSession session;
  const EqubDetailPaymentSuccess(this.session);
  @override
  List<Object?> get props => [session.reference];
}

/// More than one bank is live and the member has to choose.
///
/// The originating event travels with the state so the screen can re-dispatch
/// it verbatim once a bank is picked. Rebuilding it from screen-side variables
/// instead would risk the second attempt carrying different memberships or a
/// different date from the one the member just confirmed.
class EqubDetailPaymentChooseBank extends EqubDetailState {
  final List<PaymentClientConfig> banks;
  final EqubDetailEvent pendingEvent;

  const EqubDetailPaymentChooseBank(this.banks, this.pendingEvent);

  @override
  List<Object?> get props => [banks.map((b) => b.slug).toList(), pendingEvent];
}

class EqubDetailPaymentFailure extends EqubDetailState {
  final Failure failure;
  const EqubDetailPaymentFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class EqubDetailLeaveLoading extends EqubDetailState {}

class EqubDetailLeaveSuccess extends EqubDetailState {}

class EqubDetailLeaveFailure extends EqubDetailState {
  final Failure failure;
  const EqubDetailLeaveFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}
