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
import 'package:niya_equb/features/member/home/presentation/widgets/banner_image.dart';

import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';
import 'package:url_launcher/url_launcher.dart';

class EkubHomeScreen extends StatelessWidget {
  const EkubHomeScreen({super.key, this.onJoinGroups});

  /// Called when user taps the Join groups FAB. typically switches to Equb tab.
  final VoidCallback? onJoinGroups;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EkubHomeBloc, EkubHomeState>(
      builder: (context, state) {
        // Only ever seen on the very first launch: every later one paints
        // the saved home screen at once (EkubHomeBloc reads AppCache before
        // it asks the network), so this is the shape of the page, not a
        // spinner in the middle of a blank one.
        if (state is EkubHomeLoading) return const _HomeSkeleton();

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

        // How long each banner stays up: the admin panel's "Slide duration",
        // delivered with the banners (and kept with them in AppCache).
        final slideSeconds = switch (state) {
          EkubHomeSuccess s =>
            s.promotions?.slideSeconds ?? HomePromotions.defaultSlideSeconds,
          _ => HomePromotions.defaultSlideSeconds,
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
                // The maroon header, as on every screen (AppBarTheme).
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
                        textColor: Colors.white,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      CustomText(
                        title: '${'welcome_back_short'.tr}, $firstName',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        textColor: Colors.white.withValues(alpha: 0.8),
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
                      child: _BannerCarousel(
                        banners: banners,
                        slideDuration: Duration(seconds: slideSeconds),
                      ),
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
              backgroundColor: appColors.buttonColor,
              foregroundColor: appColors.buttonTextColor,
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

  /// How long each banner stays on screen before the carousel slides on: the
  /// "Slide duration" set in the admin panel (Banners > Slide duration). It
  /// arrives with the banners, so a change there is picked up the next time
  /// the home screen loads.
  final Duration slideDuration;

  const _BannerCarousel({required this.banners, required this.slideDuration});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  /// True while a finger is dragging the carousel, so the banner being looked
  /// at is not pulled away mid-swipe.
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startTimer();
  }

  /// Counts one whole slide duration from now, then moves to the next banner.
  ///
  /// A single timer, not a periodic one, and it is started again each time a
  /// page comes to rest (see [_onScroll]). That is what makes "each banner
  /// stays for N seconds" true: a banner the member swiped to by hand gets its
  /// full N seconds too, instead of being taken away by a tick that was
  /// already part-way through its count — which, with a long duration, would
  /// otherwise happen right after the swipe.
  void _startTimer() {
    _timer?.cancel();
    // One banner has nowhere to slide to. (mounted: this can also be reached
    // from the end of an animation that finished after the screen was left.)
    if (!mounted || widget.banners.length < 2) return;
    _timer = Timer(widget.slideDuration, _slideToNext);
  }

  void _slideToNext() {
    if (!mounted) return;

    // Not attached to a PageView yet, or the member is mid-swipe: do not
    // fight them for the page, count another full duration instead.
    if (_dragging || !_pageController.hasClients) {
      _startTimer();
      return;
    }

    final next = _currentPage < widget.banners.length - 1 ? _currentPage + 1 : 0;
    _pageController
        .animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        )
        // The scroll listener restarts the count when the page lands; this
        // covers the cases where no scroll happens (target already shown).
        .whenComplete(_startTimer);
  }

  /// Holds the countdown while a finger is on the carousel and restarts it,
  /// from zero, once the page has come to rest — after a swipe or after the
  /// automatic slide.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    final byFinger =
        (notification is ScrollStartNotification &&
            notification.dragDetails != null) ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null);

    if (byFinger) {
      _dragging = true;
      _timer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
      _startTimer();
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheBanners();
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.banners, widget.banners)) _precacheBanners();

    // A new duration from the server, or banners added or removed: count
    // again from now so the setting applies straight away. Left alone
    // otherwise, so an ordinary reload does not keep resetting the clock.
    final changed =
        oldWidget.slideDuration != widget.slideDuration ||
        oldWidget.banners.length != widget.banners.length;
    if (changed && !_dragging) _startTimer();
  }

  /// Every banner's picture is fetched — or read off the disk — as soon as
  /// the list is known, rather than when its card first slides into view, so
  /// the carousel never turns to an empty card mid-scroll. Cheap to repeat: a
  /// picture already in memory resolves at once.
  void _precacheBanners() {
    for (final banner in widget.banners) {
      final url = banner.imageUrl;
      if (url != null && url.isNotEmpty) {
        unawaited(BannerImage.precache(context, url));
      }
    }
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
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
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
                          // Kept on the phone between launches; see BannerImage
                          // for why Image.network showed grey cards every time.
                          BannerImage(
                            url: banner.imageUrl!,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(20.r),
                            placeholderColor:
                                appColors.accentColor ?? const Color(0xFFE9E4D8),
                            errorBuilder: (_) => Container(
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
          // The Niya mark on a tile of its own: white with the black shield
          // by day, and at night a dark tile with the white-shield logo, so
          // the card does not carry a white square on a black page.
          Container(
            height: 52.r,
            width: 52.r,
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              color: isDark ? niya(context).raised : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: niya(context).accent.withValues(alpha: 0.3),
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

/// The home screen's shape while its first load is in flight — greeting,
/// banner, the facts row and two Equb cards — as soft pulsing blocks.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      // The same maroon bar the loaded screen opens with, so nothing jumps
      // when the content arrives.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: math.max(64.h, 64),
        title: CustomText(
          title: 'app_name'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          textColor: Colors.white,
          maxLines: 1,
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
          children: [
            Skeleton(height: 160.h, radius: 20.r),
            SizedBox(height: 16.h),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: 10.w),
                  Expanded(child: Skeleton(height: 68.h, radius: 14.r)),
                ],
              ],
            ),
            SizedBox(height: 22.h),
            Skeleton(width: 140.w, height: 16.h),
            SizedBox(height: 12.h),
            SkeletonCard(lines: 3, height: 112.h),
            SizedBox(height: 12.h),
            SkeletonCard(lines: 3, height: 112.h),
          ],
        ),
      ),
    );
  }
}
