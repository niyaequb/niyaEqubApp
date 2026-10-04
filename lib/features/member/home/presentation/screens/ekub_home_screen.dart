import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/util/refresh_signal.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_bloc.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_event.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_state.dart';
import 'package:niya_equb/features/member/home/models/home_promotions.dart';

import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:url_launcher/url_launcher.dart';

class EkubHomeScreen extends StatelessWidget {
  const EkubHomeScreen({super.key, this.onJoinGroups});

  /// Called when user taps the Join groups FAB. typically switches to Equb tab.
  final VoidCallback? onJoinGroups;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EkubHomeBloc, EkubHomeState>(
      builder: (context, state) {
        if (state is EkubHomeLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = switch (state) {
          EkubHomeSuccess s => s.user,
          EkubHomeFailure s => s.user,
          _ => null,
        };

        final allMemberships = switch (state) {
          EkubHomeSuccess s => s.memberships,
          EkubHomeFailure s => s.memberships,
          _ => const <EqubMembership>[],
        };

        // Filter for joined groups only
        final memberships = allMemberships
            .where((m) => m.equbGroupId != null && m.equbGroup != null)
            .toList();

        final banners = switch (state) {
          EkubHomeSuccess s => s.promotions?.banners ?? const [],
          _ => const <EqubBanner>[],
        };

        final companyFacts = switch (state) {
          EkubHomeSuccess s => s.promotions?.companyFacts ?? const [],
          _ => const <CompanyFact>[],
        };

        final appColors = colors(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);

        final firstName =
            (user?.name
                .trim()
                .split(' ')
                .firstWhere((e) => e.isNotEmpty, orElse: () => 'member'.tr)) ??
            'member'.tr;

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          body: RefreshIndicator(
            // Waits for the reload instead of a fixed one second delay.
            onRefresh: () => refreshWith(
              (signal) => context.read<EkubHomeBloc>().add(
                EkubHomeLoadEvent(isSilent: true, signal: signal),
              ),
            ),
            color: appColors.primaryColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  toolbarHeight: math.max(64.h, 64) * math.min(1.25, textScale),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        title: 'app_name'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        textColor: appColors.titleTextColor,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      CustomText(
                        title: '${'welcome_back_short'.tr}, $firstName',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        textColor: appColors.bodyTextSmallColor,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  actions: [SizedBox(width: 6.w)],
                ),

                if (banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: _BannerCarousel(banners: banners),
                    ),
                  ),

                if (companyFacts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: _CompanyFactsSection(facts: companyFacts),
                    ),
                  ),

                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  sliver: SliverToBoxAdapter(
                    child: CustomText(
                      title: 'my_joined_groups'.tr,
                      fontSize: 14.sp,
                      textColor: appColors.titleTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (memberships.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 32.h),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: 0.5,
                                child: NiyaLogo(size: 56.sp),
                              ),
                              SizedBox(height: 16.h),
                              CustomText(
                                title: 'no_joined_equbs'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                textColor: appColors.bodyTextSmallColor,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 6.h),
                              CustomText(
                                title: 'joined_equbs_subtitle'.tr,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                textColor: appColors.bodyTextSmallColor,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    sliver: SliverList.separated(
                      itemCount: memberships.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final m = memberships[index];
                        return GestureDetector(
                          onTap: () {
                            if (m.equbGroupId != null) {
                              final activeDraw = state is EkubHomeSuccess 
                                ? state.activeDraws[m.equbGroupId]
                                : null;

                              Navigator.pushNamed(
                                context,
                                EqubDetailScreen.routeName,
                                arguments: {
                                  'groupId': m.equbGroupId,
                                  'drawType': activeDraw?['type'],
                                  'winnerName': activeDraw?['winnerName'],
                                  'candidates': activeDraw?['candidates'],
                                  'drawTime': activeDraw?['timestamp'],
                                  'initialTab': activeDraw != null ? 2 : 0,
                                },
                              ).then((_) {
                                if (context.mounted) {
                                  context.read<EkubHomeBloc>().add(
                                    EkubHomeLoadEvent(isSilent: true),
                                  );
                                }
                              });
                            }
                          },
                          child: _JoinedGroupCard(membership: m, isDark: isDark),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 12.h)),
              ],
            ),
          ),
          floatingActionButton: AnimatedScale(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            scale: 1,
            child: FloatingActionButton.extended(
              onPressed: onJoinGroups,
              backgroundColor: appColors.primaryColor,
              foregroundColor: Colors.black.withValues(alpha: 0.85),
              elevation: isDark ? 0 : 1,
              label: Row(
                children: [
                  const Icon(Icons.add_rounded),
                  SizedBox(width: 8.w),
                  Text('join_groups'.tr),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompanyFactsSection extends StatelessWidget {
  final List<CompanyFact> facts;
  const _CompanyFactsSection({required this.facts});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: CustomText(
            title: 'Niya Facts'.tr,
            fontSize: 14.sp,
            textColor: appColors.titleTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 68.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            itemCount: facts.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final fact = facts[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: appColors.accentColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: appColors.borderColor!.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CustomText(
                      title: fact.value ?? '',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.primaryColor,
                    ),
                    SizedBox(height: 2.h),
                    CustomText(
                      title: fact.label ?? '',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.bodyTextSmallColor,
                      maxLines: 1,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<EqubBanner> banners;
  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        if (_currentPage < widget.banners.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 160.h,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page! - index);
                    value = (1 - (value.abs() * 0.05)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 160.h,
                      width: Curves.easeOut.transform(value) * 1.sw,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () async {
                    if (banner.linkUrl != null && banner.linkUrl!.isNotEmpty) {
                      final url = Uri.tryParse(banner.linkUrl!);
                      if (url != null && await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.imageUrl != null &&
                          banner.imageUrl!.isNotEmpty)
                        Image.network(
                          banner.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: appColors.accentColor,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: appColors.bodyTextSmallColor,
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                appColors.primaryColor!,
                                appColors.primaryColor!.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (banner.title != null)
                              CustomText(
                                title: banner.title!,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                textColor: Colors.white,
                                maxLines: 1,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            if (banner.subtitle != null) ...[
                              SizedBox(height: 2.h),
                              CustomText(
                                title: banner.subtitle!,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                textColor: Colors.white.withValues(alpha: 0.9),
                                maxLines: 2,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              height: 4.h,
              width: _currentPage == index ? 16.w : 4.w,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? appColors.primaryColor
                    : appColors.bodyTextSmallColor?.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JoinedGroupCard extends StatelessWidget {
  final EqubMembership membership;
  final bool isDark;

  const _JoinedGroupCard({required this.membership, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          // The Niya mark, on white in both themes: its black shield would
          // be lost on a dark tile.
          Container(
            height: 52.r,
            width: 52.r,
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: NiyaPalette.gold.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: NiyaLogo(size: 38.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: membership.groupName ?? 'Equb',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                if (membership.contributionAmount != null)
                  CustomText(
                    title:
                        '${membership.contributionAmount!.toStringAsFixed(0)} Birr',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                if (membership.status != null &&
                    membership.status!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  CustomText(
                    title: membership.status!
                        .split('_')
                        .map(
                          (s) => s.isEmpty
                              ? s
                              : '${s[0].toUpperCase()}${s.substring(1)}',
                        )
                        .join(' '),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    textColor: appColors.primaryColor,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: appColors.bodyTextSmallColor,
            size: 22.sp,
          ),
        ],
      ),
    );
  }
}
