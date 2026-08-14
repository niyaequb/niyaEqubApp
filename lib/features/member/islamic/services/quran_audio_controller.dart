import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';
import 'package:niya_equb/features/member/islamic/data/repository/quran_repository.dart';

/// How the player behaves when a verse finishes.
enum RecitationRepeat {
  /// Advance through the surah once, then stop.
  none,

  /// Repeat the current verse indefinitely — the memorisation mode.
  ayah,

  /// Loop the whole surah.
  surah,
}

/// Owns Quran playback for the whole app.
///
/// Registered as a singleton rather than created per screen, for two reasons:
/// recitation has to keep going when the user leaves the reader, and the
/// platform media session is a process-wide resource — two players fighting
/// over it produces a notification that controls the wrong one.
///
/// Playback is modelled as a playlist of one entry per ayah rather than a
/// single surah-length file. That costs a request per verse, but it is what
/// gives the notification working next/previous buttons, lets the on-screen
/// highlight follow the reciter, and makes "repeat this verse" possible at all.
class QuranAudioController {
  QuranAudioController({required QuranRepository repository})
    : _repository = repository {
    // Surface decode and network failures instead of letting the player sit
    // silently in a broken state.
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stack) {
        logger('Quran audio: playback error — $error');
        _errorController.add(_describe(error));
      },
    );
  }

  /// Turns an ExoPlayer failure into something worth showing a user.
  ///
  /// Everything used to surface as "check your connection", which is actively
  /// misleading for the most likely failure here: a 403 from the CDN means the
  /// reciter/bitrate combination does not exist, and no amount of reconnecting
  /// will fix it. Sending someone to check their wifi over a wrong URL wastes
  /// their time and hides ours.
  static String _describe(Object error) {
    final text = error.toString();

    if (text.contains('403') || text.contains('404')) {
      return 'audio_reciter_unavailable';
    }
    return 'audio_failed';
  }

  final QuranRepository _repository;
  final AudioPlayer _player = AudioPlayer();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  SurahContent? _content;
  Reciter _reciter = Reciter.alafasy;
  RecitationRepeat _repeat = RecitationRepeat.none;

  /// The reciter the CURRENT playlist was actually built with.
  ///
  /// Kept apart from [_reciter], which is only ever the user's selection.
  /// Collapsing the two is what broke reciter switching: changeReciter() wrote
  /// the new choice into _reciter and then called load(), which compared
  /// `_reciter.id == reciter.id`, found them equal because it had just been
  /// told so, concluded the playlist was already correct, and skipped the
  /// rebuild. The audio URLs never changed and every reciter played as
  /// Alafasy.
  ///
  /// Null whenever no playlist is loaded.
  Reciter? _loadedReciter;

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  AudioPlayer get player => _player;
  SurahContent? get content => _content;
  Reciter get reciter => _reciter;
  RecitationRepeat get repeat => _repeat;
  bool get isPlaying => _player.playing;
  double get speed => _player.speed;

  /// Number of the surah currently loaded, or null when idle.
  int? get surahNumber => _content?.info.number;

  /// 1-based ayah currently loaded, or null when idle.
  int? get currentAyah {
    final index = _player.currentIndex;
    if (index == null || _content == null) return null;
    return index + 1;
  }

  /// Emits the 1-based ayah as the reciter moves through the surah.
  Stream<int?> get currentAyahStream =>
      _player.currentIndexStream.map((index) => index == null ? null : index + 1);

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<String> get errorStream => _errorController.stream;

  /// True when this controller is currently driving the given surah, whether
  /// or not it is actively playing. Lets the reader decide between resuming
  /// and loading fresh.
  bool isLoadedFor(int surah) => _content?.info.number == surah;

  // ------------------------------------------------------------------
  // Loading
  // ------------------------------------------------------------------

  /// Points the player at [content], starting from [startAyah].
  ///
  /// Rebuilding the playlist is skipped when the same surah and reciter are
  /// already loaded — otherwise tapping a second verse would tear down and
  /// re-buffer the whole queue for no reason.
  Future<void> load({
    required SurahContent content,
    required Reciter reciter,
    int startAyah = 1,
    bool autoPlay = true,
  }) async {
    // Compared against _loadedReciter, never _reciter. What matters is which
    // reciter the queued audio sources point at, not which one the user has
    // selected — those differ for exactly as long as it takes to rebuild the
    // playlist, which is the window this check governs.
    final alreadyLoaded =
        _content?.info.number == content.info.number &&
        _loadedReciter?.id == reciter.id &&
        _player.audioSource != null;

    _content = content;
    _reciter = reciter;

    if (alreadyLoaded) {
      await seekToAyah(startAyah);
      if (autoPlay) await play();
      return;
    }

    final children = <AudioSource>[];

    for (final ayah in content.ayahs) {
      final url = _repository.ayahAudioUrl(
        content.info.number,
        ayah.numberInSurah,
        reciter,
      );

      children.add(
        AudioSource.uri(
          Uri.parse(url),
          // just_audio_background reads this tag to populate the notification
          // and lock screen. Without a MediaItem on every source it throws.
          tag: MediaItem(
            id: '${content.info.number}:${ayah.numberInSurah}:${reciter.id}',
            title:
                '${content.info.englishName} · Ayah ${ayah.numberInSurah}',
            album: content.info.arabicName,
            artist: reciter.name,
            displayTitle:
                '${content.info.englishName} ${content.info.number}:${ayah.numberInSurah}',
            displaySubtitle: reciter.name,
            extras: {
              'surah': content.info.number,
              'ayah': ayah.numberInSurah,
            },
          ),
        ),
      );
    }

    if (children.isEmpty) return;

    try {
      // setAudioSources, not setAudioSource(ConcatenatingAudioSource(...)).
      // The concatenating wrapper is deprecated in just_audio; the player now
      // takes the list directly and manages the queue itself.
      await _player.setAudioSources(
        children,
        initialIndex: (startAyah - 1).clamp(0, children.length - 1),
        initialPosition: Duration.zero,
      );

      // Only now is the queue genuinely built from this reciter. Setting it
      // earlier would let a failed setAudioSource leave the controller
      // claiming a playlist it does not have.
      _loadedReciter = reciter;

      await _applyRepeatMode();

      if (autoPlay) await play();
    } catch (e) {
      logger('Quran audio: could not load surah ${content.info.number} — $e');
      _loadedReciter = null;
      _errorController.add(e.toString());
      rethrow;
    }
  }

  /// Swaps reciter without losing the user's place.
  Future<void> changeReciter(Reciter reciter) async {
    if (reciter.id == _reciter.id && _loadedReciter?.id == reciter.id) return;

    final content = _content;
    if (content == null) {
      // Nothing playing, so there is no playlist to rebuild. Remember the
      // choice and the next load() picks it up.
      _reciter = reciter;
      return;
    }

    final resumeAt = currentAyah ?? 1;
    final wasPlaying = _player.playing;

    await _player.stop();

    // NOT setting _reciter here. load() assigns it, and assigning it early is
    // precisely the bug this method used to have — stop() does not clear
    // audioSource in just_audio, so every other term in load()'s alreadyLoaded
    // check was already true and this one completed the set.
    await load(
      content: content,
      reciter: reciter,
      startAyah: resumeAt,
      autoPlay: wasPlaying,
    );
  }

  // ------------------------------------------------------------------
  // Transport
  // ------------------------------------------------------------------

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      logger('Quran audio: play failed — $e');
      _errorController.add(e.toString());
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() =>
      _player.playing ? _player.pause() : play();

  /// Stops and releases the queue, clearing the media notification.
  Future<void> stop() async {
    await _player.stop();
    _content = null;
    _loadedReciter = null;
  }

  Future<void> seekToAyah(int ayahNumber) async {
    final total = _content?.ayahs.length ?? 0;
    if (total == 0) return;

    final index = (ayahNumber - 1).clamp(0, total - 1);
    await _player.seek(Duration.zero, index: index);
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> previous() async {
    // Match the convention every music player uses: within the first few
    // seconds go to the previous verse, otherwise restart the current one.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  /// 0.5x to 2.0x — the slow end is for following along while memorising.
  Future<void> setSpeed(double value) async {
    await _player.setSpeed(value.clamp(0.5, 2.0));
  }

  Future<void> setRepeat(RecitationRepeat mode) async {
    _repeat = mode;
    await _applyRepeatMode();
  }

  Future<void> _applyRepeatMode() async {
    await _player.setLoopMode(switch (_repeat) {
      RecitationRepeat.none => LoopMode.off,
      RecitationRepeat.ayah => LoopMode.one,
      RecitationRepeat.surah => LoopMode.all,
    });
  }

  /// Only called when the app itself is shutting down. Screens must not call
  /// this — disposing on screen exit is what kills background playback.
  Future<void> dispose() async {
    await _errorController.close();
    await _player.dispose();
  }
}
