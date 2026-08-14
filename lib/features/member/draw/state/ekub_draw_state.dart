import 'package:equatable/equatable.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/draw/data/repository/ekub_draw_repository.dart';

abstract class EkubDrawState extends Equatable {}

class EkubDrawLoading extends EkubDrawState {
  @override
  List<Object?> get props => [];
}

class EkubDrawSuccess extends EkubDrawState {
  final List<EkubDrawCategory> categories;
  final List<EkubWinner> winners;

  EkubDrawSuccess({required this.categories, required this.winners});

  @override
  List<Object?> get props => [categories, winners];
}

class EkubDrawFailure extends EkubDrawState {
  final Failure failure;
  final List<EkubDrawCategory> categories;
  final List<EkubWinner> winners;

  EkubDrawFailure({
    required this.failure,
    required this.categories,
    required this.winners,
  });

  @override
  List<Object?> get props => [failure, categories, winners];
}
