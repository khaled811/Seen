import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/data/repositories/dua_user_data_repository_impl.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_dhikr_catalog.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_dua_repository.dart';
import 'package:seen_booking/features/spiritual/data/repositories/tasbeeh_repository_impl.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_filter.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_user_data.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tasbeeh.dart';
import 'package:shared_preferences/shared_preferences.dart';

T _ok<T>(Object? either) =>
    (either as dynamic).getOrElse((f) => throw StateError('$f')) as T;

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('dua favourites and last chip', () {
    test('defaults: nothing saved, the "all" chip', () async {
      final d = _ok<DuaUserData>(await DuaUserDataRepositoryImpl().load());
      expect(d.favorites, isEmpty);
      expect(d.filter, DuaFilter.all);
    });

    test('toggle adds, then removes', () async {
      final repo = DuaUserDataRepositoryImpl();
      var d = _ok<DuaUserData>(await repo.toggleFavorite('rukn'));
      expect(d.favorites, {'rukn'});
      d = _ok<DuaUserData>(await repo.toggleFavorite('rukn'));
      expect(d.favorites, isEmpty);
    });

    test('favourites and the chip survive an app restart', () async {
      final first = DuaUserDataRepositoryImpl();
      await first.toggleFavorite('a');
      await first.toggleFavorite('b');
      await first.saveFilter(DuaFilter.saved);

      // A brand-new repository over the same storage = a new app launch.
      final d = _ok<DuaUserData>(await DuaUserDataRepositoryImpl().load());
      expect(d.favorites, {'a', 'b'});
      expect(d.filter, DuaFilter.saved);
    });

    test('quick toggles never interleave', () async {
      final repo = DuaUserDataRepositoryImpl();
      await Future.wait([
        for (final id in ['a', 'b', 'c', 'a']) repo.toggleFavorite(id),
      ]);
      final d = _ok<DuaUserData>(await DuaUserDataRepositoryImpl().load());
      expect(d.favorites, {'b', 'c'});
    });

    test('unreadable stored values fall back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        DuaUserDataRepositoryImpl.favoritesKey: '{not json',
        DuaUserDataRepositoryImpl.filterKey: 'martian',
      });
      final d = _ok<DuaUserData>(await DuaUserDataRepositoryImpl().load());
      expect(d.favorites, isEmpty);
      expect(d.filter, DuaFilter.all);
    });
  });

  group('tasbeeh storage', () {
    const progress = TasbeehProgress(
      dhikrId: 'subhan',
      target: TasbeehTarget.hundred,
      count: 41,
      complete: false,
      day: '2026-10-03',
      daily: {
        'subhan': DhikrDay(total: 141, rounds: 1),
        'hamd': DhikrDay(total: 9),
      },
    );

    test('nothing saved yet is null, not an error', () async {
      expect(_ok<TasbeehProgress?>(await TasbeehRepositoryImpl().load()), isNull);
    });

    test('round trip through a restart', () async {
      expect((await TasbeehRepositoryImpl().save(progress)).isRight(), isTrue);
      final back = _ok<TasbeehProgress?>(await TasbeehRepositoryImpl().load());
      expect(back, progress);
    });

    test('every distinct count is stored immediately', () async {
      final repo = TasbeehRepositoryImpl();
      await repo.save(progress.copyWith(count: 1));
      expect(_ok<TasbeehProgress?>(await TasbeehRepositoryImpl().load())!.count, 1);
      await repo.save(progress.copyWith(count: 2));
      expect(_ok<TasbeehProgress?>(await TasbeehRepositoryImpl().load())!.count, 2);
    });

    test('a burst of saves ends with the latest value on disk', () async {
      final repo = TasbeehRepositoryImpl();
      final results = await Future.wait([
        for (var i = 1; i <= 50; i++) repo.save(progress.copyWith(count: i)),
      ]);
      expect(results.every((r) => r.isRight()), isTrue);
      final back = _ok<TasbeehProgress?>(await TasbeehRepositoryImpl().load());
      expect(back!.count, 50);
    });

    test('a burst is coalesced into far fewer writes', () async {
      final prefs = await SharedPreferences.getInstance();
      final counting = _CountingPrefs(prefs);
      final repo = TasbeehRepositoryImpl(preferences: Future.value(counting));
      await Future.wait([
        for (var i = 1; i <= 50; i++) repo.save(progress.copyWith(count: i)),
      ]);
      expect(counting.writes, lessThan(10), reason: '50 taps, not 50 writes');
      expect(counting.writes, greaterThanOrEqualTo(1));
    });

    test('unreadable or invalid stored values are ignored', () async {
      for (final bad in [
        '{oops',
        '[]',
        jsonEncode({'d': 'x', 't': 7, 'c': 1, 'day': 'd'}), // unknown target
        jsonEncode({'d': 'x', 't': 33, 'c': -4, 'day': 'd'}), // negative count
        jsonEncode({'t': 33, 'c': 1, 'day': 'd'}), // no dhikr
      ]) {
        SharedPreferences.setMockInitialValues({TasbeehRepositoryImpl.key: bad});
        expect(
          _ok<TasbeehProgress?>(await TasbeehRepositoryImpl().load()),
          isNull,
          reason: bad,
        );
      }
    });
  });

  group('bundled content', () {
    test('tasbeeh_adhkar.json holds the eight adhkar with unique ids', () async {
      final list = _ok<List<TasbeehDhikr>>(await JsonDhikrCatalog().adhkar());
      expect(list, hasLength(8));
      expect({for (final d in list) d.id}, hasLength(8));
      expect(list.every((d) => d.label.trim().isNotEmpty), isTrue);
    });

    test('malformed adhkar json is a failure, not a crash', () async {
      final catalog = JsonDhikrCatalog(bundle: _StringBundle('{oops'));
      expect((await catalog.adhkar()).isLeft(), isTrue);
    });

    test('an empty list is a failure', () async {
      final catalog = JsonDhikrCatalog(bundle: _StringBundle('[]'));
      expect((await catalog.adhkar()).isLeft(), isTrue);
    });

    test('duas.json: the eight starting duas, each complete and sourced', () async {
      final duas = _ok<List<Dua>>(
        await JsonDuaRepository(includeUnreviewed: true).getDuas(),
      );
      expect(
        {for (final d in duas) d.id},
        {
          'safar',
          'talbiyah',
          'rukn',
          'manzil',
          'istighfar',
          'afiyah',
          'thabat',
          'safa-marwa',
        },
      );
      for (final d in duas) {
        expect(d.title.trim(), isNotEmpty, reason: d.id);
        expect(d.text.trim(), isNotEmpty, reason: d.id);
        expect(d.source.trim(), isNotEmpty, reason: '${d.id} needs a source');
        expect(d.reviewed, isFalse, reason: '${d.id} awaits scholar review');
        expect(d.audioAsset, isNotNull, reason: d.id);
      }
      // Every chip has something in it.
      for (final c in DuaCategory.values) {
        expect(duas.any((d) => d.category == c), isTrue, reason: '$c');
      }
    });

    test('release builds show none of the unreviewed duas', () async {
      final duas = _ok<List<Dua>>(
        await JsonDuaRepository(includeUnreviewed: false).getDuas(),
      );
      expect(duas, isEmpty);
    });
  });
}

/// Counts writes to see how many a burst of saves causes.
class _CountingPrefs implements SharedPreferences {
  _CountingPrefs(this._inner);

  final SharedPreferences _inner;
  int writes = 0;

  @override
  Future<bool> setString(String key, String value) {
    writes++;
    return _inner.setString(key, value);
  }

  @override
  String? getString(String key) => _inner.getString(key);

  // Anything else would mean the repository grew a new dependency.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
