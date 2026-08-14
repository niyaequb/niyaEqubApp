import 'package:niya_equb/core/util/refresh_signal.dart';

abstract class GroupDetailEvent {}

class GroupDetailLoadEvent extends GroupDetailEvent {
  final int groupId;
  final bool isSilent;

  /// Set when the load came from pull-to-refresh, so the indicator can keep
  /// spinning until the request actually finishes.
  final RefreshSignal? signal;

  GroupDetailLoadEvent({
    required this.groupId,
    this.isSilent = false,
    this.signal,
  });
}

class GroupStartEvent extends GroupDetailEvent {
  final int groupId;
  GroupStartEvent({required this.groupId});
}

class GroupRemindUnpaidEvent extends GroupDetailEvent {
  final int groupId;
  GroupRemindUnpaidEvent({required this.groupId});
}

class GroupRunDrawEvent extends GroupDetailEvent {
  final int groupId;
  final List<int> membershipIds;
  final int? winnersCount;
  GroupRunDrawEvent({
    required this.groupId,
    this.membershipIds = const [],
    this.winnersCount,
  });
}

class GroupRegenerateSplitPlanEvent extends GroupDetailEvent {
  final int groupId;
  GroupRegenerateSplitPlanEvent({required this.groupId});
}

class GroupRemoveMemberEvent extends GroupDetailEvent {
  final int groupId;
  final int membershipId;
  GroupRemoveMemberEvent({required this.groupId, required this.membershipId});
}
