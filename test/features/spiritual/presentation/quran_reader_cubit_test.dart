import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_quran_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/bookmark.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/quran_usecases.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/quran_reader_cubit.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JsonQuranRepository quran;
  late InMemoryReaderState reader;

  setUp(() {
    quran = JsonQuranRepository(useIsolate: false);
    reader = InMemoryReaderState();
  });

  Future<QuranReaderCubit> open(int surah) async {
    final cubit = QuranReaderCubit(
      surahNumber: surah,
      loadQuran: LoadQuranUseCase(quran),
      getReaderState: GetReaderStateUseCase(reader),
      toggleBookmark: ToggleBookmarkUseCase(reader),
      saveLastRead: SaveLastReadUseCase(reader),
      saveFontStep: SaveFontStepUseCase(reader),
      clock: () => DateTime(2026, 10, 3),
    );
    await cubit.load();
    return cubit;
  }

  QuranReaderLoaded loaded(QuranReaderCubit c) => c.state as QuranReaderLoaded;

  test('loads the surah with its ayahs, metadata and default font', () async {
    final cubit = await open(18);
    final s = loaded(cubit);
    expect(s.surah.nameAr, 'الكهف');
    expect(s.ayahs, hasLength(110));
    expect(s.fontStep, 2);
    expect(s.fontSize, 30);
    expect(s.bookmarked, isEmpty);
    await cubit.close();
  });

  test('the basmala header appears for every surah except 1 and 9', () async {
    for (final n in [2, 18, 114]) {
      final cubit = await open(n);
      expect(loaded(cubit).basmala, isNotNull, reason: 'surah $n');
      await cubit.close();
    }
    for (final n in [1, 9]) {
      final cubit = await open(n);
      expect(loaded(cubit).basmala, isNull, reason: 'surah $n');
      await cubit.close();
    }
  });

  group('font size', () {
    test('steps through 24 27 30 34 38 42 and persists each change', () async {
      final cubit = await open(1);
      final seen = <double>[];
      for (var i = 0; i < 3; i++) {
        await cubit.increaseFont();
        seen.add(loaded(cubit).fontSize);
      }
      expect(seen, [34, 38, 42]);
      expect(reader.state.fontStep, 5);
      await cubit.decreaseFont();
      expect(loaded(cubit).fontSize, 38);
      expect(reader.state.fontStep, 4);
      await cubit.close();
    });

    test('stops at both ends', () async {
      final cubit = await open(1);
      for (var i = 0; i < 10; i++) {
        await cubit.increaseFont();
      }
      expect(loaded(cubit).canGrow, isFalse);
      expect(loaded(cubit).fontSize, 42);
      for (var i = 0; i < 10; i++) {
        await cubit.decreaseFont();
      }
      expect(loaded(cubit).canShrink, isFalse);
      expect(loaded(cubit).fontSize, 24);
      await cubit.close();
    });

    test('a stored size is restored on open', () async {
      reader.state = const ReaderState(fontStep: 4);
      final cubit = await open(1);
      expect(loaded(cubit).fontSize, 38);
      await cubit.close();
    });
  });

  group('bookmarks', () {
    test('toggle adds then removes, persisting each time', () async {
      final cubit = await open(18);
      expect(await cubit.toggleBookmark(10), isTrue);
      expect(loaded(cubit).bookmarked, {10});
      expect(reader.state.hasBookmark(18, 10), isTrue);
      expect(await cubit.toggleBookmark(10), isFalse);
      expect(loaded(cubit).bookmarked, isEmpty);
      await cubit.close();
    });

    test('only this surah\'s bookmarks are shown as bookmarked', () async {
      reader.state = ReaderState(bookmarks: [
        Bookmark(surah: 18, ayah: 3, createdAt: DateTime(2026)),
        Bookmark(surah: 2, ayah: 255, createdAt: DateTime(2026)),
      ]);
      final cubit = await open(18);
      expect(loaded(cubit).bookmarked, {3});
      await cubit.close();
    });

    test('a failed write is reported and the mark is not shown', () async {
      final cubit = await open(18);
      reader.failWrites = true;
      expect(await cubit.toggleBookmark(10), isFalse);
      expect(loaded(cubit).bookmarked, isEmpty);
      expect(loaded(cubit).saveFailed, isTrue);
      expect(loaded(cubit).saveSeq, 1);
      await cubit.close();
    });
  });

  group('last read', () {
    test('is saved with surah and ayah', () async {
      final cubit = await open(18);
      await cubit.saveLastRead(3);
      expect(reader.state.lastRead?.surah, 18);
      expect(reader.state.lastRead?.ayah, 3);
      await cubit.close();
    });

    test('a failed save is reported', () async {
      final cubit = await open(18);
      reader.failWrites = true;
      await cubit.saveLastRead(3);
      expect(loaded(cubit).saveFailed, isTrue);
      await cubit.close();
    });
  });
}
