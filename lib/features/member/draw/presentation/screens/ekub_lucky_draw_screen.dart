import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/draw/data/repository/ekub_draw_repository.dart';
import 'package:niya_equb/features/member/draw/state/ekub_draw_bloc.dart';
import 'package:niya_equb/features/member/draw/state/ekub_draw_event.dart';
import 'package:niya_equb/features/member/draw/state/ekub_draw_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

class EkubLuckyDrawScreen extends StatelessWidget {
  const EkubLuckyDrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<EkubDrawBloc, EkubDrawState>(
      builder: (context, state) {
        if (state is EkubDrawLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is EkubDrawFailure && state.categories.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('lucky_draw_title'.tr)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48.r, color: Colors.red),
                  SizedBox(height: 16.h),
                  Text(state.failure.errorMessage),
                  TextButton(
                    onPressed: () =>
                        context.read<EkubDrawBloc>().add(EkubDrawLoadEvent()),
                    child: Text('retry'.tr),
                  ),
                ],
              ),
            ),
          );
        }

        final categories = switch (state) {
          EkubDrawSuccess s => s.categories,
          EkubDrawFailure s => s.categories,
          _ => const <EkubDrawCategory>[],
        };
        final winners = switch (state) {
          EkubDrawSuccess s => s.winners,
          EkubDrawFailure s => s.winners,
          _ => const <EkubWinner>[],
        };

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                title: Text('lucky_draw_title'.tr),
                actions: [SizedBox(width: 6.w)],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: appColors.accentColor,
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: appColors.borderColor!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 44.r,
                          width: 44.r,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            color: appColors.primaryColor!.withValues(
                              alpha: isDark ? 0.18 : 0.12,
                            ),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: appColors.primaryColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText(
                                title: 'fair_transparent_draws'.tr,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                textColor: appColors.titleTextColor,
                              ),
                              SizedBox(height: 4.h),
                              CustomText(
                                title: 'draw_instruction'.tr,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                textColor: appColors.bodyTextSmallColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
                  child: CustomText(
                    title: 'categories'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) =>
                      _CategoryTile(category: categories[index]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
                  child: CustomText(
                    title: 'winner_history'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                sliver: SliverList.separated(
                  itemCount: winners.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) =>
                      _WinnerTile(winner: winners[index]),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final EkubDrawCategory category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          Container(
            height: 42.r,
            width: 42.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: appColors.primaryColor!.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
            child: Icon(category.icon, color: appColors.primaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: category.name,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  title: category.nextDrawLabel,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: appColors.bodyTextSmallColor),
        ],
      ),
    );
  }
}

class _WinnerTile extends StatelessWidget {
  final EkubWinner winner;

  const _WinnerTile({required this.winner});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          Container(
            height: 42.r,
            width: 42.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: Colors.green.withValues(alpha: isDark ? 0.16 : 0.10),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.green),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: winner.name,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  title:
                      '${winner.category} • ${DateFormat('MMM d, y').format(winner.time)}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: appColors.bodyTextSmallColor),
        ],
      ),
    );
  }
}
