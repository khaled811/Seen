import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/last_read.dart';
import '../../domain/entities/quran.dart';
import '../../domain/entities/reader_state.dart';
import '../../domain/usecases/quran_usecases.dart';

sealed class QuranReaderState extends Equatable {
  const QuranReaderState();

  @override
  List<Object?> get props => [];
}

class QuranReaderLoading extends QuranReaderState {
  const QuranReaderLoading();
}

class QuranReaderFailure extends QuranReaderState {
  const QuranReaderFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class QuranReaderLoaded extends QuranReaderState {
  const QuranReaderLoaded({
    required this.surah,
    required this.ayahs,
    required this.basmala,
    required this.fontStep,
    required this.bookmarked,
    this.saveFailed = false,
    this.saveSeq = 0,
  });

  final Surah surah;
  final List<Ayah> ayahs;

  /// Header basmala text, or null for Al-Fatihah (where it is ayah 1) and
  /// At-Tawbah (which has none).
  final String? basmala;
  final int fontStep;

  /// Ayah numbers of this surah that are bookmarked.
  final Set<int> bookmarked;

  /// The last write failed; the UI shows one warning per [saveSeq].
  final bool saveFailed;
  final int saveSeq;

  double get fontSize => ReaderState.fontSizes[fontStep];
  bool get canShrink => fontStep > 0;
  bool get canGrow => fontStep < ReaderState.fontSizes.length - 1;

  QuranReaderLoaded copyWith({
    int? fontStep,
    Set<int>? bookmarked,
    bool? saveFailed,
    int? saveSeq,
  }) =>
      QuranReaderLoaded(
        surah: surah,
        ayahs: ayahs,
        basmala: basmala,
        fontStep: fontStep ?? this.fontStep,
        bookmarked: bookmarked ?? this.bookmarked,
        saveFailed: saveFailed ?? this.saveFailed,
        saveSeq: saveSeq ?? this.saveSeq,
      );

  @override
  List<Object?> get props => [
        surah,
        ayahs,
        basmala,
        fontStep,
        bookmarked.toList()..sort(),
        saveFailed,
        saveSeq,
      ];
}

/// One surah in the reader: ayahs, font size and bookmarks, all persisted the
/// moment they change.
class QuranReaderCubit extends Cubit<QuranReaderState> {
  QuranReaderCubit({
    required this.surahNumber,
    required LoadQuranUseCase loadQuran,
    required GetReaderStateUseCase getReaderState,
    required ToggleBookmarkUseCase toggleBookmark,
    required SaveLastReadUseCase saveLastRead,
    required SaveFontStepUseCase saveFontStep,
    DateTime Function()? clock,
  })  : _loadQuran = loadQuran,
        _getReaderState = getReaderState,
        _toggleBookmark = toggleBookmark,
        _saveLastRead = saveLastRead,
        _saveFontStep = saveFontStep,
        _clock = clock ?? DateTime.now,
        super(const QuranReaderLoading());

  final int surahNumber;
  final LoadQuranUseCase _loadQuran;
  final GetReaderStateUseCase _getReaderState;
  final ToggleBookmarkUseCase _toggleBookmark;
  final SaveLastReadUseCase _saveLastRead;
  final SaveFontStepUseCase _saveFontStep;
  final DateTime Function() _clock;

  Future<void> load() async {
    final quran = await _loadQuran();
    final reader = await _getReaderState();
    if (isClosed) return;
    quran.fold(
      (failure) => emit(QuranReaderFailure(failure.message)),
      (data) {
        final rs = reader.getOrElse((_) => const ReaderState());
        emit(QuranReaderLoaded(
          surah: data.surah(surahNumber),
          ayahs: data.ayahsOf(surahNumber),
          basmala: (surahNumber == 1 || surahNumber == 9)
              ? null
              : data.ayah(1, 1)!.text,
          fontStep: rs.fontStep,
          bookmarked: _forSurah(rs),
        ));
      },
    );
  }

  Set<int> _forSurah(ReaderState rs) => {
        for (final b in rs.bookmarks)
          if (b.surah == surahNumber) b.ayah,
      };

  Future<void> increaseFont() => _setFont((s) => s.fontStep + 1);

  Future<void> decreaseFont() => _setFont((s) => s.fontStep - 1);

  Future<void> _setFont(int Function(QuranReaderLoaded) next) async {
    final current = state;
    if (current is! QuranReaderLoaded) return;
    final step = next(current).clamp(0, ReaderState.fontSizes.length - 1);
    if (step == current.fontStep) return;
    emit(current.copyWith(fontStep: step)); // instant; persisted right after
    final result = await _saveFontStep(step);
    _reportFailure(result.isLeft());
  }

  /// Adds or removes the bookmark on [ayah]. Returns whether it is now
  /// bookmarked (false if the state was not loaded or the write failed).
  Future<bool> toggleBookmark(int ayah) async {
    final current = state;
    if (current is! QuranReaderLoaded) return false;
    final result = await _toggleBookmark(surahNumber, ayah, now: _clock());
    if (isClosed) return false;
    return result.fold(
      (_) {
        _reportFailure(true);
        return current.bookmarked.contains(ayah);
      },
      (rs) {
        final latest = state;
        if (latest is QuranReaderLoaded) {
          emit(latest.copyWith(bookmarked: _forSurah(rs), saveFailed: false));
        }
        return rs.hasBookmark(surahNumber, ayah);
      },
    );
  }

  /// Persists the reading position (called when scrolling settles and on
  /// exit). Failures are reported like any other write.
  Future<void> saveLastRead(int ayah) async {
    final result = await _saveLastRead(LastRead(surah: surahNumber, ayah: ayah));
    if (!isClosed && result.isLeft()) _reportFailure(true);
  }

  void _reportFailure(bool failed) {
    final current = state;
    if (isClosed || current is! QuranReaderLoaded) return;
    if (failed) {
      emit(current.copyWith(saveFailed: true, saveSeq: current.saveSeq + 1));
    }
  }
}
