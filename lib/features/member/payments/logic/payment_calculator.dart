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
  /// The calendar day a server date stands for, as `yyyy-MM-dd`.
  ///
  /// A date sent bare ("2026-10-01") or with the server's own offset
  /// ("2026-10-01T00:00:00+03:00") is read off the string as written: that is
  /// the day the server itself compares, whatever timezone the phone is in.
  /// Only a UTC instant ("...Z") has no calendar day of its own, so it is
  /// read in the phone's timezone.
  static String? dayKey(String? raw) {
    if (raw == null || raw.length < 10) return null;

    if (raw.endsWith('Z') || raw.endsWith('z')) {
      final local = DateTime.tryParse(raw)?.toLocal();
      if (local == null) return null;
      final m = local.month.toString().padLeft(2, '0');
      final d = local.day.toString().padLeft(2, '0');
      return '${local.year}-$m-$d';
    }

    return raw.substring(0, 10);
  }

  /// Which rounds one place has paid, as 0-based indexes into [roundDates].
  ///
  /// A paid contribution counts for the round whose date it was made for:
  /// the day the member picked, and the day the server's double-payment guard
  /// compares. Only a contribution whose date matches no round (an older row,
  /// or one recorded on another day) falls back to the earliest round still
  /// open.
  ///
  /// Counting payments in order instead (round 1, round 2, ...) showed a
  /// member who had paid today and tomorrow as having paid the first two
  /// days, so today still looked due, and the Pay button then refused it as
  /// "already paid", because by date it was.
  static Set<int> paidRoundIndexes({
    required List<String?> roundDates,
    required Iterable<EqubPayment> payments,
  }) {
    final roundByDay = <String, int>{};
    for (var i = 0; i < roundDates.length; i++) {
      final key = dayKey(roundDates[i]);
      if (key != null) roundByDay.putIfAbsent(key, () => i);
    }

    final paid = <int>{};
    var unmatched = 0;

    for (final payment in payments) {
      if (!payment.isPaid) continue;

      final key = dayKey(payment.paymentDate);
      final round = key == null ? null : roundByDay[key];

      // paid.add is false when that round is already covered, which makes
      // a second payment for the same day an unmatched one.
      if (round != null && paid.add(round)) continue;
      unmatched++;
    }

    for (var i = 0; i < roundDates.length && unmatched > 0; i++) {
      if (paid.add(i)) unmatched--;
    }

    return paid;
  }

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

    // 2b. Pass 1b: payments the bank has not confirmed yet.
    //
    // A pending contribution is not money, so it never counts towards a round
    // the way a paid one does: it is not in `remainingPayments`, and it never
    // reaches the sequential fallback below. But a round with one in flight is
    // not simply unpaid either — showing it as past due moments after the
    // member paid is what Dashen's QA reported as the pending status going
    // missing (item 6). Matched on payment_date, the round the contribution
    // was raised for, and on nothing looser.
    final inFlight = sortedPayments.where((p) => p.isPending).toList();
    for (int i = 0; i < schedule.length && inFlight.isNotEmpty; i++) {
      final item = schedule[i];
      if (item.status == PaymentScheduleStatus.paid) continue;

      final match = inFlight.indexWhere((p) {
        final raw = p.paymentDate;
        if (raw == null) return false;
        final pLocal = DateTime.tryParse(raw)?.toLocal();
        if (pLocal == null) return false;
        final dLocal = item.dueDate.toLocal();
        return pLocal.year == dLocal.year &&
            pLocal.month == dLocal.month &&
            pLocal.day == dLocal.day;
      });

      if (match != -1) {
        schedule[i] = PaymentScheduleItem(
          index: item.index,
          dueDate: item.dueDate,
          amount: item.amount,
          status: PaymentScheduleStatus.pending,
          paidPayment: inFlight.removeAt(match),
        );
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
