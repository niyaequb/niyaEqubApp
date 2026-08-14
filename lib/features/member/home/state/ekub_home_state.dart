import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:niya_equb/features/member/home/data/repository/ekub_home_repository.dart';
import 'package:niya_equb/features/member/home/models/home_promotions.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';

abstract class EkubHomeState extends Equatable {}

class EkubHomeLoading extends EkubHomeState {
  @override
  List<Object?> get props => [];
}

class EkubHomeSuccess extends EkubHomeState {
  final UserModel? user;
  final EkubHomeData data;
  final List<EqubMembership> memberships;
  final Map<int, Map<String, dynamic>> activeDraws;
  final HomePromotions? promotions;

  EkubHomeSuccess({
    required this.user,
    required this.data,
    this.memberships = const [],
    this.activeDraws = const {},
    this.promotions,
  });

  EkubHomeSuccess copyWith({
    UserModel? user,
    EkubHomeData? data,
    List<EqubMembership>? memberships,
    Map<int, Map<String, dynamic>>? activeDraws,
    HomePromotions? promotions,
  }) {
    return EkubHomeSuccess(
      user: user ?? this.user,
      data: data ?? this.data,
      memberships: memberships ?? this.memberships,
      activeDraws: activeDraws ?? this.activeDraws,
      promotions: promotions ?? this.promotions,
    );
  }

  @override
  List<Object?> get props => [user, data, memberships, activeDraws, promotions];
}

class EkubHomeFailure extends EkubHomeState {
  final Failure failure;
  final UserModel? user;
  final EkubHomeData? data;
  final List<EqubMembership> memberships;
  final Map<int, Map<String, dynamic>> activeDraws;
  final HomePromotions? promotions;

  EkubHomeFailure({
    required this.failure,
    required this.user,
    required this.data,
    this.memberships = const [],
    this.activeDraws = const {},
    this.promotions,
  });

  EkubHomeFailure copyWith({
    Failure? failure,
    UserModel? user,
    EkubHomeData? data,
    List<EqubMembership>? memberships,
    Map<int, Map<String, dynamic>>? activeDraws,
    HomePromotions? promotions,
  }) {
    return EkubHomeFailure(
      failure: failure ?? this.failure,
      user: user ?? this.user,
      data: data ?? this.data,
      memberships: memberships ?? this.memberships,
      activeDraws: activeDraws ?? this.activeDraws,
      promotions: promotions ?? this.promotions,
    );
  }

  @override
  List<Object?> get props => [failure, user, data, memberships, activeDraws, promotions];
}
