import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/responsibility_widgets.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_night_theme.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/widgets/skeleton.dart';

/// Manage the people you are responsible for in a group that already exists.
///
/// The create screen keeps its own local list because the group is not there
/// yet; from here on every change is a request, because each one adds or
/// removes a real place in a running circle and changes what the sponsor owes.
class ResponsibilityPeopleScreen extends StatelessWidget {
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
  Widget build(BuildContext context) => NiyaNightTheme(
    child: _ResponsibilityPeopleView(
      groupId: groupId,
      contributionAmount: contributionAmount,
      frequencyDays: frequencyDays,
    ),
  );
}

class _ResponsibilityPeopleView extends StatefulWidget {
  final int groupId;
  final double contributionAmount;
  final int frequencyDays;

  const _ResponsibilityPeopleView({
    required this.groupId,
    required this.contributionAmount,
    required this.frequencyDays,
  });

  @override
  State<_ResponsibilityPeopleView> createState() =>
      _ResponsibilityPeopleViewState();
}

class _ResponsibilityPeopleViewState extends State<_ResponsibilityPeopleView> {
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

    final result = await sl<GroupEqubRepository>().getResponsibilityPeople(
      widget.groupId,
    );
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
    final data = _data;
    final canAdd = data != null && data.canAdd && !data.isAtLimit;

    return NiyaNightScaffold(
      title: 'my_responsibility_people'.tr,
      // Hands the "something changed" flag back to the group screen, which
      // reloads its head-count and ledger on a true. A system back gesture
      // returns null, which the caller reads as no change — the worst case
      // is a stale count until the next pull-to-refresh, never a wrong one.
      leading: IconButton(
        onPressed: () => Get.back(result: _changed),
        icon: Icon(
          Icons.arrow_back_rounded,
          size: 21.r,
          color: NiyaPalette.goldLight,
        ),
      ),
      bottomBar: canAdd ? _bottomBar : null,
      body: _body,
    );
  }

  Widget _bottomBar(BuildContext context) => NiyaGoldButton(
    label: 'add_a_person'.tr,
    icon: Icons.person_add_alt_rounded,
    busy: _busy,
    height: 50.h,
    fontSize: 15.sp,
    onPressed: _add,
  );

  Widget _body(BuildContext context) {
    final topInset = niyaTopInset(context);
    final data = _data;

    if (_loading) return _skeleton(topInset);

    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: SingleChildScrollView(
            child: NiyaEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'could_not_open_equb'.tr,
              body: _error!,
              actionLabel: 'try_again'.tr,
              actionIcon: Icons.refresh_rounded,
              onAction: _load,
            ),
          ),
        ),
      );
    }

    final mine = data?.mine ?? const <ResponsibilityPerson>[];
    final others = (data?.people ?? const <ResponsibilityPerson>[])
        .where((p) => !p.isMine)
        .toList(growable: false);

    return RefreshIndicator(
      color: NiyaPalette.gold,
      backgroundColor: NiyaPalette.navy,
      edgeOffset: topInset,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, topInset + 14.h, 16.w, 32.h),
        children: [
          ResponsibilityExplainer(
            contributionAmount: _amount,
            frequencyDays: _days,
            count: data?.myCount ?? 0,
            limit: data?.limitPerMember ?? 0,
          ),
          SizedBox(height: 18.h),

          if (mine.isEmpty && others.isEmpty)
            NiyaEmptyState(
              icon: Icons.volunteer_activism_rounded,
              title: 'no_responsibility_people'.tr,
              body: 'no_responsibility_people_body'.tr,
            )
          else ...[
            if (mine.isNotEmpty) ...[
              NiyaSectionLabel(
                label: 'yours_to_pay_for'.tr,
                icon: Icons.volunteer_activism_rounded,
                tint: responsibilityTint(context),
                trailing: NiyaPill(
                  label: '${mine.length}',
                  color: responsibilityTint(context),
                ),
              ),
              SizedBox(height: 10.h),
              // The total the sponsor owes each round for these places alone,
              // kept in front of them rather than buried in the ledger.
              if (_amount > 0) ...[
                _myTotalCard(context, mine.length),
                SizedBox(height: 10.h),
              ],
              ...mine.map(
                (p) => ResponsibilityPersonTile(
                  person: p,
                  contributionAmount: _amount,
                  frequencyDays: _days,
                  onEdit: _busy ? null : () => _edit(p),
                  onRemove: _busy ? null : () => _remove(p),
                ),
              ),
              SizedBox(height: 20.h),
            ],

            // Only the group creator ever sees this section: the API sends
            // other members' people to them alone, because they answer for the
            // whole circle's collection. It is read-only here, because
            // correcting someone else's family member is not their call.
            if (others.isNotEmpty) ...[
              NiyaSectionLabel(
                label: 'carried_by_other_members'.tr,
                icon: Icons.groups_rounded,
                trailing: NiyaPill(
                  label: '${others.length}',
                  color: NiyaPalette.goldLight,
                ),
              ),
              SizedBox(height: 10.h),
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
    );
  }

  Widget _myTotalCard(BuildContext context, int count) {
    final tint = responsibilityTint(context);

    return Container(
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
              'responsibility_round_total'.trParams({
                'count': '$count',
                'days': '$_days',
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
            etb(_amount * count),
            style: TextStyle(
              color: tint,
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(double topInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, topInset + 16.h, 16.w, 0),
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

    final result = await sl<GroupEqubRepository>().addResponsibilityPerson(
      widget.groupId,
      draft,
    );

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

    final result = await sl<GroupEqubRepository>().updateResponsibilityPerson(
      widget.groupId,
      person.membershipId,
      draft,
    );

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

    final result = await sl<GroupEqubRepository>().removeResponsibilityPerson(
      widget.groupId,
      person.membershipId,
    );

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
