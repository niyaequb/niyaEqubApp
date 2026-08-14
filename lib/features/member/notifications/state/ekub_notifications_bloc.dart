import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/notifications/data/repository/ekub_notifications_repository.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_event.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_state.dart';

class EkubNotificationsBloc
    extends Bloc<EkubNotificationsEvent, EkubNotificationsState> {
  final EkubNotificationsRepository repository;

  EkubNotificationsBloc({required this.repository})
    : super(EkubNotificationsLoading()) {
    on<EkubNotificationsLoadEvent>(_onLoad);
  }

  void _onLoad(
    EkubNotificationsLoadEvent event,
    Emitter<EkubNotificationsState> emit,
  ) async {
    logger('EkubNotificationsBloc: Loading data (silent: ${event.isSilent})');
    if (!event.isSilent) {
      emit(EkubNotificationsLoading());
    }
    try {
      emit(EkubNotificationsSuccess(items: repository.getNotifications()));
    } catch (e) {
      emit(
        EkubNotificationsFailure(
          failure: ServerFailure(e.toString(), null),
          items: const [],
        ),
      );
    }
  }
}
