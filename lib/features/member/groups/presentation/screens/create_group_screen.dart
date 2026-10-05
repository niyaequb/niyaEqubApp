import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/html_text.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/screens/group_detail_screen.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/responsibility_widgets.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/shared/presentation/screens/terms_screen.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_night_theme.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';

/// Two decisions only: which Equb you're joining, and who is in your group.
/// Every amount is calculated from the Equb's package — nothing is typed in.
///
/// The night theme is applied HERE, above the form, and not inside it. Modal
/// sheets, dialogs and snack bars inherit their colours from the context they
/// are opened with, and a State's own `context` sits above whatever that State
/// builds. Had the theme been applied inside, every sheet this screen opens
/// would have come back in the app's light colours over a navy page.
class CreateGroupScreen extends StatelessWidget {
  static const String routeName = '/create-equb-group';

  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NiyaNightTheme(child: _CreateGroupForm());
}

class _CreateGroupForm extends StatefulWidget {
  const _CreateGroupForm();

  @override
  State<_CreateGroupForm> createState() => _CreateGroupFormState();
}

class _CreateGroupFormState extends State<_CreateGroupForm> {
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

  /// Whether the field has anything in it at all.
  ///
  /// Tracked separately from [_phoneReady] because the hint under the field
  /// appears exactly while there IS text that is NOT yet a complete number -
  /// and across that whole stretch `ready` stays false from one keystroke to
  /// the next. Rebuilding only when `ready` flips means this State never
  /// rebuilds while a number is being typed, and the hint never appears at
  /// all. Reading the controller in build() does not help: TextField's own
  /// setState does not reach the State that owns it.
  bool _phoneHasText = false;

  /// The exact terms text the member read and accepted.
  ///
  /// Stored as the text itself rather than as a bool, so acceptance belongs to
  /// one specific document. Switch to another Equb, or have an admin edit the
  /// terms while this screen is open, and the stored text no longer matches
  /// what is about to be agreed to — so the acceptance lapses and has to be
  /// given again. A bool would quietly carry one Equb's consent onto another's
  /// contract.
  String? _acceptedTerms;

  static const int _responsibilityLimit = 10;

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

  // --- Terms ----------------------------------------------------------

  /// The chosen Equb's terms as plain text, laid out in lines.
  String get _termsText => htmlToPlainText(_equb?.termsContent);

  bool get _needsTerms => _termsText.isNotEmpty;

  /// True when there is nothing left to agree to — either this Equb carries no
  /// terms, or the member has read and accepted the exact text it carries now.
  bool get _termsSettled => !_needsTerms || _acceptedTerms == _termsText;

  /// Opens the terms full screen with the acceptance bar. Returns having set
  /// [_acceptedTerms] only if the member scrolled to the end, ticked the box
  /// and pressed accept.
  Future<void> _openTerms({bool validateFirst = false}) async {
    final text = _termsText;
    if (text.isEmpty) return;

    // Checked before the reader opens, not after: nobody should read a
    // contract to the last line and only then be told their group has no name.
    if (validateFirst && !_validateForm()) return;

    final accepted = await TermsScreen.open(
      context,
      terms: text,
      subtitle: _equb?.name,
      requireAcceptance: true,
    );

    if (!mounted || !accepted) return;
    setState(() => _acceptedTerms = text);
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
    final hasText = raw.trim().isNotEmpty;

    if (ready == _phoneReady && hasText == _phoneHasText) return;

    setState(() {
      _phoneReady = ready;
      _phoneHasText = hasText;
    });
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
      _phoneHasText = false;
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
    return NiyaNightScaffold(
      title: 'New Group Equb'.tr,
      bottomBar: _loading || _equbs.isEmpty ? null : _bottomBar,
      body: _body,
    );
  }

  Widget _body(BuildContext context) {
    final topInset = niyaTopInset(context);

    if (_loading) return _loadingSkeleton(topInset);

    if (_equbs.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: SingleChildScrollView(
            child: NiyaEmptyState(
              icon: Icons.inbox_rounded,
              title: 'No Equbs open right now'.tr,
              body:
                  'There are no running Equbs to build a group inside yet. Check back soon.'
                      .tr,
            ),
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, topInset + 10.h, 16.w, 28.h),
        children: [
          NiyaSectionLabel(
            label: 'Which Equb are you joining?'.tr,
            icon: Icons.savings_rounded,
          ),
          SizedBox(height: 10.h),
          _equbPicker(context),
          if (_equb != null) ...[SizedBox(height: 12.h), _moneyCard(context)],
          SizedBox(height: 24.h),

          NiyaSectionLabel(
            label: 'Group name'.tr,
            icon: Icons.drive_file_rename_outline_rounded,
          ),
          SizedBox(height: 10.h),
          NiyaField(
            controller: _name,
            label: 'e.g. Family Umrah 2026'.tr,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Give your group a name' : null,
          ),
          SizedBox(height: 24.h),

          NiyaSectionLabel(
            label: 'Add members'.tr,
            icon: Icons.person_add_alt_1_rounded,
            trailing: _pendingPhones.isEmpty
                ? null
                : NiyaPill(
                    label: '${_pendingPhones.length}',
                    color: NiyaPalette.goldLight,
                  ),
          ),
          SizedBox(height: 6.h),
          _hint('add_members_phone_only_hint'.tr),
          SizedBox(height: 10.h),
          _memberPhoneField(context),
          if (_pendingPhones.isNotEmpty) _pickedList(context),
          SizedBox(height: 26.h),

          _responsibilitySection(context),
          SizedBox(height: 26.h),

          if (_needsTerms) ...[_termsCard(context), SizedBox(height: 26.h)],

          NiyaSectionLabel(
            label: 'Description (optional)'.tr,
            icon: Icons.notes_rounded,
          ),
          SizedBox(height: 10.h),
          NiyaField(
            controller: _description,
            label: 'Who this group is for'.tr,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  /// The one action, and what it is for right now.
  ///
  /// When terms are outstanding this is not a disabled Create button. A dead
  /// button says "no" without saying why; this one says what is missing and
  /// does it in the same tap.
  Widget _bottomBar(BuildContext context) {
    final mustRead = _needsTerms && !_termsSettled;

    return NiyaGoldButton(
      label: mustRead
          ? 'Read and accept the terms'.tr
          : 'Accept and create group'.tr,
      icon: mustRead ? Icons.menu_book_rounded : Icons.check_rounded,
      busy: _submitting,
      height: 50.h,
      fontSize: 15.sp,
      onPressed: mustRead ? () => _openTerms(validateFirst: true) : _submit,
    );
  }

  /// Keeps the form's shape during a first-ever load rather than dropping to a
  /// centred spinner.
  Widget _loadingSkeleton(double topInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, topInset + 14.h, 16.w, 0),
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

  Widget _hint(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white60,
      fontSize: 11.sp,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
  );

  Widget _equbPicker(BuildContext context) {
    final equb = _equb;

    return NiyaCard(
      onTap: _openEqubSheet,
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
      child: Row(
        children: [
          NiyaStarBadge(
            size: 50.r,
            child: packageGlyph(equb?.packageName ?? equb?.name, size: 22.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equb?.name ?? 'Choose an Equb'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (equb != null) ...[
                  SizedBox(height: 3.h),
                  Text(
                    '${etb(equb.contributionPerPerson)} per person '
                    'every ${equb.frequencyDays} day(s)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 6.w),
          Icon(
            Icons.expand_more_rounded,
            size: 22.r,
            color: NiyaPalette.goldLight,
          ),
        ],
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
      backgroundColor: NiyaPalette.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => _EqubPickerSheet(equbs: _equbs, selectedId: _equb?.id),
    );

    if (picked == null || !mounted) return;

    setState(() => _equb = picked);
  }

  /// Everything here is derived: per-person amount from the Equb's package,
  /// totals from the head-count.
  Widget _moneyCard(BuildContext context) {
    final perPerson = _equb!.contributionPerPerson;
    final rounds = _equb!.roundsTotal > 0 ? _equb!.roundsTotal : 1;
    final roundTotal = perPerson * _headCount;

    return NiyaCard(
      color: NiyaPalette.navyDeep.withValues(alpha: 0.72),
      padding: EdgeInsets.all(15.r),
      child: Column(
        children: [
          _moneyRow('Each person, per round'.tr, etb(perPerson), bold: false),
          _moneyDivider(),
          _moneyRow('Members in the group'.tr, '$_headCount', bold: false),
          // Only appears once there is something to explain: it says how much
          // of that head-count is places the creator is paying for, so the
          // number never looks larger than the people who agreed to join.
          if (_responsibility.isNotEmpty) ...[
            _moneyDivider(),
            _moneyRow(
              'people_you_pay_for'.tr,
              '${_responsibility.length}',
              bold: false,
              tint: responsibilityTint(context),
            ),
          ],
          _moneyDivider(),
          _moneyRow('Whole group, per round'.tr, etb(roundTotal), bold: true),
          _moneyDivider(),
          _moneyRow(
            "${'Whole group, all'.tr} $rounds ${'rounds'.tr}",
            etb(roundTotal * rounds),
            bold: false,
          ),
          // The creator's own bill, separated out from the group's. Without
          // this the card only ever showed what the circle owes together,
          // which is not the figure the person tapping "create" needs.
          if (_responsibility.isNotEmpty) ...[
            _moneyDivider(),
            _moneyRow(
              'your_part_per_round'.tr,
              etb(_myRoundTotal),
              bold: true,
              tint: responsibilityTint(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyDivider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 9.h),
    child: const NiyaGoldRule(thickness: 0.8),
  );

  Widget _moneyRow(
    String label,
    String value, {
    required bool bold,
    Color? tint,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          value,
          style: TextStyle(
            color: tint ?? (bold ? NiyaPalette.goldLight : Colors.white),
            fontSize: bold ? 15.sp : 12.5.sp,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // --- Terms card -----------------------------------------------------

  Widget _termsCard(BuildContext context) {
    final settled = _termsSettled;
    // Enough of the document to prove it is a real one, and no more. The
    // whole thing belongs on a page of its own, not in a 260-pixel box that
    // steals the scroll from the form it sits in.
    final preview = _termsText.split('\n').where((l) => l.isNotEmpty).take(3);

    return NiyaCard(
      emphasised: !settled,
      padding: EdgeInsets.fromLTRB(14.w, 13.h, 14.w, 13.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                size: 16.r,
                color: NiyaPalette.goldLight,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Terms and conditions'.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              NiyaPill(
                label: settled ? 'Accepted'.tr : 'Not read yet'.tr,
                color: settled
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFFBBF24),
                icon: settled
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            preview.join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
          SizedBox(height: 12.h),
          if (settled)
            NiyaGhostButton(
              label: 'Read the terms again'.tr,
              icon: Icons.menu_book_rounded,
              height: 42.h,
              onPressed: _openTerms,
            )
          else
            NiyaGoldButton(
              label: 'Read the terms'.tr,
              icon: Icons.menu_book_rounded,
              height: 42.h,
              fontSize: 13.sp,
              onPressed: _openTerms,
            ),
        ],
      ),
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
    final tint = responsibilityTint(context);
    final atLimit = _responsibility.length >= _responsibilityLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NiyaSectionLabel(
          label: 'my_responsibility_people'.tr,
          icon: Icons.volunteer_activism_rounded,
          tint: tint,
          trailing: _responsibility.isEmpty
              ? null
              : NiyaPill(label: '${_responsibility.length}', color: tint),
        ),
        SizedBox(height: 6.h),
        _hint('my_responsibility_people_subtitle'.tr),
        SizedBox(height: 12.h),

        ResponsibilityExplainer(
          contributionAmount: _equb?.contributionPerPerson ?? 0,
          frequencyDays: _equb?.frequencyDays ?? 0,
          count: _responsibility.length,
          limit: _responsibilityLimit,
        ),
        SizedBox(height: 10.h),

        ..._responsibility.asMap().entries.map(
          (entry) => _responsibilityRow(context, entry.key, entry.value),
        ),

        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: atLimit ? null : _addResponsibilityPerson,
            borderRadius: BorderRadius.circular(14.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: atLimit
                    ? Colors.transparent
                    : tint.withValues(alpha: 0.1),
                border: Border.all(
                  color: atLimit
                      ? Colors.white24
                      : tint.withValues(alpha: 0.55),
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
                    color: atLimit ? Colors.white38 : tint,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      atLimit
                          ? 'responsibility_limit_reached'.trParams({
                              'limit': '$_responsibilityLimit',
                            })
                          : 'add_a_person'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: atLimit ? Colors.white38 : tint,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // The running total the creator is signing up for. Shown only once
        // there is something extra to pay, so it appears as a consequence of
        // adding someone rather than as permanent noise.
        if (_responsibility.isNotEmpty &&
            (_equb?.contributionPerPerson ?? 0) > 0) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: tint.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 15.r,
                  color: tint,
                ),
                SizedBox(width: 9.w),
                Expanded(
                  child: Text(
                    'your_share_each_round'.trParams({
                      'people': '${1 + _responsibility.length}',
                    }),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  etb(_myRoundTotal),
                  style: TextStyle(
                    color: tint,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
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
    final tint = responsibilityTint(context);
    final details = [
      if ((person.relation ?? '').trim().isNotEmpty) person.relation!.trim(),
      if ((person.phone ?? '').trim().isNotEmpty) person.phone!.trim(),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: NiyaCard(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.2),
                border: Border.all(color: tint.withValues(alpha: 0.55)),
              ),
              alignment: Alignment.center,
              child: Text(
                person.name.trim().isEmpty
                    ? '?'
                    : person.name.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: tint,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    details.isEmpty ? 'you_pay_for_them'.tr : details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _editResponsibilityPerson(index),
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints(minWidth: 30.w, minHeight: 30.h),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.edit_outlined,
                size: 15.r,
                color: NiyaPalette.goldLight,
              ),
            ),
            SizedBox(width: 4.w),
            IconButton(
              onPressed: () => setState(() => _responsibility.removeAt(index)),
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints(minWidth: 30.w, minHeight: 30.h),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.close_rounded,
                size: 15.r,
                color: Colors.white60,
              ),
            ),
          ],
        ),
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
    const green = Color(0xFF4ADE80);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NiyaField(
          controller: _search,
          label: '09xxxxxxxx',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          // The tick is the only feedback. It appears on a complete number
          // and does nothing until tapped.
          suffix: IconButton(
            onPressed: _phoneReady ? _addPhone : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'add'.tr,
            icon: Icon(
              _phoneReady
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              size: 26.r,
              color: _phoneReady ? green : Colors.white24,
            ),
          ),
        ),
        if (_phoneHasText && !_phoneReady) ...[
          SizedBox(height: 6.h),
          _hint('phone_incomplete_hint'.tr),
        ],
        if (_phoneReady) ...[
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 12.r,
                color: NiyaPalette.goldLight,
              ),
              SizedBox(width: 6.w),
              Expanded(child: _hint('phone_ready_hint'.tr)),
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
            .map(
              (p) => _chip(
                label: p,
                onRemove: () => setState(() => _pendingPhones.remove(p)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _chip({required String label, required VoidCallback onRemove}) {
    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 4.w, top: 4.h, bottom: 4.h),
      decoration: BoxDecoration(
        color: NiyaPalette.maroon.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NiyaPalette.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: NiyaPalette.goldLight,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.close_rounded,
              size: 14.r,
              color: NiyaPalette.goldLight,
            ),
          ),
        ],
      ),
    );
  }

  /// An Equb has to be chosen and the group named before anything else is
  /// worth asking for.
  bool _validateForm() {
    if (_equb == null) {
      showErrorSnackBar(context, 'Choose which Equb you are joining.');
      return false;
    }
    return _formKey.currentState?.validate() ?? false;
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    // The bottom button routes to the reader while this is outstanding, so
    // reaching here with terms unaccepted means something else called _submit.
    // Send them to the terms rather than creating the group anyway.
    if (!_termsSettled) {
      await _openTerms();
      return;
    }

    setState(() => _submitting = true);

    final result = await sl<GroupEqubRepository>().createGroup({
      'parent_equb_group_id': _equb!.id,
      'name': _name.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      // Phones only. The server resolves each number to an existing member if
      // there is one, so the app never has to know — and never has to be told.
      'invite_phones': _pendingPhones,
      // Sent with the group rather than after it: nobody has to accept these,
      // so there is no invitation round-trip to wait for and they are members
      // of the circle from the moment it exists.
      if (_responsibility.isNotEmpty)
        'responsibility_people': _responsibility.map((p) => p.toJson()).toList(),
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
                .where(
                  (e) =>
                      e.name.toLowerCase().contains(term) ||
                      (e.packageName ?? '').toLowerCase().contains(term),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 14.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: NiyaPalette.gold.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          NiyaOrnamentTitle(title: 'Choose an Equb'.tr),
          SizedBox(height: 14.h),
          NiyaField(
            controller: _search,
            label: 'Search Equbs'.tr,
            icon: Icons.search_rounded,
            onChanged: _onSearch,
          ),
          SizedBox(height: 12.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 360.h),
            child: _filtered.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 28.h),
                    child: Text(
                      'No Equb matches that search.'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8.h),
                    itemBuilder: (_, i) {
                      final e = _filtered[i];
                      final selected = e.id == widget.selectedId;

                      return NiyaCard(
                        emphasised: selected,
                        padding: EdgeInsets.fromLTRB(10.w, 9.h, 10.w, 9.h),
                        onTap: () {
                          // Close the keyboard first: the sheet is about to
                          // shrink and unwind at the same time otherwise.
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop(e);
                        },
                        child: Row(
                          children: [
                            NiyaStarBadge(
                              size: 42.r,
                              child: packageGlyph(
                                e.packageName ?? e.name,
                                size: 18.r,
                              ),
                            ),
                            SizedBox(width: 11.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${etb(e.contributionPerPerson)} per person · '
                                    'every ${e.frequencyDays} day(s)'
                                    '${e.packageName != null ? ' · ${e.packageName}' : ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected) ...[
                              SizedBox(width: 6.w),
                              Icon(
                                Icons.check_circle_rounded,
                                color: NiyaPalette.goldLight,
                                size: 20.r,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
