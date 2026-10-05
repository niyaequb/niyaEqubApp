import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
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
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// Group Equbs the member created or was invited into.
///
/// WHY THIS SCREEN LOOKS THE WAY IT DOES
///
/// It is reached from the Equb package list - both from the pill above the
/// logo and from the Group Equb row at the foot of the list - so it is read as
/// a continuation of that list, not as a different part of the app. It
/// therefore wears the same clothes: the navy night backdrop with the star
/// lattice, gold ornament titles over each section, and cards built from the
/// very same parts as a package row (star badge, gold divider, gold hairline
/// border, chevron).
///
/// Everything here is drawn from [NiyaPalette] rather than the app theme, on
/// purpose. The backdrop is always navy, so a card that followed the device's
/// light/dark setting would come out white-on-navy half the time.
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
    // The app bar sits over the backdrop so the night gradient runs unbroken
    // from the status bar down. The content has to clear it by hand.
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: NiyaPalette.navyDeep,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: NiyaPalette.goldLight, size: 22.r),
          title: Text(
            'my_group_equbs'.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _NightAction(
              icon: Icons.key_rounded,
              label: 'Join group'.tr,
              onTap: () => _openAndReload(context, const JoinGroupScreen()),
            ),
            SizedBox(height: 10.h),
            _NightAction(
              icon: Icons.add_rounded,
              label: 'create_group'.tr,
              filled: true,
              onTap: () => _openAndReload(context, const CreateGroupScreen()),
            ),
          ],
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: NiyaNightBackdrop()),
            BlocConsumer<GroupListBloc, GroupListState>(
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
                  return Padding(
                    padding: EdgeInsets.only(top: topInset + 48.h),
                    child: const Align(
                      alignment: Alignment.topCenter,
                      child: CircularProgressIndicator(
                        color: NiyaPalette.gold,
                      ),
                    ),
                  );
                }

                if (state is GroupListFailure) {
                  return _refreshable(
                    context,
                    topInset,
                    _NightEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load your groups',
                      body: state.failure.errorMessage,
                      actionLabel: 'Try again',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () =>
                          context.read<GroupListBloc>().add(GroupListLoadEvent()),
                    ),
                  );
                }

                final data = state as GroupListSuccess;

                if (data.groups.isEmpty && data.invitations.isEmpty) {
                  return _refreshable(
                    context,
                    topInset,
                    _NightEmptyState(
                      icon: Icons.groups_2_rounded,
                      title: 'Start an Equb with your circle'.tr,
                      body:
                          'Pick a package, invite your family or friends, and run your own draws.'
                              .tr,
                      actionLabel: 'Create a group'.tr,
                      actionIcon: Icons.add_rounded,
                      onAction: () =>
                          _openAndReload(context, const CreateGroupScreen()),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: NiyaPalette.gold,
                  backgroundColor: NiyaPalette.navy,
                  edgeOffset: topInset,
                  // Waits for the reload rather than completing the instant the
                  // event is added, which is why the pull never looked like it
                  // did anything.
                  onRefresh: () => _reload(context),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      topInset + 6.h,
                      16.w,
                      130.h,
                    ),
                    children: [
                      if (data.invitations.isNotEmpty) ...[
                        const NiyaOrnamentTitle(title: 'Invitations'),
                        SizedBox(height: 14.h),
                        for (final i in data.invitations)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _InvitationCard(invitation: i),
                          ),
                        SizedBox(height: 14.h),
                      ],
                      if (data.groups.isNotEmpty) ...[
                        NiyaOrnamentTitle(title: 'Your groups'.tr),
                        SizedBox(height: 14.h),
                        for (final g in data.groups)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _GroupCard(group: g),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One pull-to-refresh for every branch of this screen, including the empty
  /// and error states — those used to sit outside the RefreshIndicator, so
  /// there was no way to retry without leaving and coming back.
  Widget _refreshable(BuildContext context, double topInset, Widget child) {
    return RefreshIndicator(
      color: NiyaPalette.gold,
      backgroundColor: NiyaPalette.navy,
      edgeOffset: topInset,
      onRefresh: () => _reload(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final room = constraints.maxHeight - topInset;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(top: topInset),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: room > 0 ? room : 0),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _reload(BuildContext context) => refreshWith(
    (signal) => context.read<GroupListBloc>().add(
      GroupListLoadEvent(isSilent: true, signal: signal),
    ),
  );
}

/// Pushes [screen] and pulls the list again when it closes, so a group created
/// or joined over there shows up here without a manual refresh.
Future<void> _openAndReload(BuildContext context, Widget screen) async {
  final bloc = context.read<GroupListBloc>();
  await Get.to(() => screen);
  if (context.mounted) {
    bloc.add(GroupListLoadEvent(isSilent: true));
  }
}

/// One group in the list.
///
/// Built from the same parts as the package rows on the Equb tab — star badge,
/// gold divider, gold hairline border, chevron — because a member moving
/// between the two lists should feel they are reading one catalogue.
class _GroupCard extends StatelessWidget {
  final EqubCircle group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16.r);

    // Night-legible status colours. The light-theme greens and blues used
    // elsewhere go muddy against navy, so these are the 400-weight versions.
    final (statusLabel, statusColor) = switch (group.status) {
      'running' => ('Running', const Color(0xFF4ADE80)),
      'completed' => ('Completed', const Color(0xFF38BDF8)),
      'cancelled' => ('Cancelled', const Color(0xFF94A3B8)),
      _ => group.isPendingApproval
          ? ('Waiting for approval', const Color(0xFFFBBF24))
          : ('Collecting members', NiyaPalette.goldLight),
    };

    return Material(
      color: NiyaPalette.navySoft,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: radius,
      child: InkWell(
        onTap: () => context.navigateOnce(
          () => Get.to(() => GroupDetailScreen(groupId: group.id)),
        ),
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: NiyaPalette.gold.withValues(alpha: 0.35)),
          ),
          padding: EdgeInsets.fromLTRB(10.w, 12.h, 8.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // The badge carries the package's own glyph when the group
                  // was built on one, so a Hajj circle wears the Kaaba here
                  // exactly as it does in the package list.
                  NiyaStarBadge(
                    size: 60.r,
                    child: packageGlyph(
                      group.packageName ?? group.name,
                      size: 26.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    width: 1.4,
                    height: 64.h,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00C9A24A),
                          NiyaPalette.gold,
                          Color(0x00C9A24A),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${etb(group.contributionAmount)} every '
                          '${group.contributionFrequencyDays} day(s)'
                          '${group.packageName != null ? ' · ${group.packageName}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // The status leads the chip row rather than sitting
                        // opposite the title. A pill beside the name robbed it
                        // of most of its width on a narrow phone - "Waiting
                        // for approval" is wider than many group names - and a
                        // Wrap cannot overflow however long the label gets.
                        Wrap(
                          spacing: 5.w,
                          runSpacing: 4.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _NightPill(label: statusLabel, color: statusColor),
                            _MetaChip(
                              icon: Icons.people_alt_rounded,
                              label:
                                  '${group.currentMembersCount}/${group.maxMembers} ${'Members'.tr}',
                            ),
                            _MetaChip(
                              icon: Icons.emoji_events_rounded,
                              label:
                                  '${'round'.tr} ${group.roundsCompleted + 1} '
                                  '${'of'.tr} ${group.roundsTotal}',
                            ),
                            if (group.isOwner)
                              _MetaChip(
                                icon: Icons.verified_rounded,
                                label: 'You created this'.tr,
                                outlined: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 26.sp,
                  ),
                ],
              ),
              if (group.isRejected && group.rejectionReason != null) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFFF87171).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    group.rejectionReason!,
                    style: TextStyle(
                      color: const Color(0xFFFCA5A5),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
    final radius = BorderRadius.circular(16.r);

    return Material(
      color: NiyaPalette.navySoft,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          // A heavier gold line than a group card: an invitation is waiting on
          // the member, and should read as the louder thing on the page.
          border: Border.all(
            color: NiyaPalette.gold.withValues(alpha: 0.65),
            width: 1.2,
          ),
        ),
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NiyaStarBadge(
                  size: 44.r,
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    size: 19.r,
                    color: NiyaPalette.maroon,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${invitation.invitedByName ?? 'Someone'} invited you '
                        'to "${invitation.groupName}"',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        '${etb(invitation.contributionAmount)} per round',
                        style: TextStyle(
                          color: NiyaPalette.goldLight,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.message != null &&
                invitation.message!.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: NiyaPalette.navyDeep.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '"${invitation.message}"',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: NiyaGoldButton(
                    label: 'Join',
                    icon: Icons.check_rounded,
                    height: 42.h,
                    fontSize: 13.sp,
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
                  child: _GhostButton(
                    label: 'Decline',
                    height: 42.h,
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
      ),
    );
  }
}

/// A small status pill that holds up against navy: a tinted ground, a half
/// strength ring and the label in the full colour.
class _NightPill extends StatelessWidget {
  final String label;
  final Color color;

  const _NightPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The maroon chips of a package row, carrying a group's figures instead of
/// its cycles.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool outlined;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
      decoration: BoxDecoration(
        color: outlined
            ? Colors.transparent
            : NiyaPalette.maroon.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: outlined
            ? Border.all(color: NiyaPalette.gold.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: NiyaPalette.goldLight),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: NiyaPalette.goldLight,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two floating actions. Plain widgets rather than FloatingActionButtons
/// because the Material FAB insists on its own shape, elevation tint and
/// theme colours, all of which fight the gold.
class _NightAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _NightAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final foreground = filled
        ? NiyaPalette.maroonDeep
        : NiyaPalette.goldLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: filled ? NiyaPalette.goldSheen : null,
        color: filled ? null : NiyaPalette.navyDeep.withValues(alpha: 0.92),
        borderRadius: radius,
        border: Border.all(
          color: filled ? NiyaPalette.goldLight : NiyaPalette.gold,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: filled
                ? NiyaPalette.gold.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17.sp, color: foreground),
                SizedBox(width: 7.w),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
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

/// The quiet half of a pair of buttons: a gold outline and nothing inside it.
class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final double? height;

  const _GhostButton({
    required this.label,
    required this.onPressed,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: NiyaPalette.gold.withValues(alpha: 0.55)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: SizedBox(
            height: height ?? 44.h,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says what is missing and what to do about it, in the night style.
///
/// The shared [GroupEmptyState] is built on the app theme's text and surface
/// colours, which disappear against this backdrop — hence a local one.
class _NightEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _NightEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NiyaStarBadge(
            size: 86.r,
            child: Icon(icon, size: 34.r, color: NiyaPalette.maroon),
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20.h),
          _NightAction(
            icon: actionIcon,
            label: actionLabel,
            filled: true,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}
