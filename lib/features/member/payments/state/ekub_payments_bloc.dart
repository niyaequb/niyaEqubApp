import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/payments/data/repository/ekub_payments_repository.dart';
import 'package:niya_equb/features/member/payments/state/ekub_payments_event.dart';
import 'package:niya_equb/features/member/payments/state/ekub_payments_state.dart';

class EkubPaymentsBloc extends Bloc<EkubPaymentsEvent, EkubPaymentsState> {
  final EkubPaymentsRepository repository;

  EkubPaymentsBloc({required this.repository}) : super(EkubPaymentsLoading()) {
    on<EkubPaymentsLoadEvent>(_onLoad);
    on<EkubPaymentsSetFilterEvent>(_onSetFilter);
  }

  void _onLoad(
    EkubPaymentsLoadEvent event,
    Emitter<EkubPaymentsState> emit,
  ) async {
    logger('EkubPaymentsBloc: Loading data (silent: ${event.isSilent})');
    if (!event.isSilent) {
      emit(EkubPaymentsLoading());
    }

    final result = await repository.getPayments();

    result.fold(
      (failure) => emit(
        EkubPaymentsFailure(failure: failure, filterIndex: 0, items: const []),
      ),
      (items) => emit(EkubPaymentsSuccess(filterIndex: 0, items: items)),
    );
  }

  void _onSetFilter(
    EkubPaymentsSetFilterEvent event,
    Emitter<EkubPaymentsState> emit,
  ) async {
    final current = state;
    if (current is EkubPaymentsSuccess) {
      if (current.filterIndex == event.filterIndex) return;
      emit(current.copyWith(filterIndex: event.filterIndex));
    } else if (current is EkubPaymentsFailure) {
      emit(
        EkubPaymentsFailure(
          failure: current.failure,
          filterIndex: event.filterIndex,
          items: current.items,
        ),
      );
    }
  }
}
