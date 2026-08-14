import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';

abstract class GroupListState extends Equatable {}

class GroupListLoading extends GroupListState {
  @override
  List<Object?> get props => [];
}

class GroupListSuccess extends GroupListState {
  final List<EqubCircle> groups;
  final List<EqubInvitation> invitations;

  /// Set after accepting or declining an invitation, so the screen can show a
  /// confirmation without reloading into a spinner.
  final String? actionMessage;

  GroupListSuccess({
    required this.groups,
    required this.invitations,
    this.actionMessage,
  });

  @override
  List<Object?> get props => [groups, invitations, actionMessage];
}

class GroupListFailure extends GroupListState {
  final Failure failure;
  GroupListFailure({required this.failure});

  @override
  List<Object?> get props => [failure];
}
