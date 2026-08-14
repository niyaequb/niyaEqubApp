// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:royal_crown_luxury_driver/model/ride_request.dart';
// import 'package:royal_crown_luxury_driver/screens/order_detail_screen.dart';
// import 'package:royal_crown_luxury_driver/screens/ride_request_modal_bottomsheet.dart';
// import 'package:royal_crown_luxury_driver/service/firebase_messaging_handler.dart';
// import 'package:royal_crown_luxury_driver/util/logger.dart';

// class DriverRideHandler {
//   final BuildContext context;
//   final DatabaseReference _db = FirebaseDatabase.instance.ref();
//   final String driverId;
//   final FirebaseMessaging _fcm = FirebaseMessaging.instance;
//   final FlutterLocalNotificationsPlugin _notifications =
//       FlutterLocalNotificationsPlugin();

//   bool _isShowingRequest = false;
//   String? _currentRideId;

//   DriverRideHandler(this.driverId, this.context);

//   Future<void> initializeNotifications() async {
//     // Request notification permissions
//     final settings = await _fcm.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//       provisional: false,
//     );

//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {}

//     // Initialize local notifications
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     final InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);

//     await _notifications.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) {
//         _handleNotificationTap(response.payload);
//       },
//     );

//     // Set up FCM handlers
//     FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

//     // Save FCM token
//     _saveFcmToken();
//   }

//   Future<void> _saveFcmToken() async {
//     final token = await _fcm.getToken();
//     if (token != null) {
//       await _db
//           .child('royal_crown_luxury_drivers/$driverId/fcmToken')
//           .set(token);
//     }

//     _fcm.onTokenRefresh.listen((newToken) {
//       _db.child('royal_crown_luxury_drivers/$driverId/fcmToken').set(newToken);
//     });
//   }

//   Future<void> _handleNotificationTap(String? rideId) async {
//     if (rideId != null && !_isShowingRequest) {
//       _showRideRequestFromNotification(rideId);
//     }
//   }

//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     if (message.data['rideId'] != null && !_isShowingRequest) {
//       _showRideRequestFromNotification(message.data['rideId']!);
//     }
//   }

//   Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
//     if (message.data['rideId'] != null && !_isShowingRequest) {
//       _showRideRequestFromNotification(message.data['rideId']!);
//     }
//   }

//   Future<void> _showRideRequestFromNotification(String rideId) async {
//     final snapshot = await _db.child('rideRequests/$rideId').get();
//     if (snapshot.exists) {
//       _showRideRequest(rideId, snapshot.value as Map<dynamic, dynamic>);
//     }
//   }

//   void listenForRideRequests() {
//     _db
//         .child('rideRequests')
//         .orderByChild('assignedDrivers/$driverId')
//         .equalTo('pending')
//         .onChildAdded
//         .listen((event) {
//       final rideId = event.snapshot.key!;
//       final data = event.snapshot.value as Map<dynamic, dynamic>;

//       if (_isShowingRequest || _currentRideId != null) {
//         logger("Already handling another ride request. Ignoring $rideId");
//         return;
//       }

//       _currentRideId = rideId;
//       _isShowingRequest = true;
//       _showRideRequest(rideId, data);
//     });
//   }

//   void _showRideRequest(String rideId, Map<dynamic, dynamic> jsonData) {
//     RideRequest data = RideRequest.fromJson(jsonData);

//     showModalBottomSheet(
//       isDismissible: false,
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => RideRequestModalBottomsheet(assignmentData: data),
//     ).then((res) async {
//       if (res != null) {
//         if (res['success'] == true) {
//           await acceptRideRequest(rideId);
//           Future.delayed(Duration(seconds: 1), () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => OrderDetailPage(order: res['order']),
//               ),
//             );
//           });
//         } else {
//           await rejectRideRequest(rideId);
//         }
//       }
//       _resetState();
//     });
//   }

//   Future<void> acceptRideRequest(String rideId) async {
//     await _db
//         .child('rideRequests/$rideId/assignedDrivers/$driverId')
//         .set('accepted');
//     await _db
//         .child('royal_crown_luxury_drivers/$driverId/availability')
//         .set('in-ride');
//   }

//   Future<void> rejectRideRequest(String rideId) async {
//     await _db
//         .child('rideRequests/$rideId/assignedDrivers/$driverId')
//         .set('rejected');
//   }

//   void _resetState() {
//     _isShowingRequest = false;
//     _currentRideId = null;
//   }
// }
