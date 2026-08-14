import 'dart:async';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:niya_equb/core/init/dio_network.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:get/get.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/features/member/packages/presentation/screens/equb_detail_screen.dart';
import 'package:niya_equb/core/service/navigation_service.dart' as nav;

// Notification handle logic moved to main.dart for maximum visibility in killed state

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream for components to listen to live notifications
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    // 1. Request permissions
    await requestPermission();

    // 2. Initialize local notifications for foreground support on Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS/Linux/Web can also be initialized here if needed
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap when app is in foreground
        _handleNotificationTap(response.payload);
      },
    );

    // 3. Create High Importance Channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // 4. Handle initial notification that might have launched the app (Killed State)
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      logger("App launched from local notification");
      _handleNotificationTap(
        notificationAppLaunchDetails!.notificationResponse?.payload,
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      logger("Foreground Message Received: ${message.messageId}");
      logger("Message Data: ${message.data}");

      // Prayer announcements go to the dedicated azan channel so a
      // server-pushed adhan is indistinguishable from a locally scheduled one.
      if (AzanNotificationService.isAzanMessage(message.data)) {
        await AzanNotificationService.showFromRemote(message.data);
        return;
      }

      // Feed the broadcast stream
      logger("Adding message to notification stream");
      _messageStreamController.add(message);

      RemoteNotification? notification = message.notification;
      String? title = notification?.title;
      String? body = notification?.body;

      // Fallback to data title/body if notification object is missing
      if (title == null && message.data.containsKey('title')) {
        title = message.data['title'];
      }
      if (body == null && message.data.containsKey('body')) {
        body = message.data['body'];
      }
      if (body == null &&
          message.data.containsKey('equb_group_name') &&
          message.data['type'] == 'equb_draw_started') {
        title = "Equb Draw Started";
        body = "${message.data['equb_group_name']} is drawing now!";
      }

      if (title != null || body != null) {
        _localNotifications.show(
          id: message.hashCode,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: _channel.importance,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 5. Set up Background and Terminated state listeners
    // Note: onBackgroundMessage is now registered in main.dart for better reliability in killed state

    // 6. Handle initial message (when app is opened from a terminated state)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessage(initialMessage);
    }

    // 7. Handle message when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // 8. Get FCM Token with robust retry logic
    _fetchAndSyncToken();
  }

  Future<void> _fetchAndSyncToken() async {
    try {
      String? token;
      if (Platform.isIOS) {
        // On iOS, we must wait for APNS token
        token = await _getFcmTokenWithRetry(isIOS: true);
      } else {
        // On Android, retry if Installations Service is transiently unavailable
        token = await _getFcmTokenWithRetry(isIOS: false);
      }

      if (token != null) {
        logger("FCM Token secured: $token");
        await syncTokenToBackend(token);
      } else {
        logger(
          "Failed to secure FCM token after retries. Push notifications may not work.",
        );
      }
    } catch (e) {
      logger("Critical error during token synchronization: $e");
    }
  }

  Future<String?> _getFcmTokenWithRetry({required bool isIOS}) async {
    int retryCount = 0;
    const int maxRetries = 5;

    while (retryCount < maxRetries) {
      try {
        if (isIOS) {
          final apnsToken = await _fcm.getAPNSToken();
          if (apnsToken == null) {
            logger("Waiting for APNS token... (Attempt ${retryCount + 1})");
            await Future.delayed(
              Duration(seconds: 1 * (retryCount + 1)),
            ); // Exponential backoff-ish
            retryCount++;
            continue;
          }
        }

        // If we reach here, we either have APNS token or we are on Android
        return await _fcm.getToken();
      } catch (e) {
        logger("FCM Token Fetch Exception (Attempt ${retryCount + 1}): $e");
        await Future.delayed(
          Duration(seconds: 2 * (retryCount + 1)),
        ); // Backoff
        retryCount++;
      }
    }
    return null;
  }

  Future<void> requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    logger('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    logger("Handling message interactively: ${message.messageId}");
    logger("Message Data: ${message.data}");

    // Also feed the stream when app is opened from notification
    logger("Adding interactive message to notification stream");
    _messageStreamController.add(message);

    if (message.notification != null) {
      logger("Message Notification Title: ${message.notification?.title}");
      logger("Message Notification Body: ${message.notification?.body}");
    }

    final groupId = message.data['equb_group_id'];
    final type = message.data['type'];
    final id = groupId != null ? int.tryParse(groupId.toString()) : null;

    // Cache active draw state
    if (id != null) {
      if (type == 'equb_draw_started') {
        final candidates = _extractCandidates(message.data['member_names']);
        await PreferencesService.saveActiveDraw(id, candidates, DateTime.now().toUtc());
      } else if (type == 'equb_draw_completed') {
        await PreferencesService.clearActiveDraw(id);
      }
    }

    // Navigate to Equb Detail Screen if group id is present
    if (id != null) {
      if (!await _isNotificationFresh(message.data['date_time'])) {
        logger("Notification is too old for auto-navigation. Skipping.");
        return;
      }

      _navigateToEqubDetail(
        groupId: id,
        drawType: _filterDrawTypeByTime(type, message.data['date_time']),
        winnerName:
            message.data['winner_name'] ??
            message.data['winner_membership_id'],
        candidates: _extractCandidates(message.data['member_names']),
      );
    }
  }

  String? _filterDrawTypeByTime(String? type, dynamic dateTimeRaw) {
    if (type == 'equb_draw_started' && dateTimeRaw != null) {
      try {
        String dtStr = dateTimeRaw.toString().trim();
        if (dtStr.length >= 19 && dtStr[10] == ' ') {
          dtStr = "${dtStr.substring(0, 10)}T${dtStr.substring(11)}Z";
        } else if (!dtStr.endsWith('Z') && !dtStr.contains('+')) {
          dtStr = dtStr.replaceFirst(' ', 'T') + 'Z';
        }
        final drawTime = DateTime.parse(dtStr);
        final now = DateTime.now().toUtc();
        final diffSeconds = now.difference(drawTime).inSeconds;
        
        logger("Draw Time: \$drawTime, Now: \$now, Diff: \$diffSeconds seconds");
        
        if (diffSeconds > 60 || diffSeconds < -60) {
          logger("Draw notification is too old (> 1 min). Suppressing spinning animation.");
          return null;
        }
      } catch (e) {
        logger("Error parsing date_time: \$e");
      }
    }
    return type;
  }

  List<String> _extractCandidates(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  void _handleNotificationTap(String? payload) async {
    logger("Notification tapped with payload: $payload");
    if (payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final groupId = data['equb_group_id'];
        if (groupId != null) {
          final id = int.tryParse(groupId.toString());
          if (id != null) {
            if (!await _isNotificationFresh(data['date_time'])) {
              logger("Local notification is too old for auto-navigation. Skipping.");
              return;
            }

            _navigateToEqubDetail(
              groupId: id,
              drawType: _filterDrawTypeByTime(data['type'], data['date_time']),
              winnerName: data['winner_name'] ?? data['winner_membership_id'],
              candidates: _extractCandidates(data['member_names']),
            );
          }
        }
      } catch (e) {
        logger("Error parsing notification tap payload: $e");
      }
    }
  }

  Future<bool> _isNotificationFresh(dynamic dateTimeRaw) async {
    if (dateTimeRaw == null) return true; // If no date, assume fresh or handle cautiously
    try {
      String dtStr = dateTimeRaw.toString().trim();
      if (dtStr.length >= 19 && dtStr[10] == ' ') {
        dtStr = "${dtStr.substring(0, 10)}T${dtStr.substring(11)}Z";
      } else if (!dtStr.endsWith('Z') && !dtStr.contains('+')) {
        dtStr = dtStr.replaceFirst(' ', 'T') + 'Z';
      }
      final drawTime = DateTime.parse(dtStr);
      final now = DateTime.now().toUtc();
      final diffMinutes = now.difference(drawTime).inMinutes;
      
      // If notification is more than 10 minutes old, don't auto-navigate
      return diffMinutes.abs() < 10;
    } catch (e) {
      logger("Error parsing date_time for freshness: $e");
      return true; // Fallback to allowed if parsing fails
    }
  }

  void _navigateToEqubDetail({
    required int groupId,
    String? drawType,
    String? winnerName,
    List<String>? candidates,
  }) async {
    // Polling mechanism to wait for Splash screen to finish navigating
    int retryCount = 0;
    while (!nav.NavigationService.splashScreenFinished &&
        retryCount < 40) {
      logger(
        "Waiting for splash screen to finish... (Attempt ${retryCount + 1})",
      );
      await Future.delayed(const Duration(milliseconds: 300));
      retryCount++;
    }

    // AUTH GUARD: Only navigate if user is logged in
    final isLoggedIn = await PreferencesService.isLoggedIn();
    if (!isLoggedIn) {
      logger("NotificationService: User is not logged in. Aborting auto-navigation to Equb Detail.");
      return;
    }

    if (nav.NavigationService.navigatorKey.currentState != null) {
      Get.toNamed(
        EqubDetailScreen.routeName,
        arguments: {
          'groupId': groupId,
          'initialTab': 2,
          'drawType': drawType,
          'winnerName': winnerName,
          'candidates': candidates,
        },
      );
    } else {
      logger("Navigator not ready after multiple retries. Navigation failed.");
    }
  }

  Future<void> syncTokenToBackend(String token) async {
    // This runs on every cold start, well before the user has necessarily
    // signed in. Posting it logged out earns a 401, and a 401 used to end in
    // a jump to login — landing a second login screen on top of the one the
    // splash had already opened.
    if (!await PreferencesService.isLoggedIn()) {
      logger("Not signed in — holding the FCM token until after login.");
      return;
    }

    try {
      logger("Syncing FCM token to backend...");
      logger(token);
      await DioNetwork.appAPI.post(
        AuthEndpoint.fcmToken(),
        data: {"fcm_token": token},
      );
      logger("FCM token synced successfully.");
    } catch (e) {
      logger("Error syncing FCM token to backend: $e");
    }
  }

  void dispose() {
    _messageStreamController.close();
  }
}
