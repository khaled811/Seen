import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_quran_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/bookmark.dart';
import 'package:seen_booking/features/spiritual/domain/entities/last_read.dart';
import 'package:seen_booking/features/spiritual/domain/entities/quran_data.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/quran_repository.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/quran_usecases.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/quran_index_bloc.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/quran_index_event.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/quran_index_state.dart';

import '../support/fakes.dart';

class _FailingQuran implements QuranRepository {
  @override
  Future<Either<Failure, QuranData>> load() async =>
      const Left(CacheFailure('no quran'));
}

final _t = DateTime(2026, 10, 3, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JsonQuranRepository quran;
  late InMemoryReaderState reader;

  setUp(() {
    quran = JsonQuranRepository(useIsolate: false);
    reader = InMemoryReaderState();
  });

  QuranIndexBloc build({QuranRepository? repo}) => QuranIndexBloc(
        loadQuran: LoadQuranUseCase(repo ?? quran),
        getReaderState: GetReaderStateUseCase(reader),
        toggleBookmark: ToggleBookmarkUseCase(reader),
        debounce: const Duration(milliseconds: 30),
      );

  Future<QuranIndexBloc> started({QuranRepository? repo}) async {
    final bloc = build(repo: repo)..add(const QuranIndexStarted());
    await bloc.stream.firstWhere((s) => s is! QuranIndexLoading);
    return bloc;
  }

  QuranIndexLoaded loaded(QuranIndexBloc b) => b.state as QuranIndexLoaded;

  Future<void> settle([int ms = 80]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('loads all 114 surahs on the surah tab', () async {
    final bloc = await started();
    final s = loaded(bloc);
    expect(s.tab, QuranIndexTab.surahs);
    expect(s.rows, hasLength(114));
    expect(s.rows.first.title, 'الفاتحة');
    expect(s.rows.first.latin, 'Al-Faatiha');
    expect(s.rows.first.meta, 'مكية · ٧ آية');
    expect(s.rows.first.page, 1);
    expect(s.lastRead, isNull);
    await bloc.close();
  });

  test('a Quran that cannot be loaded becomes a failure state', () async {
    final bloc = await started(repo: _FailingQuran());
    expect(bloc.state, isA<QuranIndexFailure>());
    await bloc.close();
  });

  group('last read', () {
    test('is summarised with page and juz, and its surah is highlighted',
        () async {
      reader.state = const ReaderState(lastRead: LastRead(surah: 18, ayah: 3));
      final bloc = await started();
      final s = loaded(bloc);
      expect(s.lastRead?.surahName, 'الكهف');
      expect(s.lastRead?.ayah, 3);
      expect(s.lastRead?.page, 293);
      expect(s.lastRead?.juz, 15);
      expect(s.rows.where((r) => r.highlighted).map((r) => r.number), [18]);
      await bloc.close();
    });

    test('refresh picks up a position saved elsewhere', () async {
      final bloc = await started();
      expect(loaded(bloc).lastRead, isNull);
      await reader.saveLastRead(const LastRead(surah: 2, ayah: 255));
      bloc.add(const QuranIndexRefreshed());
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.lastRead != null);
      expect(loaded(bloc).lastRead?.page, 42);
      await bloc.close();
    });
  });

  group('tabs', () {
    test('juz tab lists the 30 parts with their start', () async {
      final bloc = await started();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.juz));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.juz);
      final rows = loaded(bloc).rows;
      expect(rows, hasLength(30));
      expect(rows[1].title, 'الجزء ٢');
      expect(rows[1].latin, 'Juz 2');
      expect(rows[1].meta, 'يبدأ من البقرة · الآية ١٤٢');
      expect(rows[14].page, 282);
      await bloc.close();
    });

    test('the juz of the last-read position is highlighted', () async {
      reader.state = const ReaderState(lastRead: LastRead(surah: 18, ayah: 3));
      final bloc = await started();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.juz));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.juz);
      expect(loaded(bloc).rows.where((r) => r.highlighted).map((r) => r.number), [15]);
      await bloc.close();
    });

    test('bookmarks tab lists saved positions, newest first', () async {
      reader.state = ReaderState(bookmarks: [
        Bookmark(surah: 18, ayah: 10, createdAt: _t.add(const Duration(minutes: 1))),
        Bookmark(surah: 2, ayah: 255, createdAt: _t),
      ]);
      final bloc = await started();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.bookmarks));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.bookmarks);
      final rows = loaded(bloc).rows;
      expect(rows.map((r) => r.title), ['سورة الكهف', 'سورة البقرة']);
      expect(rows.first.meta, 'الآية ١٠ · الجزء ١٥');
      expect(rows.first.page, 294);
      expect(rows.last.page, 42);
      expect(rows.map((r) => r.number), [1, 2]);
      await bloc.close();
    });

    test('an empty bookmarks tab has no rows', () async {
      final bloc = await started();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.bookmarks));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.bookmarks);
      expect(loaded(bloc).rows, isEmpty);
      await bloc.close();
    });
  });

  group('search', () {
    test('filters after the debounce', () async {
      final bloc = await started();
      bloc.add(const QuranIndexQueryChanged('الكهف'));
      expect(loaded(bloc).rows, hasLength(114), reason: 'not yet applied');
      await settle();
      expect(loaded(bloc).rows.map((r) => r.number), [18]);
      expect(loaded(bloc).isSearching, isTrue);
      await bloc.close();
    });

    test('only the last of rapid keystrokes is applied (restartable)', () async {
      final bloc = await started();
      final queries = <String>[];
      final sub = bloc.stream.listen((s) {
        if (s is QuranIndexLoaded) queries.add(s.query);
      });
      for (final q in ['ا', 'ال', 'الك', 'الكه', 'الكهف']) {
        bloc.add(QuranIndexQueryChanged(q));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await settle(150);
      expect(queries, ['الكهف'], reason: 'one filter pass, for the final text');
      await sub.cancel();
      await bloc.close();
    });

    test('clearing applies immediately and restores the full list', () async {
      final bloc = await started();
      bloc.add(const QuranIndexQueryChanged('الكهف'));
      await settle();
      bloc.add(const QuranIndexQueryChanged('', immediate: true));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(loaded(bloc).rows, hasLength(114));
      expect(loaded(bloc).isSearching, isFalse);
      await bloc.close();
    });

    test('matches Arabic-Indic numbers and transliteration', () async {
      final bloc = await started();
      bloc.add(const QuranIndexQueryChanged('١٨'));
      await settle();
      expect(loaded(bloc).rows.map((r) => r.number), [18]);
      bloc.add(const QuranIndexQueryChanged('kahf'));
      await settle();
      expect(loaded(bloc).rows.map((r) => r.number), contains(18));
      await bloc.close();
    });

    test('no match gives an empty list', () async {
      final bloc = await started();
      bloc.add(const QuranIndexQueryChanged('zzzzqqq'));
      await settle();
      expect(loaded(bloc).rows, isEmpty);
      await bloc.close();
    });

    test('searching also filters bookmarks by surah name', () async {
      reader.state = ReaderState(bookmarks: [
        Bookmark(surah: 18, ayah: 10, createdAt: _t),
        Bookmark(surah: 2, ayah: 255, createdAt: _t.subtract(const Duration(minutes: 1))),
      ]);
      final bloc = await started();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.bookmarks));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.bookmarks);
      bloc.add(const QuranIndexQueryChanged('البقرة'));
      await settle();
      expect(loaded(bloc).rows.map((r) => r.surah), [2]);
      await bloc.close();
    });

    test('the query survives a tab change', () async {
      final bloc = await started();
      bloc.add(const QuranIndexQueryChanged('الكهف'));
      await settle();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.juz));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.juz);
      expect(loaded(bloc).query, 'الكهف');
      expect(loaded(bloc).rows.map((r) => r.number), [16]);
      await bloc.close();
    });
  });

  group('bookmark removal', () {
    setUp(() {
      reader.state = ReaderState(bookmarks: [
        Bookmark(surah: 18, ayah: 10, createdAt: _t.add(const Duration(minutes: 1))),
        Bookmark(surah: 2, ayah: 255, createdAt: _t),
      ]);
    });

    Future<QuranIndexBloc> onBookmarks() async {
      final bloc = await started();
      bloc.add(const QuranIndexTabChanged(QuranIndexTab.bookmarks));
      await bloc.stream.firstWhere((s) => s is QuranIndexLoaded && s.tab == QuranIndexTab.bookmarks);
      return bloc;
    }

    test('is applied to the list at once and then persisted', () async {
      final bloc = await onBookmarks();
      bloc.add(const QuranIndexBookmarkRemoved(18, 10));
      await Future<void>.delayed(Duration.zero);
      expect(loaded(bloc).rows.map((r) => r.surah), [2], reason: 'optimistic');
      await settle();
      expect(reader.state.hasBookmark(18, 10), isFalse);
      await bloc.close();
    });

    test('undo brings it back in its original place', () async {
      final bloc = await onBookmarks();
      final at = loaded(bloc).rows.first.bookmarkedAtMs!;
      bloc.add(const QuranIndexBookmarkRemoved(18, 10));
      await settle();
      bloc.add(QuranIndexBookmarkRestored(
        18,
        10,
        DateTime.fromMillisecondsSinceEpoch(at),
      ));
      await settle();
      expect(loaded(bloc).rows.map((r) => r.surah), [18, 2]);
      expect(reader.state.hasBookmark(18, 10), isTrue);
      expect(reader.state.bookmarks.first.createdAt.millisecondsSinceEpoch, at);
      await bloc.close();
    });

    test('if the write fails the real list is shown again', () async {
      final bloc = await onBookmarks();
      reader.failWrites = true;
      bloc.add(const QuranIndexBookmarkRemoved(18, 10));
      await settle();
      expect(loaded(bloc).rows.map((r) => r.surah), [18, 2]);
      await bloc.close();
    });
  });
}
