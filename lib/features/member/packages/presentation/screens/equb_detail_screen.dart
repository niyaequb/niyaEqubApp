import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_bloc.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_event.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_state.dart';
import 'package:niya_equb/shared/presentation/screens/payment_webview_screen.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'package:niya_equb/core/init/injections.dart';

class EqubDetailScreen extends StatefulWidget {
  final int groupId;
  final int? initialTab;
  final String? drawType;
  final String? winnerName;
  final List<String>? candidates;
  final DateTime? drawTime;
  static const String routeName = '/equb-detail';

  const EqubDetailScreen({
    super.key,
    required this.groupId,
    this.initialTab,
    this.drawType,
    this.winnerName,
    this.candidates,
    this.drawTime,
  });

  @override
  State<EqubDetailScreen> createState() => _EqubDetailScreenState();
}

class _EqubDetailScreenState extends State<EqubDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<RemoteMessage>? _notificationSubscription;

  void _applyInitialDrawState() {
    if (widget.drawType == 'equb_draw_started') {
      if (widget.drawTime != null) {
        final diff = DateTime.now().difference(widget.drawTime!);
        if (diff.inSeconds > 60) {
          logger("EqubDetailScreen: Passed draw state is too old (${diff.inSeconds}s). Ignoring.");
          return;
        }
      }
      context.read<EqubDetailBloc>().add(
            EqubDetailDrawStartedEvent(candidates: widget.candidates ?? []),
          );
      if (_tabController.index != 2) {
        _tabController.animateTo(2);
      }
    } else if (widget.drawType == 'equb_draw_completed') {
      context.read<EqubDetailBloc>().add(
            EqubDetailDrawCompletedEvent(
              winnerName: widget.winnerName ?? 'Someone',
            ),
          );
      if (_tabController.index != 2) {
        _tabController.animateTo(2);
      }
    }
  }

  @override
  void didUpdateWidget(EqubDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drawType != oldWidget.drawType ||
        widget.winnerName != oldWidget.winnerName ||
        widget.candidates != oldWidget.candidates) {
      _applyInitialDrawState();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );

    context.read<EqubDetailBloc>().add(EqubDetailLoadEvent(widget.groupId));
    _applyInitialDrawState();

    _notificationSubscription = sl<NotificationService>().messageStream.listen((
      message,
    ) {
      final msgGroupId = message.data['equb_group_id'];
      if (msgGroupId?.toString() == widget.groupId.toString()) {
        final type = message.data['type'];
        if (type == 'equb_draw_started') {
          final rawNames = message.data['member_names'];
          List<String> candidates = [];
          
          if (rawNames is List) {
            candidates = rawNames.map((e) => e.toString()).toList();
          } else if (rawNames is String) {
            try {
              final decoded = jsonDecode(rawNames);
              if (decoded is List) {
                candidates = decoded.map((e) => e.toString()).toList();
              }
            } catch (_) {}
          }

          context.read<EqubDetailBloc>().add(
                EqubDetailDrawStartedEvent(candidates: candidates),
              );
          if (_tabController.index != 2) {
            _tabController.animateTo(2);
          }
        } else if (type == 'equb_draw_completed') {
          final winnerName =
              message.data['winner_name'] ??
              message.data['winner_membership_id'] ??
              'Someone';
          context.read<EqubDetailBloc>().add(
            EqubDetailDrawCompletedEvent(winnerName: winnerName),
          );
          if (_tabController.index != 2) {
            _tabController.animateTo(2);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<EqubDetailBloc, EqubDetailState>(
      listenWhen: (previous, current) =>
          current is EqubDetailPaymentSuccess ||
          current is EqubDetailPaymentFailure ||
          current is EqubDetailLeaveSuccess ||
          current is EqubDetailLeaveFailure ||
          (current is EqubDetailSuccess &&
              (previous is! EqubDetailSuccess ||
                  previous.isDrawing != current.isDrawing)),
      listener: (context, state) {
        logger('EqubDetailScreen Listener: state index = ${state.runtimeType}');

        if (state is EqubDetailSuccess && state.isDrawing) {
          logger(
            'EqubDetailScreen Listener: Draw detected. Switching to Draw tab.',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_tabController.index != 2) {
              _tabController.animateTo(2);
            }
          });
        }

        if (state is EqubDetailPaymentSuccess) {
          logger(
            'EqubDetailScreen Listener: Payment Success. Closing dialog...',
          );
          // Close the confirmation dialog FIRST
          Navigator.of(context).pop();

          logger('EqubDetailScreen Listener: Navigating to WebView...');
          Get.to(
            () => PaymentWebViewScreen(
              paymentUrl: state.checkoutUrl,
              userType: PaymentUserType.member,
              title: 'equb_payment',
            ),
          )?.then((result) {
            logger(
              'EqubDetailScreen Listener: Returned from WebView with result = $result',
            );
            if (context.mounted) {
              SystemChannels.textInput.invokeMethod('TextInput.hide');
              FocusManager.instance.primaryFocus?.unfocus();
            }

            if (result == true) {
              if (context.mounted) {
                context.read<EqubDetailBloc>().add(
                  EqubDetailLoadEvent(widget.groupId),
                );
                Get.rawSnackbar(
                  message: "payment_successful".tr,
                  backgroundColor: Colors.green,
                );
              }
            }
          });
        } else if (state is EqubDetailPaymentFailure) {
          logger(
            'EqubDetailScreen Listener: Payment Failure. Closing dialog...',
          );
          // Close the confirmation dialog FIRST
          Navigator.of(context).pop();

          logger(
            'EqubDetailScreen Listener: Payment Failure: ${state.failure.errorMessage}',
          );
          Get.rawSnackbar(
            message: state.failure.errorMessage,
            backgroundColor: Colors.red,
          );
        } else if (state is EqubDetailLeaveSuccess) {
          // Close confirmation dialog
          Get.back();
          // Close EqubDetailScreen
          Get.back();
          
          Get.rawSnackbar(
            message: "Successfully left the Equb group",
            backgroundColor: Colors.green,
          );
        } else if (state is EqubDetailLeaveFailure) {
          // Close the dialog so user can see error on screen
          Get.back();
          Get.rawSnackbar(
            message: state.failure.errorMessage,
            backgroundColor: Colors.red,
          );
        }
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
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: CustomText(
            title: 'group_detail'.tr,
            fontSize: 18.sp,
            textColor: appColors.titleTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        body: BlocBuilder<EqubDetailBloc, EqubDetailState>(
          buildWhen: (previous, current) =>
              current is EqubDetailLoading ||
              current is EqubDetailSuccess ||
              current is EqubDetailFailure,
          builder: (context, state) {
            if (state is EqubDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is EqubDetailFailure) {
              return Center(
                child: CustomText(title: state.failure.errorMessage),
              );
            }
            if (state is EqubDetailSuccess) {
              // Ensure we are showing data for the requested group
              if (state.groupId != widget.groupId) {
                return const Center(child: CircularProgressIndicator());
              }
              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _buildHeader(state, appColors, isDark),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: appColors.primaryColor,
                          unselectedLabelColor: appColors.bodyTextSmallColor,
                          indicatorColor: appColors.primaryColor,
                          indicatorWeight: 3,
                          tabs: [
                            Tab(text: 'payment'.tr),
                            Tab(text: 'history'.tr),
                            Tab(text: 'draw'.tr),
                          ],
                        ),
                        backgroundColor: appColors.scaffoldBackgroundColor,
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _PaymentTab(
                      group: state.group,
                      payments: state.payments,
                      schedule: state.schedule,
                    ),
                    _HistoryTab(payments: state.payments),
                    _DrawTab(draws: state.draws),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        bottomNavigationBar: BlocBuilder<EqubDetailBloc, EqubDetailState>(
          builder: (context, state) {
            if (state is! EqubDetailSuccess) return const SizedBox.shrink();

            final membership = state.group.memberships?.firstOrNull;
            if (membership == null) return const SizedBox.shrink();

            // Leaving is only allowed before the first contribution.
            final canLeave = (membership.contributedAmount ?? 0) <= 0;

            // The next instalment that can actually be paid. Overdue first,
            // then today's, then the soonest upcoming one — so the button
            // always settles whatever is most urgent.
            final payable = _nextPayable(state.schedule);

            if (payable == null && !canLeave) return const SizedBox.shrink();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (payable != null)
                      RoundedButton(
                        label: _payLabel(payable, state.group),
                        height: 52.h,
                        borderRadius: 14.r,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        backgroundColor: appColors.primaryColor,
                        foregroundColor: Colors.white,
                        icon: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        onPressed: () => _showPaymentConfirmationDialog(
                          context,
                          payable.dueDate,
                          state.group,
                          appColors,
                        ),
                      ),
                    if (payable != null && canLeave) SizedBox(height: 10.h),
                    if (canLeave)
                      TextButton(
                        onPressed: () =>
                            _showLeaveConfirmation(context, membership.id!),
                        style: TextButton.styleFrom(
                          minimumSize: Size(double.infinity, 46.h),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 18.sp),
                            SizedBox(width: 8.w),
                            CustomText(
                              title: "leave_equb_group".tr,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              textColor: Colors.redAccent,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(EqubDetailSuccess state, AppColors appColors, bool isDark) {
    final group = state.group;
    final membership = group.memberships?.firstOrNull;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
      margin: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: (appColors.borderColor ?? Colors.grey).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CustomText(
                        title: group.name ?? group.packageName ?? 'Equb',
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        textColor: appColors.titleTextColor,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: CustomText(
                        title:
                            '${group.birrPerDay?.toStringAsFixed(0)} ETB • ${group.frequencyLabel?.tr}',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        textColor: appColors.primaryColor,
                      ),
                    ),
                    if (membership?.nextDrawDate != null) ...[
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                                .withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 16.sp,
                              color: appColors.primaryColor,
                            ),
                            SizedBox(width: 6.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText(
                                  title: "next_draw".tr.toUpperCase(),
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w800,
                                  textColor: appColors.primaryColor?.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                ),
                                CustomText(
                                  title: DateFormat('MMMM dd, yyyy').format(
                                    DateTime.parse(membership!.nextDrawDate!),
                                  ),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  textColor: appColors.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                children: [
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColors.primaryColor ?? AppStaticColor.primaryAmber,
                          (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                              .withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18.r),
                      boxShadow: [
                        BoxShadow(
                          color: (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                              .withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insights_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            CustomText(
                              title: 'Conversion Rate'.tr,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              textColor: Colors.white.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            CustomText(
                              title: '1 USD ≈ ',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              textColor: Colors.white.withValues(alpha: 0.8),
                            ),
                            CustomText(
                              title:
                                  '${state.exchangeRate != null ? state.exchangeRate!.toStringAsFixed(2) : "57.50"}',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900,
                              textColor: Colors.white,
                            ),
                            CustomText(
                              title: ' ETB',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              textColor: Colors.white.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (membership != null) ...[
            SizedBox(height: 16.h),
            _buildProgressSection(membership, appColors),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(
    EqubMembership membership,
    AppColors appColors,
  ) {
    final contributed = membership.contributedAmount ?? 0.0;
    final expected = membership.expectedTotalAmount ?? 0.0;
    final progress = expected > 0 ? (contributed / expected).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: 'amount_contributed'.tr,
                  fontSize: 11.sp,
                  textColor: appColors.bodyTextSmallColor,
                  fontWeight: FontWeight.w500,
                ),
                SizedBox(height: 2.h),
                CustomText(
                  title: '${contributed.toStringAsFixed(0)} ETB',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  textColor: appColors.titleTextColor,
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: (appColors.primaryColor ?? AppStaticColor.primaryAmber)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: CustomText(
                title: '${(progress * 100).toStringAsFixed(0)}%',
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
                textColor: appColors.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Stack(
          children: [
            Container(
              height: 8.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: appColors.primaryColor!.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: 8.h,
              width: (MediaQuery.of(context).size.width - 56.w) * progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    appColors.primaryColor!,
                    appColors.primaryColor!.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(4.r),
                boxShadow: [
                  BoxShadow(
                    color: appColors.primaryColor!.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

      ],
    );
  }

  /// The instalment the Pay Now button should settle.
  ///
  /// Overdue beats today's, which beats the soonest upcoming one, so the
  /// button always clears the most pressing debt first.
  PaymentScheduleItem? _nextPayable(List<PaymentScheduleItem> schedule) {
    final open = schedule
        .where(
          (s) =>
              s.status == PaymentScheduleStatus.unpaid ||
              s.status == PaymentScheduleStatus.pending ||
              s.status == PaymentScheduleStatus.future,
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (open.isEmpty) return null;

    return open.firstWhere(
      (s) => s.status == PaymentScheduleStatus.unpaid,
      orElse: () => open.firstWhere(
        (s) => s.status == PaymentScheduleStatus.pending,
        orElse: () => open.first,
      ),
    );
  }

  /// "Pay Now · 1,210 ETB", or plain "Pay Now" if the amount is unknown.
  String _payLabel(PaymentScheduleItem item, EqubGroup group) {
    final amount = group.birrPerDay;
    if (amount == null) return 'pay_now'.tr;

    final formatted = NumberFormat('#,###').format(amount);
    return '${'pay_now'.tr}  •  $formatted ETB';
  }

  /// Leaving is destructive and cannot be undone, so it asks the member to
  /// type a confirmation phrase rather than tap a red button by reflex.
  ///
  /// The phrase follows the app language — an Amharic user types the Amharic
  /// words, an Afaan Oromoo user types theirs — so nobody is asked to copy
  /// characters off an English keyboard they aren't using.
  void _showLeaveConfirmation(BuildContext context, int membershipId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: context.read<EqubDetailBloc>(),
        child: _LeaveConfirmationDialog(membershipId: membershipId),
      ),
    );
  }
}

class _LeaveConfirmationDialog extends StatefulWidget {
  final int membershipId;

  const _LeaveConfirmationDialog({required this.membershipId});

  @override
  State<_LeaveConfirmationDialog> createState() =>
      _LeaveConfirmationDialogState();
}

class _LeaveConfirmationDialogState extends State<_LeaveConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();

  /// What the member has to type, in the language they are using.
  late final String _phrase = 'leave_confirm_phrase'.tr;

  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Forgiving on case and stray spaces — the point is deliberate intent,
      // not a typing test.
      final typed = _controller.text.trim().toLowerCase();
      final target = _phrase.trim().toLowerCase();
      final next = typed == target;
      if (next != _matches) setState(() => _matches = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Dialog(
      backgroundColor: appColors.accentColor,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 20.h),
              CustomText(
                title: "leave_confirmation_title".tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                textAlign: TextAlign.center,
                textColor: appColors.titleTextColor,
              ),
              SizedBox(height: 12.h),
              CustomText(
                title: "leave_confirmation_message".tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                textAlign: TextAlign.center,
                textColor: appColors.bodyTextSmallColor,
              ),
              SizedBox(height: 20.h),

              // The phrase, shown as something to copy rather than as prose.
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    CustomText(
                      title: "leave_type_to_confirm".tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      textAlign: TextAlign.center,
                      textColor: appColors.bodyTextSmallColor,
                    ),
                    SizedBox(height: 6.h),
                    CustomText(
                      title: _phrase,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      textAlign: TextAlign.center,
                      textColor: Colors.redAccent,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              TextField(
                controller: _controller,
                autocorrect: false,
                enableSuggestions: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: appColors.titleTextColor,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _phrase,
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: appColors.bodyTextSmallColor?.withValues(alpha: 0.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 14.h,
                  ),
                  suffixIcon: _matches
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20.sp,
                        )
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: appColors.borderColor ?? Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: _matches ? Colors.green : Colors.redAccent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: CustomText(
                        title: "cancel".tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        textColor: appColors.bodyTextSmallColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: BlocBuilder<EqubDetailBloc, EqubDetailState>(
                      builder: (context, state) {
                        final isLoading = state is EqubDetailLeaveLoading;
                        return RoundedButton(
                          label: "leave".tr,
                          submitting: isLoading,
                          // Stays inert until the phrase matches, so the
                          // action can't happen by reflex.
                          onPressed: (!_matches || isLoading)
                              ? null
                              : () {
                                  context.read<EqubDetailBloc>().add(
                                    EqubDetailLeaveEvent(widget.membershipId),
                                  );
                                },
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.redAccent.withValues(alpha: 0.25),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.7),
                          borderRadius: 12.r,
                          height: 45.h,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTab extends StatelessWidget {
  final EqubGroup group;
  final List<EqubPayment> payments;
  final List<PaymentScheduleItem> schedule;

  const _PaymentTab({
    required this.group,
    required this.payments,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Determine the earliest date for the calendar to start
    DateTime firstDay = DateTime.parse(group.equbStartDate ?? now.toString());
    final membership = group.memberships?.firstOrNull;
    if (membership?.joinDate != null) {
      final joinDate = DateTime.parse(membership!.joinDate!);
      if (joinDate.isBefore(firstDay)) firstDay = joinDate;
    }
    for (final p in payments) {
      if (p.paymentDate != null) {
        final pDate = DateTime.parse(p.paymentDate!);
        if (pDate.isBefore(firstDay)) firstDay = pDate;
      }
    }

    final lastDay = DateTime.parse(
      group.equbEndDate ?? now.add(const Duration(days: 365)).toString(),
    );

    // Ensure focusedDay is within firstDay and lastDay
    DateTime focusedDay = now;
    if (focusedDay.isBefore(firstDay)) {
      focusedDay = firstDay;
    } else if (focusedDay.isAfter(lastDay)) {
      focusedDay = lastDay;
    }

    bool isSameDayLocal(DateTime d1, DateTime d2) {
      final local1 = d1.toLocal();
      final local2 = d2.toLocal();
      return local1.year == local2.year &&
          local1.month == local2.month &&
          local1.day == local2.day;
    }

    Widget buildDayMarker(
      DateTime day, {
      required PaymentScheduleStatus? status,
    }) {
      final now = DateTime.now();
      final isDateToday = isSameDayLocal(day, now);

      if (status == PaymentScheduleStatus.paid) {
        return Container(
          margin: const EdgeInsets.all(6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '${day.day}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      if (status == PaymentScheduleStatus.unpaid) {
        return Container(
          margin: const EdgeInsets.all(6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      if (status == PaymentScheduleStatus.pending || isDateToday) {
        final color = appColors.primaryColor ?? AppStaticColor.primaryAmber;
        return Container(
          margin: const EdgeInsets.all(6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 1.5,
            ),
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      if (status == PaymentScheduleStatus.future) {
        return Container(
          margin: const EdgeInsets.all(6.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      return Container(
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: appColors.titleTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: appColors.accentColor,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: appColors.borderColor!.withValues(alpha: 0.5),
              ),
            ),
            child: TableCalendar(
              availableGestures: AvailableGestures.horizontalSwipe,
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: focusedDay,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: appColors.bodyTextSmallColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                ),
                weekendStyle: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: appColors.titleTextColor,
                  letterSpacing: 0.5,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: appColors.primaryColor,
                  size: 28.r,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: appColors.primaryColor,
                  size: 28.r,
                ),
                headerPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(
                  color: appColors.titleTextColor,
                  fontWeight: FontWeight.w500,
                ),
                // Builders will handle decorations
                todayDecoration: const BoxDecoration(),
                selectedDecoration: const BoxDecoration(),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                // Find schedule item for this day
                // Normalize dates to avoid time issues
                final sDay = selectedDay.toLocal();
                final item = schedule.firstWhereOrNull((s) {
                  final d = s.dueDate.toLocal();
                  return d.year == sDay.year &&
                      d.month == sDay.month &&
                      d.day == sDay.day;
                });

                // Only allow selection if the item exists and is unpaid or future
                if (item != null &&
                    (item.status == PaymentScheduleStatus.pending ||
                        item.status == PaymentScheduleStatus.unpaid ||
                        item.status == PaymentScheduleStatus.future)) {
                  _showPaymentConfirmationDialog(
                    context,
                    selectedDay,
                    group,
                    appColors,
                  );
                }
              },
              calendarBuilders: CalendarBuilders(
                todayBuilder: (context, day, focusedDay) {
                  // Find schedule item for this day
                  final item = schedule.firstWhereOrNull(
                    (s) => isSameDayLocal(s.dueDate, day),
                  );
                  return buildDayMarker(day, status: item?.status);
                },
                defaultBuilder: (context, day, focusedDay) {
                  final item = schedule.firstWhereOrNull(
                    (s) => isSameDayLocal(s.dueDate, day),
                  );
                  return buildDayMarker(day, status: item?.status);
                },
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildLegend(appColors),
        ],
      ),
    );
  }

  Widget _buildLegend(AppColors appColors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16.w,
        runSpacing: 8.h,
        children: [
          _legendItem(Colors.green.shade600, 'paid'.tr, appColors),
          _legendItem(Colors.redAccent, 'overdue'.tr, appColors),
          _legendItem(appColors.primaryColor ?? AppStaticColor.primaryAmber, 'due_today'.tr, appColors),
          _legendItem(Colors.blue.shade400, 'future'.tr, appColors),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, AppColors appColors) {
    return Row(
      children: [
        Container(
          width: 12.r,
          height: 12.r,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              if (color == Colors.green.shade600)
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
        ),
        SizedBox(width: 6.w),
        CustomText(
          title: label,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          textColor: appColors.bodyTextSmallColor,
        ),
      ],
    );
  }
}

void _showPaymentConfirmationDialog(
  BuildContext context,
  DateTime day,
  EqubGroup group,
  AppColors appColors,
) {
  final membership = group.memberships?.firstWhereOrNull((m) => true);
  if (membership == null || membership.id == null) {
    Get.rawSnackbar(
      message: "no_membership_found".tr,
      backgroundColor: Colors.orange,
    );
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) {
      return BlocProvider.value(
        value: context.read<EqubDetailBloc>(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: appColors.accentColor,
              borderRadius: BorderRadius.circular(32.r),
              border: Border.all(
                color: appColors.borderColor!.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: appColors.primaryColor!.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: appColors.primaryColor,
                    size: 40.r,
                  ),
                ),
                SizedBox(height: 20.h),
                CustomText(
                  title: 'payment_confirmation'.tr,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  textColor: appColors.titleTextColor,
                ),
                SizedBox(height: 12.h),
                CustomText(
                  title:
                      '${'confirm_payment_msg'.tr} ${group.birrPerDay?.toStringAsFixed(0)} ETB?',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextColor,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          alignment: Alignment.center,
                          child: CustomText(
                            title: 'cancel'.tr,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            textColor: appColors.bodyTextSmallColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: BlocBuilder<EqubDetailBloc, EqubDetailState>(
                        builder: (context, state) {
                          final isLoading = state is EqubDetailPaymentLoading;
                          return RoundedButton(
                            label: 'confirm'.tr,
                            onPressed: () {
                              final dateStr = DateFormat(
                                'yyyy-MM-dd',
                              ).format(day);
                              context.read<EqubDetailBloc>().add(
                                EqubDetailInitiatePaymentEvent(
                                  membershipId: membership.id!,
                                  amount: group.birrPerDay!.toDouble(),
                                  paymentDate: dateStr,
                                ),
                              );
                            },
                            submitting: isLoading,
                            backgroundColor: appColors.primaryColor,
                            foregroundColor: Colors.white,
                            fontSize: 15.sp,
                            height: 50.h,
                            borderRadius: 16.r,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _HistoryTab extends StatelessWidget {
  final List<EqubPayment> payments;

  const _HistoryTab({required this.payments});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    if (payments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment_rounded,
                size: 64.r,
                color: appColors.bodyTextSmallColor?.withValues(alpha: 0.5),
              ),
              SizedBox(height: 16.h),
              CustomText(
                title: 'no_payments'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                textColor: appColors.bodyTextSmallColor,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(20.r),
      itemCount: payments.length,
      separatorBuilder: (_, _) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final p = payments[index];
        final isPaid = p.isPaid;
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: appColors.accentColor,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: appColors.borderColor!.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52.r,
                width: 52.r,
                decoration: BoxDecoration(
                  color: (isPaid ? Colors.green : Colors.orange).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : Icons.history_toggle_off_rounded,
                  color: isPaid ? Colors.green : Colors.orange,
                  size: 26.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      title: '${p.amount?.toStringAsFixed(0)} ETB',
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      textColor: appColors.titleTextColor,
                    ),
                    SizedBox(height: 6.h),
                    CustomText(
                      title: p.paymentDate != null
                          ? DateFormat(
                              'MMM dd, yyyy',
                            ).format(DateTime.parse(p.paymentDate!))
                          : 'N/A',
                      fontSize: 12.sp,
                      textColor: appColors.bodyTextSmallColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: (isPaid ? Colors.green : Colors.orange).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CustomText(
                  title: (p.status ?? 'pending').tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  textColor: isPaid ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DrawTab extends StatelessWidget {
  final List<EqubDraw> draws;

  const _DrawTab({required this.draws});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return BlocBuilder<EqubDetailBloc, EqubDetailState>(
      buildWhen: (previous, current) => current is EqubDetailSuccess,
      builder: (context, state) {
        if (state is! EqubDetailSuccess) return const SizedBox.shrink();

        final isDrawing = state.isDrawing;
        final winnerNameReveal = state.winnerName;

        if (isDrawing || winnerNameReveal != null) {
          return _RealTimeDrawAnimation(
            isDrawing: isDrawing,
            winnerName: winnerNameReveal,
            candidates: state.candidates,
          );
        }

        if (draws.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 64.r,
                    color: appColors.bodyTextSmallColor?.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 16.h),
                  CustomText(
                    title: 'no_draws_yet'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20.r),
          itemCount: draws.length,
          separatorBuilder: (_, _) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            final d = draws[index];
            final winnerName = d.winnerMemberName ?? d.winner?['name'] ?? 'N/A';
            // ignore: unused_local_variable
            final initialAmount = d.winnerExpectedTotalAmount ?? 0.0;

            return Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFB8860B), // Dark Goldenrod
                    const Color(0xFFDAA520), // Goldenrod
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDAA520).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 100.r,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              d.drawDate != null
                                  ? DateFormat(
                                      'EEEE, MMM dd, yyyy',
                                      Get.locale?.toString(),
                                    ).format(DateTime.parse(d.drawDate!))
                                  : '',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'congratulations'.tr.toUpperCase(),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              winnerName,
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                'you_won_umrah'.tr,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: appColors.primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RealTimeDrawAnimation extends StatefulWidget {
  final bool isDrawing;
  final String? winnerName;
  final List<String> candidates;

  const _RealTimeDrawAnimation({
    required this.isDrawing,
    required this.winnerName,
    required this.candidates,
  });

  @override
  State<_RealTimeDrawAnimation> createState() => _RealTimeDrawAnimationState();
}

class _RealTimeDrawAnimationState extends State<_RealTimeDrawAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<String> _placeholderNames = [
    'Aman',
    'Betty',
    'Chala',
    'Dawit',
    'Elias',
    'Fana',
    'Gadisa',
    'Hawi',
    'Ibsa',
    'Jira',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat();
  }

  @override
  void didUpdateWidget(_RealTimeDrawAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isDrawing && widget.winnerName != null) {
      // Slow down and stop
      _controller.duration = const Duration(seconds: 1);
      _controller.forward(from: _controller.value);
    } else if (widget.isDrawing && !oldWidget.isDrawing) {
      _controller.duration = const Duration(milliseconds: 200);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomText(
            title: widget.isDrawing ? 'draw_in_progress'.tr : 'winner_found'.tr,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            textColor: appColors.titleTextColor,
          ),
          SizedBox(height: 32.h),
          Container(
            height: 120.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: appColors.accentColor,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: appColors.primaryColor!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: appColors.primaryColor!.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      if (!widget.isDrawing && widget.winnerName != null) {
                        return Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(seconds: 1),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: CustomText(
                                  title: widget.winnerName!,
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.w900,
                                  textColor: appColors.primaryColor,
                                ),
                              );
                            },
                          ),
                        );
                      }

                      final candidates = widget.candidates.isNotEmpty
                          ? widget.candidates
                          : _placeholderNames;
                      final count = candidates.length;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.3,
                            child: CustomText(
                              title: candidates[(_controller.value * count)
                                      .floor() %
                                  count],
                              fontSize: 20.sp,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          CustomText(
                            title: candidates[((_controller.value + 0.1) *
                                        count)
                                    .floor() %
                                count],
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            textColor: appColors.primaryColor,
                          ),
                          SizedBox(height: 10.h),
                          Opacity(
                            opacity: 0.3,
                            child: CustomText(
                              title: candidates[((_controller.value + 0.2) *
                                          count)
                                      .floor() %
                                  count],
                              fontSize: 20.sp,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Glow overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColors.accentColor!,
                          Colors.transparent,
                          Colors.transparent,
                          appColors.accentColor!,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isDrawing) ...[
            SizedBox(height: 48.h),
            const CircularProgressIndicator(),
            SizedBox(height: 16.h),
            CustomText(
              title: "waiting_for_result".tr,
              fontSize: 14.sp,
              textColor: appColors.bodyTextSmallColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this.tabBar, {this.backgroundColor});

  final TabBar tabBar;
  final Color? backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
