import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/my_groups_screen.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/package_detail_screen.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_bloc.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_event.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_state.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

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
    return BlocConsumer<EkubPackagesBloc, EkubPackagesState>(
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
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: NiyaPalette.navyDeep,
            body: Stack(
              children: [
                const Positioned.fill(child: NiyaNightBackdrop()),
                RefreshIndicator(
                  color: NiyaPalette.gold,
                  backgroundColor: NiyaPalette.navy,
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
                        child: SafeArea(
                          bottom: false,
                          child: _Header(
                            onGroupEqub: () => context.navigateOnce(
                              () => Get.to(() => const MyGroupsScreen()),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                          child: NiyaOrnamentTitle(title: 'pkg_list_title'.tr),
                        ),
                      ),
                      if (isLoading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 48.h),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: NiyaPalette.gold,
                              ),
                            ),
                          ),
                        )
                      else if (packages.isEmpty)
                        const SliverToBoxAdapter(child: _NoPackages())
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 28.h),
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
                    ],
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

/// The logo, the app's name and its line, under two gold arches.
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
          padding: EdgeInsets.fromLTRB(16.w, 6.h, 14.w, 10.h),
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
                  border: Border.all(color: NiyaPalette.gold, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: NiyaPalette.gold.withValues(alpha: 0.35),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: NiyaLogo(size: 64.r),
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
                  const Expanded(child: NiyaGoldRule()),
                  Container(
                    constraints: BoxConstraints(maxWidth: 240.w),
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Text(
                      'pkg_tagline'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NiyaPalette.goldLight,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Expanded(child: NiyaGoldRule(leadsRight: false)),
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
            color: NiyaPalette.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: NiyaPalette.gold),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_add_rounded,
                size: 16.sp,
                color: NiyaPalette.goldLight,
              ),
              SizedBox(width: 6.w),
              Text(
                'group_equb'.tr,
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

/// One package in the list: its badge, name, how long it runs and the cycles
/// it offers.
class _PackageTile extends StatelessWidget {
  final EqubPackage package;
  final VoidCallback? onTap;

  const _PackageTile({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : NiyaPalette.ink;
    final inkSoft = isDark ? Colors.white70 : NiyaPalette.inkSoft;
    final duration = packageDurationText(package);
    final cycles = packageCycles(package);
    final radius = BorderRadius.circular(16.r);

    return Material(
      color: isDark ? NiyaPalette.navySoft : Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: NiyaPalette.gold.withValues(alpha: 0.35)),
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
                      package.name ?? 'Equb',
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
                            color: isDark
                                ? NiyaPalette.goldLight
                                : NiyaPalette.goldDeep,
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
                                color: NiyaPalette.maroon.withValues(
                                  alpha: isDark ? 0.4 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: isDark
                                      ? NiyaPalette.goldLight
                                      : NiyaPalette.maroon,
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

class _NoPackages extends StatelessWidget {
  const _NoPackages();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.w, 40.h, 32.w, 32.h),
      child: Column(
        children: [
          Icon(
            Icons.mosque_rounded,
            size: 56.sp,
            color: NiyaPalette.gold.withValues(alpha: 0.6),
          ),
          SizedBox(height: 14.h),
          Text(
            'pkg_no_packages'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A gold arch in a top corner of the header, after the frame of the Niya
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
      ..color = NiyaPalette.gold.withValues(alpha: 0.75);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = NiyaPalette.gold.withValues(alpha: 0.5);

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
      Paint()..color = NiyaPalette.gold.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_CornerArchPainter oldDelegate) =>
      oldDelegate.mirrored != mirrored;
}
