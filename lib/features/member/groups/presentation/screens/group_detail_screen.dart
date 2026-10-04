import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/invite_members_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/responsibility_people_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/responsibility_widgets.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_bloc.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_event.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';
import 'package:share_plus/share_plus.dart';

/// One group Equb: contributions at a glance, who has paid, and the rounds
/// that have been drawn. Winner selection is an admin-only concern, so no
/// draw controls appear on this screen.
class GroupDetailScreen extends StatelessWidget {
  static const String routeName = '/equb-group-detail';

  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupDetailBloc>()..add(GroupDetailLoadEvent(groupId: groupId)),
      child: _GroupDetailView(groupId: groupId),
    );
  }
}

class _GroupDetailView extends StatefulWidget {
  final int groupId;

  const _GroupDetailView({required this.groupId});

  @override
  State<_GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<_GroupDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  int _memberFilter = 0; // 0 all · 1 unpaid · 2 paid · 3 my responsibility

  /// Every tab reloads the same three endpoints, and the indicator now waits
  /// for them instead of completing the moment the event is added.
  Future<void> _reload(BuildContext context) {
    return refreshWith(
      (signal) => context.read<GroupDetailBloc>().add(
            GroupDetailLoadEvent(
              groupId: widget.groupId,
              isSilent: true,
              signal: signal,
            ),
          ),
    );
  }

  /// Wraps a non-scrolling child (an empty state) so it can still be pulled
  /// down — these used to sit outside any RefreshIndicator.
  Widget _refreshable(BuildContext context, Widget child) {
    return RefreshIndicator(
      color: colors(context).primaryColor,
      onRefresh: () => _reload(context),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  /// Holds the shape of the overview tab during the very first load, so the
  /// screen never collapses to a spinner on a slow connection. Every visit
  /// after that opens straight from cache and skips this entirely.
  Widget _loadingSkeleton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 170.w, height: 18.h),
            SizedBox(height: 22.h),
            Row(
              children: [
                Skeleton(width: 70.w, height: 12.h),
                SizedBox(width: 22.w),
                Skeleton(width: 70.w, height: 12.h),
                SizedBox(width: 22.w),
                Skeleton(width: 70.w, height: 12.h),
              ],
            ),
            SizedBox(height: 22.h),
            const SkeletonCard(lines: 4),
            SizedBox(height: 14.h),
            Skeleton(width: double.infinity, height: 44.h, radius: 12),
            SizedBox(height: 14.h),
            const SkeletonCard(lines: 5),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      body: BlocConsumer<GroupDetailBloc, GroupDetailState>(
        listenWhen: (prev, next) => next is GroupDetailReady && next.actionMessage != null,
        listener: (context, state) {
          // The screen can be popped while a silent reload is still in flight;
          // touching a dead context is what throws "deactivated widget's
          // ancestor is unsafe".
          if (!context.mounted) return;

          final message = (state as GroupDetailReady).actionMessage!;
          showSuccessSnackBar(context, message);
        },
        builder: (context, state) {
          if (state is GroupDetailLoading) {
            return _loadingSkeleton(context);
          }

          if (state is GroupDetailFailure) {
            return SafeArea(
              child: GroupEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'could_not_open_equb'.tr,
                body: state.failure.errorMessage,
                action: RoundedButton(
                  label: 'try_again'.tr,
                  width: 160.w,
                  backgroundColor: primary,
                  onPressed: () => context
                      .read<GroupDetailBloc>()
                      .add(GroupDetailLoadEvent(groupId: widget.groupId)),
                ),
              ),
            );
          }

          final data = state as GroupDetailReady;
          final group = data.group;

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: appColors.scaffoldBackgroundColor,
                elevation: 0,
                title: CustomText(
                  title: group.name,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.titleTextColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (group.inviteCode != null && group.isDraftStage)
                    IconButton(
                      tooltip: 'share_invite_code'.tr,
                      onPressed: () => Share.share(
                        '${'share_invite_message'.tr} ${group.name}. '
                        '${'invite_code'.tr}: ${group.inviteCode}',
                      ),
                      icon: Icon(Icons.ios_share_rounded, size: 18.r, color: primary),
                    ),
                ],
                bottom: TabBar(
                  controller: _tabs,
                  labelColor: primary,
                  unselectedLabelColor: appColors.bodyTextSmallColor,
                  indicatorColor: primary,
                  labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'overview'.tr),
                    Tab(text: 'members'.tr),
                    Tab(text: 'rounds'.tr),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _overviewTab(context, data),
                _membersTab(context, data),
                _roundsTab(context, data),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Overview
  // ------------------------------------------------------------------

  Widget _overviewTab(BuildContext context, GroupDetailReady data) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final group = data.group;
    final totals = data.ledger.totals;

    return RefreshIndicator(
      color: primary,
      onRefresh: () => _reload(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        children: [
          if (group.isPendingApproval)
            _notice(
              context,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFD97706),
              text: 'awaiting_approval'.tr,
            ),
          if (group.isRejected && group.rejectionReason != null)
            _notice(
              context,
              icon: Icons.error_outline_rounded,
              color: const Color(0xFFDC2626),
              text: group.rejectionReason!,
            ),

          LedgerSummaryCard(
            totals: totals,
            onRemindTap: group.isOwner
                ? () => context
                    .read<GroupDetailBloc>()
                    .add(GroupRemindUnpaidEvent(groupId: widget.groupId))
                : null,
          ),
          SizedBox(height: 14.h),

          // Read-only: the plan is set by the admin who runs the draws.
          SplitPlanStrip(
            plan: data.splitPlan?.plan ?? group.splitPlan,
            cursor: group.splitPlanCursor,
          ),
          SizedBox(height: 14.h),

          _factsCard(context, group, totals),

          // Open to any member the group lets bring people in, not just the
          // creator: whoever adds a person is the one paying for them, so the
          // creator is not the only sensible sponsor.
          if (group.isOwner || group.allowMemberInvites) ...[
            SizedBox(height: 14.h),
            _responsibilityCard(context, group),
          ],

          if (group.isOwner) ...[
            SizedBox(height: 18.h),
            RoundedButton(
              label: 'invite_members'.tr,
              height: 46.h,
              backgroundColor: appColors.primaryColor,
              foregroundColor: Colors.white,
              borderSide: BorderSide(color: primary),
              icon: Icon(Icons.person_add_alt_1_outlined, size: 16.r, color: Colors.white),
              onPressed: () async {
                final sent = await Get.to(
                  () => InviteMembersScreen(groupId: group.id, inviteCode: group.inviteCode),
                );
                if (sent == true && context.mounted) {
                  context
                      .read<GroupDetailBloc>()
                      .add(GroupDetailLoadEvent(groupId: widget.groupId, isSilent: true));
                }
              },
            ),
            SizedBox(height: 12.h),
            // Draws are run by Niya from the admin panel, never from the app.
            _notice(
              context,
              icon: Icons.casino_outlined,
              color: primary,
              text: 'draws_run_by_admin'.tr,
            ),
          ],
        ],
      ),
    );
  }

  Widget _factsCard(BuildContext context, EqubCircle group, LedgerTotals totals) {
    final appColors = colors(context);

    // A group with no cap set comes back as max_members = 0, and "2 / 0" reads
    // as a broken figure rather than "no limit". Show the head count alone.
    final memberCount = group.maxMembers > 0
        ? '${group.currentMembersCount} / ${group.maxMembers}'
        : '${group.currentMembersCount}';

    final rows = <(String, String)>[
      (
        'contribution'.tr,
        '${etb(group.contributionAmount)} ${'every'.tr} ${group.contributionFrequencyDays} ${'days'.tr}'
      ),
      ('pot_per_round'.tr, etb(totals.roundTotal)),
      ('members'.tr, memberCount),
      ('rounds'.tr, '${group.roundsCompleted} / ${group.roundsTotal}'),
      // The three money rows below are the whole-term picture, spelled out so
      // the headline card's "due so far" can never be mistaken for the total.
      if (totals.totalValue > 0) ('total_value'.tr, etb(totals.totalValue)),
      if (totals.perMemberTotal > 0)
        ('each_member_pays'.tr, etb(totals.perMemberTotal)),
      if (totals.outstandingOverTerm > 0)
        ('still_to_collect'.tr, etb(totals.outstandingOverTerm)),
      if (group.startDate != null)
        ('started'.tr, DateFormat('d MMM yyyy').format(group.startDate!)),
      if (group.endDate != null)
        ('ends'.tr, DateFormat('d MMM yyyy').format(group.endDate!)),
      if (group.ownerName != null) ('created_by'.tr, group.ownerName!),
      if (group.drawRequiresUpToDate) ('draw_rule'.tr, 'draw_rule_up_to_date'.tr),
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110.w,
                        child: CustomText(
                          title: r.$1,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                          textColor: appColors.bodyTextSmallColor,
                        ),
                      ),
                      Expanded(
                        child: CustomText(
                          title: r.$2,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          textColor: appColors.titleTextColor,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// Entry point to "My Responsibility People" from the overview.
  ///
  /// Shows the count as a number rather than only a label, because that number
  /// is money: each one is a contribution this member owes every round, and it
  /// should not take a tap to find out how many there are.
  Widget _responsibilityCard(BuildContext context, EqubCircle group) {
    final appColors = colors(context);
    final mine = group.myResponsibilitySeatsCount;
    final total = group.responsibilitySeatsCount;

    return InkWell(
      onTap: () => _openResponsibilityPeople(context, group),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: kResponsibilityTint.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: kResponsibilityTint.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(9.r),
              decoration: BoxDecoration(
                color: kResponsibilityTint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(Icons.volunteer_activism_outlined,
                  size: 17.r, color: kResponsibilityTint),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    title: 'my_responsibility_people'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    textColor: appColors.titleTextColor,
                  ),
                  SizedBox(height: 3.h),
                  CustomText(
                    title: mine > 0
                        ? 'responsibility_you_carry'.trParams({'count': '$mine'})
                        : 'responsibility_card_empty'.tr,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    textColor: appColors.bodyTextSmallColor,
                    maxLines: 2,
                  ),
                  // Only the creator is sent the whole circle's places, so
                  // this line only ever has something to say for them.
                  if (group.isOwner && total > mine) ...[
                    SizedBox(height: 2.h),
                    CustomText(
                      title: 'responsibility_in_circle'.trParams({'count': '$total'}),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      textColor: appColors.hintTextColor,
                    ),
                  ],
                ],
              ),
            ),
            if (mine > 0)
              Padding(
                padding: EdgeInsets.only(right: 6.w),
                child: CustomText(
                  title: '$mine',
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  textColor: kResponsibilityTint,
                ),
              ),
            Icon(Icons.chevron_right_rounded, size: 20.r, color: kResponsibilityTint),
          ],
        ),
      ),
    );
  }

  Future<void> _openResponsibilityPeople(BuildContext context, EqubCircle group) async {
    final bloc = context.read<GroupDetailBloc>();

    final changed = await Get.to(
      () => ResponsibilityPeopleScreen(
        groupId: group.id,
        contributionAmount: group.contributionAmount,
        frequencyDays: group.contributionFrequencyDays,
      ),
    );

    // Adding or removing a place changes the head-count, the pot and the
    // ledger, so the whole screen is re-read rather than patched locally.
    if (changed == true) {
      bloc.add(GroupDetailLoadEvent(groupId: widget.groupId, isSilent: true));
    }
  }

  Widget _notice(BuildContext context,
      {required IconData icon, required Color color, required String text}) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15.r, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: CustomText(
              title: text,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              textColor: color,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Members
  // ------------------------------------------------------------------

  Widget _membersTab(BuildContext context, GroupDetailReady data) {
    final appColors = colors(context);
    final all = data.ledger.members;

    // Places held for someone with no Niya account sit in this same list — they
    // pay in and can win like anyone else — but they are worth being able to
    // isolate, because they are the rows the caller may owe money on.
    final seats = all.where((m) => m.isResponsibilitySeat).toList(growable: false);

    final list = switch (_memberFilter) {
      1 => data.ledger.behind,
      2 => data.ledger.paidUp,
      3 => seats,
      _ => all,
    };

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
          // Scrolls rather than wraps: four chips do not fit across a narrow
          // phone, and a wrapped second row pushes the list itself down.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _filterChip(context, 0, 'all'.tr, all.length),
                SizedBox(width: 8.w),
                _filterChip(context, 1, 'unpaid'.tr, data.ledger.behind.length),
                SizedBox(width: 8.w),
                _filterChip(context, 2, 'paid_up'.tr, data.ledger.paidUp.length),
                if (seats.isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  _filterChip(
                    context,
                    3,
                    'responsibility_filter'.tr,
                    seats.length,
                    tint: kResponsibilityTint,
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _refreshable(
                  context,
                  GroupEmptyState(
                    icon: _memberFilter == 1
                        ? Icons.check_circle_outline_rounded
                        : Icons.people_outline_rounded,
                    title: _memberFilter == 1 ? 'everyone_up_to_date'.tr : 'no_members_yet'.tr,
                    body: _memberFilter == 1
                        ? 'nobody_owes_now'.tr
                        : 'invite_to_fill_circle'.tr,
                  ),
                )
              : RefreshIndicator(
                  color: appColors.primaryColor,
                  onRefresh: () => _reload(context),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 30.h),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[i];

                      // Anyone who has not contributed yet can still be taken
                      // out; the backend refuses once money has moved.
                      //
                      // Places held for someone else are removable from here
                      // too, by the creator. A sponsor who does not own the
                      // group manages their own people from the responsibility
                      // screen instead, which knows who they are without this
                      // list having to carry the caller's member id.
                      final canRemove =
                          data.group.isOwner && !m.isOwner && m.roundsPaid == 0;

                      return MemberLedgerTile(
                        member: m,
                        onRemove: canRemove ? () => _confirmRemove(context, m) : null,
                      );
                    },
                  ),
                ),
        ),
        if (data.ledger.behind.isNotEmpty && data.group.isOwner)
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: RoundedButton(
              label: 'remind_everyone_who_owes'.tr,
              height: 44.h,
              submitting: data.isBusy,
              backgroundColor: appColors.primaryColor,
              foregroundColor: Colors.white,
              icon: Icon(Icons.notifications_active_outlined, size: 15.r, color: Colors.white),
              onPressed: () => context
                  .read<GroupDetailBloc>()
                  .add(GroupRemindUnpaidEvent(groupId: widget.groupId)),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(
    BuildContext context,
    int index,
    String label,
    int count, {
    Color? tint,
  }) {
    final appColors = colors(context);
    final primary = tint ?? appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final selected = _memberFilter == index;

    return InkWell(
      onTap: () => setState(() => _memberFilter = index),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.5)
                : (appColors.borderColor ?? AppStaticColor.borderLight),
          ),
        ),
        child: CustomText(
          title: '$label ($count)',
          fontSize: 11.sp,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          textColor: selected ? primary : appColors.bodyTextSmallColor,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Rounds
  // ------------------------------------------------------------------

  Widget _roundsTab(BuildContext context, GroupDetailReady data) {
    if (data.draws.isEmpty) {
      return _refreshable(
        context,
        GroupEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'no_rounds_yet'.tr,
          body: data.group.isRunning ? 'draws_run_by_admin'.tr : 'winners_appear_here'.tr,
        ),
      );
    }

    return RefreshIndicator(
      color: colors(context).primaryColor,
      onRefresh: () => _reload(context),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 30.h),
        itemCount: data.draws.length,
        itemBuilder: (context, i) => DrawRoundCard(draw: data.draws[i]),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Owner actions
  // ------------------------------------------------------------------

  Future<void> _confirmRemove(BuildContext context, LedgerMember member) async {
    final bloc = context.read<GroupDetailBloc>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: CustomText(title: '${'remove'.tr} ${member.name}?', fontSize: 15.sp),
        content: CustomText(
          // A place held for someone else is not "a member leaving" — nobody is
          // being told anything and no invitation is being withdrawn, so the
          // member wording would be wrong.
          title: member.isResponsibilitySeat
              ? 'remove_responsibility_person_body'.tr
              : 'remove_member_body'.tr,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('remove'.tr),
          ),
        ],
      ),
    );

    if (ok == true) {
      bloc.add(GroupRemoveMemberEvent(
        groupId: widget.groupId,
        membershipId: member.membershipId,
      ));
    }
  }
}
