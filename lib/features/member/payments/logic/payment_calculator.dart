import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';

enum PaymentScheduleStatus {
  paid,
  unpaid, // Past due
  future,
  pending,
}

class PaymentScheduleItem {
  final int index; // 1-based index
  final DateTime dueDate;
  final double amount;
  final PaymentScheduleStatus status;
  final EqubPayment?
  paidPayment; // The actual payment that covered this due date

  PaymentScheduleItem({
    required this.index,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidPayment,
  });

  @override
  String toString() {
    return 'PaymentScheduleItem(index: $index, dueDate: $dueDate, status: $status, paidPayment: ${paidPayment?.id})';
  }
}

class PaymentCalculator {
  /// Generates a schedule of payments based on start date, frequency, and existing payments.
  ///
  /// [startDate]: The date when the Equb starts (first payment due).
  /// [frequencyDays]: How often payments are due (e.g., 1 for daily, 30 for monthly).
  /// [durationDays]: Total duration of the Equb in days.
  /// [amount]: The fixed contribution amount per period.
  /// [payments]: List of existing payments made by the user.
  /// [now]: Current date/time (defaults to DateTime.now() if null).
  static List<PaymentScheduleItem> generateSchedule({
    required DateTime startDate,
    required double amount,
    required List<EqubPayment> payments,
    DateTime? endDate,
    int? frequencyDays,
    int? durationDays,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    int freq = frequencyDays ?? 1; // Default to 1 (daily) if not provided

    int totalPayments = 0;
    if (durationDays != null) {
      totalPayments = (durationDays / freq).ceil();
    } else if (endDate != null) {
      final diff = endDate.difference(startDate).inDays;
      totalPayments = (diff / freq).floor() + 1;
      if (totalPayments < 0) totalPayments = 0;
    } else {
      totalPayments = 0;
    }

    // Safety check for invalid frequency
    if (freq <= 0) totalPayments = 0;

    // Generate preliminary schedule items (initialized as Unpaid/Future)
    List<PaymentScheduleItem> schedule = [];
    DateTime currentDueDate = startDate;

    for (int i = 0; i < totalPayments; i++) {
      // Check if due date is clearly in the future (tomorrow or later)
      // We compare only the date parts to avoid "Today" being marked as future if time hasn't passed.
      final dueYMD = DateTime(
        currentDueDate.year,
        currentDueDate.month,
        currentDueDate.day,
      );
      final currentYMD = DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
      );

      PaymentScheduleStatus initialStatus = dueYMD.isAfter(currentYMD)
          ? PaymentScheduleStatus.future
          : PaymentScheduleStatus.unpaid;

      schedule.add(
        PaymentScheduleItem(
          index: i + 1,
          dueDate: currentDueDate,
          amount: amount,
          status: initialStatus,
          paidPayment: null,
        ),
      );
      currentDueDate = currentDueDate.add(Duration(days: freq));
    }

    // --- Hybrid Matching Logic ---

    // 1. Identify Valid Payments
    // Sort payments by date to be consistent
    final sortedPayments = List<EqubPayment>.from(payments)
      ..sort((a, b) {
        final aDateStr = a.paymentDate ?? a.createdAt;
        final bDateStr = b.paymentDate ?? b.createdAt;
        if (aDateStr == null || bDateStr == null) return 0;
        return DateTime.parse(aDateStr).compareTo(DateTime.parse(bDateStr));
      });
    final validPayments = sortedPayments.where((p) => p.isPaid).toList();
    final remainingPayments = List<EqubPayment>.from(validPayments);

    // 2. Pass 1: Exact Date Matching (Same Day)
    // If a payment was made exactly on a due date, assign it to that date.
    for (int i = 0; i < schedule.length; i++) {
      final item = schedule[i];

      // Find a payment made on this due date provided it hasn't been used
      final matchIndex = remainingPayments.indexWhere((p) {
        final pDateStr = p.paymentDate ?? p.createdAt;
        if (pDateStr == null) return false;
        final pDate = DateTime.parse(pDateStr);

        // Check same day local
        final pLocal = pDate.toLocal();
        final dLocal = item.dueDate.toLocal();
        return pLocal.year == dLocal.year &&
            pLocal.month == dLocal.month &&
            pLocal.day == dLocal.day;
      });

      if (matchIndex != -1) {
        final matchedPayment = remainingPayments[matchIndex];

        // Update item to PAID
        schedule[i] = PaymentScheduleItem(
          index: item.index,
          dueDate: item.dueDate,
          amount: item.amount,
          status: PaymentScheduleStatus.paid,
          paidPayment: matchedPayment,
        );

        // Remove from available pool so it's not reused
        remainingPayments.removeAt(matchIndex);
      }
    }

    // 3. Pass 2: Sequential Fallback (Oldest Debt First)
    // Apply any remaining payments to the earliest Unpaid items
    for (int i = 0; i < schedule.length; i++) {
      final item = schedule[i];

      // If item is still Unpaid (and not Future? Usually we pay oldest matching unpaid first)
      // If logic is "pay oldest debt", then we look for Unpaid items.
      // Note: Future items shouldn't be auto-filled by loose payments unless we want to allow prepayments?
      // Let's assume loose payments cover oldest *due* items (Unpaid).
      if (item.status == PaymentScheduleStatus.unpaid) {
        if (remainingPayments.isNotEmpty) {
          final fundingPayment = remainingPayments.removeAt(
            0,
          ); // Take oldest remaining

          final newStatus = fundingPayment.isPaid
              ? PaymentScheduleStatus.paid
              : PaymentScheduleStatus.pending;

          schedule[i] = PaymentScheduleItem(
            index: item.index,
            dueDate: item.dueDate,
            amount: item.amount,
            status: newStatus,
            paidPayment: fundingPayment,
          );
        }
      }
    }

    return schedule;
  }
}
