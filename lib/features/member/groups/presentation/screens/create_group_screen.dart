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

  final _picked = <MemberLookupResult>[];
  final _pendingPhones = <String>[];
  List<MemberLookupResult> _results = [];
  bool _searching = false;
  bool _searched = false;
  String? _searchError;
  Timer? _debounce;

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
    _debounce?.cancel();
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

  void _onSearchChanged(String raw) {
    _debounce?.cancel();

    final term = raw.trim();
    if (term.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }

    // Search from the first character so results appear while typing.
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(term));
  }

  bool _looksLikePhone(String term) => RegExp(r'^[0-9+]{2,}$').hasMatch(term);

  Future<void> _runSearch(String term) async {
    if (!mounted) return;
    setState(() => _searching = true);

    // Typed as 09xxxxxxxx, stored as +2519xxxxxxxx. Two characters is enough
    // to tell: "09" already needs converting to "+2519".
    final query = _looksLikePhone(term) ? normalizeEthiopianPhone(term) : term;

    final result = await sl<GroupEqubRepository>().searchMembers(query);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _searching = false;
        _searched = true;
        _results = [];
        _searchError = failure.errorMessage;
      }),
      (list) => setState(() {
        _searching = false;
        _searched = true;
        _searchError = null;
        _results = list
            .where((m) => !_picked.any((p) => p.memberId == m.memberId))
            .toList();
      }),
    );
  }

  void _add(MemberLookupResult member) {
    setState(() {
      _picked.add(member);
      _results.removeWhere((m) => m.memberId == member.memberId);
      _search.clear();
      _results = [];
      _searched = false;
    });
    // Unfocus via the manager rather than FocusScope.of(context): the setState
    // above tears down the tapped tile, and an ancestor lookup from a
    // deactivated element is what trips the framework assertion.
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addRawPhone() {
    final normalised = normalizeEthiopianPhone(_search.text.trim());
    if (normalised.length < 9 || _pendingPhones.contains(normalised)) return;

    setState(() {
      _pendingPhones.add(normalised);
      _search.clear();
      _results = [];
    });
  }

  int get _headCount => 1 + _picked.length + _pendingPhones.length;

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
                        title: 'Search by name or phone. They join once they accept your invitation.'.tr,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        textColor: appColors.bodyTextSmallColor,
                      ),
                      SizedBox(height: 10.h),
                      _memberSearchField(context),
                      if (_results.isNotEmpty)
                        _resultsList(context)
                      else if (_searched && !_searching)
                        _noResults(context),
                      if (_picked.isNotEmpty || _pendingPhones.isNotEmpty)
                        _pickedList(context),
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
    final appColors = colors(context);
    final searchCtrl = TextEditingController();
    var filtered = _equbs;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appColors.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 16.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(
                title: 'Choose an Equb',
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                textColor: appColors.titleTextColor,
              ),
              SizedBox(height: 12.h),
              CustomTextField(
                controller: searchCtrl,
                label: 'Search Equbs',
                onChanged: (v) => setSheet(() {
                  final t = v.trim().toLowerCase();
                  filtered = t.isEmpty
                      ? _equbs
                      : _equbs
                          .where((e) =>
                              e.name.toLowerCase().contains(t) ||
                              (e.packageName ?? '').toLowerCase().contains(t))
                          .toList();
                }),
              ),
              SizedBox(height: 12.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 360.h),
                child: filtered.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: CustomText(
                          title: 'No Equb matches that search.',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          centerText: true,
                          textColor: appColors.bodyTextSmallColor,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final e = filtered[i];
                          final selected = e.id == _equb?.id;

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
                              setState(() => _equb = e);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    searchCtrl.dispose();
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
          Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
          _moneyRow(context, 'Whole group, per round'.tr, etb(roundTotal), bold: true),
          Divider(height: 18.h, color: primary.withValues(alpha: 0.18)),
          _moneyRow(context, "${'Whole group, all'.tr} $rounds ${'rounds'.tr}",
              etb(roundTotal * rounds),
              bold: false),
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

  Widget _memberSearchField(BuildContext context) {
    final appColors = colors(context);

    return Row(
      children: [
        Expanded(
          child: CustomTextField(
            controller: _search,
            label: 'Name or 09xxxxxxxx',
            keyboardType: TextInputType.text,
            onChanged: _onSearchChanged,
          ),
        ),
        if (_searching)
          Padding(
            padding: EdgeInsets.only(left: 12.w),
            child: SizedBox(
              width: 18.r,
              height: 18.r,
              child: CircularProgressIndicator(strokeWidth: 2.w),
            ),
          )
        else if (_search.text.trim().length >= 9)
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: TextButton(
              onPressed: _addRawPhone,
              child: CustomText(
                title: 'Invite',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                textColor: appColors.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  /// Shown when a search came back with nothing, so the field never looks
  /// broken. A phone number can still be invited by SMS.
  Widget _noResults(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final typed = _search.text.trim();
    final looksLikePhone = RegExp(r'^[0-9+]{6,}$').hasMatch(typed);

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, size: 17.r, color: appColors.hintTextColor),
          SizedBox(width: 10.w),
          Expanded(
            child: CustomText(
              title: _searchError ??
                  (looksLikePhone
                      ? 'Not on Niya yet. Tap Invite to send them an SMS.'
                      : 'Nobody matches that. Try a phone number instead.'),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w400,
              textColor: _searchError != null
                  ? const Color(0xFFDC2626)
                  : appColors.bodyTextSmallColor,
            ),
          ),
          if (looksLikePhone && _searchError == null)
            TextButton(
              onPressed: _addRawPhone,
              child: CustomText(
                title: 'Invite',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                textColor: primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultsList(BuildContext context) {
    final appColors = colors(context);
    final border = appColors.borderColor ?? AppStaticColor.borderLight;

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: _results.take(6).map((m) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16.r,
              backgroundColor:
                  (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                      .withValues(alpha: 0.14),
              child: CustomText(
                title: m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                textColor: appColors.primaryColor,
              ),
            ),
            title: CustomText(
              title: m.name,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              textColor: appColors.titleTextColor,
            ),
            subtitle: CustomText(
              title: m.phone ?? '',
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
              textColor: appColors.bodyTextSmallColor,
            ),
            trailing: Icon(Icons.add_circle_outline_rounded,
                size: 20.r, color: appColors.primaryColor),
            onTap: () => _add(m),
          );
        }).toList(),
      ),
    );
  }

  Widget _pickedList(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          ..._picked.map((m) => _chip(
                context,
                label: m.name,
                onRemove: () => setState(() => _picked.remove(m)),
              )),
          ..._pendingPhones.map((p) => _chip(
                context,
                label: p,
                subtle: true,
                onRemove: () => setState(() => _pendingPhones.remove(p)),
              )),
        ],
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
      'invite_member_ids': _picked.map((m) => m.memberId).toList(),
      'invite_phones': _pendingPhones,
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (group) {
        showSuccessSnackBar(context, 'Group created. Invitations are on their way.');
        Get.off(() => GroupDetailScreen(groupId: group.id));
      },
    );
  }
}
