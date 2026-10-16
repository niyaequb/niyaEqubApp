import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:niya_equb/features/member/islamic/logic/qibla_calculator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// One compass reading.
class CompassReading {
  const CompassReading({
    required this.heading,
    required this.trueNorth,
    required this.needsCalibration,
    this.tilt,
  });

  /// Degrees clockwise from north, 0..360.
  final double heading;

  /// True when [heading] is measured from TRUE north — the north the bearing
  /// to the Kaaba is measured from. False means magnetic north.
  final bool trueNorth;

  /// The phone says its compass is unreliable right now.
  final bool needsCalibration;

  /// How far the phone is from lying flat, in degrees — 0 flat on its back,
  /// 90 held upright. Null when the platform does not say.
  ///
  /// The heading is "where the top edge of the phone points", which is only
  /// the direction the member means while the phone is reasonably flat.
  final double? tilt;

  /// True when the phone is tilted far enough that the heading no longer
  /// means anything.
  ///
  /// A phone read in the hand sits somewhere around 20–40° off flat, and that
  /// reading is fine. It is past about 55° that the top edge stops pointing
  /// anywhere in particular and the azimuth starts to swing — so that, not
  /// the ordinary way a phone is held, is where the screen asks for it to be
  /// laid flat.
  bool get isTilted => (tilt ?? 0) > _tiltLimit;

  /// Degrees off flat past which the heading is not trusted.
  static const double _tiltLimit = 55;
}

/// The phone's compass heading, as quickly and as accurately as it can give
/// it.
///
/// WHERE IT COMES FROM
///
/// First choice is the platform's own heading: Android's rotation-vector
/// sensor (HeadingStream.kt) and CoreLocation on iPhone (AppDelegate.swift).
/// Both are calibrated by the OS, steadied by the gyroscope, and corrected to
/// true north for the position passed in. This screen used to fuse the raw
/// accelerometer and magnetometer itself and smooth both to hide their jitter:
/// slow to follow the phone, and on iPhone off by the phone's own magnetism.
///
/// That fusion is still here as the fallback for a phone without those
/// sensors, or a build without the native side.
class CompassHeading {
  CompassHeading._();

  static const EventChannel _channel = EventChannel('com.niyaet.ekub/heading');

  /// Readings for as long as the stream is listened to. [latitude] and
  /// [longitude] let Android correct to true north (iPhone uses its own fix).
  static Stream<CompassReading> watch({double? latitude, double? longitude}) {
    StreamSubscription<dynamic>? native;
    StreamSubscription<AccelerometerEvent>? accelerometer;
    StreamSubscription<MagnetometerEvent>? magnetometer;
    late final StreamController<CompassReading> controller;

    void startFallback() {
      List<double>? gravity;
      List<double>? magnetic;

      void emit() {
        final g = gravity;
        final m = magnetic;
        if (g == null || m == null || controller.isClosed) return;

        final azimuth = QiblaCalculator.azimuthFrom(gravity: g, geomagnetic: m);
        if (azimuth == null) return;

        controller.add(
          CompassReading(
            heading: azimuth,
            trueNorth: false,
            needsCalibration: false,
            tilt: _tiltFromGravity(g),
          ),
        );
      }

      void fail(Object error) {
        if (!controller.isClosed) controller.addError(error);
      }

      try {
        accelerometer =
            accelerometerEventStream(
              samplingPeriod: SensorInterval.gameInterval,
            ).listen((e) {
              gravity = QiblaCalculator.lowPass([e.x, e.y, e.z], gravity);
              emit();
            }, onError: fail);

        magnetometer =
            magnetometerEventStream(
              samplingPeriod: SensorInterval.gameInterval,
            ).listen((e) {
              magnetic = QiblaCalculator.lowPass([e.x, e.y, e.z], magnetic);
              emit();
            }, onError: fail);
      } catch (error) {
        fail(error);
      }
    }

    controller = StreamController<CompassReading>(
      onListen: () {
        final hasNative = defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;

        if (kIsWeb || !hasNative) {
          startFallback();
          return;
        }

        native = _channel
            .receiveBroadcastStream(<String, Object?>{
              'latitude': latitude,
              'longitude': longitude,
            })
            .listen(
              (event) {
                if (event is! Map || controller.isClosed) return;

                final heading = (event['heading'] as num?)?.toDouble();
                if (heading == null || !heading.isFinite) return;

                controller.add(
                  CompassReading(
                    heading: (heading % 360 + 360) % 360,
                    trueNorth: event['trueNorth'] == true,
                    needsCalibration: _needsCalibration(event),
                    tilt: (event['tilt'] as num?)?.toDouble(),
                  ),
                );
              },
              // No native heading (an old build, or no such sensor): fuse the
              // raw sensors here instead.
              onError: (Object _) {
                unawaited(native?.cancel());
                native = null;
                startFallback();
              },
            );
      },
      onCancel: () async {
        await native?.cancel();
        await accelerometer?.cancel();
        await magnetometer?.cancel();
      },
    );

    return controller.stream;
  }

  /// How far off flat the phone is, from the gravity vector the fallback
  /// already has: the angle between gravity and the phone's own "up". Flat on
  /// its back reads 0, straight upright 90.
  static double? _tiltFromGravity(List<double> g) {
    if (g.length < 3) return null;
    final length = math.sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
    if (length < 0.5) return null;
    final cosine = (g[2] / length).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }

  /// iPhone sends its own error estimate in degrees, negative when the
  /// reading is not valid. Android sends a sensor status (3 high .. 0
  /// unreliable), and an error estimate when the sensor has one.
  static bool _needsCalibration(Map<dynamic, dynamic> event) {
    final degrees = (event['accuracyDegrees'] as num?)?.toDouble();
    if (degrees != null) return degrees < 0 || degrees > 25;

    final status = event['accuracy'];
    if (status is int) return status <= 1;

    return false;
  }
}
