import 'package:niya_equb/core/util/refresh_signal.dart';

abstract class EkubHomeEvent {}

class EkubHomeLoadEvent extends EkubHomeEvent {
  final bool isSilent;

  /// Set when the load came from pull-to-refresh, so the indicator can keep
  /// spinning until the request actually finishes.
  final RefreshSignal? signal;

  EkubHomeLoadEvent({this.isSilent = false, this.signal});
}

class EkubHomeDrawUpdateEvent extends EkubHomeEvent {
  final int groupId;
  final String type;
  final String? winnerName;
  final List<String>? candidates;

  EkubHomeDrawUpdateEvent({
    required this.groupId,
    required this.type,
    this.winnerName,
    this.candidates,
  });
}
