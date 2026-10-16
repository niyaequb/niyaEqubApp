import CoreLocation
import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Held here so it lives as long as the app; the channel keeps it too.
  private let headingStream = HeadingStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Qibla compass: CoreLocation's calibrated heading, measured from TRUE
    // north. See HeadingStreamHandler below and
    // lib/features/member/islamic/services/compass_heading.dart.
    if let registrar = self.registrar(forPlugin: "NiyaHeading") {
      FlutterEventChannel(name: "com.niyaet.ekub/heading", binaryMessenger: registrar.messenger())
        .setStreamHandler(headingStream)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// The compass heading for the Qibla screen.
///
/// The raw magnetometer an app can read on iPhone is not calibrated: it
/// includes the phone's own magnetism, which is why the Qibla needle could sit
/// many degrees off. CoreLocation's heading is calibrated by iOS, fused with
/// the gyroscope, and — while location updates run alongside it — corrected to
/// TRUE north, which is what the bearing to the Kaaba is measured from.
///
/// Each event: heading (degrees, 0..360), trueNorth (false when only magnetic
/// north is known), accuracyDegrees (iOS's own error estimate; negative means
/// the reading is not valid and the compass needs calibrating), tilt (degrees
/// the phone is away from lying flat, from CoreMotion).
final class HeadingStreamHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private var manager: CLLocationManager?
  private var sink: FlutterEventSink?

  /// Only for the tilt: the heading itself is CoreLocation's. A phone held at
  /// a steep angle has no meaningful "where the top edge points", and the
  /// Qibla screen says so instead of drawing a line that swings.
  private let motion = CMMotionManager()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(code: "unavailable", message: "This device has no compass.", details: nil)
    }

    let manager = CLLocationManager()
    manager.delegate = self
    // Every update, not only those a degree apart: the needle is smoothed on
    // the Dart side, and a 1° step made a slow turn look like it was ticking.
    manager.headingFilter = kCLHeadingFilterNone
    // "Where the top edge of the phone points", the same reading the Android
    // side sends, which is what a dial lying flat in the hand means.
    manager.headingOrientation = .portrait
    manager.desiredAccuracy = kCLLocationAccuracyKilometer

    // True north needs location updates running too. Without permission the
    // heading stays magnetic, and says so in every event; permission granted
    // later is picked up in locationManagerDidChangeAuthorization below.
    if isAuthorized(manager) {
      manager.startUpdatingLocation()
    }
    manager.startUpdatingHeading()

    if motion.isDeviceMotionAvailable && !motion.isDeviceMotionActive {
      motion.deviceMotionUpdateInterval = 1.0 / 20.0
      motion.startDeviceMotionUpdates()
    }

    self.manager = manager
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager?.stopUpdatingHeading()
    manager?.stopUpdatingLocation()
    manager?.delegate = nil
    manager = nil
    if motion.isDeviceMotionActive {
      motion.stopDeviceMotionUpdates()
    }
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let isTrue = newHeading.trueHeading >= 0
    var event: [String: Any] = [
      "heading": isTrue ? newHeading.trueHeading : newHeading.magneticHeading,
      "trueNorth": isTrue,
      "accuracyDegrees": newHeading.headingAccuracy,
    ]
    if let tilt = currentTilt() {
      event["tilt"] = tilt
    }
    sink?(event)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // A location failure only costs true north; headings keep coming.
  }

  /// Permission is usually granted after the Qibla screen has already
  /// started listening, so true north has to be switched on when it arrives
  /// rather than only at the start.
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard self.manager === manager else { return }
    if isAuthorized(manager) {
      manager.startUpdatingLocation()
    } else {
      manager.stopUpdatingLocation()
    }
  }

  /// Degrees away from lying flat: 0 face-up on a table, 90 held upright.
  /// CoreMotion's gravity is in g, and points down through the screen, so
  /// -z is how much of the phone's own "up" still points at the sky.
  private func currentTilt() -> Double? {
    guard let gravity = motion.deviceMotion?.gravity else { return nil }
    let upward = max(-1.0, min(1.0, -gravity.z))
    return acos(upward) * 180.0 / Double.pi
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    return true
  }

  private func isAuthorized(_ manager: CLLocationManager) -> Bool {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    return status == .authorizedWhenInUse || status == .authorizedAlways
  }
}
