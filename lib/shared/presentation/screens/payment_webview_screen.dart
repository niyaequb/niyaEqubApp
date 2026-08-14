import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// User type for navigating to the correct home (dashboard) after payment.
enum PaymentUserType { member }

/// Chapa payment WebView. On URL containing 'payment-receipt', shows success and navigates to user's dashboard.
class PaymentWebViewScreen extends StatefulWidget {
  static const String routeName = '/payment-webview';

  final String paymentUrl;
  final String title;

  /// User type (member). After payment we navigate to their dashboard.
  final PaymentUserType userType;

  /// If true, pops the screen with success=true on successful payment instead of navigating to home.
  final bool popSuccess;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.userType,
    this.title = "complete_payment",
    this.popSuccess = false,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            logger('WebView Page Finished: $url');
            setState(() => _isLoading = false);
            logger(url);

            // Check for success keywords, but ensure it's not the initial initiate URL
            final isSuccess =
                (url.contains('payment-receipt') ||
                    url.contains("admin/login") ||
                    url.contains('checkout/payment-receipt')) &&
                url != widget.paymentUrl;

            if (isSuccess) {
              if (mounted) _handleReturn(success: true);
            }
          },
          onPageStarted: (_) => setState(() => _isLoading = true),
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handleReturn({bool success = false}) async {
    if (!mounted) return;

    if (success) {
      logger('WebView: Success detected. Waiting 2.5s...');
      // 2.5s delay so user can see the "Success" screen from provider
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
    }

    logger('WebView: Returning with success=$success');

    // Load about:blank and hide keyboard to force iOS to drop the accessory bar
    _controller.loadRequest(Uri.parse('about:blank'));
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        if (!mounted) return;
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
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
