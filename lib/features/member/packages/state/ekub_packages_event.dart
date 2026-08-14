import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';

abstract class EkubPackagesEvent {}

class EkubPackagesLoadEvent extends EkubPackagesEvent {
  final bool isSilent;

  /// Set when the load came from pull-to-refresh, so the indicator can keep
  /// spinning until the data is actually in.
  final RefreshSignal? signal;

  EkubPackagesLoadEvent({this.isSilent = false, this.signal});
}

class EkubPackagesSelectFilterEvent extends EkubPackagesEvent {
  /// null = All (default)
  final int? packageId;

  EkubPackagesSelectFilterEvent({this.packageId});
}

class EkubPackagesJoinGroupEvent extends EkubPackagesEvent {
  final EqubGroup group;

  EkubPackagesJoinGroupEvent({required this.group});
}

class EkubPackagesDrawUpdateEvent extends EkubPackagesEvent {
  final int groupId;
  final String type;
  final String? winnerName;
  final List<String>? candidates;

  EkubPackagesDrawUpdateEvent({
    required this.groupId,
    required this.type,
    this.winnerName,
    this.candidates,
  });
}
