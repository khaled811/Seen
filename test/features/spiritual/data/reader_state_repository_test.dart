import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/repositories/reader_state_repository_impl.dart';
import 'package:seen_booking/features/spiritual/domain/entities/last_read.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t = DateTime(2026, 10, 3, 12);

ReaderState _ok(Object? r) =>
    (r as dynamic).getOrElse((f) => throw StateError('$f')) as ReaderState;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults: no bookmarks, no last read, font step 2 (30 sp)', () async {
    final s = _ok(await ReaderStateRepositoryImpl().load());
    expect(s.bookmarks, isEmpty);
    expect(s.lastRead, isNull);
    expect(s.fontStep, 2);
    expect(s.fontSize, 30);
  });

  group('bookmarks', () {
    test('toggle adds, then removes', () async {
      final repo = ReaderStateRepositoryImpl();
      var s = _ok(await repo.toggleBookmark(18, 10, now: _t));
      expect(s.hasBookmark(18, 10), isTrue);
      s = _ok(await repo.toggleBookmark(18, 10, now: _t));
      expect(s.hasBookmark(18, 10), isFalse);
      expect(s.bookmarks, isEmpty);
    });

    test('newest first, and they survive an app restart', () async {
      final repo = ReaderStateRepositoryImpl();
      await repo.toggleBookmark(2, 255, now: _t);
      await repo.toggleBookmark(18, 10, now: _t.add(const Duration(minutes: 1)));
      // New repository instance = new process.
      final after = _ok(await ReaderStateRepositoryImpl().load());
      expect(after.bookmarks.map((b) => '${b.surah}:${b.ayah}'), ['18:10', '2:255']);
      expect(after.bookmarks.last.createdAt, _t);
    });

    test('rapid concurrent toggles are applied in order, none lost', () async {
      final repo = ReaderStateRepositoryImpl();
      await Future.wait([
        for (var i = 1; i <= 20; i++) repo.toggleBookmark(2, i, now: _t),
      ]);
      final after = _ok(await ReaderStateRepositoryImpl().load());
      expect(after.bookmarks, hasLength(20));
    });

    test('a corrupt bookmark list is discarded, not fatal', () async {
      SharedPreferences.setMockInitialValues(
        {ReaderStateRepositoryImpl.bookmarksKey: '{broken'},
      );
      final s = _ok(await ReaderStateRepositoryImpl().load());
      expect(s.bookmarks, isEmpty);
    });
  });

  group('last read', () {
    test('is saved immediately and restored after a restart', () async {
      await ReaderStateRepositoryImpl()
          .saveLastRead(const LastRead(surah: 18, ayah: 3));
      final s = _ok(await ReaderStateRepositoryImpl().load());
      expect(s.lastRead, const LastRead(surah: 18, ayah: 3));
    });

    test('invalid stored values are ignored', () async {
      for (final bad in ['x', '0:1', '115:1', '2:0', '2', '2:x']) {
        SharedPreferences.setMockInitialValues(
          {ReaderStateRepositoryImpl.lastReadKey: bad},
        );
        final s = _ok(await ReaderStateRepositoryImpl().load());
        expect(s.lastRead, isNull, reason: bad);
      }
    });
  });

  group('font step', () {
    test('persists across restarts', () async {
      await ReaderStateRepositoryImpl().saveFontStep(4);
      final s = _ok(await ReaderStateRepositoryImpl().load());
      expect(s.fontStep, 4);
      expect(s.fontSize, 38);
    });

    test('is clamped to the six sizes', () async {
      final repo = ReaderStateRepositoryImpl();
      expect(_ok(await repo.saveFontStep(99)).fontStep, 5);
      expect(_ok(await repo.saveFontStep(-3)).fontStep, 0);
    });

    test('an out-of-range stored step falls back to the default', () async {
      SharedPreferences.setMockInitialValues(
        {ReaderStateRepositoryImpl.fontStepKey: 42},
      );
      expect(_ok(await ReaderStateRepositoryImpl().load()).fontStep, 2);
    });
  });

  test('the three pieces of state do not overwrite each other', () async {
    final repo = ReaderStateRepositoryImpl();
    await repo.toggleBookmark(1, 1, now: _t);
    await repo.saveLastRead(const LastRead(surah: 2, ayah: 5));
    await repo.saveFontStep(0);
    final s = _ok(await ReaderStateRepositoryImpl().load());
    expect(s.bookmarks, hasLength(1));
    expect(s.lastRead?.surah, 2);
    expect(s.fontStep, 0);
  });

  test('storage errors become CacheFailure, and the cache is not poisoned',
      () async {
    final repo = ReaderStateRepositoryImpl(
      preferences: Future<SharedPreferences>.delayed(
        const Duration(milliseconds: 1),
        () => throw StateError('no disk'),
      ),
    );
    final r = await repo.toggleBookmark(1, 1, now: _t);
    expect(r.swap().getOrElse((_) => throw 'x'), isA<CacheFailure>());
    expect((await repo.load()).isLeft(), isTrue);
  });

  test('stored JSON uses a compact documented shape', () async {
    await ReaderStateRepositoryImpl().toggleBookmark(2, 255, now: _t);
    final prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(
      prefs.getString(ReaderStateRepositoryImpl.bookmarksKey)!,
    ) as List;
    expect(json.single, {'s': 2, 'a': 255, 't': _t.millisecondsSinceEpoch});
  });
}
