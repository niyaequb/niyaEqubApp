package com.niyaet.ekub

import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Captures the crash that kills the app and keeps it on disk so it can be read
 * on the next launch.
 *
 * WHY THIS EXISTS
 *
 * The app dies on some devices and not others, and the devices it dies on
 * belong to clients in another city. `adb logcat` needs the phone in your hand,
 * Flutter's own error handling only sees Dart exceptions, and a screenshot of
 * "Niya Umrah Equb keeps stopping" says nothing about what threw.
 *
 * A default uncaught-exception handler is the one place that sees EVERY Java
 * and Kotlin throwable in the process, including the ones thrown from inside
 * plugins on the platform thread — which is exactly the class of failure that
 * separates Android 13 from Android 12 (SecurityException on a foreground
 * service, a missing receiver export flag, a permission that used to be
 * implicit). Dart cannot catch those; a `try` around the Dart call site is
 * useless because the throw happens on the other side of the JNI boundary.
 *
 * WHAT IT DOES NOT DO
 *
 * This is not a substitute for Crashlytics on a shipped app, and it does not
 * catch native signals (SIGSEGV in libflutter.so or a plugin's .so). It covers
 * JVM throwables, which is the overwhelming majority of "keeps stopping" on
 * an app like this one.
 *
 * The report is written to the app's private files directory. Nothing is sent
 * anywhere: the user is shown the text on next launch and chooses whether to
 * share it.
 */
object CrashReporter {

    private const val TAG = "CrashReporter"
    private const val FILE_NAME = "last_crash.txt"

    /** Guards against installing twice if the activity is recreated. */
    private var installed = false

    /**
     * Chains rather than replaces.
     *
     * The previous handler is what actually shows the system dialog and kills
     * the process. Swallowing it would leave the app frozen on a dead frame,
     * which is worse than crashing — so this records, then hands over.
     */
    fun install(context: Context) {
        if (installed) return
        installed = true

        val appContext = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                write(appContext, format(appContext, thread.name, throwable))
            } catch (e: Throwable) {
                // A crash inside the crash handler must never replace the
                // original crash — that would hide the very thing being
                // chased.
                Log.e(TAG, "failed to record crash", e)
            }

            previous?.uncaughtException(thread, throwable)
        }

        Log.i(TAG, "installed")
    }

    /** The report from the last crash, or null when the last run was clean. */
    fun read(context: Context): String? {
        val file = File(context.filesDir, FILE_NAME)
        return try {
            if (file.exists()) file.readText() else null
        } catch (e: Throwable) {
            Log.w(TAG, "could not read crash report", e)
            null
        }
    }

    fun clear(context: Context) {
        try {
            File(context.filesDir, FILE_NAME).delete()
        } catch (e: Throwable) {
            Log.w(TAG, "could not clear crash report", e)
        }
    }

    /**
     * Used by the Dart side to record an uncaught Dart error into the same
     * file, so one report covers both sides of the bridge.
     */
    fun record(context: Context, body: String) {
        try {
            write(context.applicationContext, header(context) + body + "\n")
        } catch (e: Throwable) {
            Log.w(TAG, "could not record report", e)
        }
    }

    // ------------------------------------------------------------------

    private fun write(context: Context, text: String) {
        File(context.filesDir, FILE_NAME).writeText(text)
    }

    private fun format(context: Context, threadName: String, throwable: Throwable): String {
        val trace = StringWriter()
        throwable.printStackTrace(PrintWriter(trace))

        return buildString {
            append(header(context))
            append("Source: NATIVE (uncaught JVM exception)\n")
            append("Thread: ").append(threadName).append("\n\n")
            append(trace.toString())
        }
    }

    /**
     * Device and build identity, first, and deliberately verbose.
     *
     * The Android version line is the single most useful thing in the file:
     * this whole investigation started from "works on 12, dies on 13", and a
     * report without an API level cannot confirm or kill that theory.
     */
    private fun header(context: Context): String {
        val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())

        val version = try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            info.versionName ?: "unknown"
        } catch (e: Throwable) {
            "unknown"
        }

        return buildString {
            append("=== Niya Umrah Equb crash report ===\n")
            append("When:     ").append(stamp).append("\n")
            append("App:      ").append(version).append("\n")
            append("Android:  ").append(Build.VERSION.RELEASE)
                .append(" (API ").append(Build.VERSION.SDK_INT).append(")\n")
            append("Device:   ").append(Build.MANUFACTURER).append(" ")
                .append(Build.MODEL).append("\n")
            append("Build:    ").append(Build.DISPLAY).append("\n")
            append("ABIs:     ").append(Build.SUPPORTED_ABIS.joinToString(", ")).append("\n")
            append("\n")
        }
    }
}
