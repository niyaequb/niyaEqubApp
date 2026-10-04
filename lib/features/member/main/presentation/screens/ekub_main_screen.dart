import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/util/app_update_gate.dart';
import 'package:niya_equb/features/member/home/presentation/screens/ekub_home_screen.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/ekub_packages_screen.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_bloc.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_event.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_bloc.dart';
import 'package:niya_equb/features/member/home/state/ekub_home_event.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/islamic_center_screen.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_bloc.dart';
import 'package:niya_equb/features/member/islamic/state/islamic_center_event.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_bloc.dart';
import 'package:niya_equb/features/member/packages/state/ekub_packages_event.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_bloc.dart';
import 'package:niya_equb/features/member/notifications/state/ekub_notifications_event.dart';
import 'package:niya_equb/features/member/profile/presentation/screens/ekub_profile_screen.dart';
import 'package:niya_equb/features/member/settings/state/settings_bloc.dart';
import 'package:niya_equb/features/member/settings/state/settings_event.dart';

class EkubMainScreen extends StatefulWidget {
  static const String routeName = '/ekub-main';

  const EkubMainScreen({super.key});

  @override
  State<EkubMainScreen> createState() => _EkubMainScreenState();
}

/// Offers the store update here rather than on the splash screen for two
/// reasons. The splash is already racing auth, cache warm-up and the
/// notification handshake, and a sheet thrown at a screen that is about to be
/// replaced gets torn down mid-animation. And this is the first screen a
/// member actually stops on, which is where an interruption is least likely to
/// land on top of something they were in the middle of.
class _EkubMainScreenState extends State<EkubMainScreen> with AppUpdateGate {
  int _index = 0;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
    startAppUpdateWatch();
  }

  @override
  void dispose() {
    stopAppUpdateWatch();
    _controller.dispose();
    super.dispose();
  }

  void _onTap(BuildContext statusSourceContext, int next) {
    if (next == _index) return;
    setState(() => _index = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );

    // Trigger background refresh for the newly selected tab
    _triggerSilentRefresh(statusSourceContext, next);
  }

  void _triggerSilentRefresh(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.read<EkubHomeBloc>().add(EkubHomeLoadEvent(isSilent: true));
        break;
      case 1:
        context.read<EkubPackagesBloc>().add(
          EkubPackagesLoadEvent(isSilent: true),
        );
        break;
      case 2:
        context.read<IslamicCenterBloc>().add(
          const IslamicCenterLoadEvent(isSilent: true),
        );
        break;
      case 3:
        context.read<EkubProfileBloc>().add(
          EkubProfileLoadEvent(isSilent: true),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<EkubHomeBloc>()..add(EkubHomeLoadEvent()),
        ),
        BlocProvider(
          create: (_) => sl<EkubPackagesBloc>()..add(EkubPackagesLoadEvent()),
        ),
        BlocProvider(
          create: (_) =>
              sl<EkubNotificationsBloc>()..add(EkubNotificationsLoadEvent()),
        ),
        BlocProvider(
          create: (_) => sl<EkubProfileBloc>()..add(EkubProfileLoadEvent()),
        ),
        // Not lazy: the Ibada tab owns the azan schedule, and we want the
        // rolling alarm window re-armed on app open even if the user never
        // visits the tab.
        BlocProvider(
          lazy: false,
          create: (_) =>
              sl<IslamicCenterBloc>()..add(const IslamicCenterLoadEvent()),
        ),
        BlocProvider(
          lazy: false,
          create: (_) => sl<SettingsBloc>()..add(SettingsLoadEvent()),
        ),
      ],
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: appColors.scaffoldBackgroundColor,
            body: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                EkubHomeScreen(onJoinGroups: () => _onTap(context, 1)),
                const EkubPackagesScreen(),
                const IslamicCenterScreen(),
                const EkubProfileScreen(),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: appColors.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                height: 70.h,
                backgroundColor: appColors.scaffoldBackgroundColor,
                selectedIndex: _index,
                onDestinationSelected: (i) => _onTap(context, i),
                indicatorColor: appColors.primaryColor!.withValues(
                  alpha: isDark ? 0.18 : 0.14,
                ),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_rounded),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: 'nav_home'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.groups_rounded),
                    selectedIcon: const Icon(Icons.groups_rounded),
                    label: 'nav_equb'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.mosque_rounded),
                    selectedIcon: const Icon(Icons.mosque_rounded),
                    label: 'nav_islamic_center'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_rounded),
                    selectedIcon: const Icon(Icons.settings_rounded),
                    label: 'nav_profile'.tr,
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
