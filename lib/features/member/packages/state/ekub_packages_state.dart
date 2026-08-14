import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';

const _sentinel = Object();

abstract class EkubPackagesState extends Equatable {}

class EkubPackagesLoading extends EkubPackagesState {
  @override
  List<Object?> get props => [];
}

class EkubPackagesSuccess extends EkubPackagesState {
  final List<EqubPackage> packages;
  final List<EqubGroup> groups;
  final List<EqubMembership> memberships;

  /// null = All (default selected)
  final int? selectedPackageId;
  final String? joiningGroupId;
  final bool joinSuccess;
  final bool isLoadingGroups;
  final Map<int, Map<String, dynamic>> activeDraws;

  EkubPackagesSuccess({
    required this.packages,
    required this.groups,
    this.memberships = const [],
    this.selectedPackageId,
    this.joiningGroupId,
    this.joinSuccess = false,
    this.isLoadingGroups = false,
    this.activeDraws = const {},
  });

  List<EqubGroup> get filteredGroups {
    if (selectedPackageId == null) return groups;
    return groups.where((g) => g.packageId == selectedPackageId).toList();
  }

  EkubPackagesSuccess copyWith({
    List<EqubPackage>? packages,
    List<EqubGroup>? groups,
    List<EqubMembership>? memberships,
    Object? selectedPackageId = _sentinel,
    Object? joiningGroupId = _sentinel,
    bool? joinSuccess,
    bool? isLoadingGroups,
    Map<int, Map<String, dynamic>>? activeDraws,
  }) {
    return EkubPackagesSuccess(
      packages: packages ?? this.packages,
      groups: groups ?? this.groups,
      memberships: memberships ?? this.memberships,
      selectedPackageId: identical(selectedPackageId, _sentinel)
          ? this.selectedPackageId
          : selectedPackageId as int?,
      joiningGroupId: identical(joiningGroupId, _sentinel)
          ? this.joiningGroupId
          : joiningGroupId as String?,
      joinSuccess: joinSuccess ?? this.joinSuccess,
      isLoadingGroups: isLoadingGroups ?? this.isLoadingGroups,
      activeDraws: activeDraws ?? this.activeDraws,
    );
  }

  @override
  List<Object?> get props => [
    packages,
    groups,
    memberships,
    selectedPackageId,
    joiningGroupId,
    joinSuccess,
    isLoadingGroups,
    activeDraws,
  ];
}

class EkubPackagesFailure extends EkubPackagesState {
  final Failure failure;
  final List<EqubPackage> packages;
  final List<EqubGroup> groups;
  final List<EqubMembership> memberships;
  final int? selectedPackageId;
  final String? joiningGroupId;
  final bool joinSuccess;
  final Map<int, Map<String, dynamic>> activeDraws;

  EkubPackagesFailure({
    required this.failure,
    required this.packages,
    required this.groups,
    this.memberships = const [],
    this.selectedPackageId,
    this.joiningGroupId,
    this.joinSuccess = false,
    this.activeDraws = const {},
  });

  List<EqubGroup> get filteredGroups {
    if (selectedPackageId == null) return groups;
    return groups.where((g) => g.packageId == selectedPackageId).toList();
  }

  EkubPackagesFailure copyWith({
    Failure? failure,
    List<EqubPackage>? packages,
    List<EqubGroup>? groups,
    List<EqubMembership>? memberships,
    Object? selectedPackageId = _sentinel,
    Object? joiningGroupId = _sentinel,
    bool? joinSuccess,
    Map<int, Map<String, dynamic>>? activeDraws,
  }) {
    return EkubPackagesFailure(
      failure: failure ?? this.failure,
      packages: packages ?? this.packages,
      groups: groups ?? this.groups,
      memberships: memberships ?? this.memberships,
      selectedPackageId: identical(selectedPackageId, _sentinel)
          ? this.selectedPackageId
          : selectedPackageId as int?,
      joiningGroupId: identical(joiningGroupId, _sentinel)
          ? this.joiningGroupId
          : joiningGroupId as String?,
      joinSuccess: joinSuccess ?? this.joinSuccess,
      activeDraws: activeDraws ?? this.activeDraws,
    );
  }

  @override
  List<Object?> get props => [
    failure,
    packages,
    groups,
    memberships,
    selectedPackageId,
    joiningGroupId,
    joinSuccess,
    activeDraws,
  ];
}
