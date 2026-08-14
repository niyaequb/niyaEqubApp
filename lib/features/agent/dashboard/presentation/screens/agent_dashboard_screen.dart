import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/constants/hive_constants.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_add_member_bloc.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_add_member_event.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_add_member_state.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_bloc.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_event.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_state.dart';
import 'package:niya_equb/features/agent/members/presentation/screens/agent_members_screen.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/custom_phone_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key, this.onNavigateToPayout});

  final VoidCallback? onNavigateToPayout;

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final user = PreferencesService.getUser();
    final name = user?.name.isNotEmpty == true
        ? user!.name
        : 'agent_fallback'.tr;

    return BlocConsumer<AgentDashboardBloc, AgentDashboardState>(
      listener: (context, state) {
        if (state is AgentDashboardFailure) {
          showErrorSnackBar(context, state.failure.errorMessage);
        }
      },
      builder: (context, state) {
        final isLoading = state is AgentDashboardLoading;
        final data = switch (state) {
          AgentDashboardSuccess s => s.data,
          _ => null,
        };

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<AgentDashboardBloc>().add(AgentDashboardLoadEvent());
              await Future.delayed(const Duration(milliseconds: 400));
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
                    title: name,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    textColor: appColors.titleTextColor,
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'add_user_tooltip'.tr,
                      onPressed: () => _showAddUserSheet(context),
                      icon: const Icon(Icons.person_add_rounded),
                    ),
                    ValueListenableBuilder(
                      valueListenable: Hive.box(
                        HiveConstants.appSettingsBox,
                      ).listenable(),
                      builder: (context, box, _) {
                        final isDarkTheme =
                            box.get(
                                  HiveConstants.isDarkTheme,
                                  defaultValue: false,
                                )
                                as bool;
                        return IconButton(
                          tooltip: isDarkTheme
                              ? 'switch_to_light'.tr
                              : 'switch_to_dark'.tr,
                          onPressed: () =>
                              box.put(HiveConstants.isDarkTheme, !isDarkTheme),
                          icon: Icon(
                            isDarkTheme
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 6.w),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          title: 'overview'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          textColor: appColors.titleTextColor,
                        ),
                        SizedBox(height: 16.h),
                        if (isLoading)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.h),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: appColors.primaryColor,
                              ),
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'total_earned'.tr,
                                  value: data?.totalCommissionFormatted ?? '0',
                                  icon: Icons.monetization_on_rounded,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: InkWell(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AgentMembersScreen.routeName,
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: _StatCard(
                                    label: 'members_referred'.tr,
                                    value:
                                        data?.membersReferredFormatted ?? '0',
                                    icon: Icons.people_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'pending'.tr,
                                  value:
                                      data?.pendingCommissionFormatted ?? '0',
                                  icon: Icons.schedule_rounded,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _StatCard(
                                  label: 'balance'.tr,
                                  value: data?.balanceFormatted ?? '0',
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'payment_requests_paid'.tr,
                                  value:
                                      data?.paymentRequestsPaidAmountFormatted ??
                                      '0',
                                  icon: Icons.check_circle_rounded,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _ReferralCodeCard(
                                  code: data?.referralCode ?? '—',
                                  hasCode:
                                      (data?.referralCode ?? '').isNotEmpty,
                                  onTap: () {
                                    _showReferralCodeSheet(
                                      context,
                                      data?.referralCode ?? '—',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          CustomText(
                            title: 'quick_actions'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            textColor: appColors.titleTextColor,
                          ),
                          SizedBox(height: 12.h),
                          _QuickActionTile(
                            icon: Icons.qr_code_rounded,
                            title: 'share_referral_code'.tr,
                            subtitle: 'share_referral_subtitle'.tr,
                            onTap: () {
                              _showReferralCodeSheet(
                                context,
                                data?.referralCode ?? '—',
                              );
                            },
                          ),
                          SizedBox(height: 10.h),
                          _QuickActionTile(
                            icon: Icons.receipt_long_rounded,
                            title: 'commission_history'.tr,
                            subtitle: 'commission_history_subtitle'.tr,
                            onTap: () => onNavigateToPayout?.call(),
                          ),
                        ],
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

void _showReferralCodeSheet(BuildContext context, String code) {
  if (code.isEmpty || code == '—') return;
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
      decoration: BoxDecoration(
        color: appColors.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20.h),
          CustomText(
            title: 'referral_code'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            textColor: appColors.bodyTextSmallColor,
          ),
          SizedBox(height: 12.h),
          SelectableText(
            code,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: appColors.titleTextColor,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: RoundedButton(
                  label: 'copy'.tr,
                  height: 48.h,
                  backgroundColor: appColors.primaryColor,
                  foregroundColor: Colors.black.withValues(alpha: 0.85),
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (sheetContext.mounted) {
                        HapticFeedback.lightImpact();
                        Navigator.pop(sheetContext);
                      }
                      if (context.mounted) {
                        showSuccessSnackBar(context, 'referral_code_copied'.tr);
                      }
                    } catch (_) {
                      try {
                        await Share.share(code, subject: 'referral_code'.tr);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) {
                          showSuccessSnackBar(
                            context,
                            'use_copy_from_share'.tr,
                          );
                        }
                      } catch (_) {
                        if (sheetContext.mounted) {
                          showErrorSnackBar(
                            sheetContext,
                            'long_press_to_copy'.tr,
                          );
                        }
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await Share.share(code, subject: 'referral_code'.tr);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (_) {
                      if (sheetContext.mounted) {
                        showErrorSnackBar(sheetContext, 'share_failed'.tr);
                      }
                    }
                  },
                  icon: Icon(Icons.share_rounded, size: 18.sp),
                  label: Text('share'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appColors.primaryColor,
                    side: BorderSide(color: appColors.primaryColor!),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void _showAddUserSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider(
      create: (_) => sl<AgentAddMemberBloc>(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _AddUserSheetContent(
          sheetContext: sheetContext,
          parentContext: context,
          onSuccess: () {
            Navigator.pop(sheetContext);
            if (context.mounted) {
              context.read<AgentDashboardBloc>().add(AgentDashboardLoadEvent());
              showSuccessSnackBar(context, 'add_user_success'.tr);
            }
          },
        ),
      ),
    ),
  );
}

class _AddUserSheetContent extends StatefulWidget {
  final BuildContext sheetContext;
  final BuildContext parentContext;
  final VoidCallback onSuccess;

  const _AddUserSheetContent({
    required this.sheetContext,
    required this.parentContext,
    required this.onSuccess,
  });

  @override
  State<_AddUserSheetContent> createState() => _AddUserSheetContentState();
}

class _AddUserSheetContentState extends State<_AddUserSheetContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  bool _autoValidate = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AgentAddMemberBloc>().add(
        AgentAddMemberSubmitEvent(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        ),
      );
    } else {
      setState(() => _autoValidate = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AgentAddMemberBloc, AgentAddMemberState>(
      listener: (ctx, state) {
        if (state is AgentAddMemberSuccess) {
          widget.onSuccess();
        }
        if (state is AgentAddMemberFailure) {
          CustomToast.showToast(
            state.failure.errorMessage,
            bgColor: Colors.red,
            textColor: Colors.white,
          );
        }
      },
      builder: (ctx, state) {
        final isLoading = state is AgentAddMemberLoading;

        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
          decoration: BoxDecoration(
            color: appColors.scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode: _autoValidate
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  CustomText(
                    title: 'add_user'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                  SizedBox(height: 20.h),
                  CustomTextField(
                    label: 'full_name'.tr,
                    controller: _nameCtrl,
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: appColors.primaryColor,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'name_required'.tr;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  CustomPhoneField(
                    controller: _phoneCtrl,
                    label: 'phone_number'.tr,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'phone_number_required'.tr;
                      }
                      if (v.trim().length != 9) {
                        return 'phone_9_digits'.tr;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  CustomTextField(
                    label: 'email_optional'.tr,
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: appColors.primaryColor,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final email = v.trim();
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(email)) {
                        return 'valid_email'.tr;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: appColors.primaryColor,
                            side: BorderSide(color: appColors.primaryColor!),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text('cancel'.tr),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: RoundedButton(
                          label: 'add_user_submit'.tr,
                          height: 48.h,
                          backgroundColor: appColors.primaryColor,
                          foregroundColor: Colors.black.withValues(alpha: 0.85),
                          submitting: isLoading,
                          onPressed: isLoading ? null : _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final bool hasCode;
  final VoidCallback onTap;

  const _ReferralCodeCard({
    required this.code,
    required this.hasCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: hasCode ? onTap : null,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: appColors.borderColor!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 40.r,
                  width: 40.r,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    color: appColors.primaryColor!.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: appColors.primaryColor,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.copy_rounded,
                  size: 20.sp,
                  color: hasCode
                      ? appColors.primaryColor
                      : appColors.bodyTextSmallColor,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            CustomText(
              title: code,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              textColor: appColors.titleTextColor,
              maxLines: 1,
              textOverflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            CustomText(
              title: 'referral_code'.tr,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              textColor: appColors.bodyTextSmallColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40.r,
            width: 40.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: appColors.primaryColor!.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
            child: Icon(icon, color: appColors.primaryColor, size: 22),
          ),
          SizedBox(height: 12.h),
          CustomText(
            title: value,
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 4.h),
          CustomText(
            title: label,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            textColor: appColors.bodyTextSmallColor,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: appColors.borderColor!),
        ),
        child: Row(
          children: [
            Container(
              height: 44.r,
              width: 44.r,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: appColors.primaryColor!.withValues(
                  alpha: isDark ? 0.18 : 0.12,
                ),
              ),
              child: Icon(icon, color: appColors.primaryColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    title: title,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    textColor: appColors.titleTextColor,
                  ),
                  SizedBox(height: 4.h),
                  CustomText(
                    title: subtitle,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: appColors.bodyTextSmallColor),
          ],
        ),
      ),
    );
  }
}
