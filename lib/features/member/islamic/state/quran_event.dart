import 'package:equatable/equatable.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';

abstract class QuranEvent extends Equatable {
  const QuranEvent();

  @override
  List<Object?> get props => [];
}

/// Loads a surah, using the cache when possible.
class QuranLoadSurahEvent extends QuranEvent {
  final int surahNumber;

  /// Scroll target once loaded, if the user resumed or tapped a bookmark.
  final int? scrollToAyah;

  const QuranLoadSurahEvent(this.surahNumber, {this.scrollToAyah});

  @override
  List<Object?> get props => [surahNumber, scrollToAyah];
}

/// Switches translation and reloads.
class QuranChangeTranslationEvent extends QuranEvent {
  final TranslationEdition translation;
  const QuranChangeTranslationEvent(this.translation);

  @override
  List<Object?> get props => [translation.id];
}

class QuranChangeReciterEvent extends QuranEvent {
  final Reciter reciter;
  const QuranChangeReciterEvent(this.reciter);

  @override
  List<Object?> get props => [reciter.id];
}

class QuranSetFontSizeEvent extends QuranEvent {
  final double? arabic;
  final double? translation;

  const QuranSetFontSizeEvent({this.arabic, this.translation});

  @override
  List<Object?> get props => [arabic, translation];
}

class QuranToggleBookmarkEvent extends QuranEvent {
  final int surahNumber;
  final int ayahNumber;

  const QuranToggleBookmarkEvent(this.surahNumber, this.ayahNumber);

  @override
  List<Object?> get props => [surahNumber, ayahNumber];
}

/// Records reading position so the home card can offer "continue reading".
class QuranSaveProgressEvent extends QuranEvent {
  final int surahNumber;
  final int ayahNumber;

  const QuranSaveProgressEvent(this.surahNumber, this.ayahNumber);

  @override
  List<Object?> get props => [surahNumber, ayahNumber];
}

/// Marks which ayah is currently being recited, for the highlight.
class QuranSetPlayingAyahEvent extends QuranEvent {
  final int? ayahNumber;
  const QuranSetPlayingAyahEvent(this.ayahNumber);

  @override
  List<Object?> get props => [ayahNumber];
}
