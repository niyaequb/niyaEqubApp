import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/services/azan_notification_service.dart';
import 'package:niya_equb/features/member/islamic/services/azan_voices.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:niya_equb/features/member/islamic/services/quran_audio_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Prayer settings -> Adhan voice.
///
/// Lists the built-in adhan and every voice the admin has added. Each can be
/// heard before choosing; a voice is downloaded once, then plays from the
/// phone at every prayer time, with or without a connection.
class AzanVoicesScreen extends StatefulWidget {
  const AzanVoicesScreen({super.key});

  @override
  State<AzanVoicesScreen> createState() => _AzanVoicesScreenState();
}

class _AzanVoicesScreenState extends State<AzanVoicesScreen> {
  final QuranAudioController _audio = sl<QuranAudioController>();
  StreamSubscription<PlayerState>? _playerSub;

  List<AzanVoice> _voices = AzanVoices.cached();
  final Set<String> _downloaded = {};
  final Map<String, double> _progress = {};
  final Map<String, CancelToken> _cancelTokens = {};

  String _selectedId = AzanVoices.builtInId;
  String? _playingId;
  bool _loading = true;
  bool _customSupported = true;

  @override
  void initState() {
    super.initState();
    _playerSub = _audio.playerStateStream.listen((state) {
      final finished =
          state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle;
      final playing = state.playing && !finished
          ? _audio.previewingVoiceId
          : null;
      if (mounted && playing != _playingId) {
        setState(() => _playingId = playing);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    unawaited(_audio.stopAdhanPreview());
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _selectedId = await IslamicPrefs.getAzanVoiceId();
    _customSupported = await AzanVoices.customSoundsSupported();
    await _refreshDownloaded();
    if (mounted) setState(() {});

    try {
      final fresh = await AzanVoices.fetch();
      _voices = fresh;
      await _refreshDownloaded();
    } catch (_) {
      // Offline: the saved list stays on screen.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshDownloaded() async {
    _downloaded
      ..clear()
      ..add(AzanVoices.builtInId);
    for (final voice in _voices) {
      if (await AzanVoices.isDownloaded(voice)) _downloaded.add(voice.id);
    }
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _togglePreview(AzanVoice voice) async {
    if (_playingId == voice.id) {
      await _audio.stopAdhanPreview();
      return;
    }

    try {
      final uri = await _previewUri(voice);
      if (uri == null) return;
      await _audio.previewAdhan(voiceId: voice.id, uri: uri, title: voice.name);
    } catch (_) {
      _snack('adhan_voice_preview_failed'.tr, error: true);
    }
  }

  /// The downloaded file when there is one, else the server copy; the
  /// built-in adhan from the app's own resources on Android.
  Future<Uri?> _previewUri(AzanVoice voice) async {
    if (voice.isBuiltIn) {
      if (!Platform.isAndroid) return null;
      final info = await PackageInfo.fromPlatform();
      return Uri.parse('android.resource://${info.packageName}/raw/azan');
    }
    final local = await AzanVoices.localAudio(voice);
    if (local != null) return Uri.file(local.path);
    final url = voice.audioUrl;
    return url == null ? null : Uri.parse(url);
  }

  Future<void> _download(AzanVoice voice) async {
    final token = CancelToken();
    _cancelTokens[voice.id] = token;
    setState(() => _progress[voice.id] = 0);

    try {
      await AzanVoices.download(
        voice,
        cancelToken: token,
        onProgress: (value) {
          if (mounted) setState(() => _progress[voice.id] = value);
        },
      );
      _downloaded.add(voice.id);
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        _snack('adhan_voice_download_failed'.tr, error: true);
      }
    } catch (_) {
      _snack('adhan_voice_download_failed'.tr, error: true);
    } finally {
      _cancelTokens.remove(voice.id);
      if (mounted) setState(() => _progress.remove(voice.id));
    }
  }

  void _cancelDownload(AzanVoice voice) => _cancelTokens[voice.id]?.cancel();

  Future<void> _use(AzanVoice voice) async {
    await IslamicPrefs.setAzanVoiceId(voice.id);
    if (!mounted) return;
    setState(() => _selectedId = voice.id);

    // Every booked adhan is rebuilt with the new voice.
    await AzanNotificationService.rescheduleAll();
    _snack('adhan_voice_set'.trParams({'name': _nameOf(voice)}));
  }

  Future<void> _delete(AzanVoice voice) async {
    if (_playingId == voice.id) await _audio.stopAdhanPreview();
    final wasSelected = _selectedId == voice.id;

    await AzanVoices.delete(voice);
    _downloaded.remove(voice.id);
    if (wasSelected) {
      _selectedId = AzanVoices.builtInId;
      await AzanNotificationService.rescheduleAll();
    }
    if (mounted) setState(() {});
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB91C1C) : null,
        ),
      );
  }

  String _nameOf(AzanVoice voice) =>
      voice.isBuiltIn ? 'adhan_voice_builtin'.tr : voice.name;

  /// Whether [voice] can be the adhan on this phone.
  bool _usable(AzanVoice voice) {
    if (voice.isBuiltIn) return true;
    if (!_customSupported) return false;
    if (Platform.isIOS && voice.iosSoundUrl == null) return false;
    return true;
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    const builtIn = AzanVoice(id: AzanVoices.builtInId, name: '');

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: IslamicColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'adhan_voice'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: IslamicColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 28.h),
          children: [
            Text(
              'adhan_voice_hint'.tr,
              style: TextStyle(
                fontSize: 11.5.sp,
                height: 1.45,
                color: appColors.bodyTextSmallColor,
              ),
            ),
            if (!_customSupported && Platform.isAndroid) ...[
              SizedBox(height: 10.h),
              _notice(appColors, 'adhan_voice_old_android'.tr),
            ],
            SizedBox(height: 14.h),
            _voiceCard(appColors, builtIn),
            for (final voice in _voices) ...[
              SizedBox(height: 10.h),
              _voiceCard(appColors, voice),
            ],
            if (_loading && _voices.isEmpty) ...[
              SizedBox(height: 24.h),
              const Center(child: CircularProgressIndicator()),
            ] else if (_voices.isEmpty) ...[
              SizedBox(height: 18.h),
              Text(
                'adhan_voice_none'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: appColors.bodyTextSmallColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notice(AppColors appColors, String text) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 17.sp,
            color: const Color(0xFFB45309),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.4,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceCard(AppColors appColors, AzanVoice voice) {
    final selected = _selectedId == voice.id;
    final downloaded = _downloaded.contains(voice.id);
    final progress = _progress[voice.id];
    final playing = _playingId == voice.id;
    final canPreview = !voice.isBuiltIn || Platform.isAndroid;

    final details = <String>[
      if (voice.isBuiltIn) 'adhan_voice_builtin_desc'.tr,
      if (voice.muezzin != null) voice.muezzin!,
      if (voice.durationSeconds != null) _duration(voice.durationSeconds!),
      if (!downloaded && voice.sizeBytes != null) _size(voice.sizeBytes!),
    ];

    return Material(
      color: appColors.accentColor,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected
                ? IslamicColors.primary
                : (appColors.borderColor ?? Colors.transparent),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            // Listen first.
            IconButton.filledTonal(
              onPressed: canPreview ? () => _togglePreview(voice) : null,
              icon: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              color: IslamicColors.readable(context),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameOf(voice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: appColors.titleTextColor,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      details.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                  ],
                  if (!voice.isBuiltIn &&
                      Platform.isIOS &&
                      voice.iosSoundUrl == null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'adhan_voice_no_iphone'.tr,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontStyle: FontStyle.italic,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 6.w),
            _trailing(voice, selected, downloaded, progress),
          ],
        ),
      ),
    );
  }

  Widget _trailing(
    AzanVoice voice,
    bool selected,
    bool downloaded,
    double? progress,
  ) {
    if (progress != null) {
      return SizedBox(
        width: 44.r,
        height: 44.r,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 3,
              color: IslamicColors.primary,
            ),
            IconButton(
              tooltip: 'cancel'.tr,
              onPressed: () => _cancelDownload(voice),
              icon: Icon(Icons.close_rounded, size: 18.sp),
            ),
          ],
        ),
      );
    }

    if (!downloaded) {
      return FilledButton.icon(
        onPressed: () => _download(voice),
        style: FilledButton.styleFrom(backgroundColor: IslamicColors.primary),
        icon: Icon(Icons.download_rounded, size: 16.sp),
        label: Text(
          'adhan_voice_download'.tr,
          style: TextStyle(fontSize: 11.sp),
        ),
      );
    }

    final useButton = selected
        ? Chip(
            avatar: Icon(
              Icons.check_circle_rounded,
              size: 16.sp,
              color: IslamicColors.readable(context),
            ),
            label: Text(
              'adhan_voice_selected'.tr,
              style: TextStyle(fontSize: 10.5.sp),
            ),
          )
        : OutlinedButton(
            onPressed: _usable(voice) ? () => _use(voice) : null,
            child: Text(
              'adhan_voice_use'.tr,
              style: TextStyle(fontSize: 11.sp),
            ),
          );

    if (voice.isBuiltIn) return useButton;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        useButton,
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 18.sp),
          onSelected: (_) => _delete(voice),
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'delete',
              child: Text('adhan_voice_delete'.tr),
            ),
          ],
        ),
      ],
    );
  }

  static String _duration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }
}
