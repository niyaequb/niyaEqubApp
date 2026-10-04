import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/app_assets.dart';
import 'package:niya_equb/core/service/app_update_service.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

/// The update prompt, laid out the way the store's own one is.
///
/// A bottom sheet: it arrives from the edge instead of covering the screen, it
/// can hold a real "What's new" list without becoming a wall of text, and its
/// primary action sits under the thumb. The shape deliberately echoes the
/// Google Play update sheet — store line, headline, app row with its name and
/// details, a collapsible changelog, and two buttons — because that is the
/// dialog people already know how to read.
///
/// TWO MODES, ONE WIDGET
///
///   optional — dismissible. Close button, "Not now", tap outside, back.
///   forced   — none of those. No close button, no barrier dismiss, no back,
///              and a line explaining why. See AppUpdateService for who
///              decides which.
///
/// Nothing here decides whether to show itself. That is checkForPrompt()'s
/// job, so the "how often do we nag" rules live in one place next to the
/// state they read.
Future<void> showAppUpdateSheet(BuildContext context, AppUpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    // Above everything, including any screen pushed onto a nested navigator.
    // A blocking update that a route can slide over is not blocking.
    useRootNavigator: true,
    isScrollControlled: true,
    // A forced update has nothing behind it worth tapping through to.
    isDismissible: !info.forceUpdate,
    enableDrag: !info.forceUpdate,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _AppUpdateSheet(info: info),
  );
}

class _AppUpdateSheet extends StatefulWidget {
  final AppUpdateInfo info;

  const _AppUpdateSheet({required this.info});

  @override
  State<_AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<_AppUpdateSheet> {
  bool _opening = false;
  bool _expanded = false;
  String? _error;

  AppUpdateInfo get info => widget.info;

  bool get forced => info.forceUpdate;

  /// The primary action.
  ///
  /// When Play offered its own in-app flow, that is what runs: Play downloads
  /// and installs the update and restarts the app, without anyone ever seeing
  /// a listing page. It is the better experience, it is the one people
  /// recognise, and it is the only path that cannot end with someone stranded
  /// on a store page wondering what they were meant to tap.
  ///
  /// Everything else falls back to opening the listing.
  Future<void> _startUpdate() async {
    setState(() {
      _opening = true;
      _error = null;
    });

    HapticFeedback.selectionClick();

    if (info.canUsePlayFlow) {
      final started = await sl<AppUpdateService>().startPlayUpdate();
      if (!mounted) return;

      if (started) {
        setState(() => _opening = false);
        return;
      }
      // Play declined or the user backed out of its dialog. The listing is
      // still a valid way through, so carry on rather than dead-ending.
    }

    await _openListing(alreadyBusy: true);
  }

  /// Opens the store listing in the store app.
  Future<void> _openListing({bool alreadyBusy = false}) async {
    final url = info.storeUrl;

    if (url == null || url.isEmpty) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = 'update_store_failed'.trParams({'store': info.storeName});
      });
      return;
    }

    if (!alreadyBusy) {
      setState(() {
        _opening = true;
        _error = null;
      });
      HapticFeedback.selectionClick();
    }

    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(url),
        // The store app, not a browser tab inside our own app.
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!mounted) return;

    setState(() {
      _opening = false;
      // The store app can be missing, disabled, or blocked by a work profile.
      // Saying so beats a button that quietly does nothing — especially on a
      // forced update, where this sheet is the only thing on screen.
      _error = launched
          ? null
          : 'update_store_failed'.trParams({'store': info.storeName});
    });
  }

  Future<void> _notNow() async {
    // Remember the exact release, not "don't ask again": 1.0.3 should still
    // prompt after 1.0.2 was skipped.
    await sl<AppUpdateService>().skip(info.releaseKey);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final surface =
        appColors.scaffoldBackgroundColor ?? Theme.of(context).canvasColor;

    // Back button is part of "dismissible" too — without this, Android's
    // system back would walk straight past a forced update.
    return PopScope(
      canPop: !forced,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 20.h, 22.w, 14.h),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _storeLine(appColors),
                  SizedBox(height: 20.h),
                  _headline(appColors),
                  SizedBox(height: 10.h),
                  _body(appColors),
                  SizedBox(height: 20.h),
                  _appRow(appColors),
                  if (info.releaseNotes.isNotEmpty || info.releasedAt != null)
                    _whatsNew(appColors),
                  if (_error != null) _errorNote(),
                  SizedBox(height: 22.h),
                  _actions(appColors),
                  if (!forced) ...[SizedBox(height: 4.h), _dismissHint()],
                  SizedBox(height: 6.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Google Play" / "App Store", so it is obvious where the update comes
  /// from and that this is not a third party asking for something.
  Widget _storeLine(AppColors appColors) {
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Row(
      children: [
        Container(
          height: 30.r,
          width: 30.r,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9.r),
          ),
          alignment: Alignment.center,
          child: Icon(
            Platform.isIOS ? Icons.apple : Icons.storefront_rounded,
            size: 17.r,
            color: primary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: CustomText(
            title: info.storeName,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            textColor: appColors.titleTextColor,
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
          ),
        ),
        // No way out of a forced update, so no button that pretends there is.
        if (!forced)
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(
                Icons.close_rounded,
                size: 22.r,
                color: appColors.bodyTextSmallColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _headline(AppColors appColors) {
    return CustomText(
      title: forced ? 'update_required_title'.tr : 'update_available_title'.tr,
      fontSize: 21.sp,
      fontWeight: FontWeight.w700,
      textColor: appColors.titleTextColor,
    );
  }

  Widget _body(AppColors appColors) {
    return CustomText(
      title: forced ? 'update_required_body'.tr : 'update_available_body'.tr,
      fontSize: 13.sp,
      fontWeight: FontWeight.w400,
      textColor: appColors.bodyTextSmallColor,
    );
  }

  /// The app being updated: icon, name, and whatever the store actually said
  /// about the release. Nothing here is invented — a detail the store did not
  /// publish is left out rather than guessed at.
  Widget _appRow(AppColors appColors) {
    final latest = info.prettyLatestVersion;

    final details = <String>[
      // Play's update API reports a build number, not a version name, so a
      // Play-only answer has a real update with no number to print. Saying so
      // is better than showing a blank or, worse, a wrong number.
      latest == null
          ? 'update_new_version_generic'.tr
          : 'update_new_version'.trParams({'version': latest}),
      if (info.rating != null && info.rating! > 0)
        '${info.rating!.toStringAsFixed(1)} ★',
      if (info.prettySize != null) info.prettySize!,
      if ((info.contentRating ?? '').isNotEmpty)
        'update_rated'.trParams({'rating': info.contentRating!}),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _appIcon(appColors),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomText(
                title: info.appName,
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w600,
                textColor: appColors.titleTextColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 5.h),
              CustomText(
                title: details.join('  ·  '),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                textColor: appColors.bodyTextSmallColor,
                maxLines: 2,
                textOverflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              // Both versions, always. "Update available" on its own tells
              // someone nothing about whether they are one release behind or
              // ten.
              CustomText(
                title: 'update_your_version'.trParams({
                  'current': info.prettyCurrentVersion,
                }),
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                textColor: appColors.hintTextColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appIcon(AppColors appColors) {
    final size = 52.r;
    final radius = BorderRadius.circular(13.r);
    final url = info.iconUrl;

    // Apple publishes the listing artwork; Play does not, so the bundled logo
    // stands in. Either way the network image falls back rather than showing
    // a broken box.
    final image = (url != null && url.startsWith('http'))
        ? Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _bundledIcon(size),
          )
        : _bundledIcon(size);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: (appColors.borderColor ?? AppStaticColor.borderLight)
              .withValues(alpha: 0.8),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  Widget _bundledIcon(double size) {
    return Image.asset(
      ImagesAssets.logo,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }

  /// Collapsed by default, exactly like the store's own sheet: the changelog
  /// is there for whoever wants it and out of the way of everyone else, and
  /// it can never push the Update button off a small screen.
  Widget _whatsNew(AppColors appColors) {
    final notes = info.releaseNotes;
    final released = info.releasedAt;

    return Padding(
      padding: EdgeInsets.only(top: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: (appColors.borderColor ?? AppStaticColor.borderLight)
                .withValues(alpha: 0.7),
          ),
          InkWell(
            onTap: notes.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          title: 'whats_new'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          textColor: appColors.titleTextColor,
                        ),
                        if (released != null) ...[
                          SizedBox(height: 3.h),
                          CustomText(
                            title: 'update_last_updated'.trParams({
                              'date': _formatDate(released),
                            }),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            textColor: appColors.hintTextColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (notes.isNotEmpty)
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 24.r,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _notesList(appColors, notes),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _notesList(AppColors appColors, List<String> notes) {
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Capped so a long changelog cannot turn the sheet into a document.
        // The point of the list is to justify the tap, not to be the full
        // release history.
        children: notes
            .take(6)
            .map(
              (note) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Container(
                        width: 5.r,
                        height: 5.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: CustomText(
                        title: note,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w400,
                        textColor: appColors.bodyTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _errorNote() {
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: AppStaticColor.errorRed.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(
              title: _error!,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              textColor: AppStaticColor.errorRed,
            ),
            if ((info.storeUrl ?? '').isNotEmpty) ...[
              SizedBox(height: 6.h),
              SelectableText(
                info.storeUrl!,
                style: TextStyle(fontSize: 10.5.sp, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Two buttons, side by side, the way the store lays them out.
  ///
  /// The secondary one is never a dead end. On an optional update it is
  /// "Not now"; on a forced one it opens the listing, because a screen with a
  /// single button and no explanation is where support tickets come from.
  Widget _actions(AppColors appColors) {
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final outlineColor = appColors.borderColor ?? AppStaticColor.borderLight;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48.h,
            child: OutlinedButton(
              onPressed: _opening
                  ? null
                  : (forced ? () => _openListing() : _notNow),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: outlineColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: CustomText(
                title: forced
                    ? 'update_learn_more'.tr
                    : 'update_not_now'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                textColor: appColors.bodyTextColor,
                maxLines: 1,
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: SizedBox(
            height: 48.h,
            child: ElevatedButton(
              onPressed: _opening ? null : _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: _opening
                  ? SizedBox(
                      height: 18.r,
                      width: 18.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : CustomText(
                      title: 'update_action'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      textColor: Colors.white,
                      maxLines: 1,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// One quiet line so an optional prompt never feels like a trap.
  Widget _dismissHint() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: CustomText(
          title: 'update_optional_hint'.tr,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w400,
          textColor: colors(context).hintTextColor,
          centerText: true,
        ),
      ),
    );
  }

  /// Dates come from Apple as an ISO timestamp and from Play as a parsed
  /// listing date. Either way this is decoration, so a locale intl has never
  /// heard of must not throw on the way to a blocking screen.
  String _formatDate(DateTime date) {
    try {
      return DateFormat.yMMMd().format(date);
    } catch (_) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
  }
}
