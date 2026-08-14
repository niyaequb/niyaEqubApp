import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/core/init/injections.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';
import 'package:niya_equb/features/member/islamic/data/repository/quran_repository.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/services/quran_audio_controller.dart';
import 'package:niya_equb/features/member/islamic/state/quran_bloc.dart';
import 'package:niya_equb/features/member/islamic/state/quran_event.dart';
import 'package:niya_equb/features/member/islamic/state/quran_state.dart';
import 'package:share_plus/share_plus.dart';

/// Reads one surah, with verse-by-verse recitation.
///
/// Playback lives in the app-wide [QuranAudioController], not in this screen.
/// That is deliberate: the recitation must keep running when the user backs
/// out to read something else or locks the phone, and the OS media controls
/// have to keep pointing at it. This screen only observes the controller's
/// streams and sends it commands.
class QuranReaderScreen extends StatefulWidget {
  static const String routeName = '/islamic-quran-reader';

  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah,
  });

  final int surahNumber;
  final int? initialAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  late final QuranBloc _bloc;
  QuranAudioController get _audio => sl<QuranAudioController>();

  StreamSubscription<int?>? _ayahSub;
  StreamSubscription<String>? _errorSub;

  bool _didScrollToInitial = false;

  /// Keeps the reading position with the reciter. Users scrolling back to
  /// re-read a verse do not want the page yanked away on the next ayah, so
  /// this can be switched off.
  bool _followRecitation = true;

  @override
  void initState() {
    super.initState();

    _bloc = QuranBloc(repository: sl<QuranRepository>())
      ..add(
        QuranLoadSurahEvent(
          widget.surahNumber,
          scrollToAyah: widget.initialAyah,
        ),
      );

    _ayahSub = _audio.currentAyahStream.listen((ayah) {
      if (!mounted) return;
      if (_audio.surahNumber != widget.surahNumber) return;

      _bloc.add(QuranSetPlayingAyahEvent(ayah));

      if (ayah != null) {
        _bloc.add(QuranSaveProgressEvent(widget.surahNumber, ayah));
        if (_followRecitation) _scrollToAyah(ayah);
      }
    });

    _errorSub = _audio.errorStream.listen((messageKey) {
      // The controller emits a translation KEY, not a message, so the reason
      // survives into whatever language the reader is in.
      if (mounted) _showSnack(messageKey.tr);
    });
  }

  @override
  void dispose() {
    _ayahSub?.cancel();
    _errorSub?.cancel();
    _scrollController.dispose();
    _bloc.close();
    // The audio controller is an app-wide singleton and is deliberately NOT
    // disposed here — doing so would kill playback the moment the user leaves
    // this screen, which is the whole thing we are trying to avoid.
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Audio commands
  // ------------------------------------------------------------------

  Future<void> _playFrom(int ayahNumber, QuranLoaded state) async {
    await _audio.load(
      content: state.content,
      reciter: state.reciter,
      startAyah: ayahNumber,
    );
  }

  Future<void> _togglePlayback(QuranLoaded state) async {
    if (_audio.isLoadedFor(widget.surahNumber)) {
      await _audio.togglePlayPause();
      return;
    }

    // Nothing loaded for this surah yet — start where the user left off.
    await _playFrom(state.scrollToAyah ?? 1, state);
  }

  bool get _isThisSurahLoaded => _audio.isLoadedFor(widget.surahNumber);

  // ------------------------------------------------------------------
  // Scrolling
  // ------------------------------------------------------------------

  void _scrollToAyah(int ayahNumber) {
    final target = _ayahKeys[ayahNumber]?.currentContext;
    if (target == null) return;

    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.25,
    );
  }

  void _maybeScrollToInitial(QuranLoaded state) {
    if (_didScrollToInitial) return;

    final target = state.scrollToAyah;
    _didScrollToInitial = true;

    if (target == null || target <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _scrollToAyah(target);
      });
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: appColors.scaffoldBackgroundColor,
        body: BlocBuilder<QuranBloc, QuranState>(
          builder: (context, state) {
            if (state is QuranLoading || state is QuranInitial) {
              return _shell(
                appColors,
                const Center(child: CircularProgressIndicator()),
              );
            }

            if (state is QuranFailure) {
              return _shell(appColors, _failureBody(appColors, state));
            }

            final loaded = state as QuranLoaded;
            _maybeScrollToInitial(loaded);

            return Column(
              children: [
                _appBar(appColors, loaded),
                Expanded(child: _verseList(appColors, loaded)),
                _playerBar(appColors, loaded),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _shell(dynamic appColors, Widget body) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _failureBody(dynamic appColors, QuranFailure state) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(26.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 46.sp,
              color: appColors.bodyTextSmallColor,
            ),
            SizedBox(height: 14.h),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.5,
                color: appColors.bodyTextSmallColor,
              ),
            ),
            SizedBox(height: 18.h),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: IslamicColors.featureQuran,
              ),
              onPressed: () =>
                  _bloc.add(QuranLoadSurahEvent(widget.surahNumber)),
              child: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar(dynamic appColors, QuranLoaded state) {
    final surah = state.content.info;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 4.w,
        right: 4.w,
        bottom: 8.h,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [IslamicColors.featureQuran, Color(0xFF15803D)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  surah.englishName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  '${surah.ayahCount} ${'ayahs'.tr}',
                  style: TextStyle(fontSize: 10.sp, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'follow_recitation'.tr,
            icon: Icon(
              _followRecitation
                  ? Icons.center_focus_strong_rounded
                  : Icons.center_focus_weak_rounded,
              color: _followRecitation ? Colors.white : Colors.white54,
            ),
            onPressed: () =>
                setState(() => _followRecitation = !_followRecitation),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields_rounded, color: Colors.white),
            onPressed: () => _showDisplaySheet(state),
          ),
        ],
      ),
    );
  }

  Widget _verseList(dynamic appColors, QuranLoaded state) {
    final surah = state.content.info;
    final offset = surah.showsBasmalah ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 20.h),
      itemCount: state.content.ayahs.length + offset,
      itemBuilder: (context, index) {
        if (surah.showsBasmalah && index == 0) {
          return _basmalah(appColors, state);
        }

        final ayah = state.content.ayahs[index - offset];
        _ayahKeys.putIfAbsent(ayah.numberInSurah, () => GlobalKey());

        return _ayahTile(appColors, state, ayah);
      },
    );
  }

  Widget _basmalah(dynamic appColors, QuranLoaded state) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: IslamicColors.featureQuran.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: IslamicColors.featureQuran.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: (state.arabicFontSize - 2).sp,
          fontWeight: FontWeight.w600,
          height: 1.9,
          color: IslamicColors.featureQuran,
        ),
      ),
    );
  }

  Widget _ayahTile(dynamic appColors, QuranLoaded state, Ayah ayah) {
    final isCurrent = state.playingAyah == ayah.numberInSurah;
    final isBookmarked = state.isBookmarked(ayah.numberInSurah);

    return Container(
      key: _ayahKeys[ayah.numberInSurah],
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isCurrent
            ? IslamicColors.featureQuran.withValues(alpha: 0.10)
            : appColors.accentColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isCurrent
              ? IslamicColors.featureQuran.withValues(alpha: 0.5)
              : (appColors.borderColor ?? Colors.transparent),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () => _showAyahSheet(state, ayah),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: IslamicColors.featureQuran.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${state.content.info.number}:${ayah.numberInSurah}',
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                          color: IslamicColors.featureQuran,
                        ),
                      ),
                    ),
                    if (ayah.sajdah) ...[
                      SizedBox(width: 6.w),
                      Tooltip(
                        message: 'sajdah'.tr,
                        child: Icon(
                          Icons.self_improvement_rounded,
                          size: 14.sp,
                          color: IslamicColors.mosqueDome,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isBookmarked)
                      Icon(
                        Icons.bookmark_rounded,
                        size: 15.sp,
                        color: IslamicColors.mosqueDome,
                      ),
                    SizedBox(width: 4.w),
                    InkWell(
                      onTap: () => _playFrom(ayah.numberInSurah, state),
                      borderRadius: BorderRadius.circular(20.r),
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          size: 20.sp,
                          color: IslamicColors.featureQuran,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  ayah.arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: state.arabicFontSize.sp,
                    fontWeight: FontWeight.w500,
                    height: 2.0,
                    color: appColors.titleTextColor,
                  ),
                ),
                if (ayah.translation != null &&
                    ayah.translation!.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Text(
                    ayah.translation!,
                    style: TextStyle(
                      fontSize: state.translationFontSize.sp,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Player bar
  // ------------------------------------------------------------------

  Widget _playerBar(dynamic appColors, QuranLoaded state) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14.w,
        6.h,
        14.w,
        6.h + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        border: Border(
          top: BorderSide(color: appColors.borderColor ?? Colors.transparent),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _progressBar(appColors),
          _transportRow(appColors, state),
        ],
      ),
    );
  }

  /// Scrub bar for the verse currently being recited.
  Widget _progressBar(dynamic appColors) {
    return StreamBuilder<Duration>(
      stream: _audio.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: _audio.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;

            final maxMs = duration.inMilliseconds.toDouble();
            final valueMs = position.inMilliseconds.toDouble().clamp(
              0.0,
              maxMs <= 0 ? 1.0 : maxMs,
            );

            return Row(
              children: [
                SizedBox(
                  width: 34.w,
                  child: Text(
                    _formatDuration(position),
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: maxMs <= 0 ? 0 : valueMs,
                      max: maxMs <= 0 ? 1 : maxMs,
                      activeColor: IslamicColors.featureQuran,
                      inactiveColor: IslamicColors.featureQuran.withValues(
                        alpha: 0.2,
                      ),
                      onChanged: maxMs <= 0
                          ? null
                          : (value) => _audio.seek(
                              Duration(milliseconds: value.round()),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34.w,
                  child: Text(
                    _formatDuration(duration),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _transportRow(dynamic appColors, QuranLoaded state) {
    return StreamBuilder<PlayerState>(
      stream: _audio.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processing = playerState?.processingState;
        final playing = playerState?.playing ?? false;

        final isBuffering =
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        final showsAsPlaying = playing && _isThisSurahLoaded;

        return Row(
          children: [
            _iconButton(
              appColors,
              icon: Icons.speed_rounded,
              label: '${_audio.speed.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '')}x',
              onTap: () => _showSpeedSheet(state),
            ),
            _iconButton(
              appColors,
              icon: switch (_audio.repeat) {
                RecitationRepeat.none => Icons.repeat_rounded,
                RecitationRepeat.ayah => Icons.repeat_one_rounded,
                RecitationRepeat.surah => Icons.repeat_on_rounded,
              },
              active: _audio.repeat != RecitationRepeat.none,
              onTap: () async {
                final next = switch (_audio.repeat) {
                  RecitationRepeat.none => RecitationRepeat.ayah,
                  RecitationRepeat.ayah => RecitationRepeat.surah,
                  RecitationRepeat.surah => RecitationRepeat.none,
                };
                await _audio.setRepeat(next);
                if (mounted) setState(() {});
              },
            ),
            const Spacer(),
            IconButton(
              onPressed: _isThisSurahLoaded ? _audio.previous : null,
              icon: Icon(Icons.skip_previous_rounded, size: 26.sp),
              color: appColors.titleTextColor,
            ),
            GestureDetector(
              onTap: () => _togglePlayback(state),
              child: Container(
                width: 50.w,
                height: 50.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: IslamicColors.featureQuran,
                ),
                child: isBuffering
                    ? Padding(
                        padding: EdgeInsets.all(15.w),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(
                        showsAsPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28.sp,
                      ),
              ),
            ),
            IconButton(
              onPressed: _isThisSurahLoaded ? _audio.next : null,
              icon: Icon(Icons.skip_next_rounded, size: 26.sp),
              color: appColors.titleTextColor,
            ),
            const Spacer(),
            _iconButton(
              appColors,
              icon: Icons.graphic_eq_rounded,
              onTap: () => _showReciterSheet(state),
            ),
            _iconButton(
              appColors,
              icon: Icons.stop_circle_outlined,
              onTap: () async {
                await _audio.stop();
                _bloc.add(const QuranSetPlayingAyahEvent(null));
                if (mounted) setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  Widget _iconButton(
    dynamic appColors, {
    required IconData icon,
    String? label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    final color = active
        ? IslamicColors.featureQuran
        : appColors.bodyTextSmallColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19.sp, color: color),
            if (label != null) ...[
              SizedBox(height: 1.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ------------------------------------------------------------------
  // Sheets
  // ------------------------------------------------------------------

  void _showAyahSheet(QuranLoaded state, Ayah ayah) {
    final appColors = colors(context);
    final reference =
        '${state.content.info.englishName} ${state.content.info.number}:${ayah.numberInSurah}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            Text(
              reference,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: appColors.titleTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            ListTile(
              leading: const Icon(
                Icons.play_circle_outline_rounded,
                color: IslamicColors.featureQuran,
              ),
              title: Text(
                'play_from_here'.tr,
                style: TextStyle(fontSize: 13.sp),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _playFrom(ayah.numberInSurah, state);
              },
            ),
            ListTile(
              leading: Icon(
                state.isBookmarked(ayah.numberInSurah)
                    ? Icons.bookmark_remove_rounded
                    : Icons.bookmark_add_rounded,
                color: IslamicColors.mosqueDome,
              ),
              title: Text(
                state.isBookmarked(ayah.numberInSurah)
                    ? 'remove_bookmark'.tr
                    : 'add_bookmark'.tr,
                style: TextStyle(fontSize: 13.sp),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _bloc.add(
                  QuranToggleBookmarkEvent(
                    state.content.info.number,
                    ayah.numberInSurah,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.copy_rounded,
                color: IslamicColors.primary,
              ),
              title: Text('copy'.tr, style: TextStyle(fontSize: 13.sp)),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: _shareText(ayah, reference)),
                );
                Navigator.pop(sheetContext);
                _showSnack('copied'.tr);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.share_rounded,
                color: IslamicColors.primary,
              ),
              title: Text('share'.tr, style: TextStyle(fontSize: 13.sp)),
              onTap: () {
                Navigator.pop(sheetContext);
                Share.share(_shareText(ayah, reference));
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  String _shareText(Ayah ayah, String reference) {
    final buffer = StringBuffer()..writeln(ayah.arabic);
    if (ayah.translation != null && ayah.translation!.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(ayah.translation);
    }
    buffer
      ..writeln()
      ..write('— $reference');
    return buffer.toString();
  }

  void _showSpeedSheet(QuranLoaded state) {
    final appColors = colors(context);
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 14.h),
            Text(
              'playback_speed'.tr,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: appColors.titleTextColor,
              ),
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w),
              child: Text(
                'playback_speed_hint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.sp,
                  height: 1.4,
                  color: appColors.bodyTextSmallColor,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            ...speeds.map((speed) {
              final selected = (_audio.speed - speed).abs() < 0.01;
              return ListTile(
                dense: true,
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? IslamicColors.featureQuran
                        : appColors.bodyTextColor,
                  ),
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: IslamicColors.featureQuran,
                        size: 18.sp,
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _audio.setSpeed(speed);
                  if (mounted) setState(() {});
                },
              );
            }),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  void _showReciterSheet(QuranLoaded state) {
    final appColors = colors(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 14.h),
              Text(
                'choose_reciter'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: appColors.titleTextColor,
                ),
              ),
              SizedBox(height: 6.h),
              ...Reciter.all.map((reciter) {
                final selected = reciter.id == state.reciter.id;
                return ListTile(
                  dense: true,
                  title: Text(
                    reciter.name,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? IslamicColors.featureQuran
                          : appColors.bodyTextColor,
                    ),
                  ),
                  subtitle: Text(
                    reciter.arabicName,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: appColors.bodyTextSmallColor,
                    ),
                  ),
                  trailing: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: IslamicColors.featureQuran,
                          size: 18.sp,
                        )
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    _bloc.add(QuranChangeReciterEvent(reciter));
                    if (_isThisSurahLoaded) {
                      await _audio.changeReciter(reciter);
                    }
                  },
                );
              }),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisplaySheet(QuranLoaded state) {
    final appColors = colors(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appColors.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final current = _bloc.state;
            if (current is! QuranLoaded) return const SizedBox.shrink();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'display_options'.tr,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: appColors.titleTextColor,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      '${'arabic_size'.tr}  ${current.arabicFontSize.round()}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                    Slider(
                      value: current.arabicFontSize.clamp(18, 44),
                      min: 18,
                      max: 44,
                      divisions: 13,
                      activeColor: IslamicColors.featureQuran,
                      onChanged: (value) {
                        _bloc.add(QuranSetFontSizeEvent(arabic: value));
                        setSheetState(() {});
                      },
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${'translation_size'.tr}  ${current.translationFontSize.round()}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: appColors.bodyTextSmallColor,
                      ),
                    ),
                    Slider(
                      value: current.translationFontSize.clamp(11, 24),
                      min: 11,
                      max: 24,
                      divisions: 13,
                      activeColor: IslamicColors.featureQuran,
                      onChanged: (value) {
                        _bloc.add(QuranSetFontSizeEvent(translation: value));
                        setSheetState(() {});
                      },
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'translation'.tr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: appColors.titleTextColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: TranslationEdition.all.map((edition) {
                        final selected = edition.id == current.translation.id;
                        return ChoiceChip(
                          label: Text(
                            edition.label,
                            style: TextStyle(fontSize: 11.sp),
                          ),
                          selected: selected,
                          selectedColor: IslamicColors.featureQuran.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (_) {
                            Navigator.pop(sheetContext);
                            _bloc.add(QuranChangeTranslationEvent(edition));
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
