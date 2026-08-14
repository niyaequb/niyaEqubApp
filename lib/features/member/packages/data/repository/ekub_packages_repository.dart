import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';
import 'package:niya_equb/core/util/logger.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class EkubPackagesRepository {
  final Dio dio;

  EkubPackagesRepository({required this.dio});

  /// Pulls the array out of a response that may be a bare list, or wrapped
  /// under `data` / one of the named keys.
  static List<dynamic> _unwrapList(dynamic raw, List<String> keys) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in ['data', ...keys]) {
        if (raw[key] is List) return raw[key] as List;
      }
    }
    return const [];
  }

  static List<T> _parse<T>(
    List<dynamic> list,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return list.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  /// Re-reads a cached list off disk. Returns null when nothing is stored, so
  /// callers can tell "no cache" apart from "cached empty list".
  static List<T>? _readCached<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final cached = AppCache.read<List<dynamic>>(key);
    if (cached == null) return null;
    try {
      return _parse(cached, fromJson);
    } catch (_) {
      return null;
    }
  }

  ResultFuture<double?> fetchExchangeRate() async {
    try {
      logger("fetching");
      final result = await dio.get(
        MemberEndpoints.exchangeRate(),
        queryParameters: {
          'from': 'USD',
          'to': 'ETB',
        },
      );
      logger(result.data);
      if (result.data == null) {
        return const Right(null);
      }

      final raw = result.data;
      if (raw is Map) {
        if (raw.containsKey('rate')) {
          return Right(double.tryParse(raw['rate'].toString()));
        } else if (raw.containsKey('usd_to_etb')) {
          return Right(double.tryParse(raw['usd_to_etb'].toString()));
        } else if (raw.containsKey('data')) {
          final data = raw['data'];
          if (data is List && data.isNotEmpty) {
            final item = data.first;
            if (item is Map && item.containsKey('rate')) {
              return Right(double.tryParse(item['rate'].toString()));
            }
          } else if (data is Map && data.containsKey('rate')) {
            return Right(double.tryParse(data['rate'].toString()));
          }
        }
      } else if (raw is String) {
        return Right(double.tryParse(raw));
      } else if (raw is num) {
        return Right(raw.toDouble());
      }

      return const Right(null);
    } catch (e) {
      if (e is DioException) {
        logger(e.response?.data);
        return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
      }
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Fetches equb packages from api/member/equb-packages (used as filters)
  ResultFuture<List<EqubPackage>> fetchPackages() async {
    try {
      final result = await dio.get(MemberEndpoints.equbPackages());
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final list = _unwrapList(result.data, ['packages']);
      unawaited(AppCache.write(CacheKeys.equbPackages, list));
      return Right(_parse(list, EqubPackage.fromJson));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Last known packages, straight off disk. Lets the Equb tab draw its filter
  /// chips on the first frame instead of after a round trip.
  List<EqubPackage>? cachedPackages() =>
      _readCached(CacheKeys.equbPackages, EqubPackage.fromJson);

  /// Fetches equb groups from api/member/equb-groups
  ResultFuture<List<EqubGroup>> fetchEqubGroups({int? packageId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (packageId != null) {
        queryParams['equb_package_id'] = packageId;
      }
      final result = await dio.get(
        MemberEndpoints.equbGroups(),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final list = _unwrapList(result.data, ['groups']);
      unawaited(AppCache.write(CacheKeys.equbGroups(packageId), list));
      return Right(_parse(list, EqubGroup.fromJson));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Groups for a filter as of the last successful fetch. Cached per package
  /// so switching chips is instant on a second visit.
  List<EqubGroup>? cachedEqubGroups({int? packageId}) =>
      _readCached(CacheKeys.equbGroups(packageId), EqubGroup.fromJson);

  /// Fetches current user's equb memberships (joined equbs)
  ResultFuture<List<EqubMembership>> fetchEqubMemberships() async {
    try {
      final result = await dio.get(MemberEndpoints.equbMemberships());
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final list = _unwrapList(result.data, ['memberships']);
      unawaited(AppCache.write(CacheKeys.equbMemberships, list));
      return Right(_parse(list, EqubMembership.fromJson));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// The member's joined Equbs as of the last successful fetch. Used by both
  /// the home screen and the Equb tab so they open with real content.
  List<EqubMembership>? cachedEqubMemberships() =>
      _readCached(CacheKeys.equbMemberships, EqubMembership.fromJson);

  ResultFuture<void> joinEqubGroup({required int groupId}) async {
    try {
      final data = <String, dynamic>{'equb_group_id': groupId};
      logger(data);
      await dio.post(MemberEndpoints.equbMemberships(), data: data);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// specific equb group detail
  ResultFuture<EqubGroup> fetchEqubGroupDetail(int id) async {
    try {
      final result = await dio.get(MemberEndpoints.equbGroupDetail(id));
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final raw = result.data;
      final data = (raw is Map && raw['data'] != null) ? raw['data'] : raw;
      return Right(EqubGroup.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Refreshes membership data after drawing or leaving
  ResultFuture<void> leaveEqub(int membershipId) async {
    try {
      final result = await dio.post(MemberEndpoints.leaveEqub(membershipId));
      if (result.statusCode == 200 || result.statusCode == 201) {
        return const Right(null);
      }
      throw ServerException(
        result.data?['message'] ?? 'Failed to leave equb',
        result.statusCode,
      );
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Initiates equb payment via Chapa
  ResultFuture<String> initiateEqubPayment({
    required int membershipId,
    required double amount,
    required String paymentDate,
  }) async {
    try {
      final data = {
        'equb_membership_id': membershipId,
        'amount': amount,
        'payment_method': 'chapa',
        'payment_date': paymentDate,
      };
      logger(data);
      final result = await dio.post(MemberEndpoints.equbPayments(), data: data);
      final raw = result.data;
      final checkoutUrl =
          (raw is Map &&
              raw['data'] != null &&
              raw['data'] is Map &&
              raw['data']['checkout_url'] != null)
          ? raw['data']['checkout_url']
          : (raw is Map
                ? (raw['checkout_url'] ??
                      (raw['data'] is String ? raw['data'] : null))
                : null);

      if (checkoutUrl == null) {
        throw ServerException("Failed to get payment URL", result.statusCode);
      }
      return Right(checkoutUrl.toString());
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

/// Package from API - used as filter
class EqubPackage {
  final int? id;
  final String? name;
  final String? type;
  final String? fixedContributionAmount;
  final String? minContributionAmount;
  final String? maxContributionAmount;
  final String? contributionFrequencyDays;
  final String? durationType;
  final String? durationDays;
  final String? maxMembers;
  final String? termsContent;
  final bool? isActive;
  final String? createdAt;
  final String? updatedAt;
  final List<EqubGroup>? groups;

  const EqubPackage({
    this.id,
    this.name,
    this.type,
    this.fixedContributionAmount,
    this.minContributionAmount,
    this.maxContributionAmount,
    this.contributionFrequencyDays,
    this.durationType,
    this.durationDays,
    this.maxMembers,
    this.termsContent,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.groups,
  });

  factory EqubPackage.fromJson(Map<String, dynamic> json) {
    return EqubPackage(
      id: json['id'] as int?,
      name: json['name']?.toString(),
      type: json['type']?.toString(),
      fixedContributionAmount: json['fixed_contribution_amount']?.toString(),
      minContributionAmount: json['min_contribution_amount']?.toString(),
      maxContributionAmount: json['max_contribution_amount']?.toString(),
      contributionFrequencyDays: json['contribution_frequency_days']
          ?.toString(),
      durationType: json['duration_type']?.toString(),
      durationDays: json['duration_days']?.toString(),
      maxMembers: json['max_members']?.toString(),
      termsContent: json['terms_content']?.toString(),
      isActive: json['is_active'] as bool?,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      groups: json['groups'] != null
          ? (json['groups'] as List)
                .map((g) => EqubGroup.fromJson(g as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}

/// Equb group from API - user joins these
class EqubGroup {
  final int? id;
  final String? equbPackageId;
  final String? name;
  final String? fixedContributionAmount;
  final String? contributionFrequencyDays;
  final String? durationType;
  final String? durationDays;
  final String? duration;
  final String? registrationOpenAt;
  final String? registrationCloseAt;
  final String? equbStartDate;
  final String? equbEndDate;
  final String? maxMembers;
  final String? status;
  final bool? isLocked;
  final String? currentMembersCount;
  final String? drawType;
  final String? termsAndConditions;
  final List<EqubMembership>? memberships;
  final String? createdAt;
  final String? updatedAt;
  final EqubPackage? package;

  const EqubGroup({
    this.id,
    this.equbPackageId,
    this.name,
    this.fixedContributionAmount,
    this.contributionFrequencyDays,
    this.durationType,
    this.durationDays,
    this.duration,
    this.registrationOpenAt,
    this.registrationCloseAt,
    this.equbStartDate,
    this.equbEndDate,
    this.maxMembers,
    this.status,
    this.isLocked,
    this.currentMembersCount,
    this.drawType,
    this.termsAndConditions,
    this.memberships,
    this.createdAt,
    this.updatedAt,
    this.package,
  });

  factory EqubGroup.fromJson(Map<String, dynamic> json) {
    return EqubGroup(
      id: json['id'] as int?,
      equbPackageId: json['equb_package_id']?.toString(),
      name: (json['name'] ?? json['equb_group_name'])?.toString(),
      fixedContributionAmount: json['fixed_contribution_amount']?.toString(),
      contributionFrequencyDays: json['contribution_frequency_days']
          ?.toString(),
      durationType: json['duration_type']?.toString(),
      durationDays: json['duration_days']?.toString(),
      duration: json['duration']?.toString(),
      registrationOpenAt: json['registration_open_at']?.toString(),
      registrationCloseAt: json['registration_close_at']?.toString(),
      equbStartDate: json['equb_start_date']?.toString(),
      equbEndDate: json['equb_end_date']?.toString(),
      maxMembers: json['max_members']?.toString(),
      status: json['status']?.toString(),
      isLocked: json['is_locked'] as bool?,
      currentMembersCount: json['current_members_count']?.toString(),
      drawType: json['draw_type']?.toString(),
      termsAndConditions: json['terms_and_conditions']?.toString(),
      memberships: (json['equb-memberships'] ?? json['memberships']) != null
          ? ((json['equb-memberships'] ?? json['memberships']) as List)
                .map((m) => EqubMembership.fromJson(m as Map<String, dynamic>))
                .toList()
          : null,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      package: json['package'] != null
          ? EqubPackage.fromJson(json['package'] as Map<String, dynamic>)
          : ((json['package_name'] ?? json['equb_package_name']) != null
                ? EqubPackage(
                    name: (json['package_name'] ?? json['equb_package_name'])
                        ?.toString(),
                  )
                : null),
    );
  }

  bool get isJoined => memberships != null && memberships!.isNotEmpty;

  EqubGroup copyWith({
    int? id,
    String? equbPackageId,
    String? name,
    String? fixedContributionAmount,
    String? contributionFrequencyDays,
    String? durationType,
    String? durationDays,
    String? duration,
    String? registrationOpenAt,
    String? registrationCloseAt,
    String? equbStartDate,
    String? equbEndDate,
    String? maxMembers,
    String? status,
    bool? isLocked,
    String? currentMembersCount,
    String? drawType,
    String? termsAndConditions,
    List<EqubMembership>? memberships,
    String? createdAt,
    String? updatedAt,
    EqubPackage? package,
  }) {
    return EqubGroup(
      id: id ?? this.id,
      equbPackageId: equbPackageId ?? this.equbPackageId,
      name: name ?? this.name,
      fixedContributionAmount:
          fixedContributionAmount ?? this.fixedContributionAmount,
      contributionFrequencyDays:
          contributionFrequencyDays ?? this.contributionFrequencyDays,
      durationType: durationType ?? this.durationType,
      durationDays: durationDays ?? this.durationDays,
      duration: duration ?? this.duration,
      registrationOpenAt: registrationOpenAt ?? this.registrationOpenAt,
      registrationCloseAt: registrationCloseAt ?? this.registrationCloseAt,
      equbStartDate: equbStartDate ?? this.equbStartDate,
      equbEndDate: equbEndDate ?? this.equbEndDate,
      maxMembers: maxMembers ?? this.maxMembers,
      status: status ?? this.status,
      isLocked: isLocked ?? this.isLocked,
      currentMembersCount: currentMembersCount ?? this.currentMembersCount,
      drawType: drawType ?? this.drawType,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      memberships: memberships ?? this.memberships,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      package: package ?? this.package,
    );
  }

  // Helper getters for backward compatibility with UI
  int? get packageId => package?.id ?? int.tryParse(equbPackageId ?? '');
  String? get packageName => name ?? package?.name;
  int? get memberCount => int.tryParse(currentMembersCount ?? '');
  int? get birrPerDay => (fixedContributionAmount != null)
      ? double.tryParse(fixedContributionAmount!)?.toInt()
      : (package?.fixedContributionAmount != null
            ? double.tryParse(package!.fixedContributionAmount!)?.toInt()
            : null);
  String? get durationLabel => durationDays;

  String? get frequencyLabel {
    final freq =
        contributionFrequencyDays ??
        package?.contributionFrequencyDays?.toString();
    if (freq == null) return null;
    if (freq == '1') return 'daily';
    if (freq == '7') return 'weekly';
    if (freq == '30') return 'monthly';
    return freq;
  }
}

/// User's joined equb membership from api/member/equb-memberships
class EqubMembership {
  final int? id;
  final int? equbGroupId;
  final String? memberId;
  final double? contributionAmount;
  final int? contributionFrequencyDays;
  final String? joinDate;
  final String? calculatedEndDate;
  final int? drawPosition;
  final bool? hasWon;
  final String? winDate;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final String? nextDrawDate;
  final double? contributedAmount;
  final double? expectedTotalAmount;
  final double? remainingAmount;
  final EqubGroup? equbGroup;
  final Map<String, dynamic>? member;
  final List<EqubPayment>? payments;
  final List<EqubPaymentSchedule>? paymentSchedule;
  final String? duration;
  final EqubDraw? drawInfo;

  const EqubMembership({
    this.id,
    this.equbGroupId,
    this.memberId,
    this.contributionAmount,
    this.contributionFrequencyDays,
    this.joinDate,
    this.calculatedEndDate,
    this.drawPosition,
    this.hasWon,
    this.winDate,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.nextDrawDate,
    this.contributedAmount,
    this.expectedTotalAmount,
    this.remainingAmount,
    this.equbGroup,
    this.member,
    this.payments,
    this.duration,
    this.paymentSchedule,
    this.drawInfo,
  });

  factory EqubMembership.fromJson(Map<String, dynamic> json) {
    final groupJson = json['equb_group'] ?? json['equbGroup'];
    EqubGroup? group;
    if (groupJson != null && groupJson is Map<String, dynamic>) {
      // Break recursion: remove memberships from the nested group
      final groupMap = Map<String, dynamic>.from(groupJson);
      groupMap.remove('memberships');
      groupMap.remove('equb-memberships');
      group = EqubGroup.fromJson(groupMap);
    } else {
      // Fallback: Construct group from flat fields if nested object is missing
      final flatGroupId = json['equb_group_id'];
      final flatGroupName = json['equb_group_name'];
      final flatPackageName =
          json['equb_package_name'] ?? json['equb_group_package_name'];

      if (flatGroupId != null) {
        int? gid;
        if (flatGroupId is int) {
          gid = flatGroupId;
        } else if (flatGroupId is String) {
          gid = int.tryParse(flatGroupId);
        }

        if (gid != null) {
          group = EqubGroup(
            id: gid,
            name: flatGroupName?.toString(),
            equbPackageId: null, // Not provided directly
            package: flatPackageName != null
                ? EqubPackage(name: flatPackageName.toString())
                : null,
          );
        }
      }
    }

    final amt = json['contribution_amount'];
    final amtVal = amt is num
        ? amt.toDouble()
        : (amt is String ? double.tryParse(amt) : null);

    final freq = json['contribution_frequency_days'];
    int? freqVal;
    if (freq is int) {
      freqVal = freq;
    } else if (freq is num) {
      freqVal = freq.toInt();
    } else if (freq != null) {
      freqVal = int.tryParse(freq.toString());
    }

    final groupId = json['equb_group_id'] ?? json['equbGroupId'];
    int? groupIdVal;
    if (groupId is int) {
      groupIdVal = groupId;
    } else if (groupId != null) {
      groupIdVal = int.tryParse(groupId.toString());
    }
    if (groupIdVal == null || groupIdVal <= 0) {
      groupIdVal = group?.id;
    }

    logger(
      "Parsed Membership: ID=${json['id']}, GroupId=$groupIdVal, Group=${group?.name}",
    );

    return EqubMembership(
      id: json['id'] as int?,
      equbGroupId: groupIdVal,
      memberId: json['member_id']?.toString(),
      contributionAmount: amtVal,
      contributionFrequencyDays: freqVal,
      joinDate: json['join_date']?.toString(),
      calculatedEndDate: json['calculated_end_date']?.toString(),
      drawPosition: json['draw_position'] as int?,
      hasWon: json['has_won'] as bool?,
      winDate: json['win_date']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      nextDrawDate: json['next_draw_date']?.toString() ?? json['nextDrawDate']?.toString(),
      contributedAmount: json['contributed_amount'] is num
          ? (json['contributed_amount'] as num).toDouble()
          : (json['contributed_amount'] is String
                ? double.tryParse(json['contributed_amount'])
                : null),
      expectedTotalAmount: json['expected_total_amount'] is num
          ? (json['expected_total_amount'] as num).toDouble()
          : (json['expected_total_amount'] is String
                ? double.tryParse(json['expected_total_amount'])
                : null),
      remainingAmount: json['remaining_amount'] is num
          ? (json['remaining_amount'] as num).toDouble()
          : (json['remaining_amount'] is String
                ? double.tryParse(json['remaining_amount'])
                : null),
      equbGroup: group,
      member: json['member'] as Map<String, dynamic>?,
      payments: json['payments'] != null
          ? (json['payments'] as List)
                .map((p) => EqubPayment.fromJson(p as Map<String, dynamic>))
                .toList()
          : null,
      duration: json['duration']?.toString(),
      paymentSchedule: (json['payment_schedule'] ?? json['payment-schedule']) != null
          ? ((json['payment_schedule'] ?? json['payment-schedule']) as List)
                .map((p) => EqubPaymentSchedule.fromJson(p as Map<String, dynamic>))
                .toList()
          : null,
      drawInfo: json['draw_info'] != null
          ? EqubDraw.fromJson(json['draw_info'] as Map<String, dynamic>)
          : null,
    );
  }

  String? get groupName =>
      equbGroup?.name ??
      equbGroup?.packageName ??
      'Equb #${equbGroupId ?? id}';
}

class EqubPayment {
  final int? id;
  final double? amount;
  final String? status;
  final String? paymentDate;
  final String? createdAt;

  EqubPayment({
    this.id,
    this.amount,
    this.status,
    this.paymentDate,
    this.createdAt,
  });

  factory EqubPayment.fromJson(Map<String, dynamic> json) {
    var amt = json['amount'];
    double? amtVal;
    if (amt is num) {
      amtVal = amt.toDouble();
    } else if (amt is String) {
      amtVal = double.tryParse(amt);
    }

    return EqubPayment(
      id: json['id'] as int?,
      amount: amtVal,
      status: json['status']?.toString(),
      paymentDate: json['payment_date']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  bool get isPaid =>
      status?.toLowerCase() == 'paid' || status?.toLowerCase() == 'successful';
}

class EqubDraw {
  final int? id;
  final int? round;
  final String? drawDate;
  final String? status;
  final Map<String, dynamic>? winner;

  // New fields from draw_info
  final String? equbGroupName;
  final String? equbPackageName;
  final int? equbGroupId;
  final int? executedByAdminId;
  final int? winnerMembershipId;
  final double? winnerExpectedTotalAmount;
  final double? winnerTotalPaid;
  final double? winnerRemainingAmount;
  final String? winnerMemberName;
  final int? winnerMemberId;
  final double? totalWon;

  EqubDraw({
    this.id,
    this.round,
    this.drawDate,
    this.status,
    this.winner,
    this.equbGroupName,
    this.equbPackageName,
    this.equbGroupId,
    this.executedByAdminId,
    this.winnerMembershipId,
    this.winnerExpectedTotalAmount,
    this.winnerTotalPaid,
    this.winnerRemainingAmount,
    this.winnerMemberName,
    this.winnerMemberId,
    this.totalWon,
  });

  factory EqubDraw.fromJson(Map<String, dynamic> json) {
    return EqubDraw(
      id: json['id'] as int?,
      round: json['round'] as int?,
      drawDate: json['draw_date']?.toString(),
      status: json['status']?.toString(),
      winner: json['winner'] as Map<String, dynamic>?,
      equbGroupName: json['equb_group_name']?.toString(),
      equbPackageName: json['equb_package_name']?.toString(),
      equbGroupId: int.tryParse(json['equb_group_id']?.toString() ?? ''),
      executedByAdminId: int.tryParse(
        json['executed_by_admin_id']?.toString() ?? '',
      ),
      winnerMembershipId: int.tryParse(
        json['winner_membership_id']?.toString() ?? '',
      ),
      winnerExpectedTotalAmount: double.tryParse(
        json['winner_expected_total_amount']?.toString() ?? '',
      ),
      winnerTotalPaid: double.tryParse(
        json['winner_total_paid']?.toString() ?? '',
      ),
      winnerRemainingAmount: double.tryParse(
        json['winner_remaining_amount']?.toString() ?? '',
      ),
      winnerMemberName: json['winner_member_name']?.toString(),
      winnerMemberId: int.tryParse(json['winner_member_id']?.toString() ?? ''),
      totalWon: double.tryParse(json['total_won']?.toString() ?? ''),
    );
  }
}

class EqubPaymentSchedule {
  final int? round;
  final String? expectedDate;
  final double? amount;
  final String? status;

  EqubPaymentSchedule({
    this.round,
    this.expectedDate,
    this.amount,
    this.status,
  });

  factory EqubPaymentSchedule.fromJson(Map<String, dynamic> json) {
    var amt = json['amount'];
    double? amtVal;
    if (amt is num) {
      amtVal = amt.toDouble();
    } else if (amt is String) {
      amtVal = double.tryParse(amt);
    }

    return EqubPaymentSchedule(
      round: json['round'] as int?,
      expectedDate: json['expected_date']?.toString(),
      amount: amtVal,
      status: json['status']?.toString(),
    );
  }
}
