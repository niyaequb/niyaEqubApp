// import 'package:firebase_database/firebase_database.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:royal_crown_luxury_driver/model/user.dart';
// import 'package:royal_crown_luxury_driver/service/shared_preference_service.dart';

// class DriverLocationService {
//   final DatabaseReference _driverRef;
//   final String driverId;
//   Position? _lastPosition;

//   DriverLocationService(this.driverId)
//       : _driverRef = FirebaseDatabase.instance
//             .ref('royal_crown_luxury_drivers/$driverId');

//   Future<void> startLocationUpdates() async {
//     // Check if location services are enabled
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       // Location services are not enabled, handle accordingly
//       throw Exception('Location services are disabled.');
//     }

//     // Check location permissions
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         // Permissions are denied, handle accordingly
//         throw Exception('Location permissions are denied');
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       // Permissions are denied forever, handle appropriately
//       throw Exception(
//           'Location permissions are permanently denied, we cannot request permissions.');
//     }

//     // If we reach here, permissions are granted and we can start updates
//     const locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       distanceFilter: 10, // meters
//     );

//     Geolocator.getPositionStream(locationSettings: locationSettings)
//         .listen((Position position) {
//       _updateLocation(position);
//     });
//   }

//   Future<void> _updateLocation(Position position) async {
//     _lastPosition = position;
//     await _driverRef.update({
//       'location': {
//         'latitude': position.latitude,
//         'longitude': position.longitude,
//         'timestamp': DateTime.now().millisecondsSinceEpoch,
//       }
//     });
//   }

//   Future<void> setAvailability(String status) async {
//     await _driverRef.update({
//       'availability': status,
//     });
//   }

//   Future<void> setDriver() async {
//     final driver = await PreferencesService.getUser();
//     await _driverRef.update({
//       'driver': driver?.toJson(),
//     });
//   }
// }
