# ===========================================================================
# R8 / ProGuard keep rules
#
# Release builds are minified and obfuscated; debug builds are not. Everything
# in this file exists because something in the app is reached by REFLECTION or
# BY NAME, which R8 cannot see and therefore renames or deletes. That is why
# these failures only ever show up under `flutter run --release`.
# ===========================================================================


# ---------------------------------------------------------------------------
# flutter_local_notifications  --  THE AZAN FIX
#
# The plugin ships no consumer ProGuard rules of its own, and the scheduled
# adhan never touches Dart at fire time:
#
#   zonedSchedule()   ->  Gson serialises NotificationDetails to JSON, stores
#                         it in SharedPreferences, hands AlarmManager a
#                         PendingIntent for ScheduledNotificationReceiver.
#   (hours later)     ->  the receiver wakes in a bare Android process with no
#                         Flutter engine running, Gson deserialises that JSON
#                         and rebuilds the Notification.
#
# That round trip is pure reflection: field names, generic signatures, and a
# RuntimeTypeAdapterFactory keyed on class names (that is how
# BigTextStyleInformation survives the trip). R8 rewrites all three. The
# aapt-generated rule only preserves `{ <init>(); }` on the two receivers,
# which keeps the classes alive but does nothing for the model package — so
# the receiver reads back nulls or throws, and the adhan silently never fires.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.styles.** { *; }
-dontwarn com.dexterous.**

# The three manifest-declared entry points, kept whole rather than
# constructor-only.
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }


# ---------------------------------------------------------------------------
# Gson
#
# The bundled gson.pro consumer rules are already applied, but they say so
# themselves: they are deliberately incomplete and cover only Gson's own
# classes. Third-party models with no @SerializedName annotations -- which is
# exactly what flutter_local_notifications uses -- still need these.
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations
-keepattributes AnnotationDefault

-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter { *; }
-keep class * implements com.google.gson.TypeAdapterFactory { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keep,allowobfuscation class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**
-dontwarn sun.misc.**


# ---------------------------------------------------------------------------
# timezone / flutter_timezone
#
# zonedSchedule() resolves the device's IANA zone through a platform channel.
# Nothing here is reflective, but the desugared java.time backport that
# core library desugaring pulls in confuses R8 without these.
-dontwarn java.beans.**
-dontwarn org.jetbrains.annotations.**


# ---------------------------------------------------------------------------
# audio_service / just_audio_background  --  Quran player
#
# AudioService, AudioServiceActivity and MediaButtonReceiver are all resolved
# BY NAME from AndroidManifest.xml. There is no Kotlin MainActivity in this
# project referencing them (see the comment in the manifest), so the manifest
# string is the only reference R8 can see.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.**

# ExoPlayer/Media3 backs just_audio and loads renderers reflectively.
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**


# ---------------------------------------------------------------------------
# Firebase Messaging
#
# The background isolate handler is reached from a Service the system starts
# by name. Firebase itself is heavily annotation- and reflection-driven.
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**


# ---------------------------------------------------------------------------
# Flutter embedding and plugin registration
#
# GeneratedPluginRegistrant instantiates every plugin by class name.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.embedding.**


# ---------------------------------------------------------------------------
# Other plugins in this app that resolve things by name
-keep class com.baseflow.geolocator.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn com.baseflow.**


# ---------------------------------------------------------------------------
# Mosque mode (this app's own Kotlin)
#
# MosqueModeReceiver is instantiated by the system from a manifest string, so
# aapt already generates a keep rule for its constructor. That is not enough:
# MosqueMode is a Kotlin `object`, reached only from the receiver and from the
# MethodChannel handler, and its INSTANCE field plus the SharedPreferences key
# strings are what the alarm path actually depends on. Keeping the package
# whole costs a few KB and removes a whole category of "silences in debug,
# does nothing in release" bug.
-keep class com.niyaet.ekub.MosqueMode { *; }
-keep class com.niyaet.ekub.MosqueMode$* { *; }
-keep class com.niyaet.ekub.MosqueModeReceiver { *; }
-keep class com.niyaet.ekub.MainActivity { *; }


# ---------------------------------------------------------------------------
# Crash reporting (this app's own Kotlin)
#
# CrashReporter is a Kotlin `object` reached from MainActivity.onCreate and
# from a MethodChannel handler keyed on strings. Losing it to R8 would mean
# the one build shipped to diagnose a release-only crash is the one build that
# cannot record it — so keep it whole rather than trusting reachability
# analysis through a lambda passed to setDefaultUncaughtExceptionHandler.
-keep class com.niyaet.ekub.CrashReporter { *; }
-keep class com.niyaet.ekub.CrashReporter$* { *; }


# ---------------------------------------------------------------------------
# Plugins with no keep rules of their own that reach classes reflectively.
#
# Added while chasing a release-only crash on Android 13. Each of these has
# either a native library loaded by name or an AndroidX component resolved
# through reflection, and none ships consumer rules covering it.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class dev.fluttercommunity.plus.sensors.** { *; }


# ---------------------------------------------------------------------------
# Keep the line numbers so a release crash is still readable.
# mapping.txt in build/app/outputs/mapping/release/ un-obfuscates the rest.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
