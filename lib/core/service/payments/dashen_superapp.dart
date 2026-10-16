import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:url_launcher/url_launcher.dart';

/// Getting a member from the Niya phone app to the Dashen SuperApp.
///
/// Equb contributions are paid inside the Dashen SuperApp, where Niya runs as
/// a mini app. This standalone app has no bank to hand an order to (see
/// payment_bridge.dart), so "Pay" here means: open the SuperApp if it is on
/// the phone, and its store page if it is not.
class DashenSuperApp {
  DashenSuperApp._();

  static const String androidPackage = 'com.dashen.dashensuperapp';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';

  static const String appStoreUrl =
      'https://apps.apple.com/us/app/dashen-superapp/id6670182870';

  /// Link schemes the SuperApp may answer to on an iPhone, without "://",
  /// most specific first.
  ///
  /// Dashen have not published theirs, so the likely ones are tried in turn.
  /// Opening a scheme no app has registered fails silently and costs nothing,
  /// and none of these is generic enough to belong to another app (plain
  /// "dashen" is left out on purpose: the bank's older apps may answer to it,
  /// and Pay must not open the wrong one). When Dashen confirm the real
  /// scheme, put it first here AND under LSApplicationQueriesSchemes in
  /// ios/Runner/Info.plist — the list there is what lets [isInstalled] see
  /// the app; opening works without it.
  static const List<String> iosUrlSchemes = [
    'dashensuperapp',
    'com.dashen.dashensuperapp',
    'dashensuper',
  ];

  /// The SuperApp's own web address.
  ///
  /// Tried first on both platforms, as a universal link / app link only
  /// ([LaunchMode.externalNonBrowserApplication]): if the installed SuperApp
  /// claims it, the phone goes straight into the app; if not, NOTHING opens —
  /// no browser tab — and the next way is tried.
  static const String appLink = 'https://www.dashensuperapp.com/download';

  /// Implemented in android/app/src/main/kotlin/com/niyaet/ekub/MainActivity.kt.
  /// Android 11 and later only let it see the SuperApp because of the
  /// `<queries>` entry in AndroidManifest.xml.
  static const MethodChannel _channel = MethodChannel(
    'com.niyaet.ekub/external_apps',
  );

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether the SuperApp is installed: true, false, or null when this phone
  /// cannot tell.
  ///
  /// An iPhone can only answer "yes": it sees the schemes listed in
  /// Info.plist and no others, so finding none of them means "not known",
  /// never "not installed" — the SuperApp may answer to a scheme not listed.
  static Future<bool?> isInstalled() async {
    try {
      if (_isAndroid) {
        return await _channel.invokeMethod<bool>(
              'isInstalled',
              {'package': androidPackage},
            ) ??
            false;
      }
      if (_isIOS) {
        for (final scheme in iosUrlSchemes) {
          if (await canLaunchUrl(Uri.parse('$scheme://'))) return true;
        }
      }
    } catch (e) {
      logger('DashenSuperApp.isInstalled: $e');
    }
    return null;
  }

  /// Opens the SuperApp itself whenever it is on the phone, and its store
  /// page only when it is not.
  ///
  /// In order: Android's launcher entry for the package; the SuperApp's own
  /// web address as an app link; each iPhone link scheme; the store. Every
  /// step that does not apply fails silently, so the member never sees a
  /// browser tab or an error on the way to the right place.
  ///
  /// Returns false only when nothing at all could be opened.
  static Future<bool> openOrInstall() async {
    if (_isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'open',
          {'package': androidPackage},
        );
        if (opened == true) return true;
      } catch (e) {
        logger('DashenSuperApp.open: $e');
      }
    }

    if (_isAndroid || _isIOS) {
      if (await _launch(
        appLink,
        mode: LaunchMode.externalNonBrowserApplication,
      )) {
        return true;
      }
    }

    if (_isIOS) {
      for (final scheme in iosUrlSchemes) {
        if (await _launch('$scheme://')) return true;
      }
    }

    return openStore();
  }

  /// The SuperApp's page in this phone's app store.
  static Future<bool> openStore() async {
    if (_isAndroid) {
      // Straight into the Play Store app; the web page is the fallback for a
      // phone without it.
      if (await _launch('market://details?id=$androidPackage')) return true;
      return _launch(playStoreUrl);
    }
    if (_isIOS) {
      return _launch(appStoreUrl);
    }
    return _launch(
      defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl,
    );
  }

  static Future<bool> _launch(
    String url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      return await launchUrl(Uri.parse(url), mode: mode);
    } catch (e) {
      logger('DashenSuperApp: could not open $url: $e');
      return false;
    }
  }
}

/// [key] translated, or [english] while a language file does not have it
/// yet, so the sheet never shows a raw key.
String _tr(String key, String english) {
  final value = key.tr;
  return value == key ? english : value;
}

/// The sheet shown when a member taps Pay in the phone app.
///
/// Says plainly where the payment happens, shows what they are about to pay
/// and for which day, walks through the three steps, and offers one button
/// that does the right thing for this phone: open the SuperApp, or get it.
///
/// [onReturn] runs once, the next time the member comes back to this app,
/// so a payment made in the SuperApp shows up without a manual refresh.
Future<void> showDashenPaySheet(
  BuildContext context, {
  required double amount,
  required DateTime day,
  VoidCallback? onReturn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _DashenPaySheet(
      amount: amount,
      day: day,
      onReturn: onReturn,
    ),
  );
}

class _DashenPaySheet extends StatefulWidget {
  final double amount;
  final DateTime day;
  final VoidCallback? onReturn;

  const _DashenPaySheet({
    required this.amount,
    required this.day,
    this.onReturn,
  });

  @override
  State<_DashenPaySheet> createState() => _DashenPaySheetState();
}

class _DashenPaySheetState extends State<_DashenPaySheet> {
  /// Dashen Bank's navy, for the parts of the sheet that are about the bank.
  static const Color _dashen = Color(0xFF14306B);

  late final Future<bool?> _installed = DashenSuperApp.isInstalled();

  bool _opening = false;

  Future<void> _go() async {
    if (_opening) return;
    setState(() => _opening = true);

    final opened = await DashenSuperApp.openOrInstall();

    if (!mounted) return;
    setState(() => _opening = false);

    if (!opened) {
      Get.rawSnackbar(
        message: _tr('dashen_open_failed', 'Could not open the Dashen SuperApp. Please open it yourself.'),
        backgroundColor: NiyaPalette.danger,
      );
      return;
    }

    final onReturn = widget.onReturn;
    if (onReturn != null) {
      late final AppLifecycleListener listener;
      listener = AppLifecycleListener(
        onResume: () {
          listener.dispose();
          onReturn();
        },
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = appColors.primaryColor ?? Colors.amber;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final money = NumberFormat('#,##0.##');

    // The navy itself disappears on a dark background; the steps use a
    // lighter shade of it there.
    final accent = isDark ? const Color(0xFF8FB0F2) : _dashen;

    return Container(
      decoration: BoxDecoration(
        color: appColors.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // Who takes the payment.
              Row(
                children: [
                  Container(
                    width: 52.r,
                    height: 52.r,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_dashen, Color(0xFF2A4F9E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 26.r,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          title: _tr('dashen_pay_title', 'Pay with Dashen SuperApp'),
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          textColor: appColors.titleTextColor,
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 13.sp,
                              color: niya(context).success,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: CustomText(
                                title: _tr('dashen_pay_secure', 'Paid securely through Dashen Bank'),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w500,
                                textColor: appColors.bodyTextSmallColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // What they are paying.
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: primary.withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            title: _tr('dashen_pay_amount_due', 'Amount due'),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            textColor: appColors.bodyTextSmallColor,
                          ),
                          SizedBox(height: 4.h),
                          CustomText(
                            title: '${money.format(widget.amount)} ETB',
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            textColor: appColors.titleTextColor,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.accentColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 14.sp,
                            color: primary,
                          ),
                          SizedBox(width: 6.w),
                          CustomText(
                            title: DateFormat('MMM d, yyyy').format(widget.day),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            textColor: appColors.titleTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),

              // How.
              _Step(number: 1, text: _tr('dashen_pay_step1', 'Open the Dashen SuperApp'), accent: accent),
              _Step(number: 2, text: _tr('dashen_pay_step2', 'Open Niya Umrah Equb from its mini apps'), accent: accent),
              _Step(number: 3, text: _tr('dashen_pay_step3', 'Pay for this date there. It shows here once Dashen confirms it.'), accent: accent),
              SizedBox(height: 14.h),

              // One button, labelled for what it will actually do.
              FutureBuilder<bool?>(
                future: _installed,
                builder: (context, snapshot) {
                  final installed = snapshot.data;
                  final String label;
                  final IconData icon;

                  // "Open" unless the phone has said for certain the app is
                  // not there (only Android can). An iPhone that cannot tell
                  // still tries the app first; the store is the fallback, not
                  // the first stop it used to be.
                  if (installed == false) {
                    label = isIOS
                        ? _tr('dashen_get_app_store', 'Download on the App Store')
                        : _tr('dashen_get_play_store', 'Get it on Google Play');
                    icon = Icons.download_rounded;
                  } else {
                    label = _tr('dashen_open_app', 'Open Dashen SuperApp');
                    icon = Icons.open_in_new_rounded;
                  }

                  return RoundedButton(
                    label: label,
                    onPressed: _go,
                    submitting: _opening,
                    backgroundColor: _dashen,
                    foregroundColor: Colors.white,
                    height: 52.h,
                    borderRadius: 16.r,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    icon: Icon(icon, color: Colors.white, size: 18.sp),
                  );
                },
              ),
              SizedBox(height: 6.h),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: CustomText(
                  title: _tr('dashen_not_now', 'Not now'),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  final Color accent;

  const _Step({required this.number, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.r,
            height: 24.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: CustomText(
              title: '$number',
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              textColor: accent,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3.h),
              child: CustomText(
                title: text,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
                textColor: appColors.bodyTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
