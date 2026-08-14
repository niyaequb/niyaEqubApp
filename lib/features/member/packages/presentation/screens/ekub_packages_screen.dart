import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_bloc.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_event.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_state.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/my_groups_screen.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class EkubPackagesScreen extends StatefulWidget {
  const EkubPackagesScreen({super.key});

  static void _showTermsAndJoin(
    BuildContext context,
    EqubGroup group,
    EkubPackagesBloc bloc,
  ) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: appColors.scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          child: SafeArea(
            top: false,
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
                  title: 'terms_and_conditions'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                ),
                SizedBox(height: 12.h),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: CustomText(
                      title:
                          group.termsAndConditions ?? 'no_terms_available'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      textColor: appColors.bodyTextColor,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: RoundedButton(
                        label: 'cancel'.tr,
                        height: 48.h,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        foregroundColor: appColors.bodyTextSmallColor,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: RoundedButton(
                        label: 'accept_and_join'.tr,
                        height: 48.h,
                        backgroundColor: appColors.primaryColor,
                        foregroundColor: Colors.black.withValues(alpha: 0.85),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          bloc.add(EkubPackagesJoinGroupEvent(group: group));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<EkubPackagesScreen> createState() => _EkubPackagesScreenState();
}

class _EkubPackagesScreenState extends State<EkubPackagesScreen> {
  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return BlocConsumer<EkubPackagesBloc, EkubPackagesState>(
      listener: (context, state) {
        if (state is EkubPackagesFailure) {
          showErrorSnackBar(context, state.failure.errorMessage);
        }
        if (state is EkubPackagesSuccess && state.joinSuccess) {
          showSuccessSnackBar(context, 'join_success'.tr);
        }
      },
      builder: (context, state) {
        final packages = switch (state) {
          EkubPackagesSuccess s => s.packages,
          EkubPackagesFailure s => s.packages,
          _ => const <EqubPackage>[],
        };
        final groups = switch (state) {
          EkubPackagesSuccess s => s.filteredGroups,
          EkubPackagesFailure s => s.filteredGroups,
          _ => const <EqubGroup>[],
        };
        final selectedPackageId = switch (state) {
          EkubPackagesSuccess s => s.selectedPackageId,
          EkubPackagesFailure s => s.selectedPackageId,
          _ => null,
        };
        final joiningGroupId = switch (state) {
          EkubPackagesSuccess s => s.joiningGroupId,
          EkubPackagesFailure f => f.joiningGroupId,
          _ => null,
        };
        final isLoading = state is EkubPackagesLoading;
        final isLoadingGroups =
            state is EkubPackagesSuccess && state.isLoadingGroups;

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('equb'.tr),
            actions: [
              // Opens the member's own group Equbs, with a Create button inside.
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: InkWell(
                  onTap: () => context.navigateOnce(
                    () => Get.to(() => const MyGroupsScreen()),
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: (appColors.primaryColor ?? Colors.amber)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: (appColors.primaryColor ?? Colors.amber)
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_add_rounded,
                          size: 16.r,
                          color: appColors.primaryColor,
                        ),
                        SizedBox(width: 6.w),
                        CustomText(
                          title: 'group_equb'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          textColor: appColors.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: appColors.primaryColor,
            // Waits for the reload to finish instead of snapping back after a
            // fixed half second, so the spinner reflects the actual request.
            onRefresh: () => refreshWith(
              (signal) => context.read<EkubPackagesBloc>().add(
                EkubPackagesLoadEvent(isSilent: true, signal: signal),
              ),
            ),
            child: _GroupsTab(
              packages: packages,
              groups: groups,
              selectedPackageId: selectedPackageId,
              joiningGroupId: joiningGroupId,
              isLoading: isLoading,
              isLoadingGroups: isLoadingGroups,
              activeDraws: state is EkubPackagesSuccess
                  ? state.activeDraws
                  : const {},
            ),
          ),
        );
      },
    );
  }
}

class _GroupsTab extends StatelessWidget {
  final List<EqubPackage> packages;
  final List<EqubGroup> groups;
  final int? selectedPackageId;
  final String? joiningGroupId;
  final bool isLoading;
  final bool isLoadingGroups;
  final Map<int, Map<String, dynamic>> activeDraws;

  const _GroupsTab({
    required this.packages,
    required this.groups,
    required this.selectedPackageId,
    required this.joiningGroupId,
    required this.isLoading,
    required this.isLoadingGroups,
    required this.activeDraws,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    if (isLoading) {
      // Scrollable so a pull still reaches the RefreshIndicator above; a bare
      // Center would swallow the gesture.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: 160.h),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: CustomText(
              title: 'filter_by_package'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              textColor: appColors.bodyTextSmallColor,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _FilterChips(
            packages: packages,
            selectedPackageId: selectedPackageId,
            onSelect: (id) => context.read<EkubPackagesBloc>().add(
              EkubPackagesSelectFilterEvent(packageId: id),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 8.h),
            child: CustomText(
              title: 'equb_groups'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              textColor: appColors.titleTextColor,
            ),
          ),
        ),
        if (isLoadingGroups)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 64.sp,
                      color: appColors.bodyTextSmallColor?.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    CustomText(
                      title: 'no_groups_found'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
            sliver: SliverList.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final g = groups[index];
                final isJoining = joiningGroupId == g.id?.toString();
                return GestureDetector(
                  onTap: g.isJoined
                      ? () {
                          final activeDraw = activeDraws[g.id];

                          context.pushOnce(
                            EqubDetailScreen.routeName,
                            arguments: {
                              'groupId': g.id,
                              'drawType': activeDraw?['type'],
                              'winnerName': activeDraw?['winnerName'],
                              'candidates': activeDraw?['candidates'],
                              'drawTime': activeDraw?['timestamp'],
                              'initialTab': activeDraw != null ? 2 : 0,
                            },
                          )?.then((_) {
                            if (context.mounted) {
                              context.read<EkubPackagesBloc>().add(
                                EkubPackagesLoadEvent(isSilent: true),
                              );
                            }
                          });
                        }
                      : null,
                  child: _EqubGroupCard(
                    group: g,
                    isJoining: isJoining,
                    onJoin: (g.id != null && !g.isJoined)
                        ? () => EkubPackagesScreen._showTermsAndJoin(
                            context,
                            g,
                            context.read<EkubPackagesBloc>(),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<EqubPackage> packages;
  final int? selectedPackageId;
  final void Function(int? packageId) onSelect;

  const _FilterChips({
    required this.packages,
    required this.selectedPackageId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: packages.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          final p = entry.value;
          return Padding(
            padding: EdgeInsets.only(left: isFirst ? 0 : 8.w),
            child: _Chip(
              label: p.name ?? 'Package ${p.id}',
              isSelected: selectedPackageId == p.id,
              onTap: () => onSelect(p.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? appColors.primaryColor!.withValues(alpha: isDark ? 0.3 : 0.2)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? appColors.primaryColor!
                : (appColors.borderColor ?? Colors.transparent),
          ),
        ),
        child: CustomText(
          title: label,
          fontSize: 13.sp,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          textColor: isSelected
              ? appColors.primaryColor
              : appColors.bodyTextSmallColor,
        ),
      ),
    );
  }
}

class _EqubGroupCard extends StatelessWidget {
  final EqubGroup group;
  final bool isJoining;
  final VoidCallback? onJoin;

  const _EqubGroupCard({
    required this.group,
    required this.isJoining,
    this.onJoin,
  });

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44.r,
                width: 44.r,
                decoration: BoxDecoration(
                  color: appColors.primaryColor!.withValues(
                    alpha: isDark ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: appColors.primaryColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      title:
                          group.name ??
                          group.packageName ??
                          'Group ${group.id}',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.titleTextColor,
                    ),
                    if (group.status != null && group.status!.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      CustomText(
                        title: '${'status'.tr}: ${group.status}',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        textColor: appColors.bodyTextSmallColor,
                        maxLines: 2,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: appColors.bodyTextSmallColor,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              if (group.birrPerDay != null)
                _Pill(
                  icon: Icons.payments_rounded,
                  label: '${group.birrPerDay} ETB',
                ),
              if (group.duration != null &&
                  group.duration!.trim().isNotEmpty &&
                  group.durationDays != " ")
                _Pill(icon: Icons.schedule_rounded, label: group.duration!)
              else if (group.durationDays != null)
                _Pill(
                  icon: Icons.schedule_rounded,
                  label: '${group.durationDays} ${'days'.tr}',
                ),
              if (group.frequencyLabel != null)
                _Pill(
                  icon: Icons.repeat_rounded,
                  label: group.frequencyLabel!.tr,
                ),
              if (group.registrationCloseAt != null)
                _Pill(
                  icon: Icons.event_rounded,
                  label:
                      '${'closes'.tr}: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(group.registrationCloseAt!))}',
                ),
              if (group.equbStartDate != null)
                _Pill(
                  icon: Icons.calendar_today_rounded,
                  label:
                      '${'starts_on'.tr}: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(group.equbStartDate!))}',
                ),
            ],
          ),
          SizedBox(height: 14.h),
          RoundedButton(
            label: group.isJoined ? 'joined'.tr : 'join'.tr,
            height: 42.h,
            submitting: isJoining,
            icon: group.isJoined
                ? Icon(Icons.check_circle, color: Colors.green, size: 18.sp)
                : null,
            backgroundColor: group.isJoined
                ? (isDark ? Colors.white10 : Colors.grey.shade200)
                : appColors.primaryColor,
            disabledBackgroundColor: group.isJoined
                ? (isDark ? Colors.white10 : Colors.grey.shade200)
                : null,
            foregroundColor: group.isJoined
                ? (isDark ? appColors.bodyTextSmallColor : Colors.grey.shade700)
                : Colors.black.withValues(alpha: 0.85),
            onPressed: (isJoining || onJoin == null || group.isJoined)
                ? null
                : onJoin,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: appColors.bodyTextSmallColor),
          SizedBox(width: 6.w),
          Flexible(
            child: CustomText(
              title: label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              textColor: appColors.bodyTextSmallColor,
              maxLines: 1,
              softWrap: false,
              textOverflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
