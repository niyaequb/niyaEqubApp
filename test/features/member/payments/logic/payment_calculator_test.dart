import 'package:flutter_test/flutter_test.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';

void main() {
  group('PaymentCalculator', () {
    test('Correctly schedules payments with sequential attribution', () {
      // User data scenario:
      // Start Date: 2026-02-03
      // Frequency: 1 day
      // Duration: 90 days
      // Payments: 1 payment on 2026-02-16 (late)
      // Current Date: 2026-02-17

      final startDate = DateTime.parse("2026-02-03T12:37:43+00:00");
      final now = DateTime.parse("2026-02-17T09:14:12+03:00");

      final payment1 = EqubPayment(
        id: 28,
        amount: 500.0,
        status: 'paid',
        paymentDate: "2026-02-16T09:47:19+00:00",
        createdAt: "2026-02-16T09:47:19+00:00",
      );

      final schedule = PaymentCalculator.generateSchedule(
        startDate: startDate,
        frequencyDays: 1,
        durationDays: 90,
        amount: 500.0,
        payments: [payment1],
        now: now,
      );

      // Verify first payment matches the first due date (Feb 3)
      // Logic: The single payment covers the first slot, even if late.
      expect(schedule[0].dueDate.day, 3);
      expect(schedule[0].status, PaymentScheduleStatus.paid);
      expect(schedule[0].paidPayment, payment1);

      // Verify subsequent dates up to "now" are unpaid
      // Feb 4 should be unpaid
      expect(schedule[1].dueDate.day, 4);
      expect(schedule[1].status, PaymentScheduleStatus.unpaid);

      // Verify dates after "now" are future
      // 90 days from Feb 3 -> May 3 approx.
      // Let's check the last item
      final lastItem = schedule.last;
      expect(lastItem.status, PaymentScheduleStatus.future);
    });

    test('Handles multiple payments correctly', () {
      final startDate = DateTime(2026, 2, 1);
      final now = DateTime(2026, 2, 5);
      final p1 = EqubPayment(status: 'paid', paymentDate: '2026-02-02', id: 1);
      final p2 = EqubPayment(status: 'paid', paymentDate: '2026-02-03', id: 2);

      final schedule = PaymentCalculator.generateSchedule(
        startDate: startDate,
        frequencyDays: 1,
        durationDays: 5,
        amount: 100,
        payments: [p1, p2],
        now: now,
      );

      // Day 1 (Feb 1) -> Paid by p1
      expect(schedule[0].status, PaymentScheduleStatus.paid);
      expect(schedule[0].paidPayment, p1);

      // Day 2 (Feb 2) -> Paid by p2
      expect(schedule[1].status, PaymentScheduleStatus.paid);
      expect(schedule[1].paidPayment, p2);

      // Day 3 (Feb 3) -> Unpaid (past due)
      expect(schedule[2].status, PaymentScheduleStatus.unpaid);

      // Day 4 (Feb 4) -> Unpaid (past due)
      expect(schedule[3].status, PaymentScheduleStatus.unpaid);

      // Day 5 (Feb 5) -> Unpaid (due today, effectively past due or open?)
      // Logic says: if dueDate.isBefore(now), it's unpaid.
      // If now is exactly same day??
      // Let's check implementation: if (currentDueDate.isBefore(currentTime))
      // If currentDueDate == currentTime (down to microsecond usually false unless stripped)
      // We should treat "today" as unpaid if not paid yet.
      expect(schedule[4].status, PaymentScheduleStatus.unpaid);
    });
    test('Correctly calculates schedule using endDate', () {
      final startDate = DateTime(2026, 2, 1);
      final endDate = DateTime(2026, 2, 5); // 5 days inclusive: 1, 2, 3, 4, 5
      final now = DateTime(2026, 2, 1);

      final schedule = PaymentCalculator.generateSchedule(
        startDate: startDate,
        endDate: endDate,
        frequencyDays: 1,
        amount: 100,
        payments: [],
        now: now,
      );

      expect(schedule.length, 5);
      expect(schedule.last.dueDate, endDate);
    });
  });
}
