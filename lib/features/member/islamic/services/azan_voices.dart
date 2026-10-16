import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:path_provider/path_provider.dart';

/// One adhan voice a member can choose for the prayer-time notification.
///
/// The built-in voice ([AzanVoices.builtInId]) ships inside the app. The
/// others are uploaded by an admin (Admin -> Adhan voices) and downloaded by
/// the member from the Adhan voice screen.
class AzanVoice {
  const AzanVoice({
    required this.id,
    required this.name,
    this.muezzin,
    this.description,
    this.audioUrl,
    this.iosSoundUrl,
    this.durationSeconds,
    this.sizeBytes,
    this.version = 0,
  });

  factory AzanVoice.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final s = value?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return AzanVoice(
      id: '${json['id']}',
      name: text(json['name']) ?? '',
      muezzin: text(json['muezzin']),
      description: text(json['description']),
      audioUrl: text(json['audio_url']),
      iosSoundUrl: text(json['ios_sound_url']),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String? muezzin;
  final String? description;

  /// The full recording: what the preview plays, and Android's adhan.
  final String? audioUrl;

  /// A clip of at most 30 seconds for iPhone, which refuses longer
  /// notification sounds. Null when the admin has not provided one.
  final String? iosSoundUrl;

  final int? durationSeconds;
  final int? sizeBytes;

  /// Changes whenever the admin replaces the recording.
  final int version;

  bool get isBuiltIn => id == AzanVoices.builtInId;

  /// What its files are stored and registered under. The version is part of
  /// it, so a replaced recording is a new sound: Android fixes a channel's
  /// sound when the channel is created, and iOS caches sounds by name.
  String get soundBaseName => 'niya_adhan_${id}_v$version';
}

/// The sound the adhan notification should use right now.
class AzanSoundChoice {
  const AzanSoundChoice({
    required this.voiceId,
    required this.name,
    required this.version,
    this.androidUri,
    this.iosSound,
  });

  final String voiceId;
  final String name;
  final int version;

  /// content:// address of the published copy (Android 10+).
  final String? androidUri;

  /// File name in Library/Sounds (iPhone).
  final String? iosSound;
}

/// Lists, downloads and installs adhan voices.
class AzanVoices {
  AzanVoices._();

  /// The adhan that ships inside the app (res/raw/azan, azan.caf).
  static const String builtInId = 'default';

  static const String _cacheKey = 'islamic:azan-voices';

  /// AzanSounds.kt in MainActivity.
  static const MethodChannel _android = MethodChannel(
    'com.niyaet.ekub/azan_sounds',
  );

  /// The list is public and comes from our API; the files are plain
  /// downloads from /storage. Neither needs the signed-in client.
  static final Dio _api = Dio(
    BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static final Dio _files = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  /// The voices from the last successful fetch.
  static List<AzanVoice> cached() =>
      _parse(AppCache.read<List<dynamic>>(_cacheKey) ?? const []);

  /// The admin's current list of voices.
  static Future<List<AzanVoice>> fetch() async {
    final response = await _api.get('azan-voices');
    final body = response.data;
    final list = body is Map
        ? body['data']
        : body is List
        ? body
        : null;

    if (list is! List) return const [];
    unawaited(AppCache.write(_cacheKey, list));
    return _parse(list);
  }

  static List<AzanVoice> _parse(List<dynamic> raw) => [
    for (final item in raw)
      if (item is Map)
        AzanVoice.fromJson(Map<String, dynamic>.from(item)),
  ].where((v) => v.name.isNotEmpty && v.audioUrl != null).toList();

  /// Whether this phone can use a downloaded voice for the notification:
  /// Android 10 or newer, or an iPhone.
  static Future<bool> customSoundsSupported() async {
    if (Platform.isIOS) return true;
    if (!Platform.isAndroid) return false;
    try {
      return await _android.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Files
  // ------------------------------------------------------------------

  static Future<Directory> _voicesDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/azan_voices');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Where iOS looks for notification sounds besides the app bundle.
  static Future<Directory> _iosSoundsDir() async {
    final library = await getLibraryDirectory();
    final dir = Directory('${library.path}/Sounds');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _extensionOf(String url, String fallback) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{2,4}$').hasMatch(ext) ? ext : fallback;
  }

  static Future<File> _audioFile(AzanVoice voice) async => File(
    '${(await _voicesDir()).path}/${voice.soundBaseName}.'
    '${_extensionOf(voice.audioUrl ?? '', 'mp3')}',
  );

  /// The downloaded recording of [voice], or null when it is not on the
  /// phone (always null for the built-in voice, which lives in the app).
  static Future<File?> localAudio(AzanVoice voice) async {
    if (voice.isBuiltIn || voice.audioUrl == null) return null;
    final file = await _audioFile(voice);
    return await file.exists() ? file : null;
  }

  /// True once [voice] is fully installed: the file is on the phone and the
  /// notification sound was registered for this version of it.
  static Future<bool> isDownloaded(AzanVoice voice) async {
    if (voice.isBuiltIn) return true;
    if (await localAudio(voice) == null) return false;
    final record = await IslamicPrefs.getAzanVoiceSound(voice.id);
    return record != null &&
        (record['version'] as num?)?.toInt() == voice.version;
  }

  /// Downloads [voice] and installs it as a notification sound.
  ///
  /// Throws when the download fails; a cancelled download throws a
  /// [DioException] of type cancel.
  static Future<void> download(
    AzanVoice voice, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url = voice.audioUrl;
    if (voice.isBuiltIn || url == null) return;

    final target = await _audioFile(voice);
    final partial = File('${target.path}.part');

    await _files.download(
      url,
      partial.path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    if (await target.exists()) await target.delete();
    await partial.rename(target.path);

    String? androidUri;
    String? iosSound;

    if (Platform.isAndroid) {
      try {
        androidUri = await _android.invokeMethod<String>('publish', {
          'path': target.path,
          'fileName': target.uri.pathSegments.last,
          'title': voice.name,
        });
      } catch (_) {
        androidUri = null;
      }
    }

    final clipUrl = voice.iosSoundUrl;
    if (Platform.isIOS && clipUrl != null) {
      final name = '${voice.soundBaseName}.${_extensionOf(clipUrl, 'caf')}';
      try {
        await _files.download(
          clipUrl,
          '${(await _iosSoundsDir()).path}/$name',
          cancelToken: cancelToken,
        );
        iosSound = name;
      } on DioException catch (e) {
        // A cancel cancels the whole download; any other failure leaves the
        // voice playable in the preview, with the built-in adhan as the alert.
        if (e.type == DioExceptionType.cancel) {
          await target.delete();
          rethrow;
        }
      }
    }

    await IslamicPrefs.setAzanVoiceSound(voice.id, {
      'name': voice.name,
      'version': voice.version,
      'path': target.path,
      'androidUri': androidUri,
      'iosSound': iosSound,
    });

    await _removeOtherVersions(voice);
  }

  /// Deletes [voice]'s files. If it was the chosen voice, the built-in one
  /// takes over.
  static Future<void> delete(AzanVoice voice) async {
    if (voice.isBuiltIn) return;

    final record = await IslamicPrefs.getAzanVoiceSound(voice.id);
    await _deleteFiles(record);
    await IslamicPrefs.setAzanVoiceSound(voice.id, null);

    if (await IslamicPrefs.getAzanVoiceId() == voice.id) {
      await IslamicPrefs.setAzanVoiceId(builtInId);
    }
  }

  static Future<void> _deleteFiles(Map<String, dynamic>? record) async {
    if (record == null) return;

    final path = record['path'] as String?;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      if (Platform.isAndroid) {
        try {
          await _android.invokeMethod<bool>('unpublish', {
            'fileName': file.uri.pathSegments.last,
          });
        } catch (_) {}
      }
    }

    final iosSound = record['iosSound'] as String?;
    if (iosSound != null && Platform.isIOS) {
      final clip = File('${(await _iosSoundsDir()).path}/$iosSound');
      if (await clip.exists()) await clip.delete();
    }
  }

  /// Files of older versions of [voice] left by an earlier download.
  static Future<void> _removeOtherVersions(AzanVoice voice) async {
    final prefix = 'niya_adhan_${voice.id}_v';
    final keep = voice.soundBaseName;

    final dir = await _voicesDir();
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      final current = name.startsWith('$keep.');
      if (entity is File && name.startsWith(prefix) && !current) {
        await entity.delete();
        if (Platform.isAndroid) {
          try {
            await _android.invokeMethod<bool>('unpublish', {'fileName': name});
          } catch (_) {}
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // What the notification uses
  // ------------------------------------------------------------------

  /// The chosen voice, when it is installed and usable on this phone; null
  /// means the built-in adhan.
  ///
  /// Safe to call from the background notification isolate: it only reads
  /// SharedPreferences.
  static Future<AzanSoundChoice?> activeSound() async {
    final id = await IslamicPrefs.getAzanVoiceId();
    if (id == builtInId) return null;

    final record = await IslamicPrefs.getAzanVoiceSound(id);
    if (record == null) return null;

    final choice = AzanSoundChoice(
      voiceId: id,
      name: '${record['name'] ?? 'Adhan'}',
      version: (record['version'] as num?)?.toInt() ?? 0,
      androidUri: record['androidUri'] as String?,
      iosSound: record['iosSound'] as String?,
    );

    if (Platform.isAndroid && choice.androidUri != null) return choice;
    if (Platform.isIOS && choice.iosSound != null) return choice;
    return null;
  }
}
