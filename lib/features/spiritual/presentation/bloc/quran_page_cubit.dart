import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/last_read.dart';
import '../../domain/entities/quran_data.dart';
import '../../domain/entities/reader_state.dart';
import '../../domain/usecases/quran_usecases.dart';

sealed class QuranPageState extends Equatable {
  const QuranPageState();

  @override
  List<Object?> get props => [];
}

class QuranPageLoading extends QuranPageState {
  const QuranPageLoading();
}

class QuranPageFailure extends QuranPageState {
  const QuranPageFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class QuranPageLoaded extends QuranPageState {
  const QuranPageLoaded({
    required this.data,
    required this.page,
    required this.fontStep,
    required this.bookmarkedPages,
    this.saveFailed = false,
    this.saveSeq = 0,
  });

  final QuranData data;

  /// The mushaf page on screen, 1..604.
  final int page;
  final int fontStep;

  /// Pages that hold at least one bookmarked ayah.
  final Set<int> bookmarkedPages;
  final bool saveFailed;
  final int saveSeq;

  /// Page text is set a little smaller than the list view so a page reads
  /// like a printed one (docs/03 §3 sizes × 0.72).
  double get fontSize => ReaderState.fontSizes[fontStep] * 0.72;
  bool get canShrink => fontStep > 0;
  bool get canGrow => fontStep < ReaderState.fontSizes.length - 1;
  bool get bookmarked => bookmarkedPages.contains(page);

  QuranPageLoaded copyWith({
    int? page,
    int? fontStep,
    Set<int>? bookmarkedPages,
    bool? saveFailed,
    int? saveSeq,
  }) =>
      QuranPageLoaded(
        data: data,
        page: page ?? this.page,
        fontStep: fontStep ?? this.fontStep,
        bookmarkedPages: bookmarkedPages ?? this.bookmarkedPages,
        saveFailed: saveFailed ?? this.saveFailed,
        saveSeq: saveSeq ?? this.saveSeq,
      );

  @override
  List<Object?> get props => [
        data,
        page,
        fontStep,
        bookmarkedPages.toList()..sort(),
        saveFailed,
        saveSeq,
      ];
}

/// The mushaf-page reader: which page is showing, font size and bookmarks. The position is saved 2 s after the user stops turning pages and
/// when the screen closes; the font size is saved at once.
///
/// Owns one [Timer] (the position save), cancelled in [close].
class QuranPageCubit extends Cubit<QuranPageState> {
  QuranPageCubit({
    required this.start,
    required LoadQuranUseCase loadQuran,
    required GetReaderStateUseCase getReaderState,
    required ToggleBookmarkUseCase toggleBookmark,
    required SaveLastReadUseCase saveLastRead,
    required SaveFontStepUseCase saveFontStep,
    DateTime Function()? clock,
    this.saveDelay = const Duration(seconds: 2),
  })  : _loadQuran = loadQuran,
        _getReaderState = getReaderState,
        _toggleBookmark = toggleBookmark,
        _saveLastRead = saveLastRead,
        _saveFontStep = saveFontStep,
        _clock = clock ?? DateTime.now,
        super(const QuranPageLoading());

  /// Where to open; resolved to its mushaf page once the data is loaded.
  final LastRead start;
  final Duration saveDelay;
  final LoadQuranUseCase _loadQuran;
  final GetReaderStateUseCase _getReaderState;
  final ToggleBookmarkUseCase _toggleBookmark;
  final SaveLastReadUseCase _saveLastRead;
  final SaveFontStepUseCase _saveFontStep;
  final DateTime Function() _clock;

  Timer? _saveTimer;
  bool _dirty = false;

  Future<void> load() async {
    final quran = await _loadQuran();
    final reader = await _getReaderState();
    if (isClosed) return;
    quran.fold(
      (failure) => emit(QuranPageFailure(failure.message)),
      (data) {
        final rs = reader.getOrElse((_) => const ReaderState());
        emit(QuranPageLoaded(
          data: data,
          page: data.ayah(start.surah, start.ayah)?.page ?? 1,
          fontStep: rs.fontStep,
          bookmarkedPages: _pagesWithBookmarks(data, rs),
        ));
      },
    );
  }

  static Set<int> _pagesWithBookmarks(QuranData data, ReaderState rs) => {
        for (final b in rs.bookmarks)
          if (data.ayah(b.surah, b.ayah) case final a?) a.page,
      };

  /// The user turned to [page].
  void onPageChanged(int page) {
    final s = state;
    if (s is! QuranPageLoaded || page == s.page) return;
    emit(s.copyWith(page: page));
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(_flush()));
  }

  /// First ayah on the current page: where the list view opens when the user
  /// switches style.
  LastRead? get position {
    final s = state;
    if (s is! QuranPageLoaded) return null;
    final first = s.data.ayahsOnPage(s.page).first;
    return LastRead(surah: first.surah, ayah: first.number);
  }

  Future<void> _flush() async {
    final at = position;
    if (!_dirty || at == null) return;
    _dirty = false;
    final result = await _saveLastRead(at);
    if (!isClosed && result.isLeft()) _reportFailure();
  }

  Future<void> increaseFont() => _setFont(1);

  Future<void> decreaseFont() => _setFont(-1);

  Future<void> _setFont(int delta) async {
    final s = state;
    if (s is! QuranPageLoaded) return;
    final step = (s.fontStep + delta).clamp(0, ReaderState.fontSizes.length - 1);
    if (step == s.fontStep) return;
    emit(s.copyWith(fontStep: step));
    final result = await _saveFontStep(step);
    if (result.isLeft()) _reportFailure();
  }

  /// Bookmarks (or un-bookmarks) the first ayah on the current page.
  Future<void> toggleBookmark() async {
    final s = state;
    if (s is! QuranPageLoaded) return;
    final onPage = s.data.ayahsOnPage(s.page);
    final rs = (await _getReaderState()).getOrElse((_) => const ReaderState());
    // Un-bookmark every bookmark on this page, or add one at the top.
    final existing = [
      for (final a in onPage)
        if (rs.hasBookmark(a.surah, a.number)) a,
    ];
    final targets = existing.isEmpty ? [onPage.first] : existing;
    var failed = false;
    ReaderState? latest;
    for (final a in targets) {
      final r = await _toggleBookmark(a.surah, a.number, now: _clock());
      r.fold((_) => failed = true, (v) => latest = v);
    }
    if (isClosed) return;
    final current = state;
    if (current is! QuranPageLoaded) return;
    if (latest != null) {
      emit(current.copyWith(
        bookmarkedPages: _pagesWithBookmarks(current.data, latest!),
      ));
    }
    if (failed) _reportFailure();
  }

  void _reportFailure() {
    final s = state;
    if (isClosed || s is! QuranPageLoaded) return;
    emit(s.copyWith(saveFailed: true, saveSeq: s.saveSeq + 1));
  }

  @override
  Future<void> close() async {
    _saveTimer?.cancel();
    await _flush();
    return super.close();
  }
}
