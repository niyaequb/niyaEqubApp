import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class AgentMembersRepository {
  final Dio dio;

  AgentMembersRepository({required this.dio});

  /// Fetches members list from api/admin/members
  ResultFuture<List<AgentMember>> fetchMembers() async {
    try {
      final result = await dio.get(AdminEndpoints.members());
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final raw = result.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        if (raw['data'] is List) {
          list = raw['data'] as List;
        } else if (raw['members'] is List) {
          list = raw['members'] as List;
        }
      }
      final members = list
          .map((e) => AgentMember.fromJson(
                e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
              ))
          .toList();
      return Right(members);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

/// Member from api/admin/members response
/// Structure: { id, full_name, registered_via, referral_code_used, registered_at, user: { id, phone, name }, agent: { id, referral_code } }
class AgentMember {
  final int? id;
  final String? name;
  final String? phone;
  final String? email;
  final String? registeredAt;
  final String? referralCodeUsed;

  const AgentMember({
    this.id,
    this.name,
    this.phone,
    this.email,
    this.registeredAt,
    this.referralCodeUsed,
  });

  factory AgentMember.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final user = json['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;

    final name = json['full_name']?.toString() ??
        json['name']?.toString() ??
        userMap?['name']?.toString() ??
        json['fullName']?.toString();

    final phone = userMap?['phone']?.toString() ?? json['phone']?.toString();

    return AgentMember(
      id: parseInt(json['id'] ?? userMap?['id']),
      name: name,
      phone: phone,
      email: json['email']?.toString() ?? userMap?['email']?.toString(),
      registeredAt: json['registered_at']?.toString(),
      referralCodeUsed: json['referral_code_used']?.toString(),
    );
  }
}
