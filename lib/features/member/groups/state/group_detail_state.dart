import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';

abstract class GroupDetailState extends Equatable {}

class GroupDetailLoading extends GroupDetailState {
  @override
  List<Object?> get props => [];
}

class GroupDetailReady extends GroupDetailState {
  final EqubCircle group;
  final GroupLedger ledger;
  final List<GroupDraw> draws;
  final SplitPlanPreview? splitPlan;

  /// True while a start / draw / reminder call is in flight.
  final bool isBusy;

  /// One-shot feedback for the screen (snackbar), cleared on the next load.
  final String? actionMessage;
  final GroupDraw? lastDraw;

  GroupDetailReady({
    required this.group,
    required this.ledger,
    required this.draws,
    this.splitPlan,
    this.isBusy = false,
    this.actionMessage,
    this.lastDraw,
  });

  GroupDetailReady copyWith({
    EqubCircle? group,
    GroupLedger? ledger,
    List<GroupDraw>? draws,
    SplitPlanPreview? splitPlan,
    bool? isBusy,
    String? actionMessage,
    GroupDraw? lastDraw,
  }) {
    return GroupDetailReady(
      group: group ?? this.group,
      ledger: ledger ?? this.ledger,
      draws: draws ?? this.draws,
      splitPlan: splitPlan ?? this.splitPlan,
      isBusy: isBusy ?? this.isBusy,
      actionMessage: actionMessage,
      lastDraw: lastDraw ?? this.lastDraw,
    );
  }

  @override
  List<Object?> get props => [group, ledger, draws, splitPlan, isBusy, actionMessage, lastDraw];
}

class GroupDetailFailure extends GroupDetailState {
  final Failure failure;
  GroupDetailFailure({required this.failure});

  @override
  List<Object?> get props => [failure];
}
