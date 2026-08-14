import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class AgentDashboardRepository {
  final Dio dio;

  AgentDashboardRepository({required this.dio});

  /// Fetches agent dashboard data from api/agent/dashboard
  ResultFuture<AgentDashboardData> fetchDashboard() async {
    try {
      final result = await dio.get(AgentEndpoints.dashboard());
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final raw = result.data;
      Map<String, dynamic> map = {};
      // Prefer extracting nested 'data' - API returns { "status", "data": { "referral_code", ... } }
      if (raw is Map && raw['data'] is Map) {
        map = Map<String, dynamic>.from(raw['data'] as Map);
      } else if (raw is Map && raw['dashboard'] is Map) {
        map = Map<String, dynamic>.from(raw['dashboard'] as Map);
      } else if (raw is Map<String, dynamic>) {
        map = raw;
      }
      return Right(AgentDashboardData.fromJson(map));
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Adds a member via api/agent/members
  /// Body: { name, phone, email? }
  ResultFuture<void> addMember({
    required String name,
    required String phone,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{
        'full_name': name.trim(),
        'phone': '251${phone.trim()}',
      };
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      await dio.post(AgentEndpoints.members(), data: body);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

/// Agent dashboard data from api/agent/dashboard
/// Response: { "status": "success", "data": { "agent_id", "referral_code", "members_count",
///   "total_earned", "pending_amount", "balance", "approved_amount",
///   "payment_requests_pending_amount", "payment_requests_paid_amount" } }
class AgentDashboardData {
  final int? agentId;
  final String? referralCode;
  final int? membersCount;
  final double? totalEarned;
  final double? pendingAmount;
  final double? balance;
  final double? approvedAmount;
  final double? paymentRequestsPendingAmount;
  final double? paymentRequestsPaidAmount;

  const AgentDashboardData({
    this.agentId,
    this.referralCode,
    this.membersCount,
    this.totalEarned,
    this.pendingAmount,
    this.balance,
    this.approvedAmount,
    this.paymentRequestsPendingAmount,
    this.paymentRequestsPaidAmount,
  });

  factory AgentDashboardData.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return AgentDashboardData(
      agentId: parseInt(json['agent_id'] ?? json['agentId']),
      referralCode:
          json['referral_code']?.toString() ?? json['referralCode']?.toString(),
      membersCount: parseInt(json['members_count'] ?? json['membersCount']),
      totalEarned: parseDouble(json['total_earned'] ?? json['totalEarned']),
      pendingAmount: parseDouble(
        json['pending_amount'] ?? json['pendingAmount'],
      ),
      balance: parseDouble(json['balance']),
      approvedAmount: parseDouble(
        json['approved_amount'] ?? json['approvedAmount'],
      ),
      paymentRequestsPendingAmount: parseDouble(
        json['payment_requests_pending_amount'] ??
            json['paymentRequestsPendingAmount'],
      ),
      paymentRequestsPaidAmount: parseDouble(
        json['payment_requests_paid_amount'] ??
            json['paymentRequestsPaidAmount'],
      ),
    );
  }

  String get totalCommissionFormatted {
    if (totalEarned == null) return '0';
    return 'ETB ${_formatNum(totalEarned!)}';
  }

  String get membersReferredFormatted {
    if (membersCount == null) return '0';
    return membersCount.toString();
  }

  String get pendingCommissionFormatted {
    if (pendingAmount == null) return '0';
    return 'ETB ${_formatNum(pendingAmount!)}';
  }

  String get approvedAmountFormatted {
    if (approvedAmount == null) return '0';
    return 'ETB ${_formatNum(approvedAmount!)}';
  }

  String get balanceFormatted {
    if (balance == null) return '0';
    return 'ETB ${_formatNum(balance!)}';
  }

  String get paymentRequestsPendingAmountFormatted {
    if (paymentRequestsPendingAmount == null) return '0';
    return 'ETB ${_formatNum(paymentRequestsPendingAmount!)}';
  }

  String get paymentRequestsPaidAmountFormatted {
    if (paymentRequestsPaidAmount == null) return '0';
    return 'ETB ${_formatNum(paymentRequestsPaidAmount!)}';
  }

  /// Balance available for payout request (use balance for validation).
  double get availableBalance => balance ?? 0;

  static String _formatNum(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 1);
  }
}
