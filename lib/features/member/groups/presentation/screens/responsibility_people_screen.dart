import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/responsibility_widgets.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';

/// Manage the people you are responsible for in a group that already exists.
///
/// The create screen keeps its own local list because the group is not there
/// yet; from here on every change is a request, because each one adds or
/// removes a real place in a running circle and changes what the sponsor owes.
class ResponsibilityPeopleScreen extends StatefulWidget {
  static const String routeName = '/equb-responsibility-people';

  final int groupId;

  /// Passed in from the group so the cost of a new person can be shown before
  /// the list has loaded.
  final double contributionAmount;
  final int frequencyDays;

  const ResponsibilityPeopleScreen({
    super.key,
    required this.groupId,
    this.contributionAmount = 0,
    this.frequencyDays = 0,
  });

  @override
  State<ResponsibilityPeopleScreen> createState() => _ResponsibilityPeopleScreenState();
}

class _ResponsibilityPeopleScreenState extends State<ResponsibilityPeopleScreen> {
  ResponsibilityPeople? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// True once anything has been added or removed, so the group screen behind
  /// this one knows to reload its ledger and head-count.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final result = await sl<GroupEqubRepository>().getResponsibilityPeople(widget.groupId);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        // Keep whatever is already on screen if a background refresh fails.
        if (_data == null) _error = failure.errorMessage;
      }),
      (data) => setState(() {
        _loading = false;
        _error = null;
        _data = data;
      }),
    );
  }

  double get _amount {
    final fromList = _data?.people.isNotEmpty == true
        ? _data!.people.first.contributionAmount
        : 0.0;
    return widget.contributionAmount > 0 ? widget.contributionAmount : fromList;
  }

  int get _days {
    final fromList = _data?.people.isNotEmpty == true
        ? _data!.people.first.frequencyDays
        : 0;
    return widget.frequencyDays > 0 ? widget.frequencyDays : fromList;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final data = _data;
    final mine = data?.mine ?? const <ResponsibilityPerson>[];
    final others = (data?.people ?? const <ResponsibilityPerson>[])
        .where((p) => !p.isMine)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appColors.scaffoldBackgroundColor,
        elevation: 0,
        // Hands the "something changed" flag back to the group screen, which
        // reloads its head-count and ledger on a true. A system back gesture
        // returns null, which the caller reads as no change — the worst case
        // is a stale count until the next pull-to-refresh, never a wrong one.
        leading: IconButton(
          onPressed: () => Get.back(result: _changed),
          icon: Icon(Icons.arrow_back, size: 20.r, color: appColors.titleTextColor),
        ),
        title: CustomText(
          title: 'my_responsibility_people'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          textColor: appColors.titleTextColor,
        ),
      ),
      bottomNavigationBar: (data?.canAdd ?? false) && !data!.isAtLimit
          ? SafeArea(
              minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: RoundedButton(
                label: 'add_a_person'.tr,
                height: 50.h,
                submitting: _busy,
                backgroundColor: primary,
                icon: Icon(Icons.person_add_alt_rounded, size: 16.r, color: Colors.white),
                foregroundColor: Colors.white,
                onPressed: _add,
              ),
            )
          : null,
      body: _loading
          ? _skeleton(context)
          : _error != null
              ? GroupEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'could_not_open_equb'.tr,
                    body: _error!,
                    action: RoundedButton(
                      label: 'try_again'.tr,
                      width: 160.w,
                      backgroundColor: primary,
                      onPressed: _load,
                    ),
                  )
                : RefreshIndicator(
                    color: primary,
                    onRefresh: () => _load(silent: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 30.h),
                      children: [
                        ResponsibilityExplainer(
                          contributionAmount: _amount,
                          frequencyDays: _days,
                          count: data?.myCount ?? 0,
                          limit: data?.limitPerMember ?? 0,
                        ),
                        SizedBox(height: 16.h),

                        if (mine.isEmpty && others.isEmpty)
                          GroupEmptyState(
                            icon: Icons.volunteer_activism_outlined,
                            title: 'no_responsibility_people'.tr,
                            body: 'no_responsibility_people_body'.tr,
                          )
                        else ...[
                          if (mine.isNotEmpty) ...[
                            _groupHeading(context, 'yours_to_pay_for'.tr, mine.length),
                            SizedBox(height: 8.h),
                            // The total the sponsor owes each round for these
                            // places alone, kept in front of them rather than
                            // buried in the ledger.
                            if (_amount > 0) _myTotalCard(context, mine.length),
                            SizedBox(height: 10.h),
                            ...mine.map(
                              (p) => ResponsibilityPersonTile(
                                person: p,
                                contributionAmount: _amount,
                                frequencyDays: _days,
                                onEdit: _busy ? null : () => _edit(p),
                                onRemove: _busy ? null : () => _remove(p),
                              ),
                            ),
                            SizedBox(height: 18.h),
                          ],

                          // Only the group creator ever sees this section: the
                          // API sends other members' people to them alone,
                          // because they answer for the whole circle's
                          // collection. It is read-only here, because
                          // correcting someone else's family member is not
                          // their call.
                          if (others.isNotEmpty) ...[
                            _groupHeading(
                              context,
                              'carried_by_other_members'.tr,
                              others.length,
                            ),
                            SizedBox(height: 8.h),
                            ...others.map(
                              (p) => ResponsibilityPersonTile(
                                person: p,
                                contributionAmount: _amount,
                                frequencyDays: _days,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
    );
  }

  Widget _groupHeading(BuildContext context, String label, int count) {
    final appColors = colors(context);

    return Row(
      children: [
        CustomText(
          title: label,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w700,
          textColor: appColors.titleTextColor,
        ),
        SizedBox(width: 6.w),
        CustomText(
          title: '($count)',
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
          textColor: appColors.hintTextColor,
        ),
      ],
    );
  }

  Widget _myTotalCard(BuildContext context, int count) {
    final appColors = colors(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: kResponsibilityTint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: kResponsibilityTint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 15.r, color: kResponsibilityTint),
          SizedBox(width: 9.w),
          Expanded(
            child: CustomText(
              title: 'responsibility_round_total'.trParams({
                'count': '$count',
                'days': '$_days',
              }),
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              textColor: appColors.bodyTextColor,
            ),
          ),
          CustomText(
            title: etb(_amount * count),
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            textColor: kResponsibilityTint,
          ),
        ],
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: double.infinity, height: 70.h, radius: 14),
          SizedBox(height: 18.h),
          Skeleton(width: 140.w, height: 13.h),
          SizedBox(height: 12.h),
          const SkeletonCard(lines: 2),
          SizedBox(height: 10.h),
          const SkeletonCard(lines: 2),
        ],
      ),
    );
  }

  // --- Actions -------------------------------------------------------

  Future<void> _add() async {
    final draft = await showResponsibilityPersonSheet(
      context,
      contributionAmount: _amount,
      frequencyDays: _days,
    );

    if (draft == null || !mounted) return;

    setState(() => _busy = true);

    final result = await sl<GroupEqubRepository>()
        .addResponsibilityPerson(widget.groupId, draft);

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (person) {
        _changed = true;
        showSuccessSnackBar(
          context,
          'responsibility_added'.trParams({'name': person.name}),
        );
        _load(silent: true);
      },
    );
  }

  Future<void> _edit(ResponsibilityPerson person) async {
    final draft = await showResponsibilityPersonSheet(
      context,
      initial: ResponsibilityPersonDraft(
        name: person.name,
        phone: person.phone,
        relation: person.relation,
        note: person.note,
      ),
      contributionAmount: _amount,
      frequencyDays: _days,
    );

    if (draft == null || !mounted) return;

    setState(() => _busy = true);

    final result = await sl<GroupEqubRepository>()
        .updateResponsibilityPerson(widget.groupId, person.membershipId, draft);

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (_) {
        // A rename does not change any money, so the screen behind this one
        // does not need reloading for it — but the ledger shows the name, so
        // it does.
        _changed = true;
        showSuccessSnackBar(context, 'details_updated'.tr);
        _load(silent: true);
      },
    );
  }

  Future<void> _remove(ResponsibilityPerson person) async {
    final ok = await confirmRemoveResponsibilityPerson(context, person.name);
    if (!ok || !mounted) return;

    setState(() => _busy = true);

    final result = await sl<GroupEqubRepository>()
        .removeResponsibilityPerson(widget.groupId, person.membershipId);

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (message) {
        _changed = true;
        showSuccessSnackBar(context, message);
        _load(silent: true);
      },
    );
  }
}
