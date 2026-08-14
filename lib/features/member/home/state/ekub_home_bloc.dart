import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/home/data/repository/ekub_home_repository.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_event.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_state.dart';
import 'package:niya_equb/features/member/home/models/home_promotions.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';

class EkubHomeBloc extends Bloc<EkubHomeEvent, EkubHomeState> {
  final EkubHomeRepository repository;
  final EkubPackagesRepository packagesRepository;

  StreamSubscription? _notificationSubscription;

  EkubHomeBloc({required this.repository, required this.packagesRepository, required NotificationService notificationService})
    : super(EkubHomeSuccess(user: null, data: EkubHomeData(totalSaved: 0, activePackageLabel: '', activePackageDurationLabel: '', todayDueLabel: '', todayDueSubtitle: '', nextDrawLabel: '', nextDrawSubtitle: '', referralCode: '', activities: []))) {
    on<EkubHomeLoadEvent>(_onLoad);
    on<EkubHomeDrawUpdateEvent>(_onDrawUpdate);

    _notificationSubscription = notificationService.messageStream.listen((message) {
      final groupId = message.data['equb_group_id'];
      final type = message.data['type'];
      final id = groupId != null ? int.tryParse(groupId.toString()) : null;

      if (id != null && (type == 'equb_draw_started' || type == 'equb_draw_completed')) {
        final candidates = _extractCandidates(message.data['member_names']);
        add(EkubHomeDrawUpdateEvent(
          groupId: id,
          type: type!,
          winnerName: message.data['winner_name'] ?? message.data['winner_membership_id'],
          candidates: candidates,
        ));
      }
    });
  }

  List<String> _extractCandidates(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Total contributed so far, summed from the payments on each membership.
  EkubHomeData _buildData(List<EqubMembership> memberships) {
    final base = repository.getHomeData();

    double total = 0;
    for (final m in memberships) {
      for (final p in m.payments ?? const <EqubPayment>[]) {
        if (p.isPaid == true) total += (p.amount ?? 0);
      }
    }

    return EkubHomeData(
      totalSaved: total.toInt(),
      // The rest are placeholders until the API exposes them.
      activePackageLabel: base.activePackageLabel,
      activePackageDurationLabel: base.activePackageDurationLabel,
      todayDueLabel: base.todayDueLabel,
      todayDueSubtitle: base.todayDueSubtitle,
      nextDrawLabel: base.nextDrawLabel,
      nextDrawSubtitle: base.nextDrawSubtitle,
      referralCode: base.referralCode,
      activities: const [],
    );
  }

  /// Keeps the top of the home screen populated when the API returns nothing.
  HomePromotions _withFallbacks(HomePromotions promotions) {
    final facts = promotions.companyFacts.isNotEmpty
        ? promotions.companyFacts
        : [
            CompanyFact(id: 1, label: 'Members'.tr, value: '10k+'),
            CompanyFact(id: 2, label: 'Founded'.tr, value: '2022'),
            CompanyFact(id: 3, label: 'Verified'.tr, value: '100%'),
          ];

    if (promotions.banners.isNotEmpty) {
      return HomePromotions(banners: promotions.banners, companyFacts: facts);
    }

    return HomePromotions(
      banners: [
        EqubBanner(
          id: 1,
          title: 'Welcome to Niya Equb',
          subtitle: 'Start your journey to Umrah with our flexible savings plans.',
          imageUrl: '',
        ),
        EqubBanner(
          id: 2,
          title: 'Invite Friends & Earn',
          subtitle: 'Share your referral code and get rewards for every successful join.',
          imageUrl: '',
        ),
        EqubBanner(
          id: 3,
          title: 'Secured Payments',
          subtitle: 'Your contributions are safe and secured with our trusted partners.',
          imageUrl: '',
        ),
      ],
      companyFacts: facts,
    );
  }

  void _onLoad(EkubHomeLoadEvent event, Emitter<EkubHomeState> emit) async {
    logger('EkubHomeBloc: Loading data (silent: ${event.isSilent})');

    try {
      if (!event.isSilent) {
        // Paint the last known home screen first; the network refresh replaces
        // it a moment later instead of holding a spinner.
        final cachedMemberships = packagesRepository.cachedEqubMemberships();
        final cachedPromotions = repository.cachedPromotions();

        if (cachedMemberships != null || cachedPromotions != null) {
          final memberships = cachedMemberships ?? const <EqubMembership>[];
          emit(
            EkubHomeSuccess(
              user: repository.getCachedUser(),
              data: _buildData(memberships),
              memberships: memberships,
              promotions: _withFallbacks(cachedPromotions ?? HomePromotions()),
            ),
          );
        } else {
          emit(EkubHomeLoading());
        }
      }

      final user = repository.getCachedUser();

      // Both requests are started before either is awaited, so they overlap.
      final membershipsFuture = packagesRepository.fetchEqubMemberships();
      final promotionsFuture = repository.fetchPromotions();

      final membershipsResult = await membershipsFuture;
      final promotionsResult = await promotionsFuture;

      final memberships = membershipsResult.fold(
        (failure) => <EqubMembership>[],
        (list) => list,
      );

      final promotions = _withFallbacks(
        promotionsResult.fold((failure) => HomePromotions(), (p) => p),
      );

      emit(
        EkubHomeSuccess(
          user: user,
          data: _buildData(memberships),
          memberships: memberships,
          promotions: promotions,
        ),
      );
    } catch (e) {
      emit(
        EkubHomeFailure(
          failure: ServerFailure(e.toString(), null),
          user: repository.getCachedUser(),
          data: null,
          memberships: const [],
        ),
      );
    } finally {
      // Releases the pull-to-refresh spinner on every path.
      event.signal?.complete();
    }
  }

  void _onDrawUpdate(
    EkubHomeDrawUpdateEvent event,
    Emitter<EkubHomeState> emit,
  ) {
    final current = state;
    Map<int, Map<String, dynamic>> updatedDraws = {};
    if (current is EkubHomeSuccess) {
      updatedDraws = Map<int, Map<String, dynamic>>.from(current.activeDraws);
    } else if (current is EkubHomeFailure) {
      updatedDraws = Map<int, Map<String, dynamic>>.from(current.activeDraws);
    }

    if (event.type == 'equb_draw_started') {
      updatedDraws[event.groupId] = {
        'type': event.type,
        'winnerName': event.winnerName,
        'candidates': event.candidates,
        'timestamp': DateTime.now(),
      };
    } else if (event.type == 'equb_draw_completed') {
      updatedDraws.remove(event.groupId);
    }

    if (current is EkubHomeSuccess) {
      emit(current.copyWith(activeDraws: updatedDraws));
    } else if (current is EkubHomeFailure) {
      emit(current.copyWith(activeDraws: updatedDraws));
    }
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    return super.close();
  }
}
