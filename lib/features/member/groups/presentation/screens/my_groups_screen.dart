import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/create_group_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/group_detail_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/join_group_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/state/group_list_bloc.dart';
import 'package:niya_equb/features/member/groups/state/group_list_event.dart';
import 'package:niya_equb/features/member/groups/state/group_list_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

/// Group Equbs the member created or was invited into.
class MyGroupsScreen extends StatelessWidget {
  static const String routeName = '/my-equb-groups';

  const MyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupListBloc>()..add(GroupListLoadEvent()),
      child: const _MyGroupsView(),
    );
  }
}

class _MyGroupsView extends StatelessWidget {
  const _MyGroupsView();

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appColors.scaffoldBackgroundColor,
        elevation: 0,
        title: CustomText(
          title: 'my_group_equbs'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          textColor: appColors.titleTextColor,
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'joinGroupFab',
            backgroundColor: appColors.accentColor,
            foregroundColor: primary,
            elevation: 1,
            onPressed: () async {
              await Get.to(() => const JoinGroupScreen());
              if (context.mounted) {
                context.read<GroupListBloc>().add(GroupListLoadEvent(isSilent: true));
              }
            },
            icon: Icon(Icons.key_rounded, color: primary, size: 18.r),
            label: CustomText(
              title: 'Join group'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              textColor: primary,
            ),
          ),
          SizedBox(height: 10.h),
          FloatingActionButton.extended(
            heroTag: 'createGroupFab',
            backgroundColor: primary,
            onPressed: () async {
              await Get.to(() => const CreateGroupScreen());
              if (context.mounted) {
                context.read<GroupListBloc>().add(GroupListLoadEvent(isSilent: true));
              }
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: CustomText(
              title: 'create_group'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              textColor: Colors.white,
            ),
          ),
        ],
      ),
      body: BlocConsumer<GroupListBloc, GroupListState>(
        listenWhen: (prev, next) =>
            next is GroupListSuccess && next.actionMessage != null,
        listener: (context, state) {
          if (!context.mounted) return;

          if (state is GroupListSuccess && state.actionMessage != null) {
            showSuccessSnackBar(context, state.actionMessage!);
          }
        },
        builder: (context, state) {
          if (state is GroupListLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GroupListFailure) {
            return _refreshable(
              context,
              GroupEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your groups',
                body: state.failure.errorMessage,
                action: RoundedButton(
                  label: 'Try again',
                  width: 160.w,
                  backgroundColor: appColors.primaryColor,
                  onPressed: () => context.read<GroupListBloc>().add(GroupListLoadEvent()),
                ),
              ),
            );
          }

          final data = state as GroupListSuccess;

          if (data.groups.isEmpty && data.invitations.isEmpty) {
            return _refreshable(
              context,
              GroupEmptyState(
                icon: Icons.groups_2_rounded,
                title: 'Start an Equb with your circle'.tr,
                body: 'Pick a package, invite your family or friends, and run your own draws.'.tr,
                action: RoundedButton(
                  label: 'Create a group'.tr,
                  width: 200.w,
                  backgroundColor: appColors.primaryColor,
                  onPressed: () async {
                    await Get.to(() => const CreateGroupScreen());
                    if (context.mounted) {
                      context.read<GroupListBloc>().add(GroupListLoadEvent(isSilent: true));
                    }
                  },
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: appColors.primaryColor,
            // Waits for the reload rather than completing the instant the
            // event is added, which is why the pull never looked like it did
            // anything.
            onRefresh: () => refreshWith(
              (signal) => context.read<GroupListBloc>().add(
                    GroupListLoadEvent(isSilent: true, signal: signal),
                  ),
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
              children: [
                if (data.invitations.isNotEmpty) ...[
                  _sectionLabel(context, 'Invitations'),
                  SizedBox(height: 10.h),
                  ...data.invitations.map((i) => _InvitationCard(invitation: i)),
                  SizedBox(height: 20.h),
                ],
                if (data.groups.isNotEmpty) ...[
                  _sectionLabel(context, 'Your groups'.tr),
                  SizedBox(height: 10.h),
                  ...data.groups.map((g) => _GroupCard(group: g)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// One pull-to-refresh for every branch of this screen, including the empty
  /// and error states — those used to sit outside the RefreshIndicator, so
  /// there was no way to retry without leaving and coming back.
  Widget _refreshable(BuildContext context, Widget child, {bool fill = true}) {
    return RefreshIndicator(
      color: colors(context).primaryColor,
      onRefresh: () => refreshWith(
        (signal) => context.read<GroupListBloc>().add(
              GroupListLoadEvent(isSilent: true, signal: signal),
            ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            fill
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: child,
                  )
                : child,
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return CustomText(
      title: label,
      fontSize: 13.sp,
      fontWeight: FontWeight.w700,
      textColor: colors(context).titleTextColor,
    );
  }
}

class _GroupCard extends StatelessWidget {
  final EqubCircle group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    final (statusLabel, statusColor) = switch (group.status) {
      'running' => ('Running', const Color(0xFF16A34A)),
      'completed' => ('Completed', const Color(0xFF0EA5E9)),
      'cancelled' => ('Cancelled', const Color(0xFF64748B)),
      _ => group.isPendingApproval
          ? ('Waiting for approval', const Color(0xFFD97706))
          : ('Collecting members', primary),
    };

    return InkWell(
      onTap: () => context.navigateOnce(
        () => Get.to(() => GroupDetailScreen(groupId: group.id)),
      ),
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomText(
                    title: group.name,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    textColor: appColors.titleTextColor,
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusPill(label: statusLabel, color: statusColor),
              ],
            ),
            SizedBox(height: 6.h),
            CustomText(
              title:
                  '${etb(group.contributionAmount)} every ${group.contributionFrequencyDays} day(s)'
                  '${group.packageName != null ? ' · ${group.packageName}' : ''}',
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              textColor: appColors.bodyTextSmallColor,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 14.r, color: appColors.hintTextColor),
                SizedBox(width: 5.w),
                CustomText(
                  title: '${group.currentMembersCount}/${group.maxMembers} ${'Members'.tr}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
                SizedBox(width: 14.w),
                Icon(Icons.emoji_events_outlined, size: 14.r, color: appColors.hintTextColor),
                SizedBox(width: 5.w),
                CustomText(
                  title: '${'round'.tr} ${group.roundsCompleted + 1} ${'of'.tr} ${group.roundsTotal}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
                const Spacer(),
                if (group.isOwner)
                  CustomText(
                    title: 'You created this'.tr,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    textColor: primary,
                  ),
              ],
            ),
            if (group.isRejected && group.rejectionReason != null) ...[
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: CustomText(
                  title: group.rejectionReason!,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w400,
                  textColor: const Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An invitation from a group creator. Accepting is the member's call, so it
/// carries both a Join and a Decline.
class _InvitationCard extends StatelessWidget {
  final EqubInvitation invitation;

  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            title: '${invitation.invitedByName ?? 'Someone'} invited you to '
                '"${invitation.groupName}"',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 6.h),
          CustomText(
            title: '${etb(invitation.contributionAmount)} per round',
            fontSize: 11.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.bodyTextSmallColor,
          ),
          if (invitation.message != null && invitation.message!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            CustomText(
              title: '"${invitation.message}"',
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              textColor: appColors.bodyTextSmallColor,
            ),
          ],
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: RoundedButton(
                  label: 'Join',
                  height: 42.h,
                  backgroundColor: primary,
                  onPressed: () => context.read<GroupListBloc>().add(
                        GroupInvitationRespondEvent(
                          invitationId: invitation.id,
                          accept: true,
                        ),
                      ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: RoundedButton(
                  label: 'Decline',
                  height: 42.h,
                  backgroundColor: Colors.transparent,
                  foregroundColor: appColors.bodyTextColor,
                  borderSide: BorderSide(
                    color: (appColors.borderColor ?? AppStaticColor.borderLight),
                  ),
                  onPressed: () => context.read<GroupListBloc>().add(
                        GroupInvitationRespondEvent(
                          invitationId: invitation.id,
                          accept: false,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
