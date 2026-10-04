// Payment authorisation.
//
// ============================================================================
// WHY THERE IS NO WEBVIEW IN A FILE CALLED payment_webview_screen.dart
// ============================================================================
//
// The name is historical and the path is load-bearing: MiniApp/sync.ps1 mirrors
// this tree by path and web_overrides/patches.json addresses files by path too,
// so renaming it would mean touching the sync machinery for no functional gain.
// Renaming is worth doing one day; it was not worth doing in the same change as
// a payment migration.
//
// What changed is everything inside. The old gateway was a hosted checkout: the
// server handed back a URL, mobile loaded it in a WebView and watched the
// address bar for 'payment-receipt'. The bank integrations have no such page.
// The order is authorised inside the bank's own app, from a payload the server
// signed, over a bridge — so there is nothing to load and nothing to watch.
//
// ============================================================================
// THIS SCREEN KNOWS NO BANK NAMES
// ============================================================================
//
// Niya collects through Dashen today and CBE, Awash and others soon. Nothing
// here changes when one is added: the session carries a descriptor saying which
// host app to talk to, PaymentBridges turns that into a bridge, and the bank's
// own name is read from the descriptor for anything shown to a member.
//
// ============================================================================
// ONE SCREEN, BOTH PLATFORMS
// ============================================================================
//
// This file used to have a web override, because a WebView cannot exist in a
// browser. It no longer needs one: the platform difference now lives entirely
// in PaymentBridge, which reports `isAvailable` and returns a
// PaymentAuthorisation on both. That is a better seam — the difference is "can
// this device reach the bank", which is a service question, not a UI one.
//
// On a phone `isAvailable` is false, because these bridges only exist inside
// the banks' own apps. The screen says so plainly and sends the member there,
// rather than showing a control that cannot work.
//
// ============================================================================
// THE RESULT IS NOT A CLAIM ABOUT MONEY
// ============================================================================
//
// Popping `true` means "go and re-read this contribution from the server", not
// "this was paid". It never meant more than that — even on mobile, a URL
// containing 'payment-receipt' was a client-side guess — but now it is
// explicit: the documented callbacks carry no status at all. The backend marks
// a contribution paid on a verified settlement notification and on nothing
// else, and every caller already refetches after this screen returns.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/service/payments/payment_bridge.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';

/// User type for navigating to the correct home (dashboard) after payment.
enum PaymentUserType { member }

class PaymentWebViewScreen extends StatefulWidget {
  static const String routeName = '/payment-webview';

  /// The signed order, straight from the server. Passed to the bank untouched
  /// — see PaymentSession.
  final PaymentSession session;

  final String title;
  final PaymentUserType userType;
  final bool popSuccess;

  const PaymentWebViewScreen({
    super.key,
    required this.session,
    required this.userType,
    this.title = "complete_payment",
    this.popSuccess = false,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final PaymentBridge _bridge;

  bool _inFlight = false;
  PaymentAuthorisation? _result;

  /// The bank's own name, for anything a member reads. Falls back to a neutral
  /// phrase rather than a slug — "pay in the dashen app" is not something to
  /// put in front of a customer.
  String get _bankName {
    final name = widget.session.client?.name ?? '';
    return name.isNotEmpty ? name : 'bank_generic'.tr;
  }

  @override
  void initState() {
    super.initState();

    _bridge = PaymentBridges.of(widget.session.client);

    // Presented automatically on arrival so the flow reads the way it always
    // has: tap Pay, get asked to approve. Where there is no bridge there is
    // nothing to present, and the build below explains why instead.
    if (_bridge.isAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authorise());
    }
  }

  Future<void> _authorise() async {
    if (_inFlight) return;
    setState(() {
      _inFlight = true;
      _result = null;
    });

    final result = await _bridge.authorise(
      orderPayload: widget.session.orderPayload,
      authPayload: widget.session.authPayload,
    );

    logger(
      'Payment ${widget.session.reference} via ${widget.session.provider}: '
      '${result.outcome}',
    );

    if (!mounted) return;

    setState(() {
      _inFlight = false;
      _result = result;
    });

    // A completed authorisation is the one case worth leaving on immediately —
    // the member has done their part and the previous screen refetches.
    // Anything else stays put so they can read what happened and retry without
    // losing the order.
    if (result.shouldRefetch) {
      _handleReturn(success: true);
    }
  }

  /// Pops with the caller's expected bool.
  void _handleReturn({bool success = false}) {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final unavailable = !_bridge.isAvailable;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleReturn(success: false);
      },
      child: Scaffold(
        backgroundColor: appColors.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: appColors.titleTextColor,
              size: 24.sp,
            ),
            onPressed: () => _handleReturn(success: false),
          ),
          centerTitle: true,
          title: CustomText(
            title: widget.title.tr,
            fontSize: 18.sp,
            textColor: appColors.titleTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 24.h),
                Icon(
                  unavailable
                      ? Icons.phonelink_off_rounded
                      : Icons.lock_outline_rounded,
                  size: 44.sp,
                  color: appColors.titleTextColor,
                ),
                SizedBox(height: 16.h),
                CustomText(
                  // The bank's name is interpolated into the translated string
                  // rather than concatenated onto it, so Amharic and Oromo can
                  // put it where their grammar needs it.
                  title: unavailable
                      ? 'payment_unavailable_title'.trParams({'bank': _bankName})
                      : (_inFlight
                            ? 'payment_waiting'.trParams({'bank': _bankName})
                            : 'payment_confirm_in_bank_app'.trParams({
                                'bank': _bankName,
                              })),
                  fontSize: 17.sp,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.titleTextColor,
                ),
                SizedBox(height: 10.h),
                CustomText(
                  title: unavailable
                      ? 'payment_unavailable_body'.trParams({'bank': _bankName})
                      : 'payment_bank_app_hint'.trParams({'bank': _bankName}),
                  fontSize: 13.sp,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  // ?. because AppColors fields are all nullable Color? and
                  // withValues cannot be called on a potentially-null Color.
                  textColor: appColors.titleTextColor?.withValues(alpha: 0.65),
                ),

                // Shown only for an attempt that came back without success. A
                // cancellation is the member's own choice and does not need to
                // be reported back to them as a problem.
                if (_result != null &&
                    _result!.outcome == PaymentOutcome.failed) ...[
                  SizedBox(height: 14.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB01F2E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: CustomText(
                      title: 'payment_not_confirmed'.tr,
                      fontSize: 12.sp,
                      maxLines: 4,
                      textAlign: TextAlign.center,
                      textColor: const Color(0xFFB01F2E),
                    ),
                  ),
                ],

                const Spacer(),

                if (_inFlight)
                  const Center(child: CircularProgressIndicator())
                else if (!unavailable)
                  OutlinedButton.icon(
                    onPressed: _authorise,
                    icon: Icon(Icons.refresh_rounded, size: 18.sp),
                    label: Text('payment_try_again'.tr),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(48.h),
                    ),
                  ),

                SizedBox(height: 10.h),

                // Note what this claims: the member is telling the app to go
                // and check, not asserting a result. Offered even where the
                // bridge is missing, because a member who paid from the bank's
                // app on another device still wants the app to look.
                FilledButton(
                  onPressed: () => _handleReturn(success: true),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(50.h),
                  ),
                  child: Text('payment_done_check'.tr),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () => _handleReturn(success: false),
                  child: Text('cancel'.tr),
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
