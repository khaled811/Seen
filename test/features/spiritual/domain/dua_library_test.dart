import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua_filter.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/dua_library_usecases.dart';
import 'package:seen_booking/features/spiritual/domain/utils/dua_text.dart';

import '../support/remembrance_fakes.dart';

List<String> _ids(List<Dua> l) => [for (final d in l) d.id];

List<Dua> _filter({
  DuaFilter filter = DuaFilter.all,
  Set<String> favorites = const {},
  String query = '',
}) =>
    filterDuas(sampleDuas, filter: filter, favorites: favorites, query: query);

void main() {
  group('category filtering', () {
    test('all keeps every dua in order', () {
      expect(_ids(_filter()), ['a', 'b', 'c', 'd']);
    });

    test('each chip keeps only its category', () {
      expect(_ids(_filter(filter: DuaFilter.safar)), ['a']);
      expect(_ids(_filter(filter: DuaFilter.hajj)), ['b']);
      expect(_ids(_filter(filter: DuaFilter.adhkar)), ['c']);
      expect(_ids(_filter(filter: DuaFilter.jawami)), ['d']);
    });

    test('every chip maps to the matching DuaCategory', () {
      expect(DuaFilter.hajj.category, DuaCategory.hajj);
      expect(DuaFilter.safar.category, DuaCategory.safar);
      expect(DuaFilter.adhkar.category, DuaCategory.adhkar);
      expect(DuaFilter.jawami.category, DuaCategory.jawami);
      expect(DuaFilter.all.category, isNull);
      expect(DuaFilter.saved.category, isNull);
    });

    test('saved shows only favourites, whatever their category', () {
      expect(_ids(_filter(filter: DuaFilter.saved, favorites: {'a', 'd'})), ['a', 'd']);
      expect(_filter(filter: DuaFilter.saved), isEmpty);
    });

    test('a favourite that no longer exists is ignored', () {
      expect(_filter(filter: DuaFilter.saved, favorites: {'gone'}), isEmpty);
    });
  });

  group('search', () {
    test('matches the title', () {
      expect(_ids(_filter(query: 'تلبية')), ['b']);
    });

    test('ignores tashkeel on both sides', () {
      // The stored text is fully vowelled, the query is not.
      expect(_ids(_filter(query: 'نص تجريبي للسفر')), ['a']);
      expect(_ids(_filter(query: 'نَصٌّ')), ['a', 'b', 'c', 'd']);
    });

    test('unifies alef, ya and ta marbuta spellings', () {
      expect(_ids(_filter(query: 'تلبيه')), ['b']);
      expect(_ids(_filter(query: 'ذكر الصباح')), ['c']);
    });

    test('matches the source', () {
      expect(_ids(_filter(query: 'البخاري')), ['c']);
      expect(_ids(_filter(query: 'متفق')), ['b']);
    });

    test('matches the usage note', () {
      expect(_ids(_filter(query: 'الركوب')), ['a']);
    });

    test('blank and whitespace-only queries match everything', () {
      expect(_filter(query: '   '), hasLength(4));
    });

    test('no match gives an empty list', () {
      expect(_filter(query: 'لا يوجد هذا'), isEmpty);
    });

    test('combines with the chip', () {
      expect(_ids(_filter(filter: DuaFilter.safar, query: 'تجريبي')), ['a']);
      expect(_filter(filter: DuaFilter.hajj, query: 'السفر'), isEmpty);
    });

    test('combines with saved', () {
      expect(
        _ids(_filter(filter: DuaFilter.saved, favorites: {'a', 'b'}, query: 'تلبية')),
        ['b'],
      );
    });
  });

  group('share and copy', () {
    test('the shared text carries the source on its own line', () {
      expect(duaShareText(sampleDuas.first), 'نَصٌّ تَجْرِيبِيٌّ لِلسَّفَرِ\n— صحيح مسلم');
    });

    test('share passes the title as the subject', () async {
      final sharer = FakeDuaSharer();
      final ok = await ShareDuaUseCase(sharer)(sampleDuas.first);
      expect(ok, isTrue);
      expect(sharer.shared.single.subject, 'دعاء السفر التجريبي');
      expect(sharer.shared.single.text, duaShareText(sampleDuas.first));
    });

    test('share reports a failure', () async {
      final sharer = FakeDuaSharer()..succeeds = false;
      expect(await ShareDuaUseCase(sharer)(sampleDuas.first), isFalse);
    });

    test('copy writes the same text to the clipboard', () async {
      final clipboard = FakeClipboard();
      expect(await CopyDuaUseCase(clipboard)(sampleDuas[1]), isTrue);
      expect(clipboard.last, duaShareText(sampleDuas[1]));
    });

    test('copy reports a clipboard failure instead of throwing', () async {
      final clipboard = FakeClipboard()..throws = true;
      expect(await CopyDuaUseCase(clipboard)(sampleDuas.first), isFalse);
    });
  });
}
