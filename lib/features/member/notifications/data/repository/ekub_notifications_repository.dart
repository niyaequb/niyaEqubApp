import 'package:flutter/material.dart';

class EkubNotificationsRepository {
  List<EkubNotificationItem> getNotifications() {
    return const [
      EkubNotificationItem(
        icon: Icons.notifications_active_rounded,
        title: 'Payment reminder',
        subtitle: 'Your daily contribution is due today.',
        timeLabel: 'Just now',
      ),
      EkubNotificationItem(
        icon: Icons.emoji_events_rounded,
        title: 'Lucky draw update',
        subtitle: 'Winners announced for the 100 Birr/day package.',
        timeLabel: '2h ago',
      ),
      EkubNotificationItem(
        icon: Icons.info_rounded,
        title: 'Policy update',
        subtitle: 'Terms & Conditions were updated by admin.',
        timeLabel: 'Yesterday',
      ),
    ];
  }
}

class EkubNotificationItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String timeLabel;

  const EkubNotificationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
  });
}

