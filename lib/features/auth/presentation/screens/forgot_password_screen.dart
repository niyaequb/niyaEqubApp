import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/auth/state/auth_bloc.dart';
import 'package:niya_equb/features/auth/state/auth_event.dart';
import 'package:niya_equb/features/auth/state/auth_state.dart';
import 'package:niya_equb/features/member/main/presentation/screens/ekub_main_screen.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const String routeName = '/forgot-password';
  final String phoneNumber;

  const ForgotPasswordScreen({super.key, required this.phoneNumber});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthBloc _authBloc = AuthBloc(authRepository: sl<AuthRepository>());

  bool _autoValidate = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    if (_formKey.currentState!.validate()) {
      _authBloc.add(
        AuthResetPasswordEvent(
          phone: widget.phoneNumber,
          newPassword: _passwordController.text,
        ),
      );
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
          title: "reset_password_title".tr,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20.h),

                // Icon Representation
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: appColors.primaryColor!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.lock_open_rounded,
                    size: 32.sp,
                    color: appColors.primaryColor,
                  ),
                ),

                SizedBox(height: 24.h),

                CustomText(
                  title: "set_new_password".tr,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  textColor: appColors.titleTextColor,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8.h),

                CustomText(
                  title: "account_linked_to".trParams({'s': widget.phoneNumber}),
                  fontSize: 13.sp,
                  textColor: appColors.bodyTextSmallColor,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32.h),

                // Password Field
                _buildPasswordField(
                  controller: _passwordController,
                  label: "new_password".tr,
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  appColors: appColors,
                ),

                SizedBox(height: 16.h),

                // Confirm Password Field
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: "confirm_new_password".tr,
                  obscure: _obscureConfirmPassword,
                  onToggle: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  appColors: appColors,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "confirm_password_required".tr;
                    if (value != _passwordController.text)
                      return "passwords_dont_match".tr;
                    return null;
                  },
                ),

                SizedBox(height: 32.h),

                BlocConsumer<AuthBloc, AuthState>(
                  bloc: _authBloc,
                  listener: (context, state) {
                    if (state is AuthResetPasswordFailure) {
                      showErrorSnackBar(context, state.failure.errorMessage);
                    }
                    if (state is AuthResetPasswordSuccess) {
                      showSuccessSnackBar(
                        context,
                        "password_updated".tr,
                      );
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        EkubMainScreen.routeName,
                        (route) => false,
                      );
                    }
                  },
                  builder: (context, state) {
                    return RoundedButton(
                      submitting: state is AuthResetPasswordLoading,
                      label: "update_password".tr,
                      height: 50.h,
                      backgroundColor: appColors.primaryColor,
                      onPressed: _handleResetPassword,
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

  // Helper to keep the build method clean while using your CustomTextField
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required dynamic appColors,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: appColors.titleTextColor, fontSize: 14.sp),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) return "password_required".tr;
            if (value.length < 6)
              return "min_password_6".tr;
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
        prefixIcon: Icon(
          Icons.lock_outline,
          size: 20,
          color: appColors.primaryColor,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(
            color: appColors.primaryColor!.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: appColors.primaryColor!, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
