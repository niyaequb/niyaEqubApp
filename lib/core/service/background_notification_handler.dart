import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // 0. Ensure Flutter binding is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Firebase for the background isolate (CRITICAL for reliability)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint("--- Background Handler Started ---");
    debugPrint("Message ID: ${message.messageId}");

    // Prayer announcements pushed from the server render on the dedicated azan
    // channel so they sound and behave exactly like a locally scheduled adhan.
    // Handled before the Equb path because they share none of its payload.
    if (AzanNotificationService.isAzanMessage(message.data)) {
      await AzanNotificationService.showFromRemote(message.data);
      debugPrint("Background azan notification displayed.");
      return;
    }

    // 2. Setup Local Notifications
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await localNotifications.initialize(
      settings: initializationSettings,
      // Note: We don't handle taps here as it's a background isolate.
      // Main app handles taps via NotificationService.initialize()
    );

    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // 3. Extract content
    String? title = message.notification?.title;
    String? body = message.notification?.body;

    // Data-only fallback
    if (title == null) {
      title = message.data['title'] ?? "Niya Umrah Equb";
    }

    if (body == null) {
      final groupName = message.data['equb_group_name'];
      final type = message.data['type'];

      if (type == 'equb_draw_started') {
        title = "Equb Draw Started";
        body = groupName != null
            ? "$groupName is drawing now!"
            : "A new draw has started!";
      } else if (type == 'equb_draw_completed') {
        title = "Equb Draw Completed";
        body = groupName != null
            ? "A winner has been found in $groupName!"
            : "A new winner has been announced!";
      } else {
        body = message.data['body'] ?? "New update in your Equb group";
      }
    }

    // 4. Cache state (AWAIT this to ensure isolate doesn't exit before saving)
    final groupIdStr = message.data['equb_group_id'];
    if (groupIdStr != null) {
      final id = int.tryParse(groupIdStr.toString());
      final type = message.data['type'];
      if (id != null) {
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
          debugPrint("Saving active draw state for group $id...");
          await PreferencesService.saveActiveDraw(
            id,
            candidates,
            DateTime.now().toUtc(),
          );
        } else if (type == 'equb_draw_completed') {
          debugPrint("Clearing active draw state for group $id...");
          await PreferencesService.clearActiveDraw(id);
        }
      }
    }

    // 5. Show notification
    final int notificationId =
        message.messageId?.hashCode ??
        (DateTime.now().millisecondsSinceEpoch % 100000);

    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          autoCancel: true,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
    debugPrint("Background notification displayed successfully.");
  } catch (e, stack) {
    debugPrint("Background Handler ERROR: $e");
    debugPrint(stack.toString());
  }
}
