package com.niyaet.ekub

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends AudioServiceActivity rather than FlutterActivity so the Quran player
 * can bind to the platform media session.
 *
 * This is not optional and it fails quietly: with a plain FlutterActivity the
 * audio still plays, but the notification-shade and lock-screen controls never
 * appear and nothing is logged. AudioServiceActivity is a thin FlutterActivity
 * subclass that keeps the engine in a cached engine group so the background
 * audio isolate can reach it.
 *
 * THIS FILE WAS PREVIOUSLY DELETED, AND WHY IT IS BACK
 *
 * It was renamed to MainActivity.kt.removed because release builds failed with
 * "Unresolved reference 'AudioServiceActivity'" — audio_service was only a
 * transitive dependency via just_audio_background, so its classes were not on
 * the app module's Kotlin compile classpath. The manifest was pointed straight
 * at AudioServiceActivity instead, which resolves at runtime from the merged
 * manifest and needs nothing to compile against.
 *
 * Mosque mode needs a MethodChannel, and a MethodChannel needs an Activity to
 * hang off. So the fix the old manifest comment prescribed has now been done:
 * audio_service is a direct dependency in pubspec.yaml, which puts it on the
 * compile classpath and makes this subclass legal again.
 *
 * If release ever fails on that unresolved reference again, check that the
 * audio_service line in pubspec.yaml is still there before touching anything
 * else.
 */
class MainActivity : AudioServiceActivity() {

    private companion object {
        const val CHANNEL = "com.niyaet.ekub/mosque_mode"
        const val CRASH_CHANNEL = "com.niyaet.ekub/crash"
    }

    /**
     * Installed before anything else, and before super.onCreate() attaches the
     * Flutter engine and registers plugins.
     *
     * Plugin registration is itself a candidate for the crash being chased, so
     * the handler has to be in place before it runs — install it after
     * super.onCreate() and the one throw worth catching is the one already
     * missed.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        CrashReporter.install(this)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRASH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(CrashReporter.read(this))
                    "clear" -> {
                        CrashReporter.clear(this)
                        result.success(true)
                    }
                    "record" -> {
                        CrashReporter.record(this, call.argument<String>("body") ?: "")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasDndAccess" -> result.success(MosqueMode.hasDndAccess(this))

                    "openDndSettings" -> {
                        // No runtime dialog exists for this grant; the only
                        // route is the system settings page.
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    }

                    "schedule" -> {
                        val times = call.argument<List<Number>>("triggerAtMillis")
                            ?.map { it.toLong() }
                            ?: emptyList()
                        val duration = call.argument<Int>("durationMinutes") ?: 30

                        // Notification copy is resolved in Dart and parked in
                        // SharedPreferences, because the alarms fire with no
                        // Flutter engine alive and GetX translations are
                        // unreachable at that point.
                        MosqueMode.saveTexts(
                            context = this,
                            onTitle = call.argument<String>("onTitle").orEmpty(),
                            onBody = call.argument<String>("onBody").orEmpty(),
                            offTitle = call.argument<String>("offTitle").orEmpty(),
                            offBody = call.argument<String>("offBody").orEmpty(),
                        )

                        MosqueMode.schedule(this, times, duration)
                        result.success(times.size)
                    }

                    "cancelAll" -> {
                        MosqueMode.cancelAll(this)
                        // Cancelling the schedule must also lift a silence
                        // that is currently in force. Otherwise turning the
                        // feature off mid-window cancels the restore alarm and
                        // leaves the phone mute with nothing left to undo it.
                        if (MosqueMode.isCurrentlySilenced(this)) {
                            MosqueMode.restore(this)
                        }
                        result.success(true)
                    }

                    "isCurrentlySilenced" ->
                        result.success(MosqueMode.isCurrentlySilenced(this))

                    "restoreNow" -> {
                        MosqueMode.restore(this)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        // Catches a silence window whose restore alarm never landed. Cheap,
        // and the difference between a bug and a bricked ringer.
        MosqueMode.restoreIfStale(this)
    }
}
