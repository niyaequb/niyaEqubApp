package com.niyaet.ekub

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs
import kotlin.math.acos

/**
 * The Qibla compass's heading, from Android's own sensor fusion.
 *
 * WHY NOT THE RAW SENSORS
 *
 * The Dart side used to fuse the accelerometer and magnetometer itself and
 * then smooth both streams to hide their jitter, which left the needle a
 * second or more behind the phone. TYPE_ROTATION_VECTOR is the same fusion
 * done by the OS with the gyroscope added: it follows the phone at once,
 * does not shake, and the OS keeps the magnetometer calibrated.
 *
 * Three sensors are tried in turn, so every phone gets the best it has:
 *   1. TYPE_ROTATION_VECTOR            gyro + compass + gravity, steadiest
 *   2. TYPE_GEOMAGNETIC_ROTATION_VECTOR  no gyro, still OS-fused
 *   3. the accelerometer and magnetometer, fused here
 * Only a phone with no magnetometer at all ends with an error, and then the
 * Dart side says the phone cannot point the way.
 *
 * ONE CONVENTION: THE PHONE LIES FLAT
 *
 * The heading is always "where the top edge of the phone points", which is
 * what a dial lying in the hand means. An earlier version switched to "where
 * the back of the phone faces" once the phone was tilted past 45°, and the
 * needle jumped ninety degrees as it crossed that line. It reports [tilt]
 * instead and lets the screen ask for the phone to be laid flat.
 *
 * TRUE NORTH
 *
 * A compass finds MAGNETIC north, but the bearing to the Kaaba is measured
 * from TRUE north. The difference (declination) comes from the World Magnetic
 * Model Android ships (GeomagneticField), for the position the Qibla screen
 * passes in when it starts listening.
 *
 * Each event is a map:
 *   heading          degrees clockwise from north, 0..360
 *   trueNorth        false when no position was given (heading is magnetic)
 *   accuracy         SensorManager.SENSOR_STATUS_*: 3 high .. 0 unreliable
 *   accuracyDegrees  the sensor's own heading-error estimate, when it has one
 *   tilt             degrees the phone is away from flat, 0..180
 *
 * See lib/features/member/islamic/services/compass_heading.dart.
 */
class HeadingStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {

    private val sensorManager =
        context.applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    private var sink: EventChannel.EventSink? = null
    private var declination = 0f
    private var trueNorth = false
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH

    private val rotation = FloatArray(9)
    private val inclination = FloatArray(9)
    private val orientation = FloatArray(3)

    /** Only used by the accelerometer + magnetometer fallback. */
    private var gravity: FloatArray? = null
    private var magnetic: FloatArray? = null
    private var fusingByHand = false

    /** The last reading sent, so one that has not changed is not resent. */
    private var lastSent = Float.NaN
    private var lastTilt = Float.NaN
    private var lastAccuracy = Int.MIN_VALUE

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events == null) return

        val args = arguments as? Map<*, *>
        val latitude = (args?.get("latitude") as? Number)?.toFloat()
        val longitude = (args?.get("longitude") as? Number)?.toFloat()

        if (latitude != null && longitude != null) {
            declination = GeomagneticField(
                latitude,
                longitude,
                0f,
                System.currentTimeMillis(),
            ).declination
            trueNorth = true
        } else {
            declination = 0f
            trueNorth = false
        }

        // A second onListen without an onCancel (a hot restart, a screen
        // reopened before the old stream was torn down) would otherwise leave
        // the first registration running alongside the new one.
        sensorManager.unregisterListener(this)

        sink = events
        lastSent = Float.NaN
        lastTilt = Float.NaN
        lastAccuracy = Int.MIN_VALUE
        gravity = null
        magnetic = null

        val fused = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)

        if (fused != null) {
            fusingByHand = false
            sensorManager.registerListener(this, fused, SensorManager.SENSOR_DELAY_GAME)
            return
        }

        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (accelerometer == null || magnetometer == null) {
            sink = null
            events.error("unavailable", "This phone has no compass.", null)
            return
        }

        fusingByHand = true
        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME)
        sensorManager.registerListener(this, magnetometer, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        sink = null
        gravity = null
        magnetic = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // The magnetometer's accuracy is the one worth reporting; the
        // accelerometer's says nothing about where north is.
        if (sensor?.type == Sensor.TYPE_ACCELEROMETER) return
        this.accuracy = accuracy
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || sink == null) return

        var errorDegrees: Double? = null

        if (fusingByHand) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> gravity = smooth(gravity, event.values)
                Sensor.TYPE_MAGNETIC_FIELD -> magnetic = smooth(magnetic, event.values)
                else -> return
            }
            val a = gravity ?: return
            val m = magnetic ?: return
            if (!SensorManager.getRotationMatrix(rotation, inclination, a, m)) return
        } else {
            // A few older phones report a fifth value that
            // getRotationMatrixFromVector rejects; the first four are the
            // rotation itself.
            val values =
                if (event.values.size > 4) event.values.copyOf(4) else event.values
            SensorManager.getRotationMatrixFromVector(rotation, values)

            // values[4]: estimated heading accuracy in radians, -1 when unknown.
            if (event.values.size > 4 && event.values[4] >= 0f) {
                errorDegrees = Math.toDegrees(event.values[4].toDouble())
            }
        }

        SensorManager.getOrientation(rotation, orientation)

        val heading =
            (Math.toDegrees(orientation[0].toDouble()) + declination + 720.0) % 360.0

        // rotation[8] is how much of the phone's own "up" still points at the
        // sky: 1 flat on its back, 0 straight upright.
        val tilt = Math.toDegrees(acos(rotation[8].toDouble().coerceIn(-1.0, 1.0)))

        // Hold a reading back only when nothing has changed at all; anything
        // the eye could see is sent on, so the needle never lags the phone.
        // Tilt and accuracy count as changes too: a phone being tipped up
        // while pointing the same way still has to reach the screen.
        val moved = lastSent.isNaN() ||
            abs(shortestDelta(lastSent.toDouble(), heading)) >= 0.08 ||
            lastTilt.isNaN() ||
            abs(tilt - lastTilt) >= 1.0 ||
            accuracy != lastAccuracy
        if (!moved) return
        lastSent = heading.toFloat()
        lastTilt = tilt.toFloat()
        lastAccuracy = accuracy

        val reading = HashMap<String, Any>()
        reading["heading"] = heading
        reading["trueNorth"] = trueNorth
        reading["accuracy"] = accuracy
        reading["tilt"] = tilt
        if (errorDegrees != null) reading["accuracyDegrees"] = errorDegrees

        sink?.success(reading)
    }

    /** Takes the edge off the raw vectors the hand-fused path works from. */
    private fun smooth(previous: FloatArray?, reading: FloatArray): FloatArray {
        if (previous == null) return reading.copyOf()
        val alpha = 0.25f
        for (i in previous.indices) {
            previous[i] += alpha * (reading[i] - previous[i])
        }
        return previous
    }

    private fun shortestDelta(from: Double, to: Double): Double {
        var delta = (to - from) % 360.0
        if (delta > 180) delta -= 360.0
        if (delta < -180) delta += 360.0
        return delta
    }
}
