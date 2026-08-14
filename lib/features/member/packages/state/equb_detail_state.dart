import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';

abstract class EqubDetailState extends Equatable {
  const EqubDetailState();

  @override
  List<Object?> get props => [];
}

class EqubDetailInitial extends EqubDetailState {}

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

class EqubDetailPaymentSuccess extends EqubDetailState {
  final String checkoutUrl;
  const EqubDetailPaymentSuccess(this.checkoutUrl);
  @override
  List<Object?> get props => [checkoutUrl];
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
