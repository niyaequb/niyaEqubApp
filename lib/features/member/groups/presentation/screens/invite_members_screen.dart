import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_night_theme.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:share_plus/share_plus.dart';

/// Invite people to a group by their full phone number.
///
/// There is deliberately no member search here. It used to answer a partial
/// name with a list of matching members and their phone numbers, which let any
/// signed-in account read the member directory a fragment at a time. Whether a
/// number belongs to a registered member is never disclosed either: the server
/// resolves that when the invitation goes out, sending a push to people who
/// have the app and an SMS to those who do not.
class InviteMembersScreen extends StatelessWidget {
  static const String routeName = '/invite-equb-members';

  final int groupId;
  final String? inviteCode;

  const InviteMembersScreen({
    super.key,
    required this.groupId,
    this.inviteCode,
  });

  @override
  Widget build(BuildContext context) => NiyaNightTheme(
    child: _InviteMembersForm(groupId: groupId, inviteCode: inviteCode),
  );
}

class _InviteMembersForm extends StatefulWidget {
  final int groupId;
  final String? inviteCode;

  const _InviteMembersForm({required this.groupId, this.inviteCode});

  @override
  State<_InviteMembersForm> createState() => _InviteMembersFormState();
}

class _InviteMembersFormState extends State<_InviteMembersForm> {
  final _phone = TextEditingController();
  final _message = TextEditingController();

  final _phones = <String>[];

  /// Live format check on what is typed. Nothing is sent anywhere while
  /// typing.
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
  bool _sending = false;

  static const Color _good = Color(0xFF4ADE80);

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

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
    final normalised = normalizeEthiopianPhone(_phone.text.trim());

    if (!isCompleteEthiopianPhone(normalised)) return;

    if (_phones.contains(normalised)) {
      showErrorSnackBar(context, 'phone_already_added'.tr);
      return;
    }

    setState(() {
      _phones.add(normalised);
      _phone.clear();
      _phoneReady = false;
      _phoneHasText = false;
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _send() async {
    if (_phones.isEmpty) return;

    setState(() => _sending = true);

    final result = await sl<GroupEqubRepository>().invite(
      widget.groupId,
      phones: _phones,
      message: _message.text.trim(),
    );

    if (!mounted) return;
    setState(() => _sending = false);

    result.fold(
      (failure) => showErrorSnackBar(context, failure.errorMessage),
      (message) {
        showSuccessSnackBar(context, message);
        Get.back(result: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NiyaNightScaffold(
      title: 'Invite members'.tr,
      bottomBar: _phones.isEmpty ? null : _bottomBar,
      body: _body,
    );
  }

  Widget _bottomBar(BuildContext context) => NiyaGoldButton(
    label: 'Send ${_phones.length} invitation(s)',
    icon: Icons.send_rounded,
    busy: _sending,
    height: 50.h,
    fontSize: 15.sp,
    onPressed: _send,
  );

  Widget _body(BuildContext context) {
    final total = _phones.length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16.w,
        niyaTopInset(context) + 12.h,
        16.w,
        32.h,
      ),
      children: [
        if (widget.inviteCode != null) ...[
          _inviteCodeCard(context),
          SizedBox(height: 24.h),
        ],

        NiyaSectionLabel(
          label: 'add_by_phone_title'.tr,
          icon: Icons.dialpad_rounded,
        ),
        SizedBox(height: 6.h),
        Text(
          'add_members_phone_only_hint'.tr,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        SizedBox(height: 12.h),
        NiyaField(
          controller: _phone,
          label: '09xxxxxxxx',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          // The tick means "complete number, ready to invite". It never
          // means "this person has an account" — that is not disclosed.
          suffix: IconButton(
            onPressed: _phoneReady ? _addPhone : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'add'.tr,
            icon: Icon(
              _phoneReady
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              size: 26.r,
              color: _phoneReady ? _good : Colors.white24,
            ),
          ),
        ),
        if (_phoneHasText && !_phoneReady) ...[
          SizedBox(height: 6.h),
          Text(
            'phone_incomplete_hint'.tr,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        SizedBox(height: 24.h),

        if (total == 0)
          NiyaCard(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Icon(
                  Icons.group_add_rounded,
                  size: 18.r,
                  color: NiyaPalette.goldLight,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Nobody added yet. Add a number above, or share your invite code.'
                        .tr,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          NiyaSectionLabel(
            label: 'Inviting'.tr,
            icon: Icons.outgoing_mail,
            trailing: NiyaPill(
              label: '$total',
              color: NiyaPalette.goldLight,
            ),
          ),
          SizedBox(height: 12.h),
          ..._phones.map(
            (p) => _phoneRow(
              phone: p,
              onRemove: () => setState(() => _phones.remove(p)),
            ),
          ),
          SizedBox(height: 18.h),
          NiyaField(
            controller: _message,
            label: 'Add a note (optional)'.tr,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ],
    );
  }

  Widget _inviteCodeCard(BuildContext context) {
    final code = widget.inviteCode!;

    return NiyaCard(
      emphasised: true,
      padding: EdgeInsets.fromLTRB(14.w, 13.h, 10.w, 13.h),
      child: Row(
        children: [
          NiyaStarBadge(
            size: 46.r,
            child: Icon(
              Icons.vpn_key_rounded,
              size: 19.r,
              color: NiyaPalette.maroon,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite code'.tr,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NiyaPalette.goldLight,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy'.tr,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!mounted) return;
              showSuccessSnackBar(context, 'Invite code copied.'.tr);
            },
            icon: Icon(
              Icons.copy_rounded,
              size: 19.r,
              color: NiyaPalette.goldLight,
            ),
          ),
          IconButton(
            tooltip: 'Share'.tr,
            onPressed: () => Share.share(
              'Join my Group Equb on Niya Umrah Equb. Invite code: $code',
            ),
            icon: Icon(
              Icons.ios_share_rounded,
              size: 19.r,
              color: NiyaPalette.goldLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneRow({required String phone, required VoidCallback onRemove}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: NiyaCard(
        padding: EdgeInsets.fromLTRB(12.w, 9.h, 4.w, 9.h),
        child: Row(
          children: [
            Icon(
              Icons.phone_iphone_rounded,
              size: 16.r,
              color: NiyaPalette.goldLight,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phone,
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
                    'phone_ready_hint'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            NiyaPill(label: 'invite'.tr, color: NiyaPalette.goldLight),
            IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                size: 16.r,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
