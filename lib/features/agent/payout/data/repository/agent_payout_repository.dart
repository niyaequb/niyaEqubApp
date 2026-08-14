import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';
import 'package:niya_equb/features/agent/dashboard/data/repository/agent_dashboard_repository.dart';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class AgentPayoutRepository {
  final Dio dio;
  final AgentDashboardRepository dashboardRepository;
  final AuthRepository authRepository;

  AgentPayoutRepository({
    required this.dio,
    required this.dashboardRepository,
    required this.authRepository,
  });

  /// Fetches dashboard data (for pending amount)
  ResultFuture<AgentDashboardData> fetchDashboard() async {
    return dashboardRepository.fetchDashboard();
  }

  /// Fetches current user profile to check bank info
  ResultFuture<UserModel> fetchProfile() async {
    return authRepository.me();
  }

  /// Returns true if user has bank info (provider, account number, holder name)
  bool hasBankInfo(UserModel user) {
    return (user.bankName?.trim().isNotEmpty == true) &&
        (user.accountNumber?.trim().isNotEmpty == true) &&
        (user.accountHolderName?.trim().isNotEmpty == true);
  }

  /// Fetches list of payments from api/agent/payments
  /// [status] filters by: pending, completed, failed. Pass null for all.
  ResultFuture<List<AgentPayment>> fetchPayments({String? status}) async {
    try {
      final queryParams = status != null && status.isNotEmpty && status != 'all'
          ? {'status': status}
          : null;
      final result = await dio.get(
        AgentEndpoints.payments(),
        queryParameters: queryParams,
      );
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final raw = result.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is Map && raw['payments'] is List) {
        list = raw['payments'] as List;
      }
      final payments = list
          .whereType<Map<String, dynamic>>()
          .map(AgentPayment.fromJson)
          .toList();
      return Right(payments);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  /// Requests payout via POST api/agent/payments with { amount }
  ResultFuture<void> requestPayment(double amount) async {
    try {
      await dio.post(
        AgentEndpoints.payments(),
        data: {'amount': amount},
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

class AgentPayment {
  final int? id;
  final String? agentId;
  final double? amount;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final String? status;
  final String? paidAt;
  final String? createdAt;

  const AgentPayment({
    this.id,
    this.agentId,
    this.amount,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.status,
    this.paidAt,
    this.createdAt,
  });

  factory AgentPayment.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return AgentPayment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      agentId: json['agent_id']?.toString(),
      amount: parseDouble(json['amount']),
      bankName: json['bank_name']?.toString(),
      accountNumber: json['account_number']?.toString(),
      accountHolderName: json['account_holder_name']?.toString(),
      status: json['status']?.toString(),
      paidAt: json['paid_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
