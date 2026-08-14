import 'dart:math' as math;

/// Qibla direction and a tilt-compensated compass heading.
///
/// The heading maths is deliberately implemented here rather than pulled from
/// a compass plugin: the widely used ones have been unmaintained for years and
/// break on current Gradle/AGP. `sensors_plus` gives raw accelerometer and
/// magnetometer vectors, and the rotation-matrix approach below is the same one
/// Android's own `SensorManager.getRotationMatrix` uses.
class QiblaCalculator {
  /// Coordinates of the Kaaba, Masjid al-Haram.
  static const double kaabaLatitude = 21.4224779;
  static const double kaabaLongitude = 39.8251832;

  /// Initial great-circle bearing from a point to the Kaaba, in degrees
  /// clockwise from true north (0..360).
  static double bearing({
    required double latitude,
    required double longitude,
  }) {
    final lat1 = _deg2rad(latitude);
    final lat2 = _deg2rad(kaabaLatitude);
    final dLon = _deg2rad(kaabaLongitude - longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final theta = math.atan2(y, x);
    return (_rad2deg(theta) + 360.0) % 360.0;
  }

  /// Great-circle distance to the Kaaba in kilometres.
  static double distanceKm({
    required double latitude,
    required double longitude,
  }) {
    const earthRadiusKm = 6371.0;

    final lat1 = _deg2rad(latitude);
    final lat2 = _deg2rad(kaabaLatitude);
    final dLat = _deg2rad(kaabaLatitude - latitude);
    final dLon = _deg2rad(kaabaLongitude - longitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Compass azimuth in degrees clockwise from magnetic north, derived from
  /// the gravity and geomagnetic vectors.
  ///
  /// Returns null when the two vectors are close to parallel — that happens
  /// when the phone is held in a strong local magnetic field, and a heading
  /// computed from it would be meaningless.
  static double? azimuthFrom({
    required List<double> gravity,
    required List<double> geomagnetic,
  }) {
    final ax = gravity[0], ay = gravity[1], az = gravity[2];
    final ex = geomagnetic[0], ey = geomagnetic[1], ez = geomagnetic[2];

    // H = E x A  (east vector)
    var hx = ey * az - ez * ay;
    var hy = ez * ax - ex * az;
    var hz = ex * ay - ey * ax;

    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return null; // Device is close to free fall or saturated.

    final invH = 1.0 / normH;
    hx *= invH;
    hy *= invH;
    hz *= invH;

    final invA = 1.0 / math.sqrt(ax * ax + ay * ay + az * az);
    final nax = ax * invA, nay = ay * invA, naz = az * invA;

    // M = A x H  (north vector)
    final mx = nay * hz - naz * hy;
    final my = naz * hx - nax * hz;

    // Azimuth is the rotation of the north vector in the device plane.
    final azimuth = math.atan2(hy, my);
    final degrees = (_rad2deg(azimuth) + 360.0) % 360.0;

    // Silence the analyzer about the unused component while keeping the full
    // rotation matrix derivation readable.
    assert(mx.isFinite);

    return degrees;
  }

  /// Low-pass filter for sensor streams. Raw magnetometer output is jittery
  /// enough to make the needle unreadable without it.
  static List<double> lowPass(List<double> input, List<double>? previous) {
    if (previous == null) return List<double>.from(input);
    const alpha = 0.15;
    return List<double>.generate(
      input.length,
      (i) => previous[i] + alpha * (input[i] - previous[i]),
    );
  }

  /// Shortest signed rotation from [from] to [to], in the range -180..180.
  /// Keeps the needle from spinning the long way round through 359 -> 1.
  static double shortestDelta(double from, double to) {
    var delta = (to - from) % 360.0;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  /// Cardinal label for an azimuth, for the readout under the dial.
  static String cardinal(double azimuth) {
    const labels = [
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW',
    ];
    final index = (((azimuth + 22.5) % 360) / 45).floor() % 8;
    return labels[index];
  }

  /// Formats a coordinate the way the reference app does: 9°0'6" N.
  static String formatCoordinate(double value, {required bool isLatitude}) {
    final hemisphere = isLatitude
        ? (value >= 0 ? 'N' : 'S')
        : (value >= 0 ? 'E' : 'W');
    final abs = value.abs();
    final degrees = abs.floor();
    final minutesFull = (abs - degrees) * 60;
    final minutes = minutesFull.floor();
    final seconds = ((minutesFull - minutes) * 60).round();

    return '$degrees°$minutes\'$seconds" $hemisphere';
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;
  static double _rad2deg(double r) => r * 180.0 / math.pi;
}
