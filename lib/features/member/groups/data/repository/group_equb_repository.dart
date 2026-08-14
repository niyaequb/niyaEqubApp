import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class GroupEqubRepository {
  final Dio dio;

  GroupEqubRepository({required this.dio});

  /// Re-reads a cached list off disk. Null means nothing has ever been stored,
  /// which callers treat differently from a stored empty list.
  static List<T>? _readCached<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final cached = AppCache.read<List<dynamic>>(key);
    if (cached == null) return null;
    try {
      return cached.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  /// Re-reads a cached object off disk, guarding against a shape change
  /// between app versions.
  static T? _readCachedItem<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final cached = AppCache.read<Map<String, dynamic>>(key);
    if (cached == null) return null;
    try {
      return fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Groups
  // ------------------------------------------------------------------

  ResultFuture<List<EqubCircle>> getMyGroups({bool ownedOnly = false}) async {
    try {
      final res = await dio.get(
        GroupEqubEndpoints.myGroups(),
        queryParameters: {if (ownedOnly) 'owned_only': 1, 'per_page': 50},
      );
      final raw = res.data?['data'] as List? ?? [];
      if (!ownedOnly) {
        unawaited(AppCache.write(CacheKeys.myGroupEqubs, raw));
      }
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(EqubCircle.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// The member's groups as of the last successful fetch.
  List<EqubCircle>? cachedMyGroups() =>
      _readCached(CacheKeys.myGroupEqubs, EqubCircle.fromJson);

  /// Pending invitations as of the last successful fetch.
  List<EqubInvitation>? cachedMyInvitations() =>
      _readCached(CacheKeys.myEqubInvitations, EqubInvitation.fromJson);

  ResultFuture<EqubCircle> getGroup(int id) async {
    try {
      final res = await dio.get(GroupEqubEndpoints.group(id));
      final data = res.data['data'] as Map<String, dynamic>;
      unawaited(AppCache.write(CacheKeys.groupEqub(id), data));
      return Right(EqubCircle.fromJson(data));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// The three reads the detail screen opens on, as of its last visit.
  EqubCircle? cachedGroup(int id) =>
      _readCachedItem(CacheKeys.groupEqub(id), EqubCircle.fromJson);

  GroupLedger? cachedLedger(int id) =>
      _readCachedItem(CacheKeys.groupLedger(id), GroupLedger.fromJson);

  List<GroupDraw>? cachedDraws(int id) =>
      _readCached(CacheKeys.groupDraws(id), GroupDraw.fromJson);

  ResultFuture<EqubCircle> createGroup(Map<String, dynamic> body) async {
    try {
      final res = await dio.post(GroupEqubEndpoints.myGroups(), data: body);
      return Right(EqubCircle.fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<GroupLedger> getLedger(int groupId) async {
    try {
      final res = await dio.get(GroupEqubEndpoints.ledger(groupId));
      final data = res.data['data'] as Map<String, dynamic>;
      unawaited(AppCache.write(CacheKeys.groupLedger(groupId), data));
      return Right(GroupLedger.fromJson(data));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<SplitPlanPreview> getSplitPlan(int groupId, {bool regenerate = false}) async {
    try {
      final res = await dio.get(
        GroupEqubEndpoints.splitPlan(groupId),
        queryParameters: {if (regenerate) 'regenerate': 1},
      );
      return Right(SplitPlanPreview.fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<String> startGroup(int groupId) async {
    return _post(GroupEqubEndpoints.start(groupId));
  }

  ResultFuture<String> cancelGroup(int groupId) async {
    return _post(GroupEqubEndpoints.cancel(groupId));
  }

  ResultFuture<String> remindUnpaid(int groupId) async {
    return _post(GroupEqubEndpoints.remindUnpaid(groupId));
  }

  ResultFuture<String> removeMember(int groupId, int membershipId) async {
    try {
      final res = await dio.delete(GroupEqubEndpoints.removeMember(groupId, membershipId));
      return Right(res.data?['message']?.toString() ?? 'Member removed.');
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  // ------------------------------------------------------------------
  // Invitations
  // ------------------------------------------------------------------

  /// Partial search by name or phone, for the "add members" autocomplete.
  /// The API needs at least 2 characters and caps the result list.
  ResultFuture<List<MemberLookupResult>> searchMembers(String query) async {
    try {
      final res = await dio.get(
        GroupEqubEndpoints.memberSearch(),
        queryParameters: {'q': query},
      );
      final list = (res.data?['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MemberLookupResult.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<List<JoinableEqub>> getJoinableEqubs() async {
    try {
      final res = await dio.get(GroupEqubEndpoints.joinableGroups());
      final raw = res.data?['data'] as List? ?? [];
      unawaited(AppCache.write(CacheKeys.joinableEqubs, raw));
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(JoinableEqub.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Equbs available to build a group inside, as of the last fetch. Lets the
  /// New Group Equb screen open on real content instead of a spinner.
  List<JoinableEqub>? cachedJoinableEqubs() =>
      _readCached(CacheKeys.joinableEqubs, JoinableEqub.fromJson);

  ResultFuture<MemberLookupResult?> lookupMember({String? phone, String? referralCode}) async {
    try {
      final res = await dio.post(GroupEqubEndpoints.memberLookup(), data: {
        if (phone != null) 'phone': phone,
        if (referralCode != null) 'referral_code': referralCode,
      });
      final data = res.data?['data'];
      if (data == null) return const Right(null);
      return Right(MemberLookupResult.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<String> invite(
    int groupId, {
    List<int> memberIds = const [],
    List<String> phones = const [],
    String? message,
  }) async {
    try {
      final res = await dio.post(GroupEqubEndpoints.invitations(groupId), data: {
        'member_ids': memberIds,
        'phones': phones,
        if (message != null && message.isNotEmpty) 'message': message,
      });
      return Right(res.data?['message']?.toString() ?? 'Invitations sent.');
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Preview a group from an invite code before asking to join.
  ResultFuture<GroupPreview> previewByCode(String code) async {
    try {
      final res = await dio.get(
        GroupEqubEndpoints.byCode(code.trim().toUpperCase()),
      );
      return Right(GroupPreview.fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Ask to join a group using a shared invite code. Creates a pending
  /// request; the owner still has to approve it.
  ResultFuture<String> joinByCode(String code) async {
    try {
      final res = await dio.post(
        GroupEqubEndpoints.joinByCode(),
        data: {'invite_code': code.trim().toUpperCase()},
      );
      return Right(res.data?['message']?.toString() ?? 'Request sent.');
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Pending join requests, for the group owner.
  ResultFuture<List<EqubInvitation>> getJoinRequests(int groupId) async {
    try {
      final res = await dio.get(GroupEqubEndpoints.joinRequests(groupId));
      final list = (res.data?['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EqubInvitation.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<String> respondToRequest(
    int groupId,
    int invitationId, {
    required bool approve,
  }) async {
    try {
      final res = await dio.post(
        GroupEqubEndpoints.respondToRequest(groupId, invitationId),
        data: {'approve': approve},
      );
      return Right(res.data?['message']?.toString() ?? 'Done.');
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<List<EqubInvitation>> getMyInvitations() async {
    try {
      final res = await dio.get(GroupEqubEndpoints.myInvitations());
      final raw = res.data?['data'] as List? ?? [];
      unawaited(AppCache.write(CacheKeys.myEqubInvitations, raw));
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(EqubInvitation.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<String> respondToInvitation(int invitationId, {required bool accept}) async {
    return _post(
      accept
          ? GroupEqubEndpoints.acceptInvitation(invitationId)
          : GroupEqubEndpoints.declineInvitation(invitationId),
    );
  }

  // ------------------------------------------------------------------
  // Draws
  // ------------------------------------------------------------------

  ResultFuture<List<GroupDraw>> getDraws(int groupId) async {
    try {
      final res = await dio.get(GroupEqubEndpoints.draws(groupId));
      final raw = res.data?['data'] as List? ?? [];
      unawaited(AppCache.write(CacheKeys.groupDraws(groupId), raw));
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(GroupDraw.fromJson)
          .toList();
      return Right(list);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Runs one round. Pass [membershipIds] to choose the winner group by hand.
  ResultFuture<GroupDraw> runDraw(
    int groupId, {
    List<int> membershipIds = const [],
    int? winnersCount,
  }) async {
    try {
      final res = await dio.post(GroupEqubEndpoints.draws(groupId), data: {
        if (membershipIds.isNotEmpty) 'membership_ids': membershipIds,
        if (winnersCount != null) 'winners_count': winnersCount,
      });
      return Right(GroupDraw.fromJson(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<String> _post(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await dio.post(path, data: body ?? {});
      return Right(res.data?['message']?.toString() ?? 'Done.');
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

// ====================================================================
// Models
// ====================================================================

double _toDouble(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;
int _toInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;

class EqubCircle {
  final int id;
  final String name;
  final String? description;
  final String? inviteCode;
  final String status;
  final String moderationStatus;
  final String? rejectionReason;
  final String? packageName;
  final double contributionAmount;
  final int contributionFrequencyDays;
  final int maxMembers;
  final int currentMembersCount;
  final int roundsTotal;
  final int roundsCompleted;
  final double potPerRound;
  final String winnerSelectionMode;
  final List<int> splitPlan;
  final int splitPlanCursor;
  final int nextRoundWinners;
  final bool drawRequiresUpToDate;
  final bool isOwner;
  final String? ownerName;
  final DateTime? startDate;
  final DateTime? endDate;

  const EqubCircle({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    required this.status,
    required this.moderationStatus,
    this.rejectionReason,
    this.packageName,
    required this.contributionAmount,
    required this.contributionFrequencyDays,
    required this.maxMembers,
    required this.currentMembersCount,
    required this.roundsTotal,
    required this.roundsCompleted,
    required this.potPerRound,
    required this.winnerSelectionMode,
    required this.splitPlan,
    required this.splitPlanCursor,
    required this.nextRoundWinners,
    required this.drawRequiresUpToDate,
    required this.isOwner,
    this.ownerName,
    this.startDate,
    this.endDate,
  });

  bool get isDraftStage => status == 'registration';
  bool get isRunning => status == 'running';
  bool get isPendingApproval => moderationStatus == 'pending';
  bool get isRejected => moderationStatus == 'rejected';

  factory EqubCircle.fromJson(Map<String, dynamic> json) {
    return EqubCircle(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      inviteCode: json['invite_code']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      moderationStatus: json['moderation_status']?.toString() ?? 'approved',
      rejectionReason: json['rejection_reason']?.toString(),
      packageName: json['package_name']?.toString(),
      contributionAmount: _toDouble(json['contribution_amount']),
      contributionFrequencyDays: _toInt(json['contribution_frequency_days']),
      maxMembers: _toInt(json['max_members']),
      currentMembersCount: _toInt(json['current_members_count']),
      roundsTotal: _toInt(json['rounds_total']),
      roundsCompleted: _toInt(json['rounds_completed']),
      potPerRound: _toDouble(json['pot_per_round']),
      winnerSelectionMode: json['winner_selection_mode']?.toString() ?? 'single',
      splitPlan: (json['winner_split_plan'] as List? ?? []).map(_toInt).toList(),
      splitPlanCursor: _toInt(json['split_plan_cursor']),
      nextRoundWinners: _toInt(json['next_round_winners']),
      drawRequiresUpToDate: json['draw_requires_up_to_date'] == true,
      isOwner: json['is_owner'] == true,
      ownerName: (json['owner'] as Map?)?['name']?.toString(),
      startDate: DateTime.tryParse(json['equb_start_date']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['equb_end_date']?.toString() ?? ''),
    );
  }
}

class GroupLedger {
  final LedgerTotals totals;
  final List<LedgerMember> members;

  const GroupLedger({required this.totals, required this.members});

  List<LedgerMember> get behind => members.where((m) => m.roundsOverdue > 0).toList();
  List<LedgerMember> get paidUp => members.where((m) => m.roundsOverdue == 0).toList();

  factory GroupLedger.fromJson(Map<String, dynamic> json) {
    return GroupLedger(
      totals: LedgerTotals.fromJson((json['group'] as Map?)?.cast<String, dynamic>() ?? {}),
      members: (json['members'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LedgerMember.fromJson)
          .toList(),
    );
  }
}

class LedgerTotals {
  final int membersCount;
  final int roundsTotal;
  final int roundsCompleted;
  final double contributionAmount;
  final int frequencyDays;
  final double potPerRound;
  final double expectedTotal;
  final double dueToDate;
  final double totalPaid;
  final double totalUnpaid;
  final double remainingTotal;
  final double collectionRate;
  final double progress;
  final int membersPaidUp;
  final int membersBehind;

  const LedgerTotals({
    required this.membersCount,
    required this.roundsTotal,
    required this.roundsCompleted,
    required this.contributionAmount,
    required this.frequencyDays,
    required this.potPerRound,
    required this.expectedTotal,
    required this.dueToDate,
    required this.totalPaid,
    required this.totalUnpaid,
    required this.remainingTotal,
    required this.collectionRate,
    required this.progress,
    required this.membersPaidUp,
    required this.membersBehind,
  });

  // ----------------------------------------------------------------
  // Whole-term money
  //
  // Every figure above is a "so far" number: what has come due, what has been
  // paid, who is behind today. The getters below answer the other question,
  // and the one members ask first — what is this circle worth from the first
  // round to the last.
  // ----------------------------------------------------------------

  /// The full value of the circle: every member's contribution, in every
  /// round.
  ///
  ///     members x rounds x contribution
  ///
  /// The server sends this as `expected_total`, summed the same way. The
  /// multiplication here is a fallback for a cache written by an older build
  /// or a payload that predates the field, so the screen can never show a
  /// blank total while the three numbers it needs are sitting right there.
  double get totalValue {
    if (expectedTotal > 0) return expectedTotal;
    return contributionAmount * roundsTotal * membersCount;
  }

  /// One member's share of [totalValue] — what a single person pays in across
  /// the whole term.
  double get perMemberTotal => contributionAmount * roundsTotal;

  /// Everyone's contribution for a single round, which is what that round's
  /// winners share. Falls back to the head count when the server carries no
  /// explicit per-draw amount.
  double get roundTotal =>
      potPerRound > 0 ? potPerRound : contributionAmount * membersCount;

  /// Still to be collected over the full term.
  ///
  /// Not the same as [totalUnpaid], which counts only the rounds that have
  /// already come due — that is the arrears figure, this is the runway.
  double get outstandingOverTerm {
    final left = remainingTotal > 0 ? remainingTotal : totalValue - totalPaid;
    return left < 0 ? 0 : left;
  }

  /// How far the circle has come against its full value, 0..1. The card's
  /// other bar is [collectionRate], which measures against what is due today.
  double get termProgress {
    if (totalValue <= 0) return 0;
    return (totalPaid / totalValue).clamp(0, 1).toDouble();
  }

  /// True once there is enough of the circle on hand to spell the total out.
  /// Keeps the breakdown line from reading "0 members x 0 rounds" on a cold
  /// cache.
  bool get hasTermFigures =>
      membersCount > 0 && roundsTotal > 0 && contributionAmount > 0;

  factory LedgerTotals.fromJson(Map<String, dynamic> json) {
    return LedgerTotals(
      membersCount: _toInt(json['members_count']),
      roundsTotal: _toInt(json['rounds_total']),
      roundsCompleted: _toInt(json['rounds_completed']),
      contributionAmount: _toDouble(json['contribution_amount']),
      frequencyDays: _toInt(json['contribution_frequency_days']),
      potPerRound: _toDouble(json['pot_per_round']),
      expectedTotal: _toDouble(json['expected_total']),
      dueToDate: _toDouble(json['due_to_date']),
      totalPaid: _toDouble(json['total_paid']),
      totalUnpaid: _toDouble(json['total_unpaid']),
      remainingTotal: _toDouble(json['remaining_total']),
      collectionRate: _toDouble(json['collection_rate']),
      progress: _toDouble(json['progress']),
      membersPaidUp: _toInt(json['members_paid_up']),
      membersBehind: _toInt(json['members_behind']),
    );
  }
}

class LedgerMember {
  final int membershipId;
  final int memberId;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final int roundsTotal;
  final int roundsDue;
  final int roundsPaid;
  final int roundsOverdue;
  final double totalPaid;
  final double outstandingNow;
  final double remainingTotal;
  final double progress;
  final DateTime? lastPaymentAt;
  final DateTime? nextDueDate;
  final String paymentStatus;
  final bool hasWon;
  final DateTime? winDate;
  final bool isEligibleForDraw;

  const LedgerMember({
    required this.membershipId,
    required this.memberId,
    required this.name,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.roundsTotal,
    required this.roundsDue,
    required this.roundsPaid,
    required this.roundsOverdue,
    required this.totalPaid,
    required this.outstandingNow,
    required this.remainingTotal,
    required this.progress,
    this.lastPaymentAt,
    this.nextDueDate,
    required this.paymentStatus,
    required this.hasWon,
    this.winDate,
    required this.isEligibleForDraw,
  });

  bool get isOwner => role == 'owner';

  factory LedgerMember.fromJson(Map<String, dynamic> json) {
    return LedgerMember(
      membershipId: _toInt(json['membership_id']),
      memberId: _toInt(json['member_id']),
      name: json['name']?.toString() ?? 'Member',
      phone: json['phone']?.toString(),
      avatarUrl: json['profile_picture_url']?.toString(),
      role: json['role']?.toString() ?? 'member',
      roundsTotal: _toInt(json['rounds_total']),
      roundsDue: _toInt(json['rounds_due']),
      roundsPaid: _toInt(json['rounds_paid']),
      roundsOverdue: _toInt(json['rounds_overdue']),
      totalPaid: _toDouble(json['total_paid']),
      outstandingNow: _toDouble(json['outstanding_now']),
      remainingTotal: _toDouble(json['remaining_total']),
      progress: _toDouble(json['progress']),
      lastPaymentAt: DateTime.tryParse(json['last_payment_at']?.toString() ?? ''),
      nextDueDate: DateTime.tryParse(json['next_due_date']?.toString() ?? ''),
      paymentStatus: json['payment_status']?.toString() ?? 'paid_up',
      hasWon: json['has_won'] == true,
      winDate: DateTime.tryParse(json['win_date']?.toString() ?? ''),
      isEligibleForDraw: json['is_eligible_for_draw'] == true,
    );
  }
}

class GroupDraw {
  final int id;
  final int roundNumber;
  final int winnersCount;
  final String mode;
  final DateTime? drawDate;
  final double totalPot;
  final List<DrawWinner> winners;

  const GroupDraw({
    required this.id,
    required this.roundNumber,
    required this.winnersCount,
    required this.mode,
    this.drawDate,
    required this.totalPot,
    required this.winners,
  });

  factory GroupDraw.fromJson(Map<String, dynamic> json) {
    return GroupDraw(
      id: _toInt(json['id']),
      roundNumber: _toInt(json['round_number']),
      winnersCount: _toInt(json['winners_count']),
      mode: json['mode']?.toString() ?? 'automatic',
      drawDate: DateTime.tryParse(json['draw_date']?.toString() ?? ''),
      totalPot: _toDouble(json['total_pot']),
      winners: (json['winners'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DrawWinner.fromJson)
          .toList(),
    );
  }
}

class DrawWinner {
  final int membershipId;
  final int memberId;
  final String name;
  final String? avatarUrl;
  final int position;
  final double amountWon;
  final bool isMe;

  const DrawWinner({
    required this.membershipId,
    required this.memberId,
    required this.name,
    this.avatarUrl,
    required this.position,
    required this.amountWon,
    required this.isMe,
  });

  factory DrawWinner.fromJson(Map<String, dynamic> json) {
    return DrawWinner(
      membershipId: _toInt(json['membership_id']),
      memberId: _toInt(json['member_id']),
      name: json['name']?.toString() ?? 'Member',
      avatarUrl: json['profile_picture_url']?.toString(),
      position: _toInt(json['position']),
      amountWon: _toDouble(json['amount_won']),
      isMe: json['is_me'] == true,
    );
  }
}

class SplitPlanPreview {
  final int membersCount;
  final List<int> plan;
  final int rounds;
  final bool isFinal;

  const SplitPlanPreview({
    required this.membersCount,
    required this.plan,
    required this.rounds,
    required this.isFinal,
  });

  factory SplitPlanPreview.fromJson(Map<String, dynamic> json) {
    final plan = (json['split_plan'] as List? ?? []).map(_toInt).toList();
    return SplitPlanPreview(
      membersCount: _toInt(json['members_count']),
      plan: plan,
      rounds: _toInt(json['rounds']) == 0 ? plan.length : _toInt(json['rounds']),
      isFinal: json['is_final'] == true,
    );
  }
}

class EqubInvitation {
  final int id;
  final String status;
  final String? message;
  final String groupName;
  final int groupId;
  final String? packageName;
  final double contributionAmount;
  final int currentMembers;
  final int maxMembers;
  final String? invitedByName;
  final DateTime? expiresAt;

  const EqubInvitation({
    required this.id,
    required this.status,
    this.message,
    required this.groupName,
    required this.groupId,
    this.packageName,
    required this.contributionAmount,
    required this.currentMembers,
    required this.maxMembers,
    this.invitedByName,
    this.expiresAt,
  });

  factory EqubInvitation.fromJson(Map<String, dynamic> json) {
    final group = (json['equb_group'] as Map?)?.cast<String, dynamic>() ?? {};
    return EqubInvitation(
      id: _toInt(json['id']),
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString(),
      groupId: _toInt(group['id']),
      groupName: group['name']?.toString() ?? 'Equb',
      packageName: group['package_name']?.toString(),
      contributionAmount: _toDouble(group['contribution_amount']),
      currentMembers: _toInt(group['current_members_count']),
      maxMembers: _toInt(group['max_members']),
      invitedByName: (json['invited_by'] as Map?)?['name']?.toString(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

class MemberLookupResult {
  final int memberId;
  final String name;
  final String? phone;
  final String? avatarUrl;

  const MemberLookupResult({
    required this.memberId,
    required this.name,
    this.phone,
    this.avatarUrl,
  });

  factory MemberLookupResult.fromJson(Map<String, dynamic> json) {
    return MemberLookupResult(
      memberId: _toInt(json['member_id']),
      name: json['name']?.toString() ?? 'Member',
      phone: json['phone']?.toString(),
      avatarUrl: json['profile_picture_url']?.toString(),
    );
  }
}

/// A running platform Equb a member can build a Group Equb inside.
/// Every money figure in the create screen is derived from this.
class JoinableEqub {
  final int id;
  final String name;
  final String? packageName;
  final String status;
  final double contributionPerPerson;
  final int frequencyDays;
  final int roundsTotal;
  final String? termsContent;

  const JoinableEqub({
    required this.id,
    required this.name,
    this.packageName,
    required this.status,
    required this.contributionPerPerson,
    required this.frequencyDays,
    required this.roundsTotal,
    this.termsContent,
  });

  factory JoinableEqub.fromJson(Map<String, dynamic> json) {
    return JoinableEqub(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? 'Equb',
      packageName: json['package_name']?.toString(),
      status: json['status']?.toString() ?? '',
      contributionPerPerson: _toDouble(json['contribution_per_person']),
      frequencyDays: _toInt(json['contribution_frequency_days']),
      roundsTotal: _toInt(json['rounds_total']),
      termsContent: json['terms_content']?.toString(),
    );
  }
}

/// What someone sees after entering an invite code, before requesting to join.
class GroupPreview {
  final int id;
  final String name;
  final String? description;
  final String? ownerName;
  final String? equbName;
  final int membersCount;
  final double contributionPerPerson;
  final int frequencyDays;
  final int roundsTotal;
  final String? termsContent;
  final bool alreadyMember;
  final bool requestPending;

  const GroupPreview({
    required this.id,
    required this.name,
    this.description,
    this.ownerName,
    this.equbName,
    required this.membersCount,
    required this.contributionPerPerson,
    required this.frequencyDays,
    required this.roundsTotal,
    this.termsContent,
    required this.alreadyMember,
    required this.requestPending,
  });

  factory GroupPreview.fromJson(Map<String, dynamic> json) {
    return GroupPreview(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? 'Equb group',
      description: json['description']?.toString(),
      ownerName: json['owner_name']?.toString(),
      equbName: json['equb_name']?.toString(),
      membersCount: _toInt(json['members_count']),
      contributionPerPerson: _toDouble(json['contribution_per_person']),
      frequencyDays: _toInt(json['contribution_frequency_days']),
      roundsTotal: _toInt(json['rounds_total']),
      termsContent: json['terms_content']?.toString(),
      alreadyMember: json['already_member'] == true,
      requestPending: json['request_pending'] == true,
    );
  }
}

/// Ethiopian numbers are typed as 09xxxxxxxx but stored as +2519xxxxxxxx.
String normalizeEthiopianPhone(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');

  if (cleaned.startsWith('+251')) return cleaned;
  if (cleaned.startsWith('251')) return '+$cleaned';
  if (cleaned.startsWith('0')) return '+251${cleaned.substring(1)}';

  final digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 9 && (digits.startsWith('9') || digits.startsWith('7'))) {
    return '+251$digits';
  }

  return cleaned;
}
