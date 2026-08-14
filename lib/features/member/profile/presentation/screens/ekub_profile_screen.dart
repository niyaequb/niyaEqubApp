import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/constants/hive_constants.dart';
import 'package:niya_equb/core/service/navigation_service.dart';
import 'package:niya_equb/core/service/snack_bar.dart';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:niya_equb/core/language/controllers/language_controller.dart';
import 'package:niya_equb/core/util/app_constants.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_bloc.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_event.dart';
import 'package:niya_equb/features/member/profile/state/ekub_profile_state.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/shared/widgets/custom_password_field.dart';
import 'package:niya_equb/shared/widgets/custom_text_field.dart';
import 'package:niya_equb/shared/widgets/custom_searchable_dropdown.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/features/member/settings/state/settings_bloc.dart';
import 'package:niya_equb/features/member/settings/state/settings_state.dart';
import 'package:niya_equb/features/member/settings/data/models/settings_model.dart';
import 'package:niya_equb/features/member/settings/data/models/faq_model.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EkubProfileScreen extends StatefulWidget {
  const EkubProfileScreen({super.key, this.openEditSheetNotifier});

  /// When this notifier becomes true, the edit profile sheet is shown.
  /// Used by payout screen when bank info is not set.
  final ValueNotifier<bool>? openEditSheetNotifier;

  /// Shows the edit profile sheet from any context that has EkubProfileBloc.
  /// [onProfileUpdated] is called when profile is successfully saved.
  static Future<void> showEditProfileSheet(
    BuildContext context, {
    VoidCallback? onProfileUpdated,
  }) async {
    final bloc = context.read<EkubProfileBloc>();
    final state = bloc.state;
    final user = switch (state) {
      EkubProfileLoaded s => s.user,
      EkubProfileUpdateLoading s => s.user,
      EkubProfileUpdateSuccess s => s.user,
      EkubProfileUpdateFailure s => s.user,
      EkubProfileLoading s => s.user,
      EkubProfileFailure s => s.user,
      _ => null,
    };
    final headers = switch (state) {
      EkubProfileLoaded s => s.imageHeaders,
      EkubProfileUpdateLoading s => s.imageHeaders,
      EkubProfileUpdateSuccess s => s.imageHeaders,
      EkubProfileUpdateFailure s => s.imageHeaders,
      _ => null,
    };
    await _showEditProfileSheetImpl(
      context,
      user: user,
      headers: headers,
      profileBloc: bloc,
      imagePicker: ImagePicker(),
      onProfileUpdated: onProfileUpdated,
    );
  }

  @override
  State<EkubProfileScreen> createState() => _EkubProfileScreenState();
}

class _EkubProfileScreenState extends State<EkubProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    widget.openEditSheetNotifier?.addListener(_onOpenEditSheetChanged);
  }

  @override
  void dispose() {
    widget.openEditSheetNotifier?.removeListener(_onOpenEditSheetChanged);
    super.dispose();
  }

  void _onOpenEditSheetChanged() {
    if (widget.openEditSheetNotifier?.value == true && mounted) {
      widget.openEditSheetNotifier!.value = false;
      final state = context.read<EkubProfileBloc>().state;
      final user = switch (state) {
        EkubProfileLoaded s => s.user,
        EkubProfileUpdateLoading s => s.user,
        EkubProfileUpdateSuccess s => s.user,
        EkubProfileUpdateFailure s => s.user,
        EkubProfileLoading s => s.user,
        EkubProfileFailure s => s.user,
        _ => null,
      };
      final headers = switch (state) {
        EkubProfileLoaded s => s.imageHeaders,
        EkubProfileUpdateLoading s => s.imageHeaders,
        EkubProfileUpdateSuccess s => s.imageHeaders,
        EkubProfileUpdateFailure s => s.imageHeaders,
        _ => null,
      };
      _showEditProfileSheetImpl(
        context,
        user: user,
        headers: headers,
        profileBloc: context.read<EkubProfileBloc>(),
        imagePicker: _imagePicker,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return BlocConsumer<EkubProfileBloc, EkubProfileState>(
      listener: (context, state) {
        if (state is EkubProfileFailure) {
          showErrorSnackBar(context, state.failure.errorMessage);
        } else if (state is EkubProfileDeleteAccountFailure) {
          showErrorSnackBar(context, state.failure.errorMessage);
        } else if (state is EkubProfileDeleteAccountSuccess) {
          // Same guarded exit the expired-session path uses, so a delete that
          // lands while a 401 is already in flight cannot push login twice.
          NavigationService.returnToLogin();
        }
        // Update states are handled inside the edit profile modal.
      },
      builder: (context, state) {
        final isLoading =
            state is EkubProfileLoading ||
            state is EkubProfileDeleteAccountLoading;
        final isUpdating = state is EkubProfileUpdateLoading;

        final user = switch (state) {
          EkubProfileLoaded s => s.user,
          EkubProfileUpdateLoading s => s.user,
          EkubProfileUpdateSuccess s => s.user,
          EkubProfileUpdateFailure s => s.user,
          EkubProfileDeleteAccountLoading s => s.user,
          EkubProfileDeleteAccountFailure s => s.user,
          EkubProfileLoading s => s.user,
          EkubProfileFailure s => s.user,
          _ => null,
        };

        final headers = switch (state) {
          EkubProfileLoaded s => s.imageHeaders,
          EkubProfileUpdateLoading s => s.imageHeaders,
          EkubProfileUpdateSuccess s => s.imageHeaders,
          EkubProfileUpdateFailure s => s.imageHeaders,
          EkubProfileDeleteAccountLoading s => s.imageHeaders,
          EkubProfileDeleteAccountFailure s => s.imageHeaders,
          _ => null,
        };

        final isAgent = (user?.type ?? '').toLowerCase() == 'agent';
        final name = user?.name.isNotEmpty == true
            ? user!.name
            : (isAgent ? 'agent'.tr : 'member'.tr);
        final phone = user?.phone.isNotEmpty == true ? user!.phone : '—';
        final email = (user?.email?.isNotEmpty == true) ? user!.email! : '—';

        return Scaffold(
          backgroundColor: appColors.scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<EkubProfileBloc>().add(EkubProfileRefreshEvent());
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  title: Text('profile_title'.tr),
                  actions: [
                    IconButton(
                      tooltip: 'edit_profile'.tr,
                      onPressed: isUpdating
                          ? null
                          : () => _showEditProfileSheetImpl(
                              context,
                              user: user,
                              headers: headers,
                              profileBloc: context.read<EkubProfileBloc>(),
                              imagePicker: _imagePicker,
                            ),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    SizedBox(width: 6.w),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: appColors.accentColor,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: appColors.borderColor!),
                      ),
                      child: Row(
                        children: [
                          _ProfileAvatar(
                            isLoading: isLoading,
                            imageUrl: user?.profilePicture,
                            headers: headers,
                            fallbackInitial: name.isNotEmpty
                                ? name[0].toUpperCase()
                                : (isAgent ? 'A' : 'M'),
                            onTapEdit: isUpdating
                                ? null
                                : () => _showEditProfileSheetImpl(
                                    context,
                                    user: user,
                                    headers: headers,
                                    profileBloc: context
                                        .read<EkubProfileBloc>(),
                                    imagePicker: _imagePicker,
                                  ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomText(
                                        title: name,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        textColor: appColors.titleTextColor,
                                        maxLines: 1,
                                        textOverflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isLoading)
                                      Padding(
                                        padding: EdgeInsets.only(left: 10.w),
                                        child: SizedBox(
                                          height: 14.r,
                                          width: 14.r,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: appColors.primaryColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                CustomText(
                                  title: phone,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  textColor: appColors.bodyTextSmallColor,
                                ),
                                SizedBox(height: 2.h),
                                CustomText(
                                  title: email,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  textColor: appColors.bodyTextSmallColor,
                                  maxLines: 1,
                                  textOverflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: appColors.bodyTextSmallColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isAgent &&
                    (user?.bankName?.isNotEmpty == true ||
                        user?.accountNumber?.isNotEmpty == true ||
                        user?.accountHolderName?.isNotEmpty == true))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                      child: _BankDetailsCard(user: user!),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: CustomText(
                      title: 'settings'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.titleTextColor,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      ValueListenableBuilder(
                        valueListenable: Hive.box(
                          HiveConstants.appSettingsBox,
                        ).listenable(),
                        builder: (context, box, _) {
                          final isDarkTheme =
                              box.get(
                                    HiveConstants.isDarkTheme,
                                    defaultValue: false,
                                  )
                                  as bool;
                          return _SwitchTile(
                            icon: isDarkTheme
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            title: 'appearance'.tr,
                            subtitle: isDarkTheme
                                ? 'dark_mode'.tr
                                : 'light_mode'.tr,
                            value: isDarkTheme,
                            onChanged: (v) =>
                                box.put(HiveConstants.isDarkTheme, v),
                          );
                        },
                      ),
                      SizedBox(height: 10.h),
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: 'language'.tr,
                        subtitle: 'language_subtitle'.tr,
                        onTap: () => _showLanguageSheet(context),
                      ),
                      // Settings from API
                      BlocBuilder<SettingsBloc, SettingsState>(
                        builder: (context, settingsState) {
                          if (settingsState is SettingsLoading ||
                              settingsState is SettingsInitial) {
                            return Column(
                              children: [
                                SizedBox(height: 10.h),
                                Container(
                                  height: 72.h,
                                  decoration: BoxDecoration(
                                    color: appColors.accentColor,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: appColors.borderColor!,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          if (settingsState is SettingsFailure) {
                            return const SizedBox.shrink();
                          }
                          if (settingsState is! SettingsLoaded) {
                            return const SizedBox.shrink();
                          }
                          final settings = settingsState.settings;
                          return Column(
                            children: [
                              if (settings.privacyPolicy?.isNotEmpty ==
                                  true) ...[
                                SizedBox(height: 10.h),
                                _SettingsTile(
                                  icon: Icons.privacy_tip_outlined,
                                  title: 'privacy_policy'.tr,
                                  subtitle: 'read_privacy_policy'.tr,
                                  onTap: () => _showTextSheet(
                                    context,
                                    title: 'privacy_policy'.tr,
                                    content: settings.privacyPolicy!,
                                  ),
                                ),
                              ],
                              if (settings.termsAndConditions?.isNotEmpty ==
                                  true) ...[
                                SizedBox(height: 10.h),
                                _SettingsTile(
                                  icon: Icons.description_outlined,
                                  title: 'terms_conditions'.tr,
                                  subtitle: 'read_terms_conditions'.tr,
                                  onTap: () => _showTextSheet(
                                    context,
                                    title: 'terms_conditions'.tr,
                                    content: settings.termsAndConditions!,
                                  ),
                                ),
                              ],
                              if (settingsState.faqs != null &&
                                  settingsState.faqs!.isNotEmpty) ...[
                                SizedBox(height: 10.h),
                                _SettingsTile(
                                  icon: Icons.help_outline_rounded,
                                  title: 'faqs'.tr,
                                  subtitle: 'frequently_asked_questions'.tr,
                                  onTap: () => _showFaqSheet(
                                    context,
                                    faqs: settingsState.faqs!,
                                  ),
                                ),
                              ],
                              if (settings.support != null) ...[
                                SizedBox(height: 10.h),
                                _SettingsTile(
                                  icon: Icons.support_agent_outlined,
                                  title: 'support'.tr,
                                  subtitle:
                                      settings.support!.email ??
                                      settings.support!.phone ??
                                      'contact_us'.tr,
                                  onTap: () => _showSupportSheet(
                                    context,
                                    support: settings.support!,
                                  ),
                                ),
                              ],
                              if (settings.social != null &&
                                  settings.social!.entries.isNotEmpty) ...[
                                SizedBox(height: 10.h),
                                _SettingsTile(
                                  icon: Icons.share_outlined,
                                  title: 'social_media'.tr,
                                  subtitle: 'follow_us'.tr,
                                  onTap: () => _showSocialMediaSheet(
                                    context,
                                    social: settings.social!,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 16.h),
                      RoundedButton(
                        label: 'log_out'.tr,
                        height: 48.h,
                        backgroundColor: appColors.accentColor,
                        foregroundColor: Colors.redAccent,
                        borderSide: BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final confirm = await _confirmLogout(context);
                                if (confirm != true) return;

                                // Clears the session and returns to login in
                                // one guarded step.
                                await NavigationService.returnToLogin();
                              },
                      ),
                      SizedBox(height: 16.h),
                      RoundedButton(
                        label: 'delete_account'.tr,
                        height: 48.h,
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        onPressed: isLoading
                            ? null
                            : () => _confirmDeleteAccount(context),
                      ),
                      SizedBox(height: 32.h), // Extra padding at bottom
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showEditProfileSheetImpl(
  BuildContext context, {
  required UserModel? user,
  required Map<String, String>? headers,
  required EkubProfileBloc profileBloc,
  required ImagePicker imagePicker,
  VoidCallback? onProfileUpdated,
}) async {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final maxHeight = MediaQuery.sizeOf(context).height * 0.90;
  final isAgent = (user?.type ?? '').toLowerCase() == 'agent';

  final nameCtrl = TextEditingController(text: user?.name ?? '');
  final cityCtrl = TextEditingController(text: user?.city ?? '');
  final emailCtrl = TextEditingController(text: user?.email ?? '');
  final passwordCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController(text: user?.bankName ?? '');
  final accountNumberCtrl = TextEditingController(
    text: user?.accountNumber ?? '',
  );
  final accountHolderNameCtrl = TextEditingController(
    text: user?.accountHolderName ?? '',
  );
  File? pickedImage;
  bool submitting = false;

  Future<void> pickImage(ImageSource source) async {
    final xfile = await imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (xfile == null) return;

    final file = File(xfile.path);
    final bytes = await file.length();
    if (bytes > 2048 * 1024) {
      if (!context.mounted) return;
      showErrorSnackBar(context, 'Profile picture must be less than 2MB.');
      return;
    }
    pickedImage = file;
  }

  // ignore: use_build_context_synchronously
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return BlocProvider.value(
        value: profileBloc,
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final previewUrl = user?.profilePicture;
            final initials = (nameCtrl.text.isNotEmpty
                ? nameCtrl.text[0].toUpperCase()
                : 'M');

            return BlocListener<EkubProfileBloc, EkubProfileState>(
              listenWhen: (prev, curr) =>
                  curr is EkubProfileUpdateLoading ||
                  curr is EkubProfileUpdateFailure ||
                  curr is EkubProfileUpdateSuccess,
              listener: (ctx, state) {
                if (state is EkubProfileUpdateLoading) {
                  setSheetState(() => submitting = true);
                  return;
                }
                if (state is EkubProfileUpdateFailure) {
                  setSheetState(() => submitting = false);
                  Navigator.pop(sheetCtx);
                  if (context.mounted) {
                    showErrorSnackBar(context, state.failure.errorMessage);
                  }
                  return;
                }
                if (state is EkubProfileUpdateSuccess) {
                  setSheetState(() => submitting = false);
                  showSuccessSnackBar(sheetCtx, 'profile_updated'.tr);
                  Navigator.pop(sheetCtx);
                  profileBloc.add(EkubProfileRefreshEvent());
                  onProfileUpdated?.call();
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                decoration: BoxDecoration(
                  color: appColors.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22.r),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        SizedBox(height: 14.h),
                        Row(
                          children: [
                            Expanded(
                              child: CustomText(
                                title: 'edit_profile'.tr,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                textColor: appColors.titleTextColor,
                              ),
                            ),
                            IconButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.pop(sheetCtx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                height: 86.r,
                                width: 86.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: appColors.borderColor!,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: pickedImage != null
                                    ? Image.file(
                                        pickedImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : (previewUrl != null &&
                                          previewUrl
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                    ? Image.network(
                                        previewUrl.toString(),
                                        fit: BoxFit.cover,
                                        headers: headers,
                                        errorBuilder: (_, _, _) =>
                                            _AvatarFallback(initials: initials),
                                      )
                                    : _AvatarFallback(initials: initials),
                              ),
                              InkWell(
                                onTap: submitting
                                    ? null
                                    : () async {
                                        await showModalBottomSheet(
                                          context: sheetCtx,
                                          backgroundColor: Colors.transparent,
                                          builder: (ctx) {
                                            return Container(
                                              padding: EdgeInsets.all(16.r),
                                              decoration: BoxDecoration(
                                                color: appColors
                                                    .scaffoldBackgroundColor,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(
                                                        22.r,
                                                      ),
                                                    ),
                                              ),
                                              child: SafeArea(
                                                top: false,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons
                                                            .photo_library_rounded,
                                                      ),
                                                      title: const Text(
                                                        'Gallery',
                                                      ),
                                                      onTap: () async {
                                                        Navigator.pop(ctx);
                                                        await pickImage(
                                                          ImageSource.gallery,
                                                        );
                                                        setSheetState(() {});
                                                      },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons
                                                            .camera_alt_rounded,
                                                      ),
                                                      title: const Text(
                                                        'Camera',
                                                      ),
                                                      onTap: () async {
                                                        Navigator.pop(ctx);
                                                        await pickImage(
                                                          ImageSource.camera,
                                                        );
                                                        setSheetState(() {});
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                child: Container(
                                  height: 34.r,
                                  width: 34.r,
                                  decoration: BoxDecoration(
                                    color: appColors.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: appColors.scaffoldBackgroundColor!,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: submitting,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  CustomTextField(
                                    label: 'name'.tr,
                                    controller: nameCtrl,
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: appColors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  CustomTextField(
                                    label: 'email'.tr,
                                    controller: emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: appColors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  CustomSearchableDropdown(
                                    label: 'city'.tr,
                                    hint: 'select_city'.tr,
                                    options: AppConstants.ethiopianCities,
                                    controller: cityCtrl,
                                    prefixIcon: Icon(
                                      Icons.location_city_outlined,
                                      color: appColors.primaryColor,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'city_required'.tr;
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 12.h),
                                  CustomPasswordField(
                                    label: 'new_password_optional'.tr,
                                    controller: passwordCtrl,
                                  ),
                                  if (isAgent) ...[
                                    SizedBox(height: 16.h),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: CustomText(
                                        title: 'bank_details'.tr,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        textColor: appColors.titleTextColor,
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    CustomTextField(
                                      label: 'provider_name'.tr,
                                      controller: bankNameCtrl,
                                      prefixIcon: Icon(
                                        Icons.account_balance_outlined,
                                        color: appColors.primaryColor,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    CustomTextField(
                                      label: 'account_number'.tr,
                                      controller: accountNumberCtrl,
                                      keyboardType: TextInputType.number,
                                      prefixIcon: Icon(
                                        Icons.numbers_rounded,
                                        color: appColors.primaryColor,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    CustomTextField(
                                      label: 'account_holder_name'.tr,
                                      controller: accountHolderNameCtrl,
                                      prefixIcon: Icon(
                                        Icons.badge_outlined,
                                        color: appColors.primaryColor,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 18.h),
                                  RoundedButton(
                                    submitting: submitting,
                                    label: 'save_changes'.tr,
                                    backgroundColor: appColors.primaryColor,
                                    foregroundColor: Colors.black.withValues(
                                      alpha: 0.85,
                                    ),
                                    onPressed: () {
                                      final password = passwordCtrl.text.trim();
                                      if (password.isNotEmpty &&
                                          password.length < 8) {
                                        showErrorSnackBar(
                                          sheetCtx,
                                          'Password must be at least 8 characters.',
                                        );
                                        return;
                                      }

                                      // Show loading immediately to prevent double taps.
                                      setSheetState(() => submitting = true);
                                      FocusScope.of(sheetCtx).unfocus();

                                      context.read<EkubProfileBloc>().add(
                                        EkubProfileUpdateEvent(
                                          name: nameCtrl.text.trim().isEmpty
                                              ? null
                                              : nameCtrl.text.trim(),
                                          email: emailCtrl.text.trim().isEmpty
                                              ? null
                                              : emailCtrl.text.trim(),
                                          password: password.isEmpty
                                              ? null
                                              : password,
                                          profilePicture: pickedImage,
                                          bankName: isAgent
                                              ? bankNameCtrl.text.trim()
                                              : null,
                                          accountNumber: isAgent
                                              ? accountNumberCtrl.text.trim()
                                              : null,
                                          accountHolderName: isAgent
                                              ? accountHolderNameCtrl.text
                                                    .trim()
                                              : null,
                                          city: cityCtrl.text.trim().isEmpty
                                              ? null
                                              : cityCtrl.text.trim(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<bool?> _confirmLogout(BuildContext context) {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        backgroundColor: appColors.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        contentPadding: EdgeInsets.all(18.r),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56.r,
              width: 56.r,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            ),
            SizedBox(height: 14.h),
            CustomText(
              title: 'log_out_confirm'.tr,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              textColor: appColors.titleTextColor,
              centerText: true,
            ),
            SizedBox(height: 6.h),
            CustomText(
              title: 'log_out_message'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              textColor: appColors.bodyTextSmallColor,
              centerText: true,
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: RoundedButton(
                    label: 'cancel'.tr,
                    height: 42.h,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    foregroundColor: appColors.primaryColor,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: RoundedButton(
                    label: 'log_out'.tr,
                    height: 42.h,
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _confirmDeleteAccount(BuildContext context) {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bloc = context.read<EkubProfileBloc>();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: bloc,
        child: BlocConsumer<EkubProfileBloc, EkubProfileState>(
          listener: (context, state) {
            if (state is EkubProfileDeleteAccountFailure) {
              Navigator.pop(context); // Close dialog on error? Or keep it?
              // Ideally show error on top of dialog or close it.
              // Let's rely on the main screen listener for global error snackbar
              // or show one here.
              // Since showDialog context is different, finding ScaffoldMessenger might be tricky
              // if it's not in the same tree. But usually it works.
              // Let's just update the button state (which BlocBuilder does).
              // If failure, the user can try again or cancel.
              // Actually, maybe we should pop if failure so they can retry?
              // No, let them retry in the dialog.
            }
          },
          builder: (context, state) {
            final isLoading = state is EkubProfileDeleteAccountLoading;
            return AlertDialog(
              backgroundColor: appColors.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
              contentPadding: EdgeInsets.all(24.r),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 32.sp,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  CustomText(
                    title: 'delete_account_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  CustomText(
                    title: 'delete_account_msg'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    textColor: appColors.bodyTextSmallColor,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: RoundedButton(
                          label: 'cancel'.tr,
                          height: 42.h,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          foregroundColor: appColors.titleTextColor,
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: RoundedButton(
                          label: 'delete'.tr,
                          height: 42.h,
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          submitting: isLoading,
                          onPressed: () {
                            context.read<EkubProfileBloc>().add(
                              EkubProfileDeleteAccountEvent(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

void _showTextSheet(
  BuildContext context, {
  required String title,
  required String content,
}) {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

  final bgColor = isDark ? '#1a1a1a' : '#ffffff';
  final textColor = isDark ? '#e0e0e0' : '#1a1a1a';
  final headingColor = isDark ? '#ffffff' : '#111111';
  final hrColor = isDark ? '#333333' : '#e0e0e0';

  final html =
      '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      font-size: 14px;
      line-height: 1.7;
      color: $textColor;
      background: $bgColor;
      padding: 4px 2px 32px 2px;
    }
    h1, h2, h3 { color: $headingColor; margin: 16px 0 8px; font-weight: 700; }
    h1 { font-size: 18px; }
    h2 { font-size: 16px; }
    h3 { font-size: 14px; }
    p { margin-bottom: 10px; }
    ul, ol { padding-left: 20px; margin-bottom: 10px; }
    li { margin-bottom: 4px; }
    strong { font-weight: 700; color: $headingColor; }
    hr { border: none; border-top: 1px solid $hrColor; margin: 16px 0; }
    a { color: #4a9eff; }
  </style>
</head>
<body>$content</body>
</html>
''';

  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Color(isDark ? 0xFF1a1a1a : 0xFFffffff))
    ..loadHtmlString(html);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: appColors.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 8.w, 0),
              child: Row(
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
                  SizedBox(width: 12.w),
                  Expanded(
                    child: CustomText(
                      title: title,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.titleTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: WebViewWidget(
                  controller: controller,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showSupportSheet(
  BuildContext context, {
  required SupportSettings support,
}) {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: appColors.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: CustomText(
                    title: 'support'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (support.email?.isNotEmpty == true) ...[
              _SupportRow(
                icon: Icons.email_outlined,
                label: 'email'.tr,
                value: support.email!,
                appColors: appColors,
                isDark: isDark,
              ),
              SizedBox(height: 10.h),
            ],
            if (support.phone?.isNotEmpty == true) ...[
              _SupportRow(
                icon: Icons.phone_outlined,
                label: 'phone'.tr,
                value: support.phone!,
                appColors: appColors,
                isDark: isDark,
              ),
              SizedBox(height: 10.h),
            ],
            if (support.whatsapp?.isNotEmpty == true) ...[
              _SupportRow(
                icon: Icons.chat_outlined,
                label: 'whatsapp'.tr,
                value: support.whatsapp!,
                appColors: appColors,
                isDark: isDark,
              ),
              SizedBox(height: 10.h),
            ],
            if (support.website?.isNotEmpty == true) ...[
              _SupportRow(
                icon: Icons.language_outlined,
                label: 'website'.tr,
                value: support.website!,
                appColors: appColors,
                isDark: isDark,
              ),
              SizedBox(height: 10.h),
            ],
            if (support.address?.isNotEmpty == true)
              _SupportRow(
                icon: Icons.location_on_outlined,
                label: 'address'.tr,
                value: support.address!,
                appColors: appColors,
                isDark: isDark,
              ),
          ],
        ),
      ),
    ),
  );
}

void _showSocialMediaSheet(
  BuildContext context, {
  required SocialSettings social,
}) {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final entries = social.entries;

  // Platform brand colors and icons
  IconData platformIcon(String name) {
    switch (name.toLowerCase()) {
      case 'telegram':
        return Icons.telegram_rounded;
      case 'youtube':
        return Icons.smart_display_rounded;
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      case 'twitter / x':
        return Icons.close_rounded;
      case 'linkedin':
        return Icons.work_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  Color platformColor(String name) {
    switch (name.toLowerCase()) {
      case 'telegram':
        return const Color(0xFF2AABEE);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'tiktok':
        return const Color(0xFF010101);
      case 'twitter / x':
        return const Color(0xFF000000);
      case 'linkedin':
        return const Color(0xFF0A66C2);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  Future<void> launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: appColors.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: CustomText(
                    title: 'social_media'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ...entries.map((item) {
              final brandColor = platformColor(item.name);
              final brandIcon = platformIcon(item.name);
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: InkWell(
                  onTap: () => launch(item.url),
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            brandIcon,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText(
                                title: item.name,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                textColor: appColors.titleTextColor,
                              ),
                              CustomText(
                                title: item.url,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                textColor: appColors.bodyTextSmallColor,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 16.sp,
                          color: appColors.bodyTextSmallColor,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

void _showLanguageSheet(BuildContext context) {
  final appColors = colors(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
  final localizationController = Get.find<LocalizationController>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GetBuilder<LocalizationController>(
      init: localizationController,
      builder: (ctrl) {
        return Container(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
          decoration: BoxDecoration(
            color: appColors.scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: CustomText(
                          title: 'choose_language'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          textColor: appColors.titleTextColor,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  CustomText(
                    title: 'choose_language_hint'.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...List.generate(AppConstants.languages.length, (i) {
                            final lang = AppConstants.languages[i];
                            final isSelected = ctrl.selectedLanguageIndex == i;
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _LangOption(
                                title: lang.languageName ?? '',
                                subtitle: i == 0
                                    ? 'primary_language'.tr
                                    : 'additional_language'.tr,
                                isSelected: isSelected,
                                onTap: () {
                                  ctrl.setLanguage(
                                    Locale(
                                      lang.languageCode!,
                                      lang.countryCode ?? 'ET',
                                    ),
                                    fromBottomSheet: false,
                                  );
                                  ctrl.setSelectLanguageIndex(i);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }),
                          SizedBox(height: 16.h),
                          RoundedButton(
                            label: 'done'.tr,
                            height: 46.h,
                            backgroundColor: appColors.primaryColor,
                            foregroundColor: Colors.black.withValues(
                              alpha: 0.85,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _BankDetailsCard extends StatelessWidget {
  final UserModel user;

  const _BankDetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: appColors.bodyTextSmallColor,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                CustomText(
                  title: 'bank_details'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.titleTextColor,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
            child: Column(
              children: [
                if (user.bankName?.isNotEmpty == true)
                  _BankDetailRow(
                    icon: Icons.business_rounded,
                    label: 'provider_name'.tr,
                    value: user.bankName!,
                    appColors: appColors,
                    isDark: isDark,
                  ),
                if (user.bankName?.isNotEmpty == true &&
                    (user.accountNumber?.isNotEmpty == true ||
                        user.accountHolderName?.isNotEmpty == true))
                  SizedBox(height: 8.h),
                if (user.accountNumber?.isNotEmpty == true)
                  _BankDetailRow(
                    icon: Icons.numbers_rounded,
                    label: 'account_number'.tr,
                    value: user.accountNumber!,
                    appColors: appColors,
                    isDark: isDark,
                  ),
                if (user.accountNumber?.isNotEmpty == true &&
                    user.accountHolderName?.isNotEmpty == true)
                  SizedBox(height: 8.h),
                if (user.accountHolderName?.isNotEmpty == true)
                  _BankDetailRow(
                    icon: Icons.badge_outlined,
                    label: 'account_holder_name'.tr,
                    value: user.accountHolderName!,
                    appColors: appColors,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColors appColors;
  final bool isDark;

  const _BankDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.appColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: (appColors.scaffoldBackgroundColor ?? appColors.accentColor!)
            .withValues(alpha: isDark ? 0.2 : 0.4),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: appColors.borderColor!.withValues(alpha: isDark ? 0.6 : 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: appColors.bodyTextSmallColor, size: 16.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  title: label,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
                SizedBox(height: 2.h),
                CustomText(
                  title: value,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.titleTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: appColors.borderColor!),
        ),
        child: Row(
          children: [
            Container(
              height: 42.r,
              width: 42.r,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: appColors.primaryColor!.withValues(
                  alpha: isDark ? 0.18 : 0.12,
                ),
              ),
              child: Icon(icon, color: appColors.primaryColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    title: title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                  SizedBox(height: 4.h),
                  CustomText(
                    title: subtitle,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: appColors.bodyTextSmallColor),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors.borderColor!),
      ),
      child: Row(
        children: [
          Container(
            height: 42.r,
            width: 42.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              color: appColors.primaryColor!.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
            child: Icon(icon, color: appColors.primaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: title,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                CustomText(
                  title: subtitle,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: appColors.primaryColor,
            activeTrackColor: appColors.primaryColor?.withValues(
              alpha: isDark ? 0.35 : 0.30,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;

  const _LangOption({
    required this.title,
    required this.subtitle,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: isSelected
              ? appColors.primaryColor!.withValues(alpha: isDark ? 0.15 : 0.1)
              : appColors.accentColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? appColors.primaryColor!.withValues(alpha: 0.4)
                : appColors.borderColor!,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.language_rounded, color: appColors.primaryColor),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    title: title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    textColor: appColors.titleTextColor,
                  ),
                  SizedBox(height: 4.h),
                  CustomText(
                    title: subtitle,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: appColors.primaryColor),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final bool isLoading;
  final String? imageUrl;
  final Map<String, String>? headers;
  final String fallbackInitial;
  final VoidCallback? onTapEdit;

  const _ProfileAvatar({
    required this.isLoading,
    required this.imageUrl,
    required this.headers,
    required this.fallbackInitial,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTapEdit,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            height: 56.r,
            width: 56.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: appColors.borderColor!),
              color: appColors.primaryColor!.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isLoading
                ? const SizedBox.shrink()
                : (imageUrl != null && imageUrl!.trim().isNotEmpty)
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    headers: headers,
                    errorBuilder: (_, _, _) =>
                        _AvatarFallback(initials: fallbackInitial),
                  )
                : _AvatarFallback(initials: fallbackInitial),
          ),
          Container(
            height: 22.r,
            width: 22.r,
            decoration: BoxDecoration(
              color: appColors.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: appColors.scaffoldBackgroundColor!,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    return Center(
      child: CustomText(
        title: initials,
        fontSize: 18.sp,
        fontWeight: FontWeight.w800,
        textColor: appColors.titleTextColor,
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppColors appColors;
  final bool isDark;

  const _SupportRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.appColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: (appColors.scaffoldBackgroundColor ?? appColors.accentColor!)
            .withValues(alpha: isDark ? 0.2 : 0.4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: appColors.borderColor!.withValues(alpha: isDark ? 0.6 : 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: appColors.primaryColor, size: 18.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  title: label,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
                SizedBox(height: 2.h),
                CustomText(
                  title: value,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.titleTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showFaqSheet(
  BuildContext context, {
  required List<FaqModel> faqs,
}) {
  final appColors = colors(context);
  final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: appColors.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 8.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: CustomText(
                      title: 'faqs'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.titleTextColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
                itemCount: faqs.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: appColors.accentColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: appColors.borderColor!),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        expansionTileTheme: ExpansionTileThemeData(
                          iconColor: appColors.primaryColor,
                          collapsedIconColor: appColors.bodyTextSmallColor,
                        ),
                      ),
                      child: ExpansionTile(
                        title: CustomText(
                          title: faq.question ?? '',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          textColor: appColors.titleTextColor,
                          textAlign: TextAlign.left,
                        ),
                        childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          CustomText(
                            title: (faq.answer ?? '').replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim(),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            textColor: appColors.bodyTextSmallColor,
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
