import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/group_detail_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/responsibility_widgets.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';

/// Two decisions only: which Equb you're joining, and who is in your group.
/// Every amount is calculated from the Equb's package — nothing is typed in.
class CreateGroupScreen extends StatefulWidget {
  static const String routeName = '/create-equb-group';

  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  String _cleanHtmlText(String htmlString) {
    if (htmlString.trim().isEmpty) return '';

    String cleaned = htmlString;

    // 1. Replace line break tags (<br>, <br/>) with a single newline
    cleaned = cleaned.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // 2. Replace paragraph and block closing tags with double newlines
    cleaned = cleaned.replaceAll(RegExp(r'</(p|div|h[1-6]|li)>', caseSensitive: false), '\n\n');

    // 3. Strip all remaining HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    // 4. Decode common HTML entities
    cleaned = cleaned
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    // 5. Clean up each line's whitespace and collapse 3+ excess newlines into 2
    return cleaned
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();

  List<JoinableEqub> _equbs = [];
  JoinableEqub? _equb;
  bool _loading = true;
  bool _submitting = false;

  /// Numbers to invite. There is no picked-member list any more: the app has
  /// no way to tell a registered number from an unregistered one, and does not
  /// need one — the server resolves it when the invitation is sent.
  final _pendingPhones = <String>[];

  /// People the creator is taking responsibility for: a child, a parent,
  /// anyone without a Niya account. Held locally until the group exists,
  /// then sent with it in one request — there is nobody to invite, so there is
  /// nothing to wait for.
  final _responsibility = <ResponsibilityPersonDraft>[];

  /// Live format check on what is typed. No network call is made at any point
  /// while typing — see the note on _memberPhoneField.
  bool _phoneReady = false;

  @override
  void initState() {
    super.initState();

    // The list of running Equbs barely changes, so the picker opens on the
    // last known copy and the network refresh lands underneath it. Only a
    // first-ever visit sees a loading state at all.
    final cached = sl<GroupEqubRepository>().cachedJoinableEqubs();
    if (cached != null && cached.isNotEmpty) {
      _equbs = cached;
      _equb = cached.first;
      _loading = false;
    }

    _loadEqubs();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadEqubs() async {
    final result = await sl<GroupEqubRepository>().getJoinableEqubs();
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _loading = false);
        // Cached Equbs are already usable, so only interrupt when the screen
        // has nothing to show.
        if (_equbs.isEmpty) showErrorSnackBar(context, failure.errorMessage);
      },
      (list) => setState(() {
        _equbs = list;

        // Keep whatever the user already picked from the cached list, as long
        // as it is still on offer.
        JoinableEqub? keep;
        for (final e in list) {
          if (e.id == _equb?.id) {
            keep = e;
            break;
          }
        }
        _equb = keep ?? (list.isNotEmpty ? list.first : null);
        _loading = false;
      }),
    );
  }

  // --- Members -------------------------------------------------------
  //
  // Adding someone is by full phone number, and by nothing else.
  //
  // This used to be a type-ahead over the member directory: typing "bila"
  // listed every Bilal on the platform with their phone number underneath. Any
  // signed-in account could read the directory out of it a fragment at a time
  // — who is registered, what their number is, and their full name. The search
  // was removed rather than trimmed, because any lookup that answers a partial
  // string is the same hole at a slower rate.
  //
  // Nothing is sent while typing and nothing is revealed about the person. A
  // complete number gets a tick, meaning "this number can be invited" — not
  // "this person has an account", which is deliberately never disclosed.

  void _onPhoneChanged(String raw) {
    final ready = isCompleteEthiopianPhone(raw);
    if (ready == _phoneReady) return;

    setState(() => _phoneReady = ready);
  }

  void _addPhone() {
    final normalised = normalizeEthiopianPhone(_search.text.trim());

    if (!isCompleteEthiopianPhone(normalised)) return;

    if (_pendingPhones.contains(normalised)) {
      showErrorSnackBar(context, 'phone_already_added'.tr);
      return;
    }

    setState(() {
      _pendingPhones.add(normalised);
      _search.clear();
      _phoneReady = false;
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Everyone who will hold a place in the circle: the creator, the numbers
  /// being invited, and the people the creator is answerable for. The last
  /// group counts here for the same reason it counts in the pot — a place is a
  /// place, whoever pays for it.
  int get _headCount => 1 + _pendingPhones.length + _responsibility.length;

  /// What the creator alone will owe every round: their own contribution plus
  /// one for each person they are responsible for.
  double get _myRoundTotal =>
      (_equb?.contributionPerPerson ?? 0) * (1 + _responsibility.length);

  // --- Build ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appColors.scaffoldBackgroundColor,
        elevation: 0,
        title: CustomText(
          title: 'New Group Equb'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          textColor: appColors.titleTextColor,
        ),
      ),
      bottomNavigationBar: _loading || _equbs.isEmpty
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: RoundedButton(
                label: 'Accept and create group'.tr,
                height: 50.h,
                submitting: _submitting,
                backgroundColor: primary,
                onPressed: _submit,
              ),
            ),
      body: _loading
          ? _loadingSkeleton(context)
          : _equbs.isEmpty
              ? const GroupEmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'No Equbs open right now',
                  body: 'There are no running Equbs to build a group inside yet. Check back soon.',
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                    children: [
                      _sectionLabel(context, 'Which Equb are you joining?'.tr),
                      SizedBox(height: 8.h),
                      _equbPicker(context),
                      SizedBox(height: 12.h),
                      if (_equb != null) _moneyCard(context),
                      SizedBox(height: 24.h),

                      _sectionLabel(context, 'Group name'.tr),
                      SizedBox(height: 8.h),
                      CustomTextField(
                        controller: _name,
                        label: 'e.g. Family Umrah 2026'.tr,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Give your group a name'
                            : null,
                      ),
                      SizedBox(height: 20.h),

                      _sectionLabel(context, 'Add members'.tr),
                      SizedBox(height: 4.h),
                      CustomText(
                        title: 'add_members_phone_only_hint'.tr,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        textColor: appColors.bodyTextSmallColor,
                      ),
                      SizedBox(height: 10.h),
                      _memberPhoneField(context),
                      if (_pendingPhones.isNotEmpty) _pickedList(context),
                      SizedBox(height: 24.h),

                      _responsibilitySection(context),
                      SizedBox(height: 20.h),

                      if ((_equb?.termsContent ?? '').trim().isNotEmpty) ...[
                        TermsCard(
                          terms: _cleanHtmlText(_equb!.termsContent!),
                          footnote: 'Creating the group means you accept these terms.'.tr,
                        ),
                        SizedBox(height: 20.h),
                      ],

                      _sectionLabel(context, 'Description (optional)'.tr),
                      SizedBox(height: 8.h),
                      CustomTextField(
                        controller: _description,
                        label: 'Who this group is for'.tr,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
    );
  }

  /// Keeps the form's shape during a first-ever load rather than dropping to a
  /// centred spinner.
  Widget _loadingSkeleton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 200.w, height: 13.h),
          SizedBox(height: 10.h),
          Skeleton(width: double.infinity, height: 58.h, radius: 14),
          SizedBox(height: 14.h),
          const SkeletonCard(lines: 4),
          SizedBox(height: 24.h),
          Skeleton(width: 120.w, height: 13.h),
          SizedBox(height: 10.h),
          Skeleton(width: double.infinity, height: 52.h, radius: 12),
          SizedBox(height: 22.h),
          Skeleton(width: 130.w, height: 13.h),
          SizedBox(height: 10.h),
          Skeleton(width: double.infinity, height: 52.h, radius: 12),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => CustomText(
        title: text,
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        textColor: colors(context).titleTextColor,
      );

  Widget _equbPicker(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final border = appColors.borderColor ?? AppStaticColor.borderLight;

    return InkWell(
      onTap: _openEqubSheet,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.savings_outlined, size: 17.r, color: primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    title: _equb?.name ?? 'Choose an Equb',
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    textColor: appColors.titleTextColor,
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                  if (_equb != null) ...[
                    SizedBox(height: 2.h),
                    CustomText(
                      title: '${etb(_equb!.contributionPerPerson)} per person '
                          'every ${_equb!.frequencyDays} day(s)',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 20.r, color: appColors.hintTextColor),
          ],
        ),
      ),
    );
  }

  Future<void> _openEqubSheet() async {
    // The sheet owns its own search controller — see _EqubPickerSheet. It is
    // popped with the chosen Equb rather than reaching back into this State,
    // so nothing here runs while the sheet is still animating away.
    final picked = await showModalBottomSheet<JoinableEqub>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => _EqubPickerSheet(
        equbs: _equbs,
        selectedId: _equb?.id,
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _equb = picked);
  }

  /// Everything here is derived: per-person amount from the Equb's package,
  /// totals from the head-count.
  Widget _moneyCard(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    final perPerson = _equb!.contributionPerPerson;
    final rounds = _equb!.roundsTotal > 0 ? _equb!.roundsTotal : 1;
    final roundTotal = perPerson * _headCount;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          _moneyRow(context, 'Each person, per round'.tr, etb(perPerson), bold: false),
          Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
          _moneyRow(context, 'Members in the group'.tr, '$_headCount', bold: false),
          // Only appears once there is something to explain: it says how much
          // of that head-count is places the creator is paying for, so the
          // number never looks larger than the people who agreed to join.
          if (_responsibility.isNotEmpty) ...[
            Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
            _moneyRow(
              context,
              'people_you_pay_for'.tr,
              '${_responsibility.length}',
              bold: false,
            ),
          ],
          Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
          _moneyRow(context, 'Whole group, per round'.tr, etb(roundTotal), bold: true),
          Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
          _moneyRow(context, "${'Whole group, all'.tr} $rounds ${'rounds'.tr}",
              etb(roundTotal * rounds),
              bold: false),
          // The creator's own bill, separated out from the group's. Without
          // this the card only ever showed what the circle owes together,
          // which is not the figure the person tapping "create" needs.
          if (_responsibility.isNotEmpty) ...[
            Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
            _moneyRow(context, 'your_part_per_round'.tr, etb(_myRoundTotal), bold: true),
          ],
        ],
      ),
    );
  }

  Widget _moneyRow(BuildContext context, String label, String value,
      {required bool bold}) {
    final appColors = colors(context);

    return Row(
      children: [
        Expanded(
          child: CustomText(
            title: label,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.bodyTextSmallColor,
          ),
        ),
        CustomText(
          title: value,
          fontSize: bold ? 15.sp : 12.5.sp,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          textColor: bold ? appColors.primaryColor : appColors.titleTextColor,
        ),
      ],
    );
  }

  // --- My Responsibility People ---------------------------------------

  /// The second way to fill a circle: people who cannot join by themselves.
  ///
  /// Kept visually distinct from "Add members" above rather than folded into
  /// the same list, because the two are different commitments. An invited
  /// member pays their own way; a person added here is paid for by the creator,
  /// every round, for the whole term. Merging them into one "people" list is
  /// exactly how someone ends up owing five contributions a day without having
  /// understood that they agreed to.
  Widget _responsibilitySection(BuildContext context) {
    final appColors = colors(context);
    final limit = 10;
    final atLimit = _responsibility.length >= limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.volunteer_activism_outlined,
                size: 15.r, color: kResponsibilityTint),
            SizedBox(width: 7.w),
            Expanded(child: _sectionLabel(context, 'my_responsibility_people'.tr)),
            if (_responsibility.isNotEmpty)
              CustomText(
                title: '${_responsibility.length}',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                textColor: kResponsibilityTint,
              ),
          ],
        ),
        SizedBox(height: 4.h),
        CustomText(
          title: 'my_responsibility_people_subtitle'.tr,
          fontSize: 11.sp,
          fontWeight: FontWeight.w400,
          textColor: appColors.bodyTextSmallColor,
        ),
        SizedBox(height: 10.h),

        ResponsibilityExplainer(
          contributionAmount: _equb?.contributionPerPerson ?? 0,
          frequencyDays: _equb?.frequencyDays ?? 0,
          count: _responsibility.length,
          limit: limit,
        ),
        SizedBox(height: 10.h),

        ..._responsibility.asMap().entries.map(
              (entry) => _responsibilityRow(context, entry.key, entry.value),
            ),

        InkWell(
          onTap: atLimit ? null : _addResponsibilityPerson,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: atLimit
                    ? (appColors.borderColor ?? AppStaticColor.borderLight)
                    : kResponsibilityTint.withValues(alpha: 0.45),
                // Dashed is not available on Border, so a lighter solid edge
                // carries the "this is an action, not a field" signal instead.
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  atLimit ? Icons.block_rounded : Icons.person_add_alt_rounded,
                  size: 16.r,
                  color: atLimit ? appColors.hintTextColor : kResponsibilityTint,
                ),
                SizedBox(width: 8.w),
                CustomText(
                  title: atLimit
                      ? 'responsibility_limit_reached'.trParams({'limit': '$limit'})
                      : 'add_a_person'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  textColor: atLimit ? appColors.hintTextColor : kResponsibilityTint,
                ),
              ],
            ),
          ),
        ),

        // The running total the creator is signing up for. Shown only once
        // there is something extra to pay, so it appears as a consequence of
        // adding someone rather than as permanent noise.
        if (_responsibility.isNotEmpty && (_equb?.contributionPerPerson ?? 0) > 0) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: kResponsibilityTint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 15.r, color: kResponsibilityTint),
                SizedBox(width: 9.w),
                Expanded(
                  child: CustomText(
                    title: 'your_share_each_round'.trParams({
                      'people': '${1 + _responsibility.length}',
                    }),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextColor,
                  ),
                ),
                CustomText(
                  title: etb(_myRoundTotal),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  textColor: kResponsibilityTint,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _responsibilityRow(
    BuildContext context,
    int index,
    ResponsibilityPersonDraft person,
  ) {
    final appColors = colors(context);
    final details = [
      if ((person.relation ?? '').trim().isNotEmpty) person.relation!.trim(),
      if ((person.phone ?? '').trim().isNotEmpty) person.phone!.trim(),
    ].join(' · ');

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: (appColors.borderColor ?? AppStaticColor.borderLight)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kResponsibilityTint.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: CustomText(
              title: person.name.trim().isEmpty
                  ? '?'
                  : person.name.trim()[0].toUpperCase(),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              textColor: kResponsibilityTint,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: person.name,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.titleTextColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                CustomText(
                  title: details.isEmpty ? 'you_pay_for_them'.tr : details,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w400,
                  textColor: appColors.bodyTextSmallColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editResponsibilityPerson(index),
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(minWidth: 30.w, minHeight: 30.h),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.edit_outlined, size: 15.r, color: appColors.hintTextColor),
          ),
          SizedBox(width: 4.w),
          IconButton(
            onPressed: () => setState(() => _responsibility.removeAt(index)),
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(minWidth: 30.w, minHeight: 30.h),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, size: 15.r, color: appColors.hintTextColor),
          ),
        ],
      ),
    );
  }

  Future<void> _addResponsibilityPerson() async {
    final person = await showResponsibilityPersonSheet(
      context,
      contributionAmount: _equb?.contributionPerPerson ?? 0,
      frequencyDays: _equb?.frequencyDays ?? 0,
    );

    if (person == null || !mounted) return;

    // A repeated name here is almost always a double tap, and the cost of
    // letting it through is a second contribution every round. The server
    // refuses it too; catching it now means the group is not created with a
    // silent skip the creator never sees.
    final exists = _responsibility.any(
      (p) => p.name.trim().toLowerCase() == person.name.trim().toLowerCase(),
    );

    if (exists) {
      showErrorSnackBar(
        context,
        'responsibility_duplicate'.trParams({'name': person.name.trim()}),
      );
      return;
    }

    setState(() => _responsibility.add(person));
  }

  Future<void> _editResponsibilityPerson(int index) async {
    final person = await showResponsibilityPersonSheet(
      context,
      initial: _responsibility[index],
      contributionAmount: _equb?.contributionPerPerson ?? 0,
      frequencyDays: _equb?.frequencyDays ?? 0,
    );

    if (person == null || !mounted) return;

    setState(() => _responsibility[index] = person);
  }

  /// Phone-only entry with a live format check.
  ///
  /// The tick means the number is complete and can be sent an invitation. It
  /// deliberately does NOT mean "this person is on Niya" — the app never asks
  /// and the server never says, because an endpoint that answers that question
  /// turns a stolen contact list into a list of confirmed users.
  Widget _memberPhoneField(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    const green = Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _search,
                label: '09xxxxxxxx',
                keyboardType: TextInputType.phone,
                onChanged: _onPhoneChanged,
              ),
            ),
            SizedBox(width: 10.w),
            // The tick is the only feedback. It appears on a complete number
            // and does nothing until tapped.
            IconButton(
              onPressed: _phoneReady ? _addPhone : null,
              visualDensity: VisualDensity.compact,
              tooltip: 'add'.tr,
              icon: Icon(
                _phoneReady
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                size: 28.r,
                color: _phoneReady
                    ? green
                    : (appColors.hintTextColor ?? Colors.grey)
                        .withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        if (_search.text.trim().isNotEmpty && !_phoneReady) ...[
          SizedBox(height: 6.h),
          CustomText(
            title: 'phone_incomplete_hint'.tr,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.hintTextColor,
          ),
        ],
        if (_phoneReady) ...[
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 12.r, color: primary),
              SizedBox(width: 6.w),
              Expanded(
                child: CustomText(
                  title: 'phone_ready_hint'.tr,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w400,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pickedList(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: _pendingPhones
            .map((p) => _chip(
                  context,
                  label: p,
                  onRemove: () => setState(() => _pendingPhones.remove(p)),
                ))
            .toList(),
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required String label, required VoidCallback onRemove, bool subtle = false}) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final tint = subtle ? appColors.hintTextColor ?? Colors.grey : primary;

    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 4.w, top: 6.h, bottom: 6.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomText(
            title: label,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            textColor: tint,
          ),
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, size: 14.r, color: tint),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_equb == null) {
      showErrorSnackBar(context, 'Choose which Equb you are joining.');
      return;
    }

    setState(() => _submitting = true);

    final result = await sl<GroupEqubRepository>().createGroup({
      'parent_equb_group_id': _equb!.id,
      'name': _name.text.trim(),
      if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
      // Phones only. The server resolves each number to an existing member if
      // there is one, so the app never has to know — and never has to be told.
      'invite_phones': _pendingPhones,
      // Sent with the group rather than after it: nobody has to accept these,
      // so there is no invitation round-trip to wait for and they are members
      // of the circle from the moment it exists.
      if (_responsibility.isNotEmpty)
        'responsibility_people':
            _responsibility.map((p) => p.toJson()).toList(),
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (group) {
        showSuccessSnackBar(
          context,
          _responsibility.isEmpty
              ? 'Group created. Invitations are on their way.'.tr
              : 'group_created_with_responsibility'.trParams({
                  'count': '${_responsibility.length}',
                }),
        );
        Get.off(() => GroupDetailScreen(groupId: group.id));
      },
    );
  }
}

/// The "Choose an Equb" bottom sheet.
///
/// A widget rather than a StatefulBuilder next to the showModalBottomSheet
/// call, so its search controller is created and disposed by the framework
/// alongside the sheet itself. Disposing it on the line after the await looks
/// equivalent but is not: the sheet goes on rebuilding throughout its closing
/// animation, and the search field would still be reading a controller that
/// had already been thrown away.
///
/// It also pops with the chosen Equb instead of calling setState on the screen
/// behind it, which keeps the two lifecycles from overlapping at all.
class _EqubPickerSheet extends StatefulWidget {
  final List<JoinableEqub> equbs;

  /// Ticks the row that is already selected. Just an id, so the sheet never
  /// holds on to a stale copy of the Equb itself.
  final int? selectedId;

  const _EqubPickerSheet({required this.equbs, this.selectedId});

  @override
  State<_EqubPickerSheet> createState() => _EqubPickerSheetState();
}

class _EqubPickerSheetState extends State<_EqubPickerSheet> {
  final _search = TextEditingController();

  late List<JoinableEqub> _filtered = widget.equbs;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    final term = value.trim().toLowerCase();

    setState(() {
      _filtered = term.isEmpty
          ? widget.equbs
          : widget.equbs
              .where((e) =>
                  e.name.toLowerCase().contains(term) ||
                  (e.packageName ?? '').toLowerCase().contains(term))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            title: 'Choose an Equb'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 12.h),
          CustomTextField(
            controller: _search,
            label: 'Search Equbs'.tr,
            onChanged: _onSearch,
          ),
          SizedBox(height: 12.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 360.h),
            child: _filtered.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: CustomText(
                      title: 'No Equb matches that search.'.tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      centerText: true,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final e = _filtered[i];
                      final selected = e.id == widget.selectedId;

                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                        title: CustomText(
                          title: e.name,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          textColor: appColors.titleTextColor,
                        ),
                        subtitle: CustomText(
                          title: '${etb(e.contributionPerPerson)} per person · '
                              'every ${e.frequencyDays} day(s)'
                              '${e.packageName != null ? ' · ${e.packageName}' : ''}',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          textColor: appColors.bodyTextSmallColor,
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle_rounded,
                                color: appColors.primaryColor, size: 20.r)
                            : null,
                        onTap: () {
                          // Close the keyboard first: the sheet is about to
                          // shrink and unwind at the same time otherwise.
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop(e);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
