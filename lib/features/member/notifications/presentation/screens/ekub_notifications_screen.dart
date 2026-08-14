import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_bloc.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

class EkubNotificationsScreen extends StatelessWidget {
  static const String routeName = '/ekub-notifications';

  const EkubNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<EkubNotificationsBloc, EkubNotificationsState>(
      builder: (context, state) {
        final items = switch (state) {
          EkubNotificationsSuccess s => s.items,
          EkubNotificationsFailure s => s.items,
          _ => const [],
        };

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          appBar: AppBar(title: Text('notifications_title'.tr)),
          body: ListView.separated(
            padding: EdgeInsets.all(16.r),
            itemCount: items.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final it = items[index];
              return Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: appColors.accentColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: appColors.borderColor!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42.r,
                      width: 42.r,
                      decoration: BoxDecoration(
                        color: appColors.primaryColor!.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(it.icon, color: appColors.primaryColor),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: CustomText(
                                  title: it.title,
                                  fontSize: 14.sp,
                                  textColor: appColors.titleTextColor,
                                  fontWeight: FontWeight.w700,
                                  maxLines: 1,
                                  textOverflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              CustomText(
                                title: it.timeLabel,
                                fontSize: 11.sp,
                                textColor: appColors.bodyTextSmallColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          CustomText(
                            title: it.subtitle,
                            fontSize: 12.sp,
                            textColor: appColors.bodyTextSmallColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
