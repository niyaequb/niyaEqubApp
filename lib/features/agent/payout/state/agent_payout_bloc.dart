import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/agent/payout/data/repository/agent_payout_repository.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_event.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_state.dart';

class AgentPayoutBloc extends Bloc<AgentPayoutEvent, AgentPayoutState> {
  final AgentPayoutRepository repository;

  AgentPayoutBloc({required this.repository}) : super(AgentPayoutInitial()) {
    on<AgentPayoutLoadEvent>(_onLoad);
    on<AgentPayoutSelectFilterEvent>(_onSelectFilter);
    on<AgentPayoutRequestEvent>(_onRequest);
  }

  Future<void> _onLoad(
    AgentPayoutLoadEvent event,
    Emitter<AgentPayoutState> emit,
  ) async {
    emit(AgentPayoutLoading());

    final profileResult = await repository.fetchProfile();
    final hasBankInfo = profileResult.fold(
      (f) => false,
      (user) => repository.hasBankInfo(user),
    );

    final dashboardResult = await repository.fetchDashboard();
    final statusFilter = event.statusFilter ?? 'all';
    final statusParam = (statusFilter == 'all' || statusFilter.isEmpty)
        ? null
        : statusFilter;
    final paymentsResult = await repository.fetchPayments(status: statusParam);

    final dashboard = dashboardResult.fold((f) => null, (d) => d);
    final payments = paymentsResult.fold((f) => <AgentPayment>[], (p) => p);

    Failure? failure;
    if (dashboardResult.isLeft()) {
      failure = dashboardResult.fold((l) => l, (r) => null);
    }
    if (paymentsResult.isLeft() && failure == null) {
      failure = paymentsResult.fold((l) => l, (r) => null);
    }

    if (failure != null && dashboard == null && payments.isEmpty) {
      emit(AgentPayoutFailure(failure: failure));
      return;
    }

    emit(AgentPayoutSuccess(
      dashboard: dashboard,
      payments: payments,
      hasBankInfo: hasBankInfo,
      statusFilter: statusFilter,
    ));
  }

  Future<void> _onSelectFilter(
    AgentPayoutSelectFilterEvent event,
    Emitter<AgentPayoutState> emit,
  ) async {
    add(AgentPayoutLoadEvent(statusFilter: event.status));
  }

  Future<void> _onRequest(
    AgentPayoutRequestEvent event,
    Emitter<AgentPayoutState> emit,
  ) async {
    final current = state;
    if (current is! AgentPayoutSuccess) return;
    final statusFilter = current.statusFilter;

    emit(AgentPayoutRequestLoading());

    final result = await repository.requestPayment(event.amount);

    result.fold(
      (failure) => emit(AgentPayoutFailure(failure: failure)),
      (_) => add(AgentPayoutLoadEvent(statusFilter: statusFilter)),
    );
  }
}
