import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/html_text.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/features/member/packages/presentation/widgets/equb_visuals.dart';
import 'package:niya_equb/shared/presentation/screens/terms_screen.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_night_theme.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// Enter an invite code, see what you are joining, agree to the terms, then
/// ask the creator for a place. Knowing a code is never enough on its own.
///
/// Deliberately a full screen rather than a bottom sheet: a modal that reads a
/// BlocProvider from the screen underneath is what leaves inherited-widget
/// dependents behind when the route is torn down.
///
/// The night theme goes on above the form so that sheets, dialogs and snack
/// bars opened from the State's own context inherit it — see the note on
/// CreateGroupScreen.
class JoinGroupScreen extends StatelessWidget {
  static const String routeName = '/join-equb-group';

  const JoinGroupScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NiyaNightTheme(child: _JoinGroupForm());
}

class _JoinGroupForm extends StatefulWidget {
  const _JoinGroupForm();

  @override
  State<_JoinGroupForm> createState() => _JoinGroupFormState();
}

class _JoinGroupFormState extends State<_JoinGroupForm> {
  final _code = TextEditingController();

  GroupPreview? _preview;
  bool _looking = false;
  bool _sending = false;
  bool _joined = false;
  String? _error;

  /// The exact terms text the member read and accepted — see the longer note
  /// on the same field in CreateGroupScreen. Looking up a different code puts
  /// different terms on the screen, and this makes the old acceptance lapse
  /// without any extra bookkeeping.
  String? _acceptedTerms;

  static const Color _danger = Color(0xFFF87171);
  static const Color _good = Color(0xFF4ADE80);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _termsText => htmlToPlainText(_preview?.termsContent);

  bool get _needsTerms => _termsText.isNotEmpty;

  bool get _termsSettled => !_needsTerms || _acceptedTerms == _termsText;

  Future<void> _openTerms() async {
    final text = _termsText;
    if (text.isEmpty) return;

    final accepted = await TermsScreen.open(
      context,
      terms: text,
      subtitle: _preview?.equbName ?? _preview?.name,
      requireAcceptance: true,
    );

    if (!mounted || !accepted) return;
    setState(() => _acceptedTerms = text);
  }

  Future<void> _lookup() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _looking = true;
      _error = null;
      _preview = null;
    });

    final result = await sl<GroupEqubRepository>().previewByCode(code);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _looking = false;
        _error = failure.errorMessage;
      }),
      (preview) => setState(() {
        _looking = false;
        _preview = preview;
      }),
    );
  }

  Future<void> _sendRequest() async {
    final preview = _preview;
    if (preview == null) return;

    // The bottom action sends them to the reader while this is outstanding, so
    // reaching here unaccepted means something else called in. Send them to
    // the terms rather than joining anyway.
    if (!_termsSettled) {
      await _openTerms();
      return;
    }

    setState(() => _sending = true);

    final result = await sl<GroupEqubRepository>().joinByCode(
      _code.text.trim(),
    );
    if (!mounted) return;

    setState(() => _sending = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (message) {
        setState(() => _joined = true);
        showSuccessSnackBar(context, message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NiyaNightScaffold(
      title: 'Join a group'.tr,
      bottomBar: _preview == null ? null : _bottomBar,
      body: _body,
    );
  }

  Widget _bottomBar(BuildContext context) {
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

    if (preview.alreadyMember || _joined) {
      return NiyaGoldButton(
        label: 'Done'.tr,
        icon: Icons.check_rounded,
        height: 50.h,
        fontSize: 15.sp,
        onPressed: () => Get.back(result: true),
      );
    }

    final mustRead = _needsTerms && !_termsSettled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NiyaGoldButton(
          label: mustRead
              ? 'Read and accept the terms'.tr
              : 'Accept and join'.tr,
          icon: mustRead ? Icons.menu_book_rounded : Icons.check_rounded,
          busy: _sending,
          height: 50.h,
          fontSize: 15.sp,
          onPressed: mustRead ? _openTerms : _sendRequest,
        ),
        SizedBox(height: 8.h),
        Text(
          'Your first contribution is due on the next round.'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final preview = _preview;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, niyaTopInset(context) + 12.h, 16.w, 32.h),
      children: [
        NiyaSectionLabel(
          label: 'Invite code'.tr,
          icon: Icons.key_rounded,
        ),
        SizedBox(height: 8.h),
        Text(
          'Enter the invite code the group creator shared with you.'.tr,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NiyaField(
                controller: _code,
                label: 'Invite code'.tr,
                icon: Icons.confirmation_number_rounded,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  if (_preview != null || _error != null) {
                    setState(() {
                      _preview = null;
                      _error = null;
                      _joined = false;
                    });
                  }
                },
              ),
            ),
            SizedBox(width: 10.w),
            SizedBox(
              width: 96.w,
              child: NiyaGoldButton(
                label: 'Find'.tr,
                busy: _looking,
                height: 52.h,
                fontSize: 14.sp,
                onPressed: _lookup,
              ),
            ),
          ],
        ),

        if (_error != null) ...[
          SizedBox(height: 18.h),
          _banner(
            icon: Icons.error_outline_rounded,
            color: _danger,
            text: _error!,
          ),
        ],

        if (preview != null) ...[
          SizedBox(height: 22.h),
          _groupCard(context, preview),

          if (preview.alreadyMember || _joined) ...[
            SizedBox(height: 16.h),
            _banner(
              icon: Icons.check_circle_outline_rounded,
              color: _good,
              text: _joined
                  ? 'You have joined this group. It is now in My Group Equbs.'.tr
                  : 'You are already a member of this group.'.tr,
            ),
          ] else ...[
            SizedBox(height: 18.h),
            if (_needsTerms)
              _termsCard(context)
            else
              _banner(
                icon: Icons.info_outline_rounded,
                color: NiyaPalette.goldLight,
                text:
                    'This Equb has no written terms. Ask the creator if you '
                            'are unsure how it works.'
                        .tr,
              ),
          ],
        ],
      ],
    );
  }

  Widget _termsCard(BuildContext context) {
    final settled = _termsSettled;
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
                color: settled ? _good : const Color(0xFFFBBF24),
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

  Widget _groupCard(BuildContext context, GroupPreview p) {
    final rows = <(String, String)>[
      if (p.equbName != null) ('Equb'.tr, p.equbName!),
      ('Each person, per round'.tr, etb(p.contributionPerPerson)),
      ('Every'.tr, '${p.frequencyDays} day(s)'),
      ('Members so far'.tr, '${p.membersCount}'),
      if (p.roundsTotal > 0) ('Rounds'.tr, '${p.roundsTotal}'),
      if (p.ownerName != null) ('Created by'.tr, p.ownerName!),
    ];

    return NiyaCard(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NiyaStarBadge(
                size: 48.r,
                child: packageGlyph(p.equbName ?? p.name, size: 21.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((p.description ?? '').isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        p.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const NiyaGoldRule(thickness: 0.8),
          SizedBox(height: 10.h),
          ...rows.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: 9.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.$1,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    r.$2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: EdgeInsets.all(13.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.r, color: color),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
