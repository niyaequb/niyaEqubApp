import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/notifications/data/repository/ekub_notifications_repository.dart';

abstract class EkubNotificationsState extends Equatable {}

class EkubNotificationsLoading extends EkubNotificationsState {
  @override
  List<Object?> get props => [];
}

class EkubNotificationsSuccess extends EkubNotificationsState {
  final List<EkubNotificationItem> items;

  EkubNotificationsSuccess({required this.items});

  @override
  List<Object?> get props => [items];
}

class EkubNotificationsFailure extends EkubNotificationsState {
  final Failure failure;
  final List<EkubNotificationItem> items;

  EkubNotificationsFailure({required this.failure, required this.items});

  @override
  List<Object?> get props => [failure, items];
}
