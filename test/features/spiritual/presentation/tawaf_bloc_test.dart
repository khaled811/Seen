import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/domain/entities/rite_mode.dart';
import 'package:seen_booking/features/spiritual/domain/entities/tawaf_session.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/end_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/get_duas_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/record_lap_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/restore_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/start_session_usecase.dart';
import 'package:seen_booking/features/spiritual/domain/usecases/undo_lap_usecase.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/tawaf_bloc.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/tawaf_event.dart';
import 'package:seen_booking/features/spiritual/presentation/bloc/tawaf_state.dart';

import '../support/fakes.dart';

TawafBloc _bloc(
  InMemoryTawafRepo repo,
  FakeClock clock, {
  FakeDuaRepository? duas,
}) =>
    TawafBloc(
      restoreSession: RestoreSessionUseCase(repo),
      startSession: StartSessionUseCase(repo),
      recordLap: RecordLapUseCase(repo),
      undoLap: UndoLapUseCase(repo),
      endSession: EndSessionUseCase(repo),
      getDuas: GetDuasUseCase(duas ?? FakeDuaRepository()),
      clock: clock.call,
    );

Future<TawafBloc> _started(InMemoryTawafRepo repo, FakeClock clock) async {
  final bloc = _bloc(repo, clock)..add(const TawafStarted());
  await bloc.stream.firstWhere((s) => s is TawafReady);
  return bloc;
}

TawafReady _ready(TawafBloc b) => b.state as TawafReady;

/// Presses the lap button and waits for the resulting state change.
Future<void> _press(TawafBloc bloc, FakeClock clock, {int advanceMs = 2000}) async {
  clock.advance(Duration(milliseconds: advanceMs));
  final seq = _ready(bloc).actionSeq;
  bloc.add(const TawafPrimaryPressed());
  await Future<void>.delayed(const Duration(milliseconds: 10));
  expect(_ready(bloc).actionSeq, seq + 1, reason: 'press was accepted');
}

void main() {
  late InMemoryTawafRepo repo;
  late FakeClock clock;

  setUp(() {
    repo = InMemoryTawafRepo();
    clock = FakeClock();
  });

  group('start / restore', () {
    test('with nothing stored a fresh Tawaf starts and is persisted', () async {
      final bloc = await _started(repo, clock);
      final s = _ready(bloc);
      expect(s.session.mode, RiteMode.tawaf);
      expect(s.session.currentLap, 1);
      expect(s.action, TawafAction.none);
      expect(s.saveFailed, isFalse);
      expect(repo.stored, s.session);
      expect(s.dua?.id, 'rukn');
      await bloc.close();
    });

    test('an existing session is restored at the same lap, not reset', () async {
      repo.stored = TawafSession(
        mode: RiteMode.sai,
        currentLap: 5,
        done: false,
        startedAt: clock.now,
        lapTimestamps: [clock.now, clock.now, clock.now, clock.now],
      );
      final bloc = await _started(repo, clock);
      final s = _ready(bloc);
      expect(s.session.mode, RiteMode.sai);
      expect(s.session.currentLap, 5);
      expect(s.statusLap, 4, reason: 'status says lap 4 was recorded');
      expect(s.dua?.id, 'safa-marwa');
      expect(repo.saves, 0, reason: 'restoring must not overwrite');
      await bloc.close();
    });

    test('a new bloc after a "process kill" resumes where the old one was',
        () async {
      final first = await _started(repo, clock);
      await _press(first, clock);
      await _press(first, clock);
      await first.close();

      final second = await _started(repo, clock);
      expect(_ready(second).session.currentLap, 3);
      await _press(second, clock);
      expect(_ready(second).session.currentLap, 4);
      await second.close();
    });

    test('an unreadable store falls back to a fresh session and warns',
        () async {
      repo.failLoad = true;
      final bloc = await _started(repo, clock);
      expect(_ready(bloc).session.currentLap, 1);
      expect(_ready(bloc).saveFailed, isTrue);
      await bloc.close();
    });

    test('missing duas do not block the screen', () async {
      final bloc = _bloc(repo, clock, duas: FakeDuaRepository(fail: true))
        ..add(const TawafStarted());
      await bloc.stream.firstWhere((s) => s is TawafReady);
      expect(_ready(bloc).dua, isNull);
      await bloc.close();
    });
  });

  group('recording laps', () {
    test('each press persists and advances', () async {
      final bloc = await _started(repo, clock);
      await _press(bloc, clock);
      var s = _ready(bloc);
      expect(s.session.currentLap, 2);
      expect(s.action, TawafAction.lapRecorded);
      expect(s.statusLap, 1);
      expect(repo.stored, s.session);
      await _press(bloc, clock);
      s = _ready(bloc);
      expect(s.statusLap, 2);
      expect(repo.stored?.currentLap, 3);
      await bloc.close();
    });

    test('a second press within 1.5 s is ignored (nothing emitted or saved)',
        () async {
      final bloc = await _started(repo, clock);
      await _press(bloc, clock);
      final saves = repo.saves;
      final before = _ready(bloc);

      clock.advance(const Duration(milliseconds: 800));
      bloc.add(const TawafPrimaryPressed());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(_ready(bloc), before);
      expect(repo.saves, saves);

      await _press(bloc, clock, advanceMs: 800); // 1.6 s after the lap
      expect(_ready(bloc).session.currentLap, 3);
      await bloc.close();
    });

    test('a burst of taps counts exactly one lap', () async {
      final bloc = await _started(repo, clock);
      clock.advance(const Duration(seconds: 2));
      for (var i = 0; i < 6; i++) {
        bloc.add(const TawafPrimaryPressed());
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(_ready(bloc).session.currentLap, 2);
      await bloc.close();
    });

    test('lap 7 completes the Tawaf', () async {
      final bloc = await _started(repo, clock);
      for (var i = 0; i < 6; i++) {
        await _press(bloc, clock);
      }
      expect(_ready(bloc).session.isLastLap, isTrue);
      await _press(bloc, clock);
      final s = _ready(bloc);
      expect(s.session.done, isTrue);
      expect(s.action, TawafAction.completed);
      expect(s.statusLap, 7);
      expect(repo.stored?.done, isTrue);
      await bloc.close();
    });

    test('a failing disk keeps the lap in memory and raises saveFailed',
        () async {
      final bloc = await _started(repo, clock);
      repo.failSave = true;
      await _press(bloc, clock);
      final s = _ready(bloc);
      expect(s.session.currentLap, 2, reason: 'progress is never lost');
      expect(s.saveFailed, isTrue);
      repo.failSave = false;
      await _press(bloc, clock);
      expect(_ready(bloc).saveFailed, isFalse, reason: 'recovers on next save');
      expect(repo.stored?.currentLap, 3);
      await bloc.close();
    });
  });

  group('undo', () {
    test('is a no-op at lap 1', () async {
      final bloc = await _started(repo, clock);
      final before = _ready(bloc);
      bloc.add(const TawafUndoRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(_ready(bloc), before);
      await bloc.close();
    });

    test('goes back one lap and persists it', () async {
      final bloc = await _started(repo, clock);
      await _press(bloc, clock);
      await _press(bloc, clock);
      bloc.add(const TawafUndoRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final s = _ready(bloc);
      expect(s.session.currentLap, 2);
      expect(s.action, TawafAction.undone);
      expect(s.statusLap, 2);
      expect(repo.stored?.currentLap, 2);
      await bloc.close();
    });

    test('reopens a completed rite', () async {
      final bloc = await _started(repo, clock);
      for (var i = 0; i < 7; i++) {
        await _press(bloc, clock);
      }
      bloc.add(const TawafUndoRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(_ready(bloc).session.done, isFalse);
      expect(_ready(bloc).session.currentLap, 7);
      await bloc.close();
    });
  });

  group('mode switch', () {
    test('starts the other rite from lap 1 and persists it', () async {
      final bloc = await _started(repo, clock);
      await _press(bloc, clock);
      bloc.add(const TawafModeSelected(RiteMode.sai));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final s = _ready(bloc);
      expect(s.session.mode, RiteMode.sai);
      expect(s.session.currentLap, 1);
      expect(s.action, TawafAction.modeChanged);
      expect(s.dua?.id, 'safa-marwa');
      expect(repo.stored?.mode, RiteMode.sai);
      await bloc.close();
    });

    test('selecting the current mode changes nothing', () async {
      final bloc = await _started(repo, clock);
      await _press(bloc, clock);
      final before = _ready(bloc);
      bloc.add(const TawafModeSelected(RiteMode.tawaf));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(_ready(bloc), before);
      await bloc.close();
    });

    test('pressing the button after a finished Tawaf moves to Sa\'i', () async {
      final bloc = await _started(repo, clock);
      for (var i = 0; i < 7; i++) {
        await _press(bloc, clock);
      }
      await _press(bloc, clock);
      final s = _ready(bloc);
      expect(s.session.mode, RiteMode.sai);
      expect(s.session.currentLap, 1);
      expect(s.session.done, isFalse);
      await bloc.close();
    });
  });

  group('ending', () {
    test('clears the session and emits TawafEnded', () async {
      final bloc = await _started(repo, clock);
      await _press(bloc, clock);
      bloc.add(const TawafEndRequested());
      await bloc.stream.firstWhere((s) => s is TawafEnded);
      expect(repo.stored, isNull);
      await bloc.close();
    });

    test('finishing Sa\'i with the last button also ends the rite', () async {
      repo.stored = TawafSession.start(RiteMode.sai, clock.now);
      final bloc = await _started(repo, clock);
      for (var i = 0; i < 7; i++) {
        await _press(bloc, clock);
      }
      expect(_ready(bloc).session.done, isTrue);
      bloc.add(const TawafPrimaryPressed());
      await bloc.stream.firstWhere((s) => s is TawafEnded);
      expect(repo.stored, isNull);
      await bloc.close();
    });

    test('if the session cannot be cleared the screen stays and warns',
        () async {
      final bloc = await _started(repo, clock);
      repo.failClear = true;
      bloc.add(const TawafEndRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state, isA<TawafReady>());
      expect(_ready(bloc).saveFailed, isTrue);
      await bloc.close();
    });
  });
}
