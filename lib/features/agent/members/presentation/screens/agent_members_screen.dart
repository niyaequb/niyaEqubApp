import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/agent/members/state/agent_members_bloc.dart';
import 'package:niya_equb/features/agent/members/data/repository/agent_members_repository.dart';
import 'package:niya_equb/features/agent/members/state/agent_members_event.dart';
import 'package:niya_equb/features/agent/members/state/agent_members_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class AgentMembersScreen extends StatelessWidget {
  static const String routeName = '/agent-members';

  const AgentMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<AgentMembersBloc>()..add(AgentMembersLoadEvent()),
      child: const _AgentMembersView(),
    );
  }
}

class _AgentMembersView extends StatelessWidget {
  const _AgentMembersView();

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      body: BlocConsumer<AgentMembersBloc, AgentMembersState>(
        listener: (ctx, state) {
          if (state is AgentMembersFailure) {
            showErrorSnackBar(context, state.failure.errorMessage);
          }
        },
        builder: (ctx, state) {
          final isLoading = state is AgentMembersLoading;
          final members = state is AgentMembersSuccess ? state.members : null;
          final failure = state is AgentMembersFailure ? state.failure : null;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                title: CustomText(
                  title: 'members_referred'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.titleTextColor,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              if (isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: appColors.primaryColor,
                    ),
                  ),
                )
              else if (failure != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
                    child: _ErrorMembersState(
                      failure: failure,
                      appColors: appColors,
                      isDark: isDark,
                      onRetry: () => context
                          .read<AgentMembersBloc>()
                          .add(AgentMembersLoadEvent()),
                    ),
                  ),
                )
              else if (members == null || members.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 56.sp,
                            color: appColors.bodyTextSmallColor
                                ?.withValues(alpha: 0.5),
                          ),
                          SizedBox(height: 16.h),
                          CustomText(
                            title: 'no_members_yet'.tr,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            textColor: appColors.titleTextColor,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8.h),
                          CustomText(
                            title: 'no_members_subtitle'.tr,
                            fontSize: 13.sp,
                            textColor: appColors.bodyTextSmallColor,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final member = members[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: _MemberCard(
                            member: member,
                            isDark: isDark,
                          ),
                        );
                      },
                      childCount: members.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorMembersState extends StatelessWidget {
  final Failure failure;
  final AppColors appColors;
  final bool isDark;
  final VoidCallback onRetry;

  const _ErrorMembersState({
    required this.failure,
    required this.appColors,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: appColors.borderColor!),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: isDark ? 0.06 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 72.r,
            width: 72.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.12),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 36.sp,
              color: Colors.red.shade400,
            ),
          ),
          SizedBox(height: 20.h),
          CustomText(
            title: 'could_not_load_members'.tr,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            textColor: appColors.titleTextColor,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          CustomText(
            title: failure.errorMessage,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            textColor: appColors.bodyTextSmallColor,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          CustomText(
            title: 'error_load_members_subtitle'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.bodyTextSmallColor?.withValues(alpha: 0.85),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.h),
          RoundedButton(
            label: 'retry'.tr,
            height: 48.h,
            backgroundColor: appColors.primaryColor,
            foregroundColor: Colors.black.withValues(alpha: 0.85),
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 20.sp),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final AgentMember member;
  final bool isDark;

  const _MemberCard({required this.member, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final name =
        member.name?.toString().trim().isNotEmpty == true
            ? member.name
            : '—';
    final phone =
        member.phone?.toString().trim().isNotEmpty == true
            ? member.phone
            : '—';
    final email =
        member.email?.toString().trim().isNotEmpty == true
            ? member.email
            : null;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          Container(
            height: 48.r,
            width: 48.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: appColors.primaryColor!.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              color: appColors.primaryColor,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: name ?? '—',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.titleTextColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  title: phone ?? '—',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                if (email != null) ...[
                  SizedBox(height: 2.h),
                  CustomText(
                    title: email,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor?.withValues(
                      alpha: 0.8,
                    ),
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
