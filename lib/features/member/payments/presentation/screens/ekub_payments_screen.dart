import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/payments/data/repository/ekub_payments_repository.dart';
import 'package:niya_equb/features/member/payments/state/ekub_payments_bloc.dart';
import 'package:niya_equb/features/member/payments/state/ekub_payments_event.dart';
import 'package:niya_equb/features/member/payments/state/ekub_payments_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class EkubPaymentsScreen extends StatelessWidget {
  const EkubPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return BlocBuilder<EkubPaymentsBloc, EkubPaymentsState>(
      builder: (context, state) {
        final filterIndex = switch (state) {
          EkubPaymentsSuccess s => s.filterIndex,
          EkubPaymentsFailure s => s.filterIndex,
          _ => 0,
        };
        final filtered = switch (state) {
          EkubPaymentsSuccess s => s.filtered,
          EkubPaymentsFailure s => s.items,
          _ => const <EkubPaymentItem>[],
        };

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                title: Text('payments_title'.tr),
                actions: [SizedBox(width: 6.w)],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: const _DueCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: _FilterChips(
                    index: filterIndex,
                    onChanged: (i) => context.read<EkubPaymentsBloc>().add(
                      EkubPaymentsSetFilterEvent(filterIndex: i),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: filtered.isEmpty
                        ? _EmptyState(
                            key: const ValueKey('empty'),
                            title: 'no_payments'.tr,
                            subtitle: 'payment_history_empty_subtitle'.tr,
                          )
                        : Column(
                            key: ValueKey('list-$filterIndex'),
                            children: [
                              ...filtered.map(
                                (e) => Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: _PaymentTile(item: e),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: RoundedButton(
                label: 'pay_now'.tr,
                height: 50.h,
                backgroundColor: appColors.primaryColor,
                foregroundColor: Colors.black.withValues(alpha: 0.85),
                onPressed: () => _showPaySheet(context),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaySheet(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
        decoration: BoxDecoration(
          color: appColors.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: CustomText(
                        title: 'payment_ui'.tr,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        textColor: appColors.titleTextColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          title:
                              'Backend integration will be added later. For now, this is a placeholder flow.',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          textColor: appColors.bodyTextSmallColor,
                        ),
                        SizedBox(height: 16.h),
                        RoundedButton(
                          label: 'ok'.tr,
                          height: 46.h,
                          backgroundColor: appColors.primaryColor,
                          foregroundColor: Colors.black.withValues(alpha: 0.85),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard();

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          Container(
            height: 44.r,
            width: 44.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: Colors.orange.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
            child: const Icon(Icons.schedule_rounded, color: Colors.orange),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: 'today_due'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.bodyTextSmallColor,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  title: '100 Birr',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                ),
                SizedBox(height: 2.h),
                CustomText(
                  title: '100 Birr/day • Pay before midnight',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: appColors.bodyTextSmallColor),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FilterChips({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget chip(String label, int i) {
      final selected = index == i;
      return GestureDetector(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? appColors.primaryColor!.withValues(
                    alpha: isDark ? 0.20 : 0.14,
                  )
                : appColors.accentColor,
            border: Border.all(
              color: selected
                  ? appColors.primaryColor!
                  : appColors.borderColor!,
            ),
          ),
          child: CustomText(
            title: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            textColor: selected
                ? appColors.titleTextColor
                : appColors.bodyTextSmallColor,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [chip('All', 0), chip('Paid', 1), chip('Unpaid', 2)],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final EkubPaymentItem item;

  const _PaymentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = switch (item.status) {
      EkubPaymentStatus.paid => Colors.green,
      EkubPaymentStatus.pending => Colors.blue,
      EkubPaymentStatus.unpaid => Colors.orange, // or Red for past due
      EkubPaymentStatus.future => Colors.blueGrey,
    };

    final statusLabel = switch (item.status) {
      EkubPaymentStatus.paid => 'Paid',
      EkubPaymentStatus.pending => 'pending'.tr,
      EkubPaymentStatus.unpaid => 'Unpaid', // Or "Past Due"
      EkubPaymentStatus.future => 'Upcoming',
    };

    final icon = switch (item.status) {
      EkubPaymentStatus.paid => Icons.check_circle_rounded,
      EkubPaymentStatus.pending => Icons.hourglass_top_rounded,
      EkubPaymentStatus.unpaid => Icons.priority_high_rounded,
      EkubPaymentStatus.future => Icons.event_rounded,
    };

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          Container(
            height: 42.r,
            width: 42.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: color.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomText(
                        title: item.packageLabel,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        textColor: appColors.titleTextColor,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                      ),
                      child: CustomText(
                        title: statusLabel,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        textColor: color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                CustomText(
                  title:
                      '${NumberFormat.decimalPattern().format(item.amount)} Birr • ${DateFormat('MMM d').format(item.time)}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
                SizedBox(height: 2.h),
                CustomText(
                  // .tr so a translation key (the pending label) reads as
                  // words; every other label is plain text and passes through
                  // unchanged, because GetX returns the input when no key
                  // matches.
                  title: item.method.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Column(
        children: [
          Container(
            height: 52.r,
            width: 52.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              color: appColors.primaryColor!.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: appColors.primaryColor,
            ),
          ),
          SizedBox(height: 10.h),
          CustomText(
            title: title,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 4.h),
          CustomText(
            title: subtitle,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            textColor: appColors.bodyTextSmallColor,
            centerText: true,
          ),
        ],
      ),
    );
  }
}
