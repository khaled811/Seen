import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/domain/repositories/tawaf_session_repository.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/record_lap_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/restore_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/undo_lap_usecase.dart';

class _FakeRepo implements TawafSessionRepository {
  TawafSession? stored;
  bool failSave = false;

  @override
  Future<Either<Failure, TawafSession?>> load() async => Right(stored);

  @override
  Future<Either<Failure, Unit>> save(TawafSession session) async {
    if (failSave) return const Left(CacheFailure('disk full'));
    stored = session;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> clear() async {
    stored = null;
    return const Right(unit);
  }
}

final _t0 = DateTime(2026, 10, 3, 12);

TawafSession _afterLaps(int n) {
  var s = TawafSession.start(RiteMode.tawaf, _t0);
  for (var i = 0; i < n; i++) {
    s = s.recordLap(_t0.add(Duration(minutes: i + 1)));
  }
  return s;
}

void main() {
  group('TawafSession', () {
    test('starts at lap 1 with no progress', () {
      final s = TawafSession.start(RiteMode.sai, _t0);
      expect(s.currentLap, 1);
      expect(s.completedLaps, 0);
      expect(s.done, isFalse);
      expect(s.canUndo, isFalse);
    });

    test('recording advances the lap and stores a timestamp', () {
      final s = _afterLaps(2);
      expect(s.currentLap, 3);
      expect(s.completedLaps, 2);
      expect(s.lapTimestamps, hasLength(2));
    });

    test('lap 7 completes the rite and stays at 7', () {
      final s = _afterLaps(7);
      expect(s.done, isTrue);
      expect(s.currentLap, 7);
      expect(s.completedLaps, 7);
      expect(s.isLastLap, isFalse);
      expect(_afterLaps(6).isLastLap, isTrue);
    });

    test('recording after completion is a no-op', () {
      final s = _afterLaps(7);
      expect(s.recordLap(_t0.add(const Duration(hours: 1))), s);
    });

    test('undo steps back, including out of the done state', () {
      expect(_afterLaps(3).undoLap(), _afterLaps(2));
      final undone = _afterLaps(7).undoLap();
      expect(undone.done, isFalse);
      expect(undone.currentLap, 7);
      expect(undone.completedLaps, 6);
      expect(undone.lapTimestamps, hasLength(6));
    });

    test('undo with no progress is a no-op', () {
      final s = TawafSession.start(RiteMode.tawaf, _t0);
      expect(s.undoLap(), s);
    });
  });

  group('use cases', () {
    test('record persists and returns the new session', () async {
      final repo = _FakeRepo();
      final start = TawafSession.start(RiteMode.tawaf, _t0);
      final r = await RecordLapUseCase(repo)(start, now: _t0.add(const Duration(seconds: 5)));
      expect(r.isRight(), isTrue);
      expect(repo.stored?.currentLap, 2);
    });

    test('taps within 1.5 s of the previous lap are rejected', () async {
      final repo = _FakeRepo();
      final usecase = RecordLapUseCase(repo);
      final first = (await usecase(
        TawafSession.start(RiteMode.tawaf, _t0),
        now: _t0,
      ))
          .getOrElse((_) => throw StateError('x'));
      final tooSoon = await usecase(first, now: _t0.add(const Duration(milliseconds: 1499)));
      expect(tooSoon.isLeft(), isTrue);
      expect(repo.stored?.currentLap, 2, reason: 'rejected tap must not persist');
      final ok = await usecase(first, now: _t0.add(const Duration(milliseconds: 1500)));
      expect(ok.isRight(), isTrue);
    });

    test('a storage failure is returned, not thrown', () async {
      final repo = _FakeRepo()..failSave = true;
      final r = await RecordLapUseCase(repo)(
        TawafSession.start(RiteMode.tawaf, _t0),
        now: _t0,
      );
      expect(r.swap().getOrElse((_) => throw StateError('x')), isA<CacheFailure>());
    });

    test('undo persists; restore returns what was saved', () async {
      final repo = _FakeRepo();
      final three = _afterLaps(3);
      final undone = (await UndoLapUseCase(repo)(three)).getOrElse((_) => three);
      expect(undone.completedLaps, 2);
      expect(undone.currentLap, 3);
      final restored = (await RestoreSessionUseCase(repo)()).getOrElse((_) => null);
      expect(restored, undone);
    });

    test('restore with nothing stored yields null', () async {
      final restored = (await RestoreSessionUseCase(_FakeRepo())()).getOrElse((_) => _afterLaps(1));
      expect(restored, isNull);
    });
  });
}
