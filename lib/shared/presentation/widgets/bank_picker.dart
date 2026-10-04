// Choosing which bank to pay through.
//
// Niya collects through several banks — Dashen now, CBE, Awash and more — and
// which ones are live is decided by the server, not by this build. So the list
// is passed in rather than declared here, and this file has no bank names in
// it and needs no edit when one is added.
//
// It is a bottom sheet rather than a dialog on purpose: it appears while the
// payment confirmation dialog is still open behind it, and a second dialog
// stacked on the first reads as an error state. A sheet reads as one more step.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/service/payments/payment_bridge.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

/// Ask the member which bank to pay through.
///
/// Returns null if they dismiss it, which callers must treat as "changed their
/// mind" and not as a failure — nothing has been charged and nothing needs
/// explaining to them.
///
/// With a single bank there is no question worth asking, so it resolves
/// immediately. That keeps the common case a single tap today, without the
/// caller needing to special-case it now or remember to remove the
/// special-casing when the second bank arrives.
Future<PaymentClientConfig?> pickPaymentBank(
  BuildContext context,
  List<PaymentClientConfig> banks,
) async {
  if (banks.isEmpty) return null;
  if (banks.length == 1) return banks.first;

  return showModalBottomSheet<PaymentClientConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _BankSheet(banks: banks),
  );
}

class _BankSheet extends StatelessWidget {
  final List<PaymentClientConfig> banks;

  const _BankSheet({required this.banks});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: appColors.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: appColors.titleTextColor?.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            CustomText(
              title: 'payment_choose_bank'.tr,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              textColor: appColors.titleTextColor,
            ),
            SizedBox(height: 6.h),
            CustomText(
              title: 'payment_choose_bank_hint'.tr,
              fontSize: 12.sp,
              maxLines: 3,
              textColor: appColors.titleTextColor?.withValues(alpha: 0.65),
            ),
            SizedBox(height: 16.h),

            // A plain list, not a grid: bank names vary a lot in length across
            // English, Amharic and Oromo, and a grid cell that fits "Awash"
            // truncates "Commercial Bank of Ethiopia".
            ...banks.map(
              (bank) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(bank),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(52.h),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_rounded, size: 20.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: CustomText(
                          title: bank.name,
                          fontSize: 15.sp,
                          maxLines: 2,
                          fontWeight: FontWeight.w600,
                          textColor: appColors.titleTextColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20.sp),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 4.h),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancel'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
