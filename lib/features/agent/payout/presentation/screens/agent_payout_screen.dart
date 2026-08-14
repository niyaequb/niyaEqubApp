import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/agent/payout/data/repository/agent_payout_repository.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_bloc.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_event.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_state.dart';
import 'package:niya_equb/features/member/profile/presentation/screens/ekub_profile_screen.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class AgentPayoutScreen extends StatelessWidget {
  const AgentPayoutScreen({super.key, this.onNavigateToProfile});

  final VoidCallback? onNavigateToProfile;

  static void _showRequestSheet(
    BuildContext context,
    double balance,
    AgentPayoutBloc bloc,
    bool hasBankInfo,
    bool canRequestPayout, {
    VoidCallback? onNavigateToProfile,
  }) {
    if (!hasBankInfo) {
      EkubProfileScreen.showEditProfileSheet(
        context,
        onProfileUpdated: () {
          bloc.add(AgentPayoutLoadEvent());
        },
      );
      return;
    }
    if (!canRequestPayout || balance <= 0) {
      return;
    }

    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: appColors.scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  SizedBox(height: 20.h),
                  CustomText(
                    title: 'request_payout'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                  SizedBox(height: 8.h),
                  CustomText(
                    title: 'available_balance'.tr +
                        ': ETB ${NumberFormat.decimalPattern().format(balance)}',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                  SizedBox(height: 20.h),
                  CustomTextField(
                    label: 'withdraw_amount'.tr,
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixIcon: Icon(
                      Icons.payments_rounded,
                      color: appColors.primaryColor,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'enter_amount'.tr;
                      }
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) {
                        return 'enter_amount'.tr;
                      }
                      if (n > balance) {
                        return 'amount_exceeds_balance'.tr;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24.h),
                  RoundedButton(
                    label: 'request_payout'.tr,
                    height: 48.h,
                    backgroundColor: appColors.primaryColor,
                    foregroundColor: Colors.black.withValues(alpha: 0.85),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final amount = double.parse(amountCtrl.text.trim());
                        Navigator.pop(ctx);
                        bloc.add(AgentPayoutRequestEvent(amount: amount));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return     BlocConsumer<AgentPayoutBloc, AgentPayoutState>(
      listener: (context, state) {
        if (state is AgentPayoutFailure) {
          showErrorSnackBar(context, state.failure.errorMessage);
        }
      },
      listenWhen: (prev, curr) {
        if (curr is AgentPayoutFailure) return true;
        if (prev is AgentPayoutRequestLoading && curr is AgentPayoutSuccess) {
          showSuccessSnackBar(context, 'payout_requested'.tr);
          return true;
        }
        return false;
      },
      builder: (context, state) {
        final isLoading = state is AgentPayoutLoading;
        final isRequesting = state is AgentPayoutRequestLoading;
        final success = state is AgentPayoutSuccess ? state : null;
        final dashboard = success?.dashboard;
        final payments = success?.payments ?? [];
        final hasBankInfo = success?.hasBankInfo ?? false;
        /// Use balance to determine if we can send a payout request.
        final balance = dashboard?.availableBalance ?? dashboard?.balance ?? 0.0;
        final canRequestPayout = balance > 0;

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<AgentPayoutBloc>().add(AgentPayoutLoadEvent());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  title: CustomText(
                    title: 'payout_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    textColor: appColors.titleTextColor,
                  ),
                ),
                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WalletCard(
                            balance: balance,
                            canRequestPayout: canRequestPayout,
                            hasBankInfo: hasBankInfo,
                            isLoading: isRequesting,
                            onRequestTap: () => _showRequestSheet(
                              context,
                              balance,
                              context.read<AgentPayoutBloc>(),
                              hasBankInfo,
                              canRequestPayout,
                              onNavigateToProfile: context
                                  .findAncestorWidgetOfExactType<
                                      AgentPayoutScreen>()
                                  ?.onNavigateToProfile,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          CustomText(
                            title: 'payout_history'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            textColor: appColors.titleTextColor,
                          ),
                          SizedBox(height: 12.h),
                          _FilterChips(
                            selected: success?.statusFilter ?? 'all',
                            onSelected: (s) => context
                                .read<AgentPayoutBloc>()
                                .add(AgentPayoutSelectFilterEvent(status: s)),
                          ),
                          SizedBox(height: 16.h),
                          if (payments.isEmpty)
                            _EmptyPayoutState(
                              isDark: isDark,
                              appColors: appColors,
                            )
                          else
                            ...payments.map(
                              (p) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _PaymentTile(payment: p),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double balance;
  final bool canRequestPayout;
  final bool hasBankInfo;
  final bool isLoading;
  final VoidCallback onRequestTap;

  const _WalletCard({
    required this.balance,
    required this.canRequestPayout,
    required this.hasBankInfo,
    required this.isLoading,
    required this.onRequestTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: appColors.borderColor!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48.r,
                width: 48.r,
                decoration: BoxDecoration(
                  color: appColors.bodyTextSmallColor?.withValues(
                    alpha: isDark ? 0.15 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: appColors.bodyTextSmallColor,
                  size: 26.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      title: 'available_balance'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                    SizedBox(height: 4.h),
                    CustomText(
                      title:
                          'ETB ${NumberFormat.decimalPattern().format(balance)}',
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.titleTextColor,
                    ),
                    CustomText(
                      title: 'ready_to_withdraw'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: RoundedButton(
              label: hasBankInfo ? 'request_payout'.tr : 'add_bank_information'.tr,
              height: 48.h,
              submitting: isLoading,
              backgroundColor: appColors.primaryColor,
              foregroundColor: Colors.black.withValues(alpha: 0.85),
              onPressed: !isLoading && hasBankInfo && canRequestPayout ? onRequestTap : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;

  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  static const _filters = ['all', 'pending', 'completed', 'failed'];

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final isSel = selected == f;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: FilterChip(
              label: Text(
                _labelFor(f),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel
                      ? Colors.black.withValues(alpha: 0.85)
                      : appColors.bodyTextSmallColor,
                ),
              ),
              selected: isSel,
              onSelected: (_) => onSelected(f),
              selectedColor: appColors.primaryColor,
              backgroundColor: appColors.accentColor,
              side: BorderSide(
                color: isSel
                    ? appColors.primaryColor!
                    : (appColors.borderColor ?? Colors.grey.withValues(alpha: 0.3)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _labelFor(String key) {
    switch (key) {
      case 'all':
        return 'filter_all'.tr;
      case 'pending':
        return 'filter_pending'.tr;
      case 'completed':
        return 'filter_completed'.tr;
      case 'failed':
        return 'filter_failed'.tr;
      default:
        return key;
    }
  }
}

class _PaymentTile extends StatelessWidget {
  final AgentPayment payment;

  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String formatDate(String? iso) {
      if (iso == null || iso.isEmpty) return '—';
      try {
        return DateFormat('MMM dd, yyyy').format(DateTime.parse(iso));
      } catch (_) {
        return iso;
      }
    }

    final status = (payment.status ?? '').toLowerCase();
    final statusColor = status == 'completed' || status.contains('paid')
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : status == 'failed'
                ? Colors.red
                : (appColors.bodyTextSmallColor ?? Colors.grey);

    final displayDate = payment.paidAt ?? payment.createdAt ?? '';
    final bankInfo = [
      payment.bankName,
      payment.accountHolderName,
      payment.accountNumber,
    ].where((s) => s != null && s.toString().trim().isNotEmpty).join(' • ');

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42.r,
                width: 42.r,
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: isDark ? 0.2 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: statusColor,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      title:
                          'ETB ${NumberFormat.decimalPattern().format(payment.amount ?? 0)}',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      textColor: appColors.titleTextColor,
                    ),
                    SizedBox(height: 4.h),
                    CustomText(
                      title: _statusLabel(status),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      textColor: statusColor,
                    ),
                    SizedBox(height: 2.h),
                    CustomText(
                      title: formatDate(displayDate),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bankInfo.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: (appColors.scaffoldBackgroundColor ?? Colors.grey)
                    .withValues(alpha: isDark ? 0.3 : 0.5),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 16.sp,
                    color: appColors.bodyTextSmallColor,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: CustomText(
                      title: bankInfo,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    if (status.isEmpty) return '—';
    switch (status) {
      case 'pending':
        return 'filter_pending'.tr;
      case 'completed':
        return 'filter_completed'.tr;
      case 'failed':
        return 'filter_failed'.tr;
      default:
        return status
            .split('_')
            .map((s) =>
                s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
            .join(' ');
    }
  }
}

class _EmptyPayoutState extends StatelessWidget {
  final bool isDark;
  final AppColors appColors;

  const _EmptyPayoutState({required this.isDark, required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56.sp,
            color: appColors.bodyTextSmallColor?.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          CustomText(
            title: 'no_payout_history_yet'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 8.h),
          CustomText(
            title: 'payout_history_empty_subtitle'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            textColor: appColors.bodyTextSmallColor,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
