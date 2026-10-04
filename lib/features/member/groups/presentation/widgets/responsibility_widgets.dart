import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

/// Shared pieces for "My Responsibility People" — the places a member holds in
/// a group for someone who has no Niya account of their own.
///
/// The wording in here is deliberate and consistent everywhere the feature
/// appears: these people are *counted* like members, and their contributions
/// are *yours to pay*. Both halves have to be visible at the moment someone
/// adds a name, because a name typed in a text field does not look like a
/// financial commitment until it is spelled out as one.

// kResponsibilityTint lives in group_ledger_widgets.dart, which the members
// ledger also needs it from. Imported above rather than redeclared here so the
// two can never drift to different purples.

/// The small purple label attached to a name.
class ResponsibilityBadge extends StatelessWidget {
  /// Who pays for this person. Null renders the short form, used where the
  /// answer is already obvious (a list of only your own people).
  final String? payerName;

  /// True when the signed-in member is the payer, which changes the wording
  /// from a name to "you".
  final bool isMine;

  const ResponsibilityBadge({super.key, this.payerName, this.isMine = false});

  @override
  Widget build(BuildContext context) {
    final label = isMine
        ? 'you_pay'.tr
        : (payerName == null || payerName!.isEmpty
            ? 'responsibility_person'.tr
            : '${'paid_by'.tr} $payerName');

    return StatusPill(
      label: label,
      color: kResponsibilityTint,
      icon: Icons.volunteer_activism_outlined,
    );
  }
}

/// One row in the responsibility list: who they are, how they are doing, and
/// (when allowed) the buttons to correct or remove them.
class ResponsibilityPersonTile extends StatelessWidget {
  final ResponsibilityPerson person;

  /// The per-round amount, shown so the obligation stays in front of the
  /// sponsor rather than only appearing on the payment screen.
  final double contributionAmount;
  final int frequencyDays;

  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const ResponsibilityPersonTile({
    super.key,
    required this.person,
    required this.contributionAmount,
    required this.frequencyDays,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final border = appColors.borderColor ?? AppStaticColor.borderLight;
    final amount = person.contributionAmount > 0 ? person.contributionAmount : contributionAmount;
    final days = person.frequencyDays > 0 ? person.frequencyDays : frequencyDays;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      title: person.name,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      textColor: appColors.titleTextColor,
                      maxLines: 1,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                    CustomText(
                      title: [
                        if ((person.relation ?? '').isNotEmpty) person.relation!,
                        if ((person.phone ?? '').isNotEmpty) person.phone!,
                      ].join(' · '),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w400,
                      textColor: appColors.bodyTextSmallColor,
                      maxLines: 1,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'edit'.tr,
                  icon: Icon(Icons.edit_outlined, size: 16.r, color: appColors.hintTextColor),
                ),
              // Hidden rather than shown-and-failing once they have paid in:
              // the server has already decided, and offering a button that
              // cannot work is worse than not offering one.
              if (onRemove != null && person.canRemove)
                IconButton(
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'remove'.tr,
                  icon: Icon(Icons.close_rounded, size: 16.r, color: appColors.hintTextColor),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              ResponsibilityBadge(
                payerName: person.sponsorName,
                isMine: person.isMine,
              ),
              if (amount > 0)
                StatusPill(
                  label: '${etb(amount)} / $days ${'days'.tr}',
                  color: appColors.bodyTextSmallColor ?? Colors.grey,
                ),
              if (person.roundsPaid != null && person.roundsPaid! > 0)
                StatusPill(
                  label: '${person.roundsPaid} ${'rounds paid'.tr}',
                  color: const Color(0xFF16A34A),
                  icon: Icons.check_circle_rounded,
                ),
              if (person.hasWon)
                StatusPill(
                  label: 'won'.tr,
                  color: const Color(0xFF0EA5E9),
                  icon: Icons.emoji_events_outlined,
                ),
            ],
          ),
          // Says why the remove button is missing, so its absence does not read
          // as a bug.
          if (!person.canRemove && (person.removeBlockReason ?? '').isNotEmpty) ...[
            SizedBox(height: 8.h),
            CustomText(
              title: person.removeBlockReason!,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
              textColor: appColors.hintTextColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar() {
    final initials = person.name.trim().isEmpty
        ? '?'
        : person.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      width: 36.r,
      height: 36.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kResponsibilityTint.withValues(alpha: 0.12),
      ),
      alignment: Alignment.center,
      child: CustomText(
        title: initials,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        textColor: kResponsibilityTint,
      ),
    );
  }
}

/// The explanation panel shown above the list, wherever these people are added.
///
/// Kept as a widget rather than inline copy so the create screen and the group
/// screen cannot drift into describing the same arrangement differently.
class ResponsibilityExplainer extends StatelessWidget {
  /// The per-round amount each of these people adds to the sponsor's bill.
  final double contributionAmount;
  final int frequencyDays;

  /// How many the member is already carrying, out of how many they may.
  final int count;
  final int limit;

  const ResponsibilityExplainer({
    super.key,
    required this.contributionAmount,
    required this.frequencyDays,
    this.count = 0,
    this.limit = 0,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Container(
      padding: EdgeInsets.all(13.r),
      decoration: BoxDecoration(
        color: kResponsibilityTint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: kResponsibilityTint.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15.r, color: kResponsibilityTint),
          SizedBox(width: 9.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: 'responsibility_explainer'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  textColor: appColors.bodyTextColor,
                ),
                if (contributionAmount > 0) ...[
                  SizedBox(height: 6.h),
                  CustomText(
                    title: 'responsibility_cost_note'.trParams({
                      'amount': etb(contributionAmount),
                      'days': '$frequencyDays',
                    }),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    textColor: kResponsibilityTint,
                  ),
                ],
                if (limit > 0) ...[
                  SizedBox(height: 4.h),
                  CustomText(
                    title: '$count ${'of'.tr} $limit ${'places used'.tr}',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                    textColor: appColors.hintTextColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The add / edit form, as a bottom sheet.
///
/// Returns the filled-in draft, or null if the sheet was dismissed. Nothing is
/// saved from in here — the caller decides whether that means a local list (on
/// the create screen, where the group does not exist yet) or an API call.
Future<ResponsibilityPersonDraft?> showResponsibilityPersonSheet(
  BuildContext context, {
  ResponsibilityPersonDraft? initial,

  /// Spelled out on the confirm button so the commitment is visible at the
  /// moment it is taken on, not discovered later on a payment screen.
  double contributionAmount = 0,
  int frequencyDays = 0,
}) {
  return showModalBottomSheet<ResponsibilityPersonDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors(context).scaffoldBackgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
    ),
    builder: (_) => _ResponsibilityPersonForm(
      initial: initial,
      contributionAmount: contributionAmount,
      frequencyDays: frequencyDays,
    ),
  );
}

/// The sheet's contents, as a widget that owns its own text controllers.
///
/// They used to be created next to the showModalBottomSheet call and disposed
/// on the line after the await. That reads as correct and is not: the sheet
/// keeps rebuilding all the way through its closing animation, so the fields
/// went on reading controllers that had already been disposed. That threw
/// "A TextEditingController was used after being disposed", and the failed
/// build took the surrounding element tree with it — which is where the
/// follow-on `_dependents.isEmpty` and ancestor-lookup assertions came from.
///
/// Holding them in a State hands the timing to the framework instead: dispose()
/// runs when this widget is genuinely unmounted, by which point nothing can
/// read them again.
class _ResponsibilityPersonForm extends StatefulWidget {
  final ResponsibilityPersonDraft? initial;
  final double contributionAmount;
  final int frequencyDays;

  const _ResponsibilityPersonForm({
    this.initial,
    this.contributionAmount = 0,
    this.frequencyDays = 0,
  });

  @override
  State<_ResponsibilityPersonForm> createState() =>
      _ResponsibilityPersonFormState();
}

class _ResponsibilityPersonFormState extends State<_ResponsibilityPersonForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _relation;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _phone = TextEditingController(text: widget.initial?.phone ?? '');
    _relation = TextEditingController(text: widget.initial?.relation ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Drop the keyboard before popping. Otherwise the sheet is still being
    // resized by the shrinking inset while its route is already unwinding,
    // and the layout lands on a widget that is halfway out of the tree.
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop(
      ResponsibilityPersonDraft(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        relation: _relation.text.trim(),
        // Carried through untouched. The sheet has no field for it, so
        // rebuilding the draft without it would silently wipe a note that is
        // already saved against this person.
        note: widget.initial?.note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 18.h,
        // viewInsetsOf rather than MediaQuery.of: this only needs to rebuild
        // when the keyboard moves, not on every other metric change.
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18.h,
      ),
      child: Form(
        key: _formKey,
        // The three fields plus the keyboard can outgrow a short screen, and a
        // Column alone would overflow rather than scroll.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: kResponsibilityTint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.volunteer_activism_outlined,
                        size: 16.r, color: kResponsibilityTint),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: CustomText(
                      title: _isEditing
                          ? 'edit_responsibility_person'.tr
                          : 'add_responsibility_person'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      textColor: appColors.titleTextColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              CustomTextField(
                controller: _name,
                label: 'full_name'.tr,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'responsibility_name_required'.tr
                    : null,
              ),
              SizedBox(height: 12.h),

              // Optional on purpose. Most of these people have no phone, and
              // requiring one would shut out exactly the people the feature is
              // for. It is a contact detail the sponsor keeps, nothing more: no
              // account is created and no invitation is ever sent to it.
              CustomTextField(
                controller: _phone,
                label: '${'phone_optional'.tr} · 09xxxxxxxx',
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 6.h),
              CustomText(
                title: 'responsibility_phone_note'.tr,
                fontSize: 10.sp,
                fontWeight: FontWeight.w400,
                textColor: appColors.hintTextColor,
              ),
              SizedBox(height: 12.h),

              CustomTextField(
                controller: _relation,
                label: 'relation_optional'.tr,
              ),
              SizedBox(height: 18.h),

              RoundedButton(
                label: widget.contributionAmount > 0 && !_isEditing
                    ? 'responsibility_confirm_with_cost'.trParams({
                        'amount': etb(widget.contributionAmount),
                      })
                    : (_isEditing ? 'save'.tr : 'add_person'.tr),
                height: 48.h,
                backgroundColor: primary,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation before taking someone's place out of the circle.
Future<bool> confirmRemoveResponsibilityPerson(
  BuildContext context,
  String name,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: CustomText(
        title: '${'remove'.tr} $name?',
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      ),
      content: CustomText(
        title: 'remove_responsibility_person_body'.tr,
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('remove'.tr),
        ),
      ],
    ),
  );

  return ok == true;
}
