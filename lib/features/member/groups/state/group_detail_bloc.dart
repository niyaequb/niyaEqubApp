import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_event.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_state.dart';

class GroupDetailBloc extends Bloc<GroupDetailEvent, GroupDetailState> {
  final GroupEqubRepository repository;

  GroupDetailBloc({required this.repository}) : super(GroupDetailLoading()) {
    on<GroupDetailLoadEvent>(_onLoad);
    on<GroupStartEvent>(_onStart);
    on<GroupRemindUnpaidEvent>(_onRemind);
    on<GroupRunDrawEvent>(_onRunDraw);
    on<GroupRegenerateSplitPlanEvent>(_onRegeneratePlan);
    on<GroupRemoveMemberEvent>(_onRemoveMember);
  }

  /// The screen as of its last visit. Group and ledger are what the first two
  /// tabs need, so both must be cached for this to be worth showing.
  GroupDetailReady? _cachedReady(int groupId) {
    final group = repository.cachedGroup(groupId);
    final ledger = repository.cachedLedger(groupId);
    if (group == null || ledger == null) return null;

    return GroupDetailReady(
      group: group,
      ledger: ledger,
      draws: repository.cachedDraws(groupId) ?? const [],
    );
  }

  Future<void> _onLoad(GroupDetailLoadEvent event, Emitter<GroupDetailState> emit) async {
    try {
      if (!event.isSilent) {
        // Reopening a group paints instantly off disk; the network refresh
        // lands underneath a moment later.
        final cached = _cachedReady(event.groupId);
        emit(cached ?? GroupDetailLoading());
      }

      // Draws only fill the third tab, so the screen is not held back waiting
      // for them — the request goes out now and is folded in when it lands.
      final drawsFuture = repository.getDraws(event.groupId);

      final responses = await Future.wait([
        repository.getGroup(event.groupId),
        repository.getLedger(event.groupId),
      ]);

      final groupResult = responses[0] as Either<Failure, EqubCircle>;
      final ledgerResult = responses[1] as Either<Failure, GroupLedger>;

      final failure = groupResult.fold((f) => f, (_) => null) ??
          ledgerResult.fold((f) => f, (_) => null);

      if (failure != null) {
        // Keep a screen that is already showing data rather than replacing it
        // with an error on a failed background refresh.
        if (state is! GroupDetailReady) {
          emit(GroupDetailFailure(failure: failure));
        }
        return;
      }

      // Show the overview and members straight away, carrying whatever draws
      // we already had so the Rounds tab is not momentarily empty.
      final existingDraws = switch (state) {
        GroupDetailReady s => s.draws,
        _ => repository.cachedDraws(event.groupId) ?? const <GroupDraw>[],
      };

      emit(GroupDetailReady(
        group: groupResult.fold((_) => throw StateError('unreachable'), (g) => g),
        ledger: ledgerResult.fold((_) => throw StateError('unreachable'), (l) => l),
        draws: existingDraws,
      ));

      final drawsResult = await drawsFuture;
      // The user can pop the screen while this second request is still out.
      if (emit.isDone) return;

      final current = state;
      if (current is GroupDetailReady) {
        emit(current.copyWith(
          draws: drawsResult.getOrElse(() => existingDraws),
        ));
      }
    } finally {
      // Releases the pull-to-refresh spinner on every path.
      event.signal?.complete();
    }
  }

  Future<void> _onStart(GroupStartEvent event, Emitter<GroupDetailState> emit) async {
    await _runAction(
      emit,
      () => repository.startGroup(event.groupId),
      event.groupId,
    );
  }

  Future<void> _onRemind(GroupRemindUnpaidEvent event, Emitter<GroupDetailState> emit) async {
    await _runAction(
      emit,
      () => repository.remindUnpaid(event.groupId),
      event.groupId,
      reload: false,
    );
  }

  Future<void> _onRemoveMember(GroupRemoveMemberEvent event, Emitter<GroupDetailState> emit) async {
    await _runAction(
      emit,
      () => repository.removeMember(event.groupId, event.membershipId),
      event.groupId,
    );
  }

  Future<void> _onRegeneratePlan(
    GroupRegenerateSplitPlanEvent event,
    Emitter<GroupDetailState> emit,
  ) async {
    final current = state;
    if (current is! GroupDetailReady) return;

    final result = await repository.getSplitPlan(event.groupId, regenerate: true);

    emit(result.fold(
      (f) => current.copyWith(actionMessage: f.errorMessage),
      (plan) => current.copyWith(splitPlan: plan),
    ));
  }

  Future<void> _onRunDraw(GroupRunDrawEvent event, Emitter<GroupDetailState> emit) async {
    final current = state;
    if (current is! GroupDetailReady) return;

    emit(current.copyWith(isBusy: true));

    final result = await repository.runDraw(
      event.groupId,
      membershipIds: event.membershipIds,
      winnersCount: event.winnersCount,
    );

    final failure = result.fold((f) => f, (_) => null);

    if (failure != null) {
      emit(current.copyWith(isBusy: false, actionMessage: failure.errorMessage));
      return;
    }

    emit(current.copyWith(
      isBusy: false,
      lastDraw: result.fold((_) => null, (d) => d),
    ));

    add(GroupDetailLoadEvent(groupId: event.groupId, isSilent: true));
  }

  Future<void> _runAction(
    Emitter<GroupDetailState> emit,
    Future<dynamic> Function() action,
    int groupId, {
    bool reload = true,
  }) async {
    final current = state;
    if (current is! GroupDetailReady) return;

    emit(current.copyWith(isBusy: true));

    final result = await action();
    final message = result.fold((f) => f.errorMessage as String, (m) => m as String);

    emit(current.copyWith(isBusy: false, actionMessage: message));

    if (reload) {
      add(GroupDetailLoadEvent(groupId: groupId, isSilent: true));
    }
  }
}
