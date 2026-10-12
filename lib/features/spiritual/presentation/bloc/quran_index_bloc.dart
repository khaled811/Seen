import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/quran_data.dart';
import '../../domain/entities/reader_state.dart';
import '../../domain/usecases/quran_usecases.dart';
import '../../domain/utils/quran_filters.dart';
import 'quran_index_event.dart';
import 'quran_index_state.dart';

/// Quran index: surah / juz / bookmark lists with instant search.
///
/// Concurrency: typing is `restartable` with a 150 ms debounce so only the
/// last keystroke filters; other events are handled in order.
class QuranIndexBloc extends Bloc<QuranIndexEvent, QuranIndexState> {
  QuranIndexBloc({
    required LoadQuranUseCase loadQuran,
    required GetReaderStateUseCase getReaderState,
    required ToggleBookmarkUseCase toggleBookmark,
    this.debounce = const Duration(milliseconds: 150),
  })  : _loadQuran = loadQuran,
        _getReaderState = getReaderState,
        _toggleBookmark = toggleBookmark,
        super(const QuranIndexLoading()) {
    on<QuranIndexStarted>(_onStarted);
    on<QuranIndexRefreshed>(_onRefreshed);
    on<QuranIndexTabChanged>(_onTab);
    on<QuranIndexQueryChanged>(_onQuery, transformer: restartable());
    on<QuranIndexBookmarkRemoved>(_onBookmarkRemoved);
    on<QuranIndexBookmarkRestored>(_onBookmarkRestored);
  }

  final LoadQuranUseCase _loadQuran;
  final GetReaderStateUseCase _getReaderState;
  final ToggleBookmarkUseCase _toggleBookmark;
  final Duration debounce;

  QuranData? _data;
  ReaderState _reader = const ReaderState();
  QuranIndexTab _tab = QuranIndexTab.surahs;
  String _query = '';

  Future<void> _onStarted(
    QuranIndexStarted event,
    Emitter<QuranIndexState> emit,
  ) async {
    emit(const QuranIndexLoading());
    final quran = await _loadQuran();
    final reader = await _getReaderState();
    if (isClosed) return;
    quran.fold(
      (failure) => emit(QuranIndexFailure(failure.message)),
      (data) {
        _data = data;
        _reader = reader.getOrElse((_) => const ReaderState());
        emit(_build());
      },
    );
  }

  Future<void> _onRefreshed(
    QuranIndexRefreshed event,
    Emitter<QuranIndexState> emit,
  ) async {
    if (_data == null) return;
    final reader = await _getReaderState();
    if (isClosed) return;
    _reader = reader.getOrElse((_) => _reader);
    emit(_build());
  }

  void _onTab(QuranIndexTabChanged event, Emitter<QuranIndexState> emit) {
    if (_data == null || event.tab == _tab) return;
    _tab = event.tab;
    emit(_build());
  }

  Future<void> _onQuery(
    QuranIndexQueryChanged event,
    Emitter<QuranIndexState> emit,
  ) async {
    if (_data == null) return;
    if (!event.immediate) {
      await Future<void>.delayed(debounce);
    }
    _query = event.query;
    emit(_build());
  }

  Future<void> _onBookmarkRemoved(
    QuranIndexBookmarkRemoved event,
    Emitter<QuranIndexState> emit,
  ) async {
    if (_data == null) return;
    // Optimistic: a Dismissible must leave the tree in the same frame.
    _reader = _withoutBookmark(event.surah, event.ayah);
    emit(_build());
    final result = await _toggleBookmark(
      event.surah,
      event.ayah,
      now: DateTime.now(),
    );
    if (isClosed) return;
    await _reconcile(result.map((s) => s), emit);
  }

  Future<void> _onBookmarkRestored(
    QuranIndexBookmarkRestored event,
    Emitter<QuranIndexState> emit,
  ) async {
    if (_data == null || _reader.hasBookmark(event.surah, event.ayah)) return;
    _reader = ReaderState(
      bookmarks: [
        Bookmark(surah: event.surah, ayah: event.ayah, createdAt: event.createdAt),
        ..._reader.bookmarks,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      lastRead: _reader.lastRead,
      fontStep: _reader.fontStep,
    );
    emit(_build());
    final result = await _toggleBookmark(
      event.surah,
      event.ayah,
      now: event.createdAt,
    );
    if (isClosed) return;
    await _reconcile(result.map((s) => s), emit);
  }

  /// After an optimistic bookmark change: adopt the saved state, or, if the
  /// write failed, put the real persisted state back rather than lie to the
  /// user.
  Future<void> _reconcile(
    Either<Failure, ReaderState> result,
    Emitter<QuranIndexState> emit,
  ) async {
    final saved = result.toNullable();
    if (saved != null) {
      _reader = saved;
      return;
    }
    final actual = await _getReaderState();
    if (isClosed) return;
    _reader = actual.getOrElse((_) => _reader);
    emit(_build());
  }

  ReaderState _withoutBookmark(int surah, int ayah) => ReaderState(
        bookmarks: [
          for (final b in _reader.bookmarks)
            if (!b.isAt(surah, ayah)) b,
        ],
        lastRead: _reader.lastRead,
        fontStep: _reader.fontStep,
      );

  QuranIndexLoaded _build() {
    final data = _data!;
    final last = _reader.lastRead;
    final lastRead = last == null
        ? null
        : LastReadSummary(
            surah: last.surah,
            ayah: last.ayah,
            surahName: data.surah(last.surah).nameAr,
            page: data.ayah(last.surah, last.ayah)?.page ??
                data.surah(last.surah).startPage,
            juz: data.juzOf(last.surah, last.ayah),
          );
    return QuranIndexLoaded(
      tab: _tab,
      query: _query,
      rows: switch (_tab) {
        QuranIndexTab.surahs => _surahRows(data, last?.surah),
        QuranIndexTab.juz => _juzRows(data, lastRead?.juz),
        QuranIndexTab.bookmarks => _bookmarkRows(data),
      },
      lastRead: lastRead,
    );
  }

  List<QuranIndexRow> _surahRows(QuranData data, int? lastSurah) => [
        for (final s in data.surahs)
          if (surahMatches(s, _query))
            QuranIndexRow(
              number: s.number,
              title: s.nameAr,
              latin: s.transliteration,
              meta:
                  '${s.revelation.name == 'makki' ? 'مكية' : 'مدنية'} · ${toArabicDigits(s.ayahCount)} آية',
              revelation: s.revelation,
              page: s.startPage,
              highlighted: s.number == lastSurah,
              surah: s.number,
              ayah: 1,
            ),
      ];

  List<QuranIndexRow> _juzRows(QuranData data, int? lastJuz) => [
        for (final j in data.juzs)
          if (juzMatches(j, data.surah(j.firstSurah), _query))
            QuranIndexRow(
              number: j.number,
              title: toArabicDigits('الجزء ${j.number}'),
              latin: 'Juz ${j.number}',
              meta:
                  'يبدأ من ${data.surah(j.firstSurah).nameAr} · الآية ${toArabicDigits(j.firstAyah)}',
              page: j.startPage,
              highlighted: j.number == lastJuz,
              surah: j.firstSurah,
              ayah: j.firstAyah,
            ),
      ];

  List<QuranIndexRow> _bookmarkRows(QuranData data) {
    final rows = <QuranIndexRow>[];
    final q = _query.trim();
    for (final b in _reader.bookmarks) {
      final surah = data.surah(b.surah);
      final ayah = data.ayah(b.surah, b.ayah);
      if (ayah == null) continue; // stale bookmark from a different dataset
      final title = 'سورة ${surah.nameAr}';
      if (q.isNotEmpty && !surahMatches(surah, q)) continue;
      rows.add(QuranIndexRow(
        number: rows.length + 1,
        title: title,
        meta:
            'الآية ${toArabicDigits(b.ayah)} · الجزء ${toArabicDigits(ayah.juz)}',
        page: ayah.page,
        highlighted: true,
        surah: b.surah,
        ayah: b.ayah,
        bookmarkedAtMs: b.createdAt.millisecondsSinceEpoch,
      ));
    }
    return rows;
  }
}
