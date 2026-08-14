import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/exceptions.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class EkubPaymentsRepository {
  final Dio dio;

  EkubPaymentsRepository({required this.dio});

  Future<Either<Failure, List<EkubPaymentItem>>> getPayments() async {
    try {
      // 1. Fetch User's Memberships
      final result = await dio.get(MemberEndpoints.equbMemberships());
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }
      final raw = result.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is Map && raw['memberships'] is List) {
        list = raw['memberships'] as List;
      }

      final memberships = list
          .whereType<Map<String, dynamic>>()
          .map(EqubMembership.fromJson)
          .toList();

      // 2. Generate Consolidated Schedule
      List<EkubPaymentItem> allItems = [];
      final now = DateTime.now();

      for (final membership in memberships) {
        // Skip memberships without necessary data
        if (membership.equbGroup == null) continue;

        final group = membership.equbGroup!;
        final startDateStr = group.equbStartDate;
        if (startDateStr == null) continue;

        final startDate = DateTime.tryParse(startDateStr);
        if (startDate == null) continue;

        final endDate = DateTime.tryParse(group.equbEndDate ?? '');
        final freq = int.tryParse(
          membership.contributionFrequencyDays?.toString() ??
              group.contributionFrequencyDays ??
              group.package?.contributionFrequencyDays ??
              '1',
        );
        final amount =
            membership.contributionAmount?.toDouble() ??
            group.birrPerDay?.toDouble() ??
            0.0;

        // Generate schedule for this membership
        final schedule = PaymentCalculator.generateSchedule(
          startDate: startDate,
          endDate: endDate,
          frequencyDays: freq,
          amount: amount,
          payments: membership.payments ?? [], // Use payments from membership
          now: now,
        );

        // Convert to UI items
        final items = schedule.map((item) {
          EkubPaymentStatus status;
          switch (item.status) {
            case PaymentScheduleStatus.paid:
              status = EkubPaymentStatus.paid;
              break;
            case PaymentScheduleStatus.unpaid:
              status = EkubPaymentStatus.unpaid;
              break;
            case PaymentScheduleStatus.future:
              status = EkubPaymentStatus.future;
              break;
            case PaymentScheduleStatus.pending:
              status = EkubPaymentStatus
                  .unpaid; // Treat as unpaid in this simplified view for now, or add pending to EkubPaymentStatus
              break;
          }

          return EkubPaymentItem(
            packageLabel:
                '${group.name ?? group.packageName} - Day ${item.index}',
            amount: item.amount.toInt(),
            status: status,
            time: item.dueDate,
            method: item.paidPayment?.paymentDate != null
                ? 'Paid on ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item.paidPayment!.paymentDate!))}'
                : (status == EkubPaymentStatus.future
                      ? 'Due later'
                      : 'Past Due'),
          );
        }).toList();

        allItems.addAll(items);
      }

      // 3. Sort by Date
      // Sort: Unpaid (Past/Today) -> Future -> Paid?
      // Or just chronological? Usually chronological is best for history.
      // Let's sort strictly by due date descending (newest first).
      allItems.sort((a, b) => b.time.compareTo(a.time));

      return Right(allItems);
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

enum EkubPaymentStatus { paid, unpaid, future }

class EkubPaymentItem {
  final String packageLabel;
  final int amount;
  final EkubPaymentStatus status;
  final DateTime time;
  final String method;

  EkubPaymentItem({
    required this.packageLabel,
    required this.amount,
    required this.status,
    required this.time,
    required this.method,
  });
}
