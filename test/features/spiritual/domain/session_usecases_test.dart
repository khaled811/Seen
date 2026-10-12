import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/end_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/record_lap_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/restore_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/start_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/undo_lap_usecase.dart';

import '../support/fakes.dart';

final _t0 = DateTime(2026, 10, 3, 12);

void main() {
  group('a whole Tawaf through the use cases', () {
    test('seven spaced taps complete it, persisting every step', () async {
      final repo = InMemoryTawafRepo();
      var s = (await StartSessionUseCase(repo)(RiteMode.tawaf, now: _t0))
          .getOrElse((_) => throw 'x');
      final record = RecordLapUseCase(repo);
      for (var i = 1; i <= 7; i++) {
        s = (await record(s, now: _t0.add(Duration(minutes: i))))
            .getOrElse((_) => throw 'lap $i');
        expect(repo.stored, s, reason: 'persisted after lap $i');
      }
      expect(s.done, isTrue);
      expect(s.completedLaps, 7);
      expect(repo.saves, 8, reason: 'start + 7 laps');
    });

    test('the 7th lap cannot be double-counted by a second tap', () async {
      final repo = InMemoryTawafRepo();
      var s = TawafSession.start(RiteMode.tawaf, _t0);
      final record = RecordLapUseCase(repo);
      for (var i = 1; i <= 6; i++) {
        s = (await record(s, now: _t0.add(Duration(minutes: i))))
            .getOrElse((_) => throw 'x');
      }
      final last = _t0.add(const Duration(minutes: 7));
      s = (await record(s, now: last)).getOrElse((_) => throw 'x');
      expect(s.done, isTrue);
      final again = await record(s, now: last.add(const Duration(seconds: 1)));
      expect(again.getOrElse((_) => throw 'x'), s, reason: 'done is a no-op');
    });
  });

  group('debounce window', () {
    test('rejects exactly < 1.5 s, accepts >= 1.5 s', () async {
      final repo = InMemoryTawafRepo();
      final record = RecordLapUseCase(repo);
      final first = (await record(
        TawafSession.start(RiteMode.tawaf, _t0),
        now: _t0,
      ))
          .getOrElse((_) => throw 'x');

      for (final ms in [0, 1, 750, 1499]) {
        final r = await record(first, now: _t0.add(Duration(milliseconds: ms)));
        expect(r.swap().getOrElse((_) => throw 'accepted at $ms ms'),
            isA<ValidationFailure>(),
            reason: '$ms ms');
      }
      for (final ms in [1500, 1501, 60000]) {
        final r = await record(first, now: _t0.add(Duration(milliseconds: ms)));
        expect(r.isRight(), isTrue, reason: '$ms ms');
      }
      expect(repo.saves, 4, reason: 'rejected taps never persist');
    });

    test('the very first lap is never debounced', () async {
      final repo = InMemoryTawafRepo();
      final r = await RecordLapUseCase(repo)(
        TawafSession.start(RiteMode.tawaf, _t0),
        now: _t0,
      );
      expect(r.isRight(), isTrue);
    });

    test('the window is measured from the last recorded lap, after undo too',
        () async {
      final repo = InMemoryTawafRepo();
      final record = RecordLapUseCase(repo);
      var s = TawafSession.start(RiteMode.tawaf, _t0);
      s = (await record(s, now: _t0)).getOrElse((_) => throw 'x');
      s = (await record(s, now: _t0.add(const Duration(seconds: 5))))
          .getOrElse((_) => throw 'x');
      s = (await UndoLapUseCase(repo)(s)).getOrElse((_) => throw 'x');
      // Undo removed the 5 s stamp; the previous lap was at t0.
      final r = await record(s, now: _t0.add(const Duration(seconds: 1)));
      expect(r.isLeft(), isTrue);
    });
  });

  group('undo', () {
    test('steps back one lap at a time, persisting', () async {
      final repo = InMemoryTawafRepo();
      var s = TawafSession.start(RiteMode.tawaf, _t0);
      final record = RecordLapUseCase(repo);
      for (var i = 1; i <= 3; i++) {
        s = (await record(s, now: _t0.add(Duration(minutes: i))))
            .getOrElse((_) => throw 'x');
      }
      expect(s.currentLap, 4);
      s = (await UndoLapUseCase(repo)(s)).getOrElse((_) => throw 'x');
      expect(s.currentLap, 3);
      expect(repo.stored, s);
      s = (await UndoLapUseCase(repo)(s)).getOrElse((_) => throw 'x');
      s = (await UndoLapUseCase(repo)(s)).getOrElse((_) => throw 'x');
      expect(s.currentLap, 1);
      expect(s.canUndo, isFalse);
      final saves = repo.saves;
      s = (await UndoLapUseCase(repo)(s)).getOrElse((_) => throw 'x');
      expect(s.currentLap, 1, reason: 'cannot undo below lap 1');
      expect(repo.saves, saves, reason: 'a no-op undo does not write');
    });

    test('un-completes a finished rite', () async {
      final repo = InMemoryTawafRepo();
      var s = TawafSession.start(RiteMode.sai, _t0);
      for (var i = 0; i < 7; i++) {
        s = s.recordLap(_t0.add(Duration(minutes: i + 1)));
      }
      expect(s.done, isTrue);
      s = (await UndoLapUseCase(repo)(s)).getOrElse((_) => throw 'x');
      expect(s.done, isFalse);
      expect(s.completedLaps, 6);
    });
  });

  group('restore / end', () {
    test('a restored session continues at the same lap', () async {
      final repo = InMemoryTawafRepo();
      var s = TawafSession.start(RiteMode.tawaf, _t0);
      for (var i = 1; i <= 4; i++) {
        s = (await RecordLapUseCase(repo)(s, now: _t0.add(Duration(minutes: i))))
            .getOrElse((_) => throw 'x');
      }
      // "Process death": only the repository survives.
      final restored = (await RestoreSessionUseCase(repo)())
          .getOrElse((_) => throw 'x')!;
      expect(restored, s);
      expect(restored.currentLap, 5);
      expect(restored.lapTimestamps, hasLength(4));
      final next = (await RecordLapUseCase(repo)(
        restored,
        now: _t0.add(const Duration(minutes: 5)),
      ))
          .getOrElse((_) => throw 'x');
      expect(next.currentLap, 6);
    });

    test('ending clears the stored session', () async {
      final repo = InMemoryTawafRepo(TawafSession.start(RiteMode.tawaf, _t0));
      await EndSessionUseCase(repo)();
      expect(repo.stored, isNull);
      expect(repo.clears, 1);
    });

    test('a failed clear is reported', () async {
      final repo = InMemoryTawafRepo()..failClear = true;
      expect((await EndSessionUseCase(repo)()).isLeft(), isTrue);
    });

    test('starting a session replaces whatever was stored', () async {
      final repo = InMemoryTawafRepo(
        TawafSession.start(RiteMode.tawaf, _t0).recordLap(_t0),
      );
      final s = (await StartSessionUseCase(repo)(RiteMode.sai, now: _t0))
          .getOrElse((_) => throw 'x');
      expect(repo.stored, s);
      expect(s.mode, RiteMode.sai);
      expect(s.currentLap, 1);
    });
  });
}
