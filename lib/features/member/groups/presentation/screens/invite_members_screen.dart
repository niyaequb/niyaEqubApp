import 'dart:async';

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

/// Look people up by their exact phone number and build an invite list.
/// Numbers that are not on Niya yet are invited by SMS.
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

  final _members = <MemberLookupResult>[];
  final _phones = <String>[];

  List<MemberLookupResult> _results = [];
  bool _searching = false;
  bool _searched = false;
  String? _searchError;
  Timer? _debounce;
  bool _sending = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  /// Same behaviour as the create screen: search from the first character,
  /// debounced, matching on name or phone in any format.
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

    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(term));
  }

  Future<void> _runSearch(String term) async {
    if (!mounted) return;
    setState(() => _searching = true);

    final looksLikePhone = RegExp(r'^[0-9+]{2,}$').hasMatch(term);
    final query = looksLikePhone ? normalizeEthiopianPhone(term) : term;

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
            .where((m) => !_members.any((p) => p.memberId == m.memberId))
            .toList();
      }),
    );
  }

  void _add(MemberLookupResult member) {
    setState(() {
      _members.add(member);
      _results = [];
      _searched = false;
      _phone.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addRawPhone() {
    final normalised = normalizeEthiopianPhone(_phone.text.trim());
    if (normalised.length < 9 || _phones.contains(normalised)) return;

    setState(() {
      _phones.add(normalised);
      _phone.clear();
      _results = [];
      _searched = false;
    });
  }

  Future<void> _send() async {
    if (_members.isEmpty && _phones.isEmpty) return;

    setState(() => _sending = true);

    final result = await sl<GroupEqubRepository>().invite(
      widget.groupId,
      memberIds: _members.map((m) => m.memberId).toList(),
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
    final total = _members.length + _phones.length;

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
            title: 'Add by name or phone number',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 4.h),
          CustomText(
            title: 'Results appear as you type. A number that is not on Niya can still be invited by SMS.',
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
                  label: 'Name or 09xxxxxxxx',
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
                ),
            ],
          ),
          if (_results.isNotEmpty)
            _resultsList(context)
          else if (_searched && !_searching)
            _noResults(context),
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
            ..._members.map((m) => _chipRow(
                  context,
                  title: m.name,
                  subtitle: m.phone ?? '',
                  badge: 'On Niya',
                  badgeColor: const Color(0xFF16A34A),
                  onRemove: () => setState(() => _members.remove(m)),
                )),
            ..._phones.map((p) => _chipRow(
                  context,
                  title: p,
                  subtitle: 'Will receive an SMS invite',
                  badge: 'New',
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

  /// Tap-to-add search results.
  Widget _resultsList(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: (appColors.borderColor ?? AppStaticColor.borderLight).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: _results.take(6).map((m) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16.r,
              backgroundColor: primary.withValues(alpha: 0.14),
              child: CustomText(
                title: m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                textColor: primary,
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
            trailing: Icon(Icons.add_circle_outline_rounded, size: 20.r, color: primary),
            onTap: () => _add(m),
          );
        }).toList(),
      ),
    );
  }

  /// Nothing matched: offer an SMS invite when it looks like a number.
  Widget _noResults(BuildContext context) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final typed = _phone.text.trim();
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
                      ? 'Not on Niya yet. Tap Invite to send an SMS.'
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
