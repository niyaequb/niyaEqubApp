import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/util/app_update_gate.dart';
import 'package:niya_equb/features/agent/dashboard/presentation/screens/agent_dashboard_screen.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_bloc.dart';
import 'package:niya_equb/features/agent/dashboard/state/agent_dashboard_event.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_bloc.dart';
import 'package:niya_equb/features/agent/payout/state/agent_payout_event.dart';
import 'package:niya_equb/features/agent/payout/presentation/screens/agent_payout_screen.dart';
import 'package:niya_equb/features/agent/profile/presentation/screens/agent_profile_screen.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_bloc.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_event.dart';
import 'package:niya_equb/features/member/settings/state/settings_bloc.dart';
import 'package:niya_equb/features/member/settings/state/settings_event.dart';

class AgentMainScreen extends StatefulWidget {
  static const String routeName = '/agent-main';

  const AgentMainScreen({super.key});

  @override
  State<AgentMainScreen> createState() => _AgentMainScreenState();
}

/// Agents get the same update prompt as members. They are the people least
/// able to work around a broken build — collecting on someone else's behalf —
/// so leaving them on an old version was never deliberate, only forgotten.
class _AgentMainScreenState extends State<AgentMainScreen> with AppUpdateGate {
  int _index = 0;
  late final PageController _controller;
  final ValueNotifier<bool> _openProfileEditSheet = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
    startAppUpdateWatch();
  }

  @override
  void dispose() {
    stopAppUpdateWatch();
    _openProfileEditSheet.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int next) {
    if (next == _index) return;
    setState(() => _index = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<AgentDashboardBloc>()..add(AgentDashboardLoadEvent()),
        ),
        BlocProvider(
          create: (_) => sl<EkubProfileBloc>()..add(EkubProfileLoadEvent()),
        ),
        BlocProvider(
          create: (_) => sl<AgentPayoutBloc>()..add(AgentPayoutLoadEvent()),
        ),
        BlocProvider(
          create: (_) => sl<SettingsBloc>()..add(SettingsLoadEvent()),
        ),
      ],
      child: Scaffold(
        backgroundColor: appColors.scaffoldBackgroundColor,
        body: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _index = i),
          children: [
            AgentDashboardScreen(onNavigateToPayout: () => _onTap(1)),
            AgentPayoutScreen(
              onNavigateToProfile: () {
                _onTap(2);
                Future.delayed(const Duration(milliseconds: 450), () {
                  if (mounted) _openProfileEditSheet.value = true;
                });
              },
            ),
            AgentProfileScreen(openEditSheetNotifier: _openProfileEditSheet),
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
            onDestinationSelected: _onTap,
            indicatorColor: appColors.primaryColor!.withValues(
              alpha: isDark ? 0.18 : 0.14,
            ),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_rounded),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: 'nav_dashboard'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.payments_rounded),
                selectedIcon: const Icon(Icons.payments_rounded),
                label: 'nav_payout'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_rounded),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: 'nav_profile'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
