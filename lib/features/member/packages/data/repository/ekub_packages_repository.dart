import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';
import 'package:niya_equb/core/service/payments/payment_bridge.dart';
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

  /// Records one contribution and gets back a signed bank order.
  ///
  /// Returns a [PaymentSession] rather than a URL. Under a hosted checkout this
  /// handed back a link to open in a browser; these bank integrations have no
  /// such page — the order is authorised inside the bank's own app, from a
  /// payload the server signed. See PaymentBridge.
  ///
  /// [provider] is a gateway slug from GET /api/payments/providers. It is
  /// required rather than defaulted: with several banks live, silently picking
  /// one would charge a member through a bank they did not choose.
  ///
  /// [customerIdentifier] is who the bank's own host app says is using it,
  /// from PaymentBridge.fetchCustomerIdentifier(). The server mints this
  /// order's bank access token from it; without a token the bank refuses the
  /// order as an incomplete request, whatever the payload says. Optional
  /// because it does not exist outside a host app — the server falls back to a
  /// configured identifier, which is what makes UAT testable from a browser.
  ResultFuture<PaymentSession> initiateEqubPayment({
    required int membershipId,
    required double amount,
    required String paymentDate,
    required String provider,
    String? customerIdentifier,
  }) async {
    try {
      // Asked of the host app now rather than held from sign-in, so the token
      // the bank mints belongs to whoever is actually at the phone.
      final identifier = customerIdentifier ?? await _customerIdentifier(provider);

      final data = {
        'equb_membership_id': membershipId,
        'amount': amount,
        'payment_method': provider,
        'payment_date': paymentDate,
        // Omitted rather than sent null: the server distinguishes "the client
        // could not ask" from "the client asked and got nothing".
        if (identifier != null && identifier.isNotEmpty)
          'customer_identifier': identifier,
      };
      logger(data);
      final result = await dio.post(MemberEndpoints.equbPayments(), data: data);

      final session = PaymentSession.tryParse(result.data);
      if (session == null) {
        throw ServerException(
          "Failed to start the payment",
          result.statusCode,
        );
      }

      return Right(session);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// The banks a member can pay through right now.
  ///
  /// Asked of the server rather than hardcoded. Niya collects through several
  /// banks and the list changes without an app release; a client-side list
  /// would offer banks that had been switched off and miss ones that had been
  /// added.
  ResultFuture<List<PaymentClientConfig>> fetchPaymentProviders() async {
    try {
      final result = await dio.get(MemberEndpoints.paymentProviders());
      final list = _unwrapList(result.data, ['providers']);

      return Right(
        list
            .whereType<Map<String, dynamic>>()
            .map(PaymentClientConfig.fromJson)
            .toList(growable: false),
      );
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Provider descriptors, remembered for the session.
  ///
  /// The list changes only when an operator configures or withdraws a bank on
  /// the server, so re-fetching it on every tap would buy nothing and cost a
  /// round trip on the slowest screen in the app. A stale entry costs one
  /// failed payment and is gone by the next app start.
  static List<PaymentClientConfig>? _providerCache;

  /// Who the bank's host app says is using the mini app.
  ///
  /// THE BANK MINTS THE ORDER'S ACCESS TOKEN FROM THIS, so in production it
  /// must be the live customer. A token issued for one person, against a
  /// payment another person authorises with their PIN, is refused — and during
  /// UAT that surfaced as "invalid signature", with nothing to indicate the
  /// cause. Dashen confirmed on 16 Sep 2026: hard-coding one is acceptable for
  /// testing, never for production.
  ///
  /// Returns null wherever there is no host app to ask — a phone, or a browser
  /// tab opened outside the SuperApp. The server then falls back to its
  /// configured identifier, which is what keeps UAT testable from a desk and
  /// which must be cleared before go-live.
  ///
  /// NEVER THROWS. Failing to identify the customer is not a reason to abandon
  /// a payment the server may still be able to complete; the request simply
  /// goes without the field, and the server decides.
  /// Who the bank's host app says is using it, and which bank that is.
  ///
  /// For signing in without a password when the app starts inside a bank
  /// super-app (see AuthRepository.signInWithHostApp). Walks the live banks
  /// and asks the first one whose host app is actually present.
  ///
  /// Null on a phone, in an ordinary browser tab, when no bank is configured,
  /// or when the host app does not answer — every one of which just means
  /// "use the ordinary login screen". NEVER THROWS.
  Future<({String provider, String identifier, String? appCode, String? stage})?>
      hostAppIdentity() async {
    try {
      if (!PaymentBridges.supportedOnThisPlatform) return null;

      final result = await fetchPaymentProviders();
      final providers = result.fold<List<PaymentClientConfig>>(
        (_) => const <PaymentClientConfig>[],
        (list) => list,
      );
      if (providers.isNotEmpty) _providerCache = providers;

      for (final config in providers) {
        if (config.slug.trim().isEmpty) continue;

        final bridge = PaymentBridges.of(config);
        if (!bridge.isAvailable) continue;

        final identifier = (await bridge.fetchCustomerIdentifier())?.trim();
        if (identifier == null || identifier.isEmpty) continue;

        return (
          provider: config.slug,
          identifier: identifier,
          appCode: config.appCode,
          stage: config.stage,
        );
      }
      return null;
    } catch (e) {
      logger('Could not read the host app identity: $e');
      return null;
    }
  }

  /// The payment this member tried most recently, if it was within
  /// [withinMinutes] — whatever has happened to it since.
  ///
  /// The server-side twin of PreferencesService.takePaymentReturn(). The
  /// local note is lost whenever the SuperApp's reload wipes the page's
  /// storage — which is also when the member finds themselves signed out, the
  /// case Dashen's QA reported — but the server still has the payment, and
  /// that is enough to reopen the Equb and show where it stands.
  ///
  /// The newest ATTEMPT, not the newest pending one. A member who cancelled
  /// one attempt and then paid with a second must be shown the second, even
  /// once it has been confirmed; picking the cancelled one would reopen the
  /// Equb on a payment that is going nowhere. Whatever its status, the Equb
  /// screen reports it correctly: confirmed, declined, or still confirming.
  ///
  /// NEVER THROWS, and gives up after a few seconds: nothing here is worth
  /// holding the member up for.
  Future<({int groupId, String reference})?> latestPaymentAttempt({
    int withinMinutes = 5,
  }) async {
    try {
      final result = await dio
          .get(
            MemberEndpoints.equbPayments(),
            queryParameters: {
              'recent_minutes': withinMinutes,
              'per_page': 1,
            },
          )
          .timeout(const Duration(seconds: 5));

      for (final raw in _unwrapList(result.data, const ['payments'])
          .whereType<Map<String, dynamic>>()) {
        final group = raw['equb_group_id'];
        final groupId = group is int ? group : int.tryParse('${group ?? ''}');
        final batch = raw['batch_reference']?.toString() ?? '';
        final reference =
            batch.isNotEmpty ? batch : (raw['reference']?.toString() ?? '');

        if (groupId != null && reference.isNotEmpty) {
          return (groupId: groupId, reference: reference);
        }
      }
      return null;
    } catch (e) {
      logger('Could not look up a payment in flight: $e');
      return null;
    }
  }

  Future<String?> _customerIdentifier(String provider) async {
    try {
      // On a phone there is no host app at all, so this costs nothing rather
      // than a wasted round trip before an answer that is always null.
      if (!PaymentBridges.supportedOnThisPlatform) return null;

      // Declared non-nullable, and fold's type argument given explicitly.
      // Left to infer from the assignment target, dartz picks up the nullable
      // type of the cache, the local never promotes, and neither isNotEmpty
      // nor the loop below will compile.
      List<PaymentClientConfig> providers = _providerCache ?? const [];

      if (providers.isEmpty) {
        final result = await fetchPaymentProviders();

        providers = result.fold<List<PaymentClientConfig>>(
          (_) => const <PaymentClientConfig>[],
          (list) => list,
        );

        if (providers.isNotEmpty) _providerCache = providers;
      }

      PaymentClientConfig? config;
      for (final entry in providers) {
        if (entry.slug == provider) {
          config = entry;
          break;
        }
      }

      if (config == null) return null;

      final bridge = PaymentBridges.of(config);
      if (!bridge.isAvailable) return null;

      return await bridge.fetchCustomerIdentifier();
    } catch (e) {
      logger('Could not read the customer identifier: $e');
      return null;
    }
  }

  /// Settles several contributions under one bank transaction.
  ///
  /// A member who holds places for "My Responsibility People" owes one
  /// contribution per place, every round. Each place keeps its own payment
  /// record on the server; this charges the member once, for the total.
  ///
  /// The amount is deliberately not sent — the server reads each place's
  /// contribution from its own membership, so the client cannot understate
  /// what is owed. That mattered under Chapa and matters more now: the total
  /// is signed into the order, so a client-supplied figure would be signing
  /// its own price.
  ///
  /// [customerIdentifier] carries the same meaning as on the single-payment
  /// call above.
  ResultFuture<PaymentSession> initiateBatchEqubPayment({
    required List<int> membershipIds,
    required String paymentDate,
    required String provider,
    String? customerIdentifier,
  }) async {
    try {
      final identifier = customerIdentifier ?? await _customerIdentifier(provider);

      final data = {
        'equb_membership_ids': membershipIds,
        'payment_method': provider,
        'payment_date': paymentDate,
        if (identifier != null && identifier.isNotEmpty)
          'customer_identifier': identifier,
      };
      logger(data);

      final result = await dio.post(
        MemberEndpoints.equbPaymentsBatch(),
        data: data,
      );

      final session = PaymentSession.tryParse(result.data);
      if (session == null) {
        throw ServerException(
          "Failed to start the payment",
          result.statusCode,
        );
      }

      return Right(session);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

/// One signed bank order, ready to hand to that bank's app.
///
/// Both payload maps are the server's own bytes and are passed through
/// untouched. The order carries an HMAC over its own contents, so normalising
/// a number or re-ordering a key here would make the bank reject it — which is
/// exactly the protection that lets the amount be server-derived.
///
/// [client] is why the apps need no per-bank code: it says which host app to
/// talk to and how, so the same screen presents a Dashen order and a CBE order
/// without knowing either bank exists.
class PaymentSession {
  final Map<String, dynamic> orderPayload;
  final Map<String, dynamic> authPayload;
  final String reference;

  /// Which bank signed this order.
  final String provider;

  /// How to reach that bank's app. Null on a response from an older server,
  /// which the payment screen renders as "not available here" rather than
  /// guessing a bridge name.
  final PaymentClientConfig? client;

  /// Present on a batch, null on a single contribution.
  final double? totalAmount;
  final int? contributions;

  const PaymentSession({
    required this.orderPayload,
    required this.authPayload,
    required this.reference,
    required this.provider,
    this.client,
    this.totalAmount,
    this.contributions,
  });

  /// Reads a session out of a create-payment response, or null if the response
  /// does not carry one.
  ///
  /// Null rather than an exception, so the caller decides what to say. A
  /// response without an order is a server-side failure the member cannot act
  /// on, and it should not surface as a parse error.
  static PaymentSession? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final order = raw['order_payload'];
    final auth = raw['auth_payload'];
    final reference = raw['reference'];

    if (order is! Map || reference == null) return null;

    final total = raw['total_amount'];
    final client = raw['client'];

    return PaymentSession(
      orderPayload: Map<String, dynamic>.from(order),
      authPayload: auth is Map
          ? Map<String, dynamic>.from(auth)
          : const <String, dynamic>{},
      reference: reference.toString(),
      provider: raw['provider']?.toString() ?? '',
      client: client is Map
          ? PaymentClientConfig.fromJson(Map<String, dynamic>.from(client))
          : null,
      totalAmount: total is num
          ? total.toDouble()
          : (total is String ? double.tryParse(total) : null),
      contributions: raw['contributions'] is int
          ? raw['contributions'] as int
          : int.tryParse(raw['contributions']?.toString() ?? ''),
    );
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

  // ------------------------------------------------------------------
  // The caller's places in this Equb
  //
  // `memberships` is scoped by the API to the signed-in member: their own
  // membership plus every place they hold for someone under "My Responsibility
  // People". Reading `.first` gives their own place and nothing else, which is
  // why the payment screen used to quote one contribution when several were
  // owed. These getters are the honest reads.
  // ------------------------------------------------------------------

  /// Every place the signed-in member pays for here — their own and any held
  /// for other people.
  List<EqubMembership> get myPlaces => memberships ?? const [];

  /// The member's own membership. Null if they only hold places for others,
  /// which the API allows but the app does not currently create.
  EqubMembership? get myMembership {
    for (final m in myPlaces) {
      if (!m.isResponsibilitySeat) return m;
    }
    return myPlaces.isNotEmpty ? myPlaces.first : null;
  }

  /// Places held for someone else, in the order the API returned them.
  List<EqubMembership> get myResponsibilityPlaces =>
      myPlaces.where((m) => m.isResponsibilitySeat).toList(growable: false);

  /// What the member owes for one round across every place they pay for.
  ///
  /// Summed from each place's own contribution rather than multiplying the
  /// group amount by a head-count, so a place that joined on a different
  /// package or amount is still counted at what it actually costs.
  double get myRoundTotal {
    if (myPlaces.isEmpty) return (birrPerDay ?? 0).toDouble();

    var total = 0.0;
    for (final m in myPlaces) {
      total += m.contributionAmount ?? (birrPerDay ?? 0).toDouble();
    }
    return total;
  }

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
  /// The server's verdict on whether this membership may be left.
  ///
  /// Null when the payload has no `can_leave` key at all — an older backend,
  /// a cached response written before this shipped, or a resource that does
  /// not serialise it. That is a genuinely different case from `false`, and
  /// collapsing the two is what removed the Leave button from members who had
  /// every right to it. Read [canLeaveEqub], not this.
  final bool? serverCanLeave;
  final String? exitBlockReason;
  final bool hasReceivedPayout;

  /// True when this row is a place held for someone with no Niya account —
  /// "My Responsibility People". It owes a contribution every round like any
  /// other place; the difference is only that [sponsorName] pays it.
  final bool isResponsibilitySeat;

  /// Whose place this is. The member's own name on a normal membership, the
  /// name the sponsor typed in on a held place.
  final String? displayName;
  final String? sponsorName;
  final int? sponsorMemberId;
  final String? relation;

  final double? totalWonAmount;
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
    this.serverCanLeave,
    this.exitBlockReason,
    this.hasReceivedPayout = false,
    this.isResponsibilitySeat = false,
    this.displayName,
    this.sponsorName,
    this.sponsorMemberId,
    this.relation,
    this.totalWonAmount,
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
      // Absent key stays null; only an explicit value becomes a bool.
      serverCanLeave:
          json.containsKey('can_leave') ? json['can_leave'] == true : null,
      exitBlockReason: json['exit_block_reason']?.toString(),
      hasReceivedPayout:
          json['has_received_payout'] == true || json['has_won'] == true,
      isResponsibilitySeat: json['is_responsibility_seat'] == true,
      displayName: json['display_name']?.toString(),
      sponsorName: json['sponsor_name']?.toString(),
      sponsorMemberId: json['sponsor_member_id'] == null
          ? null
          : int.tryParse(json['sponsor_member_id'].toString()),
      relation: json['responsibility_relation']?.toString(),
      totalWonAmount: json['total_won_amount'] is num
          ? (json['total_won_amount'] as num).toDouble()
          : (json['total_won_amount'] is String
                ? double.tryParse(json['total_won_amount'])
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

  /// Whether to offer the Leave button.
  ///
  /// Three cases, in order:
  ///
  ///   1. The server answered — use its answer. It can see the draw tables and
  ///      this cannot, so it is authoritative whenever it speaks.
  ///   2. No answer, but this member has won — never offer it. `has_won` has
  ///      been in the payload since long before `can_leave` existed, so this
  ///      holds even against an old backend.
  ///   3. No answer, no win — fall back to the original rule: you may leave
  ///      until your first contribution lands.
  ///
  /// Case 3 is why this is not simply "deny unless told otherwise". Failing
  /// closed on a missing field took the button away from members who had done
  /// nothing but join, which is a real feature lost to guard against a case
  /// the win check in step 2 already covers. And the button is not the
  /// enforcement — the API refuses on its own — so the worst outcome here is
  /// a request that comes back with a clear reason, not a member walking out
  /// with the pot.
  bool get canLeaveEqub {
    if (serverCanLeave != null) return serverCanLeave!;
    if (hasReceivedPayout) return false;
    return (contributedAmount ?? 0) <= 0;
  }

  /// The name to show for this place. Falls back to the member's own name so
  /// an older payload without `display_name` still reads correctly.
  String get placeName =>
      displayName ?? (member?['full_name']?.toString() ?? 'Member');

  /// The next draw, as a calendar day, when it is today or later.
  ///
  /// The server's `next_draw_date` is used while it is still ahead, and its
  /// null is respected: it means no round is left, including on the day of
  /// the final draw once that draw has run. Older servers sent the round
  /// NEAREST to today, which could be yesterday's, and a "next draw" in the
  /// past reads as a broken app. For such a date the first round on this
  /// place's own schedule that is still ahead is used instead, or null once
  /// no round is left.
  DateTime? get upcomingDrawDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final fromServer = calendarDay(nextDrawDate);
    if (fromServer == null) return null;
    if (!fromServer.isBefore(today)) return fromServer;

    final rounds = [
      for (final row in paymentSchedule ?? const <EqubPaymentSchedule>[])
        if (calendarDay(row.expectedDate) case final day?) day,
    ]..sort();

    for (final day in rounds) {
      if (!day.isBefore(today)) return day;
    }
    return null;
  }

  /// The calendar day a server date names, read from its first ten characters
  /// ("2026-09-30") so that a timezone offset can never move it to the day
  /// before or after. Null for anything that is not a date.
  static DateTime? calendarDay(String? raw) {
    if (raw == null || raw.length < 10) return null;
    final parsed = DateTime.tryParse(raw.substring(0, 10));
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }
}

class EqubPayment {
  final int? id;
  final double? amount;
  final String? status;
  final String? paymentDate;
  final String? createdAt;

  /// The merchant order id the bank was sent for this contribution.
  final String? reference;

  /// Shared by every contribution settled in one charge, when several places
  /// were paid together. When set, it is this — not [reference] — that the
  /// bank knows the payment by.
  final String? batchReference;

  EqubPayment({
    this.id,
    this.amount,
    this.status,
    this.paymentDate,
    this.createdAt,
    this.reference,
    this.batchReference,
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
      reference: json['reference']?.toString(),
      batchReference: json['batch_reference']?.toString(),
    );
  }

  bool get isPaid =>
      status?.toLowerCase() == 'paid' || status?.toLowerCase() == 'successful';

  /// Authorised or attempted, and not yet confirmed either way by the bank.
  bool get isPending => status?.toLowerCase() == 'pending';

  bool get isFailed => status?.toLowerCase() == 'failed';

  /// True when this row is the contribution, or one of the contributions,
  /// behind the bank order [bankReference].
  bool belongsTo(String bankReference) =>
      bankReference.isNotEmpty &&
      (reference == bankReference || batchReference == bankReference);
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
