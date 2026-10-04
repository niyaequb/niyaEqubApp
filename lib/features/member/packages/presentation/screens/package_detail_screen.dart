import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_ticket_card.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_bloc.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_event.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_state.dart';
import 'package:niya_equb/shared/presentation/screens/terms_screen.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// One package — Al Sabr, Al Nur, Hajj… — and the Equb plans inside it
/// (monthly, weekly, daily), each of which can be joined from here.
///
/// Shares the Equb tab's [EkubPackagesBloc]: opening a package selects it in
/// the bloc, which loads that package's plans, and joining goes through the
/// same event the tab always used.
class PackageDetailScreen extends StatelessWidget {
  final EqubPackage package;

  const PackageDetailScreen({super.key, required this.package});

  /// Opens [package] on top of the Equb tab.
  ///
  /// The new route is not under the tab's providers, so the bloc is handed
  /// over explicitly.
  static void open(BuildContext context, EqubPackage package) {
    final bloc = context.read<EkubPackagesBloc>();
    context.navigateOnce(() {
      bloc.add(EkubPackagesSelectFilterEvent(packageId: package.id));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: PackageDetailScreen(package: package),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<EkubPackagesBloc, EkubPackagesState>(
      listener: (context, state) {
        // The Equb tab underneath listens to the same bloc; only the screen
        // in front speaks.
        if (!context.isTopRoute) return;
        if (state is EkubPackagesFailure) {
          showErrorSnackBar(context, state.failure.errorMessage);
        }
        if (state is EkubPackagesSuccess && state.joinSuccess) {
          showSuccessSnackBar(context, 'join_success'.tr);
        }
      },
      builder: (context, state) {
        final current = _latest(state) ?? package;

        final selected = switch (state) {
          EkubPackagesSuccess s => s.selectedPackageId,
          EkubPackagesFailure s => s.selectedPackageId,
          _ => null,
        };
        final isThisPackage = selected == package.id;

        final groups = !isThisPackage
            ? const <EqubGroup>[]
            : switch (state) {
                EkubPackagesSuccess s => s.filteredGroups,
                EkubPackagesFailure s => s.filteredGroups,
                _ => const <EqubGroup>[],
              };
        // Not this package any more — a reload dropped it from the list —
        // shows as no plans rather than spinning for ever.
        final isLoading =
            state is EkubPackagesLoading ||
            (isThisPackage &&
                state is EkubPackagesSuccess &&
                state.isLoadingGroups);
        final joiningId = switch (state) {
          EkubPackagesSuccess s => s.joiningGroupId,
          EkubPackagesFailure s => s.joiningGroupId,
          _ => null,
        };
        final activeDraws = state is EkubPackagesSuccess
            ? state.activeDraws
            : const <int, Map<String, dynamic>>{};

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: isDark ? NiyaPalette.navyDeep : NiyaPalette.cream,
            body: Stack(
              children: [
                RefreshIndicator(
                  color: NiyaPalette.gold,
                  backgroundColor: NiyaPalette.navy,
                  edgeOffset: MediaQuery.paddingOf(context).top,
                  onRefresh: () => refreshWith(
                    (signal) => context.read<EkubPackagesBloc>().add(
                      EkubPackagesLoadEvent(isSilent: true, signal: signal),
                    ),
                  ),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _PackageHero(
                          package: current,
                          onTerms: _termsOf(current, groups) == null
                              ? null
                              : () => TermsScreen.open(
                                  context,
                                  terms: _termsOf(current, groups),
                                  subtitle: current.name,
                                ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 6.h),
                          child: _SectionLabel(
                            text: 'pkg_choose_plan'.tr,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      if (isLoading && groups.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 60.h),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: NiyaPalette.gold,
                              ),
                            ),
                          ),
                        )
                      else if (groups.isEmpty)
                        SliverToBoxAdapter(child: _NoPlans(isDark: isDark))
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 32.h),
                          sliver: SliverList.separated(
                            itemCount: groups.length,
                            separatorBuilder: (_, _) => SizedBox(height: 16.h),
                            // The page's context, not the row's: a row can
                            // leave the list while its join is in flight.
                            itemBuilder: (_, index) {
                              final g = groups[index];
                              return EqubTicketCard(
                                group: g,
                                packageName: current.name,
                                isJoining:
                                    g.id != null && joiningId == g.id.toString(),
                                onJoin: g.id == null
                                    ? null
                                    : () => _join(context, g, current),
                                onOpen: g.id == null
                                    ? null
                                    : () => _openJoined(context, g, activeDraws),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                // The status bar keeps the header's navy once the header has
                // scrolled away, so its light icons stay readable over the
                // cream page.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.paddingOf(context).top,
                  child: const ColoredBox(color: NiyaPalette.nightTop),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The package as the bloc last loaded it, so a refresh shows here too.
  EqubPackage? _latest(EkubPackagesState state) {
    final packages = switch (state) {
      EkubPackagesSuccess s => s.packages,
      EkubPackagesFailure s => s.packages,
      _ => const <EqubPackage>[],
    };
    for (final p in packages) {
      if (p.id == package.id) return p;
    }
    return null;
  }

  /// The package's terms. Every plan in a package shares them, so any plan
  /// that carries them will do when the package itself does not.
  static String? _termsOf(EqubPackage package, List<EqubGroup> groups) {
    final own = package.termsContent?.trim();
    if (own != null && own.isNotEmpty) return own;
    for (final g in groups) {
      final terms = g.termsAndConditions?.trim();
      if (terms != null && terms.isNotEmpty) return terms;
    }
    return null;
  }

  /// Joining always goes through the terms: the member reads them on a full
  /// page and ticks that they accept before the request is sent.
  Future<void> _join(
    BuildContext context,
    EqubGroup group,
    EqubPackage current,
  ) async {
    final bloc = context.read<EkubPackagesBloc>();
    final terms = group.termsAndConditions?.trim().isNotEmpty == true
        ? group.termsAndConditions
        : _termsOf(current, const []);

    final accepted = await TermsScreen.open(
      context,
      terms: terms,
      subtitle: group.name ?? current.name,
      requireAcceptance: true,
    );
    if (!accepted || bloc.isClosed) return;

    // Once the join goes through, the plan leaves this list (it is the
    // member's now), so the member is taken straight into it instead.
    //
    // A failure that settles this join comes with joiningGroupId cleared; the
    // one emitted as the join starts still carries it.
    final finished = bloc.stream
        .firstWhere(
          (s) =>
              (s is EkubPackagesSuccess && s.joinSuccess) ||
              (s is EkubPackagesFailure && s.joiningGroupId == null),
        )
        .timeout(const Duration(seconds: 45), onTimeout: () => bloc.state);

    bloc.add(EkubPackagesJoinGroupEvent(group: group));

    EkubPackagesState? outcome;
    try {
      outcome = await finished;
    } catch (_) {
      outcome = null;
    }

    if (!context.mounted) return;
    if (outcome is EkubPackagesSuccess &&
        outcome.joinSuccess &&
        group.id != null) {
      Navigator.of(context)
          .pushNamed(
            EqubDetailScreen.routeName,
            arguments: <String, dynamic>{'groupId': group.id},
          )
          .then((_) => _reload(bloc));
    }
  }

  /// Brings the plans up to date after the member comes back from an Equb:
  /// one they have just left is open to join again.
  static void _reload(EkubPackagesBloc bloc) {
    if (!bloc.isClosed) bloc.add(EkubPackagesLoadEvent(isSilent: true));
  }

  void _openJoined(
    BuildContext context,
    EqubGroup group,
    Map<int, Map<String, dynamic>> activeDraws,
  ) {
    final bloc = context.read<EkubPackagesBloc>();
    final activeDraw = activeDraws[group.id];
    context
        .pushOnce(
          EqubDetailScreen.routeName,
          arguments: <String, dynamic>{
            'groupId': group.id,
            'drawType': activeDraw?['type'],
            'winnerName': activeDraw?['winnerName'],
            'candidates': activeDraw?['candidates'],
            'drawTime': activeDraw?['timestamp'],
            'initialTab': activeDraw != null ? 2 : 0,
          },
        )
        ?.then((_) => _reload(bloc));
  }
}

/// The navy header: back button, the package's badge, name, length and
/// cycles, and a way to read its terms before choosing a plan.
class _PackageHero extends StatelessWidget {
  final EqubPackage package;
  final VoidCallback? onTerms;

  const _PackageHero({required this.package, required this.onTerms});

  @override
  Widget build(BuildContext context) {
    final duration = packageDurationText(package);
    final cycles = packageCycles(package);

    return NiyaNightBackdrop(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6.w, 4.h, 14.w, 24.h),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (onTerms != null)
                    _OutlinePill(
                      icon: Icons.description_rounded,
                      label: 'pkg_read_terms'.tr,
                      onTap: onTerms!,
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              NiyaStarBadge(
                size: 92.r,
                child: packageGlyph(package.name, size: 40.r),
              ),
              SizedBox(height: 14.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  package.name ?? 'Equb',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
              if (duration != null) ...[
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 16.sp,
                      color: NiyaPalette.goldLight,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      duration,
                      style: TextStyle(
                        color: NiyaPalette.goldLight,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              if (cycles.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    for (final c in cycles)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: NiyaPalette.gold.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              size: 13.sp,
                              color: NiyaPalette.goldLight,
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              c,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlinePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: NiyaPalette.gold),
            color: NiyaPalette.gold.withValues(alpha: 0.10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15.sp, color: NiyaPalette.goldLight),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: NiyaPalette.goldLight,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            NiyaSparkle(size: 11.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isDark ? Colors.white : NiyaPalette.ink,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        const NiyaGoldRule(leadsRight: false),
      ],
    );
  }
}

class _NoPlans extends StatelessWidget {
  final bool isDark;

  const _NoPlans({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.w, 48.h, 32.w, 32.h),
      child: Column(
        children: [
          Opacity(opacity: 0.55, child: NiyaLogo(size: 64.r)),
          SizedBox(height: 14.h),
          Text(
            'pkg_no_plans'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : NiyaPalette.inkSoft,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
