package com.niyaet.ekub

import android.annotation.TargetApi
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Makes a downloaded adhan voice playable as a notification sound.
 *
 * WHY THIS IS NEEDED
 *
 * Android plays a notification channel's sound itself, from the system UI
 * process, so that process has to be able to read the file. A download in
 * the app's private storage is invisible to it, and a file:// address is
 * refused outright. Since Android 10 an app may put an audio file in the
 * shared Notifications folder without asking for any permission, and the
 * system can always read what is there — so the voice is copied into
 * Notifications/Niya Adhan and the content:// address of that copy is what
 * the adhan's notification channel is created with. It survives restarts and
 * needs nothing re-granted.
 *
 * Android 9 and older would need a storage permission for the same thing,
 * so there the app keeps the built-in adhan (isSupported is false).
 *
 * See lib/features/member/islamic/services/azan_voices.dart.
 */
object AzanSounds {

    private const val FOLDER = "Niya Adhan"

    val isSupported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /**
     * Copies [path] into the shared Notifications folder as [fileName] and
     * returns its content:// address, or null if that was not possible.
     * A copy already there with the same name and size is reused.
     */
    fun publish(context: Context, path: String, fileName: String, title: String): String? {
        if (!isSupported) return null
        return publishQ(context, path, fileName, title)
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun publishQ(context: Context, path: String, fileName: String, title: String): String? {
        val source = File(path)
        if (!source.isFile || fileName.isBlank()) return null

        val resolver = context.contentResolver
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val folder = Environment.DIRECTORY_NOTIFICATIONS + "/" + FOLDER + "/"

        for ((uri, size) in existing(context, fileName)) {
            if (size == source.length()) return uri.toString()
            // Same name, different file: the voice was replaced on the server.
            resolver.delete(uri, null, null)
        }

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Audio.Media.TITLE, title.ifBlank { fileName })
            put(MediaStore.Audio.Media.MIME_TYPE, mimeTypeOf(fileName))
            put(MediaStore.Audio.Media.RELATIVE_PATH, folder)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_MUSIC, 0)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }

        val uri: Uri = resolver.insert(collection, values) ?: return null

        return try {
            val copied = resolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { input -> input.copyTo(out) }
            }
            if (copied == null) throw IllegalStateException("No output stream for $uri")

            val ready = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
            resolver.update(uri, ready, null, null)
            uri.toString()
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            null
        }
    }

    /** Removes the shared copy of a voice the member deleted. */
    fun unpublish(context: Context, fileName: String) {
        if (!isSupported || fileName.isBlank()) return
        for ((uri, _) in existing(context, fileName)) {
            try {
                context.contentResolver.delete(uri, null, null)
            } catch (e: Exception) {
                // Not ours any more (the app was reinstalled); leave it.
            }
        }
    }

    /** Copies of [fileName] this app has already put in the folder. */
    @TargetApi(Build.VERSION_CODES.Q)
    private fun existing(context: Context, fileName: String): List<Pair<Uri, Long>> {
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val folder = Environment.DIRECTORY_NOTIFICATIONS + "/" + FOLDER + "/"
        val found = mutableListOf<Pair<Uri, Long>>()

        context.contentResolver.query(
            collection,
            arrayOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.SIZE),
            "${MediaStore.Audio.Media.DISPLAY_NAME}=? AND ${MediaStore.Audio.Media.RELATIVE_PATH}=?",
            arrayOf(fileName, folder),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                found.add(ContentUris.withAppendedId(collection, cursor.getLong(0)) to cursor.getLong(1))
            }
        }

        return found
    }

    private fun mimeTypeOf(fileName: String): String =
        when (fileName.substringAfterLast('.', "").lowercase()) {
            "m4a", "aac", "mp4" -> "audio/mp4"
            "ogg", "oga", "opus" -> "audio/ogg"
            "wav" -> "audio/x-wav"
            else -> "audio/mpeg"
        }
}
