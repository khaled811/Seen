import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_dua_repository.dart';
import 'package:seen_booking/features/spiritual/domain/entities/dua.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/tawaf_bloc.dart';

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled duas.json has the dua of each rite', () async {
    final repo = JsonDuaRepository(includeUnreviewed: true);
    final duas = (await repo.getDuas()).getOrElse((_) => const []);
    final byId = {for (final d in duas) d.id: d};
    for (final id in TawafBloc.duaIds.values) {
      expect(byId[id], isNotNull, reason: id);
      expect(byId[id]!.text, isNotEmpty);
      expect(byId[id]!.audioAsset, isNotNull);
    }
    expect(byId['rukn']!.isQuranic, isTrue);
    expect(byId['safa-marwa']!.isQuranic, isFalse);
  });

  test('the mock audio asset referenced by the duas is bundled', () async {
    final duas = (await JsonDuaRepository(includeUnreviewed: true).getDuas())
        .getOrElse((_) => const []);
    for (final d in duas) {
      final data = await rootBundle.load(d.audioAsset!);
      expect(data.lengthInBytes, greaterThan(44), reason: d.audioAsset);
    }
  });

  test('unreviewed duas are hidden in release builds', () async {
    final repo = JsonDuaRepository(includeUnreviewed: false);
    expect((await repo.getDuas()).getOrElse((_) => throw 'x'), isEmpty);
  });

  test('filters by category and by reviewed flag', () async {
    const json = '''[
      {"id":"a","category":"safar","title":"t","text":"x","source":"s","reviewed":true},
      {"id":"b","category":"hajj","title":"t","text":"x","source":"s","reviewed":false}
    ]''';
    final all = JsonDuaRepository(
      bundle: _StringBundle(json),
      includeUnreviewed: true,
    );
    expect((await all.getDuas()).getOrElse((_) => const []), hasLength(2));
    expect(
      (await all.getDuas(category: DuaCategory.hajj))
          .getOrElse((_) => const [])
          .single
          .id,
      'b',
    );
    final released = JsonDuaRepository(
      bundle: _StringBundle(json),
      includeUnreviewed: false,
    );
    expect(
      (await released.getDuas()).getOrElse((_) => const []).single.id,
      'a',
    );
  });

  test('malformed JSON becomes a CacheFailure', () async {
    final repo = JsonDuaRepository(bundle: _StringBundle('{oops'));
    expect((await repo.getDuas()).swap().getOrElse((_) => throw 'x'),
        isA<CacheFailure>());
  });
}
