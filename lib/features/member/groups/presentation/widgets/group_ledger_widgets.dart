import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:get/get.dart';

final _money = NumberFormat('#,##0', 'en_US');
final _date = DateFormat('d MMM');

String etb(double v) => '${_money.format(v)} ETB';

/// The same amount, shortened for the places where a column is only a third
/// of the screen wide.
///
/// A year-long daily circle runs to seven figures, and "1,234,567 ETB" in a
/// stat column used to clip mid-number — which reads as a wrong figure rather
/// than a cut-off one. Anything under six digits is left exact, because that
/// is the range where the last two digits still matter to a member checking
/// what they owe.
String etbCompact(double v) {
  final abs = v.abs();

  if (abs >= 1000000) {
    final millions = v / 1000000;
    return '${millions.toStringAsFixed(abs >= 10000000 ? 0 : 1)}M ETB';
  }
  if (abs >= 100000) {
    return '${(v / 1000).toStringAsFixed(0)}K ETB';
  }
  return etb(v);
}

/// The colour used everywhere for "My Responsibility People" — the places a
/// member holds in a circle for someone with no Niya account.
///
/// Lives here rather than in responsibility_widgets.dart because the members
/// ledger below needs it too, and that file must not import upwards.
const Color kResponsibilityTint = Color(0xFF7C3AED);

/// The same colour for a dark surface. Violet-600 is the right weight on
/// white and goes to mud on navy, so the night screens get violet-400.
const Color kResponsibilityTintNight = Color(0xFFA78BFA);

/// Whichever of the two the surface underneath calls for.
Color responsibilityTint(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? kResponsibilityTintNight
    : kResponsibilityTint;

/// Colour + label for a member's contribution standing.
class PaymentStatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const PaymentStatusStyle(this.label, this.color, this.icon);

  static PaymentStatusStyle of(String status) {
    switch (status) {
      case 'overdue':
        return const PaymentStatusStyle('Overdue', Color(0xFFDC2626), Icons.error_outline_rounded);
      case 'behind':
        return const PaymentStatusStyle('Behind', Color(0xFFD97706), Icons.schedule_rounded);
      case 'completed':
        return const PaymentStatusStyle('Complete', Color(0xFF0EA5E9), Icons.verified_rounded);
      case 'cancelled':
        return const PaymentStatusStyle('Left', Color(0xFF64748B), Icons.remove_circle_outline_rounded);
      default:
        return const PaymentStatusStyle('Paid up', Color(0xFF16A34A), Icons.check_circle_rounded);
    }
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.r, color: color),
            SizedBox(width: 4.w),
          ],
          CustomText(
            title: label,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            textColor: color,
          ),
        ],
      ),
    );
  }
}

/// The headline card: what the circle has collected against what is due, and
/// underneath it what the circle is worth in total.
///
/// The two are deliberately kept apart. Everything above the divider is a
/// "today" figure and moves every round; the total below it is fixed for the
/// life of the circle. Showing them in one run of numbers is what made the
/// due-so-far amount get read as the total.
class LedgerSummaryCard extends StatelessWidget {
  final LedgerTotals totals;
  final VoidCallback? onRemindTap;

  const LedgerSummaryCard({super.key, required this.totals, this.onRemindTap});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = (totals.collectionRate * 100).round();

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.25 : 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            title: 'Collected this cycle'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            textColor: Colors.white.withValues(alpha: 0.85),
          ),
          SizedBox(height: 6.h),
          // Scales down rather than clipping: on a long circle this figure
          // eventually reaches seven digits.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CustomText(
              title: etb(totals.totalPaid),
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              textColor: Colors.white,
            ),
          ),
          SizedBox(height: 2.h),
          CustomText(
            title: "${'of'.tr} ${etb(totals.dueToDate)} ${'due so far'.tr}",
            fontSize: 11.sp,
            fontWeight: FontWeight.w400,
            textColor: Colors.white.withValues(alpha: 0.8),
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: totals.collectionRate.clamp(0, 1).toDouble(),
              minHeight: 7.h,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _stat('$rate%', 'collected'.tr),
              _divider(),
              _stat('${totals.membersPaidUp}/${totals.membersCount}', 'paid up'.tr),
              _divider(),
              _stat(etbCompact(totals.totalUnpaid), 'outstanding'.tr),
            ],
          ),
          SizedBox(height: 14.h),
          _totalValuePanel(context),
          if (totals.membersBehind > 0 && onRemindTap != null) ...[
            SizedBox(height: 12.h),
            InkWell(
              onTap: onRemindTap,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 15.r, color: Colors.white),
                    SizedBox(width: 6.w),
                    CustomText(
                      title: '${'Remind'.tr} ${totals.membersBehind} ${'member(s) who owe'.tr}',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// What the circle is worth end to end: members x rounds x contribution.
  ///
  /// Sits in its own panel with the arithmetic spelled out underneath, so the
  /// figure can be checked at a glance instead of taken on trust — a member
  /// who can see "2 members × 365 rounds × 630 ETB" does not have to wonder
  /// which of the numbers on this card the total came from.
  Widget _totalValuePanel(BuildContext context) {
    final breakdown = 'total_value_formula'.trParams({
      'members': '${totals.membersCount}',
      'rounds': '${totals.roundsTotal}',
      'amount': etb(totals.contributionAmount),
    });

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 16.r, color: Colors.white),
          SizedBox(width: 9.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  title: 'total_equb_value'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  textColor: Colors.white,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                if (totals.hasTermFigures) ...[
                  SizedBox(height: 3.h),
                  CustomText(
                    title: breakdown,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w400,
                    textColor: Colors.white.withValues(alpha: 0.78),
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: CustomText(
                title: etb(totals.totalValue),
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                textColor: Colors.white,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            title: value,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            textColor: Colors.white,
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          CustomText(
            title: label,
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            textColor: Colors.white.withValues(alpha: 0.75),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 26.h,
        margin: EdgeInsets.symmetric(horizontal: 10.w),
        color: Colors.white.withValues(alpha: 0.25),
      );
}

/// One member's contribution standing.
class MemberLedgerTile extends StatelessWidget {
  final LedgerMember member;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onRemove;

  const MemberLedgerTile({
    super.key,
    required this.member,
    this.selectable = false,
    this.selected = false,
    this.onSelectedChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final style = PaymentStatusStyle.of(member.paymentStatus);
    final border = appColors.borderColor ?? AppStaticColor.borderLight;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: selected ? style.color.withValues(alpha: 0.6) : border.withValues(alpha: 0.5),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (selectable)
                Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  onChanged: member.isEligibleForDraw
                      ? (v) => onSelectedChanged?.call(v ?? false)
                      : null,
                ),
              _avatar(context, style),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: CustomText(
                            title: member.name,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            textColor: appColors.titleTextColor,
                            maxLines: 1,
                            textOverflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.isOwner) ...[
                          SizedBox(width: 6.w),
                          CustomText(
                            title: '· creator'.tr,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w400,
                            textColor: appColors.hintTextColor,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.h),
                    CustomText(
                      title: '${member.roundsPaid}/${member.roundsTotal} ${'rounds'.tr} · ${etb(member.totalPaid)} ${'paid'.tr}',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w400,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                    // A place held for someone with no Niya account. It counts
                    // and pays like any other member, so it belongs in this
                    // list — but who owes the money has to be visible, or the
                    // circle reads it as a member who is quietly in arrears.
                    if (member.isResponsibilitySeat) ...[
                      SizedBox(height: 5.h),
                      Row(
                        children: [
                          Icon(Icons.volunteer_activism_outlined,
                              size: 11.r, color: responsibilityTint(context)),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: CustomText(
                              title: (member.sponsorName ?? '').isEmpty
                                  ? 'responsibility_person'.tr
                                  : '${'paid_by'.tr} ${member.sponsorName}',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              textColor: responsibilityTint(context),
                              maxLines: 1,
                              textOverflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(label: style.label, color: style.color, icon: style.icon),
                  if (member.outstandingNow > 0) ...[
                    SizedBox(height: 4.h),
                    CustomText(
                      title: '${etb(member.outstandingNow)} due',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      textColor: style.color,
                    ),
                  ] else if (member.hasWon && member.winDate != null) ...[
                    SizedBox(height: 4.h),
                    CustomText(
                      title: 'Won ${_date.format(member.winDate!)}',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      textColor: appColors.hintTextColor,
                    ),
                  ],
                ],
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 16.r, color: appColors.hintTextColor),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: member.progress.clamp(0, 1).toDouble(),
              minHeight: 5.h,
              backgroundColor: border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(style.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, PaymentStatusStyle style) {
    final initials = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      width: 38.r,
      height: 38.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: style.color.withValues(alpha: 0.14),
        image: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(member.avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
          ? CustomText(
              title: initials,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              textColor: style.color,
            )
          : null,
    );
  }
}

/// Shows the winner-group plan as a row of chips: "3 + 4".
class SplitPlanStrip extends StatelessWidget {
  final List<int> plan;
  final int cursor;
  final VoidCallback? onReroll;

  const SplitPlanStrip({super.key, required this.plan, this.cursor = 0, this.onReroll});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    if (plan.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_outlined, size: 15.r, color: primary),
              SizedBox(width: 6.w),
              Expanded(
                child: CustomText(
                  title: 'Winners each round',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.titleTextColor,
                ),
              ),
              if (onReroll != null)
                InkWell(
                  onTap: onReroll,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                    child: Row(
                      children: [
                        Icon(Icons.casino_outlined, size: 13.r, color: primary),
                        SizedBox(width: 4.w),
                        CustomText(
                          title: 'Shuffle',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          textColor: primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: List.generate(plan.length, (i) {
              final isDone = i < cursor;
              final isNext = i == cursor;
              final color = isDone
                  ? (appColors.hintTextColor ?? AppStaticColor.textSubLight)
                  : primary;

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isNext ? color.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: color.withValues(alpha: isNext ? 0.5 : 0.28),
                    width: isNext ? 1.3 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDone) ...[
                      Icon(Icons.check_rounded, size: 12.r, color: color),
                      SizedBox(width: 4.w),
                    ],
                    CustomText(
                      title: 'Round ${i + 1}: ${plan[i]}',
                      fontSize: 11.sp,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                      textColor: color,
                    ),
                  ],
                ),
              );
            }),
          ),
          SizedBox(height: 10.h),
          CustomText(
            title: '${plan.reduce((a, b) => a + b)} members over ${plan.length} rounds '
                '(${plan.join(' + ')})',
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.bodyTextSmallColor,
          ),
        ],
      ),
    );
  }
}

/// A completed round with its whole winning group.
class DrawRoundCard extends StatelessWidget {
  final GroupDraw draw;

  const DrawRoundCard({super.key, required this.draw});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: CustomText(
                  title: 'Round ${draw.roundNumber}',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  textColor: primary,
                ),
              ),
              SizedBox(width: 8.w),
              CustomText(
                title: '${draw.winnersCount} winner${draw.winnersCount == 1 ? '' : 's'}',
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                textColor: appColors.bodyTextSmallColor,
              ),
              const Spacer(),
              if (draw.drawDate != null)
                CustomText(
                  title: _date.format(draw.drawDate!),
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w400,
                  textColor: appColors.hintTextColor,
                ),
            ],
          ),
          SizedBox(height: 12.h),
          ...draw.winners.map((w) => Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Row(
                  children: [
                    Icon(
                      w.isMe ? Icons.star_rounded : Icons.emoji_events_outlined,
                      size: 15.r,
                      color: w.isMe ? primary : appColors.bodyTextSmallColor,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: CustomText(
                        title: w.isMe ? '${w.name} (you)' : w.name,
                        fontSize: 12.sp,
                        fontWeight: w.isMe ? FontWeight.w700 : FontWeight.w500,
                        textColor: w.isMe ? primary : appColors.titleTextColor,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CustomText(
                      title: etb(w.amountWon),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      textColor: appColors.titleTextColor,
                    ),
                  ],
                ),
              )),
          if (draw.mode == 'manual') ...[
            SizedBox(height: 4.h),
            CustomText(
              title: 'Chosen by the group creator',
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
              textColor: appColors.hintTextColor,
            ),
          ],
        ],
      ),
    );
  }
}


/// Shared empty state: says what is missing and what to do about it.
class GroupEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const GroupEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30.r, color: primary),
          ),
          SizedBox(height: 16.h),
          CustomText(
            title: title,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            centerText: true,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 6.h),
          CustomText(
            title: body,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            centerText: true,
            textColor: appColors.bodyTextSmallColor,
          ),
          if (action != null) ...[SizedBox(height: 18.h), action!],
        ],
      ),
    );
  }
}
