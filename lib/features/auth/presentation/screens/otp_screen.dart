import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:niya_equb/features/auth/presentation/screens/forgot_password_screen.dart'; // Import this
import 'package:niya_equb/features/auth/state/auth_bloc.dart';
import 'package:niya_equb/features/auth/state/auth_event.dart';
import 'package:niya_equb/features/auth/state/auth_state.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class OtpScreen extends StatefulWidget {
  static const String routeName = '/otp';
  final String phoneNumber;
  final String from;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.from,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Use sl() directly or provide from parent widget
  final AuthBloc _authBloc = AuthBloc(authRepository: sl<AuthRepository>());
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) controller.dispose();
    for (var node in _focusNodes) node.dispose();
    _authBloc.close(); // Important: Close the bloc
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appColors.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: CustomText(
          title: "otp_verification".tr,
          fontSize: 18.sp,
          textColor: appColors.titleTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 30.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: appColors.primaryColor!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 32.sp,
                  color: appColors.primaryColor,
                ),
              ),
              SizedBox(height: 24.h),
              CustomText(
                title: "verify_code".tr,
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                textColor: appColors.titleTextColor,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: appColors.bodyTextSmallColor,
                  ),
                  children: [
                    TextSpan(text: "otp_sent_to".tr),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: appColors.titleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (index) => _buildOtpBox(index, appColors, isDark),
                ),
              ),
              SizedBox(height: 32.h),

              BlocConsumer<AuthBloc, AuthState>(
                bloc: _authBloc,
                listener: (context, state) {
                  if (state is AuthVerifyOtpFailure) {
                    showErrorSnackBar(context, state.failure.errorMessage);
                  }
                  if (state is AuthRequestOtpFailure) {
                    showErrorSnackBar(context, state.failure.errorMessage);
                  }
                  if (state is AuthRequestOtpSuccess) {
                    showSuccessSnackBar(context, "otp_sent_successfully".tr);
                  }
                  if (state is AuthVerifyOtpSuccess) {
                    // Only navigate if this screen is still the one on top.
                    // Without the guard a second verify (or a rebuild while
                    // CompleteProfile is already open) pushes a duplicate,
                    // and backing out of it looks like the app jumped
                    // backwards on its own.
                    if (!context.isTopRoute) return;

                    showSuccessSnackBar(context, "verified_successfully".tr);

                    context.pushOnce(
                      widget.from == 'register'
                          ? CompleteProfileScreen.routeName
                          : ForgotPasswordScreen.routeName,
                      arguments: {'phoneNumber': widget.phoneNumber},
                    );
                  }
                },
                builder: (context, state) {
                  return RoundedButton(
                    submitting: state is AuthVerifyOtpLoading,
                    label: "verify_code_btn".tr,
                    height: 48.h,
                    backgroundColor: appColors.primaryColor,
                    onPressed: () {
                      String otp = _controllers.map((e) => e.text).join();
                      if (otp.length == 4) {
                        _authBloc.add(
                          AuthVerifyOtpEvent(
                            phoneNumber: widget.phoneNumber,
                            otp: otp,
                            verificationId: widget.verificationId,
                          ),
                        );
                      } else {
                        showErrorSnackBar(context, "enter_4_digit_code".tr);
                      }
                    },
                  );
                },
              ),

              SizedBox(height: 24.h),
              BlocBuilder<AuthBloc, AuthState>(
                bloc: _authBloc,
                builder: (context, state) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomText(
                        title: "didnt_receive_code".tr,
                        fontSize: 14.sp,
                        textColor: appColors.bodyTextSmallColor,
                      ),
                      SizedBox(width: 4.w),
                      if (state is AuthRequestOtpLoading)
                        SizedBox(
                          height: 16.r,
                          width: 16.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              appColors.primaryColor!,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            _authBloc.add(
                              AuthRequestOtpEvent(
                                phoneNumber: widget.phoneNumber,
                              ),
                            );
                          },
                          child: CustomText(
                            title: "resend".tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            textColor: appColors.primaryColor,
                          ),
                        ),
                    ],
                  );
                },
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, dynamic appColors, bool isDark) {
    return SizedBox(
      height: 60.h,
      width: 60.w,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.bold,
          color: appColors.titleTextColor,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: (value) {
          if (value.isNotEmpty && index < 3)
            _focusNodes[index + 1].requestFocus();
          if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
        },
        decoration: InputDecoration(
          filled: isDark,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF38434F)
                  : appColors.primaryColor!.withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: appColors.primaryColor!, width: 2),
          ),
        ),
      ),
    );
  }
}
