package com.niyaet.ekub

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioManager
import android.os.Build
import android.util.Log
import java.util.Date

/**
 * Mosque mode: drops the phone to vibrate a few minutes after each adhan and
 * puts the ringer back automatically once the congregation is likely finished.
 *
 * VIBRATE, NOT SILENT, AND NOT DO NOT DISTURB
 *
 * An earlier version set RINGER_MODE_SILENT and switched Do Not Disturb on.
 * That was wrong twice over. Full silence means a caller in an emergency gets
 * nothing at all, and Do Not Disturb suppresses the notification itself — so
 * after prayer the user had no idea anything had arrived, and the app had
 * quietly taken over a system-wide setting they never asked it to touch.
 *
 * Vibrate is the behaviour people actually want in a mosque: nothing audible
 * disturbs the row, the phone still taps your leg, and every notification is
 * waiting normally afterwards.
 *
 * A SIDE EFFECT WORTH KNOWING
 *
 * Because of this the feature no longer needs Do Not Disturb access to work.
 * Going NORMAL -> VIBRATE does not toggle DND, so setRingerMode does not
 * demand the policy grant; only NORMAL -> SILENT does. The old code checked
 * that grant and returned early without it, which is very probably why the
 * feature looked dead on devices where it was never given: it silently did
 * nothing, and a missing grant is indistinguishable from a broken feature.
 * The grant is still requested, because restoring a user who was ALREADY on
 * silent needs it, but it is no longer a gate on the main path.
 *
 * WHY THIS IS KOTLIN AND NOT DART
 *
 * The whole point is that it fires when the app is dead. flutter_local_
 * notifications cannot help: it displays notifications, it does not run your
 * code when one fires (its background handler only runs on a user TAP). The
 * usual Dart answer is android_alarm_manager_plus, but that spins up a
 * background Flutter isolate and leans on plugin registration inside it —
 * exactly the class of thing that works in debug and dies under R8, which this
 * project has already lost three builds to. Here nothing Flutter needs to
 * exist at fire time: AlarmManager wakes a BroadcastReceiver, the receiver
 * touches AudioManager, done.
 *
 * THE RESTORE ALARM IS NOT OPTIONAL
 *
 * Silencing without a guaranteed un-silence is how an app makes someone miss a
 * day of calls. So the restore alarm is armed by the SAME receiver invocation
 * that does the silencing, immediately after it succeeds — not queued ahead of
 * time from Dart, where a later reschedule could drop it and strand the phone
 * on vibrate. If the restore somehow never lands, [restoreIfStale] catches it
 * the next time the app is opened.
 */
object MosqueMode {

    const val ACTION_SILENCE = "com.niyaet.ekub.action.MOSQUE_SILENCE"
    const val ACTION_RESTORE = "com.niyaet.ekub.action.MOSQUE_RESTORE"

    const val EXTRA_DURATION_MINUTES = "duration_minutes"

    private const val PREFS = "mosque_mode"
    private const val KEY_PREVIOUS_RINGER = "previous_ringer_mode"
    private const val KEY_ACTIVE_UNTIL = "active_until_millis"
    private const val KEY_SCHEDULED_IDS = "scheduled_request_ids"

    /**
     * Written only by the old Do-Not-Disturb build. Read once by [restore] to
     * undo a filter that version may have left switched on, then deleted. See
     * the migration note there.
     */
    private const val KEY_LEGACY_FILTER = "previous_interruption_filter"

    // Notification copy, handed over from Dart at schedule time so the text
    // matches the language the user picked. See [saveTexts].
    private const val KEY_TXT_ON_TITLE = "txt_on_title"
    private const val KEY_TXT_ON_BODY = "txt_on_body"
    private const val KEY_TXT_OFF_TITLE = "txt_off_title"
    private const val KEY_TXT_OFF_BODY = "txt_off_body"

    /** Replaced with the wall-clock end time when the body is rendered. */
    private const val TIME_PLACEHOLDER = "{time}"

    private const val CHANNEL_ACTIVE = "mosque_mode_active"
    private const val CHANNEL_RESTORED = "mosque_mode_restored"

    private const val NOTIFICATION_ACTIVE = 730001
    private const val NOTIFICATION_RESTORED = 730002

    /** Request-code base, kept clear of the notification ids used in Dart. */
    private const val REQUEST_BASE = 720000
    private const val REQUEST_RESTORE = 729999

    private const val TAG = "MosqueMode"

    // ---------------------------------------------------------------------
    // Permission
    // ---------------------------------------------------------------------

    /**
     * Whether the app holds Notification Policy access.
     *
     * No longer required for the normal path — see the class comment. It still
     * matters in one case: if the user was already on SILENT when a window
     * opened, putting them back on SILENT at the end is a change that toggles
     * Do Not Disturb, and that does need the grant. Without it such a user is
     * restored to vibrate instead, which is a reasonable degradation rather
     * than a failure.
     */
    fun hasDndAccess(context: Context): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    // ---------------------------------------------------------------------
    // Scheduling
    // ---------------------------------------------------------------------

    /**
     * Arms one silence alarm per entry in [triggerAtMillis].
     *
     * Previously armed alarms are cancelled first, so this is safe to call on
     * every reschedule. Times already past are skipped rather than fired:
     * AlarmManager delivers a past-dated alarm immediately, which would drop
     * the phone to vibrate the instant the user opened prayer settings.
     */
    fun schedule(
        context: Context,
        triggerAtMillis: List<Long>,
        durationMinutes: Int,
    ) {
        cancelAll(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val armed = mutableListOf<Int>()

        triggerAtMillis.forEachIndexed { index, at ->
            if (at <= now) return@forEachIndexed

            val requestCode = REQUEST_BASE + index
            val pending = broadcast(
                context,
                requestCode,
                Intent(context, MosqueModeReceiver::class.java).apply {
                    action = ACTION_SILENCE
                    putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                },
            )

            try {
                if (canScheduleExact(am)) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                } else {
                    // Inexact rather than nothing. A window landing a few
                    // minutes late is still worth having; discarding the whole
                    // feature because the exact-alarm permission was denied is
                    // not.
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                }
                armed += requestCode
            } catch (e: SecurityException) {
                Log.w(TAG, "could not arm silence alarm at $at", e)
            }
        }

        prefs(context).edit()
            .putString(KEY_SCHEDULED_IDS, armed.joinToString(","))
            .apply()

        Log.i(TAG, "armed ${armed.size} vibrate windows, ${durationMinutes}min each")
    }

    /**
     * Stores the notification copy for later use by the receiver.
     *
     * The alarms fire with no Flutter engine alive, so GetX translations are
     * unreachable at that moment — the text has to be resolved while the app
     * is in the foreground and parked somewhere the receiver can read it.
     * Called from the same MethodChannel hop as [schedule].
     */
    fun saveTexts(
        context: Context,
        onTitle: String,
        onBody: String,
        offTitle: String,
        offBody: String,
    ) {
        prefs(context).edit()
            .putString(KEY_TXT_ON_TITLE, onTitle)
            .putString(KEY_TXT_ON_BODY, onBody)
            .putString(KEY_TXT_OFF_TITLE, offTitle)
            .putString(KEY_TXT_OFF_BODY, offBody)
            .apply()
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val stored = prefs(context).getString(KEY_SCHEDULED_IDS, "").orEmpty()

        stored.split(",")
            .mapNotNull { it.trim().toIntOrNull() }
            .forEach { requestCode ->
                am.cancel(
                    broadcast(
                        context,
                        requestCode,
                        Intent(context, MosqueModeReceiver::class.java)
                            .apply { action = ACTION_SILENCE },
                    ),
                )
            }

        prefs(context).edit().remove(KEY_SCHEDULED_IDS).apply()
    }

    // ---------------------------------------------------------------------
    // The actual silencing
    // ---------------------------------------------------------------------

    fun silence(context: Context, durationMinutes: Int) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val store = prefs(context)

        // Only record the previous mode when a window is not already open.
        // Without this guard two alarms landing close together would record
        // VIBRATE as the "previous" mode, and the restore would be a no-op
        // that leaves the ringer off.
        if (store.getLong(KEY_ACTIVE_UNTIL, 0L) <= System.currentTimeMillis()) {
            store.edit().putInt(KEY_PREVIOUS_RINGER, audio.ringerMode).apply()
        }

        try {
            audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
        } catch (e: SecurityException) {
            // Should not happen for VIBRATE on stock Android, but a few OEM
            // skins route every ringer change through the same policy check.
            Log.w(TAG, "setRingerMode(VIBRATE) refused", e)
            return
        }

        val until = System.currentTimeMillis() + durationMinutes * 60_000L
        store.edit().putLong(KEY_ACTIVE_UNTIL, until).apply()

        // Arm the restore right here. See the class comment.
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = broadcast(
            context,
            REQUEST_RESTORE,
            Intent(context, MosqueModeReceiver::class.java)
                .apply { action = ACTION_RESTORE },
        )

        try {
            if (canScheduleExact(am)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, until, pending)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, until, pending)
            }
        } catch (e: SecurityException) {
            // Could not arm the restore, so do not stay on vibrate. Undo
            // rather than risk a phone that never rings again.
            Log.e(TAG, "could not arm restore, reverting", e)
            restore(context)
            return
        }

        postActiveNotification(context, store, until)
        Log.i(TAG, "vibrate window open until $until")
    }

    fun restore(context: Context) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val store = prefs(context)

        // Whether a window was genuinely open. restoreNow() can be called when
        // nothing is active, and announcing "your ringer is back" to someone
        // who never lost it is noise.
        val wasActive = store.contains(KEY_ACTIVE_UNTIL)

        val previousRinger =
            store.getInt(KEY_PREVIOUS_RINGER, AudioManager.RINGER_MODE_NORMAL)

        // MIGRATION, one-off.
        //
        // The Do-Not-Disturb build could leave INTERRUPTION_FILTER_ALARMS
        // switched on. A phone updating from it would keep suppressing every
        // notification forever, with nothing in the new code path to explain
        // why. If that key is present, put the filter back the way that build
        // found it and drop the key for good.
        if (store.contains(KEY_LEGACY_FILTER)) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            val legacyFilter = store.getInt(
                KEY_LEGACY_FILTER,
                NotificationManager.INTERRUPTION_FILTER_ALL,
            )
            try {
                nm.setInterruptionFilter(legacyFilter)
                Log.i(TAG, "cleared Do Not Disturb left by the previous build")
            } catch (e: SecurityException) {
                Log.w(TAG, "could not clear legacy interruption filter", e)
            }
            store.edit().remove(KEY_LEGACY_FILTER).apply()
        }

        try {
            audio.ringerMode = previousRinger
        } catch (e: SecurityException) {
            // Restoring to SILENT toggles Do Not Disturb and needs the policy
            // grant. Leaving the user on vibrate is the safer miss — they can
            // still feel a call — so fall back rather than give up.
            Log.w(TAG, "could not restore ringer $previousRinger, leaving vibrate", e)
        }

        store.edit()
            .remove(KEY_ACTIVE_UNTIL)
            .remove(KEY_PREVIOUS_RINGER)
            .apply()

        notificationManager(context).cancel(NOTIFICATION_ACTIVE)
        if (wasActive) postRestoredNotification(context, store)

        Log.i(TAG, "restored ringer to $previousRinger")
    }

    /**
     * Safety net, called when the app comes to the foreground.
     *
     * If the restore alarm was dropped — force stop, battery optimiser, an
     * aggressive OEM task killer, a clock change — the phone would sit on
     * vibrate indefinitely. This notices an expired window and puts the ringer
     * back.
     */
    fun restoreIfStale(context: Context) {
        val until = prefs(context).getLong(KEY_ACTIVE_UNTIL, 0L)
        if (until != 0L && until <= System.currentTimeMillis()) {
            Log.i(TAG, "stale window found, restoring")
            restore(context)
        }
    }

    fun isCurrentlySilenced(context: Context): Boolean =
        prefs(context).getLong(KEY_ACTIVE_UNTIL, 0L) > System.currentTimeMillis()

    // ---------------------------------------------------------------------
    // Notifications
    // ---------------------------------------------------------------------

    private fun postActiveNotification(
        context: Context,
        store: SharedPreferences,
        until: Long,
    ) {
        // The user's own 12h/24h preference, not a hardcoded pattern.
        val endsAt = android.text.format.DateFormat
            .getTimeFormat(context)
            .format(Date(until))

        val title = store.getString(KEY_TXT_ON_TITLE, null)?.takeIf { it.isNotBlank() }
            ?: "Mosque mode is on"
        val body = (store.getString(KEY_TXT_ON_BODY, null)?.takeIf { it.isNotBlank() }
            ?: "Your phone will vibrate only until $TIME_PLACEHOLDER.")
            .replace(TIME_PLACEHOLDER, endsAt)

        notify(
            context = context,
            channelId = CHANNEL_ACTIVE,
            channelName = "Mosque mode",
            // LOW is deliberate: this notification announces that the phone
            // has just gone quiet for prayer. Anything higher would buzz the
            // phone in the exact moment the feature exists to prevent that.
            importance = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                NotificationManager.IMPORTANCE_LOW
            } else {
                NotificationManager.IMPORTANCE_DEFAULT
            },
            notificationId = NOTIFICATION_ACTIVE,
            title = title,
            body = body,
            iconRes = R.drawable.ic_mosque_vibrate,
            silent = true,
            // Stays put for the length of the window so it doubles as the
            // "why is my phone on vibrate" answer, rather than vanishing on a
            // stray swipe.
            ongoing = true,
        )
    }

    private fun postRestoredNotification(context: Context, store: SharedPreferences) {
        val title = store.getString(KEY_TXT_OFF_TITLE, null)?.takeIf { it.isNotBlank() }
            ?: "Mosque mode has ended"
        val body = store.getString(KEY_TXT_OFF_BODY, null)?.takeIf { it.isNotBlank() }
            ?: "Your ringer is back to normal."

        notify(
            context = context,
            channelId = CHANNEL_RESTORED,
            channelName = "Mosque mode ended",
            // DEFAULT, unlike the one above. Prayer is over, and this is the
            // confirmation the user is waiting for — the whole point is that
            // they notice it without going looking.
            importance = NotificationManager.IMPORTANCE_DEFAULT,
            notificationId = NOTIFICATION_RESTORED,
            title = title,
            body = body,
            iconRes = R.drawable.ic_mosque_restored,
            silent = false,
            ongoing = false,
        )
    }

    /**
     * Builds and posts a notification without androidx.
     *
     * NotificationCompat would be tidier, but androidx.core reaches this module
     * only transitively through the Flutter plugins — the same shape of
     * problem that made MainActivity fail to compile against
     * AudioServiceActivity. The platform API needs no dependency at all, so
     * there is nothing here for a plugin bump to take away.
     */
    @Suppress("DEPRECATION")
    private fun notify(
        context: Context,
        channelId: String,
        channelName: String,
        importance: Int,
        notificationId: Int,
        title: String,
        body: String,
        iconRes: Int,
        silent: Boolean,
        ongoing: Boolean,
    ) {
        val nm = notificationManager(context)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                setShowBadge(false)
                if (silent) {
                    setSound(null, null)
                    enableVibration(false)
                }
            }
            nm.createNotificationChannel(channel)
        }

        val tap = PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context).setPriority(
                if (silent) Notification.PRIORITY_LOW else Notification.PRIORITY_DEFAULT,
            )
        }

        val notification = builder
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(!ongoing)
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .build()

        try {
            nm.notify(notificationId, notification)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS refused on API 33+. The ringer change itself
            // already happened and is the part that matters.
            Log.w(TAG, "notification not permitted", e)
        }
    }

    private fun notificationManager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    // ---------------------------------------------------------------------

    private fun canScheduleExact(am: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

    private fun broadcast(context: Context, requestCode: Int, intent: Intent) =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/**
 * Wakes on the alarms armed by [MosqueMode].
 *
 * Deliberately does nothing but dispatch. onReceive runs on the main thread
 * with roughly a ten second budget and no guarantee the process outlives it,
 * so everything here has to be synchronous and fast. Setting a ringer mode and
 * posting a notification are both.
 */
class MosqueModeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            MosqueMode.ACTION_SILENCE -> MosqueMode.silence(
                context,
                intent.getIntExtra(MosqueMode.EXTRA_DURATION_MINUTES, 30),
            )
            MosqueMode.ACTION_RESTORE -> MosqueMode.restore(context)
        }
    }
}
