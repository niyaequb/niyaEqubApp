import 'package:geolocator/geolocator.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';

/// Result of a location attempt, with enough detail for the UI to explain
/// itself rather than just failing silently.
enum LocationOutcome {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

/// A city the user can pick manually when GPS is unavailable.
class SelectableCity {
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  const SelectableCity(this.name, this.country, this.latitude, this.longitude);

  String get label => '$name, $country';
}

class IslamicLocation {
  final double latitude;
  final double longitude;
  final String city;
  final String country;

  /// True when this came from cache rather than a fresh GPS fix.
  final bool fromCache;

  const IslamicLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    this.fromCache = false,
  });

  String get label => '$city, $country';
}

class LocationResult {
  final LocationOutcome outcome;
  final IslamicLocation? location;

  const LocationResult(this.outcome, [this.location]);

  bool get isSuccess => outcome == LocationOutcome.success && location != null;
}

/// Location handling for prayer times and Qibla.
///
/// Prayer times only need a few kilometres of accuracy, so this deliberately
/// asks for low accuracy with a generous timeout, then falls back through
/// last-known position and finally a saved or default city. The goal is that
/// the screen always has coordinates to work with — a prayer app that shows
/// nothing because the GPS is sulking is worse than one that is slightly off.
class IslamicLocationService {
  /// Fallback when nothing has ever been stored.
  static const _defaultLatitude = 9.0192;
  static const _defaultLongitude = 38.7525;
  static const _defaultCity = 'Addis Ababa';
  static const _defaultCountry = 'Ethiopia';

  /// Reads the cached location, or the default if nothing is stored.
  /// Never prompts and never touches the GPS — safe to call on every build.
  static Future<IslamicLocation> cachedOrDefault() async {
    final lat = await IslamicPrefs.getLatitude();
    final lng = await IslamicPrefs.getLongitude();

    if (lat != null && lng != null) {
      return IslamicLocation(
        latitude: lat,
        longitude: lng,
        city: await IslamicPrefs.getCity(),
        country: await IslamicPrefs.getCountry(),
        fromCache: true,
      );
    }

    return const IslamicLocation(
      latitude: _defaultLatitude,
      longitude: _defaultLongitude,
      city: _defaultCity,
      country: _defaultCountry,
      fromCache: true,
    );
  }

  /// Requests permission if needed and takes a fresh fix.
  static Future<LocationResult> refresh({bool requestPermission = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          LocationOutcome.serviceDisabled,
          await cachedOrDefault(),
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return LocationResult(
          LocationOutcome.permissionDenied,
          await cachedOrDefault(),
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          LocationOutcome.permissionDeniedForever,
          await cachedOrDefault(),
        );
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        logger('Islamic: fresh fix failed, falling back to last known — $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return LocationResult(LocationOutcome.error, await cachedOrDefault());
      }

      final city = _nearestKnownCity(position.latitude, position.longitude);

      await IslamicPrefs.saveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city.name,
        country: city.country,
      );

      return LocationResult(
        LocationOutcome.success,
        IslamicLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          city: city.name,
          country: city.country,
        ),
      );
    } catch (e) {
      logger('Islamic: location refresh failed — $e');
      return LocationResult(LocationOutcome.error, await cachedOrDefault());
    }
  }

  /// Stores a manually chosen city, for users who keep GPS off.
  static Future<IslamicLocation> setManualCity(SelectableCity city) async {
    await IslamicPrefs.saveLocation(
      latitude: city.latitude,
      longitude: city.longitude,
      city: city.name,
      country: city.country,
    );

    return IslamicLocation(
      latitude: city.latitude,
      longitude: city.longitude,
      city: city.name,
      country: city.country,
    );
  }

  static List<SelectableCity> get selectableCities => _cities;

  /// Reverse geocoding without a network call: pick the closest city from the
  /// bundled table. Good enough for a location label, and it works offline.
  static SelectableCity _nearestKnownCity(double lat, double lng) {
    SelectableCity best = _cities.first;
    var bestDistance = double.infinity;

    for (final city in _cities) {
      final dLat = city.latitude - lat;
      final dLng = city.longitude - lng;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = city;
      }
    }

    // Roughly two degrees out — beyond that the label would be misleading.
    if (bestDistance > 4.0) {
      return SelectableCity('Current location', 'GPS', lat, lng);
    }

    return best;
  }

  static const List<SelectableCity> _cities = [
    SelectableCity('Addis Ababa', 'Ethiopia', 9.0192, 38.7525),
    SelectableCity('Dire Dawa', 'Ethiopia', 9.5931, 41.8661),
    SelectableCity('Harar', 'Ethiopia', 9.3110, 42.1180),
    SelectableCity('Jimma', 'Ethiopia', 7.6733, 36.8344),
    SelectableCity('Adama', 'Ethiopia', 8.5400, 39.2700),
    SelectableCity('Shashamane', 'Ethiopia', 7.2000, 38.6000),
    SelectableCity('Hawassa', 'Ethiopia', 7.0621, 38.4764),
    SelectableCity('Bahir Dar', 'Ethiopia', 11.5936, 37.3908),
    SelectableCity('Gondar', 'Ethiopia', 12.6030, 37.4521),
    SelectableCity('Mekelle', 'Ethiopia', 13.4967, 39.4753),
    SelectableCity('Dessie', 'Ethiopia', 11.1333, 39.6333),
    SelectableCity('Jijiga', 'Ethiopia', 9.3500, 42.8000),
    SelectableCity('Nekemte', 'Ethiopia', 9.0833, 36.5500),
    SelectableCity('Arba Minch', 'Ethiopia', 6.0333, 37.5500),
    SelectableCity('Asella', 'Ethiopia', 7.9500, 39.1333),
    SelectableCity('Kombolcha', 'Ethiopia', 11.0833, 39.7333),
    SelectableCity('Woldiya', 'Ethiopia', 11.8311, 39.6033),
    SelectableCity('Debre Birhan', 'Ethiopia', 9.6800, 39.5325),
    SelectableCity('Ambo', 'Ethiopia', 8.9833, 37.8500),
    SelectableCity('Bale Robe', 'Ethiopia', 7.1167, 40.0000),
    SelectableCity('Gambela', 'Ethiopia', 8.2500, 34.5833),
    SelectableCity('Assosa', 'Ethiopia', 10.0667, 34.5333),
    SelectableCity('Semera', 'Ethiopia', 11.7833, 41.0000),
    SelectableCity('Moyale', 'Ethiopia', 3.5333, 39.0500),
    SelectableCity('Wolkite', 'Ethiopia', 8.2833, 37.7833),
    SelectableCity('Djibouti', 'Djibouti', 11.5721, 43.1456),
    SelectableCity('Hargeisa', 'Somaliland', 9.5600, 44.0650),
    SelectableCity('Mogadishu', 'Somalia', 2.0469, 45.3182),
    SelectableCity('Nairobi', 'Kenya', -1.2864, 36.8172),
    SelectableCity('Khartoum', 'Sudan', 15.5007, 32.5599),
    SelectableCity('Jeddah', 'Saudi Arabia', 21.4858, 39.1925),
    SelectableCity('Makkah', 'Saudi Arabia', 21.3891, 39.8579),
    SelectableCity('Madinah', 'Saudi Arabia', 24.5247, 39.5692),
    SelectableCity('Riyadh', 'Saudi Arabia', 24.7136, 46.6753),
    SelectableCity('Dubai', 'UAE', 25.2048, 55.2708),
    SelectableCity('Doha', 'Qatar', 25.2854, 51.5310),
    SelectableCity('Kuwait City', 'Kuwait', 29.3759, 47.9774),
    SelectableCity('Cairo', 'Egypt', 30.0444, 31.2357),
    SelectableCity('Istanbul', 'Turkiye', 41.0082, 28.9784),
    SelectableCity('London', 'United Kingdom', 51.5074, -0.1278),
    SelectableCity('Washington DC', 'United States', 38.9072, -77.0369),
    SelectableCity('Minneapolis', 'United States', 44.9778, -93.2650),
    SelectableCity('Toronto', 'Canada', 43.6532, -79.3832),
  ];
}
