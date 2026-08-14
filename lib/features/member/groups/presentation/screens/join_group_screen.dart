import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/member/groups/data/repository/group_equb_repository.dart';
import 'package:niya_equb/features/member/groups/presentation/widgets/group_ledger_widgets.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

/// Enter an invite code, see what you are joining, agree to the terms, then
/// ask the creator for a place. Knowing a code is never enough on its own.
///
/// Deliberately a full screen rather than a bottom sheet: a modal that reads a
/// BlocProvider from the screen underneath is what leaves inherited-widget
/// dependents behind when the route is torn down.
class JoinGroupScreen extends StatefulWidget {
  static const String routeName = '/join-equb-group';

  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
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

  
  final _code = TextEditingController();

  GroupPreview? _preview;
  bool _looking = false;
  bool _sending = false;
  bool _joined = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;

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

    setState(() => _sending = true);

    final result = await sl<GroupEqubRepository>().joinByCode(_code.text.trim());
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
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appColors.scaffoldBackgroundColor,
        elevation: 0,
        title: CustomText(
          title: 'Join a group'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          textColor: appColors.titleTextColor,
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 40.h),
        children: [
          CustomText(
            title: 'Enter the invite code the group creator shared with you.'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            textColor: appColors.bodyTextSmallColor,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _code,
                  label: 'Invite code'.tr,
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
                width: 100.w,
                child: RoundedButton(
                  label: 'Find'.tr,
                  height: 48.h,
                  submitting: _looking,
                  backgroundColor: primary,
                  onPressed: _lookup,
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            SizedBox(height: 16.h),
            _banner(
              context,
              icon: Icons.error_outline_rounded,
              color: const Color(0xFFDC2626),
              text: _error!,
            ),
          ],

          if (_preview != null) ...[
            SizedBox(height: 20.h),
            _groupCard(context, _preview!),

            if (_preview!.alreadyMember || _joined) ...[
              SizedBox(height: 16.h),
              _banner(
                context,
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF16A34A),
                text: _joined
                    ? 'You have joined this group. It is now in My Group Equbs.'
                    : 'You are already a member of this group.',
              ),
              SizedBox(height: 16.h),
              RoundedButton(
                label: 'Done',
                height: 48.h,
                backgroundColor: primary,
                onPressed: () => Get.back(result: true),
              ),
            ] else ...[
              if ((_preview!.termsContent ?? '').trim().isNotEmpty) ...[
                SizedBox(height: 18.h),
                TermsCard(
                  terms: _cleanHtmlText(_preview!.termsContent!),
                  footnote: 'Joining means you accept these terms.',
                ),
              ] else ...[
                SizedBox(height: 18.h),
                _banner(
                  context,
                  icon: Icons.info_outline_rounded,
                  color: primary,
                  text: 'This Equb has no written terms. Ask the creator if you '
                      'are unsure how it works.',
                ),
              ],
              SizedBox(height: 18.h),
              RoundedButton(
                label: 'Accept and join',
                height: 50.h,
                submitting: _sending,
                backgroundColor: primary,
                onPressed: _sendRequest,
              ),
              SizedBox(height: 8.h),
              CustomText(
                title: 'Joining means you accept the terms above. Your first '
                    'contribution is due on the next round.',
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w400,
                centerText: true,
                textColor: appColors.hintTextColor,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _groupCard(BuildContext context, GroupPreview p) {
    final appColors = colors(context);
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    final rows = <(String, String)>[
      if (p.equbName != null) ('Equb', p.equbName!),
      ('Each person, per round', etb(p.contributionPerPerson)),
      ('Every', '${p.frequencyDays} day(s)'),
      ('Members so far', '${p.membersCount}'),
      if (p.roundsTotal > 0) ('Rounds', '${p.roundsTotal}'),
      if (p.ownerName != null) ('Created by', p.ownerName!),
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Icon(Icons.groups_2_rounded, size: 18.r, color: primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      title: p.name,
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w700,
                      textColor: appColors.titleTextColor,
                    ),
                    if ((p.description ?? '').isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      CustomText(
                        title: p.description!,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        textColor: appColors.bodyTextSmallColor,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ...rows.map((r) => Padding(
                padding: EdgeInsets.only(bottom: 9.h),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomText(
                        title: r.$1,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                        textColor: appColors.bodyTextSmallColor,
                      ),
                    ),
                    CustomText(
                      title: r.$2,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      textColor: appColors.titleTextColor,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _banner(BuildContext context,
      {required IconData icon, required Color color, required String text}) {
    return Container(
      padding: EdgeInsets.all(13.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.r, color: color),
          SizedBox(width: 9.w),
          Expanded(
            child: CustomText(
              title: text,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              textColor: color,
            ),
          ),
        ],
      ),
    );
  }
}
