import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// One Equb plan inside a package, drawn as a ticket.
///
/// The details sit on a sage panel on the left; a maroon stub on the right
/// carries the package name, the cycle and the Join button. The two are
/// joined by a gold perforation with a notch cut out top and bottom, as in
/// the Niya artwork.
class EqubTicketCard extends StatelessWidget {
  final EqubGroup group;
  final String? packageName;
  final bool isJoining;

  /// Starts joining (the caller shows the terms first). Null hides nothing,
  /// but the button does nothing.
  final VoidCallback? onJoin;

  /// Opens the plan the member has already joined.
  final VoidCallback? onOpen;

  const EqubTicketCard({
    super.key,
    required this.group,
    this.packageName,
    this.isJoining = false,
    this.onJoin,
    this.onOpen,
  });

  /// Where the perforation falls, as a share of the card's width.
  static const double _split = 0.64;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notch = 9.r;
    final joined = group.isJoined;

    return GestureDetector(
      onTap: joined ? onOpen : (isJoining ? null : onJoin),
      child: CustomPaint(
        painter: _TicketShadowPainter(
          split: _split,
          notch: notch,
          radius: 18.r,
          shadow: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
        ),
        foregroundPainter: _TicketFramePainter(
          split: _split,
          notch: notch,
          radius: 18.r,
        ),
        child: ClipPath(
          clipper: _TicketClipper(split: _split, notch: notch, radius: 18.r),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: (_split * 100).round(),
                  child: _DetailsPanel(group: group, isDark: isDark),
                ),
                Expanded(
                  flex: ((1 - _split) * 100).round(),
                  child: _Stub(
                    group: group,
                    packageName: packageName,
                    joined: joined,
                    isJoining: isJoining,
                    onJoin: onJoin,
                    onOpen: onOpen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  final EqubGroup group;
  final bool isDark;

  const _DetailsPanel({required this.group, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? Colors.white : NiyaPalette.ink;
    final amount = planAmount(group);
    final status = statusText(group.status);
    final members = _membersText(group);
    final closes = dateText(group.registrationCloseAt);

    return ColoredBox(
      color: isDark ? NiyaPalette.navySoft : NiyaPalette.sage,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicPatternPainter(
                color: (isDark ? NiyaPalette.gold : NiyaPalette.goldDeep)
                    .withValues(alpha: 0.10),
                cell: 34,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 19.sp,
                      color: isDark ? NiyaPalette.goldLight : NiyaPalette.maroon,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        group.name ?? group.packageName ?? 'Equb',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (status != null) ...[
                  SizedBox(height: 6.h),
                  _StatusChip(text: status, isDark: isDark),
                ],
                SizedBox(height: 12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.payments_rounded,
                        label: paymentLabel(group.contributionFrequencyDays),
                        value: amount == null ? '—' : moneyText(amount),
                        emphasize: true,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'pkg_equb_duration'.tr,
                        value: durationText(group.duration) ?? '—',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.event_repeat_rounded,
                        label: 'pkg_payment_cycle'.tr,
                        value:
                            frequencyText(group.contributionFrequencyDays) ?? '—',
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.calendar_month_rounded,
                        label: 'pkg_start_date'.tr,
                        value: dateText(group.equbStartDate) ?? '—',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                if (members != null || closes != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    height: 1,
                    color: NiyaPalette.gold.withValues(alpha: 0.35),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 12.w,
                    runSpacing: 4.h,
                    children: [
                      if (members != null)
                        _Fact(
                          icon: Icons.people_alt_rounded,
                          text: members,
                          isDark: isDark,
                        ),
                      if (closes != null)
                        _Fact(
                          icon: Icons.lock_clock_rounded,
                          text: 'pkg_closes_on'.trParams({'date': closes}),
                          isDark: isDark,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _membersText(EqubGroup group) {
    final count = group.memberCount;
    final max = int.tryParse(group.maxMembers ?? '');
    if (count == null && max == null) return null;
    if (max != null && max > 0) {
      return 'pkg_members_of'.trParams({'n': '${count ?? 0}', 'max': '$max'});
    }
    return 'pkg_members_count'.trParams({'n': '${count ?? 0}'});
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final bool isDark;

  const _StatusChip({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: NiyaPalette.maroon.withValues(alpha: isDark ? 0.35 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: NiyaPalette.maroon.withValues(alpha: isDark ? 0.6 : 0.25),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? NiyaPalette.goldLight : NiyaPalette.maroon,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  final bool isDark;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? NiyaPalette.goldLight : NiyaPalette.maroon;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26.r,
          height: 26.r,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 15.sp, color: accent),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white60 : NiyaPalette.inkSoft,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: emphasize
                      ? (isDark ? NiyaPalette.goldLight : NiyaPalette.goldDeep)
                      : (isDark ? Colors.white : NiyaPalette.ink),
                  fontSize: emphasize ? 15.sp : 12.sp,
                  fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _Fact({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white70 : NiyaPalette.inkSoft;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: color),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Stub extends StatelessWidget {
  final EqubGroup group;
  final String? packageName;
  final bool joined;
  final bool isJoining;
  final VoidCallback? onJoin;
  final VoidCallback? onOpen;

  const _Stub({
    required this.group,
    required this.packageName,
    required this.joined,
    required this.isJoining,
    required this.onJoin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cycle = frequencyText(group.contributionFrequencyDays);
    final name = packageName ?? group.package?.name;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: NiyaPalette.maroonStub),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicPatternPainter(
                color: NiyaPalette.gold.withValues(alpha: 0.14),
                cell: 30,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 10.w, 12.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (name != null && name.trim().isNotEmpty)
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NiyaPalette.goldLight,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    if (cycle != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        cycle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12.h),
                if (joined)
                  _JoinedPill(onTap: onOpen)
                else
                  NiyaGoldButton(
                    label: 'join'.tr,
                    busy: isJoining,
                    height: 36.h,
                    fontSize: 14.sp,
                    onPressed: onJoin,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinedPill extends StatelessWidget {
  final VoidCallback? onTap;

  const _JoinedPill({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: NiyaPalette.goldLight.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 15.sp, color: NiyaPalette.goldLight),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                'joined'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: NiyaPalette.goldLight,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The outline of the ticket: a rounded rectangle with a semicircle cut out
/// of the top and bottom edges where the stub tears off.
Path _ticketPath(Size size, double split, double notch, double radius) {
  final x = size.width * split;
  final outline = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
  final cuts = Path()
    ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: notch))
    ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: notch));
  return Path.combine(PathOperation.difference, outline, cuts);
}

class _TicketClipper extends CustomClipper<Path> {
  final double split;
  final double notch;
  final double radius;

  const _TicketClipper({
    required this.split,
    required this.notch,
    required this.radius,
  });

  @override
  Path getClip(Size size) => _ticketPath(size, split, notch, radius);

  @override
  bool shouldReclip(_TicketClipper oldClipper) =>
      oldClipper.split != split ||
      oldClipper.notch != notch ||
      oldClipper.radius != radius;
}

class _TicketShadowPainter extends CustomPainter {
  final double split;
  final double notch;
  final double radius;
  final Color shadow;

  const _TicketShadowPainter({
    required this.split,
    required this.notch,
    required this.radius,
    required this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(_ticketPath(size, split, notch, radius), shadow, 6, false);
  }

  @override
  bool shouldRepaint(_TicketShadowPainter oldDelegate) =>
      oldDelegate.split != split ||
      oldDelegate.notch != notch ||
      oldDelegate.radius != radius ||
      oldDelegate.shadow != shadow;
}

/// The gold edge of the ticket and the dashed perforation, drawn over it.
class _TicketFramePainter extends CustomPainter {
  final double split;
  final double notch;
  final double radius;

  const _TicketFramePainter({
    required this.split,
    required this.notch,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _ticketPath(size, split, notch, radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = NiyaPalette.gold,
    );

    final x = size.width * split;
    final dash = Paint()
      ..color = NiyaPalette.goldLight.withValues(alpha: 0.9)
      ..strokeWidth = 1.4;
    const dashLength = 5.0;
    const gap = 4.0;
    for (var y = notch + 4; y < size.height - notch - 4; y += dashLength + gap) {
      final end = (y + dashLength).clamp(0.0, size.height - notch - 4).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x, end), dash);
    }
  }

  @override
  bool shouldRepaint(_TicketFramePainter oldDelegate) =>
      oldDelegate.split != split ||
      oldDelegate.notch != notch ||
      oldDelegate.radius != radius;
}
