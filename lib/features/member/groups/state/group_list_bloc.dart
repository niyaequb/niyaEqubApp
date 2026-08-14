import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/state/group_list_event.dart';
import 'package:niya_equb/features/member/groups/state/group_list_state.dart';

class GroupListBloc extends Bloc<GroupListEvent, GroupListState> {
  final GroupEqubRepository repository;

  GroupListBloc({required this.repository}) : super(GroupListLoading()) {
    on<GroupListLoadEvent>(_onLoad);
    on<GroupJoinEvent>(_onJoin);
    on<GroupInvitationRespondEvent>(_onRespond);
  }

  Future<void> _onJoin(GroupJoinEvent event, Emitter<GroupListState> emit) async {
    final result = await repository.joinByCode(event.code);
    final message = result.fold((f) => f.errorMessage, (m) => m);

    final responses = await Future.wait([
      repository.getMyGroups(),
      repository.getMyInvitations(),
    ]);

    emit(GroupListSuccess(
      groups: (responses[0] as Either<Failure, List<EqubCircle>>)
          .getOrElse(() => const []),
      invitations: (responses[1] as Either<Failure, List<EqubInvitation>>)
          .getOrElse(() => const []),
      actionMessage: message,
    ));
  }

  Future<void> _onLoad(GroupListLoadEvent event, Emitter<GroupListState> emit) async {
    try {
      if (!event.isSilent) {
        // Open on the last known list rather than a spinner; the fresh copy
        // lands a moment later.
        final cachedGroups = repository.cachedMyGroups();
        final cachedInvites = repository.cachedMyInvitations();

        if (cachedGroups != null) {
          emit(GroupListSuccess(
            groups: cachedGroups,
            invitations: cachedInvites ?? const [],
          ));
        } else {
          emit(GroupListLoading());
        }
      }

      // Two independent endpoints, so they go out together instead of one
      // after the other.
      final responses = await Future.wait([
        repository.getMyGroups(),
        repository.getMyInvitations(),
      ]);

      final groupsResult = responses[0] as Either<Failure, List<EqubCircle>>;
      final invitesResult = responses[1] as Either<Failure, List<EqubInvitation>>;

      final failure = groupsResult.fold((f) => f, (_) => null);
      if (failure != null) {
        // A failed background refresh must not blank a screen that is already
        // showing cached groups.
        if (state is! GroupListSuccess) {
          emit(GroupListFailure(failure: failure));
        }
        return;
      }

      emit(GroupListSuccess(
        groups: groupsResult.getOrElse(() => const []),
        invitations: invitesResult.getOrElse(() => const []),
      ));

      // Warms the New Group Equb picker while the user reads this screen, so
      // tapping Create group opens on content rather than a spinner. Cheap,
      // and it only ever fills the cache.
      unawaited(repository.getJoinableEqubs());
    } finally {
      // Releases the pull-to-refresh spinner on every path.
      event.signal?.complete();
    }
  }

  Future<void> _onRespond(
    GroupInvitationRespondEvent event,
    Emitter<GroupListState> emit,
  ) async {
    final result = await repository.respondToInvitation(
      event.invitationId,
      accept: event.accept,
    );

    final message = result.fold((f) => f.errorMessage, (m) => m);

    final responses = await Future.wait([
      repository.getMyGroups(),
      repository.getMyInvitations(),
    ]);

    emit(GroupListSuccess(
      groups: (responses[0] as Either<Failure, List<EqubCircle>>)
          .getOrElse(() => const []),
      invitations: (responses[1] as Either<Failure, List<EqubInvitation>>)
          .getOrElse(() => const []),
      actionMessage: message,
    ));
  }
}
