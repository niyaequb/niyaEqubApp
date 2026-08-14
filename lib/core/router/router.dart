import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:niya_equb/features/agent/main/presentation/screens/agent_main_screen.dart';
import 'package:niya_equb/features/agent/members/presentation/screens/agent_members_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/login_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/otp_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/phone_number_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/azkar_categories_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/qibla_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/quran_reader_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/quran_surah_list_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/tasbih_screen.dart';
import 'package:niya_equb/features/member/islamic/presentation/screens/umrah_guide_screen.dart';
import 'package:niya_equb/features/member/main/presentation/screens/ekub_main_screen.dart';
import 'package:niya_equb/features/member/notifications/presentation/screens/ekub_notifications_screen.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/my_groups_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/group_detail_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/create_group_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/invite_members_screen.dart';

class AppRouter {
  static String currentRoute = "/";

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final name = settings.name ?? "/";
    currentRoute = name;
    
    // Extract base name to support query parameters from GetX
    final String baseName = name.split('?').first;

    switch (baseName) {
      case EqubDetailScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => EqubDetailScreen(
            groupId: args['groupId'],
            initialTab: args['initialTab'],
            drawType: args['drawType'],
            winnerName: args['winnerName'],
            candidates: args['candidates'],
          ),
        );
      case EkubMainScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const EkubMainScreen(),
        );
      case MyGroupsScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const MyGroupsScreen(),
        );
      case CreateGroupScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const CreateGroupScreen(),
        );
      case GroupDetailScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => GroupDetailScreen(groupId: args['groupId']),
        );
      case InviteMembersScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => InviteMembersScreen(
            groupId: args['groupId'],
            inviteCode: args['inviteCode'],
          ),
        );
      case AgentMainScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const AgentMainScreen(),
        );
      case AgentMembersScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const AgentMembersScreen(),
        );
      case EkubNotificationsScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const EkubNotificationsScreen(),
        );

      // --- Ibada Center ---
      // The hub itself lives inside the main screen's PageView, so only the
      // leaf screens are routed. These exist so a notification tap can deep
      // link straight to, say, the Qibla compass.
      case QuranSurahListScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const QuranSurahListScreen(),
        );
      case QuranReaderScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>? ?? const {};
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => QuranReaderScreen(
            surahNumber: (args['surahNumber'] as int?) ?? 1,
            initialAyah: args['initialAyah'] as int?,
          ),
        );
      case QiblaScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const QiblaScreen(),
        );
      case AzkarCategoriesScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const AzkarCategoriesScreen(),
        );
      case TasbihScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const TasbihScreen(),
        );
      case UmrahGuideScreen.routeName:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => const UmrahGuideScreen(),
        );
      case ForgotPasswordScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) =>
              ForgotPasswordScreen(phoneNumber: args['phoneNumber'] ?? ""),
        );
      case LoginScreen.routeName:
        return CupertinoPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case PhoneNumberScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        final fromValue = args != null ? args['from'] : 'register';

        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => PhoneNumberScreen(from: fromValue),
        );

      case OtpScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => OtpScreen(
            phoneNumber: args['phoneNumber'],
            from: args['from'],
            verificationId: args['verificationId'],
          ),
        );

      case CompleteProfileScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>;
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) =>
              CompleteProfileScreen(phoneNumber: args['phoneNumber']),
        );

      default:
        return CupertinoPageRoute(
          settings: RouteSettings(name: settings.name),
          builder: (_) => Scaffold(
            appBar: AppBar(title: CustomText(title: settings.name ?? "")),
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
