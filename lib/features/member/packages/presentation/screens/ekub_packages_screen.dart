import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/core/util/package_names.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/my_groups_screen.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/package_detail_screen.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_bloc.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_event.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_state.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_night_theme.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';

/// The Equb tab: every package — Al Sabr, Al Nur, Iman, Hajj… — as a list in
/// the Niya style. A package opens its own page with the plans inside it
/// (monthly, weekly, daily), and those are joined from there.
class EkubPackagesScreen extends StatefulWidget {
  const EkubPackagesScreen({super.key});

  @override
  State<EkubPackagesScreen> createState() => _EkubPackagesScreenState();
}

class _EkubPackagesScreenState extends State<EkubPackagesScreen> {
  @override
  Widget build(BuildContext context) {
    // The brand look in whichever mode the phone is in: the list is drawn
    // from NiyaSkin, so the theme under it is built from the same skin.
    return NiyaBrandTheme(
      child: BlocConsumer<EkubPackagesBloc, EkubPackagesState>(
        listener: (context, state) {
          // A package page on top listens to the same bloc and says it there.
          if (!context.isTopRoute) return;
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
          final isLoading = state is EkubPackagesLoading;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: niyaHeaderOverlay,
            child: Scaffold(
              backgroundColor: niya(context).page,
              body: Stack(
                children: [
                  RefreshIndicator(
                    color: niya(context).accent,
                    backgroundColor: niya(context).paper,
                    edgeOffset: MediaQuery.paddingOf(context).top,
                    // Waits for the reload to finish instead of snapping back
                    // after a fixed half second.
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
                          child: NiyaHeaderBackdrop(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(28.r),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: _Header(
                                onGroupEqub: () => context.navigateOnce(
                                  () => Get.to(() => const MyGroupsScreen()),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
                            child: NiyaOrnamentTitle(title: 'pkg_list_title'.tr),
                          ),
                        ),
                        // The shape of the list while it loads, not a spinner.
                        // Only ever seen on a first launch: after that the tab
                        // opens on the saved list (AppCache).
                        if (isLoading)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                            sliver: SliverList.separated(
                              itemCount: 6,
                              separatorBuilder: (_, _) => SizedBox(height: 12.h),
                              itemBuilder: (_, _) =>
                                  SkeletonCard(lines: 2, height: 84.h),
                            ),
                          )
                        else if (packages.isEmpty)
                          const SliverToBoxAdapter(child: _NoPackages())
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
                            sliver: SliverList.separated(
                              itemCount: packages.length,
                              separatorBuilder: (_, _) => SizedBox(height: 12.h),
                              itemBuilder: (context, index) {
                                final p = packages[index];
                                return _PackageTile(
                                  package: p,
                                  onTap: p.id == null
                                      ? null
                                      : () => PackageDetailScreen.open(context, p),
                                );
                              },
                            ),
                          ),

                        // Group Equb, as the last row of the list.
                        //
                        // Shown in every state except loading - including when
                        // there are no packages at all, where it is the only way
                        // forward rather than a dead end.
                        if (!isLoading)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                packages.isEmpty ? 0 : 12.h,
                                16.w,
                                28.h,
                              ),
                              child: _GroupEqubTile(
                                onTap: () => context.navigateOnce(
                                  () => Get.to(() => const MyGroupsScreen()),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // The status bar keeps the header's maroon once the header
                  // has scrolled away, so its light icons stay readable over
                  // the white page.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.paddingOf(context).top,
                    child: ColoredBox(
                      color: niya(context).header.colors.first,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The logo, the app's name and its line, under two arches, in white on the
/// maroon header.
class _Header extends StatelessWidget {
  final VoidCallback onGroupEqub;

  const _Header({required this.onGroupEqub});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Below the Group Equb button, framing the logo.
        Positioned(
          top: 44.h,
          left: 8.w,
          child: _CornerArch(size: 70.r, mirrored: false),
        ),
        Positioned(
          top: 44.h,
          right: 8.w,
          child: _CornerArch(size: 70.r, mirrored: true),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 6.h, 14.w, 24.h),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _GroupEqubPill(onTap: onGroupEqub),
              ),
              Container(
                width: 92.r,
                height: 92.r,
                padding: EdgeInsets.all(13.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: NiyaLogo(size: 64.r, onLight: true),
              ),
              SizedBox(height: 12.h),
              Text(
                'app_name'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  const Expanded(child: NiyaRule(color: Colors.white)),
                  Container(
                    constraints: BoxConstraints(maxWidth: 240.w),
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Text(
                      'pkg_tagline'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: NiyaRule(leadsRight: false, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the member's own group Equbs, with a Create button inside.
class _GroupEqubPill extends StatelessWidget {
  final VoidCallback onTap;

  const _GroupEqubPill({required this.onTap});

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
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_add_rounded,
                size: 16.sp,
                color: Colors.white,
              ),
              SizedBox(width: 6.w),
              Text(
                'group_equb'.tr,
                style: TextStyle(
                  color: Colors.white,
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

/// One package in the list: its badge, name, how long it runs and the cycles
/// it offers.
class _PackageTile extends StatelessWidget {
  final EqubPackage package;
  final VoidCallback? onTap;

  const _PackageTile({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);
    final ink = skin.ink;
    final inkSoft = skin.inkSoft;
    final duration = packageDurationText(package);
    final cycles = packageCycles(package);
    final radius = BorderRadius.circular(16.r);

    return Material(
      color: skin.paper,
      elevation: skin.isDark ? 0 : 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: skin.line),
          ),
          padding: EdgeInsets.fromLTRB(10.w, 12.h, 8.w, 12.h),
          child: Row(
            children: [
              NiyaStarBadge(
                size: 60.r,
                child: packageGlyph(package.name, size: 26.r),
              ),
              SizedBox(width: 10.w),
              Container(
                width: 1.4,
                height: 46.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      skin.accent.withValues(alpha: 0),
                      skin.accent,
                      skin.accent.withValues(alpha: 0),
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
                      // The official name in the app's language, whatever
                      // language the admin typed it in. See package_names.dart.
                      packageDisplayName(package.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (duration != null) ...[
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 14.sp,
                            color: skin.accent,
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              duration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: inkSoft,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cycles.isNotEmpty) ...[
                      SizedBox(height: 7.h),
                      Wrap(
                        spacing: 5.w,
                        runSpacing: 4.h,
                        children: [
                          for (final c in cycles)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: skin.rose,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: skin.accent,
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: inkSoft, size: 26.sp),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group Equb, offered as the last row of the package list.
///
/// WHY IT IS HERE AS WELL AS IN THE HEADER
///
/// Someone on this screen is choosing what KIND of Equb to join, and starting
/// one with their own family or friends is one of those choices. Until now it
/// was reachable only from a small pill above the logo, which reads as a
/// utility - a settings affordance - rather than an option on the menu. Most
/// people scanning a list of packages never look up there.
///
/// The pill stays. Anyone who already knows where it is keeps their shortcut,
/// and it is the faster route once you do. This is the same destination
/// presented as what it actually is, in the place people are already reading.
///
/// Built from the same parts as _PackageTile on purpose - same badge, same
/// divider, same border, same chevron - because it belongs to that list.
/// A differently shaped card here would read as an advertisement for itself.
class _GroupEqubTile extends StatelessWidget {
  final VoidCallback onTap;

  const _GroupEqubTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);
    final ink = skin.ink;
    final inkSoft = skin.inkSoft;
    final radius = BorderRadius.circular(16.r);

    return Material(
      color: skin.paper,
      elevation: skin.isDark ? 0 : 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: skin.line),
          ),
          padding: EdgeInsets.fromLTRB(10.w, 12.h, 8.w, 12.h),
          child: Row(
            children: [
              NiyaStarBadge(
                size: 60.r,
                child: Icon(
                  Icons.groups_rounded,
                  size: 26.r,
                  color: skin.accent,
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                width: 1.4,
                height: 46.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      skin.accent.withValues(alpha: 0),
                      skin.accent,
                      skin.accent.withValues(alpha: 0),
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
                      'pkg_family_group_ekub'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Pick a package, invite your family or friends, and run your own draws.'
                          .tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: inkSoft,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: inkSoft, size: 26.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPackages extends StatelessWidget {
  const _NoPackages();

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(32.w, 40.h, 32.w, 32.h),
      child: Column(
        children: [
          Icon(
            Icons.mosque_rounded,
            size: 56.sp,
            color: skin.accent.withValues(alpha: 0.5),
          ),
          SizedBox(height: 14.h),
          Text(
            'pkg_no_packages'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: skin.inkSoft,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white arch in a top corner of the header, after the frame of the Niya
/// artwork.
class _CornerArch extends StatelessWidget {
  final double size;
  final bool mirrored;

  const _CornerArch({required this.size, required this.mirrored});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CornerArchPainter(mirrored: mirrored)),
      ),
    );
  }
}

class _CornerArchPainter extends CustomPainter {
  final bool mirrored;

  const _CornerArchPainter({required this.mirrored});

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.55);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.35);

    // Two concentric quarter arches springing from the corner.
    final outer = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(0, 0, w, 0);
    final inner = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.04, w * 0.04, w * 0.72, 0);
    canvas.drawPath(outer, line);
    canvas.drawPath(inner, thin);

    // A star where the arches are deepest.
    canvas.drawPath(
      eightPointStar(w * 0.07).shift(Offset(w * 0.24, h * 0.24)),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_CornerArchPainter oldDelegate) =>
      oldDelegate.mirrored != mirrored;
}
