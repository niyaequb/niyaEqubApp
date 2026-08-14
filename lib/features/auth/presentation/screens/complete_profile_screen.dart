import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/util/app_constants.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/auth/state/auth_bloc.dart';
import 'package:niya_equb/features/auth/state/auth_event.dart';
import 'package:niya_equb/features/auth/state/auth_state.dart';

import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/features/auth/presentation/screens/login_screen.dart';
import 'package:niya_equb/features/agent/main/presentation/screens/agent_main_screen.dart';
import 'package:niya_equb/features/member/main/presentation/screens/ekub_main_screen.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart'; // Your component
import 'package:niya_equb/shared/widgets/custom_password_field.dart';
import 'package:niya_equb/shared/widgets/custom_searchable_dropdown.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class CompleteProfileScreen extends StatefulWidget {
  static const String routeName = '/complete-profile';
  final String phoneNumber;

  const CompleteProfileScreen({super.key, required this.phoneNumber});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final AuthBloc _authBloc = AuthBloc(authRepository: sl<AuthRepository>());
  bool _autoValidate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      _authBloc.add(
        AuthSignup(
          phone: widget.phoneNumber,
          password: _passwordController.text,
          email: _emailController.text,
          name: _nameController.text,
          userType: 'member',
          referralCode: _referralCodeController.text.trim().isEmpty
              ? null
              : _referralCodeController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
        ),
      );
    } else {
      setState(() {
        _autoValidate = true;
      });
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
          title: "complete_profile".tr,
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

                // User Icon
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: appColors.primaryColor!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.badge_rounded,
                    size: 32.sp,
                    color: appColors.primaryColor,
                  ),
                ),

                SizedBox(height: 24.h),

                CustomText(
                  title: "finish_signing_up".tr,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  textColor: appColors.titleTextColor,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8.h),

                CustomText(
                  title: "setup_account_for".trParams({
                    's': widget.phoneNumber,
                  }),
                  fontSize: 13.sp,
                  textColor: appColors.bodyTextSmallColor,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32.h),

                // Name Field
                CustomTextField(
                  label: "full_name".tr,
                  controller: _nameController,
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: appColors.primaryColor,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "name_required".tr;
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16.h),

                CustomSearchableDropdown(
                  label: "city".tr,
                  hint: "select_city".tr,
                  options: AppConstants.ethiopianCities,
                  controller: _cityController,
                  prefixIcon: Icon(
                    Icons.location_city_outlined,
                    size: 20,
                    color: appColors.primaryColor,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "city_required".tr;
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16.h),

                // Email Field (Optional)
                CustomTextField(
                  label: "email_optional".tr,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    size: 20,
                    color: appColors.primaryColor,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return "valid_email_address".tr;
                      }
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16.h),

                CustomTextField(
                  label: "referral_code_optional".tr,
                  controller: _referralCodeController,
                  prefixIcon: Icon(
                    Icons.card_giftcard_outlined,
                    size: 20,
                    color: appColors.primaryColor,
                  ),
                ),

                SizedBox(height: 16.h),

                CustomPasswordField(
                  label: "password".tr,
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "password_required".tr;
                    }
                    if (value.length < 8) {
                      return "min_password".tr;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                CustomPasswordField(
                  label: "confirm_password".tr,
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return "passwords_dont_match".tr;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32.h),
                BlocConsumer<AuthBloc, AuthState>(
                  bloc: _authBloc,
                  listener: (context, state) {
                    if (state is AuthSignupSuccess) {
                      if (!context.isTopRoute) return;

                      if (state.isSignedIn) {
                        // Registration already established a session, so there
                        // is no reason to make a brand new user type their
                        // password again — straight to the home screen.
                        showSuccessSnackBar(
                          context,
                          'account_created_welcome'.tr,
                        );
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          state.isAgent
                              ? AgentMainScreen.routeName
                              : EkubMainScreen.routeName,
                          (route) => false,
                        );
                        return;
                      }

                      // Fallback: the account exists but could not be signed in
                      // (an agent waiting on approval, for instance). Clear the
                      // half-session and let them log in by hand.
                      PreferencesService.clearUserData().then((_) {
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          LoginScreen.routeName,
                          (route) => false,
                          arguments: {'snackMessage': 'account_created_wait'.tr},
                        );
                      });
                    } else if (state is AuthSignupFailure) {
                      showErrorSnackBar(context, state.failure.errorMessage);
                    }
                  },
                  builder: (context, state) {
                    return RoundedButton(
                      submitting: state is AuthSignupLoading,
                      label: "create_account_btn".tr,
                      height: 50.h,
                      backgroundColor: appColors.primaryColor,
                      onPressed: _handleSubmit,
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
