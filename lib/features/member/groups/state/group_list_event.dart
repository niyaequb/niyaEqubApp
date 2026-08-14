import 'package:niya_equb/core/util/refresh_signal.dart';

abstract class GroupListEvent {}

class GroupListLoadEvent extends GroupListEvent {
  final bool isSilent;

  /// Set when the load came from pull-to-refresh, so the indicator can keep
  /// spinning until the request actually finishes.
  final RefreshSignal? signal;

  GroupListLoadEvent({this.isSilent = false, this.signal});
}

class GroupJoinEvent extends GroupListEvent {
  final String code;
  GroupJoinEvent({required this.code});
}

class GroupInvitationRespondEvent extends GroupListEvent {
  final int invitationId;
  final bool accept;
  GroupInvitationRespondEvent({required this.invitationId, required this.accept});
}
