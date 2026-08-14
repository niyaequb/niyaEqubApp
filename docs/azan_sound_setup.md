# Azan sound setup

Reference for the adhan audio used by the Ibada Center's prayer notifications.

## Current status

`android/app/src/main/res/raw/azan.wav` is present (~5.05 MB). Android resolves
it by name at runtime, so the azan channel will play it.

An iOS copy has **not** been added yet. See the iOS section below.

---

## Important: never put non-resource files in `res/raw/`

This document originally lived in `res/raw/` and broke the build:

```
ERROR: .../res/raw/README.md: 'R' is not a valid file-based resource name
character: File-based resource names must contain only lowercase a-z, 0-9,
or underscore
```

The Android resource merger compiles **every** file in `res/raw/` into the
resource table. `README.md` fails twice over — capital letters and a dot in the
stem. Keep that folder limited to actual resources; documentation belongs here
in `docs/`.

Files beginning with a dot (`.gitkeep`, `.DS_Store`) are exempt: aapt's default
ignore pattern skips them.

## Naming rules

* lowercase only
* letters, digits and underscores only — **no hyphens, no spaces, no capitals**
* the extension is stripped, so `azan.wav` is referenced in code as
  `RawResourceAndroidNotificationSound('azan')`

## Length and file size

Keep the clip to **30 seconds or less**. Android truncates notification sounds
at roughly 30 s regardless, and a longer clip cut off mid-phrase sounds worse
than a short one that completes.

The current file is about 5 MB, which is roughly 30 s of 44.1 kHz 16-bit stereo
PCM. That is the full length available, but it ships inside the APK and adds
5 MB to every download. Converting to mono halves it with no audible loss for a
notification tone:

```
ffmpeg -i azan.wav -ac 1 -ar 44100 -c:a pcm_s16le azan_mono.wav
```

If you want the **full** adhan to play rather than a 30 s excerpt, that needs a
foreground service with an audio player instead of a notification sound — a
different mechanism requiring `FOREGROUND_SERVICE` permission and a persistent
notification.

## iOS

Android and iOS do not share the file. iOS needs its own copy:

| Platform | Path | Format |
|---|---|---|
| Android | `android/app/src/main/res/raw/azan.wav` | WAV, PCM 16-bit, 44.1 kHz |
| iOS | `ios/Runner/azan.caf` | CAF or AIFF |

Convert:

```
ffmpeg -i android/app/src/main/res/raw/azan.wav -f caf -c:a pcm_s16le ios/Runner/azan.caf
```

Dropping the file into the folder is not enough. Open `ios/Runner.xcworkspace`,
drag `azan.caf` into the **Runner** target, and confirm it appears under
*Build Phases → Copy Bundle Resources*. Otherwise iOS silently falls back to the
default notification sound.

The filename is referenced in
`lib/features/member/islamic/services/azan_notification_service.dart` as
`sound: 'azan.caf'` — including the extension, unlike Android.

## Licensing

Use a recording you have the right to ship. Muezzin recordings are performances
and are frequently copyrighted even when distributed free of charge — "found
online" is not a licence. Defensible sources:

* a recording commissioned from a local muezzin, with written permission
* a public-domain or CC0 recording, with the licence documented
* a commercially licensed audio library

Keep whatever licence or permission you rely on in this folder alongside this
file.

## Changing the sound after release

Android freezes a notification channel's sound at creation time. Replacing
`azan.wav` in an update will **not** change the sound for existing users — they
keep hearing the old one until they reinstall the app.

To push a new sound, bump the channel id in
`lib/features/member/islamic/services/azan_notification_service.dart`:

```dart
static const String azanChannelId = 'azan_channel_v1';  // -> 'azan_channel_v2'
```

The old channel lingers in the system notification settings until reinstall,
which is why the id carries a version suffix rather than a descriptive name.
