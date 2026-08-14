import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/dio_network.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/auth/state/auth_bloc.dart';
import 'package:niya_equb/features/auth/state/auth_event.dart';
import 'package:niya_equb/features/auth/state/auth_state.dart';
import 'package:niya_equb/core/util/phone_input_formatter.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_phone_field.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'otp_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  static const String routeName = '/phone-number';
  final String from;

  const PhoneNumberScreen({super.key, required this.from});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;
  bool isChecking = false;
  final AuthBloc _authBloc = AuthBloc(authRepository: sl<AuthRepository>());

  /// Always read the number through the helper so `09...`, `+251...` and a
  /// bare `9...` all reach the API in the same shape.
  String get _phone => toInternationalPhone(_phoneController.text);

  void _navigateToOtp() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          isChecking = true;
        });
        bool isRegistered = await AuthRepository(
          DioNetwork.appAPI,
        ).isPhoneRegistered(_phone);
        setState(() {
          isChecking = false;
        });

        if (isRegistered && widget.from == 'register') {
          // ignore: use_build_context_synchronously
          showErrorSnackBar(context, "phone_already_registered".tr);
          return;
        }

        if (!isRegistered && widget.from == 'forgot_password') {
          // ignore: use_build_context_synchronously
          showErrorSnackBar(context, "phone_not_registered".tr);
          return;
        }

        _authBloc.add(AuthRequestOtpEvent(phoneNumber: _phone));
      } catch (e) {
        setState(() {
          isChecking = false;
        });
        // ignore: use_build_context_synchronously
        showErrorSnackBar(context, e.toString());
      }
    } else {
      setState(() => _autoValidate = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

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
          title: "phone_number".tr,
          fontSize: 18.sp,
          textColor: appColors.titleTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Centered horizontally
              children: [
                SizedBox(height: 30.h),

                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: appColors.primaryColor!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    widget.from == 'register'
                        ? Icons.person_add_rounded
                        : Icons.lock_reset_rounded,
                    size: 32.sp,
                    color: appColors.primaryColor,
                  ),
                ),

                SizedBox(height: 24.h),

                CustomText(
                  title: widget.from == 'register'
                      ? "create_account_title".tr
                      : "reset_password_title".tr,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  textColor: appColors.titleTextColor,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8.h),

                CustomText(
                  title: widget.from == 'register'
                      ? "enter_phone_register".tr
                      : "enter_phone_reset".tr,
                  fontSize: 13.sp,
                  textColor: appColors.bodyTextSmallColor,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32.h),

                CustomPhoneField(
                  label: "phone_number".tr,
                  controller: _phoneController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "phone_number_required".tr;
                    }
                    if (value.length != 9) {
                      return "phone_9_digits".tr;
                    }
                    return null;
                  },
                ),

                SizedBox(height: 24.h),

                BlocConsumer<AuthBloc, AuthState>(
                  bloc: _authBloc,
                  listener: (context, state) {
                    if (state is AuthRequestOtpSuccess) {
                      // A resend fired from the OTP screen bubbles up to this
                      // still-mounted screen too; without the guard it pushes
                      // a second OTP screen underneath the user.
                      if (!context.isTopRoute) return;

                      context.pushOnce(
                        OtpScreen.routeName,
                        arguments: {
                          'phoneNumber': _phone,
                          'from': widget.from,
                          'verificationId': state.message,
                        },
                      );
                    } else if (state is AuthRequestOtpFailure) {
                      showErrorSnackBar(context, state.failure.errorMessage);
                    }
                  },
                  builder: (context, state) {
                    return RoundedButton(
                      submitting: state is AuthRequestOtpLoading || isChecking,
                      label: "send_code".tr,
                      height: 50.h,
                      backgroundColor: appColors.primaryColor,
                      onPressed: _navigateToOtp,
                    );
                  },
                ),

                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
