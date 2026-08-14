import 'package:equatable/equatable.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';

abstract class QuranState extends Equatable {
  const QuranState();

  @override
  List<Object?> get props => [];
}

class QuranInitial extends QuranState {
  const QuranInitial();
}

class QuranLoading extends QuranState {
  final int surahNumber;
  const QuranLoading(this.surahNumber);

  @override
  List<Object?> get props => [surahNumber];
}

class QuranLoaded extends QuranState {
  final SurahContent content;
  final TranslationEdition translation;
  final Reciter reciter;
  final double arabicFontSize;
  final double translationFontSize;

  /// "surah:ayah" keys.
  final List<String> bookmarks;

  /// Ayah currently being recited, for the highlight.
  final int? playingAyah;

  /// Set when the reader opened at a specific verse.
  final int? scrollToAyah;

  const QuranLoaded({
    required this.content,
    required this.translation,
    required this.reciter,
    required this.arabicFontSize,
    required this.translationFontSize,
    required this.bookmarks,
    this.playingAyah,
    this.scrollToAyah,
  });

  bool isBookmarked(int ayah) =>
      bookmarks.contains('${content.info.number}:$ayah');

  QuranLoaded copyWith({
    SurahContent? content,
    TranslationEdition? translation,
    Reciter? reciter,
    double? arabicFontSize,
    double? translationFontSize,
    List<String>? bookmarks,
    int? playingAyah,
    bool clearPlayingAyah = false,
    int? scrollToAyah,
    bool clearScrollTarget = false,
  }) {
    return QuranLoaded(
      content: content ?? this.content,
      translation: translation ?? this.translation,
      reciter: reciter ?? this.reciter,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      bookmarks: bookmarks ?? this.bookmarks,
      playingAyah: clearPlayingAyah ? null : (playingAyah ?? this.playingAyah),
      scrollToAyah: clearScrollTarget
          ? null
          : (scrollToAyah ?? this.scrollToAyah),
    );
  }

  @override
  List<Object?> get props => [
    content.info.number,
    content.ayahs.length,
    translation.id,
    reciter.id,
    arabicFontSize,
    translationFontSize,
    bookmarks,
    playingAyah,
    scrollToAyah,
  ];
}

class QuranFailure extends QuranState {
  final int surahNumber;
  final String message;

  const QuranFailure(this.surahNumber, this.message);

  @override
  List<Object?> get props => [surahNumber, message];
}
