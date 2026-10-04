import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:share_plus/share_plus.dart';

/// Invite people to a group by their full phone number.
///
/// There is deliberately no member search here. It used to answer a partial
/// name with a list of matching members and their phone numbers, which let any
/// signed-in account read the member directory a fragment at a time. Whether a
/// number belongs to a registered member is never disclosed either: the server
/// resolves that when the invitation goes out, sending a push to people who
/// have the app and an SMS to those who do not.
class InviteMembersScreen extends StatefulWidget {
  static const String routeName = '/invite-equb-members';

  final int groupId;
  final String? inviteCode;

  const InviteMembersScreen({super.key, required this.groupId, this.inviteCode});

  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  final _phone = TextEditingController();
  final _message = TextEditingController();

  final _phones = <String>[];

  /// Live format check on what is typed. Nothing is sent anywhere while
  /// typing.
  bool _phoneReady = false;
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String raw) {
    final ready = isCompleteEthiopianPhone(raw);
    if (ready == _phoneReady) return;

    setState(() => _phoneReady = ready);
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
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    const green = Color(0xFF16A34A);
    final total = _phones.length;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appColors.scaffoldBackgroundColor,
        elevation: 0,
        title: CustomText(
          title: 'Invite members',
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          textColor: appColors.titleTextColor,
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 40.h),
        children: [
          if (widget.inviteCode != null) _inviteCodeCard(context),

          CustomText(
            title: 'add_by_phone_title'.tr,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 4.h),
          CustomText(
            title: 'add_members_phone_only_hint'.tr,
            fontSize: 11.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.bodyTextSmallColor,
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _phone,
                  label: '09xxxxxxxx',
                  keyboardType: TextInputType.phone,
                  onChanged: _onPhoneChanged,
                ),
              ),
              SizedBox(width: 10.w),
              // The tick means "complete number, ready to invite". It never
              // means "this person has an account" — that is not disclosed.
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
          if (_phone.text.trim().isNotEmpty && !_phoneReady) ...[
            SizedBox(height: 6.h),
            CustomText(
              title: 'phone_incomplete_hint'.tr,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
              textColor: appColors.hintTextColor,
            ),
          ],
          SizedBox(height: 22.h),

          if (total == 0)
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: appColors.accentColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: (appColors.borderColor ?? AppStaticColor.borderLight)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: CustomText(
                title: 'Nobody added yet. Add a number above, or share your invite code.',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w400,
                centerText: true,
                textColor: appColors.bodyTextSmallColor,
              ),
            )
          else ...[
            CustomText(
              title: 'Inviting ($total)',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              textColor: appColors.titleTextColor,
            ),
            SizedBox(height: 10.h),
            ..._phones.map((p) => _chipRow(
                  context,
                  title: p,
                  subtitle: 'phone_ready_hint'.tr,
                  badge: 'invite'.tr,
                  badgeColor: primary,
                  onRemove: () => setState(() => _phones.remove(p)),
                )),
            SizedBox(height: 18.h),
            CustomTextField(
              controller: _message,
              label: 'Add a note (optional)',
              maxLines: 2,
            ),
            SizedBox(height: 22.h),
            RoundedButton(
              label: 'Send $total invitation(s)',
              height: 48.h,
              submitting: _sending,
              backgroundColor: primary,
              onPressed: _send,
            ),
          ],
        ],
      ),
    );
  }

  Widget _inviteCodeCard(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Container(
      margin: EdgeInsets.only(bottom: 22.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: 'Invite code',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  title: widget.inviteCode!,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  textColor: primary,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Share.share(
              'Join my Group Equb on Niya Umrah Equb. Invite code: ${widget.inviteCode}',
            ),
            icon: Icon(Icons.ios_share_rounded, size: 20.r, color: primary),
          ),
        ],
      ),
    );
  }

  Widget _chipRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onRemove,
  }) {
    final appColors = colors(context);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: title,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.titleTextColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  CustomText(
                    title: subtitle,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w400,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: CustomText(
              title: badge,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
              textColor: badgeColor,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 16.r, color: appColors.hintTextColor),
          ),
        ],
      ),
    );
  }
}
