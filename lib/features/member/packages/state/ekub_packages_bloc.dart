import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_event.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_state.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'dart:async';
import 'dart:convert';

class EkubPackagesBloc extends Bloc<EkubPackagesEvent, EkubPackagesState> {
  final EkubPackagesRepository repository;

  StreamSubscription? _notificationSubscription;

  /// Incremented every time a load or filter change starts. A handler only
  /// emits if its ticket is still the newest one.
  ///
  /// Bloc runs handlers concurrently, so tapping category A then B on a slow
  /// connection used to let A's late response overwrite B's — the chips would
  /// snap back to the category you had just left.
  int _requestTicket = 0;

  int _newTicket() => ++_requestTicket;

  bool _isStale(int ticket) => ticket != _requestTicket;

  /// The package the user is currently filtering by, whatever state we're in.
  int? get _currentSelection => switch (state) {
    EkubPackagesSuccess s => s.selectedPackageId,
    EkubPackagesFailure s => s.selectedPackageId,
    _ => null,
  };

  EkubPackagesBloc({required this.repository, required NotificationService notificationService}) : super(EkubPackagesLoading()) {
    on<EkubPackagesLoadEvent>(_onLoad);
    on<EkubPackagesSelectFilterEvent>(_onSelectFilter);
    on<EkubPackagesJoinGroupEvent>(_onJoinGroup);
    on<EkubPackagesDrawUpdateEvent>(_onDrawUpdate);

    _notificationSubscription = notificationService.messageStream.listen((message) {
      final groupId = message.data['equb_group_id'];
      final type = message.data['type'];
      final id = groupId != null ? int.tryParse(groupId.toString()) : null;

      if (id != null && (type == 'equb_draw_started' || type == 'equb_draw_completed')) {
        final candidates = _extractCandidates(message.data['member_names']);
        add(EkubPackagesDrawUpdateEvent(
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

  /// Attaches the member's own membership to each group so the card can show
  /// "Joined" instead of a Join button.
  List<EqubGroup> _enrich(
    List<EqubGroup> groups,
    List<EqubMembership> memberships,
  ) {
    if (memberships.isEmpty) return groups;
    return groups.map((g) {
      final mine = memberships.where((m) => m.equbGroupId == g.id).toList();
      return mine.isEmpty ? g : g.copyWith(memberships: mine);
    }).toList();
  }

  /// Builds a state out of the last successful fetch so the tab opens with real
  /// content instead of a spinner. Null when this device has never loaded the
  /// Equb tab before.
  EkubPackagesState? _cachedState() {
    final packages = repository.cachedPackages();
    if (packages == null || packages.isEmpty) return null;

    // Respect a category the user has already chosen rather than resetting to
    // the first chip.
    final selectedPackageId = _resolveSelection(packages);
    final groups =
        repository.cachedEqubGroups(packageId: selectedPackageId) ??
        const <EqubGroup>[];
    final memberships =
        repository.cachedEqubMemberships() ?? const <EqubMembership>[];

    return EkubPackagesSuccess(
      packages: packages,
      groups: _enrich(groups, memberships),
      memberships: memberships,
      selectedPackageId: selectedPackageId,
    );
  }

  /// Which category should be selected after a reload.
  ///
  /// Keeps whatever the user picked, as long as that package still exists.
  /// Only falls back to the first chip on a genuinely fresh start. Reloads run
  /// constantly — after joining, on pull-to-refresh, on returning from a group
  /// — and each one used to yank the user back to the first category.
  int? _resolveSelection(List<EqubPackage> packages) {
    if (packages.isEmpty) return null;

    final current = _currentSelection;
    if (current != null && packages.any((p) => p.id == current)) {
      return current;
    }
    return packages.first.id;
  }

  Future<void> _onLoad(
    EkubPackagesLoadEvent event,
    Emitter<EkubPackagesState> emit,
  ) async {
    logger('EkubPackagesBloc: Loading data (silent: ${event.isSilent})');

    final ticket = _newTicket();

    try {
      if (!event.isSilent) {
        // Draw whatever we already have, then let the network catch up behind
        // it. A warm start no longer shows a full-screen spinner.
        final cached = _cachedState();
        emit(cached ?? EkubPackagesLoading());
      }

      // Memberships don't depend on the package list, so this request goes out
      // straight away rather than queueing behind two others.
      final membershipsFuture = repository.fetchEqubMemberships();

      final packagesResult = await repository.fetchPackages();

      List<EqubPackage> fetchedPackages = [];
      Failure? packageFailure;

      packagesResult.fold(
        (Failure failure) => packageFailure = failure,
        (List<EqubPackage> packages) => fetchedPackages = packages,
      );

      if (packageFailure != null) {
        // A newer request already took over; this response is history.
        if (_isStale(ticket)) return;

        // Don't wipe the screen on a failed refresh when cached content is
        // already on it.
        final current = state;
        emit(
          EkubPackagesFailure(
            failure: packageFailure!,
            packages: current is EkubPackagesSuccess
                ? current.packages
                : const [],
            groups: current is EkubPackagesSuccess
                ? current.groups
                : const [],
            memberships: current is EkubPackagesSuccess
                ? current.memberships
                : const [],
            selectedPackageId: current is EkubPackagesSuccess
                ? current.selectedPackageId
                : null,
          ),
        );
        return;
      }

      final selectedPackageId = _resolveSelection(fetchedPackages);

      final groupsResult = await repository.fetchEqubGroups(
        packageId: selectedPackageId,
      );
      final membershipsResult = await membershipsFuture;

      // The user may have tapped a different category while this was in
      // flight; that request now owns the screen.
      if (_isStale(ticket)) return;

      groupsResult.fold(
        (Failure failure) {
          emit(
            EkubPackagesFailure(
              failure: failure,
              packages: fetchedPackages,
              groups: const [],
              selectedPackageId: selectedPackageId,
            ),
          );
        },
        (List<EqubGroup> groups) {
          final memberships = membershipsResult.getOrElse(
            () => const <EqubMembership>[],
          );

          emit(
            EkubPackagesSuccess(
              packages: fetchedPackages,
              groups: _enrich(groups, memberships),
              memberships: memberships,
              selectedPackageId: selectedPackageId,
            ),
          );
        },
      );
    } finally {
      // Releases the pull-to-refresh spinner, whichever branch we took.
      event.signal?.complete();
    }
  }

  Future<void> _onSelectFilter(
    EkubPackagesSelectFilterEvent event,
    Emitter<EkubPackagesState> emit,
  ) async {
    final current = state;

    // Already on this category — nothing to do. Stops a double tap on the same
    // chip firing a second request.
    if (_currentSelection == event.packageId && current is EkubPackagesSuccess) {
      return;
    }

    final ticket = _newTicket();

    List<EqubPackage> packages = [];
    List<EqubMembership> memberships = [];
    
    if (current is EkubPackagesSuccess) {
      packages = current.packages;
      memberships = current.memberships;

      // If this filter has been opened before, show its last known groups
      // right away rather than blanking the list behind a spinner.
      final cachedGroups = repository.cachedEqubGroups(
        packageId: event.packageId,
      );

      emit(
        current.copyWith(
          selectedPackageId: event.packageId,
          groups: cachedGroups == null
              ? current.groups
              : _enrich(cachedGroups, memberships),
          isLoadingGroups: cachedGroups == null,
        ),
      );
    } else if (current is EkubPackagesFailure) {
      packages = current.packages;
      memberships = current.memberships;
      emit(current.copyWith(selectedPackageId: event.packageId));
    } else {
      return;
    }

    final groupsResult = await repository.fetchEqubGroups(packageId: event.packageId);

    // A newer tap has taken over the screen; discard this response rather than
    // snapping the chips back to this category.
    if (_isStale(ticket)) return;

    groupsResult.fold(
      (Failure failure) {
        emit(
          EkubPackagesFailure(
            failure: failure,
            packages: packages,
            groups: const [],
            selectedPackageId: event.packageId,
          ),
        );
      },
      (List<EqubGroup> groups) {
        emit(
          EkubPackagesSuccess(
            packages: packages,
            groups: _enrich(groups, memberships),
            memberships: memberships,
            selectedPackageId: event.packageId,
            isLoadingGroups: false,
          ),
        );
      },
    );
  }

  Future<void> _onJoinGroup(
    EkubPackagesJoinGroupEvent event,
    Emitter<EkubPackagesState> emit,
  ) async {
    final current = state;
    if (current is! EkubPackagesSuccess && current is! EkubPackagesFailure) {
      return;
    }
    if (event.group.id == null) return;
    if (current is EkubPackagesSuccess) {
      emit(
        current.copyWith(
          joiningGroupId: event.group.id.toString(),
          joinSuccess: false,
        ),
      );
    } else if (current is EkubPackagesFailure) {
      emit(
        current.copyWith(
          joiningGroupId: event.group.id.toString(),
          joinSuccess: false,
        ),
      );
    }

    final result = await repository.joinEqubGroup(groupId: event.group.id!);
    result.fold(
      (Failure failure) {
        final now = state;
        if (now is EkubPackagesSuccess) {
          emit(
            EkubPackagesFailure(
              failure: failure,
              packages: now.packages,
              groups: now.groups,
              memberships: now.memberships,
              selectedPackageId: now.selectedPackageId,
            ),
          );
        } else if (now is EkubPackagesFailure) {
          emit(now.copyWith(failure: failure, joiningGroupId: null));
        }
      },
      (_) {
        final now = state;
        if (now is EkubPackagesSuccess) {
          emit(now.copyWith(joiningGroupId: null, joinSuccess: true));
        } else if (now is EkubPackagesFailure) {
          emit(
            EkubPackagesSuccess(
              packages: now.packages,
              groups: now.groups,
              memberships: now.memberships,
              selectedPackageId: now.selectedPackageId,
              joinSuccess: true,
            ),
          );
        }
        // Silent: the card already flipped to "Joined", so a visible reload
        // would only flash the stale cached list back for a frame.
        add(EkubPackagesLoadEvent(isSilent: true));
      },
    );
  }

  void _onDrawUpdate(
    EkubPackagesDrawUpdateEvent event,
    Emitter<EkubPackagesState> emit,
  ) {
    final current = state;
    Map<int, Map<String, dynamic>> updatedDraws = {};
    if (current is EkubPackagesSuccess) {
      updatedDraws = Map<int, Map<String, dynamic>>.from(current.activeDraws);
    } else if (current is EkubPackagesFailure) {
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

    if (current is EkubPackagesSuccess) {
      emit(current.copyWith(activeDraws: updatedDraws));
    } else if (current is EkubPackagesFailure) {
      emit(current.copyWith(activeDraws: updatedDraws));
    }
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    return super.close();
  }
}
