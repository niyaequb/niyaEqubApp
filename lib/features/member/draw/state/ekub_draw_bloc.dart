import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/draw/data/repository/ekub_draw_repository.dart';
import 'package:niya_equb/features/member/draw/state/ekub_draw_event.dart';
import 'package:niya_equb/features/member/draw/state/ekub_draw_state.dart';

class EkubDrawBloc extends Bloc<EkubDrawEvent, EkubDrawState> {
  final EkubDrawRepository repository;

  EkubDrawBloc({required this.repository}) : super(EkubDrawLoading()) {
    on<EkubDrawLoadEvent>(_onLoad);
  }

  void _onLoad(EkubDrawLoadEvent event, Emitter<EkubDrawState> emit) async {
    logger('EkubDrawBloc: Loading data (silent: ${event.isSilent})');
    if (!event.isSilent) {
      emit(EkubDrawLoading());
    }
    final result = await repository.fetchDrawData();
    result.fold(
      (failure) => emit(
        EkubDrawFailure(
          failure: failure,
          categories: const [],
          winners: const [],
        ),
      ),
      (data) => emit(
        EkubDrawSuccess(
          categories: data['categories'] as List<EkubDrawCategory>,
          winners: data['winners'] as List<EkubWinner>,
        ),
      ),
    );
  }
}
