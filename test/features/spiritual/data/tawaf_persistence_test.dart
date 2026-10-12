import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/data/models/tawaf_session_dto.dart';
import 'package:seen_booking/features/spiritual/data/repositories/tawaf_session_repository_impl.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 10, 3, 12);

TawafSession _session(int laps, {RiteMode mode = RiteMode.tawaf}) {
  var s = TawafSession.start(mode, _t0);
  for (var i = 0; i < laps; i++) {
    s = s.recordLap(_t0.add(Duration(minutes: i + 1)));
  }
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TawafSessionDto', () {
    test('round-trips every field', () {
      final s = _session(4, mode: RiteMode.sai);
      final back = TawafSessionDto.fromJson(
        jsonDecode(jsonEncode(TawafSessionDto.fromEntity(s).toJson())),
      ).toEntity();
      expect(back, s);
    });

    test('rejects malformed or out-of-range data', () {
      Map<String, Object?> ok() =>
          TawafSessionDto.fromEntity(_session(1)).toJson();
      expect(() => TawafSessionDto.fromJson('nope'), throwsFormatException);
      expect(() => TawafSessionDto.fromJson({...ok(), 'mode': 'hajj'}),
          throwsFormatException);
      expect(() => TawafSessionDto.fromJson({...ok(), 'currentLap': 0}),
          throwsFormatException);
      expect(() => TawafSessionDto.fromJson({...ok(), 'currentLap': 8}),
          throwsFormatException);
      expect(() => TawafSessionDto.fromJson({...ok(), 'done': 'yes'}),
          throwsFormatException);
      expect(() => TawafSessionDto.fromJson({...ok(), 'lapTimestamps': ['x']}),
          throwsFormatException);
      expect(() => TawafSessionDto.fromJson({...ok()}..remove('startedAt')),
          throwsFormatException);
    });
  });

  group('TawafSessionRepositoryImpl', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('nothing stored -> null', () async {
      final r = await TawafSessionRepositoryImpl().load();
      expect(r.getOrElse((_) => _session(1)), isNull);
    });

    test('a saved session is restored by a brand-new repository (app restart)',
        () async {
      final before = _session(3);
      await TawafSessionRepositoryImpl().save(before);
      // A new instance over a fresh SharedPreferences handle = new process.
      final after = await TawafSessionRepositoryImpl().load();
      expect(after.getOrElse((_) => null), before);
    });

    test('every save overwrites the previous state immediately', () async {
      final repo = TawafSessionRepositoryImpl();
      await repo.save(_session(1));
      await repo.save(_session(5));
      expect((await repo.load()).getOrElse((_) => null)?.currentLap, 6);
    });

    test('a corrupt record is dropped and treated as no session', () async {
      SharedPreferences.setMockInitialValues(
        {TawafSessionRepositoryImpl.storageKey: '{not json'},
      );
      final repo = TawafSessionRepositoryImpl();
      expect((await repo.load()).getOrElse((_) => _session(1)), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(TawafSessionRepositoryImpl.storageKey), isFalse);
    });

    test('an out-of-range record is dropped too', () async {
      SharedPreferences.setMockInitialValues({
        TawafSessionRepositoryImpl.storageKey: jsonEncode({
          'mode': 'tawaf',
          'currentLap': 99,
          'done': false,
          'startedAt': 0,
          'lapTimestamps': <int>[],
        }),
      });
      final r = await TawafSessionRepositoryImpl().load();
      expect(r.getOrElse((_) => _session(1)), isNull);
    });

    test('clear forgets the session', () async {
      final repo = TawafSessionRepositoryImpl();
      await repo.save(_session(2));
      await repo.clear();
      expect((await repo.load()).getOrElse((_) => _session(1)), isNull);
    });

    test('storage errors surface as CacheFailure, not exceptions', () async {
      final repo = TawafSessionRepositoryImpl(
        preferences: Future<SharedPreferences>.error(StateError('no disk')),
      );
      expect((await repo.load()).swap().getOrElse((_) => throw 'x'),
          isA<CacheFailure>());
      expect((await repo.save(_session(1))).isLeft(), isTrue);
      expect((await repo.clear()).isLeft(), isTrue);
    });
  });
}
