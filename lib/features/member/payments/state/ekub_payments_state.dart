import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/payments/data/repository/ekub_payments_repository.dart';

abstract class EkubPaymentsState extends Equatable {}

class EkubPaymentsLoading extends EkubPaymentsState {
  @override
  List<Object?> get props => [];
}

class EkubPaymentsSuccess extends EkubPaymentsState {
  final int filterIndex; // 0 all, 1 paid, 2 pending
  final List<EkubPaymentItem> items;

  EkubPaymentsSuccess({required this.filterIndex, required this.items});

  List<EkubPaymentItem> get filtered {
    return items.where((e) {
      if (filterIndex == 1) return e.status == EkubPaymentStatus.paid;
      // Not yet settled: overdue, and paid-but-unconfirmed alike.
      if (filterIndex == 2) {
        return e.status == EkubPaymentStatus.unpaid ||
            e.status == EkubPaymentStatus.pending;
      }
      return true;
    }).toList();
  }

  EkubPaymentsSuccess copyWith({
    int? filterIndex,
    List<EkubPaymentItem>? items,
  }) {
    return EkubPaymentsSuccess(
      filterIndex: filterIndex ?? this.filterIndex,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [filterIndex, items];
}

class EkubPaymentsFailure extends EkubPaymentsState {
  final Failure failure;
  final int filterIndex;
  final List<EkubPaymentItem> items;

  EkubPaymentsFailure({
    required this.failure,
    required this.filterIndex,
    required this.items,
  });

  @override
  List<Object?> get props => [failure, filterIndex, items];
}
