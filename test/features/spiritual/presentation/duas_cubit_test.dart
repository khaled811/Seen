import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_filter.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_user_data.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/dua_library_usecases.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_duas_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/utils/dua_text.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/duas_cubit.dart';

import '../support/remembrance_fakes.dart';

DuasCubit _cubit(
  DuaHarness h, {
  Duration copiedFor = const Duration(milliseconds: 1600),
}) =>
    DuasCubit(
      getDuas: GetDuasUseCase(h.repo),
      loadUserData: LoadDuaUserDataUseCase(h.userData),
      toggleFavorite: ToggleFavoriteDuaUseCase(h.userData),
      saveFilter: SaveDuaFilterUseCase(h.userData),
      share: ShareDuaUseCase(h.sharer),
      copy: CopyDuaUseCase(h.clipboard),
      copiedFor: copiedFor,
    );

List<String> _visible(DuasCubit c) => [for (final d in c.state.visible) d.id];

void main() {
  group('loading', () {
    test('shows every dua and no expanded card', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      expect(c.state.status, DuasStatus.ready);
      expect(_visible(c), ['a', 'b', 'c', 'd']);
      expect(c.state.openId, isNull);
      await c.close();
    });

    test('a repository failure becomes a failure state', () async {
      final c = _cubit(DuaHarness(failDuas: true));
      await c.load();
      expect(c.state.status, DuasStatus.failure);
      await c.close();
    });

    test('unreadable saved data does not hide the library', () async {
      final h = DuaHarness()..userData.failLoad = true;
      final c = _cubit(h);
      await c.load();
      expect(c.state.status, DuasStatus.ready);
      expect(c.state.favorites, isEmpty);
      expect(c.state.filter, DuaFilter.all);
      await c.close();
    });

    test('release gating: unreviewed duas never reach the screen', () async {
      final c = _cubit(DuaHarness(includeUnreviewed: false));
      await c.load();
      expect(_visible(c), ['a', 'b', 'c']);
      await c.close();
    });

    test('restores the saved favourites and the last chip', () async {
      final c = _cubit(DuaHarness(
        initial: const DuaUserData(favorites: {'b'}, filter: DuaFilter.saved),
      ));
      await c.load();
      expect(c.state.filter, DuaFilter.saved);
      expect(_visible(c), ['b']);
      await c.close();
    });
  });

  group('category filtering', () {
    test('each chip narrows the list', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      await c.selectFilter(DuaFilter.safar);
      expect(_visible(c), ['a']);
      await c.selectFilter(DuaFilter.hajj);
      expect(_visible(c), ['b']);
      await c.selectFilter(DuaFilter.all);
      expect(_visible(c), ['a', 'b', 'c', 'd']);
      await c.close();
    });

    test('the chosen chip is remembered', () async {
      final h = DuaHarness();
      final c = _cubit(h);
      await c.load();
      await c.selectFilter(DuaFilter.adhkar);
      expect(h.userData.data.filter, DuaFilter.adhkar);
      await c.close();
    });

    test('re-selecting the same chip writes nothing', () async {
      final h = DuaHarness();
      final c = _cubit(h);
      await c.load();
      await c.selectFilter(DuaFilter.all);
      expect(h.userData.writes, 0);
      await c.close();
    });

    test('changing chip closes the open card', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      c.toggleOpen('a');
      await c.selectFilter(DuaFilter.hajj);
      expect(c.state.openId, isNull);
      await c.close();
    });

    test('a failed save of the chip still switches it, and tells the user', () async {
      final h = DuaHarness()..userData.failWrites = true;
      final c = _cubit(h);
      await c.load();
      await c.selectFilter(DuaFilter.hajj);
      expect(_visible(c), ['b']);
      expect(c.state.notice, DuasNotice.saveFailed);
      await c.close();
    });
  });

  group('search', () {
    test('filters as the query changes and restores on clear', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      c.search('تلبية');
      expect(_visible(c), ['b']);
      c.search('');
      expect(_visible(c), ['a', 'b', 'c', 'd']);
      await c.close();
    });

    test('works inside a chip', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      await c.selectFilter(DuaFilter.safar);
      c.search('تلبية');
      expect(_visible(c), isEmpty);
      await c.close();
    });

    test('no match gives an empty list', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      c.search('xyz');
      expect(c.state.visible, isEmpty);
      await c.close();
    });
  });

  group('open card', () {
    test('only one card is open at a time', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      c.toggleOpen('a');
      expect(c.state.openId, 'a');
      c.toggleOpen('b');
      expect(c.state.openId, 'b');
      c.toggleOpen('b');
      expect(c.state.openId, isNull);
      await c.close();
    });
  });

  group('bookmarking', () {
    test('toggles at once and persists', () async {
      final h = DuaHarness();
      final c = _cubit(h);
      await c.load();
      final pending = c.toggleFavorite('a');
      expect(c.state.favorites, {'a'}, reason: 'optimistic, before the write');
      await pending;
      expect(h.userData.data.favorites, {'a'});
      await c.toggleFavorite('a');
      expect(c.state.favorites, isEmpty);
      expect(h.userData.data.favorites, isEmpty);
      await c.close();
    });

    test('survives a new session', () async {
      final h = DuaHarness();
      final first = _cubit(h);
      await first.load();
      await first.toggleFavorite('c');
      await first.close();

      final second = _cubit(h);
      await second.load();
      expect(second.state.favorites, {'c'});
      await second.close();
    });

    test('a failed write is undone and reported', () async {
      final h = DuaHarness()..userData.failWrites = true;
      final c = _cubit(h);
      await c.load();
      await c.toggleFavorite('a');
      expect(c.state.favorites, isEmpty);
      expect(c.state.notice, DuasNotice.saveFailed);
      await c.close();
    });

    test('un-saving while viewing "saved" removes the card', () async {
      final c = _cubit(DuaHarness(
        initial: const DuaUserData(favorites: {'a', 'b'}, filter: DuaFilter.saved),
      ));
      await c.load();
      await c.toggleFavorite('a');
      expect(_visible(c), ['b']);
      await c.close();
    });

    test('saving a dua adds it to the saved view', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      await c.selectFilter(DuaFilter.saved);
      expect(c.state.visible, isEmpty);
      await c.toggleFavorite('d');
      expect(_visible(c), ['d']);
      await c.close();
    });
  });

  group('copy', () {
    test('writes the dua and its source, then shows "copied" briefly', () async {
      final h = DuaHarness();
      final c = _cubit(h, copiedFor: const Duration(milliseconds: 30));
      await c.load();
      await c.copy(sampleDuas.first);
      expect(h.clipboard.last, duaShareText(sampleDuas.first));
      expect(c.state.copiedId, 'a');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.state.copiedId, isNull);
      await c.close();
    });

    test('copying another dua moves the label', () async {
      final c = _cubit(DuaHarness());
      await c.load();
      await c.copy(sampleDuas[0]);
      await c.copy(sampleDuas[1]);
      expect(c.state.copiedId, 'b');
      await c.close();
    });

    test('a clipboard failure is reported, not shown as copied', () async {
      final h = DuaHarness()..clipboard.throws = true;
      final c = _cubit(h);
      await c.load();
      await c.copy(sampleDuas.first);
      expect(c.state.copiedId, isNull);
      expect(c.state.notice, DuasNotice.copyFailed);
      await c.close();
    });

    test('closing cancels the pending label timer', () async {
      final c = _cubit(DuaHarness(), copiedFor: const Duration(milliseconds: 20));
      await c.load();
      await c.copy(sampleDuas.first);
      await c.close();
      // No emit-after-close error may surface.
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
  });

  group('share', () {
    test('hands the title and text-with-source to the share sheet', () async {
      final h = DuaHarness();
      final c = _cubit(h);
      await c.load();
      await c.share(sampleDuas[2]);
      expect(h.sharer.shared.single.subject, sampleDuas[2].title);
      expect(h.sharer.shared.single.text, duaShareText(sampleDuas[2]));
      expect(c.state.notice, DuasNotice.none);
      await c.close();
    });

    test('a failure is reported', () async {
      final h = DuaHarness();
      h.sharer.succeeds = false;
      final c = _cubit(h);
      await c.load();
      await c.share(sampleDuas.first);
      expect(c.state.notice, DuasNotice.shareFailed);
      await c.close();
    });

    test('the same notice can fire twice in a row', () async {
      final h = DuaHarness();
      h.sharer.succeeds = false;
      final c = _cubit(h);
      await c.load();
      await c.share(sampleDuas.first);
      final first = c.state.noticeSeq;
      await c.share(sampleDuas.first);
      expect(c.state.noticeSeq, greaterThan(first));
      await c.close();
    });
  });
}
