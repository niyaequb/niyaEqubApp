import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/invite_members_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/responsibility_people_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_bloc.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_event.dart';
import 'package:niya_equb/features/member/groups/state/group_detail_state.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_night_theme.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';
import 'package:share_plus/share_plus.dart';

/// One group Equb: contributions at a glance, who has paid, and the rounds
/// that have been drawn. Winner selection is an admin-only concern, so no
/// draw controls appear on this screen.
///
/// The night theme is outermost — above the BlocProvider — so that the dialogs
/// and sheets this screen opens from its State's own context inherit it. See
/// the note on CreateGroupScreen.
class GroupDetailScreen extends StatelessWidget {
  static const String routeName = '/equb-group-detail';

  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return NiyaNightTheme(
      child: BlocProvider(
        create: (_) =>
            sl<GroupDetailBloc>()..add(GroupDetailLoadEvent(groupId: groupId)),
        child: _GroupDetailView(groupId: groupId),
      ),
    );
  }
}

class _GroupDetailView extends StatefulWidget {
  final int groupId;

  const _GroupDetailView({required this.groupId});

  @override
  State<_GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<_GroupDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  int _memberFilter = 0; // 0 all · 1 unpaid · 2 paid · 3 my responsibility

  static const Color _danger = Color(0xFFF87171);
  static const Color _warn = Color(0xFFFBBF24);

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
      color: NiyaPalette.gold,
      backgroundColor: NiyaPalette.navy,
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
    return Scaffold(
      backgroundColor: NiyaPalette.navyDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: NiyaNightBackdrop()),
          BlocConsumer<GroupDetailBloc, GroupDetailState>(
            listenWhen: (prev, next) =>
                next is GroupDetailReady && next.actionMessage != null,
            listener: (context, state) {
              // The screen can be popped while a silent reload is still in
              // flight; touching a dead context is what throws "deactivated
              // widget's ancestor is unsafe".
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
                  child: Center(
                    child: SingleChildScrollView(
                      child: NiyaEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'could_not_open_equb'.tr,
                        body: state.failure.errorMessage,
                        actionLabel: 'try_again'.tr,
                        actionIcon: Icons.refresh_rounded,
                        onAction: () => context.read<GroupDetailBloc>().add(
                          GroupDetailLoadEvent(groupId: widget.groupId),
                        ),
                      ),
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
                    // Solid rather than transparent: the tab strip below it is
                    // a toolbar, and rows of members scrolling through the
                    // star lattice behind a see-through bar is unreadable.
                    backgroundColor: NiyaPalette.navyDeep,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    iconTheme: IconThemeData(
                      color: NiyaPalette.goldLight,
                      size: 21.r,
                    ),
                    title: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    actions: [
                      if (group.inviteCode != null && group.isDraftStage)
                        IconButton(
                          tooltip: 'share_invite_code'.tr,
                          onPressed: () => Share.share(
                            '${'share_invite_message'.tr} ${group.name}. '
                            '${'invite_code'.tr}: ${group.inviteCode}',
                          ),
                          icon: Icon(
                            Icons.ios_share_rounded,
                            size: 18.r,
                            color: NiyaPalette.goldLight,
                          ),
                        ),
                    ],
                    bottom: TabBar(
                      controller: _tabs,
                      labelColor: NiyaPalette.goldLight,
                      unselectedLabelColor: Colors.white60,
                      indicatorColor: NiyaPalette.gold,
                      indicatorWeight: 2.5,
                      dividerColor: NiyaPalette.gold.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
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
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Overview
  // ------------------------------------------------------------------

  Widget _overviewTab(BuildContext context, GroupDetailReady data) {
    final group = data.group;
    final totals = data.ledger.totals;

    return RefreshIndicator(
      color: NiyaPalette.gold,
      backgroundColor: NiyaPalette.navy,
      onRefresh: () => _reload(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        children: [
          if (group.isPendingApproval)
            _notice(
              icon: Icons.hourglass_top_rounded,
              color: _warn,
              text: 'awaiting_approval'.tr,
            ),
          if (group.isRejected && group.rejectionReason != null)
            _notice(
              icon: Icons.error_outline_rounded,
              color: _danger,
              text: group.rejectionReason!,
            ),

          LedgerSummaryCard(
            totals: totals,
            onRemindTap: group.isOwner
                ? () => context.read<GroupDetailBloc>().add(
                    GroupRemindUnpaidEvent(groupId: widget.groupId),
                  )
                : null,
          ),
          SizedBox(height: 14.h),

          // Read-only: the plan is set by the admin who runs the draws.
          SplitPlanStrip(
            plan: data.splitPlan?.plan ?? group.splitPlan,
            cursor: group.splitPlanCursor,
          ),
          SizedBox(height: 18.h),

          NiyaSectionLabel(
            label: 'overview'.tr,
            icon: Icons.fact_check_rounded,
          ),
          SizedBox(height: 10.h),
          _factsCard(context, group, totals),

          // Open to any member the group lets bring people in, not just the
          // creator: whoever adds a person is the one paying for them, so the
          // creator is not the only sensible sponsor.
          if (group.isOwner || group.allowMemberInvites) ...[
            SizedBox(height: 14.h),
            _responsibilityCard(context, group),
          ],

          if (group.isOwner) ...[
            SizedBox(height: 20.h),
            NiyaGoldButton(
              label: 'invite_members'.tr,
              icon: Icons.person_add_alt_1_rounded,
              height: 46.h,
              fontSize: 14.sp,
              onPressed: () async {
                final bloc = context.read<GroupDetailBloc>();
                final sent = await Get.to(
                  () => InviteMembersScreen(
                    groupId: group.id,
                    inviteCode: group.inviteCode,
                  ),
                );
                if (sent == true) {
                  bloc.add(
                    GroupDetailLoadEvent(
                      groupId: widget.groupId,
                      isSilent: true,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 14.h),
            // Draws are run by Niya from the admin panel, never from the app.
            _notice(
              icon: Icons.casino_rounded,
              color: NiyaPalette.goldLight,
              text: 'draws_run_by_admin'.tr,
              bottomMargin: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _factsCard(
    BuildContext context,
    EqubCircle group,
    LedgerTotals totals,
  ) {
    // A group with no cap set comes back as max_members = 0, and "2 / 0" reads
    // as a broken figure rather than "no limit". Show the head count alone.
    final memberCount = group.maxMembers > 0
        ? '${group.currentMembersCount} / ${group.maxMembers}'
        : '${group.currentMembersCount}';

    final rows = <(String, String)>[
      (
        'contribution'.tr,
        '${etb(group.contributionAmount)} ${'every'.tr} ${group.contributionFrequencyDays} ${'days'.tr}',
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
      if (group.drawRequiresUpToDate)
        ('draw_rule'.tr, 'draw_rule_up_to_date'.tr),
    ];

    return NiyaCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 6.h),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108.w,
                      child: Text(
                        r.$1,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        r.$2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
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
    final tint = responsibilityTint(context);
    final mine = group.myResponsibilitySeatsCount;
    final total = group.responsibilitySeatsCount;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _openResponsibilityPeople(context, group),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: tint.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.r),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  size: 17.r,
                  color: tint,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'my_responsibility_people'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      mine > 0
                          ? 'responsibility_you_carry'.trParams({
                              'count': '$mine',
                            })
                          : 'responsibility_card_empty'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    // Only the creator is sent the whole circle's places, so
                    // this line only ever has something to say for them.
                    if (group.isOwner && total > mine) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'responsibility_in_circle'.trParams({
                          'count': '$total',
                        }),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (mine > 0)
                Padding(
                  padding: EdgeInsets.only(right: 6.w),
                  child: Text(
                    '$mine',
                    style: TextStyle(
                      color: tint,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, size: 20.r, color: tint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openResponsibilityPeople(
    BuildContext context,
    EqubCircle group,
  ) async {
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

  Widget _notice({
    required IconData icon,
    required Color color,
    required String text,
    bool bottomMargin = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin ? 14.h : 0),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15.r, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
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
    final all = data.ledger.members;

    // Places held for someone with no Niya account sit in this same list — they
    // pay in and can win like anyone else — but they are worth being able to
    // isolate, because they are the rows the caller may owe money on.
    final seats = all
        .where((m) => m.isResponsibilitySeat)
        .toList(growable: false);

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
                    tint: responsibilityTint(context),
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
                  NiyaEmptyState(
                    icon: _memberFilter == 1
                        ? Icons.check_circle_rounded
                        : Icons.people_rounded,
                    title: _memberFilter == 1
                        ? 'everyone_up_to_date'.tr
                        : 'no_members_yet'.tr,
                    body: _memberFilter == 1
                        ? 'nobody_owes_now'.tr
                        : 'invite_to_fill_circle'.tr,
                  ),
                )
              : RefreshIndicator(
                  color: NiyaPalette.gold,
                  backgroundColor: NiyaPalette.navy,
                  onRefresh: () => _reload(context),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
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
                        onRemove: canRemove
                            ? () => _confirmRemove(context, m)
                            : null,
                      );
                    },
                  ),
                ),
        ),
        if (data.ledger.behind.isNotEmpty && data.group.isOwner)
          NiyaBottomBar(
            child: NiyaGoldButton(
              label: 'remind_everyone_who_owes'.tr,
              icon: Icons.notifications_active_rounded,
              busy: data.isBusy,
              height: 46.h,
              fontSize: 14.sp,
              onPressed: () => context.read<GroupDetailBloc>().add(
                GroupRemindUnpaidEvent(groupId: widget.groupId),
              ),
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
    final colour = tint ?? NiyaPalette.goldLight;
    final selected = _memberFilter == index;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => setState(() => _memberFilter = index),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: selected
                ? colour.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? colour.withValues(alpha: 0.7)
                  : Colors.white24,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              color: selected ? colour : Colors.white70,
              fontSize: 11.sp,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
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
        NiyaEmptyState(
          icon: Icons.emoji_events_rounded,
          title: 'no_rounds_yet'.tr,
          body: data.group.isRunning
              ? 'draws_run_by_admin'.tr
              : 'winners_appear_here'.tr,
        ),
      );
    }

    return RefreshIndicator(
      color: NiyaPalette.gold,
      backgroundColor: NiyaPalette.navy,
      onRefresh: () => _reload(context),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
        backgroundColor: NiyaPalette.navySoft,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: NiyaPalette.gold.withValues(alpha: 0.45)),
        ),
        title: Text(
          '${'remove'.tr} ${member.name}?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          // A place held for someone else is not "a member leaving" — nobody is
          // being told anything and no invitation is being withdrawn, so the
          // member wording would be wrong.
          member.isResponsibilitySeat
              ? 'remove_responsibility_person_body'.tr
              : 'remove_member_body'.tr,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('remove'.tr, style: const TextStyle(color: _danger)),
          ),
        ],
      ),
    );

    if (ok == true) {
      bloc.add(
        GroupRemoveMemberEvent(
          groupId: widget.groupId,
          membershipId: member.membershipId,
        ),
      );
    }
  }
}
