import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// The picture on a package's badge, chosen from the package's name.
///
/// Packages are named by an admin in free text, in any of the app's three
/// languages, so this looks for the words they are known by and falls back to
/// the Niya mark for anything else.
Widget packageGlyph(
  String? name, {
  required double size,
  Color color = NiyaPalette.maroon,
}) {
  final n = (name ?? '').toLowerCase();

  // Latin keywords are matched against whole words, so "Ibrahim" is not
  // "rah" and "Suleiman" is not "iman"; a long one may start a word
  // ("Ramadan2026"). Ethiopic ones are looked for anywhere, because Amharic
  // joins words onto them ("የሀጅ", of Hajj).
  final words = n.split(RegExp(r'[^a-z\u1200-\u137F]+'));
  bool latin(String k) => RegExp(r'^[a-z]+$').hasMatch(k);
  bool has(List<String> keys) => keys.any(
    (k) => latin(k)
        ? words.any((w) => w == k || (k.length > 4 && w.startsWith(k)))
        : n.contains(k),
  );

  if (has(['hajj', 'ሀጅ', 'ሐጅ', 'ሃጅ', 'umrah', 'umra', 'ዑምራ', 'ኡምራ', 'እምራ'])) {
    return KaabaGlyph(size: size * 1.05);
  }

  final IconData? icon = switch (n) {
    _ when has(['sabr', 'sabir', 'ሰብር', 'ሶብር']) =>
      Icons.volunteer_activism_rounded,
    _ when has(['nur', 'noor', 'ኑር']) => Icons.mosque_rounded,
    _ when has(['iman', 'eman', 'ኢማን', 'እማን']) => Icons.menu_book_rounded,
    _ when has(['ramadan', 'ramadhan', 'ረመዳን', 'ረማዳን', 'ረመዷን']) =>
      Icons.nightlight_round,
    _ when has(['family', 'jama', 'maatii', 'ቤተሰብ', 'ጀምአ', 'ጀመዓ', 'ጀማ']) =>
      Icons.family_restroom_rounded,
    _ when has(['rah', 'ረሀ', 'ራህ', 'ረህ', 'ረሕ']) => Icons.spa_rounded,
    _ => null,
  };

  if (icon != null) return Icon(icon, size: size, color: color);
  return NiyaLogo(size: size * 1.15);
}

/// A length of time from the server ("24 months", "96 weeks", "730 days"),
/// in the app's language: "24 months", "24 ወር", "Ji'a 24".
String? durationText(String? raw) {
  final match = RegExp(r'(\d+)\s*([A-Za-z]+)').firstMatch(raw ?? '');
  if (match == null) return null;

  final n = int.tryParse(match.group(1)!) ?? 0;
  if (n <= 0) return null;

  final unit = match.group(2)!.toLowerCase();
  final String? key;
  if (unit.startsWith('month')) {
    key = 'month';
  } else if (unit.startsWith('week')) {
    key = 'week';
  } else if (unit.startsWith('year')) {
    key = 'year';
  } else if (unit.startsWith('day')) {
    key = 'day';
  } else {
    key = null;
  }

  if (key == null) return '$n $unit';
  return (n == 1 ? 'pkg_dur_$key' : 'pkg_dur_${key}s').trParams({'n': '$n'});
}

/// How long a package runs, for its row in the list.
///
/// The plans inside a package each give the length in their own unit — 24
/// months, 96 weeks, 730 days are the same Equb — so the monthly wording is
/// preferred, then any plan's, then the package's own day count.
String? packageDurationText(EqubPackage package) {
  final groups = package.groups ?? const <EqubGroup>[];

  for (final g in groups) {
    if ((g.duration ?? '').toLowerCase().contains('month')) {
      final text = durationText(g.duration);
      if (text != null) return text;
    }
  }
  for (final g in groups) {
    final text = durationText(g.duration);
    if (text != null) return text;
  }

  final days = int.tryParse(package.durationDays ?? '');
  if (days == null || days <= 0) return null;
  if (days >= 28) return durationText('${(days / 30).round()} months');
  return durationText('$days days');
}

/// The translation key of a usual cycle: 'daily', 'weekly' or 'monthly'.
String? frequencyKey(String? days) => switch (days?.trim()) {
  '1' => 'daily',
  '7' => 'weekly',
  '30' || '31' => 'monthly',
  _ => null,
};

/// A plan's cycle in words: "Weekly", or "Every 14 days".
String? frequencyText(String? days) {
  final key = frequencyKey(days);
  if (key != null) return key.tr;

  final n = int.tryParse(days?.trim() ?? '');
  if (n == null || n <= 0) return null;
  return 'pkg_every_n_days'.trParams({'n': '$n'});
}

/// The label over a plan's amount: "Weekly payment".
String paymentLabel(String? days) {
  final key = frequencyKey(days);
  return key == null ? 'pkg_pay_each'.tr : 'pkg_pay_$key'.tr;
}

/// The cycles a package offers, shortest first: Daily, Weekly, Monthly.
List<String> packageCycles(EqubPackage package) {
  final groups = [...?package.groups]
    ..sort(
      (a, b) => (int.tryParse(a.contributionFrequencyDays ?? '') ?? 9999)
          .compareTo(int.tryParse(b.contributionFrequencyDays ?? '') ?? 9999),
    );

  final cycles = <String>[];
  for (final g in groups) {
    final text = frequencyText(g.contributionFrequencyDays);
    if (text != null && !cycles.contains(text)) cycles.add(text);
  }
  return cycles;
}

/// A group's status as a member would say it: "Open to join", "Running".
String? statusText(String? status) {
  final s = status?.trim().toLowerCase();
  if (s == null || s.isEmpty) return null;

  final key = 'pkg_status_$s';
  final translated = key.tr;
  if (translated != key) return translated;

  return s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// What one contribution to [group] costs, from the group or its package.
double? planAmount(EqubGroup group) {
  return double.tryParse(group.fixedContributionAmount ?? '') ??
      double.tryParse(group.package?.fixedContributionAmount ?? '');
}

/// "2,701 ETB".
String moneyText(num amount) => '${NumberFormat('#,##0.##').format(amount)} ETB';

/// "Jun 12, 2026" for a date from the server, or null if it has none.
String? dateText(String? raw) {
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateFormat('MMM d, yyyy').format(parsed);
}
