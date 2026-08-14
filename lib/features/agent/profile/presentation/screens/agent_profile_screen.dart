import 'package:flutter/material.dart';
import 'package:niya_equb/features/member/profile/presentation/screens/ekub_profile_screen.dart';

/// Agent profile screen reuses the member profile UI.
class AgentProfileScreen extends StatelessWidget {
  const AgentProfileScreen({super.key, this.openEditSheetNotifier});

  final ValueNotifier<bool>? openEditSheetNotifier;

  @override
  Widget build(BuildContext context) {
    return EkubProfileScreen(
      openEditSheetNotifier: openEditSheetNotifier,
    );
  }
}
