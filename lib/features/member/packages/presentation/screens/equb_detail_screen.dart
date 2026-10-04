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
import 'package:niya_equb/core/service/payments/dashen_superapp.dart';
import 'package:niya_equb/core/service/payments/payment_bridge.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_bloc.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_event.dart';
import 'package:niya_equb/features/member/packages/state/equb_detail_state.dart';
import 'package:niya_equb/shared/presentation/screens/payment_webview_screen.dart';
import 'package:niya_equb/shared/presentation/screens/terms_screen.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';
import 'package:niya_equb/shared/presentation/widgets/bank_picker.dart';
import 'package:niya_equb/shared/widgets/rounded_button.dart';
import 'package:niya_equb/shared/widgets/custom_text.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/payments/logic/payment_calculator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:niya_equb/core/service/notification_service.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';

class EqubDetailScreen extends StatefulWidget {
  final int groupId;
  final int? initialTab;
  final String? drawType;
  final String? winnerName;
  final List<String>? candidates;
  final DateTime? drawTime;

  /// A payment to carry on confirming as soon as the screen opens.
  ///
  /// Set when the app comes back from the bank app by way of a full page
  /// reload, which is what the Dashen SuperApp does: everything in memory is
  /// gone, including the watch the screen had started, and this is how it is
  /// picked up again. See PreferencesService.takePaymentReturn().
  final String? awaitReference;

  /// See EqubDetailAwaitSettlementEvent.quietIfUnresolved.
  final bool awaitQuietly;
  static const String routeName = '/equb-detail';

  const EqubDetailScreen({
    super.key,
    required this.groupId,
    this.initialTab,
    this.drawType,
    this.winnerName,
    this.candidates,
    this.drawTime,
    this.awaitReference,
    this.awaitQuietly = false,
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
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );

    context.read<EqubDetailBloc>().add(EqubDetailLoadEvent(widget.groupId));
    _applyInitialDrawState();

    final resume = widget.awaitReference;
    if (resume != null && resume.isNotEmpty) {
      context.read<EqubDetailBloc>().add(
        EqubDetailAwaitSettlementEvent(
          groupId: widget.groupId,
          reference: resume,
          quietIfUnresolved: widget.awaitQuietly,
        ),
      );
    }

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

  /// Tells the member how confirming their payment ended, once.
  ///
  /// Every message says only what the bank has actually said. "Still
  /// confirming" is not dressed up as a failure: the server keeps asking the
  /// bank on its own schedule and the contribution updates when it lands.
  void _announceSettlement(BuildContext context, SettlementWatch settlement) {
    String? message;
    Color background = const Color(0xFF2E3A46);

    if (settlement == SettlementWatch.confirmed) {
      message = 'payment_confirmed'.tr;
      background = const Color(0xFF1E7A4C);
    } else if (settlement == SettlementWatch.failed) {
      message = 'payment_bank_declined'.tr;
      background = const Color(0xFFB01F2E);
    } else if (settlement == SettlementWatch.stillPending) {
      message = 'payment_still_confirming'.tr;
    }

    if (message == null) return;

    Get.rawSnackbar(
      message: message,
      backgroundColor: background,
      duration: const Duration(seconds: 5),
    );
    context.read<EqubDetailBloc>().add(const EqubDetailSettlementSeenEvent());
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<EqubDetailBloc, EqubDetailState>(
      listenWhen: (previous, current) =>
          current is EqubDetailPaymentSuccess ||
          current is EqubDetailPaymentChooseBank ||
          current is EqubDetailPaymentFailure ||
          current is EqubDetailLeaveSuccess ||
          current is EqubDetailLeaveFailure ||
          (current is EqubDetailSuccess &&
              (previous is! EqubDetailSuccess ||
                  previous.isDrawing != current.isDrawing ||
                  previous.settlement != current.settlement)),
      listener: (context, state) {
        logger('EqubDetailScreen Listener: state index = ${state.runtimeType}');

        if (state is EqubDetailSuccess) {
          _announceSettlement(context, state.settlement);
        }

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

          logger('EqubDetailScreen Listener: Presenting the bank order...');

          // If the bank app reloads this page on the way back, which the
          // Dashen SuperApp does, everything in memory is gone. This is what
          // lets the app come back to this Equb and carry on confirming the
          // payment rather than dropping the member on the home screen.
          PreferencesService.savePaymentReturn(
            groupId: widget.groupId,
            reference: state.session.reference,
          );

          Get.to(
            () => PaymentWebViewScreen(
              session: state.session,
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

            // Back in the app, so the breadcrumb has done its job.
            PreferencesService.clearPaymentReturn();

            if (result != true && context.mounted) {
              // Cancelled or backed out. The attempt still exists on the
              // server and may yet complete, so show its current state once,
              // quietly — without claiming anything about it.
              context.read<EqubDetailBloc>().add(
                EqubDetailLoadEvent(widget.groupId, isSilent: true),
              );
            }

            if (result == true) {
              if (context.mounted) {
                // Watch, not read once. The server asks the bank after it
                // answers a read, so a single immediate read could only ever
                // show this payment as unconfirmed — which is what Dashen's QA
                // saw as a paid contribution missing from History, progress
                // stuck at 0% and no draw eligibility.
                context.read<EqubDetailBloc>().add(
                  EqubDetailAwaitSettlementEvent(
                    groupId: widget.groupId,
                    reference: state.session.reference,
                  ),
                );
                // NOT "Payment successful", and deliberately not green.
                //
                // Nothing at this point knows whether any money moved.
                // Popping true from PaymentWebViewScreen means "go and re-read
                // this contribution from the server" — that screen's own
                // docblock says exactly that — and on a phone the ONLY route
                // here is the member pressing "I've paid, check now", which is
                // a self-assertion with no bank involved at all.
                //
                // The old message told them the opposite of the truth, and the
                // schedule directly beneath it went on showing the
                // contribution as unpaid, because that reads server status.
                // The screen contradicted itself in the same frame.
                //
                // This is the one line in the client that was deciding a
                // contribution had settled. Settlement is the server's to
                // declare, once the bank has confirmed it.
                Get.rawSnackbar(
                  message: "payment_checking".tr,
                  backgroundColor: const Color(0xFF2E3A46),
                  duration: const Duration(seconds: 4),
                );
              }
            }
          });
        } else if (state is EqubDetailPaymentChooseBank) {
          // More than one bank is live. Ask, then re-dispatch the event the
          // bloc handed back — not a rebuilt one, so the second attempt covers
          // exactly the places and date the member confirmed.
          //
          // The confirmation dialog is deliberately left open: the member is
          // still mid-decision, and closing it would drop them back to the
          // Equb screen if they dismissed the bank sheet.
          logger(
            'EqubDetailScreen Listener: ${state.banks.length} banks available, asking.',
          );

          final bloc = context.read<EqubDetailBloc>();

          pickPaymentBank(context, state.banks).then((bank) {
            if (bank == null) return;

            final pending = state.pendingEvent;
            if (pending is EqubDetailInitiateBatchPaymentEvent) {
              bloc.add(pending.withProvider(bank.slug));
            } else if (pending is EqubDetailInitiatePaymentEvent) {
              bloc.add(pending.withProvider(bank.slug));
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
                    if (state.settlement == SettlementWatch.confirming)
                      const SliverToBoxAdapter(child: _ConfirmingBanner()),
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
                            // The Equb's terms, to read again at any time.
                            Tab(text: 'pkg_terms_tab'.tr),
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
                    _DrawTab(
                      draws: state.draws,
                      places: state.group.myPlaces,
                    ),
                    _TermsTab(group: state.group),
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

            final membership = state.group.myMembership;
            if (membership == null) return const SizedBox.shrink();

            // Whether leaving is allowed. The server decides when it has an
            // opinion; see EqubMembership.canLeaveEqub for the fallback.
            //
            // This used to be `contributedAmount <= 0`, which never looked at
            // whether the member had won. Someone who took the pot in round 1
            // before their own contribution was reconciled had a zero
            // contributed amount, saw the Leave button, and could walk out
            // holding everyone else's money. A member who has NOT won keeps
            // the button exactly as before.
            final canLeave = membership.canLeaveEqub;
            final blockReason = membership.exitBlockReason;

            // Shown to a member who has won and still owes rounds. Not an
            // error — they are mid-obligation, and the amount is the point.
            final showObligation =
                membership.hasReceivedPayout && (membership.remainingAmount ?? 0) > 0;

            // The next instalment that can actually be paid. Overdue first,
            // then today's, then the soonest upcoming one — so the button
            // always settles whatever is most urgent.
            final payable = _nextPayable(state.schedule);

            if (payable == null && !canLeave && !showObligation) {
              return const SizedBox.shrink();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showObligation) ...[
                      _WinnerObligationBanner(
                        remaining: membership.remainingAmount ?? 0,
                        reason: blockReason,
                      ),
                      SizedBox(height: 10.h),
                    ],
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
                          state.schedule,
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
    final membership = group.myMembership;
    // Never a day that has gone by. See EqubMembership.upcomingDrawDate.
    final nextDraw = membership?.upcomingDrawDate;
    final rate = state.exchangeRate;

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
                    if (nextDraw != null) ...[
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
                            // Flexible, and the date scaled down rather than
                            // clipped: this chip shares the row with the
                            // conversion-rate card on a narrow phone.
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                    title: "next_draw".tr.toUpperCase(),
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w800,
                                    textColor: appColors.primaryColor?.withValues(alpha: 0.7),
                                    letterSpacing: 0.5,
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: CustomText(
                                      title: DateFormat('MMMM dd, yyyy').format(nextDraw),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      textColor: appColors.primaryColor,
                                      maxLines: 1,
                                    ),
                                  ),
                                  CustomText(
                                    title: _relativeDay(nextDraw),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    textColor: appColors.primaryColor?.withValues(alpha: 0.8),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
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
                              // Set by an admin at Exchange Rate in the admin
                              // panel. A dash rather than a built-in figure
                              // when it cannot be read: a stale rate shown as
                              // current is worse than none.
                              title: rate != null
                                  ? NumberFormat('#,##0.00').format(rate)
                                  : '—',
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
            _buildProgressSection(group, appColors),
          ],
        ],
      ),
    );
  }

  /// Progress across everything the member pays for here.
  ///
  /// Summed over every place rather than read off their own membership: a
  /// member carrying two places has paid twice as much and owes twice as much,
  /// and a bar built from one place would report them further along than they
  /// are.
  Widget _buildProgressSection(
    EqubGroup group,
    AppColors appColors,
  ) {
    var contributed = 0.0;
    var expected = 0.0;

    for (final place in group.myPlaces) {
      contributed += place.contributedAmount ?? 0.0;
      expected += place.expectedTotalAmount ?? 0.0;
    }

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

  /// "Pay Now · 140,000 ETB", or plain "Pay Now" if the amount is unknown.
  ///
  /// The figure is the member's whole bill for the round: their own
  /// contribution plus one for every place they hold under "My Responsibility
  /// People". Quoting their own share alone was the bug — the button promised
  /// one amount and checkout asked for another.
  String _payLabel(PaymentScheduleItem item, EqubGroup group) {
    // The same figure the confirmation dialog charges: only the places that
    // still owe this date. See _roundStillOwed.
    final owed = _roundStillOwed(group, item.dueDate);
    final amount = owed.total > 0
        ? owed.total
        : (group.birrPerDay?.toDouble() ?? 0);

    if (amount <= 0) return 'pay_now'.tr;

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

/// Tells a member who has won why this Equb cannot be left, and what is left
/// to pay.
///
/// Deliberately framed as an obligation rather than a refusal. The member is
/// not being punished — they have received the pot, and the remaining rounds
/// are what everyone else is still owed. Hiding the Leave button with no
/// explanation reads as a broken app; this reads as the rule it is.
class _WinnerObligationBanner extends StatelessWidget {
  final double remaining;
  final String? reason;

  const _WinnerObligationBanner({required this.remaining, this.reason});

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final formatted = NumberFormat('#,##0').format(remaining);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            size: 18.sp,
            color: const Color(0xFFB45309),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: 'winner_obligation_title'.tr,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                  textColor: const Color(0xFF92400E),
                ),
                SizedBox(height: 3.h),
                CustomText(
                  title: reason?.isNotEmpty == true
                      ? reason!
                      : 'winner_obligation_body'.trParams({
                          'amount': '$formatted ETB',
                        }),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextColor,
                ),
              ],
            ),
          ),
        ],
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

/// The payment calendar: every round of this Equb, coloured by its status.
///
/// Stateful because the month on screen belongs to the member. It used to be
/// worked out from today's date on every build, so any refresh of this screen
/// (the settlement watch re-reads the Equb every few seconds after a payment)
/// threw a member who had paged back to an earlier month straight back to
/// this one, which made the arrows look broken.
///
/// The month header is drawn here rather than by TableCalendar, for three
/// reasons: an arrow that cannot go any further now looks disabled instead of
/// silently doing nothing, there is room for a Today button, and the member's
/// start date can be shown and jumped to.
class _PaymentTab extends StatefulWidget {
  final EqubGroup group;
  final List<EqubPayment> payments;
  final List<PaymentScheduleItem> schedule;

  const _PaymentTab({
    required this.group,
    required this.payments,
    required this.schedule,
  });

  @override
  State<_PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<_PaymentTab> {
  /// The month on screen. Null until the member first moves it, which means
  /// "today's month".
  DateTime? _focusedDay;

  EqubGroup get group => widget.group;
  List<PaymentScheduleItem> get schedule => widget.schedule;

  /// A calendar day the way TableCalendar keys its days: midnight UTC, built
  /// from the value's own year, month and day.
  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// The day an instant from the server falls on, as the member sees it.
  static DateTime _localDay(DateTime d) => _day(d.toLocal());

  /// The day a server date falls on, read the same way as the rounds: a
  /// timestamp is moved to the phone's timezone first, a bare date is taken
  /// as it is. Reading the two differently put the start flag one cell away
  /// from the first round on a phone behind the server's timezone.
  static DateTime? _serverDay(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return null;
    return raw!.length > 10 ? _localDay(parsed) : _day(parsed);
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static DateTime _clamp(DateTime d, DateTime first, DateTime last) =>
      d.isBefore(first) ? first : (d.isAfter(last) ? last : d);

  /// The days the calendar lets the member reach: from the earliest of the
  /// Equb's start, their join date, their first payment and their first round,
  /// to the latest of the Equb's end and their last round. Every round is
  /// always reachable, including when the Equb's own dates disagree with it.
  ({DateTime first, DateTime last}) _range(DateTime today) {
    var first = _serverDay(group.equbStartDate) ?? today;
    var last =
        _serverDay(group.equbEndDate) ?? today.add(const Duration(days: 365));

    final known = <DateTime>[
      if (_serverDay(group.myMembership?.joinDate) case final joined?) joined,
      for (final p in widget.payments)
        if (_serverDay(p.paymentDate) case final paidOn?) paidOn,
      for (final s in schedule) _localDay(s.dueDate),
    ];

    for (final d in known) {
      if (d.isBefore(first)) first = d;
      if (d.isAfter(last)) last = d;
    }

    if (last.isBefore(first)) last = first;
    return (first: first, last: last);
  }

  /// The member's first day in this Equb: the day they joined, else their
  /// first round, else the Equb's own start date.
  DateTime? _startDay() {
    final joined = _serverDay(group.myMembership?.joinDate);
    if (joined != null) return joined;

    DateTime? earliest;
    for (final s in schedule) {
      final d = _localDay(s.dueDate);
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    return earliest ?? _serverDay(group.equbStartDate);
  }

  void _showMonth(DateTime day, DateTime first, DateTime last) {
    setState(() => _focusedDay = _clamp(_day(day), first, last));
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = appColors.primaryColor ?? AppStaticColor.primaryAmber;
    final border = appColors.borderColor ?? Colors.grey;

    final today = _day(DateTime.now());
    final range = _range(today);
    final focused = _clamp(_focusedDay ?? today, range.first, range.last);
    final start = _startDay();

    // One lookup per day rather than a search of the whole schedule for each
    // of the forty-odd cells on every build.
    final byDay = <DateTime, PaymentScheduleItem>{
      for (final s in schedule) _localDay(s.dueDate): s,
    };

    final paidRounds =
        schedule.where((s) => s.status == PaymentScheduleStatus.paid).length;
    final overdueRounds =
        schedule.where((s) => s.status == PaymentScheduleStatus.unpaid).length;
    final upcoming = schedule
        .where(
          (s) =>
              s.status != PaymentScheduleStatus.paid &&
              !_localDay(s.dueDate).isBefore(today),
        )
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextDue = upcoming.isEmpty ? null : _localDay(upcoming.first.dueDate);

    Widget dayCell(DateTime day) {
      final key = _day(day);
      final marker = _buildDayMarker(
        day,
        status: byDay[key]?.status,
        isToday: key == today,
        appColors: appColors,
        isDark: isDark,
      );

      if (start == null || key != start) return marker;

      // The member's first day, flagged so it can be found at a glance.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: marker),
          Positioned(
            top: 1,
            right: 1,
            child: Icon(Icons.flag_rounded, size: 13.r, color: _startColor),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.r, 16.r, 16.r, 28.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(12.r, 12.r, 12.r, 14.r),
        decoration: BoxDecoration(
          color: appColors.accentColor,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _monthHeader(appColors, primary, focused, today, range),
            if (start != null) ...[
              SizedBox(height: 2.h),
              _startLine(appColors, start, range),
            ],
            if (schedule.isNotEmpty) ...[
              SizedBox(height: 10.h),
              _summary(
                appColors,
                paid: paidRounds,
                total: schedule.length,
                overdue: overdueRounds,
                nextDue: nextDue,
              ),
            ],
            SizedBox(height: 8.h),
            Divider(height: 1, color: border.withValues(alpha: 0.4)),
            SizedBox(height: 6.h),
            TableCalendar(
              // TableCalendar numbers its pages from firstDay and does not
              // renumber them when firstDay moves to another month (an older
              // payment arriving, say), which would leave the grid on a
              // different month from the header. A new key rebuilds it.
              key: ValueKey(
                'calendar-${range.first.year}-${range.first.month}-'
                '${range.last.year}-${range.last.month}',
              ),
              headerVisible: false,
              availableGestures: AvailableGestures.horizontalSwipe,
              firstDay: range.first,
              lastDay: range.last,
              focusedDay: focused,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: 46,
              daysOfWeekHeight: 26,
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: appColors.bodyTextSmallColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.sp,
                ),
                weekendStyle: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.sp,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(
                  color: appColors.titleTextColor,
                  fontWeight: FontWeight.w500,
                ),
                // Days before the member's start or after the Equb's end.
                disabledTextStyle: TextStyle(
                  color: (appColors.hintTextColor ?? Colors.grey)
                      .withValues(alpha: 0.45),
                ),
                // The builders below draw every enabled day.
                todayDecoration: const BoxDecoration(),
                selectedDecoration: const BoxDecoration(),
              ),
              // Keeps the header's month in step with a swipe, and keeps the
              // chosen month across rebuilds of this screen.
              onPageChanged: (day) => setState(() => _focusedDay = day),
              onDaySelected: (selectedDay, _) {
                final item = byDay[_day(selectedDay)];

                // Only a round that can still be paid opens checkout.
                if (item != null &&
                    (item.status == PaymentScheduleStatus.pending ||
                        item.status == PaymentScheduleStatus.unpaid ||
                        item.status == PaymentScheduleStatus.future)) {
                  // The round's own date, read the way the Pay Now button and
                  // the payment request read it. The cell can sit a day away
                  // from it on a phone in another timezone.
                  _showPaymentConfirmationDialog(
                    context,
                    item.dueDate,
                    group,
                    appColors,
                    schedule,
                  );
                }
              },
              calendarBuilders: CalendarBuilders(
                todayBuilder: (context, day, _) => dayCell(day),
                defaultBuilder: (context, day, _) => dayCell(day),
              ),
            ),
            SizedBox(height: 10.h),
            Divider(height: 1, color: border.withValues(alpha: 0.4)),
            SizedBox(height: 12.h),
            _buildLegend(appColors, primary, showStart: start != null),
          ],
        ),
      ),
    );
  }

  static const Color _startColor = Color(0xFF6D4AFF);

  /// "September 2026", then Today and the two arrows.
  ///
  /// An arrow at the first or last month the member can reach is drawn
  /// disabled. Before, it looked the same as a working one and did nothing,
  /// which is exactly what was reported.
  Widget _monthHeader(
    AppColors appColors,
    Color primary,
    DateTime focused,
    DateTime today,
    ({DateTime first, DateTime last}) range,
  ) {
    final canGoBack = !_sameMonth(focused, range.first);
    final canGoForward = !_sameMonth(focused, range.last);
    final onTodaysMonth =
        _sameMonth(focused, _clamp(today, range.first, range.last));
    final disabled =
        (appColors.hintTextColor ?? Colors.grey).withValues(alpha: 0.35);

    // Plain InkWells rather than IconButtons, so the look does not depend on
    // whether the app theme is on Material 2 or 3.
    Widget arrow({
      required IconData icon,
      required String tooltip,
      required bool enabled,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 34.r,
              height: 34.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? primary.withValues(alpha: 0.10)
                    : Colors.transparent,
              ),
              child: Icon(icon, size: 24.r, color: enabled ? primary : disabled),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(width: 4.w),
        Expanded(
          // Shrinks rather than wraps or clips on a narrow screen.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CustomText(
              title: DateFormat.yMMMM().format(focused),
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              textColor: appColors.titleTextColor,
              maxLines: 1,
            ),
          ),
        ),
        Tooltip(
          message: 'calendar_go_today'.tr,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _showMonth(today, range.first, range.last),
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: onTodaysMonth
                      ? Colors.transparent
                      : primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: primary.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.today_rounded, size: 15.r, color: primary),
                    SizedBox(width: 4.w),
                    CustomText(
                      title: 'today'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      textColor: primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 6.w),
        arrow(
          icon: Icons.chevron_left_rounded,
          tooltip: 'calendar_prev_month'.tr,
          enabled: canGoBack,
          onTap: () => _showMonth(
            DateTime.utc(focused.year, focused.month - 1, 1),
            range.first,
            range.last,
          ),
        ),
        SizedBox(width: 4.w),
        arrow(
          icon: Icons.chevron_right_rounded,
          tooltip: 'calendar_next_month'.tr,
          enabled: canGoForward,
          onTap: () => _showMonth(
            DateTime.utc(focused.year, focused.month + 1, 1),
            range.first,
            range.last,
          ),
        ),
      ],
    );
  }

  /// "Started Aug 17, 2026". Tapping it shows that month.
  Widget _startLine(
    AppColors appColors,
    DateTime start,
    ({DateTime first, DateTime last}) range,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _showMonth(start, range.first, range.last),
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_rounded, size: 14.r, color: _startColor),
                SizedBox(width: 4.w),
                CustomText(
                  title: 'calendar_started_on'.trParams({
                    'date': DateFormat('MMM d, yyyy').format(start),
                  }),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Where the member stands, in three facts: rounds paid, rounds overdue, and
  /// the next round due.
  Widget _summary(
    AppColors appColors, {
    required int paid,
    required int total,
    required int overdue,
    required DateTime? nextDue,
  }) {
    Widget chip(IconData icon, Color color, String label) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.r, color: color),
            SizedBox(width: 5.w),
            CustomText(
              title: label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              textColor: color,
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: [
        chip(
          Icons.check_circle_rounded,
          Colors.green.shade600,
          'calendar_rounds_paid'.trParams({'paid': '$paid', 'total': '$total'}),
        ),
        if (overdue > 0)
          chip(
            Icons.error_rounded,
            Colors.redAccent,
            'calendar_overdue_count'.trParams({'n': '$overdue'}),
          ),
        if (nextDue != null)
          chip(
            Icons.schedule_rounded,
            Colors.blue.shade600,
            'calendar_next_due'.trParams({
              'date': DateFormat('MMM d').format(nextDue),
            }),
          ),
      ],
    );
  }

  Widget _buildDayMarker(
    DateTime day, {
    required PaymentScheduleStatus? status,
    required bool isToday,
    required AppColors appColors,
    required bool isDark,
  }) {
    final label = '${day.day}';

    Widget circle({
      Color? fill,
      Gradient? gradient,
      Color? outline,
      double outlineWidth = 1,
      required Color text,
      FontWeight weight = FontWeight.w600,
      List<BoxShadow>? shadow,
    }) {
      return Container(
        margin: EdgeInsets.all(5.r),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          gradient: gradient,
          shape: BoxShape.circle,
          border: outline == null
              ? null
              : Border.all(color: outline, width: outlineWidth),
          boxShadow: shadow,
        ),
        child: Text(
          label,
          style: TextStyle(color: text, fontWeight: weight, fontSize: 13.sp),
        ),
      );
    }

    if (status == PaymentScheduleStatus.paid) {
      return circle(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        text: Colors.white,
        weight: FontWeight.w700,
        shadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    if (status == PaymentScheduleStatus.unpaid) {
      return circle(
        fill: Colors.red.withValues(alpha: 0.08),
        outline: Colors.redAccent.withValues(alpha: 0.55),
        text: Colors.redAccent,
      );
    }

    if (status == PaymentScheduleStatus.pending || isToday) {
      final color = appColors.primaryColor ?? AppStaticColor.primaryAmber;
      return circle(
        fill: color.withValues(alpha: 0.15),
        outline: color,
        outlineWidth: 1.5,
        text: color,
        weight: FontWeight.w800,
      );
    }

    if (status == PaymentScheduleStatus.future) {
      return circle(
        fill: Colors.blue.withValues(alpha: 0.08),
        outline: Colors.blue.withValues(alpha: 0.35),
        text: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
        weight: FontWeight.w500,
      );
    }

    return Container(
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: appColors.titleTextColor,
          fontWeight: FontWeight.w500,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  Widget _buildLegend(
    AppColors appColors,
    Color primary, {
    required bool showStart,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14.w,
      runSpacing: 8.h,
      children: [
        _legendItem(Colors.green.shade600, 'paid'.tr, appColors),
        _legendItem(Colors.redAccent, 'overdue'.tr, appColors),
        _legendItem(primary, 'due_today'.tr, appColors),
        _legendItem(Colors.blue.shade400, 'upcoming'.tr, appColors),
        if (showStart)
          _legendItem(
            _startColor,
            'calendar_start'.tr,
            appColors,
            icon: Icons.flag_rounded,
          ),
      ],
    );
  }

  Widget _legendItem(
    Color color,
    String label,
    AppColors appColors, {
    IconData? icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 13.r, color: color)
        else
          Container(
            width: 10.r,
            height: 10.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        SizedBox(width: 6.w),
        CustomText(
          title: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          textColor: appColors.bodyTextSmallColor,
        ),
      ],
    );
  }
}

/// "Today", "Tomorrow" or "in 6 days", for a day that is today or later.
///
/// Counted in whole calendar days on UTC dates, so a clock change can never
/// make tomorrow read as today.
String _relativeDay(DateTime day) {
  final now = DateTime.now();
  final days = DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;

  if (days <= 0) return 'today'.tr;
  if (days == 1) return 'draw_tomorrow'.tr;
  return 'draw_in_days'.trParams({'n': '$days'});
}

/// The places that still owe the round due on [day], and what they owe.
///
/// ONE definition, used by both the Pay button's label and the confirmation
/// dialog, so the amount on the button, the amount in the dialog and the
/// amount the server charges are always the same figure — including in a
/// part-paid round, where only the unpaid places are charged.
({List<EqubMembership> places, double total}) _roundStillOwed(
  EqubGroup group,
  DateTime day,
) {
  final dayKey = DateFormat('yyyy-MM-dd').format(day);
  final all = group.myPlaces.where((m) => m.id != null).toList(growable: false);
  final places = all
      .where((m) => !_placePaidFor(m, dayKey))
      .toList(growable: false);

  final total = places.length == all.length
      ? group.myRoundTotal
      : places.fold<double>(
          0,
          (sum, m) =>
              sum + (m.contributionAmount ?? (group.birrPerDay ?? 0).toDouble()),
        );

  return (places: places, total: total);
}

/// Whether [place] has already paid the round due on [dayKey] (`yyyy-MM-dd`).
///
/// Decided exactly the way the calendar colours that day (see
/// PaymentCalculator.paidRoundIndexes): a payment counts for the round it was
/// made for, and only one made for no round at all falls back to the earliest
/// open one. This check and the calendar used to follow different rules, so a
/// day could look unpaid on the calendar and still be refused here as
/// "already paid".
///
/// A payment made for [dayKey] itself always counts, which is also exactly
/// what the server's own double-payment guard compares.
bool _placePaidFor(EqubMembership place, String dayKey) {
  final payments = place.payments ?? const <EqubPayment>[];
  final rounds = place.paymentSchedule;

  if (rounds != null && rounds.isNotEmpty) {
    final dates = [for (final r in rounds) r.expectedDate];
    final index = dates.indexWhere(
      (d) => PaymentCalculator.dayKey(d) == dayKey,
    );

    if (index != -1) {
      return PaymentCalculator.paidRoundIndexes(
        roundDates: dates,
        payments: payments,
      ).contains(index);
    }
  }

  for (final p in payments) {
    if (p.isPaid && PaymentCalculator.dayKey(p.paymentDate) == dayKey) {
      return true;
    }
  }
  return false;
}

/// The rounds that have to be paid before any later one, oldest first:
/// every round from the member's first day up to and including today that is
/// not fully paid.
///
/// Read from the dates rather than only from each round's status, so a screen
/// left open past midnight still counts the round that has just fallen due;
/// and a round counts only while some place really still owes it, so one the
/// schedule and the payments disagree about can never block every payment.
List<PaymentScheduleItem> _unpaidDueRounds(
  List<PaymentScheduleItem> schedule,
  EqubGroup group,
) {
  final today = _scheduleDayKey(DateTime.now());
  return schedule
      .where(
        (s) =>
            s.status != PaymentScheduleStatus.paid &&
            _scheduleDayKey(s.dueDate).compareTo(today) <= 0 &&
            _roundStillOwed(group, s.dueDate).places.isNotEmpty,
      )
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}

/// A schedule date as `yyyy-MM-dd`, read the same way the payment request
/// sends it.
String _scheduleDayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

void _showPaymentConfirmationDialog(
  BuildContext context,
  DateTime requestedDay,
  EqubGroup group,
  AppColors appColors,
  List<PaymentScheduleItem> schedule,
) {
  // Days are paid in order. While any day from the member's first one up to
  // today is unpaid, the oldest of them is the one paid now, whichever day
  // was tapped; a day ahead can be chosen only once nothing is left behind.
  // The Pay Now button already picks the oldest; this also covers a tap on
  // the calendar.
  final behind = _unpaidDueRounds(schedule, group);
  var day = requestedDay;
  var redirected = false;
  if (behind.isNotEmpty) {
    final oldest = behind.first.dueDate;
    if (_scheduleDayKey(oldest) != _scheduleDayKey(requestedDay)) {
      day = oldest;
      redirected = true;
    }
  }

  // Every place this member is liable for in this Equb, not just their own —
  // minus any that have already paid this date.
  //
  // The server now refuses a charge for a round that is already paid (the
  // double-debit guard), and it is all-or-nothing for a batch. A round can be
  // part-paid: a place added after the member paid that date, or one paid on
  // its own by an older build. Sending every place would then be refused
  // every time, with no way to finish the round from the app. So only the
  // places that still owe are sent, and the total below is theirs.
  final all = group.myPlaces.where((m) => m.id != null).toList(growable: false);
  final owed = _roundStillOwed(group, day);
  final places = owed.places;

  if (all.isEmpty) {
    Get.rawSnackbar(
      message: "no_membership_found".tr,
      backgroundColor: Colors.orange,
    );
    return;
  }

  if (places.isEmpty) {
    Get.rawSnackbar(
      message: "round_already_paid".tr,
      backgroundColor: const Color(0xFF1E7A4C),
    );
    return;
  }

  // The phone app has no bank to hand an order to: Equb payments are made
  // inside the Dashen SuperApp, where Niya runs as a mini app. So the member
  // is sent there, rather than this creating an order nothing on the phone
  // can pay. The mini app has a working bridge and carries on below.
  if (!PaymentBridges.supportedOnThisPlatform) {
    final bloc = context.read<EqubDetailBloc>();
    final current = bloc.state;
    final groupId = current is EqubDetailSuccess ? current.groupId : null;

    showDashenPaySheet(
      context,
      amount: owed.total,
      day: day,
      // A payment made in the SuperApp shows here as soon as they are back.
      onReturn: () {
        if (groupId != null && !bloc.isClosed) {
          bloc.add(EqubDetailLoadEvent(groupId, isSilent: true));
        }
      },
    );
    return;
  }

  final held = places.where((m) => m.isResponsibilitySeat).toList();
  final total = owed.total;
  final money = NumberFormat('#,##0');

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
            // Scrolls on a small phone or with large text, now that the
            // date and the oldest-first note sit in it as well.
            child: SingleChildScrollView(
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
                        '${'confirm_payment_msg'.tr} ${money.format(total)} ETB?',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextColor,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14.h),

                  // The day this payment is for, always shown: after a tap on
                  // one date it may be an older one that has to go first.
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.primaryColor!.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 15.sp,
                          color: appColors.primaryColor,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: CustomText(
                            title: 'pay_for_date'.trParams({
                              'date': DateFormat('EEE, MMM d, yyyy').format(day),
                            }),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            textColor: appColors.titleTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (redirected) ...[
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18.sp,
                            color: Colors.orange.shade800,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: CustomText(
                              title: 'pay_oldest_first'.trParams({
                                'n': '${behind.length}',
                              }),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              textColor: appColors.bodyTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Itemised the moment more than one place is being settled.
                  // A member about to be charged double their own contribution
                  // is owed the reason on the same screen as the number.
                  if (held.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final place in places)
                            Padding(
                              padding: EdgeInsets.only(bottom: 6.h),
                              child: Row(
                                children: [
                                  Icon(
                                    place.isResponsibilitySeat
                                        ? Icons.volunteer_activism_outlined
                                        : Icons.person_outline_rounded,
                                    size: 13.sp,
                                    color: place.isResponsibilitySeat
                                        ? const Color(0xFF7C3AED)
                                        : appColors.bodyTextSmallColor,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: CustomText(
                                      // placeName is the member's own name on
                                      // their membership and the name they gave
                                      // on a held place, so both rows read
                                      // naturally without a new label.
                                      title: place.placeName,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      textColor: appColors.bodyTextColor,
                                      maxLines: 1,
                                      textOverflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  CustomText(
                                    title:
                                        '${money.format(place.contributionAmount ?? group.birrPerDay ?? 0)} ETB',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    textColor: appColors.titleTextColor,
                                  ),
                                ],
                              ),
                            ),
                          Divider(
                            height: 12.h,
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: CustomText(
                                  title: 'your_part_per_round'.tr,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  textColor: appColors.bodyTextSmallColor,
                                ),
                              ),
                              CustomText(
                                title: '${money.format(total)} ETB',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                                textColor: const Color(0xFF7C3AED),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

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

                                // One checkout covering every place. The server
                                // prices each from its own membership, so the
                                // total above and the amount charged come from
                                // the same place and cannot drift apart.
                                context.read<EqubDetailBloc>().add(
                                  EqubDetailInitiateBatchPaymentEvent(
                                    membershipIds: places
                                        .map((m) => m.id!)
                                        .toList(growable: false),
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
        ),
      );
    },
  );
}

/// The Equb's terms, one tab away for as long as the member is in it.
class _TermsTab extends StatelessWidget {
  final EqubGroup group;

  const _TermsTab({required this.group});

  /// The group's own terms, or its package's when it has none.
  String? get _terms {
    final own = group.termsAndConditions?.trim();
    if (own != null && own.isNotEmpty) return own;
    final fromPackage = group.package?.termsContent?.trim();
    return fromPackage != null && fromPackage.isNotEmpty ? fromPackage : null;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final terms = _terms;

    if (terms == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_rounded,
                size: 64.r,
                color: appColors.bodyTextSmallColor?.withValues(alpha: 0.5),
              ),
              SizedBox(height: 16.h),
              CustomText(
                title: 'no_terms_available'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                textColor: appColors.bodyTextSmallColor,
              ),
            ],
          ),
        ),
      );
    }

    final accent = isDark ? NiyaPalette.goldLight : NiyaPalette.maroon;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => TermsScreen.open(
              context,
              terms: terms,
              subtitle: group.name,
            ),
            icon: Icon(Icons.open_in_full_rounded, size: 16.sp, color: accent),
            label: CustomText(
              title: 'terms_open_full'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              textColor: accent,
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 18.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B33) : NiyaPalette.paper,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: NiyaPalette.gold.withValues(alpha: 0.5)),
          ),
          child: TermsContentView(
            text: terms,
            color: isDark ? const Color(0xFFE9E6DF) : NiyaPalette.ink,
          ),
        ),
      ],
    );
  }
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
        // Paid, declined by the bank, or still being confirmed. History now
        // carries all three (it used to receive paid rows only), so each
        // needs to read as what it is at a glance.
        final Color tone = isPaid
            ? Colors.green
            : (p.isFailed ? const Color(0xFFB01F2E) : Colors.orange);
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
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : (p.isFailed
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded),
                  color: tone,
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
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CustomText(
                  title: (p.status ?? 'pending').tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  textColor: tone,
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

  /// Every place the member holds in this Equb: their own, and any they pay
  /// for under "My Responsibility People". Each has its own draw status.
  final List<EqubMembership> places;

  const _DrawTab({required this.draws, this.places = const []});

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
          // The member's standing in the draw comes first. This tab used to
          // show only past wins, so before a first win all it could ever say
          // was "You haven't won yet" — whether the member was fully paid up
          // and in the next draw or had never paid at all (Dashen QA, item 7).
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.r),
            children: [
              _DrawStatusSection(places: places),
              SizedBox(height: 18.h),
              Center(
                child: CustomText(
                  title: 'no_draws_yet'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  textColor: appColors.bodyTextSmallColor,
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20.r),
          itemCount: draws.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: 16.h),
          itemBuilder: (context, index) {
            if (index == 0) return _DrawStatusSection(places: places);
            final d = draws[index - 1];
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


/// Shown under the Equb header while a payment is being confirmed.
///
/// The one thing on screen that explains why a contribution the member has
/// just paid is not green yet. Without it the schedule, progress and history
/// all read as "not paid" with nothing to say that is expected and temporary.
class _ConfirmingBanner extends StatelessWidget {
  const _ConfirmingBanner();

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: appColors.primaryColor!.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: appColors.primaryColor!.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18.r,
              height: 18.r,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: appColors.primaryColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: CustomText(
                title: 'payment_confirming_banner'.tr,
                fontSize: 13.sp,
                maxLines: 3,
                fontWeight: FontWeight.w600,
                textColor: appColors.titleTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Where each of the member's places stands in the draw.
///
/// ELIGIBILITY IS THE SERVER'S RULE, NOT A GUESS.
///
/// EqubDrawService::getEligibleMemberships() draws only from memberships that
/// are active, have not already won, and have at least one PAID contribution.
/// This applies exactly that test to what the Equb screen already holds, so
/// the tab cannot tell a member they are in the draw when the server would
/// leave them out, or the reverse.
class _DrawStatusSection extends StatelessWidget {
  final List<EqubMembership> places;

  const _DrawStatusSection({required this.places});

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final place in places) ...[
          _DrawStatusCard(place: place, showName: places.length > 1),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}

class _DrawStatusCard extends StatelessWidget {
  final EqubMembership place;
  final bool showName;

  const _DrawStatusCard({required this.place, required this.showName});

  static String? _date(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return parsed == null ? null : DateFormat('MMM dd, yyyy').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    final won = place.hasWon == true;
    final active = (place.status ?? 'active').toLowerCase() == 'active';
    final hasPaid = (place.payments ?? const <EqubPayment>[]).any((p) => p.isPaid) ||
        (place.contributedAmount ?? 0) > 0;
    final eligible = !won && active && hasPaid;

    final Color accent;
    final IconData icon;
    final String headline;

    if (won) {
      accent = const Color(0xFFB8860B);
      icon = Icons.emoji_events_rounded;
      final on = _date(place.winDate);
      headline = on == null ? 'won'.tr : 'draw_won_on'.trParams({'date': on});
    } else if (!active) {
      accent = Colors.blueGrey;
      icon = Icons.pause_circle_outline_rounded;
      headline = 'draw_place_inactive'.tr;
    } else if (eligible) {
      accent = const Color(0xFF1E7A4C);
      icon = Icons.verified_rounded;
      headline = 'draw_eligible'.tr;
    } else {
      accent = Colors.orange;
      icon = Icons.info_outline_rounded;
      headline = 'draw_needs_first_payment'.tr;
    }

    final details = <String>[
      if (showName) place.placeName,
      if (!won && place.drawPosition != null)
        'draw_position'.trParams({'n': '${place.drawPosition}'}),
      // Never a day that has gone by. See EqubMembership.upcomingDrawDate.
      if (place.upcomingDrawDate case final next? when !won)
        '${'next_draw'.tr}: ${DateFormat('MMM dd, yyyy').format(next)} · ${_relativeDay(next)}',
    ];

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 26.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title: headline,
                  fontSize: 14.sp,
                  maxLines: 2,
                  fontWeight: FontWeight.w700,
                  textColor: appColors.titleTextColor,
                ),
                for (final line in details) ...[
                  SizedBox(height: 3.h),
                  CustomText(
                    title: line,
                    fontSize: 12.sp,
                    maxLines: 2,
                    fontWeight: FontWeight.w500,
                    textColor: appColors.bodyTextSmallColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
