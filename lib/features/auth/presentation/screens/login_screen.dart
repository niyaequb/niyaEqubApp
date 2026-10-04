import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/core/util/nav_guard.dart';
import 'package:niya_equb/features/auth/presentation/screens/phone_number_screen.dart';
import 'package:niya_equb/features/auth/state/auth_bloc.dart';
import 'package:niya_equb/features/auth/state/auth_event.dart';
import 'package:niya_equb/features/auth/state/auth_state.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/core/language/controllers/language_controller.dart';
import 'package:niya_equb/core/util/app_constants.dart';
import 'package:niya_equb/features/auth/repository/auth_repository.dart';
import 'package:niya_equb/features/agent/main/presentation/screens/agent_main_screen.dart';
import 'package:niya_equb/features/member/main/presentation/screens/ekub_main_screen.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/shared/widgets/custom_password_field.dart';
import 'package:niya_equb/shared/widgets/custom_phone_field.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthBloc _authBloc = AuthBloc(authRepository: sl<AuthRepository>());

  bool _autoValidate = false;

  /// Whether a field on the form has focus — i.e. the on-screen keyboard is,
  /// or is about to be, up.
  ///
  /// WHY THE WEB BUILD NEEDS THIS AND THE PHONE DOES NOT
  ///
  /// On a phone the OS tells Flutter the keyboard's height, the Scaffold
  /// shrinks, and the focused field scrolls into view by itself. Inside the
  /// Dashen SuperApp's WebView the keyboard is drawn OVER the page and Flutter
  /// is never told it is there, so nothing moves: the password field, in the
  /// lower half of the screen, sat under the keyboard (Dashen QA, item 1).
  ///
  /// Resizing the page to the visible area instead is not an option here:
  /// flutter_screenutil would rescale every height-based dimension in the app
  /// the moment the keyboard opened. So the form makes room itself — extra
  /// space below it while a field is focused — and scrolls the focused field
  /// into the top part of the screen, clear of any keyboard.
  bool _fieldFocused = false;

  /// Into the app after signing in.
  ///
  /// And, when the member only landed on this screen because the bank app's
  /// reload lost their session in the middle of paying, straight back into
  /// the Equb they were paying from, still confirming the payment — the same
  /// thing SplashScreen does when the session survived (Dashen QA, item 9).
  ///
  /// The navigator is captured before the await, so nothing here touches this
  /// screen's context after it may have gone.
  Future<void> _enterApp(NavigatorState navigator) async {
    final user = PreferencesService.getUser();
    final isAgent = (user?.type ?? '').toLowerCase() == 'agent';

    // Only the local note is read before leaving: it is on the device and
    // instant. Anything slower here would leave the member on a sign-in
    // screen that looks stuck, with its button live again.
    final local = isAgent ? null : await PreferencesService.takePaymentReturn();

    navigator.pushNamedAndRemoveUntil(
      isAgent ? AgentMainScreen.routeName : EkubMainScreen.routeName,
      (route) => false,
    );

    if (isAgent) return;

    void reopen(int groupId, String reference, {required bool quiet}) {
      if (!navigator.mounted) return;
      navigator.pushNamed(
        EqubDetailScreen.routeName,
        arguments: {
          'groupId': groupId,
          'initialTab': 0,
          'awaitReference': reference,
          'awaitQuietly': quiet,
        },
      );
    }

    if (local != null) {
      reopen(local.groupId, local.reference, quiet: false);
      return;
    }

    // If the reload that brought the member here also wiped the note, the
    // server still knows. Asked AFTER the home screen is up, so the member is
    // never kept waiting for it; the Equb opens on top when the answer lands.
    final remote = await sl<EkubPackagesRepository>().latestPaymentAttempt();
    if (remote != null) {
      reopen(remote.groupId, remote.reference, quiet: true);
    }
  }

  void _onFormFocusChange(bool hasFocus) {
    if (!kIsWeb || hasFocus == _fieldFocused) return;
    setState(() => _fieldFocused = hasFocus);
    if (!hasFocus) return;

    // After the extra space exists, not before: there is nothing to scroll
    // until the padding below has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null || !focused.mounted) return;
      Scrollable.ensureVisible(
        focused,
        alignment: 0.2,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
  bool _snackShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_snackShown) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final msg = args['snackMessage'];
      if (msg is String && msg.trim().isNotEmpty) {
        _snackShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showSuccessSnackBar(context, msg);
        });
      }
    }
  }

  @override
  void dispose() {
    // Created in this State's field initialiser rather than pulled from the
    // provider tree, so nothing else closes it. Without this, every visit to
    // login left a bloc and its stream subscription behind — and a stale one
    // still listening is exactly how a login navigates twice.
    _authBloc.close();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      _authBloc.add(
        AuthLogin(
          phone: _phoneController.text,
          password: _passwordController.text,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -30.h,
            right: -30.w,
            child: Opacity(
              opacity: isDark ? 0.05 : 0.03,
              child: Icon(
                Icons.groups_rounded,
                size: 200.sp,
                color: appColors.primaryColor,
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: _buildLanguageSelector(appColors, isDark),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24.w,
                  10.h,
                  24.w,
                  // Room for a keyboard Flutter cannot see. See
                  // _fieldFocused. Plain pixels from MediaQuery, not .h,
                  // so it tracks the real screen rather than the design size.
                  _fieldFocused
                      ? MediaQuery.of(context).size.height * 0.45
                      : 10.h,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Focus(
                  // Observes focus for the whole form without ever taking it.
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: _onFormFocusChange,
                  child: Form(
                  key: _formKey,
                  autovalidateMode: _autoValidate
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: appColors.primaryColor!.withOpacity(
                                    0.2,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2.r),
                                child: Image.asset(
                                  'assets/images/new-logo.png',
                                  width: 48.r,
                                  height: 52.r,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            CustomText(
                              title: "app_name".tr,
                              fontSize: 18.sp,
                              textColor: appColors.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),
                      CustomText(
                        title: "welcome_back".tr,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        textColor: appColors.titleTextColor,
                      ),
                      SizedBox(height: 4.h),
                      CustomText(
                        title: "sign_in_subtitle".tr,
                        fontSize: 13.sp,
                        textColor: appColors.bodyTextSmallColor,
                        fontWeight: FontWeight.normal,
                      ),

                      SizedBox(height: 28.h),

                      _buildInputLabel("phone_number".tr, appColors),
                      CustomPhoneField(
                        label: "phone_placeholder".tr,
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

                      SizedBox(height: 16.h),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel("password".tr, appColors),
                          InkWell(
                            onTap: () {
                              context.pushOnce(
                                PhoneNumberScreen.routeName,
                                arguments: {'from': 'forgot_password'},
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 6.h),
                              child: CustomText(
                                title: "forgot_password".tr,
                                fontSize: 11.sp,
                                textColor: appColors.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      CustomPasswordField(
                        label: "enter_password".tr,
                        controller: _passwordController,
                        borderRadius: 12.r,
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

                      SizedBox(height: 24.h),
                      BlocConsumer<AuthBloc, AuthState>(
                        bloc: _authBloc,
                        listener: (context, state) {
                          if (state is AuthLoginFailure) {
                            showErrorSnackBar(
                              context,
                              state.failure.errorMessage,
                            );
                          }

                          if (state is AuthLoginSuccess) {
                            if (!context.isTopRoute) return;
                            _enterApp(Navigator.of(context));
                          }
                        },
                        builder: (context, state) {
                          return RoundedButton(
                            submitting: state is AuthLoginLoading,
                            fontSize: 14.r,
                            label: "sign_in_button".tr,
                            foregroundColor: Colors.black.withValues(alpha: .7),
                            height: 45.h,
                            borderRadius: 12.r,
                            backgroundColor: appColors.primaryColor,
                            onPressed: _handleLogin,
                          );
                        },
                      ),

                      SizedBox(height: 28.h),

                      Center(
                        child: Column(
                          children: [
                            CustomText(
                              title: "new_here".tr,
                              fontSize: 13.sp,
                              textColor: appColors.bodyTextSmallColor,
                            ),
                            SizedBox(height: 6.h),
                            InkWell(
                              onTap: () {
                                // A second tap during the page transition used
                                // to stack a duplicate signup screen, so going
                                // back landed on signup again instead of login.
                                context.pushOnce(
                                  PhoneNumberScreen.routeName,
                                  arguments: {'from': 'register'},
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: appColors.primaryColor!.withOpacity(
                                      0.4,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: CustomText(
                                    title: "create_account".tr,
                                    fontSize: 14.sp,
                                    textColor: appColors.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),  // Focus
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label, AppColors colors) {
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.h, left: 4.w),
          child: CustomText(
            title: label,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            textColor: colors.titleTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(AppColors appColors, bool isDark) {
    return GetBuilder<LocalizationController>(
      builder: (localizationController) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: isDark ? appColors.primaryColor!.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: appColors.primaryColor!.withValues(alpha: 0.2)),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: localizationController.selectedLanguageIndex,
              icon: Icon(Icons.arrow_drop_down, color: appColors.primaryColor, size: 22.sp),
              elevation: 4,
              isDense: true,
              style: TextStyle(
                color: appColors.titleTextColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              borderRadius: BorderRadius.circular(16.r),
              dropdownColor: appColors.scaffoldBackgroundColor,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  localizationController.setSelectLanguageIndex(newValue);
                  localizationController.setLanguage(Locale(
                    AppConstants.languages[newValue].languageCode!,
                    AppConstants.languages[newValue].countryCode,
                  ));
                }
              },
              selectedItemBuilder: (BuildContext context) {
                return localizationController.languages.map<Widget>((language) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language_rounded, color: appColors.primaryColor, size: 18.sp),
                      SizedBox(width: 6.w),
                      Text(
                        language.languageName!,
                        style: TextStyle(
                          color: appColors.primaryColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              items: List.generate(
                localizationController.languages.length,
                (index) => DropdownMenuItem<int>(
                  value: index,
                  child: Text(
                    localizationController.languages[index].languageName!,
                    style: TextStyle(
                      color: appColors.titleTextColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
