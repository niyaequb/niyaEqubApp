import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/member/islamic/data/models/surah_model.dart';
import 'package:niya_equb/features/member/islamic/data/repository/quran_repository.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';
import 'package:niya_equb/features/member/islamic/state/quran_event.dart';
import 'package:niya_equb/features/member/islamic/state/quran_state.dart';

class QuranBloc extends Bloc<QuranEvent, QuranState> {
  QuranBloc({required this.repository}) : super(const QuranInitial()) {
    on<QuranLoadSurahEvent>(_onLoadSurah);
    on<QuranChangeTranslationEvent>(_onChangeTranslation);
    on<QuranChangeReciterEvent>(_onChangeReciter);
    on<QuranSetFontSizeEvent>(_onSetFontSize);
    on<QuranToggleBookmarkEvent>(_onToggleBookmark);
    on<QuranSaveProgressEvent>(_onSaveProgress);
    on<QuranSetPlayingAyahEvent>(_onSetPlayingAyah);
  }

  final QuranRepository repository;

  Future<void> _onLoadSurah(
    QuranLoadSurahEvent event,
    Emitter<QuranState> emit,
  ) async {
    emit(QuranLoading(event.surahNumber));

    final translation = TranslationEdition.fromId(
      await IslamicPrefs.getTranslationId(),
    );

    try {
      final content = await repository.getSurah(
        event.surahNumber,
        translation: translation,
      );

      emit(
        QuranLoaded(
          content: content,
          translation: translation,
          reciter: Reciter.fromId(await IslamicPrefs.getReciterId()),
          arabicFontSize: await IslamicPrefs.getArabicFontSize(),
          translationFontSize: await IslamicPrefs.getTranslationFontSize(),
          bookmarks: await IslamicPrefs.getBookmarks(),
          scrollToAyah: event.scrollToAyah,
        ),
      );
    } on QuranUnavailable catch (e) {
      emit(QuranFailure(event.surahNumber, e.message));
    } catch (e) {
      logger('Quran bloc: load failed — $e');
      emit(
        QuranFailure(
          event.surahNumber,
          'Something went wrong loading this surah.',
        ),
      );
    }
  }

  Future<void> _onChangeTranslation(
    QuranChangeTranslationEvent event,
    Emitter<QuranState> emit,
  ) async {
    await IslamicPrefs.setTranslationId(event.translation.id);

    final current = state;
    if (current is! QuranLoaded) return;

    final surahNumber = current.content.info.number;

    // Keep the current text on screen while the new edition loads — blanking
    // the page to a spinner on a translation toggle feels broken.
    try {
      final content = await repository.getSurah(
        surahNumber,
        translation: event.translation,
      );
      emit(
        current.copyWith(content: content, translation: event.translation),
      );
    } on QuranUnavailable catch (e) {
      emit(QuranFailure(surahNumber, e.message));
    }
  }

  Future<void> _onChangeReciter(
    QuranChangeReciterEvent event,
    Emitter<QuranState> emit,
  ) async {
    await IslamicPrefs.setReciterId(event.reciter.id);

    final current = state;
    if (current is QuranLoaded) {
      emit(current.copyWith(reciter: event.reciter, clearPlayingAyah: true));
    }
  }

  Future<void> _onSetFontSize(
    QuranSetFontSizeEvent event,
    Emitter<QuranState> emit,
  ) async {
    if (event.arabic != null) {
      await IslamicPrefs.setArabicFontSize(event.arabic!);
    }
    if (event.translation != null) {
      await IslamicPrefs.setTranslationFontSize(event.translation!);
    }

    final current = state;
    if (current is QuranLoaded) {
      emit(
        current.copyWith(
          arabicFontSize: event.arabic == null
              ? null
              : await IslamicPrefs.getArabicFontSize(),
          translationFontSize: event.translation == null
              ? null
              : await IslamicPrefs.getTranslationFontSize(),
        ),
      );
    }
  }

  Future<void> _onToggleBookmark(
    QuranToggleBookmarkEvent event,
    Emitter<QuranState> emit,
  ) async {
    await IslamicPrefs.toggleBookmark(event.surahNumber, event.ayahNumber);

    final current = state;
    if (current is QuranLoaded) {
      emit(current.copyWith(bookmarks: await IslamicPrefs.getBookmarks()));
    }
  }

  Future<void> _onSaveProgress(
    QuranSaveProgressEvent event,
    Emitter<QuranState> emit,
  ) async {
    await IslamicPrefs.saveLastRead(event.surahNumber, event.ayahNumber);
  }

  Future<void> _onSetPlayingAyah(
    QuranSetPlayingAyahEvent event,
    Emitter<QuranState> emit,
  ) async {
    final current = state;
    if (current is! QuranLoaded) return;

    emit(
      event.ayahNumber == null
          ? current.copyWith(clearPlayingAyah: true)
          : current.copyWith(playingAyah: event.ayahNumber),
    );
  }
}
