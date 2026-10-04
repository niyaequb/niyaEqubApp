import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_event.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_state.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';

class EqubDetailBloc extends Bloc<EqubDetailEvent, EqubDetailState> {
  final EkubPackagesRepository repository;

  // Persistent flags to catch events during loading
  bool _isDrawing = false;
  String? _winnerName;
  List<String> _candidates = [];
  Timer? _drawTimer;

  EqubDetailBloc({required this.repository}) : super(EqubDetailInitial()) {
    on<EqubDetailLoadEvent>(_onLoad);
    on<EqubDetailInitiatePaymentEvent>(_onInitiatePayment);
    on<EqubDetailInitiateBatchPaymentEvent>(_onInitiateBatchPayment);
    on<EqubDetailDrawStartedEvent>(_onDrawStarted);
    on<EqubDetailDrawCompletedEvent>(_onDrawCompleted);
    on<EqubDetailDrawTimeoutEvent>(_onDrawTimeout);
    on<EqubDetailLeaveEvent>(_onLeave);
  }

  Future<void> _onLeave(
    EqubDetailLeaveEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    emit(EqubDetailLeaveLoading());
    final result = await repository.leaveEqub(event.membershipId);
    result.fold(
      (failure) => emit(EqubDetailLeaveFailure(failure)),
      (_) => emit(EqubDetailLeaveSuccess()),
    );
  }

  Future<void> _onLoad(
    EqubDetailLoadEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    logger('EqubDetailBloc: Loading data (silent: ${event.isSilent})');
    if (!event.isSilent) {
      emit(EqubDetailLoading());
    }

    final detailFuture = repository.fetchEqubGroupDetail(event.groupId);
    final rateFuture = repository.fetchExchangeRate();
    final activeDataFuture = PreferencesService.getActiveDraw(event.groupId);

    final detailResult = await detailFuture;
    final rateResult = await rateFuture;
    final activeData = await activeDataFuture;

    double? exchangeRate;
    rateResult.fold((_) {}, (r) => exchangeRate = r);

    detailResult.fold((failure) => emit(EqubDetailFailure(failure)), (group) {
      // Extract payments and draws from the first membership
      final membership =
          (group.memberships != null && group.memberships!.isNotEmpty)
          ? group.memberships!.first
          : null;

      final payments = membership?.payments ?? <EqubPayment>[];

      // Calculate schedule
      List<PaymentScheduleItem> schedule = [];
      if (membership?.paymentSchedule != null &&
          membership!.paymentSchedule!.isNotEmpty) {
        schedule = membership.paymentSchedule!.map((e) {
          final date = DateTime.tryParse(e.expectedDate ?? '');
          final now = DateTime.now();
          PaymentScheduleStatus status = PaymentScheduleStatus.pending;

          if (e.status?.toLowerCase() == 'paid') {
            status = PaymentScheduleStatus.paid;
          } else if (date != null) {
            final dateYMD = DateTime(date.year, date.month, date.day);
            final nowYMD = DateTime(now.year, now.month, now.day);
            if (dateYMD.isBefore(nowYMD)) {
              status = PaymentScheduleStatus.unpaid;
            } else if (dateYMD.isAfter(nowYMD)) {
              status = PaymentScheduleStatus.future;
            }
          }

          return PaymentScheduleItem(
            index: e.round ?? 0,
            dueDate: date ?? DateTime.now(),
            amount: e.amount ?? 0.0,
            status: status,
          );
        }).toList();
      } else if (group.equbStartDate != null && group.birrPerDay != null) {
        // Fallback to manual calculation if API doesn't provide schedule
        DateTime? startDate;
        if (group.equbStartDate != null && group.equbStartDate!.length >= 10) {
          startDate = DateTime.parse(group.equbStartDate!.substring(0, 10));
        }

        DateTime? endDate;
        if (group.equbEndDate != null && group.equbEndDate!.length >= 10) {
          endDate = DateTime.parse(group.equbEndDate!.substring(0, 10));
        }
        // default frequency to 1 if not parsed correctly
        final freq = int.tryParse(
          group.contributionFrequencyDays ??
              group.package?.contributionFrequencyDays ??
              '1',
        );

        if (startDate != null) {
          schedule = PaymentCalculator.generateSchedule(
            startDate: startDate,
            endDate: endDate,
            frequencyDays: freq,
            amount: group.birrPerDay!.toDouble(),
            payments: payments,
          );
        }
      }

      // Handling draws
      final draws = <EqubDraw>[];
      if (group.memberships != null) {
        for (final m in group.memberships!) {
          if (m.drawInfo != null) {
            draws.add(m.drawInfo!);
          }
        }
      }

      bool isCurrentlyDrawing = _isDrawing;
      List<String> currentCandidates = _candidates;
      if (activeData != null) {
        isCurrentlyDrawing = true;
        currentCandidates = activeData['candidates'] as List<String>;
        // Sync internal tracking state to prevent resets on transient UI actions
        _isDrawing = true;
        _candidates = currentCandidates;

        // Start safety timer for manual navigation based on remaining time
        final startTime = activeData['time'] as DateTime;
        final elapsed = DateTime.now().toUtc().difference(startTime);
        final remaining = const Duration(minutes: 1) - elapsed;

        if (remaining.inSeconds > 0) {
          _drawTimer?.cancel();
          _drawTimer = Timer(remaining, () {
            add(const EqubDetailDrawTimeoutEvent());
          });
          logger(
            "EqubDetailBloc: Started draw timer for manual navigation. Remaining: ${remaining.inSeconds}s",
          );
        }
      }

      emit(
        EqubDetailSuccess(
          groupId: event.groupId,
          group: group,
          payments: payments,
          draws: draws,
          schedule: schedule,
          isDrawing: isCurrentlyDrawing,
          winnerName: _winnerName,
          candidates: currentCandidates,
          exchangeRate: exchangeRate,
        ),
      );
    });
  }

  Future<void> _onInitiatePayment(
    EqubDetailInitiatePaymentEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    emit(EqubDetailPaymentLoading());

    final provider = await _resolveProvider(event.provider, event, emit);
    if (provider == null) return;

    final result = await repository.initiateEqubPayment(
      membershipId: event.membershipId,
      amount: event.amount,
      paymentDate: event.paymentDate,
      provider: provider,
    );

    result.fold(
      (failure) => emit(EqubDetailPaymentFailure(failure)),
      (session) => emit(EqubDetailPaymentSuccess(session)),
    );
  }

  /// Settles every place the member pays for in one charge.
  ///
  /// No amount is sent: the server prices each place from its own membership,
  /// so the total shown on the confirmation screen and the total actually
  /// charged come from the same source and cannot drift apart.
  Future<void> _onInitiateBatchPayment(
    EqubDetailInitiateBatchPaymentEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    emit(EqubDetailPaymentLoading());

    final provider = await _resolveProvider(event.provider, event, emit);
    if (provider == null) return;

    final result = await repository.initiateBatchEqubPayment(
      membershipIds: event.membershipIds,
      paymentDate: event.paymentDate,
      provider: provider,
    );

    result.fold(
      (failure) => emit(EqubDetailPaymentFailure(failure)),
      (session) => emit(EqubDetailPaymentSuccess(session)),
    );
  }

  /// Decide which bank this payment goes through.
  ///
  /// Returns null when the caller must stop — either because something has
  /// already been emitted explaining why, or because the member is being asked
  /// to choose and will re-dispatch the same event with their answer.
  ///
  /// The client never holds a list of banks of its own. Asking the server on
  /// each attempt is what lets a bank be added or withdrawn without an app
  /// release.
  Future<String?> _resolveProvider(
    String? chosen,
    EqubDetailEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    if (chosen != null && chosen.isNotEmpty) return chosen;

    final result = await repository.fetchPaymentProviders();

    return result.fold(
      (failure) {
        emit(EqubDetailPaymentFailure(failure));
        return null;
      },
      (banks) {
        // A provider whose slug is empty cannot be paid through. The slug IS
        // the `payment_method` the server validates against, so offering one
        // guarantees a rejection — and it arrives AFTER the member has picked
        // a date and committed to paying, as a flat "the selected payment
        // method is invalid" they can do nothing about.
        //
        // PaymentClientConfig.fromJson degrades a missing slug to '' rather
        // than failing, which is the right call for parsing and the wrong one
        // for offering. Filtered here, where the list stops being data and
        // becomes a choice.
        banks = banks
            .where((bank) => bank.slug.trim().isNotEmpty)
            .toList(growable: false);

        if (banks.isEmpty) {
          // No bank is configured, so there is nothing to charge through. Said
          // plainly rather than left as an empty picker the member cannot act
          // on.
          // Not const: ServerFailure has no const constructor.
          emit(
            EqubDetailPaymentFailure(
              ServerFailure('no_payment_banks_available', null),
            ),
          );
          return null;
        }

        if (banks.length == 1) return banks.first.slug;

        // More than one: the member chooses. The event travels with the state
        // so the second attempt is byte-for-byte the one they confirmed.
        emit(EqubDetailPaymentChooseBank(banks, event));
        return null;
      },
    );
  }

  void _onDrawStarted(
    EqubDetailDrawStartedEvent event,
    Emitter<EqubDetailState> emit,
  ) {
    logger(
      "EqubDetailBloc: Handling DrawStartedEvent. Current state type: ${state.runtimeType}",
    );
    _isDrawing = true;
    _winnerName = null;
    _candidates = event.candidates;

    // Start a 1-minute safety timer
    _drawTimer?.cancel();
    _drawTimer = Timer(const Duration(minutes: 1), () {
      add(const EqubDetailDrawTimeoutEvent());
    });

    if (state is EqubDetailSuccess) {
      logger(
        "EqubDetailBloc: Setting isDrawing to true and passing ${event.candidates.length} candidates",
      );
      emit(
        (state as EqubDetailSuccess).copyWith(
          isDrawing: true,
          winnerName: null,
          candidates: event.candidates,
        ),
      );
    } else {
      logger(
        "EqubDetailBloc: Cache DrawStarted flag and ${event.candidates.length} candidates (State is ${state.runtimeType})",
      );
    }
  }

  Future<void> _onDrawCompleted(
    EqubDetailDrawCompletedEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    logger(
      "EqubDetailBloc: Handling DrawCompletedEvent for ${event.winnerName}. Current state type: ${state.runtimeType}",
    );
    _isDrawing = false;
    _winnerName = event.winnerName;

    // Cancel safety timer
    _drawTimer?.cancel();
    _drawTimer = null;

    // Clear persistence when draw completes
    if (state is EqubDetailSuccess) {
      await PreferencesService.clearActiveDraw(
        (state as EqubDetailSuccess).group.id!,
      );
    }

    if (state is EqubDetailSuccess) {
      final currentState = state as EqubDetailSuccess;
      logger(
        "EqubDetailBloc: Setting isDrawing to false and winnerName to ${event.winnerName}",
      );
      emit(
        currentState.copyWith(isDrawing: false, winnerName: event.winnerName),
      );

      // Auto-refresh data after a long delay to show the "Won" status definitively from server
      logger("EqubDetailBloc: Refreshing data in 10 seconds...");
      await Future.delayed(const Duration(seconds: 10));

      // Clear persistence after refresh
      _winnerName = null;
      add(EqubDetailLoadEvent(currentState.group.id!, isSilent: true));
    } else {
      logger(
        "EqubDetailBloc: Cache DrawCompleted flag (Winner: ${event.winnerName})",
      );
    }
  }

  Future<void> _onDrawTimeout(
    EqubDetailDrawTimeoutEvent event,
    Emitter<EqubDetailState> emit,
  ) async {
    logger(
      "EqubDetailBloc: Draw safety timeout reached (1 minute). Resetting state and refreshing...",
    );
    _isDrawing = false;
    _candidates = [];
    _drawTimer = null;

    if (state is EqubDetailSuccess) {
      final currentState = (state as EqubDetailSuccess);
      emit(currentState.copyWith(isDrawing: false));
      // Clear persistence as well
      await PreferencesService.clearActiveDraw(currentState.group.id!);
      add(EqubDetailLoadEvent(currentState.group.id!, isSilent: true));
    }
  }

  @override
  Future<void> close() {
    _drawTimer?.cancel();
    return super.close();
  }
}
